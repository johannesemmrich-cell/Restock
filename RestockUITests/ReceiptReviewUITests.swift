import XCTest

/// Einstieg in den Bon-Prüf-Screen OHNE Kamera und OHNE Texterkennung (Issue #28) und
/// Prüfstrecke für den Karten-Umbau dieses Screens (Issue #23).
///
/// Der Screen entsteht im echten Betrieb nur am Ende der Kette Teilen-Erweiterung →
/// App-Gruppe → `HomeView.checkPendingReceiptScan()` → Sheet. Kamera und OCR laufen im
/// Simulator nicht deterministisch, also setzt `-seedReceiptReviewForUITests` (DEBUG-only,
/// `SmartCartApp.swift`) den Laden samt festem Bon direkt in die App-Gruppe — der Rest der
/// Kette läuft unverändert durch den Produktcode. Kein Sonderpfad im Produkt, keine
/// Testattrappe: was hier geprüft wird, ist derselbe Weg, den ein Nutzer nimmt.
///
/// WICHTIG — Testsprache: Der Navigationstitel „Bon scannen — Lidl" ist deutscher
/// Produkttext. Dass der Simulator im Testlauf deutsch läuft, steht in `Restock.xcscheme`
/// am `<TestAction>` (`language = "de"`, `region = "DE"`) — siehe Kopfkommentar in
/// `RestockUITests.swift`.
///
/// WICHTIG — Determinismus des festen Bons: Beim Handoff läuft `reResolveAIIfNeeded()` und
/// würde Zeilen erneut durch die Namensauflösung schicken (Wörterbuch, Ähnlichkeitssuche,
/// gelernte Zuordnungen aus FRÜHEREN Läufen). Der feste Bon ist so gebaut, dass jede Zeile
/// entweder als KI-aufgelöst markiert ist oder einen vom Bontext abweichenden Namen trägt —
/// damit ist die Menge der nachzulösenden Zeilen leer und der Bon in jedem Lauf gleich.
/// Details und die Invariante: `docs/specs/testing/receipt-review-test-entry.md`.
final class ReceiptReviewUITests: XCTestCase {

    // MARK: - Der gesäte Bon (Quelle: SmartCartApp.seedReceiptReviewForUITestsIfNeeded)

    /// Genau die vier Zeilen, die der Seed in die App-Gruppe legt — als Konstanten hier, damit
    /// jede Erwartung unten am tatsächlichen Fixture hängt und nicht an einer Annahme.
    private enum Seed {
        /// Rohtext, wie er auf dem Bon steht (`originalName`). Zeile 1 ist mit 42 Zeichen die
        /// längste — sie ist der eigentliche Prüffall für AC1 (nie abschneiden).
        static let rawTexts = [
            "MILCH 3,5% FRISCH",
            "BIO-HACKFLEISCH GEMISCHT RIND SCHWEIN 400G",
            "MILCH",
            "BROETCHEN",
        ]
        /// Zeile mit `resolvedByAI = true` — trägt die Art.-50-Kennzeichnung.
        static let aiLine = 0
        /// Einzige Zeile mit drei Listen-Treffern (Hafermilch, Buttermilch, Vollmilch).
        /// Der Seed hat keine Zeile mit KI-Vorschlag UND Treffern zugleich; die Kappung von
        /// fünf auf drei inhaltliche Optionen prüfen deshalb die Unit-Tests
        /// (`ReceiptReviewCardTests`), hier wird die Obergrenze von vier Zeilen geprüft.
        static let suggestionLine = 2
        /// Name des zweiten Treffers an `suggestionLine` (Option 1).
        static let secondSuggestion = "Buttermilch"
        /// Zugeordneter Artikel und Preis der Zeile `suggestionLine` — nach dem Speichern muss
        /// genau dieser Preis am Artikel in der Liste stehen (AC12).
        static let matchedItemName = "Milch"
        static let matchedItemPriceText = "0,99 €"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Räumt den Seed nach JEDEM Test wieder weg — sonst erbt die Bestandssuite ihn.
    ///
    /// Der App-Group-Container überlebt den einzelnen Test. Im gemeinsamen `xcodebuild
    /// test`-Lauf startet `RestockUITests` direkt nach dieser Klasse und fand den geseedeten
    /// Laden „Lidl" samt sechs Artikeln vor; `testAddStoreAndQuickAddItemShowsPriceWithoutCrash`
    /// fiel daraufhin durch. Auf leerem Gerät ist derselbe Test grün — der Unterschied ist
    /// allein der liegengebliebene Seed. Das Aufräumen gehört deshalb hierher, zu dem Test,
    /// der die Daten anlegt, nicht in die fremde Testklasse.
    override func tearDown() {
        super.tearDown()
        // Dunkelmodus-Tests stellen das Gerät um — zurücksetzen, sonst erbt ihn der nächste Test.
        XCUIDevice.shared.appearance = .light
        let cleaner = XCUIApplication()
        cleaner.launchArguments = ["-hasCompletedOnboarding", "YES", "-clearReceiptReviewSeedForUITests"]
        cleaner.launch()
        cleaner.terminate()
    }

    // MARK: - Hilfen

    private func launchedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-seedReceiptReviewForUITests"]
        app.launch()
        return app
    }

    /// Wartet, bis die App wirklich vorn und ansprechbar ist, BEVOR auf das Sheet gewartet wird.
    ///
    /// Nach einem kalten Install ist `launch()` allein kein verlässlicher Startpunkt: In einem
    /// Prüflauf brauchte schon das Hochfahren bis „App idle" rund 9,5 s (Automations-Sitzung
    /// 5,5 s, Idle-Warten weitere 2,5 s), sodass die anschließende Wartezeit auf die
    /// Navigationsleiste fast vollständig vom Start selbst aufgebraucht wurde und der Test
    /// durchfiel, obwohl das Sheet kurz darauf erschien. Gleiches defensives Muster wie das
    /// `hasKeyboardFocus`-Warten in `RestockUITests.swift` (dort Z. 183-185): erst den
    /// Vorbedingungs-Zustand abwarten, dann die eigentliche Prüfung.
    ///
    /// Reine Robustheit — geprüft wird danach exakt dasselbe wie vorher.
    ///
    /// 30 s statt 20 s: Im RED-Lauf zu #23 fiel der jeweils ERSTE Test der Klasse durch, weil
    /// beim kalten Install schon das Hochfahren die Wartezeit aufbrauchte (35,9 s Gesamtdauer,
    /// Fehler „Sheet ist nicht erschienen", während alle folgenden Tests das Sheet in unter
    /// 5 s sahen). Der Fehlschlag lag am Startzeitpunkt, nicht an der Sache.
    private func waitUntilSettled(_ app: XCUIApplication) {
        let isForeground = NSPredicate(format: "state == %d", XCUIApplication.State.runningForeground.rawValue)
        expectation(for: isForeground, evaluatedWith: app)
        waitForExpectations(timeout: 30)
    }

    /// Öffnet den Prüf-Screen und gibt die laufende App zurück.
    private func openedReviewSheet(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = launchedApp()
        waitUntilSettled(app)
        XCTAssertTrue(app.navigationBars["Bon scannen — Lidl"].waitForExistence(timeout: 30),
                      "Das Bon-Prüf-Sheet ist nicht erschienen — Seed oder Handoff greift nicht.",
                      file: file, line: line)
        return app
    }

    /// Sucht ein Element allein über seine Kennung, unabhängig vom Elementtyp.
    ///
    /// SwiftUI bildet dieselbe Karte je nach Fassung als `button`, `other` oder `staticText`
    /// ab — ein typgebundener Zugriff (`app.buttons[…]`) würde am Typ scheitern statt an der
    /// Sache. Geprüft wird die Kennung aus der Spec-Tabelle, nicht der Elementtyp.
    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Apples Währungsformatierer setzt je nach OS-Version U+00A0/U+202F vor das „€" —
    /// für einen Textvergleich auf ein normales Leerzeichen normalisieren.
    private func normalized(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{2009}", with: " ")
    }

    /// Leert ein Textfeld über die Löschtaste und tippt den neuen Wert.
    ///
    /// Erst auf den Tastaturfokus warten, dann tippen (Issue #32): ohne dieses Warten scheitert
    /// die Eingabe sporadisch mit „Neither element nor any descendant has keyboard focus".
    private func replaceText(_ field: XCUIElement, with newValue: String, timeout: TimeInterval = 10) {
        field.tap()
        expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: field)
        waitForExpectations(timeout: timeout)
        let existing = (field.value as? String) ?? ""
        if !existing.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        }
        field.typeText(newValue)
    }

    // MARK: - Grundgerüst (#28, auf den Karten-Aufbau nachgezogen)

    /// Der Prüf-Screen erscheint von selbst und trägt alle vier Bon-Positionen als Karte.
    ///
    /// Dass „Speichern" bedienbar ist, ist kein Beiwerk, sondern der Beweis, dass die
    /// Ladenerkennung gegriffen hat: `canSave` bleibt gesperrt, solange der Laden nicht
    /// sicher erkannt wurde (`storeNeedsConfirmation`).
    func testReviewSheetOpensFromShareHandoff() {
        let app = openedReviewSheet()

        for index in Seed.rawTexts.indices {
            XCTAssertTrue(element(app, "receiptReview.line.\(index).card").waitForExistence(timeout: 5),
                          "Zeile \(index): Karte fehlt.")
            XCTAssertTrue(element(app, "receiptReview.line.\(index).price").exists,
                          "Zeile \(index): Preiszeile fehlt.")
            XCTAssertTrue(element(app, "receiptReview.line.\(index).checkbox").exists,
                          "Zeile \(index): Häkchen fehlt.")
        }

        XCTAssertTrue(element(app, "receiptReview.line.\(Seed.aiLine).aiMark").exists,
                      "Zeile \(Seed.aiLine) ist als KI-aufgelöst geseedet, trägt aber keine KI-Marke.")

        let saveButton = app.buttons["receiptReview.saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Speichern-Knopf fehlt.")
        XCTAssertTrue(saveButton.isHittable,
                      "Speichern ist gesperrt — der Laden wurde nicht sicher erkannt.")
    }

    // MARK: - AC1: Bontext sichtbar und vollständig

    /// AC1 — der gedruckte Bontext steht auf jeder Karte, unverändert und ungekürzt.
    ///
    /// Das ist die Kernbeschwerde aus Issue #23: Bei „Fisch 1,99" und „Fisch 7,99" war nicht
    /// erkennbar, welche Bon-Zeile gemeint ist. Geprüft wird deshalb nicht nur Existenz,
    /// sondern Zeichengleichheit mit dem gesäten Rohtext — inklusive der 42 Zeichen langen
    /// Hackfleisch-Zeile, an der die heutige Darstellung abschneiden würde.
    func testOriginalReceiptTextIsVisibleOnEveryLine() {
        let app = openedReviewSheet()

        for (index, rawText) in Seed.rawTexts.enumerated() {
            let textElement = element(app, "receiptReview.line.\(index).originalName")
            XCTAssertTrue(textElement.waitForExistence(timeout: 5),
                          "Zeile \(index): Bontext wird nicht angezeigt.")
            XCTAssertEqual(textElement.label, rawText,
                           "Zeile \(index): Bontext weicht vom gedruckten Text ab (abgeschnitten oder umformatiert).")
            XCTAssertFalse(textElement.label.contains("…"),
                           "Zeile \(index): Bontext ist mit Auslassungszeichen gekürzt.")
        }
    }

    // MARK: - AC3: KI-Marke einzeilig

    /// AC3 — die Pille „KI-Vorschlag" bricht nicht mehr um.
    ///
    /// Im Screenshot zu #23 brach sie in vier Zeilen (KI-/Vor/sch/lag). Die Marke ist
    /// 10 pt groß mit je 2 pt Innenabstand oben/unten, einzeilig also rund 18 pt hoch; zwei
    /// Zeilen wären bereits über 28 pt. Die Grenze von 26 pt trennt beide Fälle eindeutig.
    /// Zusätzlich muss die Pille breiter als hoch sein — der Vierfach-Umbruch machte sie
    /// schmal und hoch.
    func testAiMarkStaysOnOneLine() {
        let app = openedReviewSheet()

        let mark = element(app, "receiptReview.line.\(Seed.aiLine).aiMark")
        XCTAssertTrue(mark.waitForExistence(timeout: 5), "KI-Marke an der KI-Optionszeile fehlt.")
        XCTAssertLessThan(mark.frame.height, 26,
                          "KI-Marke ist \(mark.frame.height) pt hoch — sie bricht um statt einzeilig zu bleiben.")
        XCTAssertGreaterThan(mark.frame.width, mark.frame.height,
                             "KI-Marke ist höher als breit — typisches Bild des Wort-für-Wort-Umbruchs aus #23.")
    }

    // MARK: - AC2: höchstens vier Auswahlzeilen

    /// AC2 — eine Karte bietet höchstens drei inhaltliche Namen plus „Anderer Name …".
    ///
    /// Geprüft an der Zeile mit drei Listen-Treffern: Option 0 bis 3 existieren, Option 4
    /// existiert nicht. Heute gibt es überhaupt keine Auswahlzeilen, sondern ein Textfeld mit
    /// seitlich weglaufenden Vorschlags-Chips — der Test schlägt deshalb an Option 0 fehl.
    func testCardShowsAtMostFourSelectionOptions() {
        let app = openedReviewSheet()

        for option in 0...3 {
            XCTAssertTrue(
                element(app, "receiptReview.line.\(Seed.suggestionLine).option.\(option)").waitForExistence(timeout: 5),
                "Auswahlzeile \(option) fehlt an der Karte mit drei Listen-Treffern.")
        }
        XCTAssertFalse(
            element(app, "receiptReview.line.\(Seed.suggestionLine).option.4").exists,
            "Die Karte zeigt mehr als vier Auswahlzeilen — die Kappung auf drei inhaltliche Optionen greift nicht.")
    }

    // MARK: - AC5: Listen-Treffer wählen

    /// AC5 — Antippen einer Treffer-Zeile wählt sie aus und macht das sichtbar.
    ///
    /// Die Auswahl IST der Name dieser Position (Variante B, „Auswahl statt Tippen") — es gibt
    /// keine zweite Stelle, an der der gewählte Name stünde. Von außen prüfbar ist sie deshalb
    /// nur über den Auswahl-Zustand der Zeile: die gewählte Optionszeile muss das
    /// Bedienhilfen-Merkmal „ausgewählt" tragen.
    func testTappingListMatchSelectsThatOption() {
        let app = openedReviewSheet()

        let option = element(app, "receiptReview.line.\(Seed.suggestionLine).option.1")
        XCTAssertTrue(option.waitForExistence(timeout: 5), "Zweite Auswahlzeile fehlt.")
        XCTAssertTrue(option.label.contains(Seed.secondSuggestion),
                      "Zweite Auswahlzeile trägt nicht den erwarteten Treffer \(Seed.secondSuggestion).")
        option.tap()

        XCTAssertTrue(option.isSelected,
                      "Die angetippte Zeile ist danach nicht als ausgewählt gekennzeichnet.")
        XCTAssertFalse(element(app, "receiptReview.line.\(Seed.suggestionLine).option.0").isSelected,
                       "Die zuvor gewählte Zeile ist weiterhin als ausgewählt gekennzeichnet — es ist keine Einfachauswahl.")
    }

    // MARK: - AC7: eigener Name

    /// AC7 — „Anderer Name …" öffnet ein sofort beschreibbares Feld an dieser Karte.
    ///
    /// Die letzte Auswahlzeile ist immer „Anderer Name …"; an der KI-Zeile ohne Treffer ist das
    /// Option 1 (KI-Vorschlag + eigener Name).
    func testCustomNameOptionOpensFocusedTextField() {
        let app = openedReviewSheet()

        let customOption = element(app, "receiptReview.line.\(Seed.aiLine).option.1")
        XCTAssertTrue(customOption.waitForExistence(timeout: 5), "Auswahlzeile für den eigenen Namen fehlt.")
        customOption.tap()

        let field = app.textFields["receiptReview.line.\(Seed.aiLine).customNameField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Textfeld für den eigenen Namen erscheint nicht.")
        expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: field)
        waitForExpectations(timeout: 10)
    }

    // MARK: - AC9: Preis und Menge ändern

    /// AC9 — „Ändern" öffnet Preis- und Mengenfeld; beide wirken sofort auf die Preiszeile.
    ///
    /// Geprüft wird die Zeile mit 0,99 € und einem Stück: neuer Preis 2,00 € muss in der
    /// Preiszeile erscheinen, nach Umschalten auf „Stück" und Eingabe 4 muss dort „4 St." und
    /// der daraus berechnete Stückpreis 0,50 € stehen — genau die Basis, mit der die App den
    /// Preis lernt.
    func testChangeOpensPriceAndQuantityEditorAndUpdatesSummary() {
        let app = openedReviewSheet()
        let line = Seed.suggestionLine

        let changeButton = element(app, "receiptReview.line.\(line).changeButton")
        XCTAssertTrue(changeButton.waitForExistence(timeout: 5), "Knopf zum Ändern fehlt an der Preiszeile.")
        changeButton.tap()

        let priceField = app.textFields["receiptReview.line.\(line).priceField"]
        let quantityField = app.textFields["receiptReview.line.\(line).quantityField"]
        let modeSwitch = element(app, "receiptReview.line.\(line).quantityMode")
        XCTAssertTrue(priceField.waitForExistence(timeout: 5), "Preisfeld erscheint nach dem Ändern nicht.")
        XCTAssertTrue(quantityField.exists, "Mengenfeld erscheint nach dem Ändern nicht.")
        XCTAssertTrue(modeSwitch.exists, "Umschalter Stück/Gramm erscheint nach dem Ändern nicht.")

        replaceText(priceField, with: "2,00")
        let summary = element(app, "receiptReview.line.\(line).price")
        XCTAssertTrue(normalized(summary.label).contains("2,00 €"),
                      "Preiszeile zeigt den neuen Preis nicht: \(summary.label)")

        modeSwitch.buttons["Stück"].tap()
        replaceText(quantityField, with: "4")
        let updated = normalized(summary.label)
        XCTAssertTrue(updated.contains("4 St."),
                      "Preiszeile zeigt die neue Stückzahl nicht: \(updated)")
        XCTAssertTrue(updated.contains("0,50 €"),
                      "Preiszeile zeigt den neuen Stückpreis nicht: \(updated)")
    }

    // MARK: - AC10/AC11: Kopfzeile

    /// AC11 — die Kopfzeile nennt Anzahl, Auswahl und Summe des gesäten Bons.
    func testSectionHeaderShowsPositionsSelectedAndSum() {
        let app = openedReviewSheet()

        let header = element(app, "receiptReview.sectionHeader")
        XCTAssertTrue(header.waitForExistence(timeout: 5), "Kopfzeile über den Positionen fehlt.")
        XCTAssertEqual(normalized(header.label).lowercased(),
                       "4 positionen · 4 ausgewählt · 8,73 €",
                       "Kopfzeile zeigt nicht Anzahl, Auswahl und Summe für den gesäten Bon.")
    }

    /// AC10 — Häkchen abwählen senkt Zähler und Summe um genau diese Position.
    ///
    /// Die KI-Zeile kostet 1,19 €; aus 8,73 € werden 7,54 €.
    func testUncheckingCardLowersSelectedCountAndSum() {
        let app = openedReviewSheet()

        let header = element(app, "receiptReview.sectionHeader")
        XCTAssertTrue(header.waitForExistence(timeout: 5), "Kopfzeile über den Positionen fehlt.")

        let checkbox = element(app, "receiptReview.line.\(Seed.aiLine).checkbox")
        XCTAssertTrue(checkbox.exists, "Häkchen der KI-Zeile fehlt.")
        checkbox.tap()

        let expected = "4 positionen · 3 ausgewählt · 7,54 €"
        expectation(for: NSPredicate(format: "label CONTAINS[c] %@", "3 ausgewählt"), evaluatedWith: header)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(normalized(header.label).lowercased(), expected,
                       "Kopfzeile nach dem Abwählen falsch — erwartet: \(expected)")
    }

    // MARK: - AC12: Speichern unverändert

    /// AC12 — Speichern schreibt den erkannten Preis weiterhin an den zugeordneten Artikel.
    ///
    /// Regressionsschutz für den unveränderten `save()`-Pfad: Die Zeile „MILCH" ist dem Artikel
    /// „Milch" zugeordnet und kostet 0,99 €; nach dem Speichern muss dieser Betrag in der
    /// Lidl-Liste am Artikel stehen. Vor dem Speichern hat der gesäte Artikel keinen Preis.
    func testSavingStillWritesLearnedPriceToMatchedItem() {
        let app = openedReviewSheet()

        let saveButton = app.buttons["receiptReview.saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Speichern-Knopf fehlt.")
        saveButton.tap()

        let lidlTile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Lidl,")).firstMatch
        XCTAssertTrue(lidlTile.waitForExistence(timeout: 10), "Nach dem Speichern ist der Home-Screen nicht sichtbar.")
        expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: lidlTile)
        waitForExpectations(timeout: 5)
        lidlTile.tap()

        XCTAssertTrue(app.staticTexts[Seed.matchedItemName].waitForExistence(timeout: 10),
                      "Artikel \(Seed.matchedItemName) nicht in der Lidl-Liste gefunden.")
        let priceText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "0,99")).firstMatch
        XCTAssertTrue(priceText.waitForExistence(timeout: 5),
                      "Der gespeicherte Preis \(Seed.matchedItemPriceText) steht nicht am Artikel — save() schreibt ihn nicht mehr.")
    }

    // MARK: - Dunkelmodus (der im Issue-Screenshot reproduzierte Fall)

    /// AC1 + AC3 im Dunkelmodus — der Screenshot zu #23 stammt genau daher.
    func testOriginalTextAndAiMarkAreReadableInDarkMode() {
        XCUIDevice.shared.appearance = .dark
        let app = openedReviewSheet()

        let longText = element(app, "receiptReview.line.1.originalName")
        XCTAssertTrue(longText.waitForExistence(timeout: 5), "Dunkelmodus: Bontext der langen Zeile fehlt.")
        XCTAssertEqual(longText.label, Seed.rawTexts[1],
                       "Dunkelmodus: Bontext der langen Zeile ist gekürzt oder verändert.")

        let mark = element(app, "receiptReview.line.\(Seed.aiLine).aiMark")
        XCTAssertTrue(mark.exists, "Dunkelmodus: KI-Marke fehlt.")
        XCTAssertLessThan(mark.frame.height, 26,
                          "Dunkelmodus: KI-Marke ist \(mark.frame.height) pt hoch — sie bricht um.")
    }

    /// AC9 im Dunkelmodus — Preis- und Mengenfeld müssen auch dort erscheinen und wirken.
    func testChangeEditorWorksInDarkMode() {
        XCUIDevice.shared.appearance = .dark
        let app = openedReviewSheet()
        let line = Seed.suggestionLine

        let changeButton = element(app, "receiptReview.line.\(line).changeButton")
        XCTAssertTrue(changeButton.waitForExistence(timeout: 5), "Dunkelmodus: Knopf zum Ändern fehlt.")
        changeButton.tap()

        let priceField = app.textFields["receiptReview.line.\(line).priceField"]
        XCTAssertTrue(priceField.waitForExistence(timeout: 5), "Dunkelmodus: Preisfeld erscheint nicht.")
        XCTAssertTrue(app.textFields["receiptReview.line.\(line).quantityField"].exists,
                      "Dunkelmodus: Mengenfeld erscheint nicht.")

        replaceText(priceField, with: "3,50")
        let summary = element(app, "receiptReview.line.\(line).price")
        XCTAssertTrue(normalized(summary.label).contains("3,50 €"),
                      "Dunkelmodus: Preiszeile zeigt den neuen Preis nicht: \(summary.label)")
    }
}
