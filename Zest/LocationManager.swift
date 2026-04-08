import CoreLocation
import Combine

/// Wraps CLLocationManager and publishes real-time speed in m/s.
/// Accuracy is set to kCLLocationAccuracyBestForNavigation for the
/// lowest possible latency during running.
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    @Published var speed: Double = 0
    @Published var averageSpeed: Double = 0
    @Published var distance: Double = 0

    private var startDate: Date?

    // MARK: - Published

    @Published private(set) var speedMS: Double       = 0   // m/s  (raw GPS)
    @Published private(set) var speedKMH: Double      = 0   // km/h (display)
    @Published private(set) var speedMPH: Double      = 0   // mph  (display)
    @Published private(set) var isAuthorized: Bool    = false
    @Published private(set) var isReceivingGPS: Bool  = false

    // MARK: - Private

    private let manager = CLLocationManager()

    /// Exponential moving-average α — lower = smoother, higher = more reactive
    /// 0.25 works well at running pace (updates ~1/s from GPS)
    private let alpha: Double = 0.25
    private var smoothedSpeed: Double = 0

    // MARK: - Init

    override init() {
        super.init()
        manager.delegate                 = self
        manager.desiredAccuracy          = kCLLocationAccuracyBestForNavigation
        manager.activityType             = .fitness
        manager.distanceFilter           = 1   // metres — avoids spamming at rest
        manager.pausesLocationUpdatesAutomatically = false
    }

    // MARK: - Control

    func start() {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            break
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
        DispatchQueue.main.async {
            self.speedMS        = 0
            self.speedKMH       = 0
            self.speedMPH       = 0
            self.isReceivingGPS = false
            self.smoothedSpeed  = 0
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // GPS speed can be -1 when unavailable; clamp to 0
        let raw = max(location.speed, 0)

        // Exponential moving average to smooth GPS jitter
        smoothedSpeed = alpha * raw + (1 - alpha) * smoothedSpeed

        DispatchQueue.main.async {
            self.speedMS        = self.smoothedSpeed
            self.speedKMH       = self.smoothedSpeed * 3.6
            self.speedMPH       = self.smoothedSpeed * 2.23694
            self.isReceivingGPS = location.speed >= 0
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.isAuthorized = [.authorizedWhenInUse, .authorizedAlways]
                .contains(manager.authorizationStatus)
        }
        if isAuthorized { manager.startUpdatingLocation() }
    }

    func locationManager(_ manager: CLLocationManager,
                         didFailWithError error: Error) {
        print("[LocationManager] Error: \(error.localizedDescription)")
    }
}
