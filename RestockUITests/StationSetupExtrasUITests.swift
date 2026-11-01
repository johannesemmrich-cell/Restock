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

    // MARK: - Durchgang 2b-2 (`docs/specs/views/station-picker-adoption.md`)
    //
    // Weitere Seeds (Aufräumer ebenfalls `-clearStationStoreForUITests`): `-seedLegacyCustomCategoriesForUITests`
    // (Laden „Altladen“: Gänge Obst & Gemüse, Getränke; eigene Kategorien Asia-Regal mit Nudeln, Wein,
    // Backstation mit Baguette, Aktionsware; Apfel automatisch) und `-seedStationStoreSharedForUITests`
    // (wie der Stationsladen, mit `shareID`).

    /// Startet mit `seed` und öffnet die Liste des Ladens `name`; wartet auf `item`.
    private func openedStore(seed: String, name: String, item: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", seed]
        let tile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name),")).firstMatch
        UITestLaunch.start(app, expecting: tile, description: "Kachel „\(name)“")
        tile.tap()
        XCTAssertTrue(app.staticTexts[item].waitForExistence(timeout: UITestWait.defaultTimeout), "Ladenliste „\(name)“ nicht geöffnet")
        return app
    }

    private func legacyStore() -> XCUIApplication {
        openedStore(seed: "-seedLegacyCustomCategoriesForUITests", name: "Altladen", item: "Apfel")
    }

    /// Belegbild für den Durchlauf (Muster 2a), bleibt im xcresult.
    private func attach(_ name: String, _ app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func openPicker(for item: String, in app: XCUIApplication) {
        revealHittable(text(item, app), item, in: app)
        UITestItemEditor.open(item, in: app)
        reopenPicker(app)
    }

    /// Im offenen Artikel-Dialog die Zeile „Kategorie“ antippen.
    private func reopenPicker(_ app: XCUIApplication) {
        let row = element("item.categoryRow", app)
        let ready = row.waitUntilHittable()
        XCTAssertTrue(ready.matched, "Zeile „Kategorie“ im Dialog fehlt — zuletzt: \(ready.last)")
        row.tap()
        XCTAssertTrue(app.textFields["categoryPicker.search"].firstMatch.waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Kategorie-Auswahl nicht geöffnet")
    }

    private func pickerRow(_ name: String, _ app: XCUIApplication) -> XCUIElement {
        element("categoryPicker.row.\(name)", app)
    }

    /// Gang-Zeile der Auswahl nach links wischen und `action` („edit“/„delete“) antippen.
    private func swipeStation(_ name: String, _ action: String, in app: XCUIApplication,
                              file: StaticString = #filePath, line: UInt = #line) {
        let row = pickerRow(name, app)
        revealHittable(row, "Auswahl-Zeile \(name)", in: app, file: file, line: line)
        row.swipeLeft()
        let button = element("categoryPicker.station.\(action).\(name)", app)
        let ready = button.waitUntilHittable()
        XCTAssertTrue(ready.matched, "Wischaktion „\(action)“ auf „\(name)“ fehlt — zuletzt: \(ready.last)", file: file, line: line)
        button.tap()
    }

    /// Aus der Auswahl zurück in den Artikel-Dialog.
    private func pickerBack(_ app: XCUIApplication) {
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(element("item.categoryRow", app).waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Zurück in den Artikel-Dialog fehlgeschlagen")
    }

    private func categoryRowLabel(contains text: String, _ app: XCUIApplication) {
        let result = element("item.categoryRow", app).waitForLabel(contains: text)
        XCTAssertTrue(result.matched, "Kategorie im Dialog: „\(result.lastLabel)“, erwartet „\(text)“")
    }

    private func saveEditor(_ app: XCUIApplication) {
        let save = app.buttons["Speichern"].firstMatch
        let ready = save.waitUntilHittable()
        XCTAssertTrue(ready.matched, "„Speichern“ im Dialog fehlt — zuletzt: \(ready.last)")
        save.tap()
        waitForGone(save, "Artikel-Dialog bleibt nach „Speichern“ offen")
        scrollToTop(app)
    }

    private func replaceText(_ field: XCUIElement, with text: String) {
        XCTAssertTrue(field.waitUntilHittable().matched, "Textfeld nicht antippbar")
        field.tap()
        let current = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 2) + text)
    }

    /// Rückfrage abbrechen: außerhalb des Einblendmenüs tippen (iPhone), sonst „Abbrechen“.
    private func cancelConfirmation(_ app: XCUIApplication, _ button: XCUIElement) {
        let cancel = app.sheets.buttons["Abbrechen"].firstMatch
        if cancel.waitForExistence(timeout: 2) {
            cancel.tap()
        } else {
            app.otherElements["PopoverDismissRegion"].coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5)).tap()
        }
        waitForGone(button, "Rückfrage bleibt nach dem Abbrechen")
    }

    private func confirmButton(_ label: String, _ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func assertUnderOther(_ item: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        assertAbove(label("Sonstiges", app), "Überschrift Sonstiges", text(item, app), item, in: app, file: file, line: line)
        scrollToTop(app)
    }

    // MARK: - Y1: Gang in der Auswahl umbenennen (AC-1, AC-2, AC-3)

    /// Y1: GIVEN Dialog von Gouda, „Käse“ ausdrücklich gewählt WHEN auf „Käse“ wischen → „Bearbeiten“ THEN
    /// „Drogerie“ wird mit Meldung abgelehnt, nichts geändert; „Käse & Co“ wird gespeichert, die Auswahl
    /// zieht mit, und nach Sichern steht Gouda unter „Käse & Co“ (nicht unter „Sonstiges“); „Sonstiges“
    /// hat keine Wischaktionen.
    func testPickerRenameStationKeepsSelection() {
        let app = openedStore()
        chooseCategoryMode(app)
        openPicker(for: "Gouda", in: app)
        tapRevealed("categoryPicker.row.Käse", "Auswahl-Zeile Käse", in: app)
        categoryRowLabel(contains: "Käse", app)
        reopenPicker(app)

        swipeStation("Käse", "edit", in: app)
        XCTAssertTrue(app.navigationBars["Kategorie bearbeiten"].waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Editor „Kategorie bearbeiten“ nicht geöffnet")
        let field = app.textFields["categoryEditor.name"].firstMatch
        replaceText(field, with: "Drogerie")
        app.buttons["Speichern"].firstMatch.tap()
        XCTAssertTrue(label("Diesen Namen gibt es schon oder er ist nicht erlaubt.", app)
            .waitForExistence(timeout: UITestWait.defaultTimeout), "Meldung bei vergebenem Namen fehlt")
        XCTAssertTrue(field.exists, "Editor muss nach der Ablehnung offen bleiben")
        attach("Y1 Name abgelehnt", app)
        app.buttons["Abbrechen"].firstMatch.tap()
        waitForGone(field, "Editor bleibt nach „Abbrechen“ offen")
        XCTAssertTrue(pickerRow("Käse", app).exists, "„Käse“ nach der Ablehnung unverändert")

        swipeStation("Käse", "edit", in: app)
        replaceText(app.textFields["categoryEditor.name"].firstMatch, with: "Käse & Co")
        app.buttons["Speichern"].firstMatch.tap()
        XCTAssertTrue(pickerRow("Käse & Co", app).waitForExistence(timeout: UITestWait.defaultTimeout), "Zeile „Käse & Co“ fehlt")
        XCTAssertFalse(pickerRow("Käse", app).exists, "Alter Name noch in der Auswahl")
        attach("Y1 umbenannt", app)

        let other = element("categoryPicker.row.other", app)
        revealHittable(other, "Sonstiges in der Auswahl", in: app)
        other.swipeLeft()
        let otherActions = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "categoryPicker.station."))
        XCTAssertEqual(otherActions.count, 0, "„Sonstiges“ darf keine Wischaktionen haben")

        pickerBack(app)
        categoryRowLabel(contains: "Käse & Co", app)
        saveEditor(app)
        assertDirectlyUnder("Gouda", header: "Käse & Co", emoji: "🧀", in: app)
    }

    // MARK: - Y2: Gang in der Auswahl löschen (AC-1, AC-4)

    /// Y2: GIVEN Dialog von Gouda, Auswahl „Käse“ WHEN Wischen → „Löschen“ THEN Rückfrage „Gang „Käse“
    /// löschen?“, Abbrechen lässt den Gang; bestätigt THEN Zeile weg, Auswahl „Milchprodukte“ (der Gang, in
    /// den Gouda automatisch fällt); nach Sichern kein Abschnitt „Käse“ mehr, Gouda unter „Milchprodukte“.
    func testPickerDeleteStationAsksAndFallsBack() {
        let app = openedStore()
        chooseCategoryMode(app)
        openPicker(for: "Gouda", in: app)
        tapRevealed("categoryPicker.row.Käse", "Auswahl-Zeile Käse", in: app)
        reopenPicker(app)

        swipeStation("Käse", "delete", in: app)
        let confirm = confirmButton("Gang löschen", app)
        XCTAssertTrue(confirm.waitForExistence(timeout: UITestWait.defaultTimeout), "Rückfrage fehlt")
        XCTAssertTrue(label("Gang „Käse“ löschen?", app).exists, "Titel der Rückfrage fehlt")
        attach("Y2 Rückfrage", app)
        cancelConfirmation(app, confirm)
        XCTAssertTrue(pickerRow("Käse", app).waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Abbrechen muss den Gang stehen lassen")

        swipeStation("Käse", "delete", in: app)
        XCTAssertTrue(confirm.waitUntilHittable().matched, "„Gang löschen“ fehlt")
        confirm.tap()
        waitForGone(pickerRow("Käse", app), "Zeile „Käse“ nach dem Löschen noch da")
        pickerBack(app)
        categoryRowLabel(contains: "Milchprodukte", app)
        saveEditor(app)

        assertDirectlyUnder("Gouda", header: "Milchprodukte", emoji: "🥛", in: app)
        scrollToTop(app)
        XCTAssertFalse(header("Käse", emoji: "🧀", app).exists, "Abschnitt „Käse“ darf nicht mehr erscheinen")
    }

    // MARK: - Y3: Letzten Gang in der Auswahl löschen (AC-5)

    /// Y3: GIVEN Altladen (zwei Gänge), Dialog von Apfel WHEN „Getränke“ gelöscht THEN normale Rückfrage;
    /// WHEN der letzte Gang gelöscht THEN „Gänge entfernen?“, danach zeigt die Auswahl die Kategorien eines
    /// Ladens ohne Gänge (Asia-Regal, „Alle Kategorien“); die Liste hat kein „Sonstiges“ mehr und führt
    /// Nudeln unter der eigenen Kategorie „Asia-Regal“.
    func testPickerDeleteLastStationAsksRemoveStations() {
        let app = legacyStore()
        chooseCategoryMode(app)
        openPicker(for: "Apfel", in: app)

        swipeStation("Getränke", "delete", in: app)
        let confirm = confirmButton("Gang löschen", app)
        XCTAssertTrue(confirm.waitUntilHittable().matched, "Normale Rückfrage fehlt")
        confirm.tap()
        waitForGone(pickerRow("Getränke", app), "Zeile „Getränke“ nach dem Löschen noch da")

        swipeStation("Obst & Gemüse", "delete", in: app)
        let remove = confirmButton("Gänge entfernen", app)
        XCTAssertTrue(remove.waitUntilHittable().matched, "Knopf „Gänge entfernen“ fehlt")
        XCTAssertTrue(label("Gänge entfernen?", app).exists, "Titel „Gänge entfernen?“ fehlt")
        attach("Y3 letzter Gang", app)
        remove.tap()
        XCTAssertTrue(pickerRow("Asia-Regal", app).waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Auswahl zeigt die eigenen Kategorien nicht")
        XCTAssertTrue(label("Alle Kategorien", app).exists, "Abschnitt „Alle Kategorien“ fehlt")
        XCTAssertFalse(element("categoryPicker.row.other", app).exists, "„Sonstiges“ gibt es ohne Gänge nicht")
        pickerBack(app)
        categoryRowLabel(contains: "Obst & Gemüse", app)
        saveEditor(app)

        assertDirectlyUnder("Nudeln", header: "Asia-Regal", emoji: "🍜", in: app)
        assertNoOther(app, "Ohne Gänge gibt es keinen Abschnitt „Sonstiges“")
    }

    // MARK: - Y4: Gang in der Übersicht per Wischen löschen (AC-9, AC-12 Gegenprobe)

    /// Y4: GIVEN „Kategorien einrichten“ WHEN „Drogerie“ per Wischen gelöscht und bestätigt THEN „Gänge · 11“;
    /// Abbrechen bei „Käse“ lässt ihn stehen; ohne `shareID` und ohne frühere Kategorien fehlen Hinweis und
    /// Abschnitt „von früher“; in der Liste kein Abschnitt „Drogerie“, Gouda bleibt unter „Käse“.
    /// (Nachgeholt aus 2a, prüft Bestand.)
    func testSwipeDeleteStationInOverview() {
        let app = openedStore()
        chooseCategoryMode(app)
        openSetup(app)
        XCTAssertFalse(element("stationSetup.sharedHint", app).exists, "Hinweis darf im ungeteilten Laden fehlen")
        XCTAssertFalse(element("stationSetup.adopt.section", app).exists, "Kein Abschnitt „von früher“ ohne Altlast")

        for (name, confirmIt) in [("Käse", false), ("Drogerie", true)] {
            let row = element("stationSetup.row.\(name)", app)
            revealHittable(row, "Gang-Zeile \(name)", in: app)
            row.swipeLeft()
            tapRevealed("stationSetup.row.delete.\(name)", "Löschen auf \(name)", in: app)
            let confirm = element("stationSetup.confirmDelete", app)
            XCTAssertTrue(confirm.waitForExistence(timeout: UITestWait.defaultTimeout), "Rückfrage für \(name) fehlt")
            if confirmIt {
                confirm.tap()
                waitForGone(row, "Zeile „\(name)“ nach dem Löschen noch da")
            } else {
                cancelConfirmation(app, confirm)
                attach("Y4 nach Abbrechen", app)
                // Die Liste springt nach dem Abbrechen nach oben; Rollen direkt danach öffnete im RED-Lauf
                // einen Gang (Wisch als Tipp gewertet). Die Zählung im Kopf ist der robuste Beleg.
                XCTAssertTrue(label("Gänge · 12", app).waitForExistence(timeout: UITestWait.defaultTimeout),
                              "Abbrechen muss „\(name)“ stehen lassen")
            }
        }
        scrollToTop(app)
        XCTAssertTrue(label("Gänge · 11", app).waitForExistence(timeout: UITestWait.defaultTimeout), "Übersicht zeigt nicht „Gänge · 11“")
        closeSetup(app)

        assertDirectlyUnder("Gouda", header: "Käse", emoji: "🧀", in: app)
        for position in ["oben", "unten"] {
            if position == "unten" { scrollToBottom(app) }
            XCTAssertFalse(header("Drogerie", emoji: "🧴", app).exists, "Abschnitt „Drogerie“ nach dem Löschen (\(position))")
        }
        scrollToTop(app)
    }

    // MARK: - Y5: „gehört zu Gang …“ (AC-10)

    /// Y5: GIVEN Gang „Käse“ geöffnet THEN trägt die Kategorie „Getränke“ den Untertitel „gehört zu Gang
    /// Getränke“; „Konserven“ (kein gleichnamiger Gang) trägt ihn nicht. Abweichung von der Spec-Zeile:
    /// „Milchprodukte“ ist als Gegenprobe ungeeignet, weil die Lidl-Vorlage einen Gang „Milchprodukte“ hat.
    /// (Nachgeholt aus 2a, prüft Bestand.)
    func testBoundCategorySubtitleShowsOwningStation() {
        let app = openedStore()
        openSetup(app)
        openStation("Käse", in: app)
        let bound = element("stationSetup.detail.category.Getränke", app)
        XCTAssertTrue(reveal(bound, in: app), "Kategorie-Zeile „Getränke“ fehlt")
        let result = bound.waitForLabel(contains: "gehört zu Gang Getränke")
        XCTAssertTrue(result.matched, "Untertitel fehlt — Label: „\(result.lastLabel)“")
        let open = element("stationSetup.detail.category.Konserven", app)
        XCTAssertTrue(reveal(open, in: app), "Kategorie-Zeile „Konserven“ fehlt")
        XCTAssertFalse(open.label.contains("gehört zu Gang"), "„Konserven“ ist nicht gebunden — Label: \(open.label)")
    }

    // MARK: - Y6: Emoji aus dem Raster (AC-11)

    /// Y6: GIVEN Gang „Käse“ WHEN „Emoji“ aufgeklappt und 🥛 getippt THEN steht 🥛 neben „Emoji“, in der
    /// Liste trägt der Abschnitt „Käse“ 🥛 statt 🧀.
    func testPickGangEmojiFromGrid() {
        let app = openedStore()
        chooseCategoryMode(app)
        openSetup(app)
        openStation("Käse", in: app)
        let disclosure = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Emoji")).firstMatch
        XCTAssertTrue(disclosure.waitUntilHittable().matched, "Zeile „Emoji“ fehlt")
        disclosure.tap()
        tapRevealed("stationSetup.emoji.🥛", "Emoji 🥛 im Raster", in: app)
        let result = disclosure.waitForLabel(contains: "🥛")
        XCTAssertTrue(result.matched, "🥛 steht nicht neben „Emoji“ — Label: „\(result.lastLabel)“")
        backToOverview(app)
        scrollToTop(app)
        closeSetup(app)
        assertDirectlyUnder("Gouda", header: "Käse", emoji: "🥛", in: app)
        XCTAssertFalse(header("Käse", emoji: "🧀", app).exists, "Alte Überschrift 🧀 Käse noch da")
    }

    // MARK: - Y7: Hinweis im geteilten Laden (AC-12)

    /// Y7: GIVEN Laden mit `shareID` WHEN „Kategorien einrichten“ THEN steht der Hinweis da, die Gang-Zeilen
    /// lassen sich öffnen.
    func testSharedStoreShowsHint() {
        let app = openedStore(seed: "-seedStationStoreSharedForUITests", name: storeName, item: "Salami")
        openSetup(app)
        let hint = element("stationSetup.sharedHint", app)
        XCTAssertTrue(reveal(hint, in: app), "Hinweis für geteilte Läden fehlt")
        XCTAssertTrue(hint.label.contains("Gänge bleiben bis zum Abgleich auf diesem Gerät."), "Text — Label: \(hint.label)")
        attach("Y7 geteilter Laden", app)
        scrollToTop(app)
        openStation("Käse", in: app)
        backToOverview(app)
    }

    // MARK: - Y8: Eine frühere Kategorie übernehmen (AC-6, AC-7)

    /// Y8: GIVEN Altladen, Nudeln unter „Sonstiges“ WHEN „Kategorien einrichten“ THEN „Eigene Kategorien von
    /// früher · 3“ mit Asia-Regal, Backstation, Wein, ohne Aktionsware; WHEN „Übernehmen“ bei Asia-Regal THEN
    /// „· 2“, „Gänge · 3“ mit Asia-Regal 🍜 zuletzt; in der Liste steht Nudeln unter „Asia-Regal“.
    func testAdoptOneLegacyCategory() {
        let app = legacyStore()
        chooseCategoryMode(app)
        assertUnderOther("Nudeln", in: app)
        openSetup(app)

        let section = element("stationSetup.adopt.section", app)
        XCTAssertTrue(reveal(section, in: app), "Abschnitt „Eigene Kategorien von früher“ fehlt")
        XCTAssertTrue(section.label.contains("Eigene Kategorien von früher · 3"), "Kopf — Label: \(section.label)")
        for name in ["Asia-Regal", "Backstation", "Wein"] {
            XCTAssertTrue(reveal(element("stationSetup.adopt.row.\(name)", app), in: app), "Zeile „\(name)“ fehlt")
        }
        XCTAssertFalse(element("stationSetup.adopt.row.Aktionsware", app).exists, "Ungenutzter Vorlagenname darf fehlen")
        attach("Y8 von früher", app)

        tapRevealed("stationSetup.adopt.take.Asia-Regal", "Übernehmen bei Asia-Regal", in: app)
        waitForGone(element("stationSetup.adopt.row.Asia-Regal", app), "Asia-Regal bleibt im Abschnitt")
        XCTAssertTrue(section.waitForLabel(contains: "· 2").matched, "Kopf zählt nicht auf 2 herunter — Label: \(section.label)")
        scrollToTop(app)
        XCTAssertTrue(label("Gänge · 3", app).waitForExistence(timeout: UITestWait.defaultTimeout), "Übersicht zeigt nicht „Gänge · 3“")
        let adopted = element("stationSetup.row.Asia-Regal", app)
        assertAbove(element("stationSetup.row.Getränke", app), "Gang Getränke", adopted, "Gang Asia-Regal", in: app)
        XCTAssertTrue(adopted.label.contains("🍜"), "Eigenes Emoji fehlt — Label: \(adopted.label)")
        scrollToTop(app)
        closeSetup(app)

        assertDirectlyUnder("Nudeln", header: "Asia-Regal", emoji: "🍜", in: app)
    }

    // MARK: - Y9: Alle übernehmen (AC-6, AC-8)

    /// Y9: GIVEN Altladen WHEN „Alle übernehmen“ THEN der Abschnitt verschwindet, „Gänge · 5“ mit Asia-Regal,
    /// Backstation, Wein nach „Getränke“ (Reihenfolge der eigenen Kategorien, alphabetisch; die Aufzählung
    /// der Spec-Zeile folgt dieser Regel nicht); in der Liste Nudeln unter „Asia-Regal“, Baguette unter „Backstation“.
    func testAdoptAllLegacyCategories() {
        let app = legacyStore()
        chooseCategoryMode(app)
        openSetup(app)
        tapRevealed("stationSetup.adopt.all", "Alle übernehmen", in: app)
        waitForGone(element("stationSetup.adopt.section", app), "Abschnitt „von früher“ bleibt nach „Alle übernehmen“")
        scrollToTop(app)
        XCTAssertTrue(label("Gänge · 5", app).waitForExistence(timeout: UITestWait.defaultTimeout), "Übersicht zeigt nicht „Gänge · 5“")
        let order = ["Getränke", "Asia-Regal", "Backstation", "Wein"]
        for (upper, lower) in zip(order, order.dropFirst()) {
            assertAbove(element("stationSetup.row.\(upper)", app), "Gang \(upper)",
                        element("stationSetup.row.\(lower)", app), "Gang \(lower)", in: app)
        }
        attach("Y9 alle übernommen", app)
        scrollToTop(app)
        closeSetup(app)

        assertDirectlyUnder("Nudeln", header: "Asia-Regal", emoji: "🍜", in: app)
        assertDirectlyUnder("Baguette", header: "Backstation", emoji: "🥖", in: app)
    }
}
