import XCTest

/// Issue #98, Durchgang 8: Schnell-hinzufügen-Knopf (Control Center). Das Control setzt nur den Merker
/// `pendingQuickAdd` in der App-Gruppe (`QuickAddControlIntent`); die Startseite liest und löscht ihn
/// und fokussiert das Eingabefeld. Das Startargument `-pendingQuickAddForUITests` setzt diesen Merker
/// vor dem Start. Spec: `docs/specs/ui-tests/test-98-durchgang-8-siri-widget.md`.
///
/// **Offene Grenzen:** Der Tipp auf das Control selbst, die Darstellung im Control Center und
/// `openAppWhenRun` durch das System laufen im Simulator nicht und sind hier nicht geprüft.
final class QuickAddControlUITests: XCTestCase {

    private static let placeholder = "Schnell hinzufügen…"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Der App-Group-Container überlebt den Test (siehe CLAUDE.md): Seed und Merker räumen.
    override func tearDown() {
        super.tearDown()
        let cleaner = XCUIApplication()
        cleaner.launchArguments = ["-hasCompletedOnboarding", "YES",
                                   "-clearQuickAddAssignmentSeedForUITests", "-clearPendingQuickAddForUITests"]
        cleaner.launch()
        cleaner.terminate()
    }

    private func launch(withPendingFlag: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-seedQuickAddAssignmentForUITests"]
        if withPendingFlag { app.launchArguments.append("-pendingQuickAddForUITests") }
        app.launch()
        return app
    }

    private func hasFocus(_ field: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "hasKeyboardFocus == true")
        let result = XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: field)], timeout: timeout)
        return result == .completed
    }

    func testPendingFlagFocusesQuickAddFieldAndIsConsumed() {
        let app = launch(withPendingFlag: true)
        let field = app.textFields[Self.placeholder]
        XCTAssertTrue(field.waitForExistence(timeout: UITestWait.defaultTimeout), "Schnell-Eingabe-Feld nicht gefunden")
        XCTAssertTrue(hasFocus(field, timeout: UITestWait.defaultTimeout),
                      "Mit gesetztem Merker muss das Feld fokussiert sein")

        // Merker verbraucht: Neustart ohne Argument fokussiert nicht mehr.
        app.terminate()
        let second = launch(withPendingFlag: false)
        let secondField = second.textFields[Self.placeholder]
        XCTAssertTrue(secondField.waitForExistence(timeout: UITestWait.defaultTimeout))
        XCTAssertFalse(hasFocus(secondField, timeout: 3), "Der Merker darf nicht ein zweites Mal wirken")
    }

    /// Gegenprobe: ohne Merker kein Fokus (beweist, dass der Test oben nicht leer läuft).
    func testWithoutPendingFlagFieldIsNotFocused() {
        let app = launch(withPendingFlag: false)
        let field = app.textFields[Self.placeholder]
        XCTAssertTrue(field.waitForExistence(timeout: UITestWait.defaultTimeout))
        XCTAssertFalse(hasFocus(field, timeout: 3))
    }
}
