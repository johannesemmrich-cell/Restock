import XCTest
import SwiftData
@testable import Restock

/// Schein-Modell: antwortet über `answer(prompt)` und merkt sich jeden Prompt.
private final class FakeModel: ReceiptNameLanguageModel, @unchecked Sendable {
    let isAvailable: Bool
    private let answer: @Sendable (String) -> String?
    private let lock = NSLock()
    private var _prompts: [String] = []

    init(isAvailable: Bool = true, answer: @escaping @Sendable (String) -> String?) {
        self.isAvailable = isAvailable
        self.answer = answer
    }

    var prompts: [String] {
        lock.withLock { _prompts }
    }

    func respond(to prompt: String) async -> String? {
        lock.withLock { _prompts.append(prompt) }
        return answer(prompt)
    }
}

/// Prüft Stufe 5 der Bon-Namensauflösung (Apple Intelligence) als ganze Kette — Prompt,
/// `sanitize`, Nachprüfung über mehrere Zeilen und das Ergebnis, das in der Bonprüfung ankommt —
/// mit einem Schein-Modell über die Naht `ReceiptNameLanguageModel`. Das echte Modell läuft im
/// Simulator/CI nicht; was es tatsächlich antwortet, misst die lokale Auswertung aus dem
/// Folge-Issue, nicht dieser Test.
///
/// Daten: der dm-Bon vom 05.10.2026 (gemeldet 18.10.2026, alle Zeilen wurden zu "Bröt.") und
/// der Lidl-Bon aus `ReceiptParserLidlFullReceiptTests`.
@MainActor
final class ReceiptAIResolutionChainTests: XCTestCase {

    /// Positionen des dm-Bons wie gedruckt (Name, Zeilensumme).
    static let dmLines: [ReceiptLine] = ([
        ("Soft&Sicher Pocket 6x8St", 0.85), ("dmBio Espresso gemahlen 250g", 4.25),
        ("Ricola Bonbon Salbei", 1.95), ("Mentos Gum 3 Fruity Fresh", 1.25),
        ("dmBio Noisette Schokol", 1.10), ("Schoko Lolli Vollmilch", 1.70),
        ("dmBio Schneebälle Marzipan 30g", 0.95), ("dmBio Schokolierte Brezeln ZB", 0.65),
        ("dmBio Gemüsebrühe Nachfüllbt.", 2.45), ("Elmex Zahncr. Sens. Prof. 75ml", 6.45),
        ("Balea Tuchmaske Ultra Sensitiv", 1.45), ("lavera Lippenbalsam Basis Sens", 1.95),
        ("ShirinBeauty LipOil Strawberry", 5.95), ("SEINZ. Tuchmaske Hydro Effect", 1.95),
        ("Balea Fuß-Maske Socken 1 Paar", 2.25), ("ebelin Scunchie Kugel 1St", 1.75),
    ] as [(String, Double)]).map { ReceiptLine(name: $0.0, price: $0.1) }

    private var container: ModelContainer!
    private var store: Store!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema(versionedSchema: SchemaV1.self)
        container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        store = Store(name: "dm", emoji: "🧴", colorHex: "#123456")
        container.mainContext.insert(store)
    }

    override func tearDown() {
        store = nil
        container = nil
        super.tearDown()
    }

    /// Indizes der Zeilen, die Stufe 5 erreichen (kein Alias, kein Wörterbuch). Ohne abgehakte
    /// Artikel und ohne Kaufhistorie entfallen Stufe 3 und 4.
    private func aiIndices(_ lines: [ReceiptLine]) -> [Int] {
        lines.indices.filter {
            ReceiptAliasService.shared.resolve(lines[$0].name) == nil
                && ReceiptParserService.expandAbbreviations(lines[$0].name) == nil
        }
    }

    private func resolve(
        _ lines: [ReceiptLine],
        records: [PurchaseRecord] = [],
        model: FakeModel,
        allowAI: Bool = true
    ) async -> [ResolvedReceiptLine] {
        await ReceiptResolutionService.resolve(
            parsed: lines, store: store, allRecords: records,
            allowAIResolution: allowAI, aiResolver: ReceiptNameAIResolver(model: model)
        )
    }

    /// Rohtext aus dem Prompt (erste Zeile, zwischen den Anführungszeichen).
    private nonisolated static func raw(in prompt: String) -> String {
        let firstLine = prompt.components(separatedBy: "\n").first ?? ""
        let parts = firstLine.components(separatedBy: "\"")
        return parts.count >= 2 ? parts[1] : ""
    }

    private func assertFallsBackToRawText(_ result: [ResolvedReceiptLine], _ indices: [Int], file: StaticString = #filePath, line: UInt = #line) {
        for index in indices {
            XCTAssertEqual(result[index].name, result[index].originalName, "Zeile \(index)", file: file, line: line)
            XCTAssertFalse(result[index].resolvedByAI, "Zeile \(index)", file: file, line: line)
            XCTAssertEqual(result[index].stage, .rawText, "Zeile \(index)", file: file, line: line)
        }
    }

    // MARK: - Der gemeldete Fehler

    /// K1: Das Modell antwortet für jede Zeile "Bröt." — keine Zeile darf das zeigen.
    func testSameAbbreviationForEveryLineNeverReachesReview() async {
        let model = FakeModel { _ in "Bröt." }
        let result = await resolve(Self.dmLines, model: model)
        let indices = aiIndices(Self.dmLines)

        XCTAssertGreaterThanOrEqual(indices.count, 10, "Der dm-Bon soll überwiegend Stufe 5 erreichen")
        XCTAssertEqual(model.prompts.count, indices.count)
        XCTAssertFalse(result.contains { $0.name == "Bröt." })
        assertFallsBackToRawText(result, indices)
    }

    /// K2: Nachgestellter Ablauf: "Bröt." steht als jüngster Kauf in der Historie und das Modell
    /// übernimmt den ersten eigenen Namen aus dem Prompt. "Bröt." darf gar nicht erst in den
    /// Prompt; der dann erste Name ("Salbeibonbons") darf nur bei der passenden Zeile bleiben.
    func testModelCopyingFirstKnownNameIsCaught() async {
        let now = Date()
        let broet = PurchaseRecord(itemName: "Bröt.", storeName: "Lidl")
        broet.date = now
        let salbei = PurchaseRecord(itemName: "Salbeibonbons", storeName: "dm")
        salbei.date = now.addingTimeInterval(-86_400)
        let model = FakeModel { prompt in
            guard let list = prompt.components(separatedBy: "sonst ignorieren): ").last,
                  prompt.contains("sonst ignorieren): ") else { return nil }
            return list.components(separatedBy: ", ").first
        }

        let result = await resolve(Self.dmLines, records: [broet, salbei], model: model)

        XCTAssertFalse(model.prompts.isEmpty)
        XCTAssertFalse(model.prompts.contains { $0.contains("Bröt.") }, "Kürzel darf nicht in den Prompt")
        XCTAssertTrue(model.prompts.allSatisfy { $0.contains("Salbeibonbons") })
        let ricola = result.first { $0.originalName == "Ricola Bonbon Salbei" }
        XCTAssertEqual(ricola?.name, "Salbeibonbons", "Wortbezug \"Sal\" → bleibt stehen")
        XCTAssertTrue(ricola?.resolvedByAI ?? false)
        let others = result.filter { $0.originalName != "Ricola Bonbon Salbei" && $0.name == "Salbeibonbons" }
        XCTAssertTrue(others.isEmpty, "Fremde Zeilen dürfen den kopierten Namen nicht tragen: \(others.map(\.originalName))")
    }

    // MARK: - Normale Antworten

    /// K3: Passende Antworten je Zeile kommen als KI-Vorschlag an (Stufe `.ai`, Kennzeichnung).
    func testDistinctAnswersAreApplied() async {
        let answers: [String: String] = [
            "Ricola Bonbon Salbei": "Salbeibonbons",
            "Mentos Gum 3 Fruity Fresh": "Kaugummi",
            "Balea Tuchmaske Ultra Sensitiv": "Tuchmaske",
            "SEINZ. Tuchmaske Hydro Effect": "Tuchmaske",
            "lavera Lippenbalsam Basis Sens": "Lippenbalsam",
        ]
        let model = FakeModel { answers[Self.raw(in: $0)] }
        let result = await resolve(Self.dmLines, model: model)

        for line in result {
            if let expected = answers[line.originalName], aiIndices([ReceiptLine(name: line.originalName, price: 0)]) == [0] {
                XCTAssertEqual(line.name, expected)
                XCTAssertTrue(line.resolvedByAI)
                XCTAssertEqual(line.stage, .ai)
            }
        }
        XCTAssertEqual(result.count, Self.dmLines.count)
        XCTAssertEqual(result.map(\.originalName), Self.dmLines.map(\.name), "Reihenfolge bleibt")
    }

    /// K4: Antworten werden bereinigt (Anführungszeichen, Leerraum).
    func testAnswersAreSanitized() async {
        let model = FakeModel { prompt in Self.raw(in: prompt) == "Mentos Gum 3 Fruity Fresh" ? "  \"Kaugummi\"\n" : nil }
        let result = await resolve(Self.dmLines, model: model)
        XCTAssertEqual(result.first { $0.originalName == "Mentos Gum 3 Fruity Fresh" }?.name, "Kaugummi")
    }

    // MARK: - Keine verwertbare Antwort

    /// K5: "kein Produkt", leere Antwort, mehrzeilige Antwort und Fehler → Rohtext.
    func testUnusableAnswersFallBackToRawText() async {
        for answer in ["KEIN_PRODUKT", "", "Salbei\nBonbons", nil] as [String?] {
            let model = FakeModel { _ in answer }
            let result = await resolve(Self.dmLines, model: model)
            assertFallsBackToRawText(result, aiIndices(Self.dmLines))
        }
    }

    /// K6: Modell nicht verfügbar oder Stufe 5 abgeschaltet (Teilen-Erweiterung) → kein Aufruf.
    func testModelIsNotCalledWhenUnavailableOrDisabled() async {
        let unavailable = FakeModel(isAvailable: false) { _ in "Kaugummi" }
        assertFallsBackToRawText(await resolve(Self.dmLines, model: unavailable), aiIndices(Self.dmLines))
        XCTAssertTrue(unavailable.prompts.isEmpty)

        let disabled = FakeModel { _ in "Kaugummi" }
        assertFallsBackToRawText(await resolve(Self.dmLines, model: disabled, allowAI: false), aiIndices(Self.dmLines))
        XCTAssertTrue(disabled.prompts.isEmpty)
    }

    // MARK: - Lidl-Bon aus den Parser-Tests

    /// K7: Der echte Parser liefert die Lidl-Positionen; nur Zeilen ohne Alias/Wörterbuch gehen
    /// ans Modell, jede mit ihrem Rohtext im Prompt; Wörterbuch-Zeilen bleiben unberührt.
    func testLidlReceiptOnlySendsUnresolvedLinesToModel() async {
        let parsed = ReceiptParserService.parse(ReceiptParserLidlFullReceiptTests.lidlLines)
        XCTAssertFalse(parsed.isEmpty)
        let model = FakeModel { _ in nil }
        let result = await resolve(parsed, model: model)

        let expectedRaw = aiIndices(parsed).map { parsed[$0].name }
        XCTAssertEqual(Set(model.prompts.map(Self.raw(in:))), Set(expectedRaw))
        for (index, line) in result.enumerated() where !expectedRaw.contains(parsed[index].name) {
            XCTAssertNotEqual(line.stage, .ai)
            XCTAssertNotEqual(line.stage, .rawText, "\(line.originalName) hätte vor Stufe 5 aufgelöst werden sollen")
        }
    }
}
