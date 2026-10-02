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

/// Issue #14, Schritt 1 — Messung je Auflösungsstufe: welche Stufe den Namen liefert und was der
/// Nutzer beim Speichern daraus macht.
final class ReceiptResolutionMetricsTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "ReceiptResolutionMetricsTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func line(name: String, resolvedName: String?, stage: ReceiptResolutionStage?,
                      price: Double = 1.99, included: Bool = true) -> EditableReceiptLine {
        var line = EditableReceiptLine(name: name, price: price, originalName: "RAW")
        line.isIncluded = included
        line.resolutionStage = stage
        line.resolutionName = resolvedName
        return line
    }

    // MARK: - Zähler

    func testMetricsCountPerStageAndOutcome() {
        let metrics = ReceiptResolutionMetrics(defaults: defaults)

        metrics.record(.history, .kept)
        metrics.record(.history, .kept)
        metrics.record(.history, .renamed)
        metrics.record(.ai, .excluded)
        metrics.recordNonProductAnswer()

        XCTAssertEqual(metrics.count(.history, .kept), 2)
        XCTAssertEqual(metrics.count(.history, .renamed), 1)
        XCTAssertEqual(metrics.total(.history), 3)
        XCTAssertEqual(metrics.total(.ai), 1)
        XCTAssertEqual(metrics.total(.alias), 0)
        XCTAssertEqual(metrics.nonProductAnswers, 1)

        metrics.reset()
        XCTAssertEqual(metrics.total(.history), 0)
        XCTAssertEqual(metrics.nonProductAnswers, 0)
    }

    // MARK: - Ergebnis einer Zeile

    func testOutcomeKeptWhenNameUnchangedIgnoringCase() {
        let kept = line(name: "vollmilch", resolvedName: "Vollmilch", stage: .history)
        XCTAssertEqual(EditableReceiptLine.resolutionOutcome(kept), .kept)
    }

    func testOutcomeRenamedWhenUserChangedName() {
        let renamed = line(name: "Hafermilch", resolvedName: "Vollmilch", stage: .ai)
        XCTAssertEqual(EditableReceiptLine.resolutionOutcome(renamed), .renamed)
    }

    func testOutcomeExcludedWhenLineIsNotSaved() {
        XCTAssertEqual(EditableReceiptLine.resolutionOutcome(
            line(name: "Pizza Baguette", resolvedName: "Pizza Baguette", stage: .ai, included: false)), .excluded)
        XCTAssertEqual(EditableReceiptLine.resolutionOutcome(
            line(name: "Butter", resolvedName: "Butter", stage: .alias, price: 0)), .excluded)
    }

    func testOutcomeNilWithoutStage() {
        XCTAssertNil(EditableReceiptLine.resolutionOutcome(line(name: "Butter", resolvedName: nil, stage: nil)))
    }

    // MARK: - Weitergabe der Stufe

    func testReviewLineTakesStageAndNameFromResolution() {
        let resolved = ResolvedReceiptLine(
            name: "Toilettenpapier", originalName: "HAKLE TOIPA", price: 3.49, quantity: 1, unit: "",
            suggestions: [], matchedItemID: nil, stage: .dictionary)

        let line = EditableReceiptLine(resolved: resolved)

        XCTAssertEqual(line.resolutionStage, .dictionary)
        XCTAssertEqual(line.resolutionName, "Toilettenpapier")
    }

    func testAIReresolutionReplacesStage() {
        let unresolved = EditableReceiptLine(resolved: ResolvedReceiptLine(
            name: "MZZRLL", originalName: "MZZRLL", price: 0.99, quantity: 1, unit: "",
            suggestions: [], matchedItemID: nil, stage: .unresolved))
        let reresolved = ResolvedReceiptLine(
            name: "Mozzarella", originalName: "MZZRLL", price: 0.99, quantity: 1, unit: "",
            suggestions: [], matchedItemID: nil, resolvedByAI: true, stage: .ai)

        let merged = EditableReceiptLine.mergeAIReresolution(into: [unresolved], resolved: [reresolved], at: [0])

        XCTAssertEqual(merged[0].resolutionStage, .ai)
        XCTAssertEqual(merged[0].resolutionName, "Mozzarella")
    }

    func testResolveTagsDictionaryAndUnresolvedStages() async {
        let store = Store(name: "Testladen-\(UUID().uuidString)", emoji: "🛒", colorHex: "#123456")
        let parsed = [
            ReceiptLine(name: "Hakle ToiPa Traumweich 8x130Bl", price: 3.49),
            ReceiptLine(name: "Xqzvw Plrtk", price: 1.00),
        ]

        let resolved = await ReceiptResolutionService.resolve(
            parsed: parsed, store: store, allRecords: [], allowAIResolution: false)

        XCTAssertEqual(resolved.map(\.stage), [.dictionary, .unresolved])
    }

    // MARK: - KEIN_PRODUKT

    func testNonProductAnswerIsRecognizedAfterTrimming() {
        let resolver = ReceiptNameAIResolver.shared
        XCTAssertTrue(resolver.isNonProductAnswer(" \"\(ReceiptNameAIResolver.nonProductSentinel)\" "))
        XCTAssertFalse(resolver.isNonProductAnswer("Sahne"))
    }
}
