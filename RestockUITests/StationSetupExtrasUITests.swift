import XCTest

/// Issue #234, Durchgang 2b-1 (`docs/specs/views/station-templates-keywords.md`): Vorlagen-Blatt mit
/// fünf Vorlagen und Stichwörter je Gang in „Kategorien einrichten“.
///
/// Seed (`-seedStationStoreForUITests`, Aufräumer `-clearStationStoreForUITests`): Laden
/// „Stationsladen“ mit Lidl-Vorlage, offene Artikel Batterien (Sonstiges), Milch, Gouda (Käse, über das
/// Stichwort „gouda“), Salami (Kühltheke Fertiges), Apfel, Brot (dringend). Geprüft wird die Wirkung in
/// der Ladenliste (Modus „Kategorie“), nicht nur das Vorhandensein der Bedienelemente.
///
/// Eigene Klasse in CI-Teil D (`EXTRA_CLASSES`), damit Teil C (`StoreStationsUITests`) nicht über
/// 60 min wächst.
final class StationSetupExtrasUITests: XCTestCase {

    private let storeName = "Stationsladen"
    private let patternTemplates = ["Discounter", "FullRange", "Drugstore", "Hardware"]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Der App-Group-Container überlebt den einzelnen Test (siehe CLAUDE.md).
    override func tearDown() {
        super.tearDown()
        let cleaner = XCUIApplication()
        cleaner.launchArguments = ["-hasCompletedOnboarding", "YES", "-clearStationStoreForUITests"]
        cleaner.launch()
        cleaner.terminate()
    }

    // MARK: - Start, Menü, Einrichtung

    private func openedStore() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-seedStationStoreForUITests"]
        let tile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(storeName),")).firstMatch
        UITestLaunch.start(app, expecting: tile, description: "Kachel „\(storeName)“")
        tile.tap()
        XCTAssertTrue(app.staticTexts["Salami"].waitForExistence(timeout: UITestWait.defaultTimeout), "Ladenliste nicht geöffnet")
        return app
    }

    private func element(_ identifier: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func openMenu(_ app: XCUIApplication) {
        let more = element("storeDetail.moreMenu", app)
        let ready = more.waitUntilHittable()
        XCTAssertTrue(ready.matched, "···-Menü nicht antippbar — zuletzt: \(ready.last)")
        more.tap()
    }

    /// ··· → „Sortieren“ → „Kategorie“.
    private func chooseCategoryMode(_ app: XCUIApplication) {
        openMenu(app)
        let sortMenu = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Sortieren")).firstMatch
        XCTAssertTrue(sortMenu.waitForExistence(timeout: UITestWait.defaultTimeout), "Menüpunkt „Sortieren“ fehlt")
        sortMenu.tap()
        let button = app.buttons["Kategorie"].firstMatch
        let option = button.waitForExistence(timeout: 5)
            ? button
            : app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Kategorie")).firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: UITestWait.defaultTimeout), "Sortieroption „Kategorie“ fehlt")
        option.tap()
        scrollToTop(app)
    }

    private func openSetup(_ app: XCUIApplication) {
        openMenu(app)
        let entry = app.buttons.matching(identifier: "store.menu.setupStations").firstMatch
        let ready = entry.waitUntilHittable()
        XCTAssertTrue(ready.matched, "„Kategorien einrichten“ fehlt im Menü — zuletzt: \(ready.last)")
        entry.tap()
        XCTAssertTrue(element("stationSetup.addStation", app).waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Übersicht „Kategorien einrichten“ nicht geöffnet")
    }

    private func closeSetup(_ app: XCUIApplication) {
        let done = element("stationSetup.done", app)
        let ready = done.waitUntilHittable()
        XCTAssertTrue(ready.matched, "„Fertig“ fehlt — zuletzt: \(ready.last)")
        done.tap()
        waitForGone(element("stationSetup.addStation", app), "Übersicht bleibt nach „Fertig“ offen")
        scrollToTop(app)
    }

    private func openStation(_ name: String, in app: XCUIApplication) {
        tapRevealed("stationSetup.row.\(name)", "Gang-Zeile \(name)", in: app)
        XCTAssertTrue(app.textFields["stationSetup.detail.name"].firstMatch.waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Gang-Detail „\(name)“ nicht geöffnet")
    }

    private func backToOverview(_ app: XCUIApplication) {
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(element("stationSetup.addStation", app).waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Zurück in die Übersicht fehlgeschlagen")
    }

    // MARK: - Vorlagen-Blatt

    /// „Vorlage wählen …“ in der Übersicht antippen; wartet auf die Lidl-Zeile des Blatts.
    private func openTemplateSheet(_ app: XCUIApplication) {
        tapRevealed("stationSetup.template", "Vorlage wählen …", in: app)
        XCTAssertTrue(element("stationSetup.templateLidl", app).waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Vorlagen-Blatt nicht geöffnet")
    }

    private func templateRow(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(identifier: "stationSetup.template\(id)").firstMatch
    }

    /// Rückfrage „Vorhandene Gänge ersetzen?“ abbrechen: Knopf „Abbrechen“, wenn das System ihn zeigt,
    /// sonst außerhalb des Einblendmenüs tippen (iPhone, gemessen in `StoreSetupUITests` S3).
    private func cancelReplaceDialog(_ app: XCUIApplication) {
        let cancel = app.sheets.buttons["Abbrechen"].firstMatch
        if cancel.waitForExistence(timeout: 2) {
            cancel.tap()
        } else {
            app.otherElements["PopoverDismissRegion"].coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5)).tap()
        }
        waitForGone(app.buttons.matching(identifier: "stationSetup.templateReplace").firstMatch,
                    "Rückfrage bleibt nach „Abbrechen“")
    }

    // MARK: - Stichwörter

    private func keywordField(_ app: XCUIApplication) -> XCUIElement {
        app.textFields["stationSetup.keyword.field"].firstMatch
    }

    /// Tippt `text` ins Stichwort-Feld und drückt „Hinzufügen“.
    private func addKeyword(_ text: String, in app: XCUIApplication) {
        let field = keywordField(app)
        revealHittable(field, "Feld „Stichwort hinzufügen“", in: app)
        field.tap()
        field.typeText(text)
        let add = element("stationSetup.keyword.add", app)
        let ready = add.waitUntilHittable()
        XCTAssertTrue(ready.matched, "Knopf „Hinzufügen“ fehlt — zuletzt: \(ready.last)")
        add.tap()
    }

    /// Leert das Stichwort-Feld (nach einer Ablehnung bleibt der Text stehen).
    private func clearKeywordField(_ app: XCUIApplication) {
        let field = keywordField(app)
        field.tap()
        let current = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 2))
    }

    private func keywordRow(_ word: String, _ app: XCUIApplication) -> XCUIElement {
        element("stationSetup.keyword.row.\(word)", app)
    }

    /// Wischt die Stichwort-Zeile nach links und tippt „Löschen“.
    private func swipeDeleteKeyword(_ word: String, in app: XCUIApplication) {
        let row = keywordRow(word, app)
        revealHittable(row, "Stichwort-Zeile \(word)", in: app)
        row.swipeLeft()
        let delete = element("stationSetup.keyword.delete.\(word)", app)
        let ready = delete.waitUntilHittable()
        XCTAssertTrue(ready.matched, "„Löschen“ nach dem Wischen fehlt — zuletzt: \(ready.last)")
        delete.tap()
    }

    // MARK: - Liste, Rollen, Warten

    private func text(_ label: String, _ app: XCUIApplication) -> XCUIElement {
        app.staticTexts[label].firstMatch
    }

    /// Abschnittsüberschrift „<Emoji> <Name>“ mit genau diesem Namen (schließt Untertitel und
    /// längere Gang-Namen aus).
    private func header(_ name: String, emoji: String, _ app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@ AND label ENDSWITH[c] %@", emoji, " \(name)")).firstMatch
    }

    private func label(_ text: String, _ app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", text)).firstMatch
    }

    private func dragUp(_ app: XCUIApplication) {
        let window = app.windows.firstMatch
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            .press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)))
    }

    private func scrollToTop(_ app: XCUIApplication) {
        let window = app.windows.firstMatch
        for _ in 0..<3 {
            window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
                .press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)))
        }
    }

    private func scrollToBottom(_ app: XCUIApplication) {
        for _ in 0..<4 { dragUp(app) }
    }

    /// Rollt, bis `element` im Baum ist (höchstens acht Schritte; das Gang-Detail listet alle 35 Kategorien).
    @discardableResult
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        for _ in 0..<8 {
            if element.waitForExistence(timeout: 2) { return true }
            dragUp(app)
        }
        return element.exists
    }

    private func revealHittable(_ element: XCUIElement, _ what: String, in app: XCUIApplication,
                                file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<8 {
            if element.waitUntilHittable(timeout: 2).matched { return }
            dragUp(app)
        }
        let ready = element.waitUntilHittable(timeout: 2)
        XCTAssertTrue(ready.matched, "„\(what)“ nicht antippbar — zuletzt: \(ready.last)", file: file, line: line)
    }

    private func tapRevealed(_ identifier: String, _ what: String, in app: XCUIApplication,
                             file: StaticString = #filePath, line: UInt = #line) {
        let target = element(identifier, app)
        revealHittable(target, what, in: app, file: file, line: line)
        target.tap()
    }

    private func waitForGone(_ element: XCUIElement, _ message: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        let gone = UITestWait.poll(timeout: UITestWait.defaultTimeout, read: { element.exists }, done: { !$0 })
        XCTAssertTrue(gone.matched, message, file: file, line: line)
    }

    /// GIVEN zwei Elemente WHEN beide im Baum THEN `upper` steht oberhalb von `lower`.
    private func assertAbove(_ upper: XCUIElement, _ upperName: String, _ lower: XCUIElement, _ lowerName: String,
                             in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(reveal(upper, in: app), "„\(upperName)“ nicht gefunden", file: file, line: line)
        XCTAssertTrue(reveal(lower, in: app), "„\(lowerName)“ nicht gefunden", file: file, line: line)
        let result = UITestWait.poll(timeout: UITestWait.defaultTimeout,
                                     read: { (upper.frame.minY, lower.frame.minY) },
                                     done: { $0.0 < $0.1 })
        XCTAssertTrue(result.matched, "„\(upperName)“ (y=\(result.last.0)) muss über „\(lowerName)“ (y=\(result.last.1)) stehen",
                      file: file, line: line)
    }

    /// Unmittelbar über `item` steht genau diese Überschrift: keine andere Überschrift mit Emoji und
    /// kein „Sonstiges“ zwischen beiden.
    private func assertDirectlyUnder(_ item: String, header name: String, emoji: String, in app: XCUIApplication,
                                     file: StaticString = #filePath, line: UInt = #line) {
        let target = header(name, emoji: emoji, app)
        assertAbove(target, "Überschrift \(emoji) \(name)", text(item, app), item, in: app, file: file, line: line)
        let itemY = text(item, app).frame.minY
        let headerY = target.frame.minY
        let between = app.staticTexts.allElementsBoundByIndex.filter {
            $0.exists && $0.frame.minY > headerY + 1 && $0.frame.minY < itemY - 1
                && ($0.label == "Sonstiges" || $0.label.unicodeScalars.first?.properties.isEmojiPresentation == true)
        }
        XCTAssertTrue(between.isEmpty, "Zwischen „\(name)“ und „\(item)“ steht eine andere Überschrift: \(between.map(\.label))",
                      file: file, line: line)
    }

    private func assertNoOther(_ app: XCUIApplication, _ reason: String,
                               file: StaticString = #filePath, line: UInt = #line) {
        for position in ["unten", "oben"] {
            if position == "oben" { scrollToTop(app) } else { scrollToBottom(app) }
            XCTAssertFalse(label("Sonstiges", app).exists, "\(reason) (\(position))", file: file, line: line)
        }
        scrollToTop(app)
    }

    // MARK: - X1: Vorlage Discounter ersetzt die Gänge (AC-1, AC-2, AC-5)

    /// X1 / AC-1, AC-2, AC-5: GIVEN Seed (Lidl-Gänge, Salami unter „Kühltheke Fertiges“) WHEN „Vorlage
    /// wählen …“ THEN fünf Zeilen, die vier Muster mit „Vorschlag, bitte prüfen“, Lidl ohne; WHEN
    /// „Discounter“ THEN Rückfrage, Abbrechen ändert nichts; WHEN „Discounter“ + „Ersetzen“ THEN
    /// „Gänge · 10“ mit „Backstation“, in der Liste steht Salami unter „Wurst, Käse & Molkerei“.
    func testChooseDiscounterTemplateReplacesStations() {
        let app = openedStore()
        chooseCategoryMode(app)
        assertDirectlyUnder("Salami", header: "Kühltheke Fertiges", emoji: "🧊", in: app)
        scrollToTop(app)

        openSetup(app)
        openTemplateSheet(app)
        let lidl = templateRow("Lidl", app)
        XCTAssertFalse(lidl.label.contains("Vorschlag"), "Lidl trägt kein Kennzeichen — Label: \(lidl.label)")
        for id in patternTemplates {
            let row = templateRow(id, app)
            XCTAssertTrue(row.waitForExistence(timeout: UITestWait.defaultTimeout), "Vorlage \(id) fehlt im Blatt")
            XCTAssertTrue(row.label.contains("Vorschlag, bitte prüfen"), "Vorlage \(id) ohne Kennzeichen — Label: \(row.label)")
            XCTAssertTrue(row.label.contains("Gänge"), "Vorlage \(id) ohne „N Gänge“ — Label: \(row.label)")
        }
        XCTAssertTrue(templateRow("Discounter", app).label.contains("10 Gänge"), "Discounter: „10 Gänge“")
        XCTAssertTrue(templateRow("Hardware", app).label.contains("8 Gänge"), "Baumarkt: „8 Gänge“")

        // Rückfrage, weil der Laden Gänge hat; Abbrechen lässt alles unverändert.
        templateRow("Discounter", app).tap()
        let replace = app.buttons.matching(identifier: "stationSetup.templateReplace").firstMatch
        XCTAssertTrue(replace.waitForExistence(timeout: UITestWait.defaultTimeout), "Rückfrage „Vorhandene Gänge ersetzen?“ fehlt")
        XCTAssertTrue(label("Vorhandene Gänge ersetzen?", app).exists, "Titel der Rückfrage fehlt")
        cancelReplaceDialog(app)
        if templateRow("Lidl", app).exists {
            // Das Blatt bleibt nach dem Abbrechen offen; schließen über „Abbrechen“ oben links.
            let cancel = element("stationSetup.template.cancel", app)
            XCTAssertTrue(cancel.waitUntilHittable().matched, "„Abbrechen“ im Vorlagen-Blatt fehlt")
            cancel.tap()
            waitForGone(templateRow("Lidl", app), "Vorlagen-Blatt bleibt nach „Abbrechen“ offen")
        }
        XCTAssertTrue(label("Gänge · 12", app).waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Nach Abbrechen bleiben die 12 Lidl-Gänge")
        XCTAssertFalse(element("stationSetup.row.Backstation", app).exists, "Kein Discounter-Gang nach Abbrechen")

        // Ersetzen.
        openTemplateSheet(app)
        templateRow("Discounter", app).tap()
        XCTAssertTrue(replace.waitUntilHittable().matched, "„Ersetzen“ fehlt")
        replace.tap()
        waitForGone(templateRow("Lidl", app), "Vorlagen-Blatt bleibt nach „Ersetzen“ offen")
        XCTAssertTrue(label("Gänge · 10", app).waitForExistence(timeout: UITestWait.defaultTimeout), "Übersicht zeigt nicht „Gänge · 10“")
        XCTAssertTrue(reveal(element("stationSetup.row.Backstation", app), in: app), "Gang „Backstation“ fehlt")
        XCTAssertFalse(element("stationSetup.row.Kühltheke Fertiges", app).exists, "Lidl-Gang nach dem Ersetzen noch da")
        scrollToTop(app)
        closeSetup(app)

        assertDirectlyUnder("Salami", header: "Wurst, Käse & Molkerei", emoji: "🧀", in: app)
        scrollToTop(app)
        XCTAssertFalse(header("Kühltheke Fertiges", emoji: "🧊", app).exists, "Kein Lidl-Abschnitt mehr")
    }

    // MARK: - X2: Stichwort hinzufügen holt Artikel in den Gang (AC-6, AC-7, AC-8, AC-9, AC-11)

    /// X2: GIVEN Seed WHEN im Gang „Drogerie“ „ Batterien “ hinzugefügt THEN Zeile „batterien“, Feld leer;
    /// erneut → „steht hier schon“, keine zweite Zeile; „ab“ → Hinweis zum Mindestumfang; im Gang
    /// „Käse“ „wurst“ → Hinweis nennt „Kühltheke Fertiges“, gespeichert; in der Liste steht Batterien
    /// unter „Drogerie“, „Sonstiges“ ist weg.
    func testAddKeywordMovesItemIntoStation() {
        let app = openedStore()
        chooseCategoryMode(app)
        let batterien = text("Batterien", app)
        XCTAssertTrue(reveal(batterien, in: app), "Batterien fehlt")
        XCTAssertTrue(label("Sonstiges", app).exists, "Vorbedingung: Batterien steht unter „Sonstiges“")
        scrollToTop(app)

        openSetup(app)
        openStation("Drogerie", in: app)
        addKeyword(" Batterien ", in: app)
        XCTAssertTrue(reveal(keywordRow("batterien", app), in: app), "Stichwort-Zeile „batterien“ fehlt (getrimmt, klein)")
        let emptied = UITestWait.poll(timeout: UITestWait.defaultTimeout,
                                      read: { (self.keywordField(app).value as? String) ?? "" },
                                      done: { $0.isEmpty || $0 == "Stichwort hinzufügen" })
        XCTAssertTrue(emptied.matched, "Feld nach dem Speichern nicht leer — zuletzt: „\(emptied.last)“")

        addKeyword("batterien", in: app)
        let duplicate = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "steht hier schon")).firstMatch
        XCTAssertTrue(duplicate.waitForExistence(timeout: UITestWait.defaultTimeout), "Hinweis „steht hier schon“ fehlt")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "stationSetup.keyword.row.batterien").count, 1,
                       "Stichwort darf nicht doppelt stehen")
        clearKeywordField(app)

        addKeyword("ab", in: app)
        let invalid = element("stationSetup.keyword.invalid", app)
        XCTAssertTrue(invalid.waitForExistence(timeout: UITestWait.defaultTimeout), "Hinweis zum Mindestumfang fehlt")
        XCTAssertTrue(invalid.label.contains("mindestens 3 Buchstaben"), "Text des Hinweises — Label: \(invalid.label)")
        XCTAssertFalse(keywordRow("ab", app).exists, "„ab“ darf nicht gespeichert sein")
        clearKeywordField(app)

        backToOverview(app)
        scrollToTop(app)
        openStation("Käse", in: app)
        addKeyword("wurst", in: app)
        let notice = element("stationSetup.keyword.notice", app)
        XCTAssertTrue(notice.waitForExistence(timeout: UITestWait.defaultTimeout), "Hinweis auf den anderen Gang fehlt")
        XCTAssertTrue(notice.label.contains("Kühltheke Fertiges"), "Hinweis nennt den anderen Gang nicht — Label: \(notice.label)")
        XCTAssertTrue(notice.label.contains("weiter oben"), "Hinweis erklärt nicht, wer gewinnt — Label: \(notice.label)")
        XCTAssertTrue(reveal(keywordRow("wurst", app), in: app), "„wurst“ muss trotz anderem Gang gespeichert sein")
        backToOverview(app)
        scrollToTop(app)
        closeSetup(app)

        assertDirectlyUnder("Batterien", header: "Drogerie", emoji: "🧴", in: app)
        assertNoOther(app, "„Sonstiges“ darf ohne Artikel nicht erscheinen")
        assertDirectlyUnder("Salami", header: "Kühltheke Fertiges", emoji: "🧊", in: app)
    }

    // MARK: - X3: Stichwort löschen nimmt Artikel heraus (AC-10, AC-11)

    /// X3: GIVEN Seed, Gouda unter „Käse“ WHEN im Gang „Käse“ „gouda“ per Wischen gelöscht THEN Zeile
    /// weg; in der Liste kein Abschnitt „Käse“ mehr (Gouda war sein einziger Artikel), Gouda noch da;
    /// WHEN „gouda“ wieder hinzugefügt THEN Gouda wieder unter „Käse“.
    func testDeleteKeywordMovesItemOut() {
        let app = openedStore()
        chooseCategoryMode(app)
        assertDirectlyUnder("Gouda", header: "Käse", emoji: "🧀", in: app)
        scrollToTop(app)

        openSetup(app)
        openStation("Käse", in: app)
        XCTAssertTrue(reveal(keywordRow("käse", app), in: app), "Stichwort „käse“ fehlt")
        swipeDeleteKeyword("gouda", in: app)
        waitForGone(keywordRow("gouda", app), "Stichwort „gouda“ steht nach dem Löschen noch da")
        XCTAssertTrue(keywordRow("käse", app).exists, "Die übrigen Stichwörter bleiben")
        backToOverview(app)
        scrollToTop(app)
        closeSetup(app)

        let gouda = text("Gouda", app)
        XCTAssertTrue(reveal(gouda, in: app), "Gouda muss in der Liste bleiben")
        scrollToTop(app)
        for position in ["oben", "unten"] {
            if position == "unten" { scrollToBottom(app) }
            XCTAssertFalse(header("Käse", emoji: "🧀", app).exists, "Abschnitt „Käse“ ohne Artikel (\(position))")
        }
        scrollToTop(app)

        openSetup(app)
        openStation("Käse", in: app)
        addKeyword("gouda", in: app)
        XCTAssertTrue(reveal(keywordRow("gouda", app), in: app), "„gouda“ nach dem Wiedereinfügen fehlt")
        backToOverview(app)
        scrollToTop(app)
        closeSetup(app)
        assertDirectlyUnder("Gouda", header: "Käse", emoji: "🧀", in: app)
    }
}
