import Foundation

enum ZestSettings {
    enum Keys {
        static let slowPaceSecondsPerKm = "zest.pace.slow.secPerKm"
        static let mediumPaceSecondsPerKm = "zest.pace.medium.secPerKm"
        static let fastPaceSecondsPerKm = "zest.pace.fast.secPerKm"
    }

    enum Defaults {
        // 7:00 /km, 5:30 /km, 4:30 /km
        static let slowPaceSecondsPerKm: Double = 7 * 60
        static let mediumPaceSecondsPerKm: Double = 5.5 * 60
        static let fastPaceSecondsPerKm: Double = 4.5 * 60
    }

    static func paceSecondsPerKm(key: String, defaultValue: Double) -> Double {
        let v = UserDefaults.standard.double(forKey: key)
        return v > 0 ? v : defaultValue
    }

    /// Converts pace (sec/km) to speed (m/s).
    static func speedMetersPerSecond(fromPaceSecondsPerKm pace: Double) -> Float {
        guard pace > 0 else { return 0 }
        return Float(1000.0 / pace)
    }

    /// Ensures slow <= medium <= fast in *speed* space by sorting.
    static func orderedSpeedThresholds() -> (slow: Float, medium: Float, fast: Float) {
        let slowPace = paceSecondsPerKm(
            key: Keys.slowPaceSecondsPerKm,
            defaultValue: Defaults.slowPaceSecondsPerKm
        )
        let mediumPace = paceSecondsPerKm(
            key: Keys.mediumPaceSecondsPerKm,
            defaultValue: Defaults.mediumPaceSecondsPerKm
        )
        let fastPace = paceSecondsPerKm(
            key: Keys.fastPaceSecondsPerKm,
            defaultValue: Defaults.fastPaceSecondsPerKm
        )

        let speeds = [
            speedMetersPerSecond(fromPaceSecondsPerKm: slowPace),
            speedMetersPerSecond(fromPaceSecondsPerKm: mediumPace),
            speedMetersPerSecond(fromPaceSecondsPerKm: fastPace),
        ].sorted()

        return (slow: speeds[0], medium: speeds[1], fast: speeds[2])
    }
}

