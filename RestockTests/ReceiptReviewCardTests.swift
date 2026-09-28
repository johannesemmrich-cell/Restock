import XCTest
@testable import Restock

/// Regeln der Bon-Prüf-Karte (Issue #23, Spec `docs/specs/views/receipt-review-card.md`).
///
/// Geprüft werden ausschließlich die reinen Funktionen der Karte — Auswahl-Optionen,
/// Preiszeile, Kopfzeile, Mengen-Editor und die drei Auswahl-Zuweisungen. Kein SwiftUI, kein
/// Simulator: Diese Regeln entscheiden, welchen Preis die App später lernt, und müssen
/// deshalb einzeln und schnell prüfbar sein.
///
/// WICHTIG — Währungsformat: Die erwarteten Texte sind deutsch („1,99 €"). Dass der Testlauf
/// deutsch läuft, steht in `Restock.xcscheme` am `<TestAction>` (`language = "de"`,
/// `region = "DE"`). `setUp` prüft das ausdrücklich, damit eine falsch eingestellte
/// Testumgebung als solche auffällt und nicht als scheinbarer Formatierungsfehler.
final class ReceiptReviewCardTests: XCTestCase {

    override func setUpWithError() throws {
        let separator = Locale.current.decimalSeparator ?? "."
        try XCTSkipUnless(
            separator == ",",
            "Testumgebung läuft nicht auf deutschem Zahlenformat (Dezimaltrenner \"\(separator)\") — "
            + "Sprache/Region des Test-Schemas prüfen (language = de, region = DE).")
    }

    // MARK: - Hilfen

    private func makeLine(
        name: String,
        price: Double,
        originalName: String = "",
        quantity: Double = 1,
        unit: String = "",
        weightBasis: Double? = nil,
        suggestions: [ReceiptSuggestion] = [],
        matchedItemID: UUID? = nil,
        resolvedByAI: Bool = false,
        aiSuggestedName: String? = nil,
        aiSuggestedMatchedItemID: UUID? = nil
    ) -> EditableReceiptLine {
        var line = EditableReceiptLine(name: name, price: price)
        line.originalName = originalName.isEmpty ? name : originalName
        line.quantity = quantity
        line.unit = unit
        line.weightBasis = weightBasis
        line.suggestions = suggestions
        line.matchedItemID = matchedItemID
        line.resolvedByAI = resolvedByAI
        line.aiSuggestedName = aiSuggestedName
        line.aiSuggestedMatchedItemID = aiSuggestedMatchedItemID
        return line
    }

    /// Kurzform der Option für lesbare Fehlermeldungen: „treffer:Hafermilch", „ki:Milch",
    /// „aktuell:Milch", „eigener".
    private func describe(_ option: ReceiptNameOption) -> String {
        switch option {
        case .listMatch(let suggestion): return "treffer:\(suggestion.name)"
        case .aiSuggestion(let name): return "ki:\(name)"
        case .currentName(let name): return "aktuell:\(name)"
        case .receiptText(let name): return "bon:\(name)"
        case .custom: return "eigener"
        }
    }

    private func describe(_ options: [ReceiptNameOption]) -> String {
        options.map(describe).joined(separator: ", ")
    }

    /// Apples Währungsformatierer setzt je nach OS-Version U+00A0/U+202F vor das „€".
    private func normalized(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{2009}", with: " ")
    }

    private func summary(_ line: EditableReceiptLine) -> String {
        normalized(ReceiptReviewCard.priceSummary(for: line))
    }

    // MARK: - AC2/AC4: Auswahl-Optionen

    /// AC2/AC4 — KI-Vorschlag und zwei Listen-Treffer ergeben vier Zeilen, die KI-Zeile zuerst.
    ///
    /// Der Name der Zeile entspricht dem KI-Vorschlag, also ist diese Option die aktuell
    /// gewählte und steht laut Regel 3 an erster Stelle.
    func testAiLineWithTwoSuggestionsOffersFourOptionsWithAiFirst() {
        let line = makeLine(
            name: "Frische Vollmilch",
            price: 1.19,
            originalName: "MILCH 3,5% FRISCH",
            suggestions: [
                ReceiptSuggestion(name: "Hafermilch", itemID: UUID()),
                ReceiptSuggestion(name: "Buttermilch", itemID: UUID()),
            ],
            resolvedByAI: true,
            aiSuggestedName: "Frische Vollmilch",
            aiSuggestedMatchedItemID: UUID())

        let options = ReceiptReviewCard.selectionOptions(for: line)

        // Issue #65, Paket 2: "MILCH 3,5% FRISCH" normalisiert zu "Milch 3,5% Frisch" und weicht
        // vom gewählten Namen "Frische Vollmilch" ab — die Bon-Zeile kommt als Add-on VOR "Anderer
        // Name …" hinzu, ohne die drei bisherigen Kandidaten zu verdrängen.
        XCTAssertEqual(options.count, 5, "Erwartet: KI-Zeile + zwei Treffer + Bon-Zeile + eigener Name. Bekommen: \(describe(options))")
        XCTAssertEqual(describe(options[0]), "ki:Frische Vollmilch",
                       "Die aktuell gewählte KI-Zeile muss an erster Stelle stehen. Bekommen: \(describe(options))")
        XCTAssertEqual(describe(options[3]), "bon:Milch 3,5% Frisch",
                       "Die Bon-Zeile muss unmittelbar vor \"Anderer Name …\" stehen. Bekommen: \(describe(options))")
        XCTAssertEqual(describe(options[4]), "eigener",
                       "Der eigene Name muss immer die letzte Zeile sein. Bekommen: \(describe(options))")
    }

    /// AC4 — auch ein reiner Listen-Treffer wird als Vorauswahl nach vorn sortiert, und zwar
    /// unabhängig von der Schreibweise.
    ///
    /// Das ist der häufigere Fall als der KI-Fall darüber: Die Zeile trägt bereits den Namen
    /// eines Artikels der Liste, die Vorschlagsliste des Dienstes führt ihn aber nicht an
    /// erster Stelle. Stünde die Vorauswahl dann nicht oben, müsste der Nutzer an jeder
    /// Position erst suchen, welche der drei Zeilen gerade gilt — die Karte behauptete eine
    /// andere Vorauswahl als die, mit der `save()` rechnet. Die Schreibweise wird mitgeprüft,
    /// weil gelernte Aliase und OCR-Namen klein-/großgeschrieben durcheinander auftreten
    /// („vollmilch" gegen den Artikel „Vollmilch").
    func testPreselectedListMatchIsSortedFirstRegardlessOfCase() {
        let hafermilch = ReceiptSuggestion(name: "Hafermilch", itemID: UUID())
        let vollmilch = ReceiptSuggestion(name: "Vollmilch", itemID: UUID())
        let buttermilch = ReceiptSuggestion(name: "Buttermilch", itemID: UUID())
        let line = makeLine(
            name: "vollmilch",                      // klein — der Treffer heißt „Vollmilch"
            price: 1.19,
            originalName: "MILCH 3,5% FRISCH",
            suggestions: [hafermilch, vollmilch, buttermilch],
            matchedItemID: vollmilch.itemID)        // kein KI-Vorschlag im Spiel

        let options = ReceiptReviewCard.selectionOptions(for: line)

        // Issue #65, Paket 2: "MILCH 3,5% FRISCH" normalisiert zu "Milch 3,5% Frisch" und weicht
        // vom gewählten Namen "vollmilch" ab — die Bon-Zeile kommt als Add-on hinzu.
        XCTAssertEqual(options.count, 5, "Drei Treffer plus Bon-Zeile plus eigener Name. Bekommen: \(describe(options))")
        guard case .listMatch(let first) = options[0] else {
            return XCTFail("Die erste Zeile ist kein Listen-Treffer. Bekommen: \(describe(options))")
        }
        XCTAssertEqual(first.itemID, vollmilch.itemID,
                       "Der vorausgewählte Treffer (Vollmilch, zweiter Vorschlag) muss an erster Stelle stehen. "
                       + "Bekommen: \(describe(options))")
        XCTAssertEqual(describe(options[1]), "treffer:Hafermilch",
                       "Die übrigen Treffer behalten ihre relative Reihenfolge. Bekommen: \(describe(options))")
        XCTAssertEqual(describe(options[2]), "treffer:Buttermilch",
                       "Die übrigen Treffer behalten ihre relative Reihenfolge. Bekommen: \(describe(options))")
        XCTAssertEqual(describe(options[3]), "bon:Milch 3,5% Frisch",
                       "Die Bon-Zeile muss unmittelbar vor \"Anderer Name …\" stehen. Bekommen: \(describe(options))")
        XCTAssertEqual(describe(options[4]), "eigener",
                       "Der eigene Name muss immer die letzte Zeile sein. Bekommen: \(describe(options))")
    }

    /// AC2 — fünf Treffer werden auf drei gekappt; der Dienst liefert heute bis zu fünf.
    ///
    /// AC4 (Issue #37): Keiner der drei nach der Kappung verbliebenen Treffer entspricht dem
    /// geltenden Namen „Milch" — der geltende Name wird deshalb zusätzlich vorausgewählt
    /// eingefügt, und der schwächste der drei (zuletzt gereiht, „Vollmilch") entfällt dafür.
    /// Insgesamt bleibt es bei drei inhaltlichen Kandidaten (zwei Treffer + der geltende Name).
    func testFiveSuggestionsAreCappedToThreeListMatches() {
        let suggestions = ["Hafermilch", "Buttermilch", "Vollmilch", "Kondensmilch", "Reismilch"]
            .map { ReceiptSuggestion(name: $0, itemID: UUID()) }
        let line = makeLine(name: "Milch", price: 0.99, originalName: "MILCH", suggestions: suggestions)

        let options = ReceiptReviewCard.selectionOptions(for: line)

        let listMatches = options.filter { if case .listMatch = $0 { return true } else { return false } }
        XCTAssertEqual(listMatches.count, 2,
                        "Zwei Treffer bleiben, der dritte weicht dem vorausgewählten geltenden Namen "
                        + "(Issue #37). Bekommen: \(describe(options))")
        XCTAssertEqual(options.count, 4, "Drei inhaltliche Kandidaten plus eigener Name. Bekommen: \(describe(options))")
        XCTAssertEqual(describe(options[0]), "aktuell:Milch",
                       "Der geltende Name muss vorausgewählt an erster Stelle stehen (Issue #37, AC-4). "
                       + "Bekommen: \(describe(options))")
    }

    /// AC4 (Issue #37) — passt keiner der Kandidaten zum aktuell geltenden Namen, wird dieser
    /// zusätzlich als vorausgewählte Zeile angeboten; dafür entfällt der schwächste (zuletzt
    /// gereihte) bisherige Kandidat, sodass es bei max. drei inhaltlichen Optionen bleibt.
    func testCurrentNameIsOfferedAndPreselectedWhenNoCandidateMatches() {
        let line = makeLine(
            name: "Milch",
            price: 0.99,
            originalName: "MILCH",
            suggestions: ["Hafermilch", "Buttermilch", "Vollmilch"]
                .map { ReceiptSuggestion(name: $0, itemID: UUID()) })

        let options = ReceiptReviewCard.selectionOptions(for: line)

        XCTAssertEqual(options.count, 4, "Drei inhaltliche Kandidaten plus eigener Name. Bekommen: \(describe(options))")
        XCTAssertEqual(describe(options[0]), "aktuell:Milch",
                       "Der geltende Name muss vorausgewählt an erster Stelle stehen. Bekommen: \(describe(options))")
        XCTAssertEqual(describe(options[1]), "treffer:Hafermilch", "Bekommen: \(describe(options))")
        XCTAssertEqual(describe(options[2]), "treffer:Buttermilch", "Bekommen: \(describe(options))")
        XCTAssertEqual(describe(options[3]), "eigener", "Bekommen: \(describe(options))")
        XCTAssertFalse(options.contains { describe($0) == "treffer:Vollmilch" },
                        "Der schwächste (zuletzt gereihte) Kandidat muss entfallen. Bekommen: \(describe(options))")
    }

    /// Regressionsschutz (Issue #37) — ist der geltende Name leer, ändert sich nichts: kein
    /// zusätzlicher Kandidat, die drei Treffer bleiben unangetastet.
    func testEmptyCurrentNameDoesNotAddExtraOptionWhenNoCandidateMatches() {
        let line = makeLine(
            name: "",
            price: 0.99,
            originalName: "UNLESBARER BONTEXT",
            suggestions: ["Hafermilch", "Buttermilch", "Vollmilch"]
                .map { ReceiptSuggestion(name: $0, itemID: UUID()) })

        let options = ReceiptReviewCard.selectionOptions(for: line)

        let listMatches = options.filter { if case .listMatch = $0 { return true } else { return false } }
        XCTAssertEqual(listMatches.count, 3,
                        "Bei leerem Namen darf keine Zeile entfallen. Bekommen: \(describe(options))")
        // Issue #65, Paket 2: Die Bon-Zeile bleibt auch bei leerem `line.name` ein Angebot
        // (Design-Entscheidung "Nachtrag Issue #65 (Paket 2)") — "UNLESBARER BONTEXT" normalisiert
        // zu "Unlesbarer Bontext" und ist ungleich dem leeren gewählten Namen.
        XCTAssertEqual(options.count, 5, "Drei Treffer plus Bon-Zeile plus eigener Name. Bekommen: \(describe(options))")
        XCTAssertEqual(describe(options[3]), "bon:Unlesbarer Bontext",
                       "Die Bon-Zeile muss unmittelbar vor \"Anderer Name …\" stehen. Bekommen: \(describe(options))")
        XCTAssertFalse(options.contains { describe($0).hasPrefix("aktuell:") },
                        "Bei leerem Namen darf keine `.currentName`-Zeile entstehen. Bekommen: \(describe(options))")
    }

    /// AC2 — trägt ein Treffer denselben Namen wie der KI-Vorschlag, erscheint er nur einmal.
    ///
    /// Invariante 3 der Spec: Der KI-Name bleibt wählbar, nur die separate KI-Zeile entfällt.
    func testAiSuggestionIsDroppedWhenAListMatchCarriesTheSameName() {
        let line = makeLine(
            name: "Vollmilch",
            price: 1.19,
            originalName: "MILCH 3,5% FRISCH",
            suggestions: [
                ReceiptSuggestion(name: "vollmilch", itemID: UUID()),
                ReceiptSuggestion(name: "Hafermilch", itemID: UUID()),
            ],
            resolvedByAI: true,
            aiSuggestedName: "Vollmilch",
            aiSuggestedMatchedItemID: UUID())

        let options = ReceiptReviewCard.selectionOptions(for: line)

        let aiRows = options.filter { if case .aiSuggestion = $0 { return true } else { return false } }
        XCTAssertTrue(aiRows.isEmpty,
                      "Bei namensgleichem Treffer darf keine separate KI-Zeile entstehen. Bekommen: \(describe(options))")
        let vollmilchRows = options.filter { describe($0).lowercased().hasSuffix(":vollmilch") }
        XCTAssertEqual(vollmilchRows.count, 1,
                       "Der Name darf nur einmal zur Auswahl stehen. Bekommen: \(describe(options))")
    }

    /// AC2 — ohne Treffer und ohne KI-Vorschlag bleibt der heutige Name plus eigener Name.
    func testLineWithoutSuggestionsAndWithoutAiKeepsCurrentName() {
        let line = makeLine(name: "Bio-Hackfleisch", price: 4.99, originalName: "BIO-HACKFLEISCH 400G", unit: "400g")

        let options = ReceiptReviewCard.selectionOptions(for: line)

        // Issue #65, Paket 2: "BIO-HACKFLEISCH 400G" normalisiert zu "Bio-hackfleisch 400g" und
        // weicht vom gewählten Namen "Bio-Hackfleisch" ab — die Bon-Zeile kommt als Add-on hinzu.
        XCTAssertEqual(options.count, 3, "Erwartet: aktueller Name + Bon-Zeile + eigener Name. Bekommen: \(describe(options))")
        XCTAssertEqual(describe(options[0]), "aktuell:Bio-Hackfleisch", "Bekommen: \(describe(options))")
        XCTAssertEqual(describe(options[1]), "bon:Bio-hackfleisch 400g", "Bekommen: \(describe(options))")
        XCTAssertEqual(describe(options[2]), "eigener", "Bekommen: \(describe(options))")
    }

    // MARK: - AC-21/AC-22 (Issue #65, Paket 2): Bon-Zeile

    /// AC-21 — der gedruckte Bontext wird wortweise großgeschrieben, unabhängig vom
    /// Ausgangszustand (durchgehend groß, gemischt oder klein).
    func testNormalizedReceiptTextCapitalizesEachWord() {
        XCTAssertEqual(ReceiptReviewCard.normalizedReceiptText("MILCH 3,5% FRISCH"), "Milch 3,5% Frisch")
    }

    /// AC-21 — ein bindestrich-verbundenes Wort wird als EIN Wort behandelt: nur der erste
    /// Buchstabe des gesamten Worts wird groß, nicht jeder Teil rechts vom Bindestrich.
    func testNormalizedReceiptTextKeepsHyphenatedWordAsOneUnit() {
        XCTAssertEqual(ReceiptReviewCard.normalizedReceiptText("BIO-HACKFLEISCH 400G"), "Bio-hackfleisch 400g")
    }

    /// AC-22 — das vom PO selbst genannte Unsinns-Beispiel „BTR" (3 Zeichen) wird unterdrückt,
    /// unabhängig davon, wie sehr sich der Bontext vom gewählten Namen unterscheidet.
    func testShouldOfferReceiptTextOptionRejectsNamesBelowMinLength() {
        XCTAssertFalse(ReceiptReviewCard.shouldOfferReceiptTextOption(originalName: "BTR", selectedName: "Butter"))
    }

    /// AC-22 — entspricht der normalisierte Bontext (case-insensitiv) bereits dem gewählten
    /// Namen, ist die Bon-Zeile redundant und wird unterdrückt.
    func testShouldOfferReceiptTextOptionRejectsNameEqualToSelection() {
        XCTAssertFalse(ReceiptReviewCard.shouldOfferReceiptTextOption(originalName: "MILCH", selectedName: "Milch"))
    }

    /// AC-22 — Regelfall: Bontext lang genug und ungleich dem gewählten Namen → Angebot.
    func testShouldOfferReceiptTextOptionAcceptsDifferingName() {
        XCTAssertTrue(ReceiptReviewCard.shouldOfferReceiptTextOption(
            originalName: "MILCH 3,5% FRISCH", selectedName: "Frische Vollmilch"))
    }

    /// AC-22 (Design-Entscheidung, „Nachtrag Issue #65 (Paket 2)") — ist `selectedName` leer,
    /// bleibt die Bon-Zeile trotzdem ein Angebot: gerade wenn nichts sonst passt, hilft der rohe
    /// Bontext als zusätzliche Wahlmöglichkeit; `isSavable` verhindert ohnehin jedes Speichern
    /// mit leerem Namen.
    func testShouldOfferReceiptTextOptionAcceptsEmptySelection() {
        XCTAssertTrue(ReceiptReviewCard.shouldOfferReceiptTextOption(
            originalName: "UNLESBARER BONTEXT", selectedName: ""))
    }

    /// AC-21 — Auswahl der Bon-Zeile setzt den normalisierten Bontext als Namen und löscht
    /// Artikel-Zuordnung und KI-Kennzeichnung — gleiche Form wie `.currentName`.
    func testChoosingReceiptTextSetsNameAndClearsMatchAndAiFlag() {
        var line = makeLine(name: "Milch", price: 0.99, originalName: "MILCH 3,5% FRISCH",
                            matchedItemID: UUID(), resolvedByAI: true, aiSuggestedName: "Milch")

        ReceiptReviewCard.applySelection(&line, option: .receiptText(name: "Milch 3,5% Frisch"))

        XCTAssertEqual(line.name, "Milch 3,5% Frisch")
        XCTAssertNil(line.matchedItemID)
        XCTAssertFalse(line.resolvedByAI)
        XCTAssertEqual(line.originalName, "MILCH 3,5% FRISCH")
    }

    // MARK: - AC5/AC6/AC7: Auswahl übernehmen

    /// AC5 — ein Listen-Treffer setzt Name und Artikel-Zuordnung und löscht die KI-Markierung.
    ///
    /// Muss den heutigen Chip-Tap Zeichen für Zeichen nachbilden, sonst lernt `save()` den
    /// Preis auf einen anderen Artikel als angezeigt.
    func testChoosingListMatchSetsNameAndItemAndClearsAiFlag() {
        let itemID = UUID()
        var line = makeLine(name: "Milch", price: 0.99, originalName: "MILCH",
                            matchedItemID: UUID(), resolvedByAI: true,
                            aiSuggestedName: "Milch")
        let suggestion = ReceiptSuggestion(name: "Buttermilch", itemID: itemID)

        ReceiptReviewCard.applySelection(&line, option: .listMatch(suggestion))

        XCTAssertEqual(line.name, "Buttermilch")
        XCTAssertEqual(line.matchedItemID, itemID)
        XCTAssertFalse(line.resolvedByAI, "Ein selbst gewählter Treffer ist kein KI-Vorschlag mehr.")
        XCTAssertEqual(line.originalName, "MILCH", "Der Bontext darf sich nie ändern.")
    }

    /// AC6 — der KI-Vorschlag lässt sich nach einer Zwischenauswahl exakt wiederherstellen.
    func testChoosingAiSuggestionRestoresAiStateAfterAnotherSelection() {
        let aiItemID = UUID()
        var line = makeLine(name: "Frische Vollmilch", price: 1.19, originalName: "MILCH 3,5% FRISCH",
                            matchedItemID: aiItemID, resolvedByAI: true,
                            aiSuggestedName: "Frische Vollmilch",
                            aiSuggestedMatchedItemID: aiItemID)

        ReceiptReviewCard.applySelection(&line, option: .listMatch(ReceiptSuggestion(name: "Hafermilch", itemID: UUID())))
        ReceiptReviewCard.applySelection(&line, option: .aiSuggestion(name: "Frische Vollmilch"))

        XCTAssertTrue(line.resolvedByAI, "Nach Rückkehr zum KI-Vorschlag muss die Kennzeichnung wieder stehen.")
        XCTAssertEqual(line.name, "Frische Vollmilch")
        XCTAssertEqual(line.matchedItemID, aiItemID, "Die ursprüngliche Artikel-Zuordnung der KI muss zurückkommen.")
    }

    /// AC7 — ein eigener Name löst die Artikel-Zuordnung und die KI-Kennzeichnung.
    func testEnteringCustomNameClearsMatchAndAiFlag() {
        var line = makeLine(name: "Milch", price: 0.99, originalName: "MILCH",
                            matchedItemID: UUID(), resolvedByAI: true, aiSuggestedName: "Milch")

        ReceiptReviewCard.applyCustomName(&line, name: "Ziegenmilch")

        XCTAssertEqual(line.name, "Ziegenmilch")
        XCTAssertNil(line.matchedItemID, "Ein frei eingetippter Name darf nicht am alten Artikel hängen bleiben.")
        XCTAssertFalse(line.resolvedByAI)
        XCTAssertEqual(line.originalName, "MILCH", "Der Bontext darf sich nie ändern.")
    }

    /// Invariante 2 — keiner der drei Wege verändert den Bontext.
    func testOriginalNameSurvivesAllThreeSelectionPaths() {
        var line = makeLine(name: "Fischstäbchen", price: 1.99, originalName: "FISCHSTAEBCHEN 15ST",
                            resolvedByAI: true, aiSuggestedName: "Fischstäbchen")

        ReceiptReviewCard.applySelection(&line, option: .listMatch(ReceiptSuggestion(name: "Lachs", itemID: UUID())))
        XCTAssertEqual(line.originalName, "FISCHSTAEBCHEN 15ST", "Bontext nach Treffer-Auswahl verändert.")

        ReceiptReviewCard.applySelection(&line, option: .aiSuggestion(name: "Fischstäbchen"))
        XCTAssertEqual(line.originalName, "FISCHSTAEBCHEN 15ST", "Bontext nach KI-Auswahl verändert.")

        ReceiptReviewCard.applyCustomName(&line, name: "Seelachs")
        XCTAssertEqual(line.originalName, "FISCHSTAEBCHEN 15ST", "Bontext nach eigener Eingabe verändert.")
    }

    // MARK: - AC8: Preiszeile

    /// AC8 (Fall 4) — ohne erkennbare Menge bleibt ein Stück. „15ST" ist keine Gewichtsangabe,
    /// die Regel erfindet nichts (vgl. Negativfall in `ReceiptParserPriceTests`).
    func testPriceSummaryFallsBackToSinglePiece() {
        let line = makeLine(name: "Fischstäbchen", price: 1.99, originalName: "FISCHSTAEBCHEN 15ST")

        XCTAssertEqual(summary(line), "1,99 € · 1 St. · 1,99 € je Stück")
    }

    /// AC8 (Fall 3) — die im Bontext gedruckte Füllmenge ergibt den Kilopreis.
    func testPriceSummaryUsesPrintedGramSize() {
        let line = makeLine(name: "Gouda jung", price: 3.99, originalName: "GOUDA JUNG 400G", unit: "400g")

        XCTAssertEqual(summary(line), "3,99 € · 400g · 9,98 € je kg")
    }

    /// AC8 (Fall 3) — Flüssigkeiten rechnen auf den Literpreis.
    func testPriceSummaryUsesLitrePriceForLiquids() {
        let line = makeLine(name: "Cola", price: 1.29, originalName: "COLA 1,5L", unit: "1,5l")

        XCTAssertEqual(summary(line), "1,29 € · 1,5l · 0,86 € je l")
    }

    /// AC8 (Fall 2) — eine Stückzahl größer eins ergibt den Stückpreis.
    func testPriceSummaryUsesQuantityWhenGreaterThanOne() {
        let line = makeLine(name: "Brötchen", price: 1.60, originalName: "BROETCHEN", quantity: 4)

        XCTAssertEqual(summary(line), "1,60 € · 4 St. · 0,40 € je Stück")
    }

    /// AC8 (Fall 1) — die Gewichtszeile des Bons hat Vorrang vor allem anderen.
    func testPriceSummaryUsesWeightBasisFirst() {
        let line = makeLine(name: "Lachs", price: 7.99, originalName: "LACHS", weightBasis: 250)

        XCTAssertEqual(summary(line), "7,99 € · 250 g · 31,96 € je kg")
    }

    // MARK: - AC11: Kopfzeile

    /// AC11 — die Kopfzeile fasst Anzahl, Auswahl und Summe zusammen.
    func testSectionHeaderTextShowsCountSelectedAndSum() {
        let text = normalized(ReceiptReviewCard.sectionHeaderText(count: 7, selected: 6, sum: 18.94))

        XCTAssertEqual(text, "7 Positionen · 6 ausgewählt · 18,94 €")
    }

    // MARK: - AC9: Mengen-Editor

    /// AC9 — Umstellung auf Stück setzt die Stückzahl und räumt eine alte Gewichtsbasis weg.
    func testApplyQuantityEditWithPiecesSetsQuantityAndClearsWeight() {
        var line = makeLine(name: "Brötchen", price: 1.60, originalName: "BROETCHEN", weightBasis: 500)

        ReceiptReviewCard.applyQuantityEdit(&line, mode: .pieces, value: 4)

        XCTAssertEqual(line.quantity, 4, accuracy: 0.001)
        XCTAssertNil(line.weightBasis, "Bei Stückzahl darf keine Gewichtsbasis stehen bleiben.")
        XCTAssertEqual(line.price, 1.60, accuracy: 0.001, "Der Mengen-Editor ändert den Preis nicht.")
        XCTAssertEqual(summary(line), "1,60 € · 4 St. · 0,40 € je Stück")
    }

    /// AC9 — Umstellung auf Gramm setzt die Gewichtsbasis und normiert die Stückzahl auf eins.
    func testApplyQuantityEditWithGramsSetsWeightAndResetsQuantity() {
        var line = makeLine(name: "Lachs", price: 7.99, originalName: "LACHS", quantity: 3)

        ReceiptReviewCard.applyQuantityEdit(&line, mode: .grams, value: 250)

        XCTAssertEqual(line.weightBasis ?? -1, 250, accuracy: 0.001)
        XCTAssertEqual(line.quantity, 1, accuracy: 0.001)
        XCTAssertEqual(summary(line), "7,99 € · 250 g · 31,96 € je kg")
    }

    /// AC9 — null Stück ist keine gültige Menge; sonst teilt `learningQuantity` durch null.
    func testApplyQuantityEditFloorsPiecesAtOne() {
        var line = makeLine(name: "Brötchen", price: 1.60, originalName: "BROETCHEN", quantity: 4)

        ReceiptReviewCard.applyQuantityEdit(&line, mode: .pieces, value: 0)

        XCTAssertEqual(line.quantity, 1, accuracy: 0.001, "Stückzahl darf nie unter eins fallen.")
    }

    /// AC9 — Größe und Bontext bleiben unangetastet, egal wie oft umgestellt wird.
    func testApplyQuantityEditNeverTouchesUnitOrOriginalName() {
        var line = makeLine(name: "Lachs", price: 7.99, originalName: "LACHS 250G",
                            unit: "250g", weightBasis: 250)

        ReceiptReviewCard.applyQuantityEdit(&line, mode: .pieces, value: 2)
        ReceiptReviewCard.applyQuantityEdit(&line, mode: .grams, value: 400)
        ReceiptReviewCard.applyQuantityEdit(&line, mode: .pieces, value: 1)

        XCTAssertEqual(line.unit, "250g", "Die gedruckte Größe ist Anzeige, kein Eingabefeld.")
        XCTAssertEqual(line.originalName, "LACHS 250G", "Der Bontext darf sich nie ändern.")
    }

    // MARK: - Issue #50, Paket 1 — Regel 10: leerer Name ist kein speicherbarer Zustand

    /// AC-15 — Leert der Nutzer das vorbelegte Feld „Anderer Name …", fällt die Zeile auf die
    /// Auswahl zurück, die unmittelbar zuvor galt. `line.name` wird nie leer geschrieben, weil
    /// `save()` daraus einen Kaufdatensatz ohne Namen machen würde.
    func testApplyCustomNameOrFallbackRestoresPreviousSelectionOnEmptyName() {
        let vollmilchID = UUID()
        var line = makeLine(name: "Vollmilch", price: 1.19, originalName: "MILCH 3,5% FRISCH",
                            matchedItemID: vollmilchID)

        ReceiptReviewCard.applyCustomNameOrFallback(
            &line, name: "",
            previousSelection: (name: "Vollmilch", matchedItemID: vollmilchID, resolvedByAI: false))

        XCTAssertEqual(line.name, "Vollmilch",
                       "Der leere Zwischenstand darf nie in die Zeile geschrieben werden.")
        XCTAssertEqual(line.matchedItemID, vollmilchID,
                       "Die Artikel-Zuordnung der vorherigen Auswahl kommt mit zurück.")
        XCTAssertFalse(line.resolvedByAI)
    }

    /// AC-15 — Alle drei Felder fallen zurück, nicht nur der Name: ein KI-Vorschlag käme sonst
    /// ohne seine Art.-50-Kennzeichnung wieder, obwohl er sie vorher trug.
    func testApplyCustomNameOrFallbackRestoresAIStateOnEmptyName() {
        let aiID = UUID()
        var line = makeLine(name: "Frische Vollmilch", price: 1.19, originalName: "MILCH 3,5%",
                            matchedItemID: aiID, resolvedByAI: true,
                            aiSuggestedName: "Frische Vollmilch", aiSuggestedMatchedItemID: aiID)

        ReceiptReviewCard.applyCustomNameOrFallback(
            &line, name: "",
            previousSelection: (name: "Frische Vollmilch", matchedItemID: aiID, resolvedByAI: true))

        XCTAssertEqual(line.name, "Frische Vollmilch")
        XCTAssertTrue(line.resolvedByAI,
                      "Die KI-Kennzeichnung gehört zur vorherigen Auswahl und muss mit zurückkommen.")
        XCTAssertEqual(line.matchedItemID, aiID)
    }

    /// AC-15 (Regression) — Für jeden nicht-leeren Namen verhält sich die neue Funktion exakt wie
    /// das bestehende `applyCustomName`: eigene Eingabe löst Artikel-Identität und KI-Kennzeichnung.
    func testApplyCustomNameOrFallbackAppliesNonEmptyNameUnchanged() {
        var line = makeLine(name: "Vollmilch", price: 1.19, originalName: "MILCH 3,5% FRISCH",
                            matchedItemID: UUID(), resolvedByAI: true)

        ReceiptReviewCard.applyCustomNameOrFallback(
            &line, name: "H-Milch",
            previousSelection: (name: "Vollmilch", matchedItemID: UUID(), resolvedByAI: true))

        XCTAssertEqual(line.name, "H-Milch")
        XCTAssertNil(line.matchedItemID, "Ein selbst getippter Name trägt keine Artikel-Identität.")
        XCTAssertFalse(line.resolvedByAI, "Ein selbst getippter Name ist kein KI-Vorschlag.")
        XCTAssertEqual(line.originalName, "MILCH 3,5% FRISCH", "Der Bontext bleibt unangetastet.")
    }

    // MARK: - Issue #50, Paket 1b — F002: ein Name aus reinen Leerzeichen ist leer

    /// AC-18 — Ein Feld, in dem nur noch Leerzeichen stehen, ist für den Nutzer leer und löst
    /// denselben Rückfall aus wie ein vollständig geleertes Feld: Name, `matchedItemID` UND
    /// `resolvedByAI` der vorherigen Auswahl kommen gemeinsam zurück.
    ///
    /// Vor Paket 1b guardete Regel 10 auf `isEmpty`, Regel 11 (`isSavable`) dagegen auf den
    /// getrimmten Namen — ein einzelnes Leerzeichen fiel zwischen beiden durch: `line.name` wurde
    /// " ", die Position zählte in Kopfzeile und Summe weiter mit, `save()` verwarf sie still.
    func testApplyCustomNameOrFallbackRestoresPreviousSelectionOnWhitespaceOnlyName() {
        let vollmilchID = UUID()
        // Zustand während der Eingabe eines eigenen Namens: `applyCustomName` hat Artikel-Identität
        // und KI-Kennzeichnung schon gelöscht — beide müssen mit dem Namen zurückkommen.
        var line = makeLine(name: "Vollm", price: 1.19, originalName: "MILCH 3,5% FRISCH",
                            matchedItemID: nil, resolvedByAI: false,
                            aiSuggestedName: "Frische Vollmilch", aiSuggestedMatchedItemID: vollmilchID)

        ReceiptReviewCard.applyCustomNameOrFallback(
            &line, name: "   ",
            previousSelection: (name: "Frische Vollmilch", matchedItemID: vollmilchID, resolvedByAI: true))

        XCTAssertEqual(line.name, "Frische Vollmilch",
                       "Ein Name aus reinen Leerzeichen darf nie in die Zeile geschrieben werden — "
                       + "bekommen: \"\(line.name)\"")
        XCTAssertEqual(line.matchedItemID, vollmilchID,
                       "Die Artikel-Zuordnung der vorherigen Auswahl kommt mit zurück.")
        XCTAssertTrue(line.resolvedByAI,
                      "Die KI-Kennzeichnung gehört zur vorherigen Auswahl und muss mit zurückkommen.")
    }

    /// AC-18 (Verteidigungs-Rückfall) — Ist der festgehaltene `previousSelection.name` selbst
    /// reine Leerzeichen, gilt er nicht als gültiger Rückfall: die Zeile fällt auf ihren Bontext
    /// (`originalName`) zurück, ohne Artikel-Identität und ohne KI-Kennzeichnung.
    func testApplyCustomNameOrFallbackFallsBackToOriginalNameWhenPreviousSelectionIsWhitespaceOnly() {
        var line = makeLine(name: "Butter", price: 1.19, originalName: "BTR",
                            matchedItemID: nil, resolvedByAI: false)

        ReceiptReviewCard.applyCustomNameOrFallback(
            &line, name: " ",
            previousSelection: (name: "  ", matchedItemID: UUID(), resolvedByAI: true))

        XCTAssertEqual(line.name, "BTR",
                       "Ein festgehaltenes Leerzeichen ist kein gültiger Rückfall — dann gilt der "
                       + "Bontext. Bekommen: \"\(line.name)\"")
        XCTAssertNil(line.matchedItemID,
                     "Der Bontext trägt keine Artikel-Identität.")
        XCTAssertFalse(line.resolvedByAI,
                       "Der Bontext ist kein KI-Vorschlag.")
    }
}
