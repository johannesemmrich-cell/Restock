import XCTest

/// Issue #145, Durchgang 2 — der echte Systemdialog der Mitteilungserlaubnis.
/// Spec: `docs/specs/ui-tests/test-145-durchgang-2-mitteilungserlaubnis.md` (AC-1 bis AC-7).
///
/// Die Erlaubnis gilt nur auf einem frischen Gerät als offen (Neuinstallation reicht erst nach einem Tag):
/// `simctl privacy` und `resetAuthorizationStatus(for:)` kennen keine Mitteilungen. Je Gerät ist also genau eine
/// Entscheidung testbar. Deshalb läuft die Klasse nur mit `RESTOCK_NOTIF_DECISION=allow|deny`
/// (gesetzt über `TEST_RUNNER_RESTOCK_NOTIF_DECISION`, z. B. von
/// `scripts/run-notification-permission-uitest.sh`) und sonst als Skip.
///
/// Nie den Schalter-Schlüssel als Launch-Argument: überlagert in der Argument-Domain, was der Schalter schreibt.
/// Die Klasse legt keinen Zustand im App-Group-Container an, daher gibt es kein Aufräum-Argument.
final class NotificationPermissionUITests: XCTestCase {

    private static let decisionKey = "RESTOCK_NOTIF_DECISION"
    private static let allowLabels = ["Erlauben", "Allow"]
    private static let denyLabels = ["Nicht erlauben", "Don’t Allow", "Don't Allow"]

    private var decision = ""

    override func setUpWithError() throws {
        continueAfterFailure = false
        guard let value = ProcessInfo.processInfo.environment[Self.decisionKey], !value.isEmpty else {
            throw XCTSkip("""
                Übersprungen: Braucht eine frische Installation und \(Self.decisionKey)=allow|deny. \
                Die Mitteilungserlaubnis ist nur auf einem frischen Simulator offen (Neuinstallation reicht erst nach einem Tag). \
                Zum Ausführen: bash scripts/run-notification-permission-uitest.sh
                """)
        }
        XCTAssertTrue(["allow", "deny"].contains(value),
                      "\(Self.decisionKey)=\(value) ist ungültig, erlaubt sind allow und deny")
        decision = value
    }

    // MARK: - AC-1

    func testAllow() throws {
        try XCTSkipUnless(decision == "allow", "Übersprungen: andere Entscheidung dieses Laufs (\(decision))")
        let app = launchAndOpenNotificationSettings()
        let toggle = switchOnAndAnswerDialog(in: app, buttonLabels: Self.allowLabels)
        assertToggle(toggle, is: "1", "Schalter steht nach „Erlauben“ nicht auf an")
        reopenNotificationSettings(in: app)
        assertToggle(replenishToggle(in: app), is: "1", "Schalter steht nach erneutem Öffnen nicht mehr auf an")
    }

    // MARK: - AC-2

    func testDeny() throws {
        try XCTSkipUnless(decision == "deny", "Übersprungen: andere Entscheidung dieses Laufs (\(decision))")
        let app = launchAndOpenNotificationSettings()
        let toggle = switchOnAndAnswerDialog(in: app, buttonLabels: Self.denyLabels)
        assertToggle(toggle, is: "0", "Schalter springt nach „Nicht erlauben“ nicht auf aus")
        reopenNotificationSettings(in: app)
        assertToggle(replenishToggle(in: app), is: "0", "Schalter steht nach erneutem Öffnen nicht mehr auf aus")
    }

    // MARK: - Ablauf

    private func launchAndOpenNotificationSettings() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-developerMode", "YES"]
        UITestLaunch.start(app, expecting: app.buttons["gearshape"], description: "Zahnrad")
        tapWhenHittable(app.buttons["gearshape"], "Zahnrad")
        tapWhenHittable(app.buttons["Benachrichtigungen"], "Zeile „Benachrichtigungen“")
        return app
    }

    private func replenishToggle(in app: XCUIApplication) -> XCUIElement {
        let toggle = app.switches.matching(NSPredicate(format: "label IN %@",
                                                       ["Nachkauf-Erinnerungen", "Restock reminders"])).firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Schalter „Nachkauf-Erinnerungen“ fehlt (Dev-Modus aktiv?)")
        return toggle
    }

    /// Bei frischer Installation setzt das `.task` der Einstellungen den Schalter (Default an) auf aus,
    /// weil keine Erlaubnis vorliegt. Erst dann löst aus → an die Anfrage aus.
    private func switchOnAndAnswerDialog(in app: XCUIApplication, buttonLabels: [String]) -> XCUIElement {
        let toggle = replenishToggle(in: app)
        assertToggle(toggle, is: "0", """
            Installation nicht frisch: Schalter steht beim Öffnen auf an, die Erlaubnis ist schon erteilt. \
            Lauf auf frischem Simulator nötig (scripts/run-notification-permission-uitest.sh)
            """)

        var answered = false
        let monitor = addUIInterruptionMonitor(withDescription: "Mitteilungsdialog") { alert in
            guard let button = buttonLabels.map({ alert.buttons[$0] }).first(where: { $0.exists }) else { return false }
            button.tap()
            answered = true
            return true
        }
        defer { removeUIInterruptionMonitor(monitor) }

        // Die Mitte eines Listen-Schalters trifft auf iOS 26 oft nur das Label; der Knopf sitzt rechts.
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        if alert.waitForExistence(timeout: UITestWait.defaultTimeout) {
            let button = buttonLabels.map { alert.buttons[$0] }.first { $0.exists }
            XCTAssertNotNil(button, "Mitteilungsdialog ohne erwartete Schaltfläche \(buttonLabels): \(alert.debugDescription)")
            button?.tap()
            answered = true
        } else {
            app.swipeUp() // gibt dem Unterbrechungs-Beobachter Gelegenheit, falls er den Dialog hält
        }
        XCTAssertTrue(answered, """
            Installation nicht frisch: kein Mitteilungsdialog erschienen — die Erlaubnis wurde schon \
            früher entschieden; Lauf auf frischem Simulator nötig (scripts/run-notification-permission-uitest.sh)
            """)
        return toggle
    }

    private func reopenNotificationSettings(in app: XCUIApplication) {
        tapWhenHittable(app.navigationBars.buttons.element(boundBy: 0), "Zurück zu den Einstellungen")
        tapWhenHittable(app.buttons["Fertig"], "„Fertig“")
        tapWhenHittable(app.buttons["gearshape"], "Zahnrad (erneut)")
        tapWhenHittable(app.buttons["Benachrichtigungen"], "Zeile „Benachrichtigungen“ (erneut)")
    }

    /// Wartet auf den Zustand, statt ihn sofort zu lesen, und prüft ihn danach noch einmal nach kurzer
    /// Pause, damit ein späteres Zurückspringen (Antwort der Anfrage, `.task`) auffällt.
    private func assertToggle(_ toggle: XCUIElement, is value: String, _ message: String,
                              file: StaticString = #filePath, line: UInt = #line) {
        let reached = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: toggle)
        let waited = XCTWaiter().wait(for: [reached], timeout: UITestWait.defaultTimeout) == .completed
        XCTAssertTrue(waited, "\(message) (zuletzt: \(String(describing: toggle.value)))", file: file, line: line)
        Thread.sleep(forTimeInterval: 2)
        XCTAssertEqual(toggle.value as? String, value, "\(message) (sprang zurück)", file: file, line: line)
    }

    private func tapWhenHittable(_ element: XCUIElement, _ what: String,
                                 file: StaticString = #filePath, line: UInt = #line) {
        let result = element.waitUntilHittable()
        XCTAssertTrue(result.matched, "\(what) nicht antippbar, zuletzt: \(result.last)", file: file, line: line)
        element.tap()
    }
}
