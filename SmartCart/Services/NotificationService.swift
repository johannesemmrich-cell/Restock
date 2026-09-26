import UserNotifications
import Foundation

@MainActor
class NotificationService {
    static let shared = NotificationService()

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Reads the *actual* current authorization status without prompting — used to keep a
    /// settings toggle honest, since the user can revoke notification permission from the
    /// system Settings app at any time without the app ever finding out otherwise.
    func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    func scheduleReplenishment(patterns: [ConsumptionPattern]) async {
        let center = UNUserNotificationCenter.current()
        let overdueLedger = OverdueNotificationLedger()

        for pattern in patterns {
            let identifier = "replenish-\(pattern.itemName.lowercased().replacingOccurrences(of: " ", with: "-"))"

            guard pattern.daysUntilNeeded >= 0 else {
                // Overdue — fire immediately (or next reasonable time), but only once per item and
                // estimated date (Issue #30, A3). An already-notified item is skipped BEFORE the
                // pending request is removed: refreshDueSoon() often runs several times within
                // the 5-second trigger delay, and removing it there would swallow the one push.
                guard overdueLedger.shouldNotify(pattern) else { continue }
                await center.removePendingNotificationRequests(withIdentifiers: [identifier])
                await scheduleImmediate(pattern: pattern, identifier: identifier)
                overdueLedger.markNotified(pattern)
                continue
            }

            await center.removePendingNotificationRequests(withIdentifiers: [identifier])

            let content = UNMutableNotificationContent()
            content.title = String(localized: "notification.replenish.title")
            content.body = String(format: String(localized: "notification.replenish.body"), pattern.itemName)
            content.sound = .default
            content.userInfo = ["itemName": pattern.itemName]

            var components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: pattern.estimatedNextPurchaseDate
            )
            components.hour = 9
            components.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            try? await center.add(request)
        }
    }

    private func scheduleImmediate(pattern: ConsumptionPattern, identifier: String) async {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.overdue.title")
        content.body = String(format: String(localized: "notification.overdue.body"), pattern.itemName)
        content.sound = .default
        content.userInfo = ["itemName": pattern.itemName]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Cancels the pending replenishment reminder for one item (e.g. after the user dismissed
    /// its suggestion in the banner) without touching other scheduled reminders.
    func cancelReplenishment(itemName: String) {
        let identifier = "replenish-\(itemName.lowercased().replacingOccurrences(of: " ", with: "-"))"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
