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
    /// Review-UI als "N St." angezeigt (`ReceiptReviewCard.priceSummary`) — 500 dort würde
    /// "500 St." zeigen, als hätte der Nutzer 500 Stück gekauft.
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
    /// `expectedUnit` prüft zusätzlich die Bezugsgröße (Issue #10): Preis und Bezugsgröße werden in
    /// `ReceiptScannerView.save()` gemeinsam geschrieben, also müssen sie hier auch gemeinsam
    /// geprüft werden — ein Preis ohne Bezugsgröße wird von `ShoppingItem.init` nie mehr angewendet.
    private func assertLearnedPriceRoundTrip(matchQuantityAmount: Double?, line: String, expectedUnit: String = "g") throws {
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
        // Dieselbe Instanz, dieselbe Methode wie in `save()` — keine nachgebaute Formel.
        let learnedUnit = editableLine.learningUnit(matchUnit: matchQuantityAmount == nil ? nil : "g")

        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#123456")
        store.learnedPrices["skyr natur 500g"] = perUnitPrice
        store.learnedPriceUnits["skyr natur 500g"] = learnedUnit
        let item = ShoppingItem(name: "Skyr Natur 500g", quantityAmount: 500, unit: "g", store: store)

        XCTAssertEqual(learnedUnit, expectedUnit, "Preis und Bezugsgröße müssen zusammen gelernt werden (Issue #10)")
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
        XCTAssertEqual(editableLine.learningUnit(matchUnit: nil), "g",
                       "Zum Divisor aus der Füllmenge gehört die Bezugsgröße 'g' (Issue #10)")

        let perUnitPrice = receiptLine.price / quantity
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#123456")
        store.learnedPrices["skyr natur 500g"] = perUnitPrice
        store.learnedPriceUnits["skyr natur 500g"] = editableLine.learningUnit(matchUnit: nil)
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

    /// Issue #25 — eine Differenz von exakt einem Cent liegt innerhalb der Toleranz, unabhängig
    /// davon, in welche Richtung die Fließkomma-Rundung fällt (4 × 0,39 − 1,57 ergibt
    /// 0.010000000000000009 und wurde vorher abgelehnt, 2 × 3,44 − 6,87 dagegen angenommen).
    func testConfirmationLineWithExactlyOneCentDifferenceIsAttributedInBothDirections() throws {
        let broetchen = try XCTUnwrap(ReceiptParserService.parse(["Produkt  1,57 A", "4 Stk x 0,39"]).first)
        XCTAssertEqual(broetchen.quantity, 4, accuracy: 0.001)

        let maultaschen = try XCTUnwrap(ReceiptParserService.parse(["Produkt  6,87 A", "2 Stk x 3,44"]).first)
        XCTAssertEqual(maultaschen.quantity, 2, accuracy: 0.001)
    }

    func testAmountsAgreeIsInclusiveAtTheToleranceBoundary() {
        XCTAssertTrue(ReceiptParserService.amountsAgree(4 * 0.39, 1.57, tolerance: 0.01))
        XCTAssertTrue(ReceiptParserService.amountsAgree(2 * 3.44, 6.87, tolerance: 0.01))
        XCTAssertFalse(ReceiptParserService.amountsAgree(4 * 0.39, 1.58, tolerance: 0.01))
        XCTAssertTrue(ReceiptParserService.amountsAgree(3 * 2.29, 6.92, tolerance: 0.05))
        XCTAssertFalse(ReceiptParserService.amountsAgree(3 * 2.29, 6.93, tolerance: 0.05))
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
        store.learnedPriceUnits["banane chiquita"] = "g" // Gewichtszeile → Bezugsgröße g (Issue #10)
        let kilo = ShoppingItem(name: "Banane Chiquita", quantityAmount: 1000, unit: "g", store: store)
        XCTAssertEqual(try XCTUnwrap(kilo.estimatedLineTotal), 2.49, accuracy: 0.01,
                       "AC8: 1 kg Bananen kostet wieder den Bon-Kilopreis")
    }

    // MARK: - Issue #10: Preis UND Bezugsgröße werden gemeinsam gelernt

    /// Der Lern-Plan kommt seit #59 aus `ReceiptLearning.plan` — derselben Funktion, die `save()`
    /// aufruft; hier stehen nur noch die drei Schreibzeilen. `match` ist `nil`, weil im
    /// reproduzierten Fall kein unbepreister Kaufdatensatz existiert (der zugeordnete Artikel ist
    /// noch offen, also hat er keinen) — genau die Lage in `save()` bei diesem Bon.
    private func learnLikeSave(_ line: EditableReceiptLine, into store: Store) {
        let plan = ReceiptLearning.plan(line: line, match: nil)
        store.learnedPrices[plan.key] = plan.perUnitPrice
        store.learnedPriceUnits[plan.key] = plan.unit
        store.learnedPriceDates[plan.key] = Date()
    }

    /// AC-1 am Schreibweg: Die Bon-Zeile des gemeldeten Falls legt Rate UND Bezugsgröße unter
    /// demselben Schlüssel ab — beides in einem Zug geprüft, denn eine Rate ohne Bezugsgröße wird
    /// von `ShoppingItem.init` nie mehr angewendet (PO-Entscheidung 1) und der Preis wäre still
    /// verloren. Die Werte sind wörtlich die Fixture aus
    /// `SmartCartApp.seedReceiptReviewForUITestsIfNeeded` (SmartCartApp.swift:245-257), also
    /// dieselben, mit denen der Fehler am 26.09.2026 im Simulator reproduziert wurde.
    /// Gegenprobe in derselben Methode: eine Zeile ohne Füllmenge im Namen lernt einen STÜCKpreis —
    /// sonst wäre `"g"` auch dann richtig, wenn die Methode es pauschal zurückgäbe.
    func testSavingReceiptStoresPriceAndUnitTogether() throws {
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#0050AA")

        let hackfleisch = EditableReceiptLine(
            name: "Bio-Hackfleisch gemischt Rind & Schwein 400 g",
            price: 4.99,
            originalName: "BIO-HACKFLEISCH GEMISCHT RIND SCHWEIN 400G",
            quantity: 1,
            unit: "400g",
            weightBasis: nil
        )
        let milch = EditableReceiptLine(
            name: "Frische Vollmilch 3,5 %",
            price: 1.19,
            originalName: "MILCH 3,5% FRISCH",
            quantity: 1,
            unit: "",
            weightBasis: nil
        )

        learnLikeSave(hackfleisch, into: store)
        learnLikeSave(milch, into: store)

        let hackKey = "bio-hackfleisch gemischt rind & schwein 400 g"
        XCTAssertEqual(
            try XCTUnwrap(store.learnedPrices[hackKey]), 4.99 / 400, accuracy: 0.000001,
            "4,99 € für eine 400-g-Packung ergeben die Rate 0,0125 €/g"
        )
        XCTAssertEqual(
            store.learnedPriceUnits[hackKey], "g",
            "Zur Rate gehört ihre Bezugsgröße — ohne sie entstehen die gemeldeten 0,01 € auf der Liste"
        )

        let milchKey = "frische vollmilch 3,5 %"
        XCTAssertEqual(
            try XCTUnwrap(store.learnedPrices[milchKey]), 1.19, accuracy: 0.000001,
            "Ohne Füllmenge im Namen ist der Zeilenpreis bereits der Preis pro Stück"
        )
        XCTAssertEqual(
            store.learnedPriceUnits[milchKey], "stk",
            "Ein Stückpreis darf nicht als Gewichts-Rate gelernt werden"
        )
    }

    /// AC-9: `learningQuantity` und `learningUnit` müssen dieselben Bedingungen in derselben
    /// Reihenfolge treffen — sonst lernt `save()` einen richtigen Preis unter einer falschen
    /// Bezugsgröße, was schlimmer ist als gar kein Preis. Deshalb wird jeder der fünf Zweige an
    /// DERSELBEN Instanz doppelt abgefragt, und die jeweils nicht zuständigen Quellen sind bewusst
    /// mit abweichenden Werten belegt: ein Zweig, der zu früh oder zu spät greift, fällt auf.
    func testLearningUnitMatchesLearningQuantityBranchForEveryCase() {
        // 1) Gewichtszeile "0,436 kg x 12,49" — weightBasis schlägt alles andere.
        let weighed = EditableReceiptLine(
            name: "Aufschnitt", price: 5.44, originalName: "AUFSCHNITT 200G",
            quantity: 3, unit: "", weightBasis: 436
        )
        XCTAssertEqual(weighed.learningQuantity(matchQuantityAmount: 250), 436, "Zweig 1: weightBasis")
        XCTAssertEqual(weighed.learningUnit(matchUnit: "stk"), "g", "Zweig 1 gehört die Bezugsgröße g")

        // 2) Mengenzeile "3 Stk x 0,79" — quantity > 1 schlägt Artikel-Match und Füllmenge im Namen.
        let multiple = EditableReceiptLine(
            name: "Eier Freiland", price: 2.37, originalName: "EIER FREILAND 300G",
            quantity: 3, unit: "", weightBasis: nil
        )
        XCTAssertEqual(multiple.learningQuantity(matchQuantityAmount: 250), 3, "Zweig 2: quantity")
        XCTAssertEqual(multiple.learningUnit(matchUnit: "g"), "stk", "Zweig 2 ist ein Stückpreis")

        // 3) Abgehakter Artikel — die Bezugsgröße ist der Eimer SEINER Einheit, nicht eine
        //    Konstante; deshalb drei Einheiten an derselben Zeile.
        let matched = EditableReceiptLine(
            name: "Mozzarella", price: 1.98, originalName: "MDHSZ",
            quantity: 1, unit: "", weightBasis: nil
        )
        XCTAssertEqual(matched.learningQuantity(matchQuantityAmount: 250), 250, "Zweig 3: matchQuantityAmount")
        XCTAssertEqual(matched.learningUnit(matchUnit: "g"), "g", "Zweig 3 übernimmt den Eimer des Artikels")
        XCTAssertEqual(matched.learningUnit(matchUnit: "ml"), "g", "ml liegt im selben Eimer wie g")
        XCTAssertEqual(matched.learningUnit(matchUnit: "Stück"), "stk", "Ein Stück-Artikel lernt einen Stückpreis")

        // 4) Füllmenge im rohen Bon-Namen — greift erst, wenn es keinen Artikel-Match gibt.
        let packaged = EditableReceiptLine(
            name: "Skyr Natur", price: 2.29, originalName: "SKYR NATUR 500G",
            quantity: 1, unit: "", weightBasis: nil
        )
        XCTAssertEqual(packaged.learningQuantity(matchQuantityAmount: nil), 500, "Zweig 4: Füllmenge im Namen")
        XCTAssertEqual(packaged.learningUnit(matchUnit: nil), "g", "Eine Füllmenge in g ergibt eine Gramm-Rate")

        // 5) Keine Quelle — Fallback 1, der Zeilenpreis IST der Stückpreis.
        let plain = EditableReceiptLine(
            name: "Seitan", price: 2.49, originalName: "SEITAN NATUR",
            quantity: 1, unit: "", weightBasis: nil
        )
        XCTAssertEqual(plain.learningQuantity(matchQuantityAmount: nil), 1, "Zweig 5: Fallback 1")
        XCTAssertEqual(plain.learningUnit(matchUnit: nil), "stk", "Zum Divisor 1 gehört der Stückpreis")
    }

    /// AC-10: `packageSizeFromName` ist die Anzeige-Schwester von `weightBasisFromName` — dieselbe
    /// Zahl, aber mit der literalen Einheit, damit für eine 0,5-l-Flasche nicht „ca. 500 g" am
    /// Artikel steht (sichtbar falsch).
    func testPackageSizeFromNameReturnsLitreAsMillilitre() throws {
        let cola = try XCTUnwrap(ReceiptParserService.packageSizeFromName("COLA 0,5L"))
        XCTAssertEqual(cola.amount, 500, accuracy: 0.0001)
        XCTAssertEqual(cola.unit, "ml", "Eine halbe Liter-Flasche sind 500 ml, nicht 500 g")

        let skyr = try XCTUnwrap(ReceiptParserService.packageSizeFromName("SKYR NATUR 500G"))
        XCTAssertEqual(skyr.amount, 500, accuracy: 0.0001)
        XCTAssertEqual(skyr.unit, "g")

        let wein = try XCTUnwrap(ReceiptParserService.packageSizeFromName("WEIN 75CL"))
        XCTAssertEqual(wein.amount, 750, accuracy: 0.0001)
        XCTAssertEqual(wein.unit, "ml", "Zentiliter sind ein Volumen")

        XCTAssertNil(
            ReceiptParserService.packageSizeFromName("Bio Eier 6er"),
            "Ohne erkennbare Einheit darf keine Füllmenge erfunden werden"
        )
    }

    /// AC-10, zweite Hälfte: Beide Funktionen müssen für denselben Namen denselben Zahlenwert
    /// liefern — sonst zeigte die Anzeige eine andere Menge, als der Preis-Divisor benutzt.
    func testPackageSizeFromNameAgreesWithWeightBasisFromName() throws {
        for name in ["COLA 0,5L", "SKYR NATUR 500G", "WEIN 75CL", "Reis 1kg", "Cola 1,5l"] {
            let package = try XCTUnwrap(ReceiptParserService.packageSizeFromName(name), name)
            let basis = try XCTUnwrap(ReceiptParserService.weightBasisFromName(name), name)
            XCTAssertEqual(
                package.amount, basis, accuracy: 0.0001,
                "Anzeige-Menge und Preis-Divisor müssen für '\(name)' dieselbe Zahl sein"
            )
        }
    }
}
