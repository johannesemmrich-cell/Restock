import XCTest
@testable import Restock

/// Beweist, dass ein echter Rewe-eBon (vom Nutzer als PDF bereitgestellt, 13.08.2026) vom
/// bestehenden, generischen `ReceiptParserService.parseClassic`-Pfad korrekt geparst wird —
/// sobald der Text überhaupt ankommt. Root Cause des gemeldeten "Kassenbon-Scan funktioniert nur
/// bei Lidl Plus"-Bugs war NICHT der Parser (siehe `RestockShareExtension/ShareViewController.swift`-
/// Fix: die Share Extension akzeptierte bisher nur Bilder, Rewes digitaler eBon kommt aber als PDF).
/// Dieser Test deckt die reine Text-Parsing-Seite ab: exakt die Zeilen, die
/// `PDFDocument.page(at:).string` für diesen Bon liefert (Leerzeichen-Layout wie im Original-PDF,
/// EIN Leerzeichen zwischen Name und Preis statt Visions 2+-Leerzeichen-Spaltenrekonstruktion —
/// prüft damit gezielt den `looseRegex`-Fallback in `parseClassic`, nicht nur `tightRegex`).
final class ReceiptParserReweTests: XCTestCase {

    /// Rohzeilen des Bons in Original-Reihenfolge, inkl. Kopf-/Fußzeilen — der Parser muss diese
    /// selbst über die Admin-Wortliste herausfiltern, wie bei jedem anderen Bon auch.
    private static let reweLines: [String] = [
        "REWE MARKT",
        "Eckenheimer Landstr. 183",
        "60322 Frankfurt",
        "UID Nr.: DE812706034",
        "EUR",
        "GOUDA JUNG 1,65 B",
        "LAUGENBROETCHEN 1,56 B",
        "4 Stk x 0,39",
        "MAULTASCHEN TR. 2,29 B",
        "KR.BUTTERBAGUETT 0,99 B",
        "BANANE CHIQUITA 1,76 B",
        "0,706 kg x 2,49 EUR/kg",
        "MANDELN GEROES. 3,79 B",
        "EIER FH RES S-L 2,29 B",
        "IRISCHE BUTTER 1,79 B",
        "SKYR NATUR 1,99 B",
        "BIO HAFERFL.GBL. 0,95 B",
        "LUNGO CREMA 3,99 B",
        "ESPR DELIZIOSO 3,99 B",
        "SPUELM ZITRUS 0,95 A",
        "GEFRIERBEUTEL 3L 1,45 A",
        "--------------------------------------",
        "SUMME EUR 29,44",
        "======================================",
        "Geg. American Express EUR 29,44",
        "Steuer % Netto Steuer Brutto",
        "A= 19,0% 2,02 0,38 2,40",
        "B= 7,0% 25,27 1,77 27,04",
        "Gesamtbetrag 27,29 2,15 29,44",
    ]

    func testAllFourteenPositionsAreRecognized() {
        let result = ReceiptParserService.parse(Self.reweLines)
        XCTAssertEqual(result.count, 14, "Erwartet: alle 14 echten Positionen erkannt, Kopf-/Fuß-/Steuerzeilen und die redundante Mengen-Bestätigungszeile herausgefiltert. Erkannt: \(result.map(\.name))")
    }

    func testItemNamesAndPricesAreCorrect() throws {
        let result = ReceiptParserService.parse(Self.reweLines)

        func price(for nameContains: String) throws -> Double {
            try XCTUnwrap(result.first { $0.name.lowercased().contains(nameContains.lowercased()) }, "Keine Position mit '\(nameContains)' erkannt").price
        }

        XCTAssertEqual(try price(for: "gouda"), 1.65, accuracy: 0.001)
        XCTAssertEqual(try price(for: "maultaschen"), 2.29, accuracy: 0.001)
        XCTAssertEqual(try price(for: "mandeln"), 3.79, accuracy: 0.001)
        XCTAssertEqual(try price(for: "skyr"), 1.99, accuracy: 0.001, "Der Rewe-Skyr-Preis (1,99€) darf nicht mit dem Lidl-Preis verwechselt/aufsummiert werden")
        XCTAssertEqual(try price(for: "spuelm"), 0.95, accuracy: 0.001)
    }

    /// Diese beiden Positionen haben eine zweite Mengen-/Gewichts-Zeile DIREKT DARUNTER, die den
    /// bereits auf der Namenszeile stehenden Gesamtpreis nur bestätigt (4×0,39=1,56;
    /// 0,706kg×2,49€/kg≈1,76€) — anders als das Lidl-Format, wo der Gesamtpreis NUR aus dieser
    /// zweiten Zeile berechenbar ist. Der bereits korrekte Preis von der Namenszeile darf durch
    /// die Zusatzzeile nicht verändert/verdoppelt werden.
    func testQuantityAndWeightFollowupLinesDoNotOverrideAlreadyKnownTotal() throws {
        let result = ReceiptParserService.parse(Self.reweLines)

        let broetchen = try XCTUnwrap(result.first { $0.name.lowercased().contains("laugenbroetchen") })
        XCTAssertEqual(broetchen.price, 1.56, accuracy: 0.01)

        let banane = try XCTUnwrap(result.first { $0.name.lowercased().contains("banane") })
        XCTAssertEqual(banane.price, 1.76, accuracy: 0.01)
    }

    func testNoAdminOrTaxLinesLeakIntoResults() {
        let result = ReceiptParserService.parse(Self.reweLines)
        let names = result.map { $0.name.lowercased() }
        for forbidden in ["summe", "gesamtbetrag", "steuer", "rewe markt", "uid nr", "geg. american express"] {
            XCTAssertFalse(names.contains { $0.contains(forbidden) }, "Admin-/Steuerzeile '\(forbidden)' wurde fälschlich als Produkt erkannt")
        }
    }
}
