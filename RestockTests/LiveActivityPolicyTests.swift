import ActivityKit
import XCTest
@testable import Restock

/// Wann die Live Activity läuft (PO 2026-10-22): Start erst beim ersten Abhaken, bleibt beim
/// Verlassen der Liste und der App, endet bei „alles erledigt“ oder nach 30 Minuten ohne Haken.
/// Vorher startete jedes Öffnen einer Liste mit offenen Artikeln eine Anzeige — auch beim Planen
/// zu Hause. P1–P12 prüfen die reine Regel `LiveActivityPolicy`, I1–I3 die Verdrahtung in
/// `LiveActivityService` mit echtem ActivityKit im Simulator (wie `LiveActivityServiceReattachTests`).
final class LiveActivityPolicyTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func action(_ event: LiveActivityPolicy.Event, hasActivity: Bool, pending: Int = 3,
                        lastCheckOffMinutesAgo: Double?) -> LiveActivityPolicy.Action {
        LiveActivityPolicy.action(
            for: event,
            hasActivity: hasActivity,
            pendingCount: pending,
            lastCheckOff: lastCheckOffMinutesAgo.map { now.addingTimeInterval(-$0 * 60) },
            now: now
        )
    }

    // MARK: - Regel

    /// P1: Liste zu Hause öffnen (kein Haken) startet nichts — der gemeldete Fall.
    func testP1_openingListWithoutCheckOffStartsNothing() {
        XCTAssertEqual(action(.listOpened, hasActivity: false, lastCheckOffMinutesAgo: nil), .none)
    }

    /// P2: Auch ein alter Einkauf (vor 2 Stunden) lässt das Öffnen nichts starten.
    func testP2_openingListAfterOldTripStartsNothing() {
        XCTAssertEqual(action(.listOpened, hasActivity: false, lastCheckOffMinutesAgo: 120), .none)
    }

    /// P3: Erster Haken mit weiteren offenen Artikeln startet die Anzeige.
    func testP3_firstCheckOffStarts() {
        XCTAssertEqual(action(.checkedOff, hasActivity: false, lastCheckOffMinutesAgo: 0), .startOrUpdate)
    }

    /// P4: Letzter Haken beendet eine laufende Anzeige.
    func testP4_lastCheckOffEnds() {
        XCTAssertEqual(action(.checkedOff, hasActivity: true, pending: 0, lastCheckOffMinutesAgo: 0), .end)
    }

    /// P5: Einziger Artikel abgehakt, nichts lief: keine Anzeige für eine leere Liste.
    func testP5_checkingOffOnlyItemStartsNothing() {
        XCTAssertEqual(action(.checkedOff, hasActivity: false, pending: 0, lastCheckOffMinutesAgo: 0), .none)
    }

    /// P6: Liste im laufenden Einkauf wieder öffnen aktualisiert die Anzeige.
    func testP6_reopeningDuringTripUpdates() {
        XCTAssertEqual(action(.listOpened, hasActivity: true, lastCheckOffMinutesAgo: 5), .startOrUpdate)
    }

    /// P7: Nach mehr als 30 Minuten ohne Haken endet sie beim Öffnen der Liste und beim
    /// Zurückkehren in die App; genau 30 Minuten zählen noch zum Einkauf.
    func testP7_idleTripEndsOnOpenAndActivation() {
        XCTAssertEqual(action(.listOpened, hasActivity: true, lastCheckOffMinutesAgo: 31), .end)
        XCTAssertEqual(action(.appActivated, hasActivity: true, lastCheckOffMinutesAgo: 31), .end)
        XCTAssertEqual(action(.appActivated, hasActivity: true, lastCheckOffMinutesAgo: 30), .startOrUpdate)
        XCTAssertEqual(action(.appActivated, hasActivity: true, lastCheckOffMinutesAgo: nil), .end)
    }

    /// P8: Zurück in die App ohne laufende Anzeige startet nichts.
    func testP8_activationWithoutActivityStartsNothing() {
        XCTAssertEqual(action(.appActivated, hasActivity: false, lastCheckOffMinutesAgo: 1), .none)
    }

    /// P9: Haken zurücknehmen nach „alles erledigt“ im laufenden Einkauf zeigt sie wieder,
    /// ohne laufenden Einkauf nicht.
    func testP9_uncheckRestartsOnlyDuringTrip() {
        XCTAssertEqual(action(.unchecked, hasActivity: false, pending: 1, lastCheckOffMinutesAgo: 1), .startOrUpdate)
        XCTAssertEqual(action(.unchecked, hasActivity: false, pending: 1, lastCheckOffMinutesAgo: nil), .none)
        XCTAssertEqual(action(.unchecked, hasActivity: false, pending: 1, lastCheckOffMinutesAgo: 45), .none)
    }

    /// P10: Artikel hinzufügen (zu Hause, Sync) startet nichts; im Einkauf wird aktualisiert.
    func testP10_itemsChangedNeverStarts() {
        XCTAssertEqual(action(.itemsChanged, hasActivity: false, lastCheckOffMinutesAgo: nil), .none)
        XCTAssertEqual(action(.itemsChanged, hasActivity: false, lastCheckOffMinutesAgo: 1), .none)
        XCTAssertEqual(action(.itemsChanged, hasActivity: true, lastCheckOffMinutesAgo: 1), .startOrUpdate)
        XCTAssertEqual(action(.itemsChanged, hasActivity: true, pending: 0, lastCheckOffMinutesAgo: 1), .end)
    }

    /// P11: Veraltet-Zeitpunkt = letzter Haken + 30 Minuten (ohne Haken: ab jetzt).
    func testP11_staleDateFollowsLastCheckOff() {
        let last = now.addingTimeInterval(-10 * 60)
        XCTAssertEqual(LiveActivityPolicy.staleDate(lastCheckOff: last, now: now), last.addingTimeInterval(30 * 60))
        XCTAssertEqual(LiveActivityPolicy.staleDate(lastCheckOff: nil, now: now), now.addingTimeInterval(30 * 60))
    }

    /// P12: Leerlauf-Erkennung beim Zurückkehren in die App.
    func testP12_isIdle() {
        XCTAssertTrue(LiveActivityPolicy.isIdle(staleDate: now.addingTimeInterval(-1), now: now))
        XCTAssertTrue(LiveActivityPolicy.isIdle(staleDate: now, now: now))
        XCTAssertFalse(LiveActivityPolicy.isIdle(staleDate: now.addingTimeInterval(60), now: now))
        XCTAssertFalse(LiveActivityPolicy.isIdle(staleDate: nil, now: now))
    }

    // MARK: - Verdrahtung mit echtem ActivityKit

    private var stores: [Store] = []

    override func tearDown() async throws {
        for activity in Activity<ShoppingActivityAttributes>.activities
            where activity.attributes.storeName.hasPrefix("PolicyTest-") {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        await MainActor.run { stores.forEach { $0.removeRouteData() } }
        stores = []
    }

    @MainActor
    private func makeStore() -> Store {
        let store = Store(name: "PolicyTest-\(UUID().uuidString.prefix(8))", emoji: "🛒", colorHex: "#0050AA")
        store.items = [ShoppingItem(name: "Milch", store: store), ShoppingItem(name: "Brot", store: store),
                       ShoppingItem(name: "Käse", store: store)]
        stores.append(store)
        return store
    }

    private func activeCount(_ store: Store) -> Int {
        Activity<ShoppingActivityAttributes>.activities
            .filter { $0.attributes.storeName == store.name && $0.activityState == .active }
            .count
    }

    @MainActor
    private func checkOffFirst(_ store: Store) {
        guard let item = store.pendingItems.first else { return }
        item.isCompleted = true
        store.recordCheckOff(item)
        LiveActivityService.shared.handle(.checkedOff, for: store)
    }

    /// I1: Öffnen startet nichts, der erste Haken startet genau eine Anzeige.
    func testI1_openDoesNotStartButFirstCheckOffDoes() async throws {
        try XCTSkipUnless(ActivityAuthorizationInfo().areActivitiesEnabled, "Live Activities im Testprozess deaktiviert")
        let store = await makeStore()

        await LiveActivityService.shared.handle(.listOpened, for: store)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(activeCount(store), 0, "Öffnen der Liste darf keine Live Activity starten")

        await checkOffFirst(store)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(activeCount(store), 1, "Der erste Haken muss genau eine Live Activity starten")
    }

    /// I2: Erneutes Öffnen im Einkauf hängt sich an, statt eine zweite zu starten; der letzte
    /// Haken beendet sie.
    func testI2_reopenKeepsOneAndLastCheckOffEnds() async throws {
        try XCTSkipUnless(ActivityAuthorizationInfo().areActivitiesEnabled, "Live Activities im Testprozess deaktiviert")
        let store = await makeStore()

        await checkOffFirst(store)
        try await Task.sleep(for: .milliseconds(300))
        await LiveActivityService.shared.handle(.listOpened, for: store)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(activeCount(store), 1)

        await checkOffFirst(store)
        await checkOffFirst(store)
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(activeCount(store), 0, "Nach dem letzten Haken darf keine Live Activity mehr aktiv sein")
    }

    /// I3: Ein Haken in einem zweiten Laden beendet die Anzeige des ersten.
    func testI3_checkOffInOtherStoreEndsFirst() async throws {
        try XCTSkipUnless(ActivityAuthorizationInfo().areActivitiesEnabled, "Live Activities im Testprozess deaktiviert")
        let first = await makeStore()
        let second = await makeStore()

        await checkOffFirst(first)
        try await Task.sleep(for: .milliseconds(300))
        await checkOffFirst(second)
        try await Task.sleep(for: .milliseconds(500))

        XCTAssertEqual(activeCount(first), 0, "Nur ein Einkauf zugleich")
        XCTAssertEqual(activeCount(second), 1)
    }
}
