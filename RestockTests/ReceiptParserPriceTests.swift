import XCTest
import SwiftData
@testable import Restock

/// Beweist den Fix für den Skyr-Bug (gemeldet 2026-08-03): "Skyr, 500 g" (Lidl) zeigte
/// geschätzt 1.145,00 € statt 1,15 €, wodurch auch der Listen-Gesamtbetrag ("Geschätzter
/// Betrag") mit aufsummiert kaputt war.
///
/// Root Cause war KEIN Formatierungs-/Dezimaltrennzeichen-Bug — jede Preisanzeige in der App
/// läuft über SwiftUIs lokalisiertes `.currency`-FormatStyle, es gibt keinen einzigen
/// `NumberFormatter` oder manuelles String-Bauen mit "€" im Repo. Stattdessen ein
/// Berechnungsfehler in `ReceiptParserService.parseClassic()`: bei Gewichts-/Grundpreiszeilen
/// wie "0,500 kg x 2,29" (Bon druckt Gewicht × €/kg-Rate, ohne separaten Gesamtpreis auf
/// derselben Zeile) griff `extractTrailingPrice` die Rate (2,29) selbst statt eines
/// Gesamtpreises — die Rate wurde dadurch fälschlich als `ReceiptLine.price` (laut eigenem
/// Struct-Kommentar der Zeilen-GESAMTpreis) übernommen und landete unkorrigiert in
/// `store.learnedPrices`. Für ein 500g-Produkt macht das ×500 (statt ×0,5) den Endpreis
/// 1000-fach zu groß: 2,29 × 500 = 1145,00 statt 2,29 × 0,5 = 1,145 ≈ 1,15 €.
///
/// Zweiter, per unabhängigem Review gefundener Teil desselben Bugs: selbst mit korrektem
/// Gesamtpreis lernte `ReceiptScannerView.save()` bei einem ERSTEN Scan eines neuen
/// Gewichtsartikels (kein historischer Artikel-Match vorhanden, `match?.quantityAmount` liefert
/// nichts) weiterhin per Fallback `quantity = 1` — der korrekte Gesamtpreis (1,15) landete dann
/// selbst als "Preis pro Gramm" in `learnedPrices`, und ein künftiger 500g-Artikel hätte
/// 1,15 × 500 = 575 € geschätzt bekommen. `ReceiptLine.weightBasis` schließt genau diese Lücke.
final class ReceiptParserPriceTests: XCTestCase {

    // MARK: - Der gemeldete Bug

    func testWeightBasedGrundpreisLineComputesCorrectTotal() throws {
        // Name auf eigener Zeile, Gewichtsdetail direkt darunter, OHNE "EUR/Kg"-Textrest nach
        // der Rate (Vision-Rekonstruktion lässt diesen manchmal weg) — exakt das im Code
        // dokumentierte "0,436 kg x 12,49"-Format, nur mit Skyrs echten Zahlen.
        let lines = ["Skyr Natur 500g", "0,500 kg x 2,29"]

        let result = ReceiptParserService.parse(lines)

        let skyr = try XCTUnwrap(
            result.first { $0.name.lowercased().contains("skyr") },
            "Kein ReceiptLine für Skyr erkannt"
        )
        XCTAssertEqual(
            skyr.price, 1.15, accuracy: 0.005,
            "Gesamtpreis muss Gewicht × Grundpreis sein (0,5 kg × 2,29 €/kg ≈ 1,15 €), nicht die nackte Rate 2,29 €"
        )

        // Exakt die Formatierung, die der Nutzer auf der Liste sieht (SwiftUI .currency-Style,
        // deutsches Locale). Non-breaking spaces normalisieren, da Apples Formatter je nach
        // OS-Version U+00A0/U+202F statt eines normalen Leerzeichens vor "€" verwendet.
        let formatted = skyr.price
            .formatted(.currency(code: "EUR").locale(Locale(identifier: "de_DE")))
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
        XCTAssertEqual(formatted, "1,15 €")
    }

    /// Der Gewichts-Divisor muss getrennt von `quantity` ankommen: `quantity` wird in der
    /// Review-UI als "N × Preis" angezeigt (`ReceiptLineRow.detailText`) — 500 dort würde
    /// "500 × ..." zeigen, als hätte der Nutzer 500 Stück gekauft.
    func testWeightLineSetsGramWeightBasisNotQuantity() throws {
        let lines = ["Skyr Natur 500g", "0,500 kg x 2,29"]

        let result = ReceiptParserService.parse(lines)

        let skyr = try XCTUnwrap(result.first { $0.name.lowercased().contains("skyr") })
        XCTAssertEqual(skyr.weightBasis ?? -1, 500, accuracy: 0.01, "500g als Gramm-Basis erwartet")
        XCTAssertEqual(skyr.quantity, 1, accuracy: 0.001, "quantity darf NICHT auf das Gewicht gesetzt werden")
    }

    // MARK: - Weiteres dokumentiertes Format (Code-Kommentar in ReceiptParserService)

    func testDocumentedWeightLineWithoutSuffixComputesWeightTimesRate() throws {
        let lines = ["Aufschnitt", "0,436 kg x 12,49"]

        let result = ReceiptParserService.parse(lines)

        let line = try XCTUnwrap(result.first { $0.name.lowercased().contains("aufschnitt") })
        XCTAssertEqual(line.price, 0.436 * 12.49, accuracy: 0.01)
        XCTAssertNotEqual(line.price, 12.49, "Die nackte Grundpreis-Rate darf nie als Gesamtpreis übernommen werden")
    }

    // MARK: - Stückzahl-Variante ("3 Stk x 0,79") — quantity statt weightBasis

    func testPieceCountLineSetsQuantityNotWeightBasis() throws {
        let lines = ["Eier Freiland", "3 Stk x 0,79"]

        let result = ReceiptParserService.parse(lines)

        let eier = try XCTUnwrap(result.first { $0.name.lowercased().contains("eier") })
        XCTAssertEqual(eier.price, 3 * 0.79, accuracy: 0.01)
        XCTAssertEqual(eier.quantity, 3, accuracy: 0.001, "echte Stückzahl gehört in quantity (korrekt für die '3 × 0,79 €'-Anzeige)")
        XCTAssertNil(eier.weightBasis, "Stückzahl-Zeilen dürfen keinen Gewichts-Divisor setzen")
    }

    // MARK: - Non-Regression: Zeile mit echtem, separatem Gesamtpreis bleibt unangetastet

    func testWeightLineWithSeparateTotalPriceLineIsNotOverridden() throws {
        // "Umgekehrte Reihenfolge" (siehe pendingPrice-Kommentar in ReceiptParserService): eine
        // reine Preiszeile (der echte, tatsächlich bezahlte Gesamtpreis — hier absichtlich MIT
        // Rabatt, klar verschieden von Gewicht × Rate = 0,584 × 1,29 ≈ 0,75) steht VOR der
        // Name+Gewicht-Zeile. Mit 0,75 statt 0,50 wären beide Pfade (Override greift / Override
        // greift nicht) numerisch ununterscheidbar gewesen — bewusst so gewählt, dass ein
        // fälschlich greifender Override (0,75 statt 0,50) den Test sicher rot machen würde.
        let lines = ["0,50", "Banane lose  0,584 kg x 1,29  EUR/Kg"]

        let result = ReceiptParserService.parse(lines)

        let banane = try XCTUnwrap(result.first { $0.name.lowercased().contains("banane") })
        XCTAssertEqual(
            banane.price, 0.50, accuracy: 0.005,
            "Ein bereits vorhandener echter Gesamtpreis darf nicht durch Gewicht × Rate überschrieben werden"
        )
    }

    // MARK: - Fehlender Gesamtpreis überhaupt (weder Trailing-Preis noch pendingPrice)

    func testWeightLineWithNoSeparateTotalFallsBackToComputedTotal() throws {
        // Gleiche Zeile wie oben, aber OHNE vorherige Preiszeile — bisher wurde die Position in
        // diesem Fall mangels erkennbaren Preises komplett verworfen (fehlender statt sicher
        // falscher Preis); jetzt wird der berechenbare Gesamtpreis genutzt.
        let lines = ["Banane lose  0,584 kg x 1,29  EUR/Kg"]

        let result = ReceiptParserService.parse(lines)

        let banane = try XCTUnwrap(result.first { $0.name.lowercased().contains("banane") })
        XCTAssertEqual(banane.price, 0.584 * 1.29, accuracy: 0.01)
    }

    // MARK: - End-to-End: derselbe Mengen-Auflösung/Lern-Kreislauf wie ReceiptScannerView.save()

    /// Ruft `EditableReceiptLine.learningQuantity(matchQuantityAmount:)` — dieselbe Methode, die
    /// `ReceiptScannerView.save()` selbst aufruft — statt ihre Formel hier nachzubilden. Ein
    /// unabhängiges Review hat gezeigt: eine Kopie der Formel bemerkt eine Regression in `save()`
    /// selbst NICHT (Beweis: `save()`s echte Formel testweise auf den alten, kaputten Stand
    /// zurückgesetzt — beide Tests blieben mit der kopierten Formel grün). Läuft für BEIDE Fälle
    /// durch: ein historischer Match existiert (`matchQuantityAmount` gesetzt) UND — der zuvor
    /// kaputte Fall — gar keiner (`nil`, z. B. allererster Scan dieses Artikels). Vor der
    /// `weightBasis`-Änderung fiel der `nil`-Fall auf den Fallback `1` zurück und hätte 1,15 als
    /// Gramm-Preis gelernt (→ 575 € für einen künftigen 500g-Artikel statt 1,15 €).
    private func assertLearnedPriceRoundTrip(matchQuantityAmount: Double?, line: String) throws {
        let lines = ["Skyr Natur 500g", line]
        let receiptLine = try XCTUnwrap(ReceiptParserService.parse(lines).first)

        // Exakt dieselbe Konstruktion wie an den echten Call-Sites in ReceiptScannerView.swift
        // (init(store:prefilled:) / der normale Scan-Pfad) — kein Test-Sonderweg.
        let editableLine = EditableReceiptLine(
            name: receiptLine.name,
            price: receiptLine.price,
            quantity: receiptLine.quantity,
            unit: receiptLine.unit,
            weightBasis: receiptLine.weightBasis
        )
        let quantity = editableLine.learningQuantity(matchQuantityAmount: matchQuantityAmount)
        let perUnitPrice = receiptLine.price / quantity

        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#123456")
        store.learnedPrices["skyr natur 500g"] = perUnitPrice
        let item = ShoppingItem(name: "Skyr Natur 500g", quantityAmount: 500, unit: "g", store: store)

        XCTAssertEqual(try XCTUnwrap(item.estimatedLineTotal), 1.15, accuracy: 0.01)
    }

    func testLearnedPriceRoundTripWithHistoricalMatch() throws {
        try assertLearnedPriceRoundTrip(matchQuantityAmount: 500, line: "0,500 kg x 2,29")
    }

    func testLearnedPriceRoundTripWithoutHistoricalMatch() throws {
        // Der Fall, den die alte Version dieses Tests (vor dem unabhängigen Review) nicht
        // abdeckte: kein Match, `matchQuantityAmount: nil`.
        try assertLearnedPriceRoundTrip(matchQuantityAmount: nil, line: "0,500 kg x 2,29")
    }

    // MARK: - Regression guards für OCR-Formatvarianten (Nutzer meldete den Skyr-Bug erneut nach
    // dem Fix — dieser Test beweist, dass der Fix nicht an einem bestimmten Dezimaltrennzeichen
    // oder Multiplikationszeichen hängt, das ein anderer Beleg-Scan liefern könnte)

    func testWeightLineWithDecimalDotInsteadOfCommaComputesCorrectTotal() throws {
        let lines = ["Skyr Natur 500g", "0.500 kg x 2.29"]

        let result = ReceiptParserService.parse(lines)

        let skyr = try XCTUnwrap(result.first { $0.name.lowercased().contains("skyr") })
        XCTAssertEqual(skyr.price, 1.15, accuracy: 0.005)
        XCTAssertNotEqual(skyr.price, 2.29, "Die nackte Rate darf auch bei Punkt-Dezimaltrennzeichen nicht als Gesamtpreis übernommen werden")
    }

    func testWeightLineWithMultiplicationSignInsteadOfXComputesCorrectTotal() throws {
        let lines = ["Aufschnitt", "0,436 kg × 12,49"]

        let result = ReceiptParserService.parse(lines)

        let line = try XCTUnwrap(result.first { $0.name.lowercased().contains("aufschnitt") })
        XCTAssertEqual(line.price, 0.436 * 12.49, accuracy: 0.01)
    }

    // MARK: - Vierter Anlauf: derselbe sichtbare Bug (1145€ statt 1,15€), aber eine ANDERE Ursache
    // — ein abgepackter Skyr-Becher mit festem Gesamtpreis druckt auf dem Bon NUR eine einzige
    // Zeile ("SKYR NATUR 500G   2,29"), OHNE separate "0,500 kg x 2,29"-Gewichtszeile (die gibt es
    // nur bei an der Frischetheke/Waage gewogener Ware). `weightBasis` blieb dadurch `nil`, UND
    // `matchQuantityAmount` ist beim allerersten Scan dieses Artikels ebenfalls `nil` —
    // `learningQuantity` fiel auf den absoluten Fallback `1` zurück und lernte 2,29€ als
    // vermeintlichen Gramm-Preis. Fix: `ReceiptParserService.weightBasisFromName` liest die im
    // Namen selbst gedruckte Füllmenge ("500G") als letzten Fallback vor der `1`.

    func testFlatPricePackagedItemWithoutWeightLineLearnsCorrectPerGramPrice() throws {
        let lines = ["Skyr Natur 500g   2,29"]
        let receiptLine = try XCTUnwrap(ReceiptParserService.parse(lines).first)
        XCTAssertNil(receiptLine.weightBasis, "Setup-Annahme: keine separate Gewichtszeile vorhanden")

        let editableLine = EditableReceiptLine(
            name: receiptLine.name,
            price: receiptLine.price,
            originalName: receiptLine.name,
            quantity: receiptLine.quantity,
            unit: receiptLine.unit,
            weightBasis: receiptLine.weightBasis
        )
        // Allererster Scan dieses Artikels — kein historischer Match.
        let quantity = editableLine.learningQuantity(matchQuantityAmount: nil)
        XCTAssertEqual(quantity, 500, "Divisor muss aus der im Namen gedruckten Füllmenge (500G) kommen, nicht auf 1 zurückfallen")

        let perUnitPrice = receiptLine.price / quantity
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#123456")
        store.learnedPrices["skyr natur 500g"] = perUnitPrice
        let item = ShoppingItem(name: "Skyr Natur 500g", quantityAmount: 500, unit: "g", store: store)

        XCTAssertEqual(try XCTUnwrap(item.estimatedLineTotal), 2.29, accuracy: 0.01)
        XCTAssertNotEqual(try XCTUnwrap(item.estimatedLineTotal), 1145.0)
    }

    func testWeightBasisFromNameHandlesKgLiterAndCentiliterUnits() {
        XCTAssertEqual(ReceiptParserService.weightBasisFromName("Skyr Natur 500g"), 500)
        XCTAssertEqual(ReceiptParserService.weightBasisFromName("Reis 1kg"), 1000)
        XCTAssertEqual(ReceiptParserService.weightBasisFromName("Cola 1,5l"), 1500)
        XCTAssertEqual(ReceiptParserService.weightBasisFromName("Rotwein 75cl"), 750)
        XCTAssertNil(ReceiptParserService.weightBasisFromName("Bio Eier 6er"), "Ohne erkennbare g/kg/l-Einheit darf nichts erfunden werden")
    }

    // MARK: - Lidl-Mehrfachkauf ohne Einheiten-Wort ("2,29 x 3") — gemeldet 24.08.2026
    //
    // Bon druckt Stückpreis × Anzahl OHNE "Stk"/"kg"-Wort dazwischen ("2,29 x 3   6,87 A").
    // `weightTimesRateRegex` griff hier nie (verlangt zwingend ein Einheiten-Wort), `quantity`
    // blieb beim Default 1 — der volle Zeilen-Gesamtpreis (6,87€) wurde beim erneuten
    // Hinzufügen zur Liste fälschlich als Stückpreis angezeigt statt 2,29€.

    func testBarePriceTimesCountSetsQuantityFromLidlMultiBuyLine() throws {
        let lines = ["BürgerSchwä.Maultas.  2,29 x 3  6,87 A"]

        let result = ReceiptParserService.parse(lines)

        let maultaschen = try XCTUnwrap(result.first { $0.name.lowercased().contains("maultas") })
        XCTAssertEqual(maultaschen.price, 6.87, accuracy: 0.001, "Zeilen-Gesamtpreis bleibt unverändert (für die Ausgaben-Ansicht)")
        XCTAssertEqual(maultaschen.quantity, 3, accuracy: 0.001, "Menge muss aus 'x 3' erkannt werden, nicht beim Default 1 bleiben")
    }

    func testBarePriceTimesCountLearnsPerUnitPriceNotLineTotal() throws {
        // Derselbe End-zu-Ende-Kreislauf wie die Skyr-Roundtrip-Tests oben: die eigentliche
        // Nutzer-Beschwerde war nicht "quantity falsch", sondern "beim erneuten Hinzufügen zur
        // Liste steht 6,87€ statt 2,29€ pro Packung".
        let lines = ["BürgerSchwä.Maultas.  2,29 x 3  6,87 A"]
        let receiptLine = try XCTUnwrap(ReceiptParserService.parse(lines).first)

        let editableLine = EditableReceiptLine(
            name: receiptLine.name,
            price: receiptLine.price,
            quantity: receiptLine.quantity,
            unit: receiptLine.unit,
            weightBasis: receiptLine.weightBasis
        )
        let quantity = editableLine.learningQuantity(matchQuantityAmount: nil)
        let perUnitPrice = receiptLine.price / quantity

        XCTAssertEqual(perUnitPrice, 2.29, accuracy: 0.01, "Stückpreis muss 2,29€ sein, nicht der Zeilen-Gesamtpreis 6,87€")
    }

    func testBarePriceTimesCountHandlesMandelkerneAndBroetchenFromRealLidlReceipt() throws {
        // Zwei weitere reale Zeilen desselben Bons (24.08.2026) — beweist, dass der Fix nicht
        // nur für einen einzelnen Zahlenwert zufällig passt.
        let mandelnResult = ReceiptParserService.parse(["Mandelkerne  2,49 x 2  4,98 A"])
        let mandeln = try XCTUnwrap(mandelnResult.first { $0.name.lowercased().contains("mandel") })
        XCTAssertEqual(mandeln.price, 4.98, accuracy: 0.001)
        XCTAssertEqual(mandeln.quantity, 2, accuracy: 0.001)

        let broetchenResult = ReceiptParserService.parse(["Brötchen Lauge  0,39 x 2  0,78 A"])
        let broetchen = try XCTUnwrap(broetchenResult.first { $0.name.lowercased().contains("brötchen") })
        XCTAssertEqual(broetchen.price, 0.78, accuracy: 0.001)
        XCTAssertEqual(broetchen.quantity, 2, accuracy: 0.001)
    }

    func testBarePriceTimesCountDoesNotInterfereWithWeightBasedLine() throws {
        // Non-Regression: das bestehende "kg x Rate"-Format (siehe
        // testWeightBasedGrundpreisLineComputesCorrectTotal oben) muss unverändert funktionieren,
        // auch wenn eine Zeile im selben Bon das neue "Preis x Anzahl"-Format nutzt.
        let lines = ["Skyr Natur 500g", "0,500 kg x 2,29", "Mandelkerne  2,49 x 2  4,98 A"]

        let result = ReceiptParserService.parse(lines)

        let skyr = try XCTUnwrap(result.first { $0.name.lowercased().contains("skyr") })
        XCTAssertEqual(skyr.price, 1.15, accuracy: 0.005)
        XCTAssertEqual(skyr.quantity, 1, accuracy: 0.001)
        XCTAssertEqual(skyr.weightBasis ?? -1, 500, accuracy: 0.01)

        let mandeln = try XCTUnwrap(result.first { $0.name.lowercased().contains("mandel") })
        XCTAssertEqual(mandeln.quantity, 2, accuracy: 0.001)
    }
    // MARK: - Issue #9: Bestätigungszeile unter einer Namenszeile MIT Preis (Rewe-eBon-Format)

    /// AC6 — Rechenprobe schlägt fehl (3 × 0,50 = 1,50 ≠ 1,00, z. B. OCR-Zahlendreher): Die
    /// Bestätigungszeile wird konsumiert, aber NICHT zugeschrieben — und sie wird auch nicht zur
    /// eigenen Phantom-Position (beobachtet ohne Schutz: Name "Stk x 0,50").
    func testBareConfirmationLineWithFailedSanityCheckIsConsumedNotAttributed() throws {
        let result = ReceiptParserService.parse(["Produkt  1,00 A", "3 Stk x 0,50"])

        XCTAssertEqual(result.count, 1, "Keine Phantom-Position aus der Bestätigungszeile. Erkannt: \(result.map(\.name))")
        let produkt = try XCTUnwrap(result.first)
        XCTAssertEqual(produkt.price, 1.00, accuracy: 0.001)
        XCTAssertEqual(produkt.quantity, 1, accuracy: 0.001, "Unpassende Stückzahl darf nicht übernommen werden")
        XCTAssertNil(produkt.weightBasis)
    }

    /// AC7 — Bestätigungszeile als allererste Zeile: keine Vorposition, an die sie gehören könnte.
    /// Ergebnis: keine Position, kein Absturz.
    func testBareConfirmationLineAsFirstLineDoesNotCrash() {
        let result = ReceiptParserService.parse(["4 Stk x 0,39", "0,706 kg x 2,49 EUR/kg"])

        XCTAssertTrue(result.isEmpty, "Bestätigungszeilen ohne Vorposition dürfen keine Position bilden. Erkannt: \(result.map(\.name))")
    }

    /// AC8 — Durchstich bis zum gelernten Preis, dieselbe Kette wie `assertLearnedPriceRoundTrip`
    /// oben, nur mit den Rewe-Zeilen aus Issue #9: Brötchen lernen 0,39 €/Stück (nicht 1,56 €),
    /// Banane lernt einen Gramm-Preis, der für 1 kg wieder 2,49 € ergibt (nicht 1,76 €/g).
    func testLearnedPriceRoundTripForReweBroetchenAndBanane() throws {
        func learnedPerUnit(_ lines: [String]) throws -> Double {
            let receiptLine = try XCTUnwrap(ReceiptParserService.parse(lines).first)
            let editableLine = EditableReceiptLine(
                name: receiptLine.name,
                price: receiptLine.price,
                quantity: receiptLine.quantity,
                unit: receiptLine.unit,
                weightBasis: receiptLine.weightBasis
            )
            let quantity = editableLine.learningQuantity(matchQuantityAmount: nil)
            return receiptLine.price / quantity
        }

        XCTAssertEqual(try learnedPerUnit(["LAUGENBROETCHEN 1,56 B", "4 Stk x 0,39"]), 0.39, accuracy: 0.001,
                       "AC8: Stückpreis = 1,56 / 4")

        let bananePerGram = try learnedPerUnit(["BANANE CHIQUITA 1,76 B", "0,706 kg x 2,49 EUR/kg"])
        let store = Store(name: "Rewe", emoji: "🛒", colorHex: "#123456")
        store.learnedPrices["banane chiquita"] = bananePerGram
        let kilo = ShoppingItem(name: "Banane Chiquita", quantityAmount: 1000, unit: "g", store: store)
        XCTAssertEqual(try XCTUnwrap(kilo.estimatedLineTotal), 2.49, accuracy: 0.01,
                       "AC8: 1 kg Bananen kostet wieder den Bon-Kilopreis")
    }
}
