import XCTest

/// Issue #145, Durchgang 4: jeder Ausgang von Kauf und Wiederherstellen in der Paywall (P1–P11).
/// Spec: `docs/specs/ui-tests/test-145-durchgang-4-kauf-wiederherstellen.md`.
///
/// Der Ausgang kommt aus dem DEBUG-Ersatz-Appstore, gewählt mit `-purchaseScenarioForUITests <name>`.
/// Der Ersatz hält Käufe nur im Prozess und schreibt nichts in den App-Group-Container, daher gibt es kein
/// Aufräum-Argument. `-developerMode NO` liest nur (wie in `PaywallUITests`), nie `YES`.
///
/// Offene Grenzen: Apples Kaufdialog, echte Transaktionen und Produkte in App Store Connect prüft das nicht
/// (SKTestSession per Kommandozeile auf iOS 26.5/27.0 defekt, #178; Produkte #175); „bleibt nach Neustart
/// freigeschaltet“ ist mit dem Ersatz nicht prüfbar.
final class PurchaseUITests: XCTestCase {

    private enum Notice {
        static let pending = "Der Kauf wartet auf Zustimmung"
        static let restoreNone = "Kein Kauf gefunden"
        static let restoreFailed = "Wiederherstellen hat nicht geklappt"
        static let productMissing = "Der Kauf konnte nicht geladen werden"
        static let purchaseFailed = "Kauf fehlgeschlagen"
        static let all = [pending, restoreNone, restoreFailed, productMissing, purchaseFailed]
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDown() {
        XCUIDevice.shared.appearance = .light
        super.tearDown()
    }

    // MARK: - Hilfen

    private func launch(scenario: String, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-developerMode", "NO",
                                "-purchaseScenarioForUITests", scenario] + extra
        UITestLaunch.start(app, expecting: app.buttons["fork.knife"], description: "Menüplan-Knopf fork.knife")
        return app
    }

    private func tapWhenHittable(_ element: XCUIElement, _ what: String,
                                 file: StaticString = #filePath, line: UInt = #line) {
        let result = element.waitUntilHittable()
        XCTAssertTrue(result.matched, "\(what) nicht antippbar, zuletzt: \(result.last)", file: file, line: line)
        element.tap()
    }

    private func openPaywall(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        tapWhenHittable(app.buttons["fork.knife"], "fork.knife", file: file, line: line)
        XCTAssertTrue(app.staticTexts["Restock Pro"].waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Paywall öffnet sich nicht", file: file, line: line)
    }

    private func buyButton(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Jetzt freischalten")).firstMatch
    }

    private func restoreButton(_ app: XCUIApplication) -> XCUIElement {
        app.buttons["Käufe wiederherstellen"]
    }

    private func notice(_ text: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// Wischt nach oben, bis das Element antippbar ist (der Wiederherstellen-Knopf liegt unter dem Kaufknopf).
    private func scrollIntoView(_ element: XCUIElement, in app: XCUIApplication) {
        var swipes = 0
        while !(element.exists && element.isHittable) && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
    }

    private func tapBuy(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let button = buyButton(app)
        scrollIntoView(button, in: app)
        tapWhenHittable(button, "Kaufknopf „Jetzt freischalten…“", file: file, line: line)
    }

    private func tapRestore(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let button = restoreButton(app)
        scrollIntoView(button, in: app)
        tapWhenHittable(button, "„Käufe wiederherstellen“", file: file, line: line)
    }

    private func assertNotice(_ text: String, in app: XCUIApplication,
                              file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(notice(text, in: app).waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Hinweis „\(text) …“ erscheint nicht", file: file, line: line)
    }

    private func assertPaywallOpen(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.staticTexts["Restock Pro"].exists, "Paywall hat sich geschlossen", file: file, line: line)
    }

    private func waitForPaywallClosed(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let closed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.staticTexts["Restock Pro"])
        let result = XCTWaiter().wait(for: [closed], timeout: UITestWait.defaultTimeout)
        XCTAssertEqual(result, .completed, "Paywall schließt sich nicht", file: file, line: line)
    }

    private func closePaywall(_ app: XCUIApplication) {
        tapWhenHittable(app.buttons["Schließen"], "„Schließen“")
        waitForPaywallClosed(app)
    }

    private func assertRecipePlanOpens(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        tapWhenHittable(app.buttons["fork.knife"], "fork.knife", file: file, line: line)
        XCTAssertTrue(app.buttons["Tag hinzufügen"].waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Rezeptplan öffnet sich nach dem Kauf nicht", file: file, line: line)
        XCTAssertFalse(app.staticTexts["Restock Pro"].exists, "Paywall erscheint trotz Kauf", file: file, line: line)
    }

    // MARK: - Kaufen (P1–P5)

    func testPurchaseSuccessClosesPaywallAndUnlocksRecipePlan() {
        let app = launch(scenario: "success", extra: ["-clearMenuPlanForUITests"])
        openPaywall(app)
        tapBuy(app)
        waitForPaywallClosed(app)
        assertRecipePlanOpens(app)
    }

    func testPurchaseCancelledKeepsPaywallOpenWithoutMessage() {
        let app = launch(scenario: "cancel")
        openPaywall(app)
        tapBuy(app)
        // Der Kaufknopf ist während des Kaufs gesperrt; wieder antippbar heißt: Ausgang ist da.
        XCTAssertTrue(buyButton(app).waitUntilHittable().matched, "Kaufknopf nach Abbruch nicht wieder bereit")
        assertPaywallOpen(app)
        for text in Notice.all {
            XCTAssertFalse(notice(text, in: app).exists, "Nach Abbruch steht ein Hinweis: „\(text)“")
        }
    }

    func testPurchasePendingShowsApprovalNoticeAndKeepsPaywallOpen() {
        let app = launch(scenario: "pending")
        openPaywall(app)
        tapBuy(app)
        assertNotice(Notice.pending, in: app)
        assertPaywallOpen(app)
        closePaywall(app)
        // Noch nicht zugestimmt: Der Rezeptplan bleibt gesperrt.
        openPaywall(app)
        XCTAssertFalse(app.buttons["Tag hinzufügen"].exists, "Rezeptplan frei, obwohl der Kauf noch wartet")
    }

    func testPurchaseFailureShowsErrorAndKeepsPaywallOpen() {
        let app = launch(scenario: "fail")
        openPaywall(app)
        tapBuy(app)
        assertNotice("\(Notice.purchaseFailed): Testfehler Kauf", in: app)
        assertPaywallOpen(app)
    }

    func testMissingProductShowsLoadErrorInsteadOfClosing() {
        let app = launch(scenario: "productMissing")
        openPaywall(app)
        tapBuy(app)
        assertNotice(Notice.productMissing, in: app)
        assertPaywallOpen(app)
    }

    // MARK: - Wiederherstellen (P6–P8)

    func testRestoreWithoutPurchaseShowsNoPurchaseNotice() {
        let app = launch(scenario: "restoreNone")
        openPaywall(app)
        tapRestore(app)
        assertNotice(Notice.restoreNone, in: app)
        assertPaywallOpen(app)
    }

    func testRestoreFoundClosesPaywallAndUnlocks() {
        let app = launch(scenario: "restoreFound", extra: ["-clearMenuPlanForUITests"])
        openPaywall(app)
        tapRestore(app)
        waitForPaywallClosed(app)
        assertRecipePlanOpens(app)
    }

    func testRestoreFailureShowsErrorNotice() {
        let app = launch(scenario: "restoreFail")
        openPaywall(app)
        tapRestore(app)
        assertNotice(Notice.restoreFailed, in: app)
        assertPaywallOpen(app)
    }

    // MARK: - Hinweis-Verhalten (P9, P10)

    func testNoticeDisappearsOnNextTap() {
        let app = launch(scenario: "pending")
        openPaywall(app)
        tapBuy(app)
        assertNotice(Notice.pending, in: app)

        // Tipp auf „Käufe wiederherstellen“: Kauf-Hinweis weg, danach nur der Wiederherstell-Hinweis.
        tapRestore(app)
        assertNotice(Notice.restoreNone, in: app)
        XCTAssertFalse(notice(Notice.pending, in: app).exists, "Kauf-Hinweis bleibt neben dem Wiederherstell-Hinweis stehen")

        // Tipp auf „Jetzt freischalten“: Wiederherstell-Hinweis weg, wieder nur der Kauf-Hinweis.
        tapBuy(app)
        assertNotice(Notice.pending, in: app)
        XCTAssertFalse(notice(Notice.restoreNone, in: app).exists, "Wiederherstell-Hinweis bleibt nach Kaufversuch stehen")
    }

    func testNoticeIsDirectlyBelowRestoreButton() {
        let app = launch(scenario: "restoreNone")
        openPaywall(app)
        tapRestore(app)
        let hint = notice(Notice.restoreNone, in: app)
        XCTAssertTrue(hint.waitForExistence(timeout: UITestWait.defaultTimeout), "Hinweis erscheint nicht")
        let legal = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Abonnements verlängern sich")).firstMatch
        XCTAssertTrue(legal.exists, "Rechtstext fehlt")
        let restoreFrame = restoreButton(app).frame
        XCTAssertGreaterThanOrEqual(hint.frame.minY, restoreFrame.maxY,
                                    "Hinweis (\(hint.frame)) liegt nicht unter „Käufe wiederherstellen“ (\(restoreFrame))")
        XCTAssertLessThanOrEqual(hint.frame.maxY, legal.frame.minY,
                                 "Hinweis (\(hint.frame)) liegt nicht über dem Rechtstext (\(legal.frame))")
    }

    // MARK: - Schließen-Chip (P11)

    /// Das Accessibility-Label bleibt „Schließen“, auch wenn die Anzeige zu „…“ gekürzt ist; ein Test auf
    /// Existenz oder Label wäre also auch im Fehlerzustand grün. Geprüft wird deshalb die gerenderte Breite:
    /// „Schließen“ in 15 pt halbfett ist rund 62 pt breit, dazu 2 × 14 pt Innenabstand, Soll ca. 90 pt.
    /// Die Untergrenze 80 pt lässt Spielraum für Schriftrundung; ein „…“-Chip ist deutlich schmaler
    /// (Vorher-Messwert im RED-Lauf 2026-10-19, iOS 26.5, hell: 40 pt; dunkel nicht erreicht, weil der Test
    /// beim ersten Fehlschlag abbricht). Ein Screenshot je Erscheinungsbild hängt am Ergebnis.
    func testCloseChipShowsFullWord() {
        let minWidth: CGFloat = 80
        for appearance in [XCUIDevice.Appearance.light, .dark] {
            XCUIDevice.shared.appearance = appearance
            let app = launch(scenario: "cancel")
            openPaywall(app)
            let chip = app.buttons["Schließen"]
            XCTAssertTrue(chip.waitUntilHittable().matched, "„Schließen“ nicht antippbar")
            let name = appearance == .dark ? "dunkel" : "hell"
            let shot = XCTAttachment(screenshot: chip.screenshot())
            shot.name = "schliessen-chip-\(name)"
            shot.lifetime = .keepAlways
            add(shot)
            XCTAssertGreaterThanOrEqual(chip.frame.width, minWidth,
                                        "„Schließen“-Chip \(name) nur \(chip.frame.width) pt breit (Soll ≥ \(minWidth)), Anzeige gekürzt")
            app.terminate()
        }
    }
}
