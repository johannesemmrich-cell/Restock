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

    /// Präfix aller Nachkauf-Nachrichten, auch der früheren pro Artikel (`replenish-<name>`).
    static let replenishmentIdentifierPrefix = "replenish-"

    private var digestScheduling: Task<Void, Never>?

    /// C3 (Issue #30): ersetzt alle geplanten Nachkauf-Nachrichten durch höchstens eine
    /// Sammelnachricht pro Tag (`ReplenishmentDigestPlanner`). Aufrufe laufen nacheinander:
    /// `refreshDueSoon()` feuert oft mehrmals kurz hintereinander, und zwei verschränkte Läufe
    /// könnten sonst Nachrichten des jeweils anderen stehen lassen.
    func scheduleReplenishmentDigests(candidates: [ConsumptionPattern], now: Date = Date()) async {
        let previous = digestScheduling
        let task = Task {
            await previous?.value
            await self.performDigestScheduling(candidates: candidates, now: now)
        }
        digestScheduling = task
        await task.value
    }

    private func performDigestScheduling(candidates: [ConsumptionPattern], now: Date) async {
        let center = UNUserNotificationCenter.current()
        let ledger = OverdueNotificationLedger()
        let log = ReplenishmentDigestLog()
        log.commitDelivered(now: now, to: ledger)
        let digests = ReplenishmentDigestPlanner.plan(candidates: candidates, ledger: ledger, now: now)

        let stale = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.replenishmentIdentifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: stale)

        var scheduled: [ReplenishmentDigest] = []
        for digest in digests {
            let content = UNMutableNotificationContent()
            content.title = digest.title
            content.body = digest.body
            content.sound = .default
            content.userInfo = ["itemNames": digest.itemNames]

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: digest.deliveryDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let identifier = Self.replenishmentIdentifierPrefix
                + "digest-\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            // Ohne Erlaubnis scheitert das — dann gilt der Artikel später auch nicht als gemeldet.
            if (try? await center.add(request)) != nil {
                scheduled.append(digest)
            }
        }
        log.replace(with: scheduled)
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        ReplenishmentDigestLog().removeAll()
    }
}
