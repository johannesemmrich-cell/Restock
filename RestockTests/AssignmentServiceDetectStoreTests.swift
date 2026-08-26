import XCTest
@testable import Restock

/// Beweist zwei von der `verify-changes`-Runde gefundene Lücken in `AssignmentService.detectStore`
/// (24.08.2026), NACHDEM die Suche zuvor auf den kompletten Bon ausgeweitet wurde (siehe
/// ReceiptParserLidlFullReceiptTests):
///
/// 1. Ein Unentschieden zwischen zwei VERSCHIEDENEN, tatsächlich im Bon vorkommenden Ladennamen
///    (z. B. "Lidl" im Fußbereich vs. "Frankfurt" in der Adresse) durfte nicht mehr von der
///    unspezifizierten Kandidaten-Array-Reihenfolge abhängen — beide Reihenfolgen müssen dasselbe,
///    richtige Ergebnis liefern.
/// 2. Die Ausweitung auf den kompletten Bon darf nicht dazu führen, dass die MwSt-Tabellen-Spalte
///    "Netto" (auf praktisch jedem deutschen Bon) das eingebaute Laden-Preset "Netto" mit einem
///    perfekten Score trifft, unabhängig vom tatsächlichen Laden.
final class AssignmentServiceDetectStoreTests: XCTestCase {

    private func store(_ name: String) -> Store {
        Store(name: name, emoji: "🛒", colorHex: "#123456")
    }

    // MARK: - Reales Bon-Fixture (siehe ReceiptParserLidlFullReceiptTests)

    func testDetectsLidlRegardlessOfCandidateOrder_LidlFirst() {
        let lidl = store("Lidl")
        let frankfurt = store("Frankfurt")
        let result = AssignmentService.detectStore(fromReceiptLines: ReceiptParserLidlFullReceiptTests.lidlLines, candidates: [lidl, frankfurt])
        XCTAssertEqual(result?.name, "Lidl")
    }

    func testDetectsLidlRegardlessOfCandidateOrder_FrankfurtFirst() {
        let lidl = store("Lidl")
        let frankfurt = store("Frankfurt")
        // Umgekehrte Reihenfolge derselben zwei Kandidaten -- das Ergebnis darf sich NICHT ändern.
        let result = AssignmentService.detectStore(fromReceiptLines: ReceiptParserLidlFullReceiptTests.lidlLines, candidates: [frankfurt, lidl])
        XCTAssertEqual(result?.name, "Lidl", "Ergebnis darf nicht von der Kandidaten-Reihenfolge abhängen")
    }

    func testDetectsLidlNotNetto_NettoFirst() {
        let lidl = store("Lidl")
        let netto = store("Netto")
        let result = AssignmentService.detectStore(fromReceiptLines: ReceiptParserLidlFullReceiptTests.lidlLines, candidates: [netto, lidl])
        XCTAssertEqual(result?.name, "Lidl", "Die MwSt-Tabellen-Spalte 'Netto' darf das echte 'Lidl' nicht verdrängen")
    }

    func testDetectsLidlNotNetto_LidlFirst() {
        let lidl = store("Lidl")
        let netto = store("Netto")
        let result = AssignmentService.detectStore(fromReceiptLines: ReceiptParserLidlFullReceiptTests.lidlLines, candidates: [lidl, netto])
        XCTAssertEqual(result?.name, "Lidl")
    }

    /// Wenn "Netto" der EINZIGE Kandidat ist und der Bon (wie im Lidl-Fixture) gar nicht von Netto
    /// stammt, darf die MwSt-Tabellen-Spalte "Netto" trotzdem keinen Treffer erzeugen -- sonst
    /// würde JEDER Nutzer mit "Netto" als konfiguriertem Laden JEDEN Bon fälschlich als Netto
    /// erkannt bekommen.
    func testNettoAloneDoesNotFalsePositiveOnVATTable() {
        let netto = store("Netto")
        let result = AssignmentService.detectStore(fromReceiptLines: ReceiptParserLidlFullReceiptTests.lidlLines, candidates: [netto])
        XCTAssertNil(result, "Die MwSt-Tabellen-Spalte 'Netto' darf allein keinen Laden-Treffer erzeugen")
    }

    /// Regressions-Schutz: ein Bon, der WIRKLICH von Netto stammt (Name lesbar im Kopfbereich),
    /// muss weiterhin korrekt erkannt werden -- der Admin-Wort-Filter gilt nur für die
    /// Fallback-Stufe (kompletter Bon), nicht für den unveränderten Kopfbereichs-Scan.
    func testGenuineNettoReceiptStillDetectedViaHeader() {
        let lines = [
            "Netto Marken-Discount",
            "Musterstraße 1",
            "12345 Musterstadt",
            "Joghurt  0,89 A",
            "zu zahlen  0,89",
        ]
        let netto = store("Netto")
        let lidl = store("Lidl")
        let result = AssignmentService.detectStore(fromReceiptLines: lines, candidates: [netto, lidl])
        XCTAssertEqual(result?.name, "Netto", "Ein echter, im Kopfbereich lesbarer Netto-Ladenname muss weiter erkannt werden")
    }

    func testNoMatchReturnsNilRatherThanGuessing() {
        let result = AssignmentService.detectStore(fromReceiptLines: ["Irgendein Bon", "Artikel  1,00"], candidates: [store("Lidl"), store("Netto")])
        XCTAssertNil(result)
    }

    func testEmptyCandidatesReturnsNil() {
        XCTAssertNil(AssignmentService.detectStore(fromReceiptLines: ReceiptParserLidlFullReceiptTests.lidlLines, candidates: []))
    }
}
