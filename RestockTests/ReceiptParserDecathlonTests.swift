import XCTest
@testable import Restock

/// Decathlon-Bon (vom Nutzer als PDF geteilt, 21.10.2026, „Dieser Kassenzettel konnte nicht erkannt
/// werden“). Decathlon druckt jede Position zweizeilig: Name, darunter Artikelnummer und Preis mit
/// angehängtem €, darunter eine RFID-Zeile. Vorher erkannte keiner der beiden Parser-Pfade eine
/// Position: der klassische Pfad kannte „Preis + €“ nicht, der Euro-Pfad greift nur bei
/// Spaltenlücke (2+ Leerzeichen), PDF-Text liefert aber ein Leerzeichen.
final class ReceiptParserDecathlonTests: XCTestCase {

    /// Zeilen wie aus `PDFDocument.page(at:).string` (ein Leerzeichen zwischen Spalten), gekürzt
    /// um den Zahlungsbeleg am Ende, der hinter der MwSt-Tabelle ohnehin abgeschnitten wird.
    static let decathlonLines: [String] = [
        "DECATHLON DUSSELDORF",
        "Schadowstraße 77-79",
        "40212 Dusseldorf",
        "www.decathlon.de",
        "Kartennummer: 2090619448827",
        "Verkauf",
        "TREK FOOD PASTA BOLOGNESE No Size",
        "4037949 8.99€",
        "RFID: 2744945",
        "TREK FOOD PASTA BOLOGNESE No Size",
        "4037949 8.99€",
        "RFID: 2744944",
        "1P 100 HEVA U BLACK* DE 36 / FR 38",
        "2745750 9.99€",
        "RFID: 2735553",
        "Gesamt 27.97€",
        "3 Artikel",
        "Karte 27.97€",
        "% MwSt. MwSt. Gesamt Nettosumme",
        "19% 1.59€ 8.40€",
        "7% 1.18€ 16.80€",
        "Kasse: 5 14/08/2026 12:48:23",
        "Summe € 27,97",
        "Vielen Dank",
    ]

    private func assertDecathlonItems(_ parsed: [ReceiptLine], file: StaticString = #filePath, line: UInt = #line) {
        let byName = Dictionary(parsed.map { ($0.name.lowercased(), $0.price) }, uniquingKeysWith: { a, _ in a })
        XCTAssertEqual(byName["trek food pasta bolognese no size"], 8.99, "Trek Food fehlt: \(parsed.map(\.name))", file: file, line: line)
        XCTAssertEqual(byName["1p 100 heva u black* de 36 / fr 38"], 9.99, "Badehose fehlt: \(parsed.map(\.name))", file: file, line: line)
        for forbidden in ["karte", "rfid", "gesamt", "artikel", "decathlon", "verkauf", "mwst"] {
            XCTAssertFalse(byName.keys.contains { $0.contains(forbidden) },
                           "Verwaltungszeile '\(forbidden)' als Position erkannt: \(parsed.map(\.name))", file: file, line: line)
        }
    }

    func testSingleSpacePDFTextIsRecognized() {
        assertDecathlonItems(ReceiptParserService.parse(Self.decathlonLines))
    }

    /// Dieselben Zeilen mit Spaltenlücke (Vision-Rekonstruktion eines Fotos) laufen über den Euro-Pfad.
    func testColumnGapVariantIsRecognized() {
        let lines = Self.decathlonLines.map {
            $0.replacingOccurrences(of: #"^(\d{5,}) "#, with: "$1       ", options: .regularExpression)
              .replacingOccurrences(of: #"^(Gesamt|Karte) "#, with: "$1    ", options: .regularExpression)
        }
        assertDecathlonItems(ReceiptParserService.parse(lines))
    }

    /// PDF-Text mit Tabulator zwischen Artikelnummer und Preis.
    func testTabSeparatedVariantIsRecognized() {
        let lines = Self.decathlonLines.map {
            $0.replacingOccurrences(of: #"^(\d{5,}) "#, with: "$1\t", options: .regularExpression)
        }
        assertDecathlonItems(ReceiptParserService.parse(lines))
    }

    /// Eine Artikelnummer-Preis-Zeile ohne Namenszeile davor wird keine Position.
    func testArticleNumberPriceLineWithoutNameIsIgnored() {
        XCTAssertTrue(ReceiptParserService.parse(["4037949 8.99€"]).isEmpty)
    }
}
