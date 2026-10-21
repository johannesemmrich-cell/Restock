import SwiftData
import UserNotifications
import XCTest
@testable import Restock

/// Issue #98, Durchgang 7 (Punkt 5): die Kette Kaufhistorie → Muster → Kandidaten → Planer →
/// Mitteilungszentrale → Protokoll → Ledger über die echten Funktionen
/// (`ReplenishmentBackgroundRefresh.run`, `scheduleReplenishmentDigests`, `cancelAll`) mit echtem
/// SwiftData-Container. Ersetzt wird nur die Mitteilungszentrale (`DigestNotificationCenter`).
///
/// Offene Grenzen (gelten für jede Zusage dieser Klasse): geprüft wird, was in der Zentrale
/// *angemeldet* ist — nicht die echte Zustellung um 9:00, nicht der vom System gestartete
/// Hintergrundlauf (`BGAppRefreshTask`), nicht `BGTaskScheduler.submit` (scheitert im Simulator),
/// nicht der Systemdialog der Erlaubnis (`simctl privacy` kennt ihn nicht). Es läuft nichts auf
/// einem Gerät des Users.
///
/// Feste Daten im September 2026 (keine Zeitumstellung) mit `Calendar.current`, wie der Planer.
@MainActor
final class NotificationDigestChainTests: XCTestCase {

    private let calendar = Calendar.current
    private var center: FakeDigestCenter!

    /// Alle `UserDefaults.standard`-Schlüssel, die Kette und Hilfstypen berühren (im Code ermittelt).
    private static let touchedKeys = [
        "notifiedOverdueReplenishments", "scheduledReplenishmentDigests", "snoozedReplenishments",
        "blockedReplenishments", "dismissedReplenishments", "acceptedReplenishments",
        "replenishmentKeysByPurchaseDate", "replenishmentMetricsCounts", "replenishmentMetricsShown",
        "developerMode", "notificationsEnabled",
    ]

    override func setUp() {
        super.setUp()
        removeTouchedKeys()
        assertNoKeysLeft("setUp")
        UserDefaults.standard.set(true, forKey: "developerMode")
        UserDefaults.standard.set(true, forKey: "notificationsEnabled")
        center = FakeDigestCenter()
    }

    override func tearDown() {
        removeTouchedKeys()
        assertNoKeysLeft("tearDown")
        center = nil
        super.tearDown()
    }

    // MARK: - D1 Kette

    func testPurchaseHistoryBecomesOneDigestAtNine() async throws {
        let container = try makeContainer(items: ["Milch"])

        await ReplenishmentBackgroundRefresh.run(container: container, now: date(9, 21, hour: 8), center: center)

        let digests = center.digestRequests
        XCTAssertEqual(digests.map(\.identifier), ["replenish-digest-2026-9-22"])
        let request = try XCTUnwrap(digests.first)
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(trigger.dateComponents.day, 22)
        XCTAssertEqual(trigger.dateComponents.hour, 9)
        XCTAssertTrue(request.content.body.contains("Milch"), "Text nennt den Artikel: \(request.content.body)")
        XCTAssertEqual(request.content.userInfo["itemNames"] as? [String], ["Milch"])

        let planned = ReplenishmentDigestLog().planned()
        XCTAssertEqual(planned.map(\.deliveryDate), [date(9, 22, hour: 9)])
        XCTAssertEqual(planned.first?.itemNames, ["Milch"])
    }

    // MARK: - D2 Abgemeldet

    func testNothingIsPlannedWhenDeveloperModeIsOff() async throws {
        UserDefaults.standard.set(false, forKey: "developerMode")
        let container = try makeContainer(items: ["Milch"])

        await ReplenishmentBackgroundRefresh.run(container: container, now: date(9, 21, hour: 8), center: center)

        XCTAssertTrue(center.requests.isEmpty)
        XCTAssertTrue(ReplenishmentDigestLog().planned().isEmpty)
    }

    func testNothingIsPlannedWhenNotificationsAreOff() async throws {
        UserDefaults.standard.set(false, forKey: "notificationsEnabled")
        let container = try makeContainer(items: ["Milch"])

        await ReplenishmentBackgroundRefresh.run(container: container, now: date(9, 21, hour: 8), center: center)

        XCTAssertTrue(center.requests.isEmpty)
        XCTAssertTrue(ReplenishmentDigestLog().planned().isEmpty)
    }

    // MARK: - D3 Ersetzen

    func testSecondRunReplacesDigestAndKeepsForeignRequests() async throws {
        center.preload(identifier: "other-1")
        center.preload(identifier: "replenish-old")
        let container = try makeContainer(items: ["Milch"])

        await ReplenishmentBackgroundRefresh.run(container: container, now: date(9, 21, hour: 8), center: center)
        XCTAssertNil(center.requests["replenish-old"], "Alte Nachkauf-Anfrage wird entfernt.")
        XCTAssertNotNil(center.requests["other-1"], "Fremde Kennung bleibt stehen.")
        XCTAssertEqual(center.digestRequests.count, 1)

        for record in purchases("Butter") { container.mainContext.insert(record) }
        await ReplenishmentBackgroundRefresh.run(container: container, now: date(9, 21, hour: 8), center: center)

        XCTAssertEqual(center.digestRequests.map(\.identifier), ["replenish-digest-2026-9-22"], "Keine Dopplung.")
        XCTAssertEqual(center.digestRequests.first?.content.userInfo["itemNames"] as? [String], ["Butter", "Milch"])
        XCTAssertNotNil(center.requests["other-1"])
    }

    // MARK: - D4 Ledger erst nach Zustellzeit

    func testItemEntersLedgerOnlyAfterDeliveryTime() async throws {
        let container = try makeContainer(items: ["Milch"])
        let pattern = try XCTUnwrap(HabitService.patterns(allRecords: try allRecords(container)).first)

        await ReplenishmentBackgroundRefresh.run(container: container, now: date(9, 21, hour: 8), center: center)
        XCTAssertTrue(OverdueNotificationLedger().shouldNotify(pattern), "Vor 9 Uhr des Zustelltags noch nicht gemeldet.")

        await ReplenishmentBackgroundRefresh.run(container: container, now: date(9, 22, hour: 10), center: center)
        XCTAssertFalse(OverdueNotificationLedger().shouldNotify(pattern), "Nach der Zustellzeit gemeldet.")
        XCTAssertTrue(center.digestRequests.isEmpty, "Im selben Kaufzyklus keine neue Anfrage.")
    }

    // MARK: - D5 Ohne Erlaubnis (Produktfix)

    func testNothingIsPlannedOrLoggedWithoutPermissionAndItemStaysNotifiable() async throws {
        let container = try makeContainer(items: ["Milch"])
        let pattern = try XCTUnwrap(HabitService.patterns(allRecords: try allRecords(container)).first)

        for status in [UNAuthorizationStatus.notDetermined, .denied] {
            center.status = status
            await ReplenishmentBackgroundRefresh.run(container: container, now: date(9, 21, hour: 8), center: center)
            XCTAssertTrue(center.requests.isEmpty, "Status \(status.rawValue): nichts in der Zentrale.")
            XCTAssertTrue(
                ReplenishmentDigestLog().planned().isEmpty,
                "Status \(status.rawValue): nichts im Protokoll."
            )

            await ReplenishmentBackgroundRefresh.run(container: container, now: date(9, 22, hour: 10), center: center)
            XCTAssertTrue(
                OverdueNotificationLedger().shouldNotify(pattern),
                "Status \(status.rawValue): kein Ledger-Eintrag auch nach der Zustellzeit."
            )
        }

        center.status = .authorized
        await ReplenishmentBackgroundRefresh.run(container: container, now: date(9, 22, hour: 10), center: center)
        XCTAssertEqual(center.digestRequests.map(\.identifier), ["replenish-digest-2026-9-23"], "Nach Erlaubnis geplant.")
    }

    func testProvisionalPermissionPlansLikeAuthorized() async throws {
        center.status = .provisional
        let container = try makeContainer(items: ["Milch"])

        await ReplenishmentBackgroundRefresh.run(container: container, now: date(9, 21, hour: 8), center: center)

        XCTAssertEqual(center.digestRequests.count, 1)
    }

    // MARK: - D6 cancelAll

    func testCancelAllClearsCenterAndLog() async throws {
        let container = try makeContainer(items: ["Milch"])
        await ReplenishmentBackgroundRefresh.run(container: container, now: date(9, 21, hour: 8), center: center)
        XCTAssertEqual(center.digestRequests.count, 1, "Setup: Sammelnachricht geplant.")
        XCTAssertFalse(ReplenishmentDigestLog().planned().isEmpty, "Setup: Protokoll gefüllt.")

        NotificationService.shared.cancelAll(center: center)

        XCTAssertTrue(center.requests.isEmpty)
        XCTAssertTrue(ReplenishmentDigestLog().planned().isEmpty)
    }

    // MARK: - Hilfen

    private func removeTouchedKeys() {
        for key in Self.touchedKeys { UserDefaults.standard.removeObject(forKey: key) }
    }

    private func assertNoKeysLeft(_ phase: String) {
        for key in Self.touchedKeys {
            XCTAssertNil(UserDefaults.standard.object(forKey: key), "\(phase): Schlüssel \(key) übrig.")
        }
    }

    private func date(_ month: Int, _ day: Int, hour: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    /// Drei Käufe im Abstand von 10 Tagen (23.08., 02.09., 12.09.) → nächster Kauf am 22.09.
    private func purchases(_ name: String) -> [PurchaseRecord] {
        [date(8, 23), date(9, 2), date(9, 12)].map { day in
            let record = PurchaseRecord(itemName: name, storeName: "Lidl")
            record.date = day
            return record
        }
    }

    private func makeContainer(items: [String]) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let container = try ModelContainer(
            for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        for name in items {
            for record in purchases(name) { container.mainContext.insert(record) }
        }
        try container.mainContext.save()
        return container
    }

    private func allRecords(_ container: ModelContainer) throws -> [PurchaseRecord] {
        try container.mainContext.fetch(FetchDescriptor<PurchaseRecord>())
    }
}

/// Fake-Zentrale: speichert Anfragen nach Kennung, Erlaubnis-Status einstellbar.
private final class FakeDigestCenter: DigestNotificationCenter {
    var status: UNAuthorizationStatus = .authorized
    private(set) var requests: [String: UNNotificationRequest] = [:]

    var digestRequests: [UNNotificationRequest] {
        requests.values.filter { $0.identifier.hasPrefix("replenish-digest-") }
            .sorted { $0.identifier < $1.identifier }
    }

    func preload(identifier: String) {
        requests[identifier] = UNNotificationRequest(
            identifier: identifier, content: UNMutableNotificationContent(), trigger: nil
        )
    }

    func authorizationStatus() async -> UNAuthorizationStatus { status }
    func pendingIdentifiers() async -> [String] { Array(requests.keys) }
    func remove(identifiers: [String]) { identifiers.forEach { requests[$0] = nil } }
    func add(_ request: UNNotificationRequest) async throws { requests[request.identifier] = request }
    func removeAll() { requests.removeAll() }
}
