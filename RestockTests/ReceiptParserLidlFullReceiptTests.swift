import XCTest
@testable import Restock

/// Reproduziert den am 24.08.2026 gemeldeten Bug anhand eines echten Lidl-Bons (vom Nutzer als
/// Foto bereitgestellt): der Scan erkannte u. a. VIER Phantom-Positionen namens "Pizza Baguette"
/// zu 5,45€/27,46€/32,91€/35,87€ — Zahlen, die exakt der MwSt-Tabelle + Bon-Summe entsprechen
/// (B-Netto/A-Netto/Summe-Netto/Summe-Brutto), nicht irgendeinem echten Artikel. Viele echte
/// Artikel fehlten komplett.
///
/// Die Zeilen unten sind eine bestmögliche, realistische Rekonstruktion dessen, was
/// `ReceiptParserService.reconstructLines` aus Visions Text-Beobachtungen für dieses Bon-Foto
/// bauen würde (Spalten-Zeilen mit 2+ Leerzeichen zwischen Name/Preis, wie in den bereits
/// bestehenden Tests dieser Art) — KEIN tatsächlicher Vision-Rohdump (den hat niemand
/// aufgezeichnet). Das LIDL-Logo ganz oben ist bewusst NICHT als Zeile enthalten: es ist auf dem
/// Foto ein stilisiertes Bild, kein maschinenlesbarer Text, Vision liefert dafür keine
/// Text-Beobachtung.
final class ReceiptParserLidlFullReceiptTests: XCTestCase {

    static let realItemNames = [
        "banane", "nektarinen", "bistrobaguet", "gouda", "schlagsahne",
        "maultas", "penne", "spaghetti", "eier", "haferflocken",
        "olivenöle", "red bull", "mandelkerne", "brötchen",
    ]

    static let lidlLines: [String] = [
        "Friedberger Landstrasse 298",
        "60389 Frankfurt/Main, Nordend West",
        "EUR",
        "Banane lose  0,82 A",
        "0,638 kg x 1,29  EUR/kg",
        "Nektarinen  1,89 A",
        "BistroBaguet. Salami  4,38 A",
        "Gouda Scheiben 48%  2,45 A",
        "Schlagsahne 30%  0,89 A",
        "BürgerSchwä.Maultas.  2,29 x  3  6,87 A",
        "Preisvorteil  -1,80",
        "Penne Rigate  0,69 A",
        "Spaghetti  0,69 A",
        "Eier Hessen Freilan.  2,29 A",
        "Bioland Haferflocken  0,85 A",
        "Olivenöle natur  4,99 A",
        "Red Bull E. Original  4,99 B",
        "Pfand 1,50 M",
        "Mandelkerne  2,49 x  2  4,98 A",
        "Rabatt Mandelkerne  -1,00",
        "Brötchen Lauge  0,39 x  2  0,78 A",
        "Lidl Plus Rabatt  -0,39",
        "zu zahlen  35,87",
        "Kreditkarte  35,87",
        "MWST%  MWST +  Netto = Brutto",
        "A  7 %  1,92  27,46  29,38",
        "B  19 %  1,04  5,45  6,49",
        "Summe  2,96  32,91  35,87",
        "Gesamter Preisvorteil",
        "3,19 EUR gespart",
        "Mit Lidl Plus",
        "0,39 EUR gespart",
        "TSE Transaktionsnummer: 2111061",
        "Seriennr. Kasse: LDL-000-1843-2",
        "Seriennr. TSE: MkveLvNfCJoeKKRB13xUI1YYGKp5/LRD0NvfDbEg0Hc=",
        "Prüfwert: 4j3sz6tr0QKcVi9Ba7w5IAiN/hnmbVMdIEneQefmfckpb8XfdIJK/gkWXhPDiNLgUYFr98Wyop",
        "oionkn86rgiEImakdsbqV8JuonTwS04+SusX2W+TIOr4uF9OBTKh/9",
        "Signaturzähler: 4292728",
        "2026-08-24T09:44:51.000Z",
        "2026-08-24T09:45:31.000Z",
        "1843  619046/02  24.08.26 11:44",
        "UST-ID-NR: DE813388807",
        "K-U-N-D-E-N-B-E-L-E-G",
        "Bezahlung American Express",
        "Betrag  35,87 EUR",
        "24.08.2026  11:44",
        "T-ID 60158601",
        "TA-Nr. 146189",
        "Beleg-Nr. 8899",
        "Kartennr.  ##########1002 00",
        "Kontaktlos Chip  Online",
        "VU-Nummer  9506755750",
        "Autorisierungsnummer  050783",
        "Autorisierungsantwortcode  00",
        "EMV-Daten:  A00000002501/00",
        "AS-Proc-Code = 00 075 00",
        "Capt.-Ref.= 0825",
        "AID59: 861717",
        "00 GEN.NR: 17  35,87",
        "Zahlung erfolgt",
        "VIELEN DANK FÜR DEINEN EINKAUF!",
        "Kostenlose Servicenummer:",
        "0800 5435 7587",
        "www.lidl.de",
        "Eingelöste Coupons",
        "1+1",
        "Laugenbrötchen",
        "Erhaltene Punkte",
        "+38 Lidl Punkte",
        "Punkte sind verfügbar am 25.08.2026",
        "Einkauf getätigt in",
        "Nordend-West",
        "Friedberger Landstr. 298",
        "60389 Frankfurt",
    ]

    /// Diagnose-Test, kein reiner Pass/Fail-Beweis: druckt das TATSÄCHLICHE aktuelle
    /// `parse()`-Ergebnis in die Testausgabe, damit man beim ersten Lauf sieht, was wirklich
    /// passiert (statt nur "rot"/"grün"), bevor gezielt nachgebessert wird.
    func testDiagnosticDumpOfCurrentParseResult() {
        let result = ReceiptParserService.parse(Self.lidlLines)
        for line in result {
            print("PARSED: \(line.name) | price=\(line.price) qty=\(line.quantity) weightBasis=\(line.weightBasis ?? -1)")
        }
        print("TOTAL POSITIONS: \(result.count)")
    }

    func testNoPhantomItemsFromVATTableOrTrailer() {
        let result = ReceiptParserService.parse(Self.lidlLines)
        let names = result.map { $0.name.lowercased() }

        // Keine Position darf aus der MwSt-Tabelle/Fußzeile stammen -- erkennbar an einem Preis,
        // der zu einer der vier Tabellen-/Summenzahlen passt, aber zu KEINEM echten Artikelnamen
        // gehört.
        let phantomPrices: [Double] = [27.46, 5.45, 32.91]
        for price in phantomPrices {
            let matchesRealItem = result.contains { line in
                abs(line.price - price) < 0.01 && Self.realItemNames.contains { line.name.lowercased().contains($0) }
            }
            let hasPhantom = result.contains { abs($0.price - price) < 0.01 } && !matchesRealItem
            XCTAssertFalse(hasPhantom, "Preis \(price) taucht als Position auf, die zu keinem echten Artikel gehört -- vermutlich ein Phantom aus der MwSt-Tabelle. Ergebnis: \(result.map { "\($0.name)=\($0.price)" })")
        }

        for forbidden in ["mwst", "tse", "transaktionsnummer", "autorisierung", "gen.nr", "beleg-nr",
                          "signaturzähler", "prüfwert", "kartennr", "emv", "proc-code", "capt",
                          "kontaktlos", "servicenummer", "coupons", "punkte", "filiale"] {
            XCTAssertFalse(names.contains { $0.contains(forbidden) }, "Metadaten-Fragment '\(forbidden)' wurde fälschlich als Produktname erkannt")
        }
    }

    func testAllFourteenRealItemsAreFound() {
        let result = ReceiptParserService.parse(Self.lidlLines)
        var missing: [String] = []
        for expected in Self.realItemNames {
            if !result.contains(where: { $0.name.lowercased().contains(expected) }) {
                missing.append(expected)
            }
        }
        XCTAssertTrue(missing.isEmpty, "Fehlende echte Artikel: \(missing). Erkannt: \(result.map(\.name))")
    }

    /// Härtungs-Test für den vermuteten echten Auslöser des gemeldeten Bugs: ein Foto-Scan liest
    /// vermutlich "zu zahlen" NICHT sauber (Unschärfe/Schatten/Blendung) — simuliert hier, indem
    /// die "zu zahlen"/"Kreditkarte"-Zeilen komplett aus dem Fixture entfernt werden. Ohne den
    /// zusätzlichen "mwst"-Auslöser (siehe `triggersPastItemSection`) würde die komplette
    /// Zahlungs-/MwSt-Metadaten-Sektion durchrutschen. Der MwSt-Tabellen-Header ("MWST%  MWST +
    /// Netto = Brutto") bleibt als zweite, unabhängige Absicherung übrig.
    func testStillNoPhantomItemsWhenZuZahlenLineIsMissing() {
        let linesWithoutZuZahlen = Self.lidlLines.filter {
            !$0.lowercased().contains("zu zahlen") && !$0.lowercased().contains("kreditkarte")
        }
        // Setup-Annahme prüfen: die beiden Auslöser-Zeilen wurden wirklich entfernt.
        XCTAssertEqual(linesWithoutZuZahlen.count, Self.lidlLines.count - 2)

        let result = ReceiptParserService.parse(linesWithoutZuZahlen)
        let phantomPrices: [Double] = [27.46, 5.45, 32.91, 35.87]
        for price in phantomPrices {
            let matchesRealItem = result.contains { line in
                abs(line.price - price) < 0.01 && Self.realItemNames.contains { line.name.lowercased().contains($0) }
            }
            let hasPhantom = result.contains { abs($0.price - price) < 0.01 } && !matchesRealItem
            XCTAssertFalse(hasPhantom, "Auch ohne lesbare 'zu zahlen'-Zeile darf \(price) nicht als Phantom-Position auftauchen (mwst-Auslöser als Absicherung). Ergebnis: \(result.map { "\($0.name)=\($0.price)" })")
        }
    }

    // MARK: - detectedTotal() Härtung (verify-changes, 24.08.2026)

    func testDetectedTotalFindsAmountNormally() throws {
        let total = try XCTUnwrap(ReceiptParserService.detectedTotal(from: Self.lidlLines))
        XCTAssertEqual(total, 35.87, accuracy: 0.001)
    }

    /// Beweist die Härtung von `detectedTotal`: fehlt "zu zahlen"/"Kreditkarte" (derselbe
    /// simulierte OCR-Fehler wie oben), muss der Betrag trotzdem über die unabhängige
    /// "Betrag"-Zeile aus dem Kartenzahlungs-Beleg gefunden werden, statt den "Summe stimmt
    /// nicht"-Hinweis stillschweigend ausfallen zu lassen.
    func testDetectedTotalStillFoundWhenZuZahlenLineIsMissing() throws {
        let linesWithoutZuZahlen = Self.lidlLines.filter {
            !$0.lowercased().contains("zu zahlen") && !$0.lowercased().contains("kreditkarte")
        }
        let total = try XCTUnwrap(ReceiptParserService.detectedTotal(from: linesWithoutZuZahlen), "Betrag muss auch ohne 'zu zahlen'/'Kreditkarte' über die 'Betrag'-Zeile gefunden werden")
        XCTAssertEqual(total, 35.87, accuracy: 0.001)
    }

    func testMultiBuyLinesHaveCorrectQuantityInFullReceiptContext() throws {
        let result = ReceiptParserService.parse(Self.lidlLines)

        let maultaschen = try XCTUnwrap(result.first { $0.name.lowercased().contains("maultas") })
        XCTAssertEqual(maultaschen.quantity, 3, accuracy: 0.001)
        XCTAssertEqual(maultaschen.price, 6.87, accuracy: 0.01)

        let mandeln = try XCTUnwrap(result.first { $0.name.lowercased().contains("mandel") })
        XCTAssertEqual(mandeln.quantity, 2, accuracy: 0.001)

        let broetchen = try XCTUnwrap(result.first { $0.name.lowercased().contains("brötchen") })
        XCTAssertEqual(broetchen.quantity, 2, accuracy: 0.001)
    }
}
