import XCTest

/// Issue #98, Durchgang 2 (`docs/specs/ui-tests/replenishment-uitest.md`): der echte Durchlauf
/// Kaufhistorie → die App errechnet die Fälligkeit → Banner „Zeit zum Nachkaufen" bzw. Abschnitt
/// „Vielleicht auch fällig" → `+`, „Hab noch", „Nicht mehr vorschlagen", „Alle hinzufügen".
///
/// Der Seed (`-seedReplenishmentForUITests`) legt nur Rohdaten an: zwei Läden und rückdatierte
/// Käufe. Welche Vorschläge fällig sind, rechnet die App selbst. Beide Oberflächen gibt es nur im
/// Entwicklermodus, deshalb starten die Tests mit `-developerMode YES`.
final class ReplenishmentUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Der App-Group-Container überlebt den einzelnen Test (siehe CLAUDE.md): Läden, Seed-Käufe und
    /// die Vorschlags-Zustände in UserDefaults (Snoozes, Sperrliste, ...) wieder entfernen.
    override func tearDown() {
        super.tearDown()
        let cleaner = XCUIApplication()
        cleaner.launchArguments = ["-hasCompletedOnboarding", "YES", "-clearReplenishmentForUITests"]
        cleaner.launch()
        cleaner.terminate()
    }

    // MARK: - Hilfen

    private func tile(_ storeName: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(storeName),")).firstMatch
    }

    /// Startet die App und wartet auf eine Ladenkachel. Der Testläufer startet die App gelegentlich
    /// ganz ohne Launch-Argumente (Issue #105); ein zweiter Start trägt sie wieder.
    private func launch(_ app: XCUIApplication, waitingFor storeName: String) {
        app.launch()
        if !tile(storeName, in: app).waitForExistence(timeout: 15) {
            app.terminate()
            app.launch()
        }
        XCTAssertTrue(tile(storeName, in: app).waitForExistence(timeout: 15),
                      "Kachel „\(storeName)“ nicht auf dem Home-Screen gefunden")
    }

    private func launchSeeded(developerMode: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-seedReplenishmentForUITests"]
        if developerMode { app.launchArguments += ["-developerMode", "YES"] }
        launch(app, waitingFor: "Bannerladen")
        return app
    }

    /// Neustart ohne Seed (Käufe, Snoozes und Sperren bleiben im Container).
    private func relaunchWithoutSeed(_ app: XCUIApplication) -> XCUIApplication {
        app.terminate()
        let relaunched = XCUIApplication()
        relaunched.launchArguments += ["-hasCompletedOnboarding", "YES", "-developerMode", "YES"]
        launch(relaunched, waitingFor: "Bannerladen")
        return relaunched
    }

    private func openStore(_ storeName: String, in app: XCUIApplication) {
        let t = tile(storeName, in: app)
        XCTAssertTrue(t.waitForExistence(timeout: 15), "Kachel „\(storeName)“ nicht gefunden")
        expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: t)
        waitForExpectations(timeout: 5)
        t.tap()
    }

    private func closeStore(in app: XCUIApplication) {
        app.navigationBars.buttons.firstMatch.tap()
    }

    /// Ein SwiftUI-`Menu` trägt den Identifier je nach iOS-Version auf Button, Bild oder
    /// Container (Apple-Forum 690882, 713900, 760070).
    private func control(_ id: String, in app: XCUIApplication, timeout: TimeInterval = 10) -> XCUIElement {
        let candidates = [app.buttons[id], app.images[id], app.otherElements[id]]
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let hit = candidates.first(where: { $0.exists }) { return hit }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        } while Date() < deadline
        return candidates[0]
    }

    private func chooseMenuItem(_ menuID: String, _ label: String, in app: XCUIApplication) {
        let menu = control(menuID, in: app)
        XCTAssertTrue(menu.exists, "Menü „\(menuID)“ nicht gefunden")
        menu.tap()
        let item = app.buttons[label]
        XCTAssertTrue(item.waitForExistence(timeout: 5), "Menüpunkt „\(label)“ nicht gefunden")
        item.tap()
    }

    private func gone(_ element: XCUIElement, _ message: String) {
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        waitForExpectations(timeout: 10)
        XCTAssertFalse(element.exists, message)
    }

    // MARK: - Banner (Startbildschirm)

    /// AC-1, AC-2, AC-12: der Banner zeigt genau die beiden fälligen Banner-Artikel.
    func testBannerShowsDueItems() {
        let app = launchSeeded()
        XCTAssertTrue(app.staticTexts["Zeit zum Nachkaufen"].waitForExistence(timeout: 10), "Banner fehlt")
        for name in ["Bannerbutter", "Bannerquark"] {
            XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5), "„\(name)“ fehlt im Banner")
            XCTAssertTrue(control("replenish.add.\(name)", in: app).exists, "+ von „\(name)“ fehlt")
            XCTAssertTrue(control("replenish.menu.\(name)", in: app).exists, "Menü von „\(name)“ fehlt")
        }
        XCTAssertFalse(app.staticTexts["Listenreis"].exists, "Listen-Artikel gehören nicht in den Banner")
        XCTAssertFalse(app.staticTexts["Listennudeln"].exists, "Listen-Artikel gehören nicht in den Banner")
    }

    /// AC-3: `+` legt den Artikel in die Liste des Ladens und nimmt ihn aus dem Banner.
    func testBannerPlusAddsItemToStoreList() {
        let app = launchSeeded()
        let plus = control("replenish.add.Bannerbutter", in: app)
        XCTAssertTrue(plus.exists, "+ von „Bannerbutter“ fehlt")
        plus.tap()
        gone(app.staticTexts["Bannerbutter"], "„Bannerbutter“ steht noch im Banner")
        XCTAssertTrue(app.staticTexts["Bannerquark"].exists, "„Bannerquark“ muss im Banner bleiben")

        openStore("Bannerladen", in: app)
        XCTAssertTrue(app.staticTexts["Bannerbutter"].waitForExistence(timeout: 10),
                      "„Bannerbutter“ steht nicht in der Liste von „Bannerladen“")
    }

    /// AC-4: „Hab noch" blendet den Vorschlag aus, auch nach App-Neustart.
    func testBannerStillHaveItHidesSuggestion() {
        let app = launchSeeded()
        chooseMenuItem("replenish.menu.Bannerquark", "Hab noch", in: app)
        gone(app.staticTexts["Bannerquark"], "„Bannerquark“ steht nach „Hab noch“ noch im Banner")

        let relaunched = relaunchWithoutSeed(app)
        XCTAssertTrue(relaunched.staticTexts["Bannerbutter"].waitForExistence(timeout: 10),
                      "Gegenprobe: der Banner darf nach dem Neustart nicht leer sein")
        XCTAssertFalse(relaunched.staticTexts["Bannerquark"].exists,
                       "„Bannerquark“ kehrt nach dem Neustart zurück")
    }

    /// AC-5: „Nicht mehr vorschlagen" sperrt den Vorschlag dauerhaft.
    func testBannerBlockSurvivesRestart() {
        let app = launchSeeded()
        chooseMenuItem("replenish.menu.Bannerbutter", "Nicht mehr vorschlagen", in: app)
        gone(app.staticTexts["Bannerbutter"], "„Bannerbutter“ steht nach der Sperre noch im Banner")

        let relaunched = relaunchWithoutSeed(app)
        XCTAssertTrue(relaunched.staticTexts["Bannerquark"].waitForExistence(timeout: 10),
                      "Gegenprobe: „Bannerquark“ muss nach dem Neustart im Banner stehen")
        XCTAssertFalse(relaunched.staticTexts["Bannerbutter"].exists,
                       "„Bannerbutter“ kehrt nach dem Neustart zurück")
    }

    /// AC-6: „Alle hinzufügen" legt beide Banner-Artikel in „Bannerladen", nichts in „Listenladen".
    func testBannerAddAllAddsEverything() {
        let app = launchSeeded()
        let addAll = control("replenish.addAll", in: app)
        XCTAssertTrue(addAll.exists, "„Alle hinzufügen“ fehlt")
        addAll.tap()
        gone(app.staticTexts["Zeit zum Nachkaufen"], "Banner steht nach „Alle hinzufügen“ noch da")

        openStore("Bannerladen", in: app)
        XCTAssertTrue(app.staticTexts["Bannerbutter"].waitForExistence(timeout: 10), "„Bannerbutter“ fehlt in der Liste")
        XCTAssertTrue(app.staticTexts["Bannerquark"].exists, "„Bannerquark“ fehlt in der Liste")
        closeStore(in: app)

        openStore("Listenladen", in: app)
        XCTAssertTrue(app.staticTexts["Vielleicht auch fällig"].waitForExistence(timeout: 10),
                      "Listenladen-Ansicht nicht geöffnet")
        // Ein hinzugefügter Artikel hätte seine Vorschlagszeile (mit +) verloren.
        XCTAssertTrue(control("replenish.also.add.Listenreis", in: app).exists,
                      "„Listenreis“ darf nicht als offener Artikel hinzugefügt worden sein")
        XCTAssertTrue(control("replenish.also.add.Listennudeln", in: app).exists,
                      "„Listennudeln“ darf nicht als offener Artikel hinzugefügt worden sein")
    }

    // MARK: - Ladenliste („Vielleicht auch fällig")

    /// AC-7: der Abschnitt zeigt genau die beiden Listen-Artikel.
    func testAlsoDueShowsStoreItems() {
        let app = launchSeeded()
        openStore("Listenladen", in: app)
        XCTAssertTrue(app.staticTexts["Vielleicht auch fällig"].waitForExistence(timeout: 10),
                      "Abschnitt „Vielleicht auch fällig“ fehlt")
        for name in ["Listenreis", "Listennudeln"] {
            XCTAssertTrue(control("replenish.also.add.\(name)", in: app).exists, "+ von „\(name)“ fehlt")
            XCTAssertTrue(control("replenish.also.menu.\(name)", in: app).exists, "Menü von „\(name)“ fehlt")
        }
        XCTAssertFalse(app.staticTexts["Bannerbutter"].exists, "Banner-Artikel gehören nicht in diesen Laden")
    }

    /// AC-8: `+` macht den Vorschlag zum offenen Artikel derselben Liste.
    func testAlsoDuePlusAddsItem() {
        let app = launchSeeded()
        openStore("Listenladen", in: app)
        let plus = control("replenish.also.add.Listenreis", in: app)
        XCTAssertTrue(plus.exists, "+ von „Listenreis“ fehlt")
        plus.tap()
        gone(app.buttons["replenish.also.add.Listenreis"], "„Listenreis“ steht noch im Abschnitt")
        XCTAssertTrue(app.staticTexts["Listenreis"].waitForExistence(timeout: 5),
                      "„Listenreis“ steht nicht als offener Artikel in der Liste")
        XCTAssertTrue(control("replenish.also.add.Listennudeln", in: app).exists,
                      "„Listennudeln“ muss im Abschnitt bleiben")
    }

    /// AC-9: „Hab noch" blendet den Vorschlag aus, auch nach Schließen und Öffnen des Ladens.
    func testAlsoDueStillHaveItHidesSuggestion() {
        let app = launchSeeded()
        openStore("Listenladen", in: app)
        chooseMenuItem("replenish.also.menu.Listennudeln", "Hab noch", in: app)
        gone(app.buttons["replenish.also.add.Listennudeln"], "„Listennudeln“ steht nach „Hab noch“ noch im Abschnitt")
        XCTAssertTrue(control("replenish.also.add.Listenreis", in: app).exists, "„Listenreis“ muss unberührt bleiben")

        closeStore(in: app)
        openStore("Listenladen", in: app)
        XCTAssertTrue(control("replenish.also.add.Listenreis", in: app).exists,
                      "Gegenprobe: der Abschnitt darf nach dem Öffnen nicht leer sein")
        XCTAssertFalse(app.buttons["replenish.also.add.Listennudeln"].exists,
                       "„Listennudeln“ kehrt nach erneutem Öffnen zurück")
    }

    /// AC-10: „Nicht mehr vorschlagen" sperrt dauerhaft, auch nach App-Neustart.
    func testAlsoDueBlockSurvivesRestart() {
        let app = launchSeeded()
        openStore("Listenladen", in: app)
        chooseMenuItem("replenish.also.menu.Listenreis", "Nicht mehr vorschlagen", in: app)
        gone(app.buttons["replenish.also.add.Listenreis"], "„Listenreis“ steht nach der Sperre noch im Abschnitt")

        let relaunched = relaunchWithoutSeed(app)
        openStore("Listenladen", in: relaunched)
        XCTAssertTrue(control("replenish.also.add.Listennudeln", in: relaunched).exists,
                      "Gegenprobe: „Listennudeln“ muss nach dem Neustart wieder im Abschnitt stehen")
        XCTAssertFalse(relaunched.buttons["replenish.also.add.Listenreis"].exists,
                       "„Listenreis“ kehrt nach dem Neustart zurück")
    }

    // MARK: - Negativ-Kontrolle

    /// AC-11: ohne Entwicklermodus gibt es weder Banner noch Abschnitt.
    func testNothingWithoutDeveloperMode() {
        let app = launchSeeded(developerMode: false)
        // Dem Banner Zeit geben, falls er (fälschlich) erscheinen würde.
        XCTAssertFalse(app.staticTexts["Zeit zum Nachkaufen"].waitForExistence(timeout: 3),
                       "Banner erscheint ohne Entwicklermodus")
        openStore("Listenladen", in: app)
        XCTAssertFalse(app.staticTexts["Vielleicht auch fällig"].waitForExistence(timeout: 3),
                       "Abschnitt erscheint ohne Entwicklermodus")
    }
}
