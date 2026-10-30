import XCTest

/// Issue #233 (`docs/specs/views/item-row-tap-to-check.md`): Ein Tipp auf die Artikelzeile hakt ab,
/// Bearbeiten liegt in Wischen, Lang drücken und „Preis?“.
///
/// Seed: `-seedShoppingRouteForUITests` (Laden „Wegeladen“ mit „Brot“, „Apfel“, „Gouda“, alle offen).
/// Das Kästchen hat im offenen Zustand kein Label; abgehakt trägt es die Kennung `checkmark` (Label „Ausgewählt“).
final class ItemRowTapUITests: XCTestCase {

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

    private func openedStore(unpricedItem: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-seedShoppingRouteForUITests"]
        if unpricedItem { app.launchArguments += ["-shoppingRouteUnpricedItemForUITests"] }
        let tile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Wegeladen,")).firstMatch
        UITestLaunch.start(app, expecting: tile, description: "Kachel „Wegeladen“")
        tile.tap()
        XCTAssertTrue(app.staticTexts["Apfel"].waitForExistence(timeout: UITestWait.defaultTimeout), "Ladenliste nicht geöffnet")
        return app
    }

    private func row(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.cells.containing(.staticText, identifier: name).firstMatch
    }

    private func checkbox(of name: String, in app: XCUIApplication) -> XCUIElement {
        app.cells.containing(.staticText, identifier: name).buttons.firstMatch
    }

    private func checkmark(of name: String, in app: XCUIApplication) -> XCUIElement {
        app.cells.containing(.staticText, identifier: name).buttons["checkmark"].firstMatch
    }

    private func expectNoEditor(_ app: XCUIApplication, _ message: String) {
        XCTAssertFalse(app.buttons["Speichern"].waitForExistence(timeout: 2), message)
    }

    private func expectEditor(_ app: XCUIApplication, _ message: String) {
        XCTAssertTrue(app.buttons["Speichern"].waitForExistence(timeout: UITestWait.defaultTimeout), message)
    }

    private func tapName(_ name: String, in app: XCUIApplication) {
        let text = app.staticTexts[name].firstMatch
        let ready = text.waitUntilHittable()
        XCTAssertTrue(ready.matched, "Zeile „\(name)“ nicht antippbar — zuletzt: \(ready.last)")
        text.tap()
    }

    // AC-1
    func testTapOnRowChecksItemWithoutOpeningEditor() {
        let app = openedStore()
        XCTAssertFalse(checkmark(of: "Apfel", in: app).exists, "Vorbedingung: Apfel ist offen")
        tapName("Apfel", in: app)
        XCTAssertTrue(checkmark(of: "Apfel", in: app).waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Ein Tipp auf die Zeile muss „Apfel“ abhaken")
        expectNoEditor(app, "Ein Tipp auf die Zeile darf den Bearbeiten-Dialog nicht öffnen")
    }

    // AC-2
    func testTapOnCompletedRowUnchecksItem() {
        let app = openedStore()
        let box = checkbox(of: "Apfel", in: app)
        XCTAssertTrue(box.waitForExistence(timeout: UITestWait.defaultTimeout), "Kästchen von „Apfel“ nicht gefunden")
        box.tap()
        XCTAssertTrue(checkmark(of: "Apfel", in: app).waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Vorbedingung: Apfel ist abgehakt")

        tapName("Apfel", in: app)
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: checkmark(of: "Apfel", in: app))
        waitForExpectations(timeout: UITestWait.defaultTimeout)
        expectNoEditor(app, "Ein Tipp auf eine erledigte Zeile darf den Bearbeiten-Dialog nicht öffnen")
    }

    // AC-3: genau eine Änderung je Tipp, in beide Richtungen
    func testTapOnCheckboxTogglesExactlyOnce() {
        let app = openedStore()
        let box = checkbox(of: "Brot", in: app)
        XCTAssertTrue(box.waitForExistence(timeout: UITestWait.defaultTimeout), "Kästchen von „Brot“ nicht gefunden")

        box.tap()
        XCTAssertTrue(checkmark(of: "Brot", in: app).waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Erster Tipp aufs Kästchen muss abhaken")
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        XCTAssertTrue(checkmark(of: "Brot", in: app).exists,
                      "Der Haken darf nach einem Tipp nicht von allein wieder verschwinden (Doppelauslösung)")

        checkbox(of: "Brot", in: app).tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: checkmark(of: "Brot", in: app))
        waitForExpectations(timeout: UITestWait.defaultTimeout)
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        XCTAssertFalse(checkmark(of: "Brot", in: app).exists,
                       "Zweiter Tipp aufs Kästchen muss den Haken aufheben und es bleibt dabei")
        expectNoEditor(app, "Ein Tipp aufs Kästchen darf den Dialog nie öffnen")
    }

    // AC-7 (automatisierbarer Teil)
    func testCheckboxIsExposedAsButton() {
        let app = openedStore()
        let box = checkbox(of: "Gouda", in: app)
        XCTAssertTrue(box.waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Das Kästchen muss als Knopf in der Zeile erreichbar sein")
        XCTAssertEqual(box.elementType, .button)
    }

    // AC-4: Wischen nach links, offene Zeile (teilweise ziehen, damit der volle Wisch nicht löscht)
    func testSwipeLeftShowsEditAndOpensEditor() {
        let app = openedStore()
        let target = row("Gouda", in: app)
        XCTAssertTrue(target.waitForExistence(timeout: UITestWait.defaultTimeout), "Zeile „Gouda“ nicht gefunden")
        let start = target.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        let end = target.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: end)

        let edit = app.buttons["Bearbeiten"].firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Wischen nach links muss „Bearbeiten“ zeigen")
        XCTAssertTrue(app.buttons["Löschen"].firstMatch.exists, "„Löschen“ muss weiterhin in der Wischleiste stehen")
        edit.tap()
        expectEditor(app, "„Bearbeiten“ muss den Dialog öffnen")
        XCTAssertTrue(app.textFields.matching(NSPredicate(format: "value == %@", "Gouda")).firstMatch
            .waitForExistence(timeout: UITestWait.defaultTimeout), "Der Dialog muss „Gouda“ zeigen")
    }

    // AC-5: Lang drücken
    func testLongPressShowsEditAndOpensEditor() {
        let app = openedStore()
        let text = app.staticTexts["Gouda"].firstMatch
        let ready = text.waitUntilHittable()
        XCTAssertTrue(ready.matched, "Zeile „Gouda“ nicht antippbar — zuletzt: \(ready.last)")
        text.press(forDuration: 1.0)

        let edit = app.buttons.matching(
            NSPredicate(format: "identifier == %@ OR label == %@", "item.action.edit", "Bearbeiten")).firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Lang drücken muss „Bearbeiten“ im Menü zeigen")
        edit.tap()
        expectEditor(app, "„Bearbeiten“ im Menü muss den Dialog öffnen")
    }

    // AC-6: „Preis?“ öffnet den Dialog und hakt nicht ab
    func testPricePromptOpensEditorWithoutChecking() {
        let app = openedStore(unpricedItem: true)
        let prompt = app.buttons["Preis?"].firstMatch
        XCTAssertTrue(prompt.waitForExistence(timeout: UITestWait.defaultTimeout),
                      "„Preis?“ muss ein eigener Knopf in der Zeile sein")
        prompt.tap()
        expectEditor(app, "Ein Tipp auf „Preis?“ muss den Bearbeiten-Dialog öffnen")
        for name in ["Brot", "Apfel", "Gouda", "Wunderkraut"] {
            XCTAssertFalse(checkmark(of: name, in: app).exists, "„Preis?“ darf „\(name)“ nicht abhaken")
        }
    }
}
