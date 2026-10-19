import XCTest
import SwiftData
@testable import Restock

/// Issue #156, Teil B1/B2: Doppel-Läden erkennen (nur anzeigen), Gewinnerregel kleinste UUID, nur fehlende
/// Presets einfügen, Beitritt mit vorhandener `shareID` wiederverwenden.
/// Spec: `docs/specs/services/icloud-abgleich-sichtbar.md` (T9–T18; AC-8 bis AC-10, AC-12, AC-17, AC-18).
///
/// Die Einfügelogik läuft gegen einen In-Memory-Container ohne CloudKit (Muster `SharedStoreMergeTests`).
/// `Store.shareID` liegt in `UserDefaults.standard` (`shareID_<id>`); jeder Test, der sie setzt, räumt sie
/// im `tearDown()` wieder ab. Offene Grenze: Gleichzeitigkeit auf zwei Geräten ist nicht geprüft.
@MainActor
final class StoreDuplicateFinderTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var sharedStores: [Store] = []

    override func setUpWithError() throws {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
    }

    override func tearDown() {
        for store in sharedStores { store.shareID = nil }
        sharedStores = []
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Hilfen

    private func snap(_ name: String, _ country: String = "DE", custom: Bool = false,
                      shareID: String? = nil, id: UUID = UUID()) -> StoreSnapshot {
        StoreSnapshot(id: id, name: name, countryCode: country, isCustom: custom,
                      shareID: shareID, isActive: true, itemCount: 0)
    }

    private func uuid(_ text: String) -> UUID { UUID(uuidString: text)! }

    private func allStores() throws -> [Store] {
        try context.fetch(FetchDescriptor<Store>())
    }

    // MARK: - T9, T10, T12 (AC-8)

    func testClassesOneToThree() {
        // GIVEN gleiche shareID (T9) WHEN groups THEN eine Gruppe der Klasse 1
        let shared = StoreDuplicateFinder.groups([snap("Lidl", shareID: "ABC123"), snap("Lidl Markt", shareID: "ABC123")])
        XCTAssertEqual(shared.count, 1)
        XCTAssertEqual(shared.first?.kind, .sameShareID)
        XCTAssertEqual(shared.first?.stores.count, 2)

        // GIVEN „Lidl“ und „lidl “ als Preset DE (T10) WHEN groups THEN eine Gruppe der Klasse 2
        let caseAndSpace = StoreDuplicateFinder.groups([snap("Lidl"), snap("lidl ")])
        XCTAssertEqual(caseAndSpace.count, 1)
        XCTAssertEqual(caseAndSpace.first?.kind, .samePreset)
        XCTAssertEqual(caseAndSpace.first?.reportOnly, false)

        // GIVEN „Bäckerei“ und „Backerei“ (T10) WHEN groups THEN diakritikfrei eine Gruppe
        let diacritics = StoreDuplicateFinder.groups([snap("Bäckerei"), snap("Backerei")])
        XCTAssertEqual(diacritics.count, 1)
        XCTAssertEqual(diacritics.first?.kind, .samePreset)

        // GIVEN zwei eigene Läden gleichen Namens (T12) WHEN groups THEN Klasse 3, nur melden
        let custom = StoreDuplicateFinder.groups([snap("Wochenmarkt", custom: true), snap("wochenmarkt", custom: true)])
        XCTAssertEqual(custom.count, 1)
        XCTAssertEqual(custom.first?.kind, .sameCustomName)
        XCTAssertEqual(custom.first?.reportOnly, true)
    }

    // MARK: - T11, T13 (AC-9)

    func testNoFalsePositives() {
        // GIVEN gleicher Name in DE und AT WHEN groups THEN keine Gruppe
        XCTAssertEqual(StoreDuplicateFinder.groups([snap("Lidl", "DE"), snap("Lidl", "AT")]).count, 0)

        // GIVEN ein geteilter „Lidl“ neben dem Preset „Lidl“ WHEN groups THEN keine Gruppe
        XCTAssertEqual(StoreDuplicateFinder.groups([snap("Lidl", shareID: "XYZ789"), snap("Lidl")]).count, 0)

        // GIVEN eigener Laden „Lidl“ neben Preset „Lidl“ WHEN groups THEN keine Gruppe
        XCTAssertEqual(StoreDuplicateFinder.groups([snap("Lidl", custom: true), snap("Lidl")]).count, 0)

        // GIVEN die 17 DE-Presets (T13) WHEN groups THEN keine Gruppe
        let presets = Store.presets(for: "DE").map { StoreSnapshot($0) }
        XCTAssertEqual(presets.count, 17)
        XCTAssertEqual(StoreDuplicateFinder.groups(presets).count, 0,
                       "Die 17 DE-Presets dürfen kein Doppel ergeben")
    }

    // MARK: - T14 (AC-10)

    func testWinnerIsSmallestUUIDRegardlessOfOrder() {
        // GIVEN eine Gruppe aus drei Läden mit fester UUID
        let small = snap("Lidl", id: uuid("10000000-0000-0000-0000-000000000000"))
        let middle = snap("Lidl", id: uuid("20000000-0000-0000-0000-000000000000"))
        let large = snap("lidl", id: uuid("A0000000-0000-0000-0000-000000000000"))

        // WHEN winner in drei Reihenfolgen THEN immer die kleinste UUID
        for order in [[small, middle, large], [large, small, middle], [middle, large, small]] {
            XCTAssertEqual(StoreDuplicateFinder.winner(of: order)?.id, small.id, "Reihenfolge: \(order.map(\.id))")
        }
        XCTAssertNil(StoreDuplicateFinder.winner(of: []))
    }

    // MARK: - T15 (AC-17)

    func testOnboardingInsertsOnlyMissingPresets() throws {
        // GIVEN 17 vorhandene DE-Läden, Edeka und Rewe inaktiv
        for store in Store.presets(for: "DE") {
            store.isActive = !["Edeka", "Rewe"].contains(store.name)
            context.insert(store)
        }
        try context.save()

        // WHEN die Einfügelogik von finishOnboarding mit Auswahl „Rewe“ und „Lidl“ läuft
        let chosen = Store.presets(for: "DE")
        for store in chosen { store.isActive = ["Rewe", "Lidl"].contains(store.name) }
        let inserted = try StoreSeeding.insertMissingPresets(chosen, into: context)

        // THEN bleiben es 17 Läden, vorhandene isActive unverändert
        let stores = try allStores()
        XCTAssertEqual(inserted, 0)
        XCTAssertEqual(stores.count, 17)
        XCTAssertEqual(stores.first { $0.name == "Rewe" }?.isActive, false, "Vorhandener Laden wurde verändert")
        XCTAssertEqual(stores.first { $0.name == "Edeka" }?.isActive, false)
        XCTAssertEqual(stores.first { $0.name == "Aldi" }?.isActive, true)
    }

    // MARK: - T16 (AC-17)

    func testSeedStoresInsertsOnlyMissingPresets() throws {
        // GIVEN 10 der 17 DE-Presets sind vorhanden
        let existing = Array(Store.presets(for: "DE").prefix(10))
        existing.forEach { context.insert($0) }
        try context.save()

        // WHEN missingPresets (rein) THEN fehlen genau 7
        let missing = StoreDuplicateFinder.missingPresets(Store.presets(for: "DE").map { StoreSnapshot($0) },
                                                          existing: existing.map { StoreSnapshot($0) })
        XCTAssertEqual(missing.count, 7)
        XCTAssertTrue(Set(missing.map(\.name)).isDisjoint(with: existing.map(\.name)))

        // WHEN die Einfügelogik von seedStores läuft THEN werden genau 7 eingefügt, ohne Doppel
        let inserted = try StoreSeeding.insertMissingPresets(Store.presets(for: "DE"), into: context)
        let stores = try allStores()
        XCTAssertEqual(inserted, 7)
        XCTAssertEqual(stores.count, 17)
        XCTAssertEqual(StoreDuplicateFinder.groups(stores.map { StoreSnapshot($0) }).count, 0)
    }

    // MARK: - T17 (AC-18)

    func testJoinReusesStoreWithSameShareID() throws {
        // GIVEN ein Laden mit shareID X und ein zweiter mit anderer shareID
        let code = "UTJOIN-\(UUID().uuidString.prefix(8))"
        let joined = Store(name: "Lidl", emoji: "🛒", colorHex: "#2563EB")
        let other = Store(name: "dm", emoji: "🧴", colorHex: "#DB2777")
        [joined, other].forEach { context.insert($0) }
        sharedStores = [joined, other]
        joined.shareID = code
        other.shareID = "\(code)-OTHER"
        try context.save()

        // WHEN Beitritt zu X den vorhandenen Laden sucht
        let found = StoreShareJoin.existingStore(shareID: code, in: context)

        // THEN derselbe Laden, Zahl der Läden unverändert; unbekannter Code liefert nichts
        XCTAssertEqual(found?.id, joined.id)
        XCTAssertEqual(try allStores().count, 2)
        XCTAssertNil(StoreShareJoin.existingStore(shareID: "\(code)-UNKNOWN", in: context))
    }

    // MARK: - T18 (AC-12)

    func testNewFilesNeverDelete() throws {
        // GIVEN alle neuen Produktdateien von #156
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let paths = [
            "SmartCart/Services/CloudMirrorMonitor.swift",
            "SmartCart/Services/StoreDuplicateService.swift",
            "SmartCart/Views/Settings/CloudMirrorStatusView.swift",
            "SmartCart/Views/Settings/StoreDuplicatesView.swift",
        ]
        for path in paths {
            // WHEN der Quelltext nach `delete(` durchsucht wird
            let source = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            // THEN kein Treffer
            XCTAssertFalse(source.contains("delete("), "\(path) enthält `delete(`")
        }
    }
}
