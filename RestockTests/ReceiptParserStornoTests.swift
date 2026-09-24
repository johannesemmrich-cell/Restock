import XCTest
@testable import Restock

/// Beweist den Fix für einen von einem echten DM-Kassenbon gemeldeten Bug (13.08.2026): eine
/// vom Kassierer falsch gescannte und per "ZEILENSTORNO" korrigierte Position (hier: der falsche
/// CO2-Zylinder wurde storniert und durch den richtigen ersetzt) blieb in den erkannten
/// Positionen stehen, während die stornierende Negativ-Zeile spurlos verworfen wurde (sie
/// scheiterte am `price > 0.05`-Positivitäts-Check) — der Nutzer hätte den STORNIERTEN, nie
/// bezahlten Artikel fälschlich in seiner Liste gehabt. Zusätzlich enthielt derselbe Bon eine
/// MwSt-Aufschlüsselungszeile mit numerischer Kennung ("1=19,00% 25,45 21,39 4,06"), die als
/// Phantom-Position erkannt wurde — Vorgänger-Fix deckte nur Buchstaben-Kennungen ("A=", "B=") ab.
///
/// Erwartung laut Nutzer: nur die drei tatsächlich bezahlten Positionen — Toilettenpapier 3,95€,
/// Flaschenbürste 1,95€, CO2-Zylinder (Ivorell) 19,55€. Summe laut Bon: 25,45€.
final class ReceiptParserStornoTests: XCTestCase {

    private static let dmLines: [String] = [
        "dm-drogerie markt",
        "Eschersheimer Landstr. 178-182",
        "60322 Frankfurt am Main",
        "13.08.2026 17:56 D364/2 004566/20 5744",
        "Hakle ToiPa Traumweich 8x130Bl    3,95",
        "babylove Prem. Fl.buerste 1St     1,95",
        "Ivorell CO2 Zylinder 425g         5,55",
        "ZEILENSTORNO",
        "Ivorell CO2 Zylinder 425g        -5,55",
        "Kauf-CO2-Zylinder Duo            28,75",
        "ZEILENSTORNO",
        "Kauf-CO2-Zylinder Duo           -28,75",
        "Kauf-CO2-Zylinder Ivorell        19,55",
        "Rückgabe CO2-Leerzylinder         0,00",
        "ZEILENSTORNO",
        "Rückgabe CO2-Leerzylinder         0,00",
        "SUMME EUR                        25,45",
        "Zyl:Tausch 5,55€ / Rück -",
        "AMEX EUR                        -25,45",
        "MwSt-Satz    Brutto    Netto    MwSt",
        "1=19,00%     25,45     21,39     4,06",
    ]

    func testOnlyTheThreeActuallyPurchasedItemsSurvive() {
        let result = ReceiptParserService.parse(Self.dmLines)
        XCTAssertEqual(
            result.count, 3,
            "Erwartet: nur Toilettenpapier, Flaschenbürste, CO2-Zylinder — stornierte Positionen und die MwSt-Tabellenzeile müssen verschwinden. Erkannt: \(result.map { "\($0.name)=\($0.price)" })"
        )
    }

    func testCorrectItemsAndPricesSurvive() throws {
        let result = ReceiptParserService.parse(Self.dmLines)

        func price(for nameContains: String) throws -> Double {
            try XCTUnwrap(result.first { $0.name.lowercased().contains(nameContains.lowercased()) }, "Keine Position mit '\(nameContains)' erkannt").price
        }

        XCTAssertEqual(try price(for: "Toi"), 3.95, accuracy: 0.001, "Toilettenpapier (Hakle ToiPa) muss mit 3,95€ erhalten bleiben")
        XCTAssertEqual(try price(for: "buerste"), 1.95, accuracy: 0.001, "Flaschenbürste muss mit 1,95€ erhalten bleiben")
        XCTAssertEqual(try price(for: "Ivorell"), 19.55, accuracy: 0.001, "Der finale (nicht stornierte) CO2-Zylinder muss mit 19,55€ erhalten bleiben")
    }

    func testStornoedItemsDoNotAppear() {
        let result = ReceiptParserService.parse(Self.dmLines)
        XCTAssertFalse(result.contains { abs($0.price - 5.55) < 0.001 }, "Der stornierte 5,55€-Zylinder darf nicht mehr in den Positionen sein")
        XCTAssertFalse(result.contains { abs($0.price - 28.75) < 0.001 }, "Das stornierte 28,75€-Zylinder-Duo darf nicht mehr in den Positionen sein")
    }

    func testVatSummaryRowWithNumericCodeIsNotMistakenForAnItem() {
        let result = ReceiptParserService.parse(Self.dmLines)
        XCTAssertFalse(result.contains { abs($0.price - 4.06) < 0.001 }, "Die MwSt-Tabellenzeile ('1=19,00% ... 4,06') darf nicht als Produktposition erkannt werden")
    }

    /// Non-Regression: eine STORNO-Zeile ohne passende vorherige Position darf nicht crashen oder
    /// eine falsche Position entfernen.
    func testStornoWithoutPriorMatchIsHarmless() {
        let lines = ["ZEILENSTORNO", "Irgendwas Unbekanntes  1,00"]
        let result = ReceiptParserService.parse(lines)
        XCTAssertTrue(result.isEmpty, "Eine Storno-Zeile ohne vorherige passende Position darf nichts hinzufügen")
    }

    /// Regressionstest für Issue #24 (Adversary-Dialog zu #9, Finding F-C): folgt auf eine
    /// STORNO-Zeile eine reine Mengen-/Gewichts-Bestätigungszeile ("-4 Stk x 0,39"), darf daraus
    /// keine Phantom-Position mit dem Zeilentext als Namen entstehen — die Zeile läuft sonst am
    /// `pendingStornoCancel`-Schutz vorbei in den `" x "`-Zweig.
    func testConfirmationLineAfterStornoDoesNotBecomePhantomPosition() {
        let lines = ["GOUDA JUNG 1,65 B", "LAUGENBROETCHEN 1,56 B", "STORNO", "-4 Stk x 0,39"]
        let result = ReceiptParserService.parse(lines)
        XCTAssertEqual(
            result.count, 2,
            "Erwartet: nur Gouda und Laugenbrötchen — die Bestätigungszeile nach STORNO darf keine eigene Position werden. Erkannt: \(result.map { "\($0.name)=\($0.price)" })"
        )
        XCTAssertFalse(result.contains { $0.name.contains("Stk x") }, "Die Bestätigungszeile darf nicht als Positionsname auftauchen")
    }
}
