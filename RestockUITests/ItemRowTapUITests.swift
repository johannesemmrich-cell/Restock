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

    private func openedStore(unpricedItem: Bool = false, seeded: Bool = true,
                             extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES"]
        if seeded { app.launchArguments += ["-seedShoppingRouteForUITests"] }
        if unpricedItem { app.launchArguments += ["-shoppingRouteUnpricedItemForUITests"] }
        app.launchArguments += extraArguments
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

    // AC-4: Wischen nach links, erledigte Zeile — „Bearbeiten“ neben „Löschen“, Tipp öffnet genau diesen Artikel
    func testSwipeLeftOnCompletedRowShowsEditAndDelete() {
        let app = openedStore()
        checkOff("Brot", in: app)
        swipePartially("Brot", in: app)

        let edit = app.buttons["Bearbeiten"].firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Wischen nach links auf einer erledigten Zeile muss „Bearbeiten“ zeigen")
        XCTAssertTrue(app.buttons["Löschen"].firstMatch.exists,
                      "„Löschen“ muss auf der erledigten Zeile weiterhin in der Wischleiste stehen")
        edit.tap()
        expectEditor(app, "„Bearbeiten“ auf der erledigten Zeile muss den Dialog öffnen")
        expectEditorShows("Brot", in: app)
    }

    // AC-4: Ein voller Wisch nach links löscht weiterhin (Löschen bleibt die äußere Aktion)
    func testFullSwipeLeftStillDeletes() {
        let app = openedStore()
        let target = row("Gouda", in: app)
        XCTAssertTrue(target.waitForExistence(timeout: UITestWait.defaultTimeout), "Zeile „Gouda“ nicht gefunden")
        let start = target.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        let end = target.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .fast, thenHoldForDuration: 0)

        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.staticTexts["Gouda"].firstMatch)
        waitForExpectations(timeout: UITestWait.defaultTimeout)
        expectNoEditor(app, "Ein voller Wisch darf nicht „Bearbeiten“ auslösen")
        XCTAssertTrue(app.staticTexts["Apfel"].exists && app.staticTexts["Brot"].exists,
                      "Nur „Gouda“ darf gelöscht sein")
    }

    // AC-5: Lang drücken auf eine offene Zeile — „Bearbeiten“ ist der erste Menüeintrag
    func testLongPressShowsEditAndOpensEditor() {
        let app = openedStore()
        longPress("Gouda", in: app)
        let edit = expectEditFirstInContextMenu(app)
        edit.tap()
        expectEditor(app, "„Bearbeiten“ im Menü muss den Dialog öffnen")
        expectEditorShows("Gouda", in: app)
    }

    // AC-5: Lang drücken auf eine erledigte Zeile — ebenfalls „Bearbeiten“ zuerst
    func testLongPressOnCompletedRowShowsEditFirst() {
        let app = openedStore()
        checkOff("Brot", in: app)
        longPress("Brot", in: app)
        let edit = expectEditFirstInContextMenu(app)
        edit.tap()
        expectEditor(app, "„Bearbeiten“ im Menü der erledigten Zeile muss den Dialog öffnen")
        expectEditorShows("Brot", in: app)
    }

    // AC-6: „Preis?“ öffnet den Dialog dieses Artikels mit Preisfeld und hakt nicht ab
    func testPricePromptOpensEditorWithoutChecking() {
        let app = openedStore(unpricedItem: true)
        // Sichtbar steht „Preis?“; für Bedienhilfen trägt der Knopf seit #160 das Label
        // „Preis unbekannt, antippen zum Eintragen“ (`price.prompt.accessibility`).
        let prompt = app.buttons["Preis unbekannt, antippen zum Eintragen"].firstMatch
        XCTAssertTrue(prompt.waitForExistence(timeout: UITestWait.defaultTimeout),
                      "„Preis?“ muss ein eigener Knopf in der Zeile sein")
        prompt.tap()
        expectEditor(app, "Ein Tipp auf „Preis?“ muss den Bearbeiten-Dialog öffnen")
        expectEditorShows("Wunderkraut", in: app)
        XCTAssertTrue(priceField(in: app).waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Der Dialog muss das Preisfeld „Preis (optional)“ zeigen")

        closeEditor(app)
        XCTAssertTrue(app.staticTexts["Wunderkraut"].waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Nach dem Schließen muss die Ladenliste wieder sichtbar sein")
        for name in ["Brot", "Apfel", "Gouda", "Wunderkraut"] {
            XCTAssertTrue(checkbox(of: name, in: app).exists, "Zeile „\(name)“ nicht gefunden")
            XCTAssertFalse(checkmark(of: name, in: app).exists, "„Preis?“ darf „\(name)“ nicht abhaken")
        }
    }

    // AC-9: Durchlauf als Nutzer mit Bildschirmfotos unter docs/artifacts/feat-233-abhaken-per-tipp/.
    // Die Live Activity wird nur fotografiert, nicht geprüft.
    func testWalkthroughWithScreenshots() {
        var app = openedStore()
        photo("durchlauf-01-ladenliste")

        tapName("Apfel", in: app)
        XCTAssertTrue(checkmark(of: "Apfel", in: app).waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Zeilentipp muss „Apfel“ abhaken")
        expectNoEditor(app, "Zeilentipp darf den Dialog nicht öffnen")
        photo("durchlauf-02-apfel-per-zeilentipp-abgehakt")

        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 2)
        photo("durchlauf-03-home-dynamic-island")
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.005))
            .press(forDuration: 0.1, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.7)))
        Thread.sleep(forTimeInterval: 2)
        photo("durchlauf-04-mitteilungszentrale-live-activity")
        app.activate()
        XCTAssertTrue(app.staticTexts["Apfel"].waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Zurück in der App muss die Ladenliste offen sein")

        tapName("Apfel", in: app)
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: checkmark(of: "Apfel", in: app))
        waitForExpectations(timeout: UITestWait.defaultTimeout)
        expectNoEditor(app, "Zeilentipp auf die erledigte Zeile darf den Dialog nicht öffnen")
        photo("durchlauf-05-apfel-per-zeilentipp-aufgehoben")

        checkOff("Brot", in: app)
        photo("durchlauf-06-brot-per-kaestchen-abgehakt")

        swipePartially("Gouda", in: app)
        XCTAssertTrue(app.buttons["Bearbeiten"].firstMatch.waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Wischen auf „Gouda“ muss „Bearbeiten“ zeigen")
        photo("durchlauf-07-gouda-wischen-links")
        closeSwipeActions(app)

        swipePartially("Brot", in: app)
        XCTAssertTrue(app.buttons["Bearbeiten"].firstMatch.waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Wischen auf die erledigte Zeile „Brot“ muss „Bearbeiten“ zeigen")
        photo("durchlauf-08-brot-erledigt-wischen-links")
        closeSwipeActions(app)

        longPress("Gouda", in: app)
        _ = expectEditFirstInContextMenu(app)
        photo("durchlauf-09-gouda-kontextmenue")

        app.terminate()
        app = openedStore(unpricedItem: true)
        let prompt = app.buttons["Preis unbekannt, antippen zum Eintragen"].firstMatch
        XCTAssertTrue(prompt.waitForExistence(timeout: UITestWait.defaultTimeout), "„Preis?“ fehlt")
        photo("durchlauf-10-wunderkraut-preis-fehlt")
        prompt.tap()
        expectEditor(app, "„Preis?“ muss den Dialog öffnen")
        XCTAssertTrue(priceField(in: app).waitForExistence(timeout: UITestWait.defaultTimeout), "Preisfeld fehlt")
        photo("durchlauf-11-preis-dialog")
    }

    // Adversary-Lücke: Abhaken per Zeilentipp lernt den Einkaufsweg wie das Kästchen.
    // Szenario wie `ShoppingRouteLearningUITests.testRouteIsLearnedFromSlowCheckOffs`, nur per Tipp auf den Namen.
    func testRouteIsLearnedFromRowTaps() {
        let app = openedStore(extraArguments: ["-shoppingRouteNoLearnedModelForUITests",
                                               "-routeCheckOffStepSecondsForUITests", "5"])
        waitForOrder(["Apfel", "Brot", "Gouda"], in: app,
                     "Ausgangslage: ohne gelerntes Modell gilt die feste Supermarkt-Reihenfolge")
        for name in ["Gouda", "Brot", "Apfel"] {
            tapName(name, in: app)
            XCTAssertTrue(checkmark(of: name, in: app).waitForExistence(timeout: UITestWait.defaultTimeout),
                          "Zeilentipp muss „\(name)“ abhaken")
        }

        app.terminate()
        let relaunched = openedStore(seeded: false, extraArguments: ["-routeClockOffsetMinutesForUITests", "31"])
        for name in ["Brot", "Apfel", "Gouda"] {
            tapName(name, in: relaunched)
            expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: checkmark(of: name, in: relaunched))
            waitForExpectations(timeout: UITestWait.defaultTimeout)
        }
        waitForOrder(["Gouda", "Brot", "Apfel"], in: relaunched,
                     "Die Zeilentipps in der Reihenfolge Gouda, Brot, Apfel müssen den Einkaufsweg gelernt haben")
    }

    // MARK: - Helfer

    private func waitForOrder(_ expected: [String], in app: XCUIApplication, _ message: String) {
        let visibleOrder = {
            ["Brot", "Apfel", "Gouda"].map { ($0, app.staticTexts[$0].firstMatch.frame.minY) }
                .sorted { $0.1 < $1.1 }.map(\.0)
        }
        let deadline = Date().addingTimeInterval(5)
        var order = visibleOrder()
        while order != expected && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            order = visibleOrder()
        }
        XCTAssertEqual(order, expected, message)
    }

    private func checkOff(_ name: String, in app: XCUIApplication) {
        let box = checkbox(of: name, in: app)
        XCTAssertTrue(box.waitForExistence(timeout: UITestWait.defaultTimeout), "Kästchen von „\(name)“ nicht gefunden")
        box.tap()
        XCTAssertTrue(checkmark(of: name, in: app).waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Vorbedingung: „\(name)“ ist abgehakt")
    }

    /// Teilweise nach links ziehen, damit die Wischleiste stehen bleibt und der volle Wisch nicht löscht.
    private func swipePartially(_ name: String, in app: XCUIApplication) {
        let target = row(name, in: app)
        XCTAssertTrue(target.waitForExistence(timeout: UITestWait.defaultTimeout), "Zeile „\(name)“ nicht gefunden")
        let start = target.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        let end = target.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: end)
    }

    /// Tipp auf die Kopfzelle des Ladens (keine Artikelzeile) schließt eine offene Wischleiste.
    private func closeSwipeActions(_ app: XCUIApplication) {
        app.collectionViews.firstMatch.cells.element(boundBy: 0).tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.buttons["Bearbeiten"].firstMatch)
        waitForExpectations(timeout: UITestWait.defaultTimeout)
    }

    private func longPress(_ name: String, in app: XCUIApplication) {
        let text = app.staticTexts[name].firstMatch
        let ready = text.waitUntilHittable()
        XCTAssertTrue(ready.matched, "Zeile „\(name)“ nicht antippbar — zuletzt: \(ready.last)")
        text.press(forDuration: 1.0)
    }

    /// Das Kontextmenü ist eine eigene Liste (CollectionView) neben der Ladenliste; „Bearbeiten“
    /// (`item.action.edit`) muss darin der oberste Eintrag sein.
    private func expectEditFirstInContextMenu(_ app: XCUIApplication) -> XCUIElement {
        let edit = app.buttons.matching(identifier: "item.action.edit").firstMatch
        let ready = edit.waitUntilHittable()
        XCTAssertTrue(ready.matched, "Lang drücken muss „Bearbeiten“ im Menü zeigen — zuletzt: \(ready.last)")
        XCTAssertEqual(edit.label, "Bearbeiten")
        let menu = app.collectionViews.containing(.button, identifier: "item.action.edit").firstMatch
        let entries = menu.buttons.allElementsBoundByIndex.filter { $0.exists && $0.frame.height > 0 }
        XCTAssertFalse(entries.isEmpty, "Menüeinträge nicht gefunden")
        let topY = entries.map { $0.frame.minY }.min() ?? .infinity
        XCTAssertEqual(edit.frame.minY, topY, accuracy: 0.5,
                       "„Bearbeiten“ muss der erste Eintrag sein — Einträge: \(entries.map { "\($0.label)@\($0.frame.minY)" })")
        print("ItemRowTap: Kontextmenü-Einträge \(entries.map { $0.label })")
        return edit
    }

    private func expectEditorShows(_ name: String, in app: XCUIApplication) {
        XCTAssertTrue(app.textFields.matching(NSPredicate(format: "value == %@", name)).firstMatch
            .waitForExistence(timeout: UITestWait.defaultTimeout), "Der Dialog muss „\(name)“ zeigen")
    }

    private func priceField(in app: XCUIApplication) -> XCUIElement {
        app.textFields.matching(NSPredicate(format: "placeholderValue == %@ OR label == %@",
                                            "Preis (optional)", "Preis (optional)")).firstMatch
    }

    private func closeEditor(_ app: XCUIApplication) {
        let cancel = app.buttons["Abbrechen"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: UITestWait.defaultTimeout), "„Abbrechen“ im Dialog fehlt")
        cancel.tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.buttons["Speichern"].firstMatch)
        waitForExpectations(timeout: UITestWait.defaultTimeout)
    }

    /// Vollbild (inkl. Statusleiste/Dynamic Island) als Anhang und als PNG im Artefaktordner.
    private func photo(_ name: String, filePath: String = #filePath) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let dir = URL(fileURLWithPath: filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/artifacts/feat-233-abhaken-per-tipp", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try shot.pngRepresentation.write(to: dir.appendingPathComponent("\(name).png"))
        } catch {
            print("DURCHLAUF: \(name).png nicht geschrieben (\(error)); nur als Anhang vorhanden")
        }
    }
}
