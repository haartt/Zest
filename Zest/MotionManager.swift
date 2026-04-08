import CoreMotion
import Combine
import Foundation

// MARK: - CalibrationState

enum CalibrationState: Equatable {
    case idle
    case warmingUp(secondsRemaining: Int)
    case active
}

// MARK: - RMSBuffer
// Fixed-size circular buffer that computes Root Mean Square efficiently.
// RMS = sqrt(mean of squares) — measures signal energy regardless of sign.

private struct RMSBuffer {
    private var data: [Double]
    private var writeIndex = 0
    private(set) var count = 0
    let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        data = Array(repeating: 0, count: capacity)
    }

    mutating func push(_ value: Double) {
        data[writeIndex % capacity] = value
        writeIndex += 1
        count = min(count + 1, capacity)
    }

    var isFull: Bool { count == capacity }

    /// Root Mean Square of all stored samples.
    var rms: Double {
        guard count > 0 else { return 0 }
        let sumSq = data.prefix(count).reduce(0.0) { $0 + $1 * $1 }
        return sqrt(sumSq / Double(count))
    }

    /// Mean of stored samples (used for baseline mean display).
    var mean: Double {
        guard count > 0 else { return 0 }
        return data.prefix(count).reduce(0, +) / Double(count)
    }
}

// MARK: - MotionManager

/// Fuses accelerometer + gyroscope to detect gait anomalies.
///
/// Core idea — Energy Ratio Detection:
///
///   shortRMS (0.5 s) / longRMS (5 s) = energy ratio
///
///   • Normal running/walking → ratio ≈ 1.0  (short energy ≈ long energy)
///   • Stumble / hit           → ratio > spikeThreshold  (energy spike)
///   • Sudden stop             → ratio < dropThreshold   (energy disappears)
///
/// This is self-normalising: no absolute thresholds, no person-specific tuning.
/// The 60-second warm-up builds a stable longRMS before detection starts.
///
/// GPS deceleration is a second independent trigger.
final class MotionManager: ObservableObject {

    // MARK: - Published

    @Published private(set) var calibrationState: CalibrationState = .idle
    @Published private(set) var isScatterTriggered = false
    @Published private(set) var magnitude: Double = 0

    /// Live energy ratio — useful for debug UI or future visualisation.
    @Published private(set) var energyRatio: Double = 1.0
    @Published private(set) var shortEnergy: Double = 0
    @Published private(set) var longEnergy: Double  = 0

    // MARK: - External input (from WorkoutManager via GPS)

    var externalSpeed: Double = 0

    // MARK: - Configuration

    private let sampleRate: Double = 30      // Hz (accelerometer + gyroscope)

    // Buffer sizes
    private let shortWindowSeconds: Double = 0.5   // 15 samples — reacts fast
    private let longWindowSeconds:  Double = 5.0   // 150 samples — stable baseline
    private var shortCapacity: Int { Int(sampleRate * shortWindowSeconds) }
    private var longCapacity:  Int { Int(sampleRate * longWindowSeconds)  }

    // Warm-up
    private let warmupSeconds: Double = 60.0

    // Scatter triggers
    /// Short/long RMS ratio above this → energy spike → scatter
    private let spikeThreshold: Double = 2.2
    /// Short/long RMS ratio below this → energy vanished → scatter (sudden stop)
    private let dropThreshold:  Double = 0.25

    // Relock (scatter → off)
    /// Ratio must be inside this band to count as "stable new gait"
    private let relockLow:  Double = 0.35
    private let relockHigh: Double = 2.2
    /// Must stay in band for this long before scatter turns off
    private let relockMinSeconds: Double = 1.0

    /// EMA alpha for smoothing the ratio used in relock check.
    /// High value = more reactive, lower = ignores brief spikes during recovery.
    private let ratioEMAalpha: Double = 0.25

    // Smoothed ratio — used only for relock, not for trigger
    private var smoothedRatio: Double = 1.0

    // Sensor fusion weight
    /// Gyroscope contributes this fraction to the combined signal.
    /// Gyro is very sensitive to stumbles; 0.4 is a good starting point.
    private let gyroWeight: Double = 0.4

    // GPS deceleration
    private let speedDropThreshold: Double = 1.5   // m/s
    private let speedWindowSeconds: Int    = 3

    // Cooldown between consecutive scatter triggers
    private let scatterCooldown: Double = 0.8

    // MARK: - Private state

    private let motion = CMMotionManager()
    private let motionQueue: OperationQueue = {
        let q = OperationQueue()
        q.qualityOfService = .userInteractive
        q.maxConcurrentOperationCount = 1
        return q
    }()

    private var shortBuffer = RMSBuffer(capacity: 0)   // sized in start()
    private var longBuffer  = RMSBuffer(capacity: 0)
    private var longFrozen  = false                    // frozen during scatter

    private var stableStartTime: Date? = nil
    private var warmupStartTime: Date? = nil
    private var warmupTimer: Timer?

    private var speedHistory: [(time: Date, speed: Double)] = []
    private var lastScatterTime: Date? = nil

    // MARK: - Public control

    func start() {
        shortBuffer     = RMSBuffer(capacity: shortCapacity)
        longBuffer      = RMSBuffer(capacity: longCapacity)
        longFrozen      = false
        stableStartTime = nil
        smoothedRatio   = 1.0
        speedHistory    = []
        lastScatterTime = nil
        warmupStartTime = Date()

        calibrationState = .warmingUp(secondsRemaining: Int(warmupSeconds))
        startWarmupTimer()

        guard motion.isAccelerometerAvailable && motion.isGyroAvailable else {
            print("[MotionManager] Sensors unavailable — GPS-only mode")
            calibrationState = .active
            return
        }

        motion.accelerometerUpdateInterval = 1.0 / sampleRate
        motion.gyroUpdateInterval          = 1.0 / sampleRate

        // We only need one callback — pair acc+gyro via DeviceMotion
        // which gives us both in a single fused update (no sync needed).
        if motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = 1.0 / sampleRate
            motion.startDeviceMotionUpdates(to: motionQueue) { [weak self] data, _ in
                guard let self, let data else { return }
                let accMag  = Self.jerk(from: data.userAcceleration)
                let gyroMag = Self.gyroMag(from: data.rotationRate)
                let fused   = accMag + self.gyroWeight * gyroMag
                DispatchQueue.main.async { self.process(fused, raw: accMag) }
            }
        } else {
            // Fallback: accelerometer only
            motion.startAccelerometerUpdates(to: motionQueue) { [weak self] data, _ in
                guard let self, let data else { return }
                let acc   = data.acceleration
                let totalG = sqrt(acc.x*acc.x + acc.y*acc.y + acc.z*acc.z)
                let jerk   = abs(totalG - 1.0)
                DispatchQueue.main.async { self.process(jerk, raw: jerk) }
            }
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        motion.stopAccelerometerUpdates()
        warmupTimer?.invalidate()
        warmupTimer = nil

        calibrationState   = .idle
        isScatterTriggered = false
        magnitude          = 0
        energyRatio        = 1.0
        shortEnergy        = 0
        longEnergy         = 0
        externalSpeed      = 0
        speedHistory       = []
        stableStartTime    = nil
        longFrozen         = false
        lastScatterTime    = nil
        warmupStartTime    = nil
    }

    // MARK: - GPS deceleration (called by WorkoutManager)

    func updateSpeed(_ speed: Double) {
        externalSpeed = speed
        let now = Date()
        speedHistory.append((now, speed))
        speedHistory.removeAll {
            $0.time < now.addingTimeInterval(-Double(speedWindowSeconds))
        }

        guard calibrationState == .active,
              !isScatterTriggered,
              let oldest = speedHistory.first else { return }

        let drop = oldest.speed - speed
        if drop >= speedDropThreshold {
            fire(reason: "GPS decel \(String(format:"%.1f", drop)) m/s")
        }
    }

    // MARK: - Core processing

    private func process(_ fused: Double, raw: Double) {
        magnitude = raw

        // Push to short buffer always
        shortBuffer.push(fused)

        // Warm-up: also feed long buffer, no detection
        if case .warmingUp = calibrationState {
            longBuffer.push(fused)
            return
        }

        guard calibrationState == .active else { return }

        // Normal: update long baseline only when not frozen
        if !longFrozen {
            longBuffer.push(fused)
        }

        let sRMS = shortBuffer.rms
        let lRMS = longBuffer.rms
        shortEnergy = sRMS
        longEnergy  = lRMS

        guard lRMS > 0.001 else { return }   // not enough signal yet

        let ratio = sRMS / lRMS
        energyRatio = ratio

        if !isScatterTriggered {
            // Use raw ratio for triggering — we want fast reaction
            if ratio > spikeThreshold {
                fire(reason: "spike ratio=\(String(format:"%.2f", ratio))")
            } else if ratio < dropThreshold && shortBuffer.isFull {
                fire(reason: "drop ratio=\(String(format:"%.2f", ratio))")
            }
        } else {
            // Recovery: use SMOOTHED ratio so step peaks don't reset the clock
            let inBand = smoothedRatio > relockLow && smoothedRatio < relockHigh

            if inBand {
                if stableStartTime == nil { stableStartTime = Date() }
                if let stableStartTime {
                    let elapsed = Date().timeIntervalSince(stableStartTime)
                    if elapsed >= relockMinSeconds {
                    relock()
                    }
                }
            } else {
                stableStartTime = nil
            }
        }
    }

    // MARK: - Scatter fire / relock

    private func fire(reason: String) {
        let now = Date()
        if let last = lastScatterTime,
           now.timeIntervalSince(last) < scatterCooldown { return }
        lastScatterTime = now

        guard !isScatterTriggered else { return }
        print("[Motion] ▲ ON — \(reason)")

        isScatterTriggered = true
        longFrozen         = true
        stableStartTime    = nil
    }

    private func relock() {
        print("[Motion] ▼ Relock — ratio stable for \(relockMinSeconds)s")
        // Unfreeze: start accepting new long-buffer samples again
        longFrozen         = false
        stableStartTime    = nil
        smoothedRatio      = 1.0
        isScatterTriggered = false
    }

    // MARK: - Warm-up timer

    private func startWarmupTimer() {
        warmupTimer?.invalidate()
        warmupTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let start = self.warmupStartTime else { return }
            let elapsed   = Date().timeIntervalSince(start)
            let remaining = max(0, Int(ceil(self.warmupSeconds - elapsed)))
            if remaining <= 0 {
                self.calibrationState = .active
                self.warmupTimer?.invalidate()
                self.warmupTimer = nil
                print("[Motion] Warm-up done — longRMS=\(String(format:"%.4f", self.longBuffer.rms))")
            } else {
                self.calibrationState = .warmingUp(secondsRemaining: remaining)
            }
        }
    }

    // MARK: - Signal helpers

    /// Jerk from CMDeviceMotion.userAcceleration (gravity already removed by CoreMotion).
    private static func jerk(from a: CMAcceleration) -> Double {
        sqrt(a.x*a.x + a.y*a.y + a.z*a.z)
    }

    /// Total rotation rate magnitude in rad/s.
    private static func gyroMag(from r: CMRotationRate) -> Double {
        sqrt(r.x*r.x + r.y*r.y + r.z*r.z)
    }
}
