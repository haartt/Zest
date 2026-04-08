import AVFoundation
import Combine

/// Wraps AVAudioEngine with:
///  - Speed-driven low-pass filter (400 Hz closed → 20 kHz open)
///  - Shaperbox-style scatter volume gate (random 8–16 Hz ON/OFF bursts)
///  - Two dry placeholder effect nodes (reverb, delay) ready for future tweaking
@MainActor
final class AudioEngine: ObservableObject {

    // MARK: - Published state

    @Published private(set) var isPlaying = false
    @Published private(set) var isScattering = false
    @Published private(set) var currentTrackName: String = "—"

    // MARK: - AVAudio graph

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let lowPassEQ: AVAudioUnitEQ        // speed-driven low-pass
    private let reverbNode = AVAudioUnitReverb() // placeholder — dry
    private let delayNode  = AVAudioUnitDelay()  // placeholder — dry

    private var smoothedSpeed: Float = 0

    // MARK: - Scatter

    private var scatterTimer: Timer?
    private var scatterPhase = false

    // MARK: - Constants

    private let minFrequency: Float = 400      // Hz at speed ≈ 0
    private let maxFrequency: Float = 20_000   // Hz at speed ≥ maxSpeed
    private let mediumFrequency: Float = 4_000 // Hz at "medium" pace
    private let smoothingFactor: Float = 0.1

    // MARK: - Init

    init() {
        lowPassEQ = AVAudioUnitEQ(numberOfBands: 1)
        configureLowPass()
        configureAudioSession()
        buildEngineGraph()
    }

    // MARK: - Setup

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("[AudioEngine] Session error: \(error)")
        }
    }

    private func configureLowPass() {
        let band = lowPassEQ.bands[0]
        band.filterType = .lowPass
        band.frequency  = minFrequency
        band.bandwidth  = 0.5  // narrow → steep roll-off
        band.bypass     = false
    }

    private func buildEngineGraph() {
        // Attach
        engine.attach(playerNode)
        engine.attach(lowPassEQ)
        engine.attach(reverbNode)
        engine.attach(delayNode)

        // Chain: player → lowPass → reverb → delay → mainMixer → output
        // (final formats are set when a file is loaded)
        let mixer = engine.mainMixerNode
        engine.connect(playerNode, to: lowPassEQ, format: nil)
        engine.connect(lowPassEQ, to: reverbNode, format: nil)
        engine.connect(reverbNode, to: delayNode, format: nil)
        engine.connect(delayNode, to: mixer, format: nil)

        // Placeholder effects are dry by default
        reverbNode.wetDryMix = 0
        delayNode.wetDryMix  = 0

        // Start engine lazily (on play) after a file is scheduled.
    }

    private func startEngine() {
        guard !engine.isRunning else { return }
        do {
            try engine.start()
        } catch {
            print("[AudioEngine] Engine start error: \(error)")
        }
    }

    // MARK: - Track loading

    func load(url: URL) {
        stopScatter()
        playerNode.stop()

        do {
            let file = try AVAudioFile(forReading: url)
            currentTrackName = url.deletingPathExtension().lastPathComponent

            // Safest AVAudioEngine reconfiguration pattern:
            // stop + reset engine, disconnect, then reconnect using the file's format.
            if engine.isRunning { engine.stop() }
            engine.reset()
            playerNode.stop()

            engine.disconnectNodeOutput(playerNode)
            engine.disconnectNodeOutput(lowPassEQ)
            engine.disconnectNodeOutput(reverbNode)
            engine.disconnectNodeOutput(delayNode)

            let fmt = file.processingFormat
            let mixer = engine.mainMixerNode
            engine.connect(playerNode, to: lowPassEQ, format: fmt)
            engine.connect(lowPassEQ, to: reverbNode, format: fmt)
            engine.connect(reverbNode, to: delayNode, format: fmt)
            engine.connect(delayNode, to: mixer, format: fmt)

            playerNode.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.isPlaying = false
                }
            }
        } catch {
            print("[AudioEngine] Load error: \(error)")
        }
    }

    // MARK: - Playback

    func play() {
        // Ensure the audio session is active right before playback.
        configureAudioSession()
        if !engine.isRunning { startEngine() }
        playerNode.play()
        isPlaying = true
    }

    func stop() {
        playerNode.stop()
        stopScatter()
        isPlaying = false
    }

    // MARK: - Speed-driven filter

    /// Call this on every speed update (m/s). Interpolates cutoff exponentially.
    func updateSpeed(_ speed: Float) {
        // Smooth incoming speed to avoid audio jitter
        smoothedSpeed = smoothingFactor * speed + (1 - smoothingFactor) * smoothedSpeed

        let thresholds = ZestSettings.orderedSpeedThresholds()
        let slow = max(0, thresholds.slow)
        let medium = max(slow, thresholds.medium)
        let fast = max(medium, thresholds.fast)

        let freq: Float
        let shouldBypass: Bool

        if fast > 0, smoothedSpeed >= fast {
            freq = maxFrequency
            shouldBypass = true // "filter basically off"
        } else {
            shouldBypass = false
            if medium > slow, smoothedSpeed <= medium {
                // slow → medium maps minFrequency → mediumFrequency
                let t = clamp01((smoothedSpeed - slow) / max(0.0001, (medium - slow)))
                freq = expInterpolate(from: minFrequency, to: mediumFrequency, t: t)
            } else if fast > medium {
                // medium → fast maps mediumFrequency → maxFrequency
                let t = clamp01((smoothedSpeed - medium) / max(0.0001, (fast - medium)))
                freq = expInterpolate(from: mediumFrequency, to: maxFrequency, t: t)
            } else {
                freq = expInterpolate(from: minFrequency, to: maxFrequency, t: clamp01(smoothedSpeed / max(0.0001, fast)))
            }
        }

        lowPassEQ.bands[0].bypass = shouldBypass
        lowPassEQ.bands[0].frequency = freq
    }

    private func expInterpolate(from a: Float, to b: Float, t: Float) -> Float {
        let safeA = max(1, a)
        let safeB = max(1, b)
        return safeA * pow(safeB / safeA, t)
    }

    private func clamp01(_ x: Float) -> Float {
        min(max(x, 0), 1)
    }

    // MARK: - Scatter effect

    /// Start the Shaperbox-style rapid volume gate.
    func startScatter() {
        guard !isScattering else { return }
        isScattering = true
        fireScatterBurst()
    }

    /// Stop the scatter gate and restore full volume.
    func stopScatter() {
        scatterTimer?.invalidate()
        scatterTimer = nil
        isScattering = false
        playerNode.volume = 1.0
    }

    private func fireScatterBurst() {
        guard isScattering else { return }
        scatterPhase.toggle()
        // Toggle volume between 0 and 1 at 8–16 Hz (62–125 ms intervals)
        playerNode.volume = scatterPhase ? 1.0 : 0.0
        let interval = Double.random(in: 0.0625...0.125)
        scatterTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.fireScatterBurst() }
        }
    }

    // MARK: - Placeholder effect controls (extend later)

    /// Reverb wet amount 0–100. Wired but dry by default.
    func setReverbWet(_ amount: Float) {
        reverbNode.wetDryMix = min(max(amount, 0), 100)
    }

    /// Delay wet amount 0–100. Wired but dry by default.
    func setDelayWet(_ amount: Float) {
        delayNode.wetDryMix = min(max(amount, 0), 100)
    }
}
