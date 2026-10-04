import XCTest

/// Issue #98, Durchgang 3 (`docs/specs/ui-tests/test-98-durchgang-3-schnelleingabe-notfallpfad.md`):
/// der Notfallpfad (Stufe 3) in `SmartCartApp.init()` — Store-Dateien löschen, frischer Container,
/// einmaliger Hinweis „Daten neu geladen“ in `HomeView`. Der Pfad lief bisher nie.
///
/// Das DEBUG-Argument `-forceContainerFailureForUITests` überspringt `SharedModelContainer.make()`,
/// damit Stufe 3 mit der echten `deleteStoreFiles()` durchlaufen wird. Vorlauf mit Seed legt zwei
/// Läden („Lidl“, „dm“) in die Store-Dateien; danach müssen sie weg sein.
///
/// OFFENE GRENZE: Dass `make()` in der Praxis `nil` liefert (CloudKit, Schema, Dateisystem), lässt
/// sich im Simulator nicht erzeugen und wird hier NICHT geprüft. Bewiesen wird alles ab Stufe 3.
///
/// Nur im Test-Simulator laufen lassen: der Notfalllauf löscht Store-Dateien.
final class DataResetUITests: XCTestCase {

    private static let placeholder = "Schnell hinzufügen…"
    private static let alertTitle = "Daten neu geladen"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Der App-Group-Container und `UserDefaults.standard` überleben den Test (siehe CLAUDE.md):
    /// Läden, gemerkte Korrekturen und den Hinweis-Schlüssel wieder entfernen.
    override func tearDown() {
        super.tearDown()
        let cleaner = XCUIApplication()
        cleaner.launchArguments = ["-hasCompletedOnboarding", "YES",
                                   "-clearQuickAddAssignmentSeedForUITests", "-clearDataResetForUITests"]
        cleaner.launch()
        cleaner.terminate()
    }

    // MARK: - Hilfen

    private func tile(_ storeName: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(storeName),")).firstMatch
    }

    /// Vorlauf: zwei Läden anlegen (Seed), warten bis die Kacheln stehen, App beenden. Der Testläufer
    /// startet die App gelegentlich ganz ohne Launch-Argumente (Issue #105); ein zweiter Start trägt sie.
    private func seedTwoStores() {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-seedQuickAddAssignmentForUITests"]
        app.launch()
        if !tile("Lidl", in: app).waitForExistence(timeout: 15) {
            app.terminate()
            app.launch()
        }
        XCTAssertTrue(tile("Lidl", in: app).waitForExistence(timeout: 15), "Vorlauf: Kachel „Lidl“ fehlt")
        XCTAssertTrue(tile("dm", in: app).exists, "Vorlauf: Kachel „dm“ fehlt")
        app.terminate()
    }

    /// Notfalllauf: erzwungener Container-Fehler, ohne Seed. Ein Start ohne Launch-Argumente (#105)
    /// würde den Pfad gar nicht berühren — dann erscheint kein Alert und die Seed-Läden stünden noch da;
    /// in dem Fall einmal neu starten.
    private func launchEmergency() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-forceContainerFailureForUITests"]
        app.launch()
        if !app.alerts[Self.alertTitle].waitForExistence(timeout: 20) {
            app.terminate()
            app.launch()
        }
        return app
    }

    private func quickAddField(in app: XCUIApplication) -> XCUIElement {
        app.textFields[Self.placeholder]
    }

    // MARK: - D1: Löschen, Hinweis genau einmal, Fremddatei bleibt

    /// Nach dem Notfalllauf sind die Läden aus dem Vorlauf weg, der Hinweis erscheint einmal, und ein
    /// dritter Start zeigt ihn nicht erneut. Die Fremddatei-Prüfung (Markerdatei) läuft im DEBUG-Zweig
    /// der App mit: trifft das Löschen Fremddateien, beendet sich die App und der Alert bleibt aus.
    func testEmergencyPathDeletesStoresAndShowsNoticeOnce() {
        seedTwoStores()

        let app = launchEmergency()
        let alert = app.alerts[Self.alertTitle]
        XCTAssertTrue(alert.waitForExistence(timeout: 20),
                      "Der Hinweis „\(Self.alertTitle)“ erscheint nach dem Notfalllauf nicht")
        alert.buttons["OK"].tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: alert)
        waitForExpectations(timeout: 10)

        XCTAssertTrue(quickAddField(in: app).waitForExistence(timeout: 15),
                      "Nach dem Hinweis ist die Startseite nicht bedienbar (Schnell-Eingabe-Feld fehlt)")
        XCTAssertFalse(tile("Lidl", in: app).exists, "„Lidl“ aus dem Vorlauf steht nach dem Notfall noch da")
        XCTAssertFalse(tile("dm", in: app).exists, "„dm“ aus dem Vorlauf steht nach dem Notfall noch da")
        app.terminate()

        // Einmaligkeit: dritter Start ohne Flag und ohne Seed.
        let third = XCUIApplication()
        third.launchArguments += ["-hasCompletedOnboarding", "YES"]
        third.launch()
        XCTAssertTrue(quickAddField(in: third).waitForExistence(timeout: 15), "Dritter Start: Startseite fehlt")
        XCTAssertFalse(third.alerts[Self.alertTitle].waitForExistence(timeout: 3),
                       "Der Hinweis erscheint beim dritten Start erneut")
        XCTAssertFalse(tile("Lidl", in: third).exists, "„Lidl“ ist beim dritten Start wieder da")
        XCTAssertFalse(tile("dm", in: third).exists, "„dm“ ist beim dritten Start wieder da")
    }

    // MARK: - D2: Die App bleibt nach dem Notfall bedienbar

    /// Nach dem Notfall ist der frische Container benutzbar: Eingabe im Schnell-Eingabe-Feld geht,
    /// und es kommt kein zweiter Hinweis.
    func testAppUsableAfterEmergencyReset() {
        seedTwoStores()

        let app = launchEmergency()
        let alert = app.alerts[Self.alertTitle]
        XCTAssertTrue(alert.waitForExistence(timeout: 20), "Der Hinweis erscheint nicht")
        alert.buttons["OK"].tap()

        let field = quickAddField(in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 15), "Schnell-Eingabe-Feld fehlt")
        field.tap()
        expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: field)
        waitForExpectations(timeout: 10)
        field.typeText("Nudeln")
        expectation(for: NSPredicate(format: "value CONTAINS %@", "Nudeln"), evaluatedWith: field)
        waitForExpectations(timeout: 5)
        XCTAssertFalse(app.alerts[Self.alertTitle].exists, "Der Hinweis erscheint ein zweites Mal")
    }
}
