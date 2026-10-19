import XCTest
import SwiftData
@testable import Restock

/// Schutz und Aufräumung gegen gespeicherte Kürzel-Namen ("Bröt.", gemeldet 18.10.2026):
/// Alias-Lernen beim Speichern (`ReceiptAliasService.isLearnableTarget`,
/// `ReceiptLearning.aliasLearnableIndices`) und die einmalige Aufräumung gelernter Preise
/// (`AbbreviatedNameCleanup`). Der Alias-Speicher selbst (App-Gruppe) wird hier nicht berührt.
@MainActor
final class AbbreviatedNameCleanupTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: AbbreviatedNameCleanup.flagKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: AbbreviatedNameCleanup.flagKey)
        super.tearDown()
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return ModelContext(try ModelContainer(for: schema, configurations: config))
    }

    // MARK: - Alias-Schutz

    func testAbbreviationIsNotALearnableAliasTarget() {
        XCTAssertFalse(ReceiptAliasService.isLearnableTarget("Bröt."))
        XCTAssertFalse(ReceiptAliasService.isLearnableTarget("Schokol."))
        XCTAssertTrue(ReceiptAliasService.isLearnableTarget("Brötchen"))
        XCTAssertTrue(ReceiptAliasService.isLearnableTarget("Dr. Oetker Pizza"))
    }

    /// Der gemeldete Bon: derselbe Name an vier fremden Zeilen ohne Wortbezug → für keine davon
    /// ein Alias. („Salbeibonbons“ wäre an „Ricola Bonbon Salbei“ bezogen und bliebe lernbar.)
    func testSameNameOnUnrelatedLinesBlocksAliasLearning() {
        let lines = [
            (name: "Lutschpastille", originalName: "Ricola Bonbon Salbei"),
            (name: "Lutschpastille", originalName: "Mentos Gum 3 Fruity Fresh"),
            (name: "Lutschpastille", originalName: "Elmex Zahncr. Sens. Prof. 75ml"),
            (name: "Lutschpastille", originalName: "Balea Tuchmaske Ultra Sensitiv"),
            (name: "Kaffee", originalName: "dmBio Espresso gemahlen 250g"),
        ]
        XCTAssertEqual(ReceiptLearning.aliasLearnableIndices(lines), [4])
    }

    /// Zwei Tuchmasken dürfen beide "Tuchmaske" heißen; drei Zeilen mit Wortbezug ebenso.
    func testRelatedOrRareRepeatsStayLearnable() {
        let lines = [
            (name: "Tuchmaske", originalName: "Balea Tuchmaske Ultra Sensitiv"),
            (name: "Tuchmaske", originalName: "SEINZ. Tuchmaske Hydro Effect"),
            (name: "Schokolade", originalName: "dmBio Noisette Schokol"),
            (name: "Schokolade", originalName: "Schoko Lolli Vollmilch"),
            (name: "Schokolade", originalName: "dmBio Schokolierte Brezeln ZB"),
        ]
        XCTAssertEqual(ReceiptLearning.aliasLearnableIndices(lines), [0, 1, 2, 3, 4])
    }

    // MARK: - Aufräumung gelernter Preise

    func testRemovesLearnedPricesUnderAbbreviatedKeysOnly() throws {
        let context = try makeContext()
        let store = Store(name: "dm", emoji: "🧴", colorHex: "#123456")
        for key in ["bröt.", "brötchen", "milch 3.5"] {
            store.learnedPrices[key] = 1.75
            store.learnedPriceUnits[key] = "stk"
            store.learnedPriceDates[key] = Date()
            store.learnedPriceOrigins[key] = "receipt"
        }
        context.insert(store)

        AbbreviatedNameCleanup.runIfNeeded(context: context)

        XCTAssertNil(store.learnedPrices["bröt."])
        XCTAssertNil(store.learnedPriceUnits["bröt."])
        XCTAssertNil(store.learnedPriceDates["bröt."])
        XCTAssertNil(store.learnedPriceOrigins["bröt."])
        XCTAssertEqual(store.learnedPrices["brötchen"], 1.75)
        XCTAssertEqual(store.learnedPrices["milch 3.5"], 1.75)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: AbbreviatedNameCleanup.flagKey))
    }

    func testRunsOnlyOnce() throws {
        let context = try makeContext()
        let store = Store(name: "dm", emoji: "🧴", colorHex: "#123456")
        context.insert(store)
        AbbreviatedNameCleanup.runIfNeeded(context: context)

        store.learnedPrices["bröt."] = 1.75
        AbbreviatedNameCleanup.runIfNeeded(context: context)

        XCTAssertEqual(store.learnedPrices["bröt."], 1.75, "Zweiter Aufruf darf nichts mehr ändern")
    }

    // MARK: - Kaufdatensätze

    private func record(_ name: String, store: String = "dm", price: Double? = 1.0, daysAgo: Double = 0) -> PurchaseRecord {
        let r = PurchaseRecord(itemName: name, storeName: store, actualPrice: price)
        r.date = Date().addingTimeInterval(-daysAgo * 86_400)
        return r
    }

    /// Der gemeldete Bon: 16 „Bröt.“-Datensätze mit Bon-Preis am selben Tag im selben Laden → weg.
    func testRemovesBugPatternRecords() throws {
        let context = try makeContext()
        let prices = [0.85, 4.25, 1.95, 1.25, 1.10, 1.70, 0.95, 0.65, 2.45, 6.45, 1.45, 1.95, 5.95, 1.95, 2.25, 1.75]
        for price in prices { context.insert(record("Bröt.", price: price)) }
        context.insert(record("Brötchen", price: 0.39))

        AbbreviatedNameCleanup.runIfNeeded(context: context)

        let names = try context.fetch(FetchDescriptor<PurchaseRecord>()).map(\.itemName)
        XCTAssertEqual(names, ["Brötchen"])
    }

    /// Einzelne oder zwei Kürzel-Datensätze, Datensätze ohne Bon-Preis, an anderen Tagen oder in
    /// anderen Läden gehören nicht zum Muster und bleiben.
    func testKeepsRecordsOutsideThePattern() throws {
        let context = try makeContext()
        context.insert(record("Bröt.", price: 1.0))
        context.insert(record("Bröt.", price: 2.0))
        context.insert(record("Bröt.", store: "Lidl", price: 3.0))
        context.insert(record("Bröt.", price: nil))
        context.insert(record("Bröt.", price: 4.0, daysAgo: 1))

        AbbreviatedNameCleanup.runIfNeeded(context: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<PurchaseRecord>()).count, 5)
    }

    func testBugPatternDecisionGroupsByNameStoreAndDay() {
        let same = (0..<3).map { record("Bröt.", price: Double($0)) }
        let otherDay = record("Bröt.", price: 9, daysAgo: 2)
        let doomed = AbbreviatedNameCleanup.bugPatternRecords(in: same + [otherDay])
        XCTAssertEqual(Set(doomed.map(\.id)), Set(same.map(\.id)))
    }
}
