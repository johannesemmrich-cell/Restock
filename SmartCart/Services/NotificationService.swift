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

    func scheduleReplenishment(patterns: [ConsumptionPattern]) async {
        let center = UNUserNotificationCenter.current()

        for pattern in patterns {
            let identifier = "replenish-\(pattern.itemName.lowercased().replacingOccurrences(of: " ", with: "-"))"
            await center.removePendingNotificationRequests(withIdentifiers: [identifier])

            guard pattern.daysUntilNeeded >= 0 else {
                // Overdue — fire immediately (or next reasonable time)
                await scheduleImmediate(pattern: pattern, identifier: identifier)
                continue
            }

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

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
