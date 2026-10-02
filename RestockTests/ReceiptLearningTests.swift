import XCTest
@testable import Restock

/// Issue #59 — die Fachentscheidungen aus `ReceiptScannerView.save()` (`ReceiptLearning`) direkt
/// geprüft: Lern-Plan, Auflösung des gemeinten Artikels, Ähnlichkeitsschwelle der lockeren Suche
/// und Rückschreiben auf den gelisteten Artikel.
final class ReceiptLearningTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private var cutoff: Date { now.addingTimeInterval(-7 * 24 * 3600) }

    private func line(_ name: String, price: Double = 1.99, matchedItemID: UUID? = nil) -> EditableReceiptLine {
        var line = EditableReceiptLine(name: name, price: price, originalName: name.uppercased())
        line.matchedItemID = matchedItemID
        return line
    }

    private func completedItem(_ name: String, completedAt: Date) -> ShoppingItem {
        let item = ShoppingItem(name: name)
        item.isCompleted = true
        item.completedDate = completedAt
        return item
    }

    private func record(_ name: String, store: String = "Lidl", date: Date, price: Double? = nil,
                        amount: Double = 1, unit: String = "") -> PurchaseRecord {
        let record = PurchaseRecord(itemName: name, storeName: store, quantityAmount: amount, unit: unit, actualPrice: price)
        record.date = date
        return record
    }

    // MARK: - plan

    func testPlanUsesQuantityAndUnitOfTheSameMatchRecord() {
        let match = record("Hackfleisch", date: now, amount: 500, unit: "g")

        let plan = ReceiptLearning.plan(line: line("Hackfleisch", price: 5.00), match: match)

        XCTAssertEqual(plan.key, "hackfleisch")
        XCTAssertEqual(plan.perUnitPrice, 0.01, accuracy: 0.000001)
        XCTAssertEqual(plan.unit, "g")
    }

    func testPlanWithoutMatchLearnsPiecePrice() {
        let plan = ReceiptLearning.plan(line: line("Frische Vollmilch", price: 1.19), match: nil)

        XCTAssertEqual(plan, ReceiptLearning.Plan(key: "frische vollmilch", perUnitPrice: 1.19, unit: "stk"))
    }

    // MARK: - matchedItem

    func testMatchedItemPrefersExplicitItemID() {
        let explicit = ShoppingItem(name: "Mozzarella")
        let sameName = completedItem("Butter", completedAt: now)

        let found = ReceiptLearning.matchedItem(for: line("Butter", matchedItemID: explicit.id),
                                                in: [sameName, explicit])

        XCTAssertTrue(found === explicit)
    }

    /// „Maultaschen ohne Preis": ohne `matchedItemID` findet der exakte Name den abgehakten Artikel.
    func testMatchedItemFallsBackToExactNameAmongCompletedItems() {
        let maultaschen = completedItem("Maultaschen", completedAt: now)

        XCTAssertTrue(ReceiptLearning.matchedItem(for: line("maultaschen"), in: [maultaschen]) === maultaschen)
    }

    /// Ein noch offener, gleichnamiger Artikel wurde nicht gekauft und bekommt den Bon-Preis nie.
    func testMatchedItemIgnoresPendingItemWithSameName() {
        let bought = completedItem("Butter", completedAt: now.addingTimeInterval(-3600))
        let pending = ShoppingItem(name: "Butter")
        pending.addedDate = now

        XCTAssertTrue(ReceiptLearning.matchedItem(for: line("Butter"), in: [pending, bought]) === bought)
        XCTAssertNil(ReceiptLearning.matchedItem(for: line("Butter"), in: [pending]))
    }

    func testMatchedItemPicksMostRecentlyCompleted() {
        let older = completedItem("Butter", completedAt: now.addingTimeInterval(-86_400))
        let newer = completedItem("Butter", completedAt: now)

        XCTAssertTrue(ReceiptLearning.matchedItem(for: line("Butter"), in: [older, newer]) === newer)
    }

    // MARK: - purchaseMatch

    func testPurchaseMatchPrefersNewestUnpricedOwnRecord() {
        let priced = record("Butter", date: now, price: 1.99)
        let oldUnpriced = record("Butter", date: now.addingTimeInterval(-86_400))
        let newUnpriced = record("Butter", date: now.addingTimeInterval(-3600))

        let match = ReceiptLearning.purchaseMatch(
            for: line("Butter"), ownRecords: [priced, oldUnpriced, newUnpriced],
            allRecords: [], storeName: "Lidl", cutoff: cutoff)

        XCTAssertTrue(match === newUnpriced)
    }

    func testPurchaseMatchLooseSearchFindsSimilarRecordInSameStoreWithinSevenDays() {
        let loose = record("Butter mild", date: now.addingTimeInterval(-86_400))

        let match = ReceiptLearning.purchaseMatch(
            for: line("Butter"), ownRecords: [], allRecords: [loose], storeName: "lidl", cutoff: cutoff)

        XCTAssertTrue(match === loose)
    }

    /// Der Kondensmilch-Fall: reines `contains` träfe einen fremden Artikel — die
    /// Ähnlichkeitsschwelle verwirft ihn (0,588 < 0,6).
    func testPurchaseMatchRejectsLooseHitBelowSimilarityThreshold() {
        let kondensmilch = record("Kondensmilch", date: now.addingTimeInterval(-86_400))

        XCTAssertNil(ReceiptLearning.purchaseMatch(
            for: line("Milch"), ownRecords: [], allRecords: [kondensmilch], storeName: "Lidl", cutoff: cutoff))
    }

    func testPurchaseMatchLooseSearchIgnoresOtherStoresAndOldRecords() {
        let otherStore = record("Butter", store: "Rewe", date: now)
        let tooOld = record("Butter", date: cutoff.addingTimeInterval(-1))

        XCTAssertNil(ReceiptLearning.purchaseMatch(
            for: line("Butter"), ownRecords: [], allRecords: [otherStore, tooOld], storeName: "Lidl", cutoff: cutoff))
    }

    // MARK: - apply

    func testApplyWritesMatchingPiecePrice() throws {
        let item = ShoppingItem(name: "Butter")

        ReceiptLearning.apply(ReceiptLearning.Plan(key: "butter", perUnitPrice: 1.99, unit: "stk"), to: item)

        XCTAssertEqual(try XCTUnwrap(item.estimatedPrice), 1.99, accuracy: 0.000001)
        XCTAssertFalse(item.estimatedPriceIsAutoDerived)
    }

    /// Issue #10: eine Gramm-Rate wird nie als Stückpreis an einen Artikel ohne Menge geschrieben
    /// (die gemeldeten „0,01 €").
    func testApplyNeverWritesGramRateAsPiecePrice() {
        let item = ShoppingItem(name: "Hackfleisch")
        let before = item.estimatedPrice

        ReceiptLearning.apply(ReceiptLearning.Plan(key: "hackfleisch", perUnitPrice: 0.0125, unit: "g"), to: item)

        XCTAssertNotEqual(item.estimatedPrice, 0.0125)
        XCTAssertEqual(item.estimatedPrice, before)
    }
}
