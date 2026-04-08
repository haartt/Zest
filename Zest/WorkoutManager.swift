import SwiftUI
import Combine
internal import CoreData

@MainActor
final class WorkoutManager: ObservableObject {

    // MARK: - Published

    @Published var isSessionActive = false
    @Published var elapsedSeconds: Int = 0
    @Published var speed: Float = 0
    @Published var scatterCount: Int = 0

    // MARK: - Sub-managers

    let audioEngine     = AudioEngine()
    let motionManager   = MotionManager()
    let locationManager = LocationManager()

    // MARK: - Track selection

    var selectedTrackURL: URL?
    var selectedGenre: String = ""

    // MARK: - Private

    private var timer: AnyCancellable?
    private var motionCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private var sessionStartDate: Date?

    // MARK: - Session control

    func start() {
        guard let url = selectedTrackURL else { return }
        guard url.isFileURL else {
            print("[WorkoutManager] Selected track is not a file URL: \(url)")
            return
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("[WorkoutManager] Track file missing at path: \(url.path)")
            return
        }

        audioEngine.load(url: url)
        audioEngine.play()

        motionManager.start()
        locationManager.start()

        isSessionActive  = true
        elapsedSeconds   = 0
        scatterCount     = 0
        sessionStartDate = Date()

        // 1-second heartbeat
        timer?.cancel()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.elapsedSeconds += 1
                if self.elapsedSeconds % 5 == 0 {
                    NotificationManager.shared.updateWorkoutNotification(
                        trackName: self.audioEngine.currentTrackName,
                        elapsed: self.elapsedSeconds,
                        speed: self.speed,
                        scatterCount: self.scatterCount
                    )
                }
            }

        // GPS speed → audio filter + motion deceleration detector
        locationManager.$speed
            .receive(on: RunLoop.main)
            .sink { [weak self] (newSpeed: Double) in
                guard let self else { return }
                self.speed = Float(newSpeed)
                self.audioEngine.updateSpeed(self.speed)
                self.motionManager.updateSpeed(newSpeed)
            }
            .store(in: &cancellables)

        // isScatterTriggered: rising edge (false→true) starts scatter,
        // falling edge (true→false) stops it and increments the counter.
        motionCancellable = motionManager.$isScatterTriggered
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] triggered in
                guard let self else { return }
                if triggered {
                    self.audioEngine.startScatter()
                    self.scatterCount += 1
                } else {
                    self.audioEngine.stopScatter()
                }
            }

        NotificationManager.shared.scheduleWorkoutNotification(
            trackName: audioEngine.currentTrackName,
            elapsed: elapsedSeconds,
            speed: speed,
            scatterCount: scatterCount
        )
    }

    func stop(context: NSManagedObjectContext) {
        audioEngine.stop()
        motionManager.stop()
        locationManager.stop()

        timer?.cancel();             timer = nil
        motionCancellable?.cancel(); motionCancellable = nil
        cancellables.removeAll()

        isSessionActive = false

        if let startDate = sessionStartDate, elapsedSeconds > 0 {
            PersistenceController.shared.saveSession(
                date: startDate,
                duration: elapsedSeconds,
                trackName: audioEngine.currentTrackName,
                genre: selectedGenre,
                context: context
            )
        }

        NotificationManager.shared.cancelWorkoutNotification()
        sessionStartDate = nil
    }
}
