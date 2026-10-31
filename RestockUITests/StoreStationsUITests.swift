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

    /// Tippt einen Menüeintrag mit Rückfrage an und bestätigt sie.
    private func confirmMenuAction(_ menuID: String, confirmID: String, in app: XCUIApplication) {
        openMenu(app)
        let entry = menuItem(menuID, in: app)
        let ready = entry.waitUntilHittable()
        XCTAssertTrue(ready.matched, "Menüeintrag \(menuID) fehlt — zuletzt: \(ready.last)")
        entry.tap()
        let confirm = app.buttons.matching(identifier: confirmID).firstMatch
        let confirmReady = confirm.waitUntilHittable()
        XCTAssertTrue(confirmReady.matched, "Bestätigung \(confirmID) fehlt — zuletzt: \(confirmReady.last)")
        confirm.tap()
        scrollToTop(app)
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

    // MARK: - U6: Menü (AC-15)

    /// U6 / AC-15: GIVEN Seed WHEN ···-Menü im Modus „Einkaufsweg“ THEN „Reihenfolge anpassen“ und
    /// „Gänge entfernen“ da, „Lidl-Vorlage übernehmen“ nicht; im Modus „Kategorie“ fehlt „Reihenfolge
    /// anpassen“.
    func testMenuEntriesInStoreWithStations() {
        let app = openedStore()
        choose("Einkaufsweg", in: app)

        openMenu(app)
        XCTAssertTrue(menuItem("store.menu.removeStations", in: app).waitForExistence(timeout: UITestWait.defaultTimeout),
                      "„Gänge entfernen“ fehlt im Menü")
        XCTAssertTrue(reorderItem(app).exists, "Im Einkaufsweg bleibt „Reihenfolge anpassen“")
        XCTAssertFalse(menuItem("store.menu.applyStationTemplate", in: app).exists, "Vorlage nur für Läden ohne Gänge")
        pickSort("Kategorie", in: app)

        openMenu(app)
        XCTAssertTrue(menuItem("store.menu.removeStations", in: app).waitForExistence(timeout: UITestWait.defaultTimeout),
                      "„Gänge entfernen“ fehlt im Menü (Kategorie)")
        XCTAssertFalse(reorderItem(app).exists, "Im Modus Kategorie eines Ladens mit Gängen ist die Reihenfolge fest")
        XCTAssertFalse(menuItem("store.menu.applyStationTemplate", in: app).exists)
        pickSort("Kategorie", in: app)
    }

    // MARK: - U7: Gänge entfernen und wieder übernehmen (AC-14)

    /// U7 / AC-14: GIVEN Seed WHEN „Gänge entfernen“ bestätigt THEN klassische Abschnitte (Salami
    /// unter „Fleisch & Wurst“), „Reihenfolge anpassen“ und „Lidl-Vorlage übernehmen“ wieder da;
    /// WHEN Vorlage erneut übernommen THEN wieder Gang-Abschnitte.
    func testRemoveAndReapplyStations() {
        let app = openedStore()
        choose("Kategorie", in: app)
        XCTAssertTrue(reveal(header("Kühltheke Fertiges", emoji: "🧊", app), in: app), "Ausgangslage: Gang-Abschnitt")
        scrollToTop(app)

        confirmMenuAction("store.menu.removeStations", confirmID: "store.stations.confirmRemove", in: app)

        let classic = app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS[c] %@ AND NOT (label ==[c] %@)", "Fleisch & Wurst", "Fleisch & Wurst")).firstMatch
        assertAbove(classic, "Überschrift Fleisch & Wurst", text("Salami", app), "Salami", in: app)
        scrollToTop(app)
        XCTAssertFalse(header("Kühltheke Fertiges", emoji: "🧊", app).exists, "Nach dem Entfernen keine Gang-Abschnitte")

        openMenu(app)
        XCTAssertTrue(menuItem("store.menu.applyStationTemplate", in: app).waitForExistence(timeout: UITestWait.defaultTimeout),
                      "„Lidl-Vorlage übernehmen“ fehlt nach dem Entfernen")
        XCTAssertTrue(reorderItem(app).exists, "„Reihenfolge anpassen“ wieder da")
        XCTAssertFalse(menuItem("store.menu.removeStations", in: app).exists, "„Gänge entfernen“ nur mit Gängen")
        pickSort("Kategorie", in: app)

        confirmMenuAction("store.menu.applyStationTemplate", confirmID: "store.stations.confirmApply", in: app)
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

        confirmMenuAction("store.menu.removeStations", confirmID: "store.stations.confirmRemove", in: app)
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
            _ = UITestWait.poll(timeout: 5, read: { text(item, app).frame }, done: { defer { previous = $0 }; return $0 == previous })
            UITestItemEditor.open(item, in: app)
            let row = app.descendants(matching: .any)["item.categoryRow"].firstMatch
            let label = row.waitForLabel(contains: "Fleisch & Wurst")
            XCTAssertTrue(label.matched, "\(item): Kategorie im Dialog: \(label.lastLabel)")
            app.buttons["Abbrechen"].firstMatch.tap()
            expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: row)
            waitForExpectations(timeout: UITestWait.defaultTimeout)
        }
    }
}
