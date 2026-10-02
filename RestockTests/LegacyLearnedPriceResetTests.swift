import XCTest
import SwiftData
@testable import Restock

/// TDD RED (Issue #11, `docs/specs/models/legacy-price-reset-migration.md`) — deckt AC1–AC10 und
/// AC14 (Zuordnung identisch zu `ShoppingItem.init`) ab. Der Altzustand wird von Hand hergestellt:
/// `ShoppingItem.init` würde einen Altwert ohne Einheit seit #10 selbst verwerfen, deshalb setzen
/// die Tests `estimatedPrice`/`estimatedPriceIsAutoDerived` nach der Konstruktion.
@MainActor
final class LegacyLearnedPriceResetTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: LegacyLearnedPriceReset.flagKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: LegacyLearnedPriceReset.flagKey)
        super.tearDown()
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return ModelContext(try ModelContainer(for: schema, configurations: config))
    }

    private func legacyStore(_ context: ModelContext, key: String = "laugenbrötchen", price: Double = 1.56, unit: String? = nil) -> Store {
        let store = Store(name: "Altbon", emoji: "🥐", colorHex: "#AA5500")
        store.learnedPrices[key] = price
        if let unit { store.learnedPriceUnits[key] = unit }
        context.insert(store)
        return store
    }

    /// Artikel im Altzustand: Wert mit „echter Herkunft“ von Hand gesetzt.
    private func legacyItem(
        _ context: ModelContext, name: String, store: Store?, price: Double? = 1.56,
        autoDerived: Bool = false, completed: Bool = false
    ) -> ShoppingItem {
        let item = ShoppingItem(name: name, category: "Backwaren", store: store)
        item.estimatedPrice = price
        item.estimatedPriceIsAutoDerived = autoDerived
        item.isCompleted = completed
        context.insert(item)
        return item
    }

    private func expectedEstimate(_ item: ShoppingItem) -> Double? {
        PriceEstimator.estimate(for: item.name, category: item.category, unit: item.unit, quantityAmount: item.quantityAmount)
    }

    // AC1
    func testLegacyValueIsResetToEstimate() throws {
        let context = try makeContext()
        let store = legacyStore(context)
        let item = legacyItem(context, name: "Laugenbrötchen", store: store)
        LegacyLearnedPriceReset.runIfNeeded(context: context)
        XCTAssertEqual(item.estimatedPrice, expectedEstimate(item))
        XCTAssertTrue(item.estimatedPriceIsAutoDerived)
    }

    // AC2
    func testManualPriceWithDifferentValueIsUntouched() throws {
        let context = try makeContext()
        let store = legacyStore(context)
        let item = legacyItem(context, name: "Laugenbrötchen", store: store, price: 2.50)
        LegacyLearnedPriceReset.runIfNeeded(context: context)
        XCTAssertEqual(item.estimatedPrice, 2.50)
        XCTAssertFalse(item.estimatedPriceIsAutoDerived)
    }

    // AC3
    func testRateWithUnitIsUntouched() throws {
        let context = try makeContext()
        let store = legacyStore(context, unit: "stk")
        let item = legacyItem(context, name: "Laugenbrötchen", store: store)
        LegacyLearnedPriceReset.runIfNeeded(context: context)
        XCTAssertEqual(item.estimatedPrice, 1.56)
        XCTAssertFalse(item.estimatedPriceIsAutoDerived)
    }

    // AC4
    func testAutoDerivedAndPricelessItemsAreUntouched() throws {
        let context = try makeContext()
        let store = legacyStore(context)
        let auto = legacyItem(context, name: "Laugenbrötchen", store: store, price: 1.56, autoDerived: true)
        let priceless = legacyItem(context, name: "Laugenbrötchen groß", store: store, price: nil)
        LegacyLearnedPriceReset.runIfNeeded(context: context)
        XCTAssertEqual(auto.estimatedPrice, 1.56)
        XCTAssertNil(priceless.estimatedPrice)
        XCTAssertFalse(priceless.estimatedPriceIsAutoDerived)
    }

    // AC5
    func testNameMatchingFollowsSubstringAndFuzzyRules() throws {
        let context = try makeContext()
        let store = legacyStore(context)
        let substring = legacyItem(context, name: "Brötchen", store: store)
        let fuzzy = legacyItem(context, name: "Laugenbrotchen", store: store)
        let noMatch = legacyItem(context, name: "Käse", store: store)
        LegacyLearnedPriceReset.runIfNeeded(context: context)
        XCTAssertTrue(substring.estimatedPriceIsAutoDerived, "Teilstring-Treffer wird zurückgesetzt")
        XCTAssertTrue(fuzzy.estimatedPriceIsAutoDerived, "Fuzzy-Treffer (#52) wird zurückgesetzt")
        XCTAssertFalse(noMatch.estimatedPriceIsAutoDerived, "Name ohne Treffer bleibt unberührt")
        XCTAssertEqual(noMatch.estimatedPrice, 1.56)
    }

    // AC5/AC14: Extraktion liefert denselben Schlüssel wie die Zuordnung in `init`
    func testMatchingKeyMatchesInitBehavior() {
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#123456")
        store.learnedPrices["hackfleisch gemischt 500g"] = 3.49
        store.learnedPrices["rinderhackfleisch"] = 5.99
        store.learnedPrices["seitan"] = 2.99
        store.learnedPriceDates["rinderhackfleisch"] = Date()
        XCTAssertEqual(ShoppingItem.matchingLearnedPriceKey(forLowercasedName: "hackfleisch", in: store), "rinderhackfleisch")
        XCTAssertEqual(ShoppingItem.matchingLearnedPriceKey(forLowercasedName: "saitan", in: store), "seitan")
        XCTAssertNil(ShoppingItem.matchingLearnedPriceKey(forLowercasedName: "käse", in: store))
    }

    // AC6
    func testCompletedItemIsResetAndStaysCompleted() throws {
        let context = try makeContext()
        let store = legacyStore(context)
        let item = legacyItem(context, name: "Laugenbrötchen", store: store, completed: true)
        item.quantityAmount = 4
        item.unit = "Stk"
        item.quantitySource = "history"
        LegacyLearnedPriceReset.runIfNeeded(context: context)
        XCTAssertTrue(item.estimatedPriceIsAutoDerived)
        XCTAssertTrue(item.isCompleted)
        XCTAssertEqual(item.quantityAmount, 4)
        XCTAssertEqual(item.unit, "Stk")
        XCTAssertEqual(item.quantitySource, "history")
    }

    // AC7
    func testItemWithoutStoreIsUntouched() throws {
        let context = try makeContext()
        let item = legacyItem(context, name: "Laugenbrötchen", store: nil)
        LegacyLearnedPriceReset.runIfNeeded(context: context)
        XCTAssertEqual(item.estimatedPrice, 1.56)
        XCTAssertFalse(item.estimatedPriceIsAutoDerived)
    }

    // AC8
    func testFlagIsSetAndSecondRunAndSetFlagDoNothing() throws {
        let context = try makeContext()
        let store = legacyStore(context)
        let first = legacyItem(context, name: "Laugenbrötchen", store: store)
        LegacyLearnedPriceReset.runIfNeeded(context: context)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: LegacyLearnedPriceReset.flagKey))
        let afterFirst = first.estimatedPrice

        let second = legacyItem(context, name: "Laugenbrötchen groß", store: store)
        LegacyLearnedPriceReset.runIfNeeded(context: context)
        XCTAssertEqual(first.estimatedPrice, afterFirst)
        XCTAssertEqual(second.estimatedPrice, 1.56, "Bei gesetztem Flag wird nichts mehr angefasst")
        XCTAssertFalse(second.estimatedPriceIsAutoDerived)
    }

    // AC9
    func testToleranceBoundary() {
        XCTAssertTrue(LegacyLearnedPriceReset.shouldReset(
            hasStore: true, isAutoDerived: false, estimatedPrice: 1.564,
            matchedLearnedPrice: 1.56, matchedLearnedUnit: nil))
        XCTAssertFalse(LegacyLearnedPriceReset.shouldReset(
            hasStore: true, isAutoDerived: false, estimatedPrice: 1.566,
            matchedLearnedPrice: 1.56, matchedLearnedUnit: nil))
        XCTAssertFalse(LegacyLearnedPriceReset.shouldReset(
            hasStore: true, isAutoDerived: false, estimatedPrice: 1.56,
            matchedLearnedPrice: 1.56, matchedLearnedUnit: "stk"))
        XCTAssertFalse(LegacyLearnedPriceReset.shouldReset(
            hasStore: false, isAutoDerived: false, estimatedPrice: 1.56,
            matchedLearnedPrice: 1.56, matchedLearnedUnit: nil))
    }

    // AC10
    func testLearnedPriceMapsAreUntouched() throws {
        let context = try makeContext()
        let store = legacyStore(context)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        store.learnedPriceDates["laugenbrötchen"] = date
        _ = legacyItem(context, name: "Laugenbrötchen", store: store)
        LegacyLearnedPriceReset.runIfNeeded(context: context)
        XCTAssertEqual(store.learnedPrices, ["laugenbrötchen": 1.56])
        XCTAssertEqual(store.learnedPriceUnits, [:])
        XCTAssertEqual(store.learnedPriceDates, ["laugenbrötchen": date])
    }
}
