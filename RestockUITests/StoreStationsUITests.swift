import XCTest

/// Issue #234, Durchgang 1 (`docs/specs/models/store-stations.md`): Laden-Stationen („Gänge“) in der
/// Ladenliste, in der Kategorie-Auswahl und im ···-Menü.
///
/// Seed (`-seedStationStoreForUITests`, Aufräumer `-clearStationStoreForUITests`): Laden
/// „Stationsladen“ mit Lidl-Vorlage, offene Artikel in der Hinzufüge-Reihenfolge Batterien, Milch,
/// Gouda, Salami, Apfel, Brot (Brot dringend), kein gelernter Weg, Modus „Einkaufsweg“. Die
/// Hinzufüge-Reihenfolge ist das Gegenteil der Gang-Reihenfolge, damit eine Sortierung nach Datum
/// sichtbar falsch wäre.
///
/// Die Liste ist länger als ein Bildschirm: Vergleiche laufen paarweise und rollen bei Bedarf weiter.
final class StoreStationsUITests: XCTestCase {

    private let storeName = "Stationsladen"
    private let allStations = [
        "Obst & Gemüse", "Frische Säfte, Salate, gekühlte Getränke", "Nüsse, Süßigkeiten, Kaffee, Tee",
        "Brot & Backwaren", "Konserven & Gewürze", "Frisches Fleisch & Fisch", "Kühltheke Fertiges",
        "Käse", "Milchprodukte", "Tiefkühl", "Drogerie", "Getränke",
    ]

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

    // MARK: - Start und Menü

    private func openedStore() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-seedStationStoreForUITests"]
        let tile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(storeName),")).firstMatch
        UITestLaunch.start(app, expecting: tile, description: "Kachel „\(storeName)“")
        tile.tap()
        XCTAssertTrue(app.staticTexts["Salami"].waitForExistence(timeout: UITestWait.defaultTimeout), "Ladenliste nicht geöffnet")
        return app
    }

    private func openMenu(_ app: XCUIApplication) {
        let more = app.descendants(matching: .any)["storeDetail.moreMenu"].firstMatch
        let ready = more.waitUntilHittable()
        XCTAssertTrue(ready.matched, "···-Menü nicht antippbar — zuletzt: \(ready.last)")
        more.tap()
    }

    /// Wählt im schon geöffneten ···-Menü „Sortieren“ → `mode` (schließt damit das Menü).
    private func pickSort(_ mode: String, in app: XCUIApplication) {
        let sortMenu = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Sortieren")).firstMatch
        XCTAssertTrue(sortMenu.waitForExistence(timeout: UITestWait.defaultTimeout), "Menüpunkt „Sortieren“ fehlt")
        sortMenu.tap()
        let button = app.buttons[mode].firstMatch
        let option = button.waitForExistence(timeout: 5)
            ? button
            : app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", mode)).firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: UITestWait.defaultTimeout), "Sortieroption „\(mode)“ fehlt")
        option.tap()
    }

    private func choose(_ mode: String, in app: XCUIApplication) {
        openMenu(app)
        pickSort(mode, in: app)
        scrollToTop(app)
    }

    private func menuItem(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(identifier: identifier).firstMatch
    }

    private func reorderItem(_ app: XCUIApplication) -> XCUIElement {
        app.buttons["Reihenfolge anpassen"].firstMatch
    }

    // MARK: - „Kategorien einrichten“ (Durchgang 2a, `docs/specs/views/station-setup.md`)

    private func element(_ identifier: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// ··· → „Kategorien einrichten“; wartet auf die Übersicht.
    private func openSetup(_ app: XCUIApplication) {
        openMenu(app)
        let entry = menuItem("store.menu.setupStations", in: app)
        let ready = entry.waitUntilHittable()
        XCTAssertTrue(ready.matched, "„Kategorien einrichten“ fehlt im Menü — zuletzt: \(ready.last)")
        entry.tap()
        XCTAssertTrue(element("stationSetup.addStation", app).waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Übersicht „Kategorien einrichten“ nicht geöffnet")
    }

    /// „Fertig“ schließt die Ansicht.
    private func closeSetup(_ app: XCUIApplication) {
        let done = element("stationSetup.done", app)
        let ready = done.waitUntilHittable()
        XCTAssertTrue(ready.matched, "„Fertig“ fehlt — zuletzt: \(ready.last)")
        done.tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element("stationSetup.addStation", app))
        waitForExpectations(timeout: UITestWait.defaultTimeout)
        scrollToTop(app)
    }

    private func tapRevealed(_ identifier: String, _ what: String, in app: XCUIApplication,
                             file: StaticString = #filePath, line: UInt = #line) {
        let target = element(identifier, app)
        revealHittable(target, what, in: app, file: file, line: line)
        target.tap()
    }

    /// Tippt `identifier` an und bestätigt die Rückfrage `confirmID`.
    private func tapAndConfirm(_ identifier: String, confirmID: String, in app: XCUIApplication) {
        tapRevealed(identifier, identifier, in: app)
        let confirm = app.buttons.matching(identifier: confirmID).firstMatch
        let ready = confirm.waitUntilHittable()
        XCTAssertTrue(ready.matched, "Bestätigung \(confirmID) fehlt — zuletzt: \(ready.last)")
        confirm.tap()
    }

    /// Gang-Detail aus der Übersicht öffnen.
    private func openStation(_ name: String, in app: XCUIApplication) {
        tapRevealed("stationSetup.row.\(name)", "Gang-Zeile \(name)", in: app)
        XCTAssertTrue(app.textFields["stationSetup.detail.name"].firstMatch.waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Gang-Detail „\(name)“ nicht geöffnet")
    }

    /// Zurück aus dem Gang-Detail in die Übersicht.
    private func backToOverview(_ app: XCUIApplication) {
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(element("stationSetup.addStation", app).waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Zurück in die Übersicht fehlgeschlagen")
    }

    /// Ersetzt den Namen im Gang-Detail und bestätigt mit Return (`onSubmit`).
    private func renameStation(to name: String, in app: XCUIApplication) {
        let field = app.textFields["stationSetup.detail.name"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: UITestWait.defaultTimeout), "Namensfeld fehlt")
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        let current = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 2))
        field.typeText(name + "\n")
    }

    /// ··· → „Kategorien einrichten“ → „Gänge entfernen“ (Rückfrage) → Fertig.
    private func removeStationsViaSetup(_ app: XCUIApplication) {
        openSetup(app)
        tapAndConfirm("stationSetup.remove", confirmID: "stationSetup.confirmRemove", in: app)
        closeSetup(app)
    }

    /// Prüft oben und unten, dass keine „Sonstiges“-Überschrift (bzw. kein Untertitel) erscheint.
    private func assertNoOther(_ app: XCUIApplication, _ reason: String,
                               file: StaticString = #filePath, line: UInt = #line) {
        for position in ["unten", "oben"] {
            if position == "oben" { scrollToTop(app) } else { scrollToBottom(app) }
            XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Sonstiges")).firstMatch.exists,
                           "\(reason) (\(position))", file: file, line: line)
        }
        scrollToTop(app)
    }

    /// Abschnittsüberschrift mit genau diesem Namen hinter dem Emoji (schließt „Käsetheke“ für „Käse“ aus).
    private func exactHeader(_ name: String, emoji: String, _ app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@ AND label ENDSWITH[c] %@", emoji, " \(name)")).firstMatch
    }

    // MARK: - Rollen und Reihenfolge

    /// Zieht den Inhalt um etwa ein Fünftel des Fensters nach oben (rollt nach unten).
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

    /// Rollt, bis `element` im Baum ist (höchstens sechs Schritte); Listenzeilen unter dem Rand fehlen sonst.
    @discardableResult
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        for _ in 0..<6 {
            if element.waitForExistence(timeout: 2) { return true }
            dragUp(app)
        }
        return element.exists
    }

    /// Rollt, bis `element` antippbar ist.
    private func revealHittable(_ element: XCUIElement, _ what: String, in app: XCUIApplication,
                                file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<6 {
            if element.waitUntilHittable(timeout: 2).matched { return }
            dragUp(app)
        }
        let ready = element.waitUntilHittable(timeout: 2)
        XCTAssertTrue(ready.matched, "„\(what)“ nicht antippbar — zuletzt: \(ready.last)", file: file, line: line)
    }

    /// GIVEN zwei Elemente WHEN beide im Baum THEN `upper` steht oberhalb von `lower`. Wartet bis zur
    /// Standardfrist (Liste sortiert nach Moduswechsel mit Animation um).
    private func assertAbove(_ upper: XCUIElement, _ upperName: String, _ lower: XCUIElement, _ lowerName: String,
                             in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(reveal(upper, in: app), "„\(upperName)“ nicht gefunden", file: file, line: line)
        XCTAssertTrue(reveal(lower, in: app), "„\(lowerName)“ nicht gefunden", file: file, line: line)
        XCTAssertTrue(upper.exists, "„\(upperName)“ beim Rollen zu „\(lowerName)“ verloren", file: file, line: line)
        let result = UITestWait.poll(timeout: UITestWait.defaultTimeout,
                                     read: { (upper.frame.minY, lower.frame.minY) },
                                     done: { $0.0 < $0.1 })
        XCTAssertTrue(result.matched, "„\(upperName)“ (y=\(result.last.0)) muss über „\(lowerName)“ (y=\(result.last.1)) stehen",
                      file: file, line: line)
    }

    private func text(_ label: String, _ app: XCUIApplication) -> XCUIElement {
        app.staticTexts[label].firstMatch
    }

    /// Abschnittsüberschrift „<Emoji> <Name>“. Nur über den Namen gesucht träfe man auch den
    /// Untertitel der Zeile (ohne Emoji).
    private func header(_ name: String, emoji: String, _ app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS[c] %@", emoji, name)).firstMatch
    }

    /// Überschrift „Dringend“ (Label des Abschnittskopfs).
    private func urgentHeader(_ app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Dringend")).firstMatch
    }

    /// Die „Sonstiges“-Überschrift (ohne Emoji) steht über `item`; der gleichlautende Untertitel der
    /// Zeile darunter. Liefert die Y-Position der Überschrift, falls vorhanden.
    private func otherHeaderY(above item: XCUIElement, _ app: XCUIApplication) -> CGFloat? {
        let itemY = item.frame.minY
        return app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Sonstiges"))
            .allElementsBoundByIndex
            .filter { $0.exists }
            .map { $0.frame.minY }
            .filter { $0 < itemY }
            .max()
    }

    /// Prüft oben und unten in der Liste, dass keine Überschrift mit diesem Emoji erscheint.
    private func assertNoHeaders(_ emojis: [String], in app: XCUIApplication, _ reason: String,
                                 file: StaticString = #filePath, line: UInt = #line) {
        for position in ["oben", "unten"] {
            if position == "unten" { scrollToBottom(app) } else { scrollToTop(app) }
            for emoji in emojis {
                let found = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", emoji)).firstMatch
                XCTAssertFalse(found.exists, "\(reason): Überschrift mit \(emoji) (\(position)) — \(found.exists ? found.label : "")",
                               file: file, line: line)
            }
        }
        scrollToTop(app)
    }

    // MARK: - Dialoge

    private func openCategoryPicker(for item: String, in app: XCUIApplication) {
        revealHittable(text(item, app), item, in: app)
        UITestItemEditor.open(item, in: app)
        let categoryRow = app.descendants(matching: .any)["item.categoryRow"].firstMatch
        XCTAssertTrue(categoryRow.waitForExistence(timeout: UITestWait.defaultTimeout), "Zeile „Kategorie“ im Bearbeiten-Dialog fehlt")
        categoryRow.tap()
        XCTAssertTrue(app.textFields["categoryPicker.search"].firstMatch.waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Kategorie-Auswahl nicht geöffnet")
    }

    private func saveEditor(_ app: XCUIApplication) {
        let save = app.buttons["Speichern"].firstMatch
        let ready = save.waitUntilHittable()
        XCTAssertTrue(ready.matched, "„Speichern“ im Dialog fehlt — zuletzt: \(ready.last)")
        save.tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: save)
        waitForExpectations(timeout: UITestWait.defaultTimeout)
    }

    // MARK: - U1: Modus Kategorie (AC-2, AC-3, AC-4)

    /// U1 / AC-2, AC-3, AC-4: GIVEN Seed WHEN Modus „Kategorie“ THEN Abschnitte in Gang-Reihenfolge:
    /// Dringend (Brot), Obst & Gemüse (Apfel), Kühltheke Fertiges (Salami), Käse (Gouda),
    /// Milchprodukte (Milch), zuletzt Sonstiges ohne Emoji (Batterien); leere Gänge ohne Überschrift.
    func testCategoryModeShowsStationSections() {
        let app = openedStore()
        choose("Kategorie", in: app)

        let chain: [(XCUIElement, String)] = [
            (urgentHeader(app), "Überschrift Dringend"), (text("Brot", app), "Brot"),
            (header("Obst & Gemüse", emoji: "🥦", app), "Überschrift 🥦 Obst & Gemüse"), (text("Apfel", app), "Apfel"),
            (header("Kühltheke Fertiges", emoji: "🧊", app), "Überschrift 🧊 Kühltheke Fertiges"), (text("Salami", app), "Salami"),
            (header("Käse", emoji: "🧀", app), "Überschrift 🧀 Käse"), (text("Gouda", app), "Gouda"),
            (header("Milchprodukte", emoji: "🥛", app), "Überschrift 🥛 Milchprodukte"), (text("Milch", app), "Milch"),
            (text("Batterien", app), "Batterien"),
        ]
        for (upper, lower) in zip(chain, chain.dropFirst()) {
            assertAbove(upper.0, upper.1, lower.0, lower.1, in: app)
        }

        // Sonstiges: letzte Überschrift, ohne Emoji, zwischen Milch und Batterien.
        let batterien = text("Batterien", app)
        XCTAssertTrue(reveal(batterien, in: app), "Batterien nicht gefunden")
        let otherY = otherHeaderY(above: batterien, app)
        XCTAssertNotNil(otherY, "Überschrift „Sonstiges“ über Batterien fehlt")
        if let otherY {
            XCTAssertGreaterThan(otherY, text("Milch", app).frame.minY, "„Sonstiges“ muss nach Milchprodukte kommen")
        }

        // Leere Gänge (Brot ist dringend, Gang Brot & Backwaren also leer) haben keine Überschrift.
        assertNoHeaders(["🥖", "🥗", "☕️", "🥫", "🥩", "❄️", "🧴", "🥤"], in: app, "Leerer Gang")
    }

    // MARK: - U2: Modus Einkaufsweg (AC-8, AC-10)

    /// U2 / AC-8, AC-10: GIVEN Seed WHEN Modus „Einkaufsweg“ THEN flache Reihenfolge Brot, Apfel,
    /// Salami, Gouda, Milch, Batterien (Hinzufüge-Reihenfolge ist umgekehrt); Untertitel „Kühltheke
    /// Fertiges“ unter Salami, „Sonstiges“ unter Batterien; keine Gang-Überschrift.
    func testRouteModeIsFlatInStationOrderWithStationSubtitles() {
        let app = openedStore()
        choose("Hinzugefügt", in: app)
        assertAbove(text("Batterien", app), "Batterien", text("Milch", app), "Milch", in: app)
        scrollToTop(app)
        choose("Einkaufsweg", in: app)

        let order = ["Brot", "Apfel", "Salami", "Gouda", "Milch", "Batterien"]
        for (upper, lower) in zip(order, order.dropFirst()) {
            assertAbove(text(upper, app), upper, text(lower, app), lower, in: app)
        }

        scrollToTop(app)
        let subtitle = text("Kühltheke Fertiges", app)
        assertAbove(text("Salami", app), "Salami", subtitle, "Untertitel Kühltheke Fertiges", in: app)
        assertAbove(subtitle, "Untertitel Kühltheke Fertiges", text("Gouda", app), "Gouda", in: app)
        XCTAssertFalse(text("Fleisch & Wurst", app).exists, "Der Untertitel zeigt den Gang, nicht die feste Kategorie")
        assertAbove(text("Batterien", app), "Batterien", text("Sonstiges", app), "Untertitel Sonstiges", in: app)

        assertNoHeaders(["🥦", "🧊", "🧀", "🥛"], in: app, "Einkaufsweg ist flach")
    }

    // MARK: - U3: Auswahl zeigt nur Gänge (AC-11)

    /// U3 / AC-11: GIVEN Seed WHEN Auswahl in „Salami“ öffnen THEN Zeilen für alle 12 Gänge und
    /// „Sonstiges“ (zuletzt); keine Zeilen fester Kategorien, kein Abschnitt „Alle Kategorien“.
    func testPickerShowsOnlyStationsAndOther() {
        let app = openedStore()
        openCategoryPicker(for: "Salami", in: app)

        let wanted = allStations.map { "categoryPicker.row.\($0)" } + ["categoryPicker.row.other"]
        let forbidden = ["categoryPicker.row.Werkzeug", "categoryPicker.row.Körperpflege", "categoryPicker.row.Lebensmittel"]
        var seen = Set<String>()
        for _ in 0..<10 {
            for id in wanted where !seen.contains(id) && app.descendants(matching: .any)[id].firstMatch.exists {
                seen.insert(id)
            }
            for id in forbidden {
                XCTAssertFalse(app.descendants(matching: .any)[id].firstMatch.exists, "Feste Kategorie in der Auswahl: \(id)")
            }
            XCTAssertFalse(app.staticTexts["Alle Kategorien"].exists, "Abschnitt „Alle Kategorien“ darf fehlen")
            if seen.count == wanted.count { break }
            dragUp(app)
        }
        XCTAssertEqual(Set(wanted).subtracting(seen).sorted(), [], "Gang-Zeilen fehlen in der Auswahl")

        let last = app.descendants(matching: .any)["categoryPicker.row.Getränke"].firstMatch
        let other = app.descendants(matching: .any)["categoryPicker.row.other"].firstMatch
        assertAbove(last, "Gang Getränke", other, "Sonstiges", in: app)
    }

    // MARK: - U4: Gang anlegen (AC-11)

    /// U4 / AC-11: GIVEN Seed WHEN in „Batterien“ über die Suche „Backstation“ anlegen und speichern
    /// THEN im Modus „Kategorie“ ist „Backstation“ der letzte Abschnitt hinter Milchprodukte, und
    /// „Sonstiges“ erscheint nicht mehr (Batterien war der einzige Artikel dort).
    func testCreatingStationFromPickerAppendsSection() {
        let app = openedStore()
        openCategoryPicker(for: "Batterien", in: app)
        let search = app.textFields["categoryPicker.search"].firstMatch
        search.tap()
        search.typeText("Backstation")
        let create = app.descendants(matching: .any)["categoryPicker.create"].firstMatch
        let ready = create.waitUntilHittable()
        XCTAssertTrue(ready.matched, "„„Backstation“ als Gang bei \(storeName) anlegen“ fehlt — zuletzt: \(ready.last)")
        XCTAssertTrue(create.label.contains("Gang"), "Die Anlegen-Zeile spricht von einem Gang: \(create.label)")
        create.tap()
        saveEditor(app)

        choose("Kategorie", in: app)
        let backstation = header("Backstation", emoji: "🥖", app)
        assertAbove(header("Milchprodukte", emoji: "🥛", app), "Überschrift Milchprodukte", backstation, "Überschrift Backstation", in: app)
        assertAbove(text("Milch", app), "Milch", backstation, "Überschrift Backstation", in: app)
        assertAbove(backstation, "Überschrift Backstation", text("Batterien", app), "Batterien", in: app)
        for position in ["unten", "oben"] {
            if position == "oben" { scrollToTop(app) }
            XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Sonstiges")).firstMatch.exists,
                           "„Sonstiges“ darf ohne Artikel nicht erscheinen (\(position))")
        }
    }

    // MARK: - U5: Gemerkter Gang beim Neu-Hinzufügen (AC-12)

    /// U5 / AC-12: GIVEN Seed WHEN „Batterien“ auf „Drogerie“ setzen, speichern, löschen und über „+“
    /// neu hinzufügen THEN steht der neue Artikel im Abschnitt Drogerie.
    func testChosenStationIsRememberedForNewItem() {
        let app = openedStore()
        openCategoryPicker(for: "Batterien", in: app)
        let drogerie = app.descendants(matching: .any)["categoryPicker.row.Drogerie"].firstMatch
        revealHittable(drogerie, "Gang Drogerie in der Auswahl", in: app)
        drogerie.tap()
        saveEditor(app)

        // Löschen per vollem Wisch nach links.
        let batterien = text("Batterien", app)
        revealHittable(batterien, "Batterien", in: app)
        let row = app.cells.containing(.staticText, identifier: "Batterien").firstMatch
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: row.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5)),
                   withVelocity: .fast, thenHoldForDuration: 0)
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: batterien)
        waitForExpectations(timeout: UITestWait.defaultTimeout)

        scrollToTop(app)
        let addButton = app.buttons.matching(NSPredicate(format: "identifier == 'plus'")).firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: UITestWait.defaultTimeout), "„+“ in der Ladenliste fehlt")
        addButton.tap()
        let nameField = app.textFields["Artikelname"]
        XCTAssertTrue(nameField.waitForExistence(timeout: UITestWait.defaultTimeout), "Artikelname-Feld fehlt")
        nameField.tap()
        nameField.typeText("Batterien")
        let confirm = app.navigationBars["Artikel hinzufügen"].buttons["Hinzufügen"]
        XCTAssertTrue(confirm.waitForExistence(timeout: UITestWait.defaultTimeout), "„Hinzufügen“ fehlt")
        confirm.tap()
        XCTAssertTrue(reveal(text("Batterien", app), in: app), "Neu hinzugefügte Batterien fehlen in der Liste")

        choose("Kategorie", in: app)
        assertAbove(header("Drogerie", emoji: "🧴", app), "Überschrift Drogerie", text("Batterien", app), "Batterien", in: app)
        assertAbove(text("Milch", app), "Milch", header("Drogerie", emoji: "🧴", app), "Überschrift Drogerie", in: app)
    }

    // MARK: - V1: Einstieg „Kategorien einrichten“ (ersetzt U6; Spec D2a AC-1, AC-2)

    /// V1 / AC-1, AC-2: GIVEN Seed WHEN ···-Menü THEN „Kategorien einrichten“ da, „Lidl-Vorlage
    /// übernehmen“ und „Gänge entfernen“ fehlen; „Reihenfolge anpassen“ nur im Einkaufsweg. WHEN
    /// geöffnet THEN Übersicht mit Vorlage, Gängen, Offen (9), Ausgeblendet (9), Gänge entfernen;
    /// „Fertig“ schließt sie.
    func testSetupEntryReplacesTemplateEntries() {
        let app = openedStore()
        choose("Einkaufsweg", in: app)

        openMenu(app)
        XCTAssertTrue(menuItem("store.menu.setupStations", in: app).waitForExistence(timeout: UITestWait.defaultTimeout),
                      "„Kategorien einrichten“ fehlt im Menü")
        XCTAssertFalse(menuItem("store.menu.applyStationTemplate", in: app).exists, "„Lidl-Vorlage übernehmen“ ist entfallen")
        XCTAssertFalse(menuItem("store.menu.removeStations", in: app).exists, "„Gänge entfernen“ steht nicht mehr im Menü")
        XCTAssertTrue(reorderItem(app).exists, "Im Einkaufsweg bleibt „Reihenfolge anpassen“")
        pickSort("Kategorie", in: app)

        openMenu(app)
        XCTAssertTrue(menuItem("store.menu.setupStations", in: app).waitForExistence(timeout: UITestWait.defaultTimeout),
                      "„Kategorien einrichten“ fehlt im Menü (Kategorie)")
        XCTAssertFalse(reorderItem(app).exists, "Im Modus Kategorie eines Ladens mit Gängen ist die Reihenfolge fest")
        pickSort("Kategorie", in: app)

        openSetup(app)
        XCTAssertTrue(element("stationSetup.template", app).exists, "„Vorlage wählen …“ fehlt")
        for label in ["Gänge · 12", "Offen · 9", "Ausgeblendet · 9"] {
            let header = app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", label)).firstMatch
            XCTAssertTrue(reveal(header, in: app), "Abschnitt „\(label)“ fehlt")
        }
        XCTAssertTrue(reveal(element("stationSetup.open.Elektronik", app), in: app), "„Elektronik“ fehlt unter „Offen“")
        XCTAssertTrue(reveal(element("stationSetup.hidden.Werkzeug", app), in: app), "„Werkzeug“ fehlt unter „Ausgeblendet“")
        XCTAssertTrue(reveal(element("stationSetup.remove", app), in: app), "„Gänge entfernen“ fehlt in der Ansicht")
        closeSetup(app)
        XCTAssertTrue(text("Salami", app).waitForExistence(timeout: UITestWait.defaultTimeout), "Nach „Fertig“ wieder die Liste")
    }

    // MARK: - V2: Umbenennen (AC-3, AC-4)

    /// V2 / AC-3: GIVEN Seed, Modus Kategorie WHEN Gang „Käse“ in „Käsetheke“ umbenannt THEN Abschnitt
    /// „Käsetheke“ mit Gouda, kein Abschnitt „Käse“; die Gang-Zeile heißt danach „Käsetheke“.
    func testRenameStationMovesItemsToRenamedSection() {
        let app = openedStore()
        choose("Kategorie", in: app)

        openSetup(app)
        openStation("Käse", in: app)
        renameStation(to: "Käsetheke", in: app)
        backToOverview(app)
        closeSetup(app)

        assertAbove(exactHeader("Käsetheke", emoji: "🧀", app), "Überschrift 🧀 Käsetheke", text("Gouda", app), "Gouda", in: app)
        assertAbove(text("Gouda", app), "Gouda", header("Milchprodukte", emoji: "🥛", app), "Überschrift Milchprodukte", in: app)
        scrollToTop(app)
        for position in ["oben", "unten"] {
            if position == "unten" { scrollToBottom(app) }
            XCTAssertFalse(exactHeader("Käse", emoji: "🧀", app).exists, "Abschnitt „Käse“ darf es nicht mehr geben (\(position))")
        }
        scrollToTop(app)

        openSetup(app)
        XCTAssertTrue(reveal(element("stationSetup.row.Käsetheke", app), in: app), "Gang-Zeile „Käsetheke“ fehlt")
        XCTAssertFalse(element("stationSetup.row.Käse", app).exists, "Gang-Zeile „Käse“ darf es nicht mehr geben")
        closeSetup(app)
    }

    // MARK: - V3: Kollision (AC-5)

    /// V3 / AC-5: GIVEN Seed WHEN „Käse“ auf „Milchprodukte“ umbenannt THEN Hinweis sichtbar, nichts
    /// zusammengeführt: Gouda bleibt unter „Käse“, Milch unter „Milchprodukte“.
    func testRenameCollisionIsRejected() {
        let app = openedStore()
        choose("Kategorie", in: app)

        openSetup(app)
        openStation("Käse", in: app)
        renameStation(to: "Milchprodukte", in: app)
        let hint = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Diesen Namen gibt es schon")).firstMatch
        XCTAssertTrue(hint.waitForExistence(timeout: UITestWait.defaultTimeout), "Hinweis auf abgelehnten Namen fehlt")
        backToOverview(app)
        XCTAssertTrue(reveal(element("stationSetup.row.Käse", app), in: app), "Gang „Käse“ muss erhalten bleiben")
        closeSetup(app)

        let chain: [(XCUIElement, String)] = [
            (exactHeader("Käse", emoji: "🧀", app), "Überschrift 🧀 Käse"), (text("Gouda", app), "Gouda"),
            (header("Milchprodukte", emoji: "🥛", app), "Überschrift 🥛 Milchprodukte"), (text("Milch", app), "Milch"),
        ]
        for (upper, lower) in zip(chain, chain.dropFirst()) {
            assertAbove(upper.0, upper.1, lower.0, lower.1, in: app)
        }
    }

    // MARK: - V4: Offene Kategorie im Gang-Detail zuordnen (AC-8)

    /// V4 / AC-8: GIVEN Seed WHEN Gang „Drogerie“ → „Elektronik“ angetippt THEN Zeile ausgewählt; die
    /// Liste zeigt Batterien unter „Drogerie“, „Sonstiges“ erscheint nicht mehr.
    func testAssignOpenCategoryMovesItemToStation() {
        let app = openedStore()
        choose("Kategorie", in: app)

        openSetup(app)
        openStation("Drogerie", in: app)
        let row = element("stationSetup.detail.category.Elektronik", app)
        revealHittable(row, "Kategorie Elektronik im Gang-Detail", in: app)
        XCTAssertFalse(row.isSelected, "Vorbedingung: Elektronik ist offen, nicht in Drogerie")
        row.tap()
        let selected = UITestWait.poll(timeout: UITestWait.defaultTimeout, read: { row.isSelected }, done: { $0 })
        XCTAssertTrue(selected.matched, "Elektronik muss nach dem Tipp als zugeordnet markiert sein")
        backToOverview(app)
        XCTAssertFalse(element("stationSetup.open.Elektronik", app).exists, "Elektronik steht nicht mehr unter „Offen“")
        closeSetup(app)

        assertAbove(header("Drogerie", emoji: "🧴", app), "Überschrift Drogerie", text("Batterien", app), "Batterien", in: app)
        assertNoOther(app, "„Sonstiges“ darf ohne Artikel nicht erscheinen")
    }

    // MARK: - V5: Zuordnen über „Offen“, Ausblenden, Einblenden (AC-8, AC-9)

    /// V5 / AC-8: GIVEN Seed WHEN „Elektronik“ über „Zuordnen …“ → Drogerie, im Detail wieder offen,
    /// dann „Ausblenden“ THEN Abschnitt „Ausgeblendet“ enthält sie, Batterien steht unter „Sonstiges“;
    /// „Einblenden“ → wieder offen.
    func testHideCategoryRemovesItemFromStation() {
        let app = openedStore()
        openSetup(app)

        tapRevealed("stationSetup.open.Elektronik", "Zuordnen … für Elektronik", in: app)
        let drogerie = app.buttons["Drogerie"].firstMatch
        XCTAssertTrue(drogerie.waitForExistence(timeout: UITestWait.defaultTimeout), "Gang „Drogerie“ im Zuordnen-Menü fehlt")
        drogerie.tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element("stationSetup.open.Elektronik", app))
        waitForExpectations(timeout: UITestWait.defaultTimeout)

        scrollToTop(app)
        openStation("Drogerie", in: app)
        let row = element("stationSetup.detail.category.Elektronik", app)
        revealHittable(row, "Kategorie Elektronik im Gang-Detail", in: app)
        XCTAssertTrue(row.isSelected, "Elektronik muss nach „Zuordnen …“ in Drogerie stehen")
        row.tap()
        let opened = UITestWait.poll(timeout: UITestWait.defaultTimeout, read: { row.isSelected }, done: { !$0 })
        XCTAssertTrue(opened.matched, "Tipp auf die markierte Zeile macht Elektronik wieder offen")
        backToOverview(app)

        tapRevealed("stationSetup.open.Elektronik", "Zuordnen … für Elektronik (wieder offen)", in: app)
        let hide = app.buttons["Ausblenden"].firstMatch
        XCTAssertTrue(hide.waitForExistence(timeout: UITestWait.defaultTimeout), "„Ausblenden“ im Zuordnen-Menü fehlt")
        hide.tap()
        XCTAssertTrue(reveal(element("stationSetup.hidden.Elektronik", app), in: app), "Elektronik fehlt unter „Ausgeblendet“")
        XCTAssertFalse(element("stationSetup.open.Elektronik", app).exists, "Elektronik steht nicht mehr unter „Offen“")
        closeSetup(app)

        choose("Kategorie", in: app)
        let batterien = text("Batterien", app)
        XCTAssertTrue(reveal(batterien, in: app), "Batterien fehlt")
        XCTAssertNotNil(otherHeaderY(above: batterien, app), "Batterien muss unter „Sonstiges“ stehen")
        scrollToTop(app)

        openSetup(app)
        tapRevealed("stationSetup.hidden.Elektronik", "Einblenden für Elektronik", in: app)
        XCTAssertTrue(reveal(element("stationSetup.open.Elektronik", app), in: app), "Elektronik nach „Einblenden“ wieder offen")
        XCTAssertFalse(element("stationSetup.hidden.Elektronik", app).exists, "Elektronik nicht mehr ausgeblendet")
        closeSetup(app)
    }

    // MARK: - V6: Gang anlegen und löschen (AC-7, AC-10)

    /// V6 / AC-7, AC-10: GIVEN Seed WHEN „Gang hinzufügen“ → „Lager“, Batterien in der Auswahl dorthin,
    /// dann „Gang löschen“ bestätigt THEN „Lager“ erscheint und verschwindet wieder, Batterien steht
    /// danach in „Sonstiges“.
    func testAddAndDeleteStationFromSetup() {
        let app = openedStore()
        openSetup(app)
        tapRevealed("stationSetup.addStation", "Gang hinzufügen", in: app)
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: UITestWait.defaultTimeout), "Eingabe „Name des Gangs“ fehlt")
        field.typeText("Lager")
        app.alerts.buttons["Hinzufügen"].firstMatch.tap()
        XCTAssertTrue(reveal(element("stationSetup.row.Lager", app), in: app), "Gang „Lager“ fehlt in der Übersicht")
        closeSetup(app)

        openCategoryPicker(for: "Batterien", in: app)
        let lager = element("categoryPicker.row.Lager", app)
        revealHittable(lager, "Gang Lager in der Auswahl", in: app)
        lager.tap()
        saveEditor(app)

        choose("Kategorie", in: app)
        let lagerHeader = app.staticTexts.matching(NSPredicate(
            format: "label ENDSWITH[c] %@ AND NOT (label ==[c] %@)", " Lager", "Lager")).firstMatch
        assertAbove(lagerHeader, "Überschrift Lager", text("Batterien", app), "Batterien", in: app)
        scrollToTop(app)

        openSetup(app)
        openStation("Lager", in: app)
        tapAndConfirm("stationSetup.detail.delete", confirmID: "stationSetup.confirmDelete", in: app)
        XCTAssertTrue(element("stationSetup.addStation", app).waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Nach dem Löschen zurück in der Übersicht")
        XCTAssertFalse(element("stationSetup.row.Lager", app).exists, "Gang „Lager“ muss verschwunden sein")
        closeSetup(app)

        let batterien = text("Batterien", app)
        XCTAssertTrue(reveal(batterien, in: app), "Batterien fehlt")
        XCTAssertNotNil(otherHeaderY(above: batterien, app), "Batterien muss nach dem Löschen unter „Sonstiges“ stehen")
        XCTAssertFalse(lagerHeader.exists, "Kein Abschnitt „Lager“ mehr")
    }

    // MARK: - V7: Sortieren (AC-6)

    /// V7 / AC-6: GIVEN Seed WHEN „Sortieren“ und „Käse“ vor „Obst & Gemüse“ gezogen THEN die Übersicht
    /// und die Liste im Modus Kategorie folgen (Gouda über Apfel).
    func testSortModeReordersStations() {
        let app = openedStore()
        openSetup(app)
        tapRevealed("stationSetup.sort", "Sortieren", in: app)
        let handles = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "anordnen"))
        let kaese = handles.matching(NSPredicate(format: "label CONTAINS %@ AND NOT (label CONTAINS %@)", "Käse", "Gemüse")).firstMatch
        let obst = handles.matching(NSPredicate(format: "label CONTAINS %@", "Obst & Gemüse")).firstMatch
        XCTAssertTrue(kaese.waitForExistence(timeout: UITestWait.defaultTimeout), "Verschiebegriff „Käse“ fehlt")
        XCTAssertTrue(obst.exists, "Verschiebegriff „Obst & Gemüse“ fehlt")
        let target = obst.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: 0, dy: -20))
        kaese.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.8, thenDragTo: target, withVelocity: .slow, thenHoldForDuration: 0.5)
        element("stationSetup.sort", app).tap()

        assertAbove(element("stationSetup.row.Käse", app), "Gang-Zeile Käse",
                    element("stationSetup.row.Obst & Gemüse", app), "Gang-Zeile Obst & Gemüse", in: app)
        closeSetup(app)

        choose("Kategorie", in: app)
        assertAbove(exactHeader("Käse", emoji: "🧀", app), "Überschrift Käse", header("Obst & Gemüse", emoji: "🥦", app),
                    "Überschrift Obst & Gemüse", in: app)
        assertAbove(text("Gouda", app), "Gouda", text("Apfel", app), "Apfel", in: app)
    }

    // MARK: - V8: Gänge entfernen und Vorlage wählen (ersetzt U7; AC-1, AC-11, AC-13)

    /// V8 / AC-11, AC-13: GIVEN Seed WHEN „Gänge entfernen“ bestätigt THEN klassische Abschnitte
    /// (Salami unter „Fleisch & Wurst“), die Ansicht zeigt nur „Vorlage wählen …“ und „Gang
    /// hinzufügen“; der Menüeintrag bleibt; WHEN „Vorlage wählen …“ → „Lidl“ THEN wieder Gänge.
    func testRemoveStationsAndApplyTemplate() {
        let app = openedStore()
        choose("Kategorie", in: app)
        XCTAssertTrue(reveal(header("Kühltheke Fertiges", emoji: "🧊", app), in: app), "Ausgangslage: Gang-Abschnitt")
        scrollToTop(app)

        openSetup(app)
        tapAndConfirm("stationSetup.remove", confirmID: "stationSetup.confirmRemove", in: app)
        XCTAssertTrue(element("stationSetup.template", app).waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Nach dem Entfernen bleibt die Ansicht offen und zeigt „Vorlage wählen …“")
        XCTAssertTrue(element("stationSetup.addStation", app).exists, "„Gang hinzufügen“ fehlt im leeren Zustand")
        XCTAssertFalse(element("stationSetup.row.Käse", app).exists, "Keine Gang-Zeilen mehr")
        XCTAssertFalse(element("stationSetup.remove", app).exists, "„Gänge entfernen“ nur mit Gängen")
        XCTAssertFalse(element("stationSetup.open.Elektronik", app).exists, "Ohne Gänge kein Abschnitt „Offen“")
        closeSetup(app)

        let classic = app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS[c] %@ AND NOT (label ==[c] %@)", "Fleisch & Wurst", "Fleisch & Wurst")).firstMatch
        assertAbove(classic, "Überschrift Fleisch & Wurst", text("Salami", app), "Salami", in: app)
        scrollToTop(app)
        XCTAssertFalse(header("Kühltheke Fertiges", emoji: "🧊", app).exists, "Nach dem Entfernen keine Gang-Abschnitte")

        openMenu(app)
        XCTAssertTrue(menuItem("store.menu.setupStations", in: app).waitForExistence(timeout: UITestWait.defaultTimeout),
                      "„Kategorien einrichten“ steht auch im Laden ohne Gänge")
        XCTAssertTrue(reorderItem(app).exists, "„Reihenfolge anpassen“ wieder da")
        pickSort("Kategorie", in: app)

        openSetup(app)
        tapRevealed("stationSetup.template", "Vorlage wählen …", in: app)
        let lidl = app.buttons.matching(identifier: "stationSetup.templateLidl").firstMatch
        let ready = lidl.waitUntilHittable()
        XCTAssertTrue(ready.matched, "Eintrag „Lidl“ im Vorlagen-Dialog fehlt — zuletzt: \(ready.last)")
        lidl.tap()
        XCTAssertTrue(reveal(element("stationSetup.row.Käse", app), in: app), "Nach der Vorlage wieder Gang-Zeilen")
        closeSetup(app)
        assertAbove(header("Kühltheke Fertiges", emoji: "🧊", app), "Überschrift Kühltheke Fertiges",
                    text("Salami", app), "Salami", in: app)
    }

    // MARK: - U8: Wahl „Sonstiges“ in Bearbeiten und Hinzufügen (AC-6, AC-13, Adversary F002)

    /// U8 / AC-13: GIVEN Seed WHEN Salami (Bearbeiten) und ein neuer „Schinken“ (Hinzufügen) mit der
    /// Wahl „Sonstiges“ gespeichert THEN beide stehen im Modus Kategorie unter „Sonstiges“, obwohl
    /// ihr Stichwort zur Kühltheke führt; nach „Gänge entfernen“ stehen beide unter „Fleisch & Wurst“
    /// und der Bearbeiten-Dialog zeigt diese feste Kategorie — die Marke steckt nicht in `item.category`.
    func testChoosingOtherNeverStoresMarkerAsCategory() {
        let app = openedStore()
        let other = app.descendants(matching: .any)["categoryPicker.row.other"].firstMatch
        openCategoryPicker(for: "Salami", in: app)
        revealHittable(other, "Sonstiges in der Auswahl (Bearbeiten)", in: app)
        other.tap()
        saveEditor(app)

        scrollToTop(app)
        app.buttons.matching(NSPredicate(format: "identifier == 'plus'")).firstMatch.tap()
        let nameField = app.textFields["Artikelname"]
        XCTAssertTrue(nameField.waitForExistence(timeout: UITestWait.defaultTimeout), "Artikelname-Feld fehlt")
        nameField.tap()
        nameField.typeText("Schinken")
        app.descendants(matching: .any)["item.categoryRow"].firstMatch.tap()
        revealHittable(other, "Sonstiges in der Auswahl (Hinzufügen)", in: app)
        other.tap()
        app.navigationBars["Artikel hinzufügen"].buttons["Hinzufügen"].tap()

        choose("Kategorie", in: app)
        for item in ["Salami", "Schinken"] {
            XCTAssertTrue(reveal(text(item, app), in: app), "\(item) fehlt")
            XCTAssertNotNil(otherHeaderY(above: text(item, app), app), "\(item) muss unter „Sonstiges“ stehen")
        }
        scrollToTop(app)

        // D2a: Gänge entfernen geht nur noch über „Kategorien einrichten“ (Menüeintrag entfallen).
        removeStationsViaSetup(app)
        let classic = app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS[c] %@ AND NOT (label ==[c] %@)", "Fleisch & Wurst", "Fleisch & Wurst")).firstMatch
        assertAbove(classic, "Überschrift Fleisch & Wurst", text("Salami", app), "Salami", in: app)
        assertAbove(classic, "Überschrift Fleisch & Wurst", text("Schinken", app), "Schinken", in: app)

        // Der Dialog zeigt, was in `item.category` steht (Marke wäre „\u{E000}other“). Nötig, weil die
        // Liste bei nicht von Hand gesetzter Kategorie ohnehin die automatische zeigt.
        for item in ["Salami", "Schinken"] {
            revealHittable(text(item, app), item, in: app)
            // Eine am unteren Rand angeschnittene Zeile gilt als antippbar, das Lang-Drücken dort öffnet aber nichts.
            if text(item, app).frame.maxY > app.windows.firstMatch.frame.maxY - 150 { dragUp(app) }
            var previous = CGRect.null
            _ = UITestWait.poll(timeout: 5, read: { text(item, app).frame }, done: { frame in defer { previous = frame }; return frame == previous })
            UITestItemEditor.open(item, in: app)
            let row = app.descendants(matching: .any)["item.categoryRow"].firstMatch
            let label = row.waitForLabel(contains: "Fleisch & Wurst")
            XCTAssertTrue(label.matched, "\(item): Kategorie im Dialog: \(label.lastLabel)")
            app.buttons["Abbrechen"].firstMatch.tap()
            expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: row)
            waitForExpectations(timeout: UITestWait.defaultTimeout)
        }
    }

    // MARK: - V10: Letzten Gang löschen (AC-11, Validierung)

    /// V10 / AC-11: GIVEN Laden mit genau einem Gang „Lager“ WHEN „Gang löschen“ im Gang-Detail THEN
    /// fragt die App „Gänge entfernen?“ (nicht „Gang „Lager“ löschen?“); nach Bestätigung zeigt die
    /// Übersicht nur „Vorlage wählen …“ und „Gang hinzufügen“.
    func testDeletingLastStationAsksToRemoveStations() {
        let app = openedStore()
        openSetup(app)
        tapAndConfirm("stationSetup.remove", confirmID: "stationSetup.confirmRemove", in: app)
        tapRevealed("stationSetup.addStation", "Gang hinzufügen", in: app)
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: UITestWait.defaultTimeout), "Eingabe „Name des Gangs“ fehlt")
        field.typeText("Lager")
        app.alerts.buttons["Hinzufügen"].firstMatch.tap()

        openStation("Lager", in: app)
        tapRevealed("stationSetup.detail.delete", "Gang löschen", in: app)
        let removeTitle = app.staticTexts["Gänge entfernen?"].firstMatch
        XCTAssertTrue(removeTitle.waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Beim letzten Gang muss die Rückfrage „Gänge entfernen?“ lauten")
        XCTAssertFalse(app.staticTexts["Gang „Lager“ löschen?"].exists, "Keine Rückfrage „Gang löschen“ beim letzten Gang")
        let confirm = app.buttons.matching(identifier: "stationSetup.confirmDelete").firstMatch
        XCTAssertTrue(confirm.waitUntilHittable().matched, "Bestätigung fehlt")
        XCTAssertEqual(confirm.label, "Gänge entfernen", "Der Knopf der Rückfrage heißt wie die Rückfrage")
        confirm.tap()

        XCTAssertTrue(element("stationSetup.template", app).waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Nach dem Löschen zeigt die Übersicht „Vorlage wählen …“")
        XCTAssertFalse(element("stationSetup.row.Lager", app).exists, "Keine Gang-Zeile mehr")
        closeSetup(app)
    }

    // MARK: - V9: Gang hinzufügen mit vorhandenem Namen (AC-5, Adversary F003)

    /// V9 / AC-5: GIVEN Seed WHEN „Gang hinzufügen“ mit „käse“ (vorhandener Gang, andere Schreibweise)
    /// THEN der Hinweis „Diesen Namen gibt es schon …“ erscheint und es bleibt bei 12 Gängen.
    func testAddStationWithExistingNameShowsHint() {
        let app = openedStore()
        openSetup(app)
        tapRevealed("stationSetup.addStation", "Gang hinzufügen", in: app)
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: UITestWait.defaultTimeout), "Eingabe „Name des Gangs“ fehlt")
        field.typeText("käse")
        app.alerts.buttons["Hinzufügen"].firstMatch.tap()

        let hint = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Diesen Namen gibt es schon")).firstMatch
        XCTAssertTrue(hint.waitForExistence(timeout: UITestWait.defaultTimeout), "Hinweis auf abgelehnten Namen fehlt")
        let dismiss = app.alerts.buttons.firstMatch
        XCTAssertTrue(dismiss.waitForExistence(timeout: UITestWait.defaultTimeout), "Knopf im Hinweis fehlt")
        dismiss.tap()

        let count = app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Gänge · 12")).firstMatch
        XCTAssertTrue(count.waitForExistence(timeout: UITestWait.defaultTimeout), "Es muss bei 12 Gängen bleiben")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Gänge · 13")).firstMatch.exists,
                       "Kein zweiter Gang „käse“")
        XCTAssertFalse(element("stationSetup.row.käse", app).exists, "Kein Gang in anderer Schreibweise")
        closeSetup(app)
    }
}
