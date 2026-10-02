import XCTest
import SwiftData
@testable import Restock

/// Issue #14 (Teil „Messung zuerst“) — beweist, dass jede aufgelöste Bon-Zeile die Stufe trägt, die
/// ihren Namen bestimmt hat, und dass der lokale Zähler (`ReceiptResolutionStats`) beim Speichern
/// je Stufe „gesamt / geändert / abgewählt“ richtig zählt — nur Zahlen, nie Namen.
/// Spec: `docs/specs/services/receipt-resolution-stats.md` (AC-1 bis AC-14).
///
/// Jeder Test nutzt eine eigene `UserDefaults`-Suite (UUID im Namen), damit der App-Gruppen-
/// Speicher der echten App unberührt bleibt.
final class ReceiptResolutionStatsTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "ReceiptResolutionStatsTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    // MARK: - Hilfen

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: config))
    }

    private func line(
        _ resolvedName: String, final finalName: String? = nil, stage: ReceiptResolutionStage?,
        included: Bool = true, price: Double = 1.99
    ) -> EditableReceiptLine {
        var l = EditableReceiptLine(name: finalName ?? resolvedName, price: price, originalName: "RAW")
        l.stage = stage
        l.resolvedName = resolvedName
        l.isIncluded = included
        return l
    }

    // MARK: - AC-1: Stufen-Enum

    func testStageHasExactlyTheSevenCasesAndStringRawValues() {
        XCTAssertEqual(
            Set(ReceiptResolutionStage.allCases.map(\.rawValue)),
            ["alias", "dictionary", "completed", "history", "ai", "rawText", "nonProduct"])
        XCTAssertEqual(ReceiptResolutionStage.allCases.count, 7)
    }

    // MARK: - AC-2 / AC-3 / AC-5: resolve setzt die Stufe, das Verhalten bleibt

    func testAliasLineGetsAliasStage() async throws {
        let context = try makeContext()
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#123456")
        context.insert(store)
        ReceiptAliasService.shared.learn(receiptText: "ZZQX KUERZEL", itemName: "Testalias")
        defer { ReceiptAliasService.shared.learn(receiptText: "ZZQX KUERZEL", itemName: "ZZQX KUERZEL") }

        let result = await ReceiptResolutionService.resolve(
            parsed: [ReceiptLine(name: "ZZQX KUERZEL", price: 1.0)],
            store: store, allRecords: [], allowAIResolution: false)

        XCTAssertEqual(result.first?.name, "Testalias")
        XCTAssertEqual(result.first?.stage, .alias)
    }

    func testDictionaryLineGetsDictionaryStage() async throws {
        let context = try makeContext()
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#123456")
        context.insert(store)

        let result = await ReceiptResolutionService.resolve(
            parsed: [ReceiptLine(name: "BTR", price: 1.49)],
            store: store, allRecords: [], allowAIResolution: false)

        XCTAssertEqual(result.first?.name, "Butter", "Eintrag \"btr\" des Wörterbuchs")
        XCTAssertEqual(result.first?.stage, .dictionary)
    }

    func testCompletedItemLineGetsCompletedStageAndKeepsMatchedItem() async throws {
        let context = try makeContext()
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#123456")
        context.insert(store)
        let item = ShoppingItem(name: "Hackfleisch", store: store)
        context.insert(item)
        item.markCompleted()

        let result = await ReceiptResolutionService.resolve(
            parsed: [ReceiptLine(name: "Hackfleish", price: 4.99)],
            store: store, allRecords: [], allowAIResolution: false)

        XCTAssertEqual(result.first?.name, "Hackfleisch")
        XCTAssertEqual(result.first?.matchedItemID, item.id, "Verhalten unverändert: Verknüpfung zum abgehakten Artikel")
        XCTAssertEqual(result.first?.stage, .completed)
    }

    func testHistoryLineGetsHistoryStage() async throws {
        let context = try makeContext()
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#123456")
        context.insert(store)
        let records = [PurchaseRecord(itemName: "Mozzarella", storeName: "Lidl")]

        let result = await ReceiptResolutionService.resolve(
            parsed: [ReceiptLine(name: "Mzzrll", price: 0.89)],
            store: store, allRecords: records, allowAIResolution: false)

        XCTAssertEqual(result.first?.name, "Mozzarella")
        XCTAssertEqual(result.first?.stage, .history)
    }

    func testUnresolvedLineWithoutAIKeepsRawTextAndGetsRawTextStage() async throws {
        let context = try makeContext()
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#123456")
        context.insert(store)

        let result = await ReceiptResolutionService.resolve(
            parsed: [ReceiptLine(name: "Xyz123 Qwv", price: 2.0)],
            store: store, allRecords: [], allowAIResolution: false)

        XCTAssertEqual(result.first?.name, "Xyz123 Qwv", "Name unverändert")
        XCTAssertEqual(result.first?.stage, .rawText)
        XCTAssertEqual(result.first?.resolvedByAI, false)
    }

    func testResolvedByAILinesNeverCarryAnotherStage() async throws {
        // Auf einem Gerät mit Apple Intelligence prüfbar; im Simulator ist `resolvedByAI` nie true,
        // die Bedingung gilt dann trivial. Die Zählung der Stufe .ai deckt `testTallyCountsAIStage` ab.
        let context = try makeContext()
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#123456")
        context.insert(store)

        let result = await ReceiptResolutionService.resolve(
            parsed: [ReceiptLine(name: "Xyz123 Qwv", price: 2.0), ReceiptLine(name: "BTR", price: 1.0)],
            store: store, allRecords: [])

        for r in result where r.resolvedByAI {
            XCTAssertEqual(r.stage, .ai)
        }
        for r in result where !r.resolvedByAI {
            XCTAssertNotEqual(r.stage, .ai)
            XCTAssertNotNil(r.stage, "Jede von resolve gelieferte Zeile trägt eine Stufe")
        }
    }

    // MARK: - AC-6: Wire-Format der Share Extension

    func testLegacyPayloadWithoutStageDecodesWithNilStage() throws {
        let legacy = """
        {"name":"Milch","originalName":"MILCH","price":0.99,"quantity":1,"unit":"",
         "suggestions":[],"resolvedByAI":false}
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(ResolvedReceiptLine.self, from: legacy)

        XCTAssertEqual(decoded.name, "Milch")
        XCTAssertNil(decoded.stage, "Alt-Payload ohne Schlüssel `stage` → Stufe unbekannt, nicht erfunden")
    }

    func testStageRoundTripsThroughCodable() throws {
        var line = ResolvedReceiptLine(
            name: "Milch", originalName: "MILCH", price: 0.99, quantity: 1, unit: "",
            suggestions: [], matchedItemID: nil)
        line.stage = .history

        let data = try JSONEncoder().encode(line)
        let back = try JSONDecoder().decode(ResolvedReceiptLine.self, from: data)

        XCTAssertEqual(back.stage, .history)
    }

    // MARK: - AC-7 / AC-8 / AC-9 / AC-4: tally

    func testTallyCountsEachLineOnceAtItsStageAndSkipsUnknownStage() {
        let lines = [
            line("Butter", stage: .dictionary),
            line("Milch", stage: .dictionary),
            line("Brot", stage: .history),
            line("Rohtext", stage: nil),
        ]

        let tally = ReceiptResolutionStats.tally(lines)

        XCTAssertEqual(tally[.dictionary]?.total, 2)
        XCTAssertEqual(tally[.history]?.total, 1)
        XCTAssertEqual(tally.values.map(\.total).reduce(0, +), 3, "Zeile ohne Stufe wird nicht gezählt")
    }

    func testTallyCountsAIStage() {
        let tally = ReceiptResolutionStats.tally([line("Frische Vollmilch", stage: .ai)])
        XCTAssertEqual(tally[.ai]?.total, 1)
    }

    func testTallyChangedOnlyWhenIncludedAndNameDiffersBeyondCaseAndWhitespace() {
        let lines = [
            line("Butter", stage: .alias),                                   // unverändert
            line("Butter", final: "Süßrahmbutter", stage: .alias),           // geändert
            line("Butter", final: "  butter ", stage: .alias),               // nur Groß/Klein + Leerzeichen
            line("Butter", stage: .alias, price: 9.99),                      // nur Preis anders
        ]

        let counts = ReceiptResolutionStats.tally(lines)[.alias]

        XCTAssertEqual(counts?.total, 4)
        XCTAssertEqual(counts?.changed, 1)
        XCTAssertEqual(counts?.deselected, 0)
    }

    func testTallyQuantityChangeIsNotAChangedName() {
        var l = line("Butter", stage: .alias)
        l.quantity = 3
        XCTAssertEqual(ReceiptResolutionStats.tally([l])[.alias]?.changed, 0)
    }

    func testTallyDeselectedLinesCountAsTotalAndDeselectedButNeverChanged() {
        let lines = [
            line("Butter", final: "Anderer Name", stage: .history, included: false),
            line("Milch", stage: .history, included: false),
            line("Brot", final: "Roggenbrot", stage: .history),
        ]

        let counts = ReceiptResolutionStats.tally(lines)[.history]

        XCTAssertEqual(counts?.total, 3)
        XCTAssertEqual(counts?.deselected, 2)
        XCTAssertEqual(counts?.changed, 1, "Abgewählte Zeilen zählen nie als geändert")
        let c = counts ?? .init()
        XCTAssertLessThanOrEqual(c.changed + c.deselected, c.total)
    }

    // MARK: - AC-10 / AC-11: Persistenz, Zurücksetzen

    func testRecordAddsUpAcrossReceiptsAndSurvivesNewInstance() {
        let stats = ReceiptResolutionStats(defaults: defaults)
        stats.record([line("Butter", stage: .alias), line("Milch", final: "Hafermilch", stage: .alias)])
        stats.record([line("Brot", stage: .alias, included: false)])

        let reloaded = ReceiptResolutionStats(defaults: defaults)
        let counts = reloaded.counts(for: .alias)

        XCTAssertEqual(counts, ReceiptResolutionStats.Counts(total: 3, changed: 1, deselected: 1))
    }

    func testResetClearsAllAndUnseenStageIsZero() {
        let stats = ReceiptResolutionStats(defaults: defaults)
        XCTAssertEqual(stats.counts(for: .ai), ReceiptResolutionStats.Counts(), "Nie gezählt → 0/0/0")

        stats.record([line("Butter", stage: .alias)])
        stats.reset()

        for stage in ReceiptResolutionStage.allCases {
            XCTAssertEqual(ReceiptResolutionStats(defaults: defaults).counts(for: stage), ReceiptResolutionStats.Counts())
        }
    }

    // MARK: - AC-12: nur Zahlen, keine Namen

    func testStoredValueContainsNoLineNames() throws {
        let stats = ReceiptResolutionStats(defaults: defaults)
        var l = line("Zebrastreifenkuchen", final: "Eindeutigerneuername", stage: .history)
        l.originalName = "ROHTEXTGEHEIM"
        stats.record([l])

        let data = try XCTUnwrap(defaults.data(forKey: "smartcart.receiptResolutionStats.v1"))
        let raw = String(decoding: data, as: UTF8.self)

        XCTAssertFalse(raw.contains("Zebrastreifenkuchen"))
        XCTAssertFalse(raw.contains("Eindeutigerneuername"))
        XCTAssertFalse(raw.contains("ROHTEXTGEHEIM"))
        XCTAssertTrue(raw.contains("history"), "Stufenschlüssel steht drin")
    }

    // MARK: - AC-14: mergeAIReresolution setzt Stufe und resolvedName

    func testMergeAIReresolutionSetsStageAndResolvedNameOnlyAtTargetedIndices() {
        var untouched = EditableReceiptLine(name: "Butter", price: 1.49, originalName: "Butter")
        untouched.stage = .alias
        untouched.resolvedName = "Butter"
        var target = EditableReceiptLine(name: "MDHSZ", price: 1.99, originalName: "MDHSZ")
        target.stage = .rawText
        target.resolvedName = "MDHSZ"
        var resolved = ResolvedReceiptLine(
            name: "Mozzarella", originalName: "MDHSZ", price: 1.99, quantity: 1, unit: "",
            suggestions: [], matchedItemID: nil, resolvedByAI: true)
        resolved.stage = .ai

        let merged = EditableReceiptLine.mergeAIReresolution(into: [untouched, target], resolved: [resolved], at: [1])

        XCTAssertEqual(merged[0].stage, .alias, "Nicht ausgewählte Zeile unangetastet")
        XCTAssertEqual(merged[0].resolvedName, "Butter")
        XCTAssertEqual(merged[1].stage, .ai)
        XCTAssertEqual(merged[1].resolvedName, "Mozzarella")
    }
}
