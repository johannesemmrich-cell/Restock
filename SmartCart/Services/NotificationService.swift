import UserNotifications
import Foundation

/// Naht vor der Mitteilungszentrale (Issue #98, Durchgang 7): `UNUserNotificationCenter` im
/// Produkt, eine Fake-Zentrale im Test — die Systemerlaubnis lässt sich per `simctl` nicht setzen.
protocol DigestNotificationCenter {
    func authorizationStatus() async -> UNAuthorizationStatus
    func pendingIdentifiers() async -> [String]
    func remove(identifiers: [String])
    func add(_ request: UNNotificationRequest) async throws
    func removeAll()
}

extension UNUserNotificationCenter: DigestNotificationCenter {
    func authorizationStatus() async -> UNAuthorizationStatus {
        await notificationSettings().authorizationStatus
    }

    func pendingIdentifiers() async -> [String] {
        await pendingNotificationRequests().map(\.identifier)
    }

    func remove(identifiers: [String]) {
        removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func removeAll() {
        removeAllPendingNotificationRequests()
    }
}

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
    func scheduleReplenishmentDigests(
        candidates: [ConsumptionPattern],
        now: Date = Date(),
        center: DigestNotificationCenter = UNUserNotificationCenter.current()
    ) async {
        let previous = digestScheduling
        let task = Task {
            await previous?.value
            await self.performDigestScheduling(candidates: candidates, now: now, center: center)
        }
        digestScheduling = task
        await task.value
    }

    private func performDigestScheduling(
        candidates: [ConsumptionPattern],
        now: Date,
        center: DigestNotificationCenter
    ) async {
        // add wirft ohne Erlaubnis keinen Fehler, die Mitteilung würde still verworfen und trotzdem
        // protokolliert. Deshalb vorher prüfen und ohne Erlaubnis nichts planen, entfernen oder protokollieren.
        let status = await center.authorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        let ledger = OverdueNotificationLedger()
        let log = ReplenishmentDigestLog()
        log.commitDelivered(now: now, to: ledger)
        let digests = ReplenishmentDigestPlanner.plan(candidates: candidates, ledger: ledger, now: now)

        let stale = await center.pendingIdentifiers()
            .filter { $0.hasPrefix(Self.replenishmentIdentifierPrefix) }
        center.remove(identifiers: stale)

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
            // Die Erlaubnis ist oben geprüft; schlägt add trotzdem fehl, gilt der Artikel nicht als gemeldet.
            if (try? await center.add(request)) != nil {
                scheduled.append(digest)
            }
        }
        log.replace(with: scheduled)
    }

    func cancelAll(center: DigestNotificationCenter = UNUserNotificationCenter.current()) {
        center.removeAll()
        ReplenishmentDigestLog().removeAll()
    }
}
