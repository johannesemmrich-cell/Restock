import XCTest

/// Issue #98, Durchgang 1 (`docs/specs/ui-tests/shopping-route-learning-uitest.md`): der echte
/// Durchlauf Haken tippen → Einkauf ruht → Weg wird gelernt → Sortierung „Einkaufsweg".
///
/// `ShoppingRouteUITests` sät den fertig gelernten Weg und prüft nur die Anzeige. Hier startet der
/// Laden „Wegeladen" (Brot, Apfel, Gouda) **ohne** gelerntes Modell
/// (`-shoppingRouteNoLearnedModelForUITests`); gelernt wird ausschließlich durch die Haken in der
/// Liste. Die 30 Minuten Ruhe simuliert `-routeClockOffsetMinutesForUITests 31` beim Neustart.
///
/// Abgehakte Artikel stehen im Bereich „Erledigt". Damit die gelernte Sortierung an der Anzeige
/// ablesbar ist, nimmt der Test nach dem Neustart die Haken wieder zurück (der Einkauf ist dann
/// schon abgeschlossen und gelernt) und liest die Reihenfolge der offenen Liste.
final class ShoppingRouteLearningUITests: XCTestCase {

    /// Abstand zwischen zwei Haken, von der App vorgegeben (`-routeCheckOffStepSecondsForUITests`),
    /// nicht vom Tempo des Testläufers: `ShoppingRoute.bulkGap` ist 2 s, darunter gilt ein Haken als
    /// „zu Hause nachgetragen". Auf dem CI-Runner lagen drei Taps mehr als 2 s auseinander, der
    /// Test „zu Hause" lernte dort den Weg (PR #104).
    private let slowStep = "5"
    private let fastStep = "0.1"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Der App-Group-Container überlebt den einzelnen Test (siehe CLAUDE.md): Laden, Trip und
    /// gelerntes Modell von „Wegeladen" wieder entfernen.
    override func tearDown() {
        super.tearDown()
        let cleaner = XCUIApplication()
        cleaner.launchArguments = ["-hasCompletedOnboarding", "YES", "-clearShoppingRouteSeedForUITests"]
        cleaner.launch()
        cleaner.terminate()
    }

    private func openStore(_ app: XCUIApplication) {
        let tile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Wegeladen,")).firstMatch
        // Fehlstart ohne Launch-Argumente (#98, #105, #128): Gegenprobe und einmaliger Neustart im Helfer.
        UITestLaunch.start(app, expecting: tile, description: "Kachel „Wegeladen“")
        XCTAssertTrue(tile.waitForExistence(timeout: 15), "Wegeladen-Kachel nicht auf dem Home-Screen gefunden")
        expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: tile)
        waitForExpectations(timeout: 5)
        tile.tap()
        XCTAssertTrue(app.staticTexts["Gouda"].waitForExistence(timeout: 10), "Ladenliste nicht geöffnet")
    }

    /// App ohne gelerntes Modell starten und den Laden öffnen.
    private func openUnlearnedStore(checkOffStep: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES",
                                "-seedShoppingRouteForUITests", "-shoppingRouteNoLearnedModelForUITests",
                                "-routeCheckOffStepSecondsForUITests", checkOffStep]
        openStore(app)
        return app
    }

    /// Neustart ohne Seed, mit simulierten 31 Minuten Ruhe.
    private func relaunchAfterQuietPeriod(_ app: XCUIApplication) -> XCUIApplication {
        app.terminate()
        let relaunched = XCUIApplication()
        relaunched.launchArguments += ["-hasCompletedOnboarding", "YES", "-routeClockOffsetMinutesForUITests", "31"]
        openStore(relaunched)
        return relaunched
    }

    /// Der Haken-Knopf in der Zeile des Artikels (der Knopf hat kein eigenes Label).
    private func checkbox(of name: String, in app: XCUIApplication) -> XCUIElement {
        app.cells.containing(.staticText, identifier: name).buttons.firstMatch
    }

    private func check(_ names: [String], in app: XCUIApplication) {
        for name in names {
            let box = checkbox(of: name, in: app)
            XCTAssertTrue(box.waitForExistence(timeout: 5), "Haken von „\(name)“ nicht gefunden")
            box.tap()
        }
    }

    /// Nimmt alle Haken zurück, damit die offene Liste wieder alle drei Artikel zeigt.
    private func uncheckAll(in app: XCUIApplication) {
        for name in ["Brot", "Apfel", "Gouda"] {
            let box = checkbox(of: name, in: app)
            XCTAssertTrue(box.waitForExistence(timeout: 5), "Haken von „\(name)“ nicht gefunden")
            box.tap()
        }
    }

    private func visibleOrder(_ app: XCUIApplication) -> [String] {
        ["Brot", "Apfel", "Gouda"]
            .map { ($0, app.staticTexts[$0].firstMatch.frame.minY) }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
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

    /// AC-1, AC-3, AC-4, AC-6: langsames Abhaken im Laden lernt den Weg Gouda → Brot → Apfel.
    func testRouteIsLearnedFromSlowCheckOffs() {
        let app = openUnlearnedStore(checkOffStep: slowStep)
        waitForOrder(["Apfel", "Brot", "Gouda"], in: app,
                     "Ausgangslage: ohne gelerntes Modell gilt die feste Supermarkt-Reihenfolge")

        check(["Gouda", "Brot", "Apfel"], in: app)

        let relaunched = relaunchAfterQuietPeriod(app)
        uncheckAll(in: relaunched)
        waitForOrder(["Gouda", "Brot", "Apfel"], in: relaunched,
                     "Die Haken in der Reihenfolge Gouda, Brot, Apfel müssen den Einkaufsweg gelernt haben")
    }

    /// AC-5: drei Haken direkt hintereinander gelten als „zu Hause nachgetragen" und lernen nichts.
    func testFastCheckOffsAtHomeLearnNothing() {
        let app = openUnlearnedStore(checkOffStep: fastStep)
        waitForOrder(["Apfel", "Brot", "Gouda"], in: app,
                     "Ausgangslage: ohne gelerntes Modell gilt die feste Supermarkt-Reihenfolge")

        check(["Gouda", "Brot", "Apfel"], in: app)

        let relaunched = relaunchAfterQuietPeriod(app)
        uncheckAll(in: relaunched)
        waitForOrder(["Apfel", "Brot", "Gouda"], in: relaunched,
                     "Schnelles Abhaken zu Hause darf nichts lernen, die feste Reihenfolge bleibt")
    }
}
