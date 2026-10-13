import XCTest

/// Laden-Einrichtung (`StoreSetupView`): deaktivieren, aktivieren, löschen, eigenen Laden anlegen,
/// Besuchshäufigkeit ändern, Reihenfolge ziehen (Issue #98, Durchgang 6).
///
/// Seed: `-seedQuickAddAssignmentForUITests` legt „Lidl“ (2x pro Woche) und „dm“ (1x pro Woche) an, beide
/// mit `sortIndex` 0 — die Startreihenfolge ist daher nicht festgelegt; der Reihenfolge-Test liest sie
/// vorher und prüft die Umkehrung. Löschen läuft nur gegen gesäte Läden im Test-Simulator.
///
/// Zeilenschalter: per S8 bedient (Aus und wieder An). Reihenfolge: `onMove` speichert seit dem Fix mit
/// PO-Wort vom 2026-10-13 sofort; S6 beendet die App deshalb direkt, ohne Umweg über den Hintergrund.
/// Rückfrage „Markt löschen?“: erscheint auf dem iPhone als Einblendmenü ohne „Abbrechen“-Knopf;
/// Abbrechen heißt, außerhalb tippen (S3).
///
/// Offene Grenzen: „Teilen beenden“ beim Löschen geteilter Läden (CloudKit), Emoji-Eingabe, Farbwähler,
/// Tagesmitteilung und Siri/Widget (Punkte 5/6 aus #98) sind nicht geprüft.
final class StoreSetupUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Der App-Group-Container überlebt den einzelnen Test (siehe CLAUDE.md).
    override func tearDown() {
        super.tearDown()
        let cleaner = XCUIApplication()
        cleaner.launchArguments = ["-hasCompletedOnboarding", "YES", "-clearQuickAddAssignmentSeedForUITests"]
        cleaner.launch()
        cleaner.terminate()
    }

    // MARK: - Hilfen

    private func launchedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-seedQuickAddAssignmentForUITests"]
        UITestLaunch.start(app, expecting: tile("Lidl", in: app), description: "Kachel „Lidl“")
        return app
    }

    private func tile(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name),")).firstMatch
    }

    /// Gemessen (Lauf 2): nach einem Kaltstart von ca. 18 s kam der Tipp auf „Verwalten“ einmal nicht an,
    /// Ursache unbekannt. Deshalb: höchstens ein zweiter Tipp, mit Messzeile — keine stille Abhilfe.
    private func openSetup(_ app: XCUIApplication, function: String = #function) {
        let manage = app.buttons["Verwalten"]
        let edit = app.buttons["Bearbeiten"]
        let ready = manage.waitUntilHittable()
        XCTAssertTrue(ready.matched, "„Verwalten“ nicht antippbar — zuletzt: \(ready.last)")
        let firstTap = Date()
        manage.tap()
        if !edit.waitForExistence(timeout: 10) {
            let again = manage.waitUntilHittable(timeout: 0)
            if again.matched {
                let load = UITestLaunch.loadAverage().map {
                    String(format: "%.1f/%.1f/%.1f", locale: Locale(identifier: "en_US_POSIX"), $0.0, $0.1, $0.2)
                } ?? "unbekannt"
                let since = String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"),
                                   Date().timeIntervalSince(firstTap))
                NSLog("%@", "StoreSetupUITests: zweiter Tipp auf Verwalten nötig — seit erstem Tipp \(since) s, "
                      + "Verwalten: \(again.last), Last \(load) [\(function)]")
                manage.tap()
            }
        }
        XCTAssertTrue(edit.waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Laden-Einrichtung nicht geöffnet")
    }

    /// Kein Schließen-Knopf: von der Titelzeile des Sheets nach unten ziehen (Muster `RestockUITests`).
    private func closeSetup(_ app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
            .press(forDuration: 0.2, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
    }

    /// Zeilen der Liste mit diesem Namen. Eine weggewischte Zeile hinterlässt in der Hierarchie eine
    /// Geisterzeile links außerhalb (x < 0, gemessen); sie zählt nicht.
    private func rows(_ name: String, in app: XCUIApplication) -> [XCUIElement] {
        app.cells.containing(.staticText, identifier: name).allElementsBoundByIndex
            .filter { $0.exists && $0.frame.minX >= 0 && $0.frame.width > 0 }
    }

    /// Zeile im Abschnitt „Aktiv“ (über der Überschrift „Inaktiv“) bzw. „Inaktiv“; fehlt sie, ein nicht
    /// vorhandenes Element (`exists == false`).
    private func row(_ name: String, in app: XCUIApplication, inactive: Bool = false) -> XCUIElement {
        let header = app.staticTexts["Inaktiv"]
        let headerY = header.exists ? header.frame.minY : CGFloat.greatestFiniteMagnitude
        let match = rows(name, in: app).first { inactive ? $0.frame.minY > headerY : $0.frame.minY < headerY }
        return match ?? app.cells["keine-Zeile-\(name)"]
    }

    /// Zeilennamen der Liste von oben nach unten (nur Zellen; die Startseite dahinter liefert Mehrfachtreffer).
    private func rowNames(_ app: XCUIApplication, among names: [String]) -> [String] {
        app.cells.staticTexts.allElementsBoundByIndex
            .filter { $0.exists && $0.frame.minX > 0 && names.contains($0.label) }
            .sorted { $0.frame.minY < $1.frame.minY }
            .map { $0.label }
    }

    private func waitForRows(_ app: XCUIApplication, among names: [String], toBe expected: [String],
                             _ message: String) {
        let result = UITestWait.poll(timeout: UITestWait.defaultTimeout,
                                     read: { self.rowNames(app, among: names) }, done: { $0 == expected })
        XCTAssertTrue(result.matched, "\(message) — erwartet \(expected), zuletzt \(result.last)")
    }

    /// Gemessen (Runde 2, 3 von 5 Läufen): die erste Wischgeste nach dem Kaltstart, 2–5 s nach dem Öffnen
    /// des Sheets, kam nicht an — der Knopf erschien nie. Ursache unbekannt. Deshalb: vorher warten, bis
    /// die Zeile stillsteht, und höchstens eine zweite Geste, mit Messzeile — keine stille Abhilfe.
    private func swipeAndTap(_ action: String, on r: XCUIElement, in app: XCUIApplication,
                             function: String = #function) {
        XCTAssertTrue(r.waitForExistence(timeout: UITestWait.defaultTimeout), "Zeile für „\(action)“ fehlt")
        var previous: CGRect?
        _ = UITestWait.poll(timeout: 4, read: { () -> Bool in
            let current = r.frame
            defer { previous = current }
            return previous == current
        }, done: { $0 })
        let firstSwipe = Date()
        r.swipeLeft()
        let button = app.buttons[action]
        let early = button.waitUntilHittable(timeout: 4)
        if !early.matched {
            let load = UITestLaunch.loadAverage().map {
                String(format: "%.1f/%.1f/%.1f", locale: Locale(identifier: "en_US_POSIX"), $0.0, $0.1, $0.2)
            } ?? "unbekannt"
            let since = String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"),
                               Date().timeIntervalSince(firstSwipe))
            NSLog("%@", "StoreSetupUITests: zweite Wischgeste für \(action) nötig — seit erster Geste \(since) s, "
                  + "Knopf: \(early.last), Last \(load) [\(function)]")
            r.swipeLeft()
        }
        let ready = button.waitUntilHittable()
        XCTAssertTrue(ready.matched, "Wischknopf „\(action)“ nicht antippbar — zuletzt: \(ready.last)")
        button.tap()
    }

    private func waitForGone(_ element: XCUIElement, _ message: String) {
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        waitForExpectations(timeout: UITestWait.defaultTimeout)
        XCTAssertFalse(element.exists, message)
    }

    private func deactivate(_ name: String, in app: XCUIApplication) {
        swipeAndTap("Deaktivieren", on: row(name, in: app), in: app)
        XCTAssertTrue(app.staticTexts["Inaktiv"].waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Abschnitt „Inaktiv“ erscheint nicht")
    }

    // MARK: - S1 / S2

    func testDeactivateBySwipeMovesStoreToInactiveAndRemovesTile() {
        let app = launchedApp()
        openSetup(app)
        deactivate("Lidl", in: app)
        XCTAssertTrue(row("Lidl", in: app, inactive: true).exists, "„Lidl“ steht nicht unter „Inaktiv“")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "S1-nach-Deaktivieren"
        shot.lifetime = .keepAlways
        add(shot)
        XCTAssertFalse(row("Lidl", in: app).exists, "„Lidl“ steht noch unter „Aktiv“")
        XCTAssertTrue(row("dm", in: app).exists, "„dm“ ist nicht mehr unter „Aktiv“")
        closeSetup(app)
        waitForGone(tile("Lidl", in: app), "Kachel „Lidl“ steht nach dem Deaktivieren noch auf der Startseite")
        XCTAssertTrue(tile("dm", in: app).waitUntilHittable().matched, "Kachel „dm“ ist verschwunden")
    }

    func testActivateBySwipeRestoresStoreAndTile() {
        let app = launchedApp()
        openSetup(app)
        deactivate("Lidl", in: app)
        swipeAndTap("Aktivieren", on: row("Lidl", in: app, inactive: true), in: app)
        waitForGone(app.staticTexts["Inaktiv"], "Abschnitt „Inaktiv“ bleibt trotz Aktivieren")
        // Ohne Überschrift „Inaktiv“ zählt jede sichtbare Zeile als „Aktiv“.
        XCTAssertTrue(row("Lidl", in: app).exists, "„Lidl“ steht nach dem Aktivieren nicht wieder unter „Aktiv“")
        closeSetup(app)
        let ready = tile("Lidl", in: app).waitUntilHittable()
        XCTAssertTrue(ready.matched, "Kachel „Lidl“ fehlt nach dem Aktivieren — zuletzt: \(ready.last)")
    }

    // MARK: - S8

    /// AC-10: Der Schalter in der Zeile (je Zelle ein `Switch`, `value` „1“/„0“) deaktiviert und aktiviert.
    func testRowSwitchDeactivatesAndActivates() {
        let app = launchedApp()
        openSetup(app)
        let activeSwitch = row("Lidl", in: app).switches.firstMatch
        XCTAssertTrue(activeSwitch.waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Schalter in der Zeile „Lidl“ fehlt")
        XCTAssertEqual(activeSwitch.value as? String, "1", "Schalter „Lidl“ steht vor dem Tipp nicht auf an")
        activeSwitch.tap()
        XCTAssertTrue(app.staticTexts["Inaktiv"].waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Abschnitt „Inaktiv“ erscheint nach dem Schalter nicht")
        XCTAssertTrue(row("Lidl", in: app, inactive: true).exists, "„Lidl“ steht nicht unter „Inaktiv“")
        XCTAssertFalse(row("Lidl", in: app).exists, "„Lidl“ steht noch unter „Aktiv“")
        closeSetup(app)
        waitForGone(tile("Lidl", in: app), "Kachel „Lidl“ steht nach dem Ausschalten noch auf der Startseite")

        openSetup(app)
        let inactiveRow = row("Lidl", in: app, inactive: true)
        XCTAssertTrue(inactiveRow.exists, "„Lidl“ steht nach erneutem Öffnen nicht unter „Inaktiv“")
        let inactiveSwitch = inactiveRow.switches.firstMatch
        XCTAssertTrue(inactiveSwitch.waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Schalter in der inaktiven Zeile „Lidl“ fehlt")
        XCTAssertEqual(inactiveSwitch.value as? String, "0", "Schalter „Lidl“ steht unter „Inaktiv“ nicht auf aus")
        inactiveSwitch.tap()
        waitForGone(app.staticTexts["Inaktiv"], "Abschnitt „Inaktiv“ bleibt nach dem Einschalten")
        XCTAssertTrue(row("Lidl", in: app).exists, "„Lidl“ steht nach dem Einschalten nicht wieder unter „Aktiv“")
        closeSetup(app)
        let ready = tile("Lidl", in: app).waitUntilHittable()
        XCTAssertTrue(ready.matched, "Kachel „Lidl“ fehlt nach dem Einschalten — zuletzt: \(ready.last)")
    }

    // MARK: - S3

    func testDeleteInactiveStoreAsksFirstCancelKeepsConfirmRemoves() {
        let app = launchedApp()
        openSetup(app)
        deactivate("dm", in: app)

        swipeAndTap("Löschen", on: row("dm", in: app, inactive: true), in: app)
        XCTAssertTrue(app.staticTexts["Markt löschen?"].waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Rückfrage „Markt löschen?“ erscheint nicht")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "\"dm\"")).firstMatch
                        .exists, "Rückfrage nennt „dm“ nicht")
        // Auf dem iPhone erscheint die Rückfrage als Einblendmenü ohne sichtbaren „Abbrechen“-Knopf (gemessen):
        // Abbrechen heißt, außerhalb des Menüs tippen.
        app.otherElements["PopoverDismissRegion"].coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5)).tap()
        waitForGone(app.staticTexts["Markt löschen?"], "Rückfrage bleibt nach „Abbrechen“")
        XCTAssertTrue(row("dm", in: app, inactive: true).exists, "„dm“ ist nach „Abbrechen“ verschwunden")

        swipeAndTap("Löschen", on: row("dm", in: app, inactive: true), in: app)
        XCTAssertTrue(app.staticTexts["Markt löschen?"].waitForExistence(timeout: UITestWait.defaultTimeout))
        app.sheets.buttons["Löschen"].firstMatch.tap()
        // Nicht `row(…inactive: true)`: mit dem letzten inaktiven Laden verschwindet auch die Überschrift
        // „Inaktiv“, und zwischen deren exists und frame scheitert die Abfrage (gemessen, Lauf 1).
        waitForGone(app.staticTexts["Inaktiv"], "Abschnitt „Inaktiv“ bleibt ohne inaktive Läden")
        XCTAssertTrue(rows("dm", in: app).isEmpty, "„dm“ steht nach dem Löschen noch in der Liste")
        closeSetup(app)
        waitForGone(tile("dm", in: app), "Kachel „dm“ steht nach dem Löschen noch auf der Startseite")
        XCTAssertTrue(tile("Lidl", in: app).waitUntilHittable().matched, "Kachel „Lidl“ fehlt")
    }

    // MARK: - S4

    func testAddCustomStoreCreatesTileAndBlocksEmptyName() {
        let app = launchedApp()
        openSetup(app)
        app.buttons["Eigenen Laden hinzufügen"].tap()
        let add = app.navigationBars["Eigenen Laden hinzufügen"].buttons["Hinzufügen"]
        XCTAssertTrue(add.waitForExistence(timeout: UITestWait.defaultTimeout), "„Hinzufügen“ fehlt")
        XCTAssertFalse(add.isEnabled, "„Hinzufügen“ ist bei leerem Namen nicht gesperrt")

        let field = app.textFields["Name des Ladens"]
        field.tap()
        expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: field)
        waitForExpectations(timeout: UITestWait.defaultTimeout)
        field.typeText("Testmarkt")
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: add)
        waitForExpectations(timeout: UITestWait.defaultTimeout)
        add.tap()

        XCTAssertTrue(row("Testmarkt", in: app).waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Zeile „Testmarkt“ fehlt in der Liste")
        closeSetup(app)
        let t = tile("Testmarkt", in: app)
        let ready = t.waitUntilHittable()
        XCTAssertTrue(ready.matched, "Kachel „Testmarkt“ fehlt — zuletzt: \(ready.last)")
        XCTAssertTrue(t.label.contains("1x pro Woche"), "Vorbelegung „1x pro Woche“ fehlt: \(t.label)")
    }

    // MARK: - S5

    func testChangingVisitFrequencyUpdatesTileLabel() {
        let app = launchedApp()
        openSetup(app)
        let picker = row("Lidl", in: app).buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Besuche pro Woche")).firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: UITestWait.defaultTimeout), "Picker „Besuche pro Woche“ fehlt")
        picker.tap()
        app.buttons["3x pro Woche"].tap()
        XCTAssertTrue(row("Lidl", in: app).staticTexts["3x pro Woche"].waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Untertitel der Zeile zeigt „3x pro Woche“ nicht")
        closeSetup(app)
        let t = tile("Lidl", in: app)
        let result = t.waitForLabel(contains: "3x pro Woche")
        XCTAssertTrue(result.matched, "Kachel zeigt „3x pro Woche“ nicht — zuletzt: \(result.lastLabel)")
        XCTAssertFalse(t.label.contains("2x pro Woche"), "Alte Stufe steht noch im Label: \(t.label)")
    }

    // MARK: - S6

    func testDragReorderingReversesStoresAndSurvivesRestart() {
        let names = ["Lidl", "dm"]
        let app = launchedApp()
        openSetup(app)
        let before = rowNames(app, among: names)
        XCTAssertEqual(Set(before), Set(names), "Beide Läden müssen in „Aktiv“ stehen: \(before)")

        app.buttons["Bearbeiten"].tap()
        let handles = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "anordnen"))
        let first = handles.element(boundBy: 0)
        XCTAssertTrue(first.waitForExistence(timeout: UITestWait.defaultTimeout), "Verschiebegriff fehlt")
        let second = handles.element(boundBy: 1)
        XCTAssertTrue(second.exists, "Zweiter Verschiebegriff fehlt")
        let target = second.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .withOffset(CGVector(dx: 0, dy: 20))
        first.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.8, thenDragTo: target, withVelocity: .slow, thenHoldForDuration: 0.5)
        app.buttons["Fertig"].tap()

        let reversed = Array(before.reversed())
        waitForRows(app, among: names, toBe: reversed, "Reihenfolge in der Liste nach dem Ziehen")
        closeSetup(app)
        assertTileOrder(app, reversed, "Kachelreihenfolge nach dem Ziehen")

        // Neustart ohne Seed (der Seed würde alle Läden neu anlegen).
        // Direkt beenden, kein Hintergrund: Eine frühere Fassung von `onMove` ohne save() verlor dabei
        // die Reihenfolge (2/2 gemessen) — dieser Weg beweist, dass sofort gespeichert wird.
        app.terminate()
        let restarted = XCUIApplication()
        restarted.launchArguments += ["-hasCompletedOnboarding", "YES"]
        restarted.launch()
        XCTAssertTrue(tile(names[0], in: restarted).waitUntilHittable().matched, "Läden nach Neustart weg")
        assertTileOrder(restarted, reversed, "Kachelreihenfolge nach Neustart")
        openSetup(restarted)
        waitForRows(restarted, among: names, toBe: reversed, "Listenreihenfolge nach Neustart")
    }

    /// Kacheln liegen im Raster: erst nach Zeile (minY), dann nach Spalte (minX).
    private func assertTileOrder(_ app: XCUIApplication, _ expected: [String], _ message: String) {
        let result = UITestWait.poll(timeout: UITestWait.defaultTimeout, read: { () -> [String] in
            let placed: [(name: String, frame: CGRect)] = expected.map { ($0, self.tile($0, in: app).frame) }
            let sorted = placed.sorted { (a: (name: String, frame: CGRect), b: (name: String, frame: CGRect)) -> Bool in
                if abs(a.frame.minY - b.frame.minY) > 4 { return a.frame.minY < b.frame.minY }
                return a.frame.minX < b.frame.minX
            }
            return sorted.map { $0.name }
        }, done: { $0 == expected })
        XCTAssertTrue(result.matched, "\(message) — erwartet \(expected), zuletzt \(result.last)")
    }

    // MARK: - S7

    func testEmojiSheetOpensAndCancelsWithoutChange() {
        let app = launchedApp()
        openSetup(app)
        let emojiButton = row("Lidl", in: app).buttons.firstMatch
        XCTAssertTrue(emojiButton.waitForExistence(timeout: UITestWait.defaultTimeout), "Emoji-Knopf fehlt")
        emojiButton.tap()
        XCTAssertTrue(app.staticTexts["Emoji ändern"].waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Sheet „Emoji ändern“ erscheint nicht")
        app.buttons["Abbrechen"].tap()
        waitForGone(app.staticTexts["Emoji ändern"], "Sheet bleibt nach „Abbrechen“")
        XCTAssertTrue(row("Lidl", in: app).exists, "Zeile „Lidl“ fehlt nach „Abbrechen“")
    }
}
