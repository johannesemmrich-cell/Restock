import XCTest
import SwiftData
@testable import Restock

/// Issue #98, Durchgang 8: Abhak-Warteschlange von Dynamic Island, Sperrbildschirm und Widget.
/// Spec: `docs/specs/ui-tests/test-98-durchgang-8-siri-widget.md`.
///
/// Geprüft wird die Logik hinter dem Abhaken (`CheckoffQueue`), die App und Widget teilen.
/// **Offene Grenzen:** Der Tipp auf Widget, Live Activity oder Insel und der Activity-Teil von
/// `CheckOffItemIntent.perform()` laufen im Simulator nicht und sind hier nicht geprüft; ebenso kein
/// Test auf einem Gerät des Users.
@MainActor
final class CheckoffQueueTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var suiteName = ""
    private var defaults: UserDefaults!
    private var stores: [Store] = []

    override func setUpWithError() throws {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
        suiteName = "UT-CheckoffQueue-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDown() {
        // Der Einkaufsweg liegt in der App-Gruppe unter der Laden-ID (Store.routeDefaults).
        stores.forEach { $0.removeRouteData() }
        defaults?.removePersistentDomain(forName: suiteName)
        XCTAssertTrue((UserDefaults(suiteName: suiteName)?.dictionaryRepresentation() ?? [:])
            .keys.filter { $0.hasPrefix("pendingCheckoff") }.isEmpty,
                      "tearDown hat Warteschlangen-Schlüssel stehen lassen")
        container = nil
        context = nil
    }

    // MARK: - Hilfen

    private func makeStore(_ name: String, items: [String]) -> Store {
        let store = Store(name: name, emoji: "🛒", colorHex: "#0050AA")
        context.insert(store)
        for itemName in items {
            context.insert(ShoppingItem(name: itemName, category: "Milch", store: store))
        }
        stores.append(store)
        return store
    }

    private func item(_ name: String, in store: Store) throws -> ShoppingItem {
        try XCTUnwrap(store.items?.first { $0.name == name })
    }

    private func purchaseRecords(named name: String) throws -> [PurchaseRecord] {
        try context.fetch(FetchDescriptor<PurchaseRecord>()).filter { $0.itemName == name }
    }

    // MARK: - Q1 Reihenfolge und Wirkung

    func testDrainCompletesExactlyQueuedItemsWithHistoryAndRoute() throws {
        let store = makeStore("UT-Laden-Q1", items: ["Milch", "Brot", "Käse"])
        let milch = try item("Milch", in: store)
        let kaese = try item("Käse", in: store)
        CheckoffQueue.enqueue(itemID: kaese.id, storeName: store.name, defaults: defaults)
        CheckoffQueue.enqueue(itemID: milch.id, storeName: store.name, defaults: defaults)

        let applied = CheckoffQueue.drain(for: store, defaults: defaults)

        XCTAssertEqual(applied, 2)
        XCTAssertTrue(milch.isCompleted)
        XCTAssertTrue(kaese.isCompleted)
        XCTAssertFalse(try item("Brot", in: store).isCompleted, "nicht gequeuter Artikel bleibt offen")
        XCTAssertEqual(try purchaseRecords(named: "Milch").count, 1)
        XCTAssertEqual(try purchaseRecords(named: "Käse").count, 1)
        XCTAssertEqual(try purchaseRecords(named: "Brot").count, 0)
        // Einkaufsweg: in Queue-Reihenfolge (Käse vor Milch) im laufenden Einkauf des Ladens.
        XCTAssertEqual(store.currentTrip.entries.map(\.key), ["käse", "milch"])
        XCTAssertTrue(store.currentTrip.entries.allSatisfy(\.batched))
        XCTAssertNil(defaults.stringArray(forKey: "pendingCheckoffIDs_\(store.name)"), "Queue ist danach leer")
    }

    // MARK: - Q2 Doppelt, erledigt, unbekannt

    func testDrainIgnoresDuplicateCompletedAndUnknownIDs() throws {
        let store = makeStore("UT-Laden-Q2", items: ["Milch", "Brot"])
        let milch = try item("Milch", in: store)
        let brot = try item("Brot", in: store)
        brot.markCompleted()
        CheckoffQueue.enqueue(itemID: milch.id, storeName: store.name, defaults: defaults)
        CheckoffQueue.enqueue(itemID: milch.id, storeName: store.name, defaults: defaults)
        CheckoffQueue.enqueue(itemID: brot.id, storeName: store.name, defaults: defaults)
        CheckoffQueue.enqueue(itemID: UUID(), storeName: store.name, defaults: defaults)

        let applied = CheckoffQueue.drain(for: store, defaults: defaults)

        XCTAssertEqual(applied, 1, "nur der eine echte Haken zählt")
        XCTAssertEqual(try purchaseRecords(named: "Milch").count, 1, "kein zweiter Kaufdatensatz")
        XCTAssertEqual(try purchaseRecords(named: "Brot").count, 1, "nur der eigene Haken von Hand")
    }

    // MARK: - Q3 Anzeige

    func testEffectivePendingMatchesStateAfterDrain() throws {
        let store = makeStore("UT-Laden-Q3", items: ["Milch", "Brot", "Käse"])
        let brot = try item("Brot", in: store)
        CheckoffQueue.enqueue(itemID: brot.id, storeName: store.name, defaults: defaults)

        let shownBefore = CheckoffQueue.effectivePending(for: store, defaults: defaults).map(\.name)
        XCTAssertFalse(shownBefore.contains("Brot"), "gequeuter Artikel ist aus der Anzeige herausgerechnet")
        XCTAssertEqual(shownBefore.count, 2)

        CheckoffQueue.drain(for: store, defaults: defaults)

        XCTAssertEqual(Set(store.pendingItems.map(\.name)), Set(shownBefore))
        XCTAssertEqual(CheckoffQueue.effectivePending(for: store, defaults: defaults).map(\.name), store.pendingItems.map(\.name))
    }

    // MARK: - Q4 Legacy-Zähler

    func testLegacyCounterIsRespectedAndCleared() throws {
        let store = makeStore("UT-Laden-Q4", items: ["Milch", "Brot", "Käse"])
        defaults.set(2, forKey: "pendingCheckoffs_\(store.name)")
        let expectedStay = Array(store.pendingItems.dropFirst(2)).map(\.name)

        XCTAssertEqual(CheckoffQueue.effectivePending(for: store, defaults: defaults).map(\.name), expectedStay)
        let applied = CheckoffQueue.drain(for: store, defaults: defaults)

        XCTAssertEqual(applied, 2)
        XCTAssertEqual(store.pendingItems.map(\.name), expectedStay)
        XCTAssertEqual(defaults.integer(forKey: "pendingCheckoffs_\(store.name)"), 0)
    }

    // MARK: - Q5 Läden getrennt

    func testQueueIsSeparatePerStore() throws {
        let a = makeStore("UT-Laden-Q5a", items: ["Milch"])
        let b = makeStore("UT-Laden-Q5b", items: ["Milch"])
        CheckoffQueue.enqueue(itemID: try item("Milch", in: a).id, storeName: a.name, defaults: defaults)

        XCTAssertEqual(CheckoffQueue.drain(for: b, defaults: defaults), 0)
        XCTAssertFalse(try item("Milch", in: b).isCompleted)
        XCTAssertEqual(CheckoffQueue.drain(for: a, defaults: defaults), 1)
        XCTAssertTrue(try item("Milch", in: a).isCompleted)
    }

    // MARK: - Q6 enqueue

    func testEnqueueAppendsOnlyOwnKey() {
        let first = UUID(), second = UUID()
        CheckoffQueue.enqueue(itemID: first, storeName: "UT-Laden-Q6", defaults: defaults)
        CheckoffQueue.enqueue(itemID: second, storeName: "UT-Laden-Q6", defaults: defaults)

        XCTAssertEqual(defaults.stringArray(forKey: "pendingCheckoffIDs_UT-Laden-Q6"), [first.uuidString, second.uuidString])
        let keys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("pendingCheckoff") }
        XCTAssertEqual(keys, ["pendingCheckoffIDs_UT-Laden-Q6"])
    }
}
