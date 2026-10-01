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
        let header = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Milchprodukte")).firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 5), "Im Modus Kategorie fehlt die Abschnittsüberschrift")

        choose("Einkaufsweg", in: app)
        waitForOrder(["Gouda", "Brot", "Apfel"], in: app, "Zurück auf Einkaufsweg muss wieder die gelernte Reihenfolge zeigen")
        XCTAssertFalse(header.exists, "Im Modus Einkaufsweg darf es keine Kategorie-Abschnitte geben")
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
}
