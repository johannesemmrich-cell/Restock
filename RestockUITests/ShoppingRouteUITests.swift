import XCTest

/// Issue #79 (`docs/specs/models/shopping-route-order.md`): Sortierung pro Laden im ···-Menü.
///
/// Seed (`SmartCartApp.seedShoppingRouteForUITestsIfNeeded`): Laden „Wegeladen" mit „Brot",
/// „Apfel", „Gouda" in dieser Reihenfolge hinzugefügt, gelernter Weg Gouda → Brot → Apfel. Die
/// drei Modi ergeben damit drei verschiedene Reihenfolgen — und die gelernte Kategorie-
/// Reihenfolge (Milchprodukte, Backwaren, Obst & Gemüse) weicht von der festen Supermarkt-
/// Reihenfolge (Obst & Gemüse, Backwaren, Milchprodukte) ab.
///
/// Das Lernen selbst (30-Minuten-Fenster, Erkennung „zu Hause nachgetragen") hängt an echter Zeit
/// und ist in `RestockTests/ShoppingRouteTests.swift` abgedeckt; hier geht es um die Anzeige.
final class ShoppingRouteUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Der App-Group-Container überlebt den einzelnen Test (siehe CLAUDE.md).
    override func tearDown() {
        super.tearDown()
        let cleaner = XCUIApplication()
        cleaner.launchArguments = ["-hasCompletedOnboarding", "YES", "-clearShoppingRouteSeedForUITests"]
        cleaner.launch()
        cleaner.terminate()
    }

    private func openedStore() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-seedShoppingRouteForUITests"]
        app.launch()
        let tile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Wegeladen,")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 15), "Wegeladen-Kachel nicht auf dem Home-Screen gefunden")
        expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: tile)
        waitForExpectations(timeout: 5)
        tile.tap()
        XCTAssertTrue(app.staticTexts["Gouda"].waitForExistence(timeout: 10), "Ladenliste nicht geöffnet")
        return app
    }

    /// Reihenfolge der drei Artikel von oben nach unten.
    private func visibleOrder(_ app: XCUIApplication) -> [String] {
        ["Brot", "Apfel", "Gouda"]
            .map { ($0, app.staticTexts[$0].firstMatch.frame.minY) }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    private func choose(_ mode: String, in app: XCUIApplication) {
        let more = app.descendants(matching: .any)["storeDetail.moreMenu"].firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 5), "···-Menü fehlt")
        more.tap()
        let sortMenu = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Sortieren")).firstMatch
        XCTAssertTrue(sortMenu.waitForExistence(timeout: 5), "Menüpunkt „Sortieren“ fehlt")
        sortMenu.tap()
        let button = app.buttons[mode].firstMatch
        let option = button.waitForExistence(timeout: 5)
            ? button
            : app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", mode)).firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 5), "Sortieroption „\(mode)“ fehlt")
        option.tap()
    }

    private func waitForOrder(_ expected: [String], in app: XCUIApplication, _ message: String) {
        let deadline = Date().addingTimeInterval(5)
        var order = visibleOrder(app)
        while order != expected && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            order = visibleOrder(app)
        }
        XCTAssertEqual(order, expected, message)
    }

    func testRouteModeShowsLearnedOrder() {
        let app = openedStore()
        waitForOrder(["Gouda", "Brot", "Apfel"], in: app,
                     "Einkaufsweg muss die gelernte Reihenfolge zeigen, nicht die Hinzufüge- oder Kategorie-Reihenfolge")
    }

    func testSwitchingSortModesReordersList() {
        let app = openedStore()

        choose("Hinzugefügt", in: app)
        waitForOrder(["Brot", "Apfel", "Gouda"], in: app, "Hinzugefügt muss die Reihenfolge des Hinzufügens zeigen")

        choose("Kategorie", in: app)
        waitForOrder(["Gouda", "Brot", "Apfel"], in: app,
                     "Kategorie muss die Abschnitte in der gelernten Ladenreihenfolge zeigen, nicht in der festen")
        // Abschnittsüberschrift „🥛 Milchprodukte“. Nur über den Namen gesucht träfe der Test auch die
        // Kategorie-Zeile, die `ItemRow` in jedem Modus unter „Gouda“ zeigt (ohne Emoji).
        let header = app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@ AND label CONTAINS[c] %@", "🥛", "Milchprodukte")).firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 5), "Im Modus Kategorie fehlt die Abschnittsüberschrift")

        choose("Einkaufsweg", in: app)
        waitForOrder(["Gouda", "Brot", "Apfel"], in: app, "Zurück auf Einkaufsweg muss wieder die gelernte Reihenfolge zeigen")
        // Die Reihenfolge ist in beiden Modi gleich — `waitForOrder` kehrt also sofort zurück, bevor
        // die Liste neu gezeichnet ist. Deshalb aufs Verschwinden der Überschrift warten.
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: header)
        waitForExpectations(timeout: 5)
    }

    func testSortModeIsRememberedPerStore() {
        let app = openedStore()
        choose("Hinzugefügt", in: app)
        waitForOrder(["Brot", "Apfel", "Gouda"], in: app, "Hinzugefügt muss die Reihenfolge des Hinzufügens zeigen")

        // Neustart ohne Seed: der gewählte Modus muss erhalten bleiben.
        app.terminate()
        let relaunched = XCUIApplication()
        relaunched.launchArguments += ["-hasCompletedOnboarding", "YES"]
        relaunched.launch()
        let tile = relaunched.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Wegeladen,")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 15), "Wegeladen-Kachel nach Neustart nicht gefunden")
        tile.tap()
        XCTAssertTrue(relaunched.staticTexts["Gouda"].waitForExistence(timeout: 10), "Ladenliste nicht geöffnet")
        waitForOrder(["Brot", "Apfel", "Gouda"], in: relaunched, "Der gewählte Sortiermodus muss nach einem Neustart erhalten bleiben")
    }

    // MARK: - Eigene Kategorie (Issue #85)

    func testCreatingCustomCategoryFromItemDialog() {
        let app = openedStore()
        app.staticTexts["Gouda"].firstMatch.tap()

        let categoryRow = app.descendants(matching: .any)["item.categoryRow"].firstMatch
        XCTAssertTrue(categoryRow.waitForExistence(timeout: 5), "Zeile „Kategorie“ im Bearbeiten-Dialog fehlt")
        categoryRow.tap()

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5), "Suchfeld der Kategorieliste fehlt")
        search.tap()
        search.typeText("Kühltheke hinten")

        let create = app.descendants(matching: .any)["categoryPicker.create"].firstMatch
        XCTAssertTrue(create.waitForExistence(timeout: 5), "„… bei Wegeladen anlegen“ fehlt")
        create.tap()

        let save = app.buttons["Speichern"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 5), "Zurück im Dialog fehlt „Speichern“")
        save.tap()

        let caption = app.staticTexts["Kühltheke hinten"].firstMatch
        XCTAssertTrue(caption.waitForExistence(timeout: 5), "Gouda zeigt die neue Kategorie nicht")

        choose("Kategorie", in: app)
        let header = app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@ AND label CONTAINS[c] %@", "🧊", "Kühltheke hinten")).firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 5), "Die eigene Kategorie erscheint nicht als Abschnitt mit ihrem Emoji")
    }

    // MARK: - Von Hand verschieben (Issue #86)

    private func startReordering(_ app: XCUIApplication) {
        let more = app.descendants(matching: .any)["storeDetail.moreMenu"].firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 5), "···-Menü fehlt")
        more.tap()
        let reorder = app.buttons["Reihenfolge anpassen"].firstMatch
        XCTAssertTrue(reorder.waitForExistence(timeout: 5), "Menüpunkt „Reihenfolge anpassen“ fehlt")
        reorder.tap()
    }

    /// Zieht die Zeile `source` am Griff (rechter Rand) an den Anfang der Zeile `target`.
    private func drag(_ source: String, above target: String, in app: XCUIApplication) {
        let from = app.cells.containing(.any, identifier: "reorder.row.\(source)").firstMatch
        let to = app.cells.containing(.any, identifier: "reorder.row.\(target)").firstMatch
        XCTAssertTrue(from.waitForExistence(timeout: 5), "Zeile „\(source)“ im Verschiebe-Modus fehlt")
        XCTAssertTrue(to.waitForExistence(timeout: 5), "Zeile „\(target)“ im Verschiebe-Modus fehlt")
        from.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
            .press(forDuration: 0.6, thenDragTo: to.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.1)))
    }

    private func finishReordering(_ app: XCUIApplication) {
        let done = app.descendants(matching: .any)["storeDetail.reorderDone"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5), "„Fertig“ fehlt")
        done.tap()
        XCTAssertTrue(app.staticTexts["Gouda"].waitForExistence(timeout: 5), "Liste nach „Fertig“ nicht zurück")
    }

    func testDraggingItemInRouteModeChangesOrder() {
        let app = openedStore()
        waitForOrder(["Gouda", "Brot", "Apfel"], in: app, "Ausgangslage: gelernter Weg")

        startReordering(app)
        drag("Apfel", above: "Gouda", in: app)
        finishReordering(app)

        waitForOrder(["Apfel", "Gouda", "Brot"], in: app, "Apfel muss nach dem Verschieben vorne stehen")
    }

    func testDraggingCategorySectionChangesOrder() {
        let app = openedStore()
        choose("Kategorie", in: app)
        waitForOrder(["Gouda", "Brot", "Apfel"], in: app, "Ausgangslage: gelernte Kategorie-Reihenfolge")

        startReordering(app)
        drag("Obst & Gemüse", above: "Milchprodukte", in: app)
        finishReordering(app)

        waitForOrder(["Apfel", "Gouda", "Brot"], in: app, "Der Abschnitt Obst & Gemüse muss nach dem Verschieben vorne stehen")
    }
}
