import XCTest

/// TDD RED (Issue #57, `docs/specs/services/assignment-service-quantity-suggestion.md`) — deckt
/// AC-13 (Bypass bei Nutzereingabe), AC-14, AC-15 und AC-16 ab. Eigene Klasse statt
/// `ReceiptReviewUITests.swift`, weil "Artikel hinzufügen" thematisch nicht zu den Bon-Scan-Tests
/// dort passt.
///
/// `ItemRow`/`AddItemView`/`EditItemView` setzen KEINE eigenen `accessibilityIdentifier`s (anders
/// als `ReceiptReviewCard`) — alle Lookups hier gehen deshalb über lokalisierte Anzeigetexte
/// (Deutsch, siehe `Restock.xcscheme` `<TestAction language="de" region="DE">`) oder über
/// SF-Symbol-`identifier`s wie `"plus"`/`"plus.circle.fill"`.
///
/// AC-14 (Farbe `Color.amber` statt `.secondary`) wird hier NUR über den textlichen "ca. "-Präfix
/// geprüft, nicht über Pixelfarbe — ein XCUITest kann Farbe nicht direkt lesen, ohne eigene
/// Accessibility-Infrastruktur an `ItemRow` zu bauen (Produktcode-Änderung, außerhalb des Scopes
/// dieser TDD-RED-Phase). Der Kontrastwert selbst ist über den Unit-Test `testAmberDarkModeContrastMeetsWCAGAA`
/// in `AssignmentServiceQuantitySuggestionTests.swift` rechnerisch abgedeckt (AC-18).
///
/// **TDD-RED-Hinweis für `/50-implement`:** `SmartCartApp.seedQuantitySuggestionForUITestsIfNeeded`/
/// `clearQuantitySuggestionSeedForUITestsIfNeeded` existieren noch NICHT — das Gate für Phase 5
/// (TDD RED) erlaubt keine Edits an `SmartCart/SmartCartApp.swift` (Produktcode-Freeze bis Phase 6).
/// Diese vier Tests sind bereits durch den Compile-Fehler in `AssignmentServiceQuantitySuggestionTests.swift`
/// (fehlendes `suggestQuantity`) RED; zusätzlich fehlt bis Phase 6 die Seed-Fixture, ohne die sie
/// zur Laufzeit ohnehin nicht liefen. Muster zum Übernehmen: `seedReceiptReviewForUITestsIfNeeded`/
/// `clearReceiptReviewSeedForUITestsIfNeeded` in `SmartCartApp.swift` — Store "Quittenhof" anlegen,
/// einen Artikel "Bio Käse" mit `quantitySource: "history"`, `quantityAmount: 400`, `unit: "g"`
/// (AC-14/16), einen zweiten Artikel z. B. "Parmesan" mit `quantitySource: "none"` UND vorher
/// gesetztem `store.learnedPrices["parmesan"] = 0.0125` + `store.learnedPriceUnits["parmesan"] =
/// "g"` (AC-15 — der Konstruktor setzt `item.unit` dann selbst auf "g", siehe #10-Spec Abschnitt 3).
final class AddItemQuantitySuggestionUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Der App-Group-Container überlebt den einzelnen Testlauf (siehe CLAUDE.md) — ohne dieses
    /// Aufräumen bliebe der geseedete Store "Quittenhof" für spätere Testklassen im selben
    /// gemeinsamen Lauf stehen und würde z. B. `RestockUITests.testAppLaunchesToHomeScreen`s
    /// Annahme über den leeren Home-State verfälschen.
    override func tearDown() {
        super.tearDown()
        let cleaner = XCUIApplication()
        cleaner.launchArguments = ["-hasCompletedOnboarding", "YES", "-clearQuantitySuggestionSeedForUITests"]
        cleaner.launch()
        cleaner.terminate()
    }

    /// Seedet frisch bei jedem Aufruf (die Seed-Funktion löscht zuerst alle Stores/Items, siehe
    /// `SmartCartApp.seedQuantitySuggestionForUITestsIfNeeded`) — jeder Test bekommt so denselben,
    /// deterministischen Ausgangszustand unabhängig von der Reihenfolge.
    private func launchedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-seedQuantitySuggestionForUITests"]
        app.launch()
        return app
    }

    private func openQuittenhofStoreDetail(_ app: XCUIApplication) {
        let tile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Quittenhof,")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 15), "Quittenhof-Kachel nicht auf dem Home-Screen gefunden")
        let ready = tile.waitUntilHittable()
        XCTAssertTrue(ready.matched, "Quittenhof-Kachel nicht antippbar — zuletzt: \(ready.last)")
        tile.tap()
    }

    /// Apple setzt vor "€" je nach Locale/Formatierer U+00A0/U+202F/U+2009 statt eines normalen
    /// Leerzeichens — dasselbe Problem, das `ReceiptReviewUITests.normalized(_:)` schon löst.
    private func normalized(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{2009}", with: " ")
    }

    // MARK: - AC-14

    /// GIVEN ein Artikel wird mit quantitySource == "history" angelegt (hier: geseedet, da
    /// AddItemView diesen Pfad vor der Implementierung von #57 noch nicht erreicht) WHEN die Liste
    /// geöffnet wird THEN zeigt die Mengenzeile "ca. <Menge> <Einheit>" statt der reinen Menge.
    func testAssumedQuantityIsMarkedAsAssumptionInList() throws {
        let app = launchedApp()
        openQuittenhofStoreDetail(app)

        XCTAssertTrue(
            app.staticTexts["ca. 400 g"].waitForExistence(timeout: 10),
            "Eine angenommene Menge (quantitySource == \"history\") muss mit dem 'ca. '-Präfix markiert sein (AC-14)"
        )
    }

    // MARK: - AC-15

    /// GIVEN ein Artikel ohne belegte Menge und mit gelernter Gramm-Rate wird angelegt
    /// (quantitySource == "none") WHEN die Liste geöffnet wird THEN zeigt die Preiszelle die Rate
    /// "<Betrag> €/100 g" statt eines Gesamtpreises oder gar nichts.
    func testItemWithoutEvidenceShowsRateInsteadOfTotal() throws {
        let app = launchedApp()
        openQuittenhofStoreDetail(app)

        let rateText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "/100 g")).firstMatch
        XCTAssertTrue(
            rateText.waitForExistence(timeout: 10),
            "Ohne belegte Menge (quantitySource == \"none\") muss die Preiszelle die Rate '.../100 g' statt eines Gesamtpreises oder gar nichts zeigen (AC-15)"
        )
        XCTAssertTrue(
            normalized(rateText.label).contains("1,25"),
            "Rate muss estimatedPrice × 100 = 1,25 zeigen (estimatedPrice 0,0125 €/g aus dem Seed), tatsächlich: \(rateText.label)"
        )
    }

    // MARK: - AC-16

    /// GIVEN ein Artikel mit angenommener Menge ist in der Liste WHEN der Nutzer die Menge in
    /// EditItemView manuell korrigiert (Mengen-Stepper "+") und speichert THEN verschwindet die
    /// "ca."-Markierung und die Preiszelle zeigt wieder einen Gesamtpreis.
    func testCorrectingQuantityRemovesAssumptionMarkAndRestoresTotal() throws {
        let app = launchedApp()
        openQuittenhofStoreDetail(app)

        XCTAssertTrue(
            app.staticTexts["ca. 400 g"].waitForExistence(timeout: 10),
            "Vorbedingung: die Menge muss zunächst als Annahme markiert sein"
        )

        app.staticTexts["Bio Käse"].firstMatch.tap()

        let incrementButton = app.buttons["plus.circle.fill"].firstMatch
        XCTAssertTrue(incrementButton.waitForExistence(timeout: 5), "Mengen-Stepper '+' in EditItemView nicht gefunden")
        incrementButton.tap() // 400 g + Schrittweite 50 g (siehe QuantityStepperField) = 450 g

        let saveButton = app.buttons["Speichern"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "'Speichern'-Button in EditItemView nicht gefunden")
        saveButton.tap()

        // Kurze Pause: das Sheet muss erst schließen und die Liste neu zeichnen, bevor die
        // Abwesenheits-Prüfung unten aussagekräftig ist.
        sleep(1)

        XCTAssertFalse(app.staticTexts["ca. 400 g"].exists, "'ca. '-Markierung muss nach der manuellen Korrektur verschwinden")
        XCTAssertFalse(app.staticTexts["ca. 450 g"].exists, "Auch die korrigierte Menge darf keine 'ca. '-Markierung tragen")
        XCTAssertTrue(app.staticTexts["450 g"].waitForExistence(timeout: 5), "Korrigierte Menge muss ohne 'ca. '-Präfix erscheinen")

        let totalText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "€")).firstMatch
        XCTAssertTrue(totalText.waitForExistence(timeout: 5), "Preiszelle muss nach der Korrektur wieder einen Gesamtpreis zeigen, nicht nur eine Rate")
    }

    // MARK: - AC-13 (Bypass-Teil: Nutzereingabe wird nie als Annahme markiert)

    /// GIVEN der Nutzer tippt beim Anlegen selbst eine Menge ein (quantity nicht leer) WHEN der
    /// Artikel gespeichert und die Liste geöffnet wird THEN zeigt die Mengenzeile die Menge OHNE
    /// "ca."-Präfix — der Guard `quantity.isEmpty` in `AddItemView` (unverändert aus dem Bestand)
    /// überspringt `suggestQuantity` komplett, `quantitySource` bleibt beim Default "user".
    func testUserTypedQuantityIsNeverMarkedAsAssumption() throws {
        let app = launchedApp()
        openQuittenhofStoreDetail(app)

        let addButton = app.buttons.matching(NSPredicate(format: "identifier == 'plus'")).firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "'+'-Button in StoreDetailView nicht gefunden")
        addButton.tap()

        let nameField = app.textFields["Artikelname"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Artikelname-Feld in AddItemView nicht gefunden")
        nameField.tap()
        nameField.typeText("Kaffeebohnen")

        let quantityField = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", "1")).firstMatch
        XCTAssertTrue(quantityField.waitForExistence(timeout: 5), "Mengen-Textfeld in AddItemView nicht gefunden")
        quantityField.tap()
        expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: quantityField)
        waitForExpectations(timeout: 10)
        quantityField.typeText("3")

        let addConfirmButton = app.navigationBars["Artikel hinzufügen"].buttons["Hinzufügen"]
        XCTAssertTrue(addConfirmButton.waitForExistence(timeout: 5), "'Hinzufügen'-Button in AddItemView nicht gefunden")
        addConfirmButton.tap()

        XCTAssertTrue(app.staticTexts["Kaffeebohnen"].waitForExistence(timeout: 10), "Neu angelegter Artikel erscheint nicht in der Liste")
        XCTAssertTrue(app.staticTexts["3"].waitForExistence(timeout: 5), "Selbst eingetippte Menge muss unverändert angezeigt werden")
        XCTAssertFalse(app.staticTexts["ca. 3"].exists, "Eine selbst eingetippte Menge darf NIE als Annahme ('ca. ') markiert werden (AC-13)")
    }

    // MARK: - Regressionen F001/F002 (Adversary-Befunde zu #57)

    /// Öffnet `AddItemView` über den "+"-Button der Quittenhof-Liste (presetStore gesetzt).
    private func openAddItemFromQuittenhof(_ app: XCUIApplication) {
        openQuittenhofStoreDetail(app)
        let addButton = app.buttons.matching(NSPredicate(format: "identifier == 'plus'")).firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: UITestWait.defaultTimeout), "'+'-Button in StoreDetailView nicht gefunden")
        addButton.tap()
    }

    /// F001: GIVEN ein Kauf "Milch" (2 l) im Quittenhof (Seed) WHEN der Nutzer "Milch" tippt
    /// (Vorbelegung greift, Einheit "l") und dann zu "Milchreis" weitertippt (kein Kauf) THEN darf
    /// die Vorbelegung aus dem Zwischenstand nicht hängen bleiben — kein "ca. 2 l" in der Liste.
    func testStaleSuggestionIsDroppedWhenNameIsTypedFurther() throws {
        let app = launchedApp()
        openAddItemFromQuittenhof(app)

        let nameField = app.textFields["Artikelname"]
        XCTAssertTrue(nameField.waitForExistence(timeout: UITestWait.defaultTimeout), "Artikelname-Feld in AddItemView nicht gefunden")
        nameField.tap()
        nameField.typeText("Milch")

        let unitField = app.textFields["Einheit"]
        XCTAssertTrue(unitField.waitForExistence(timeout: UITestWait.defaultTimeout), "Einheiten-Feld in AddItemView nicht gefunden")
        expectation(for: NSPredicate(format: "value == %@", "l"), evaluatedWith: unitField)
        waitForExpectations(timeout: UITestWait.defaultTimeout)

        nameField.typeText("reis")

        let addConfirmButton = app.navigationBars["Artikel hinzufügen"].buttons["Hinzufügen"]
        XCTAssertTrue(addConfirmButton.waitForExistence(timeout: UITestWait.defaultTimeout), "'Hinzufügen'-Button in AddItemView nicht gefunden")
        addConfirmButton.tap()

        XCTAssertTrue(app.staticTexts["Milchreis"].waitForExistence(timeout: UITestWait.defaultTimeout), "Neu angelegter Artikel 'Milchreis' erscheint nicht in der Liste")
        let staleSuggestion = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "ca. 2 l")).firstMatch
        XCTAssertFalse(staleSuggestion.exists, "Die Vorbelegung aus dem Zwischenstand 'Milch' darf bei 'Milchreis' nicht übernommen werden (F001)")
        XCTAssertFalse(app.staticTexts["2 l"].exists, "Auch ohne 'ca.' darf die überholte Menge 2 l nicht bei 'Milchreis' landen (F001)")
    }

    /// F002: GIVEN der Nutzer tippt zuerst die Einheit "kg" WHEN er danach den Namen "Kaffeebohnen"
    /// tippt (kein Kauf, keine Packungsgröße → Stufe "none") THEN bleibt die Einheit "kg" stehen und
    /// die Liste zeigt "1 kg" ohne "ca."-Präfix.
    func testUserTypedUnitIsNeverOverwrittenBySuggestion() throws {
        let app = launchedApp()
        openAddItemFromQuittenhof(app)

        let unitField = app.textFields["Einheit"]
        XCTAssertTrue(unitField.waitForExistence(timeout: 5), "Einheiten-Feld in AddItemView nicht gefunden")
        unitField.tap()
        expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: unitField)
        waitForExpectations(timeout: 10)
        unitField.typeText("kg")

        let nameField = app.textFields["Artikelname"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Artikelname-Feld in AddItemView nicht gefunden")
        nameField.tap()
        expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: nameField)
        waitForExpectations(timeout: 10)
        nameField.typeText("Kaffeebohnen")

        XCTAssertEqual(unitField.value as? String, "kg", "Die selbst getippte Einheit darf durch die Namenseingabe nicht überschrieben werden (F002)")

        let addConfirmButton = app.navigationBars["Artikel hinzufügen"].buttons["Hinzufügen"]
        XCTAssertTrue(addConfirmButton.waitForExistence(timeout: 5), "'Hinzufügen'-Button in AddItemView nicht gefunden")
        addConfirmButton.tap()

        XCTAssertTrue(app.staticTexts["Kaffeebohnen"].waitForExistence(timeout: 10), "Neu angelegter Artikel erscheint nicht in der Liste")
        XCTAssertTrue(app.staticTexts["1 kg"].waitForExistence(timeout: 5), "Die selbst gesetzte Einheit muss als '1 kg' in der Liste erscheinen (F002)")
        XCTAssertFalse(app.staticTexts["ca. 1 kg"].exists, "Eine selbst gesetzte Einheit darf nie als Annahme ('ca. ') markiert werden (F002)")
    }
}
