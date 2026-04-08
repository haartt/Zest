import UserNotifications

/// Manages the "workout active" local notification.
/// Note: iOS local notifications aren't true live-updating; we emulate it by
/// re-posting with the same identifier periodically.
final class NotificationManager {

    static let shared = NotificationManager()
    private init() {}

    private let activeNotificationID = "zest.workout.active"

    // MARK: - Permission

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if let error { print("[Notifications] Auth error: \(error)") }
        }
    }

    // MARK: - Session start

    /// Posts a notification immediately when the session begins.
    func scheduleWorkoutNotification(trackName: String, elapsed: Int, speed: Float, scatterCount: Int) {
        let content = UNMutableNotificationContent()
        content.title = titleString(elapsed: elapsed, speed: speed)
        content.body  = bodyString(trackName: trackName, scatterCount: scatterCount)
        content.sound = nil  // silent — we don't want to interrupt audio

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(
            identifier: activeNotificationID,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Re-posts the active notification with updated stats.
    func updateWorkoutNotification(trackName: String, elapsed: Int, speed: Float, scatterCount: Int) {
        cancelWorkoutNotification()

        let content = UNMutableNotificationContent()
        content.title = titleString(elapsed: elapsed, speed: speed)
        content.body  = bodyString(trackName: trackName, scatterCount: scatterCount)
        content.sound = nil

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(
            identifier: activeNotificationID,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Session end

    func cancelWorkoutNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [activeNotificationID])
        center.removeDeliveredNotifications(withIdentifiers: [activeNotificationID])
    }

    // MARK: - Formatting

    private func titleString(elapsed: Int, speed: Float) -> String {
        let timeString = formatElapsed(elapsed)
        let speedString = String(format: "%.1f m/s", speed)
        return "Zest — \(timeString)  •  \(speedString)"
    }

    private func bodyString(trackName: String, scatterCount: Int) -> String {
        "▶ \(trackName)\nScatter: \(scatterCount)"
    }

    private func formatElapsed(_ elapsed: Int) -> String {
        let h = elapsed / 3600
        let m = (elapsed % 3600) / 60
        let s = elapsed % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
