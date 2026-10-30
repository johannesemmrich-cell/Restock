import XCTest

/// Issue #98, Durchgang 5 — Paywall-Sperre an den drei Auslösern und Falsch-Pfad des Dev-Passworts.
/// Spec: `docs/specs/ui-tests/test-98-durchgang-5-onboarding-paywall.md` (AC-5 bis AC-9).
///
/// Läuft ohne Premium (`-developerMode NO` überlagert einen gespeicherten Wert). Die Klasse sät und
/// speichert nichts Dauerhaftes (kein Kauf, kein erfolgreiches Passwort) und braucht daher kein Aufräumen.
///
/// Offene Grenzen (Spec AC-13): Kauf, Wiederherstellen und die Release-Fehlermeldung der Paywall werden
/// nur auf Existenz geprüft, nie bedient (im Simulator ist `products` leer; `Restock.storekit` steht in
/// keinem Scheme, der DEBUG-Zweig `dismiss()` ist nicht der Release-Weg). Der Richtig-Pfad des
/// Dev-Passworts ist ungeprüft; der Test kennt das Passwort nicht. `StoreSetupView` folgt in Durchgang 6.
final class PaywallUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchLocked(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-developerMode", "NO"] + extraArguments
        UITestLaunch.start(app, expecting: app.buttons["fork.knife"], description: "Menüplan-Knopf fork.knife")
        return app
    }

    private func tapWhenHittable(_ element: XCUIElement, _ what: String,
                                 file: StaticString = #filePath, line: UInt = #line) {
        let result = element.waitUntilHittable()
        XCTAssertTrue(result.matched, "\(what) nicht antippbar, zuletzt: \(result.last)", file: file, line: line)
        element.tap()
    }

    /// „Paywall steht“: nur Existenz, kein Tipp auf Kaufen oder Wiederherstellen.
    private func assertPaywall(_ app: XCUIApplication, feature: String,
                               file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.staticTexts["Restock Pro"].waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Paywall-Kopf „Restock Pro“ fehlt", file: file, line: line)
        // Das Label trägt einen Zeilenumbruch („… weiteren\nPro-Features frei.“), deshalb nur Teilstrings,
        // und über alle Elementarten, weil SwiftUI den Text je nach Container unterschiedlich ausweist.
        let title = app.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS %@ AND label CONTAINS %@", "Schalte \(feature)", "Pro-Features frei")).firstMatch
        let anyTitle = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Schalte")).firstMatch
        _ = anyTitle.waitForExistence(timeout: 5)
        XCTAssertTrue(title.waitForExistence(timeout: 5),
                      "Titelzeile „Schalte \(feature) …“ fehlt, gefunden: „\(anyTitle.exists ? anyTitle.label : "nichts")“",
                      file: file, line: line)
        XCTAssertTrue(app.buttons["Käufe wiederherstellen"].exists, "„Käufe wiederherstellen“ fehlt", file: file, line: line)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Jetzt freischalten")).firstMatch.exists,
                      "Kaufknopf „Jetzt freischalten…“ fehlt", file: file, line: line)
    }

    private func closePaywall(_ app: XCUIApplication) {
        tapWhenHittable(app.buttons["Schließen"], "„Schließen“")
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.staticTexts["Restock Pro"])
        waitForExpectations(timeout: UITestWait.defaultTimeout)
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        var swipes = 0
        while !element.exists && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
    }

    /// Wischt bis das Element existiert, dann in kurzen Zügen bis es antippbar ist (Abschrift aus
    /// `DynamicTypeUITests`): Inhalt unter dem Rand steht schon im Baum, ist aber noch nicht antippbar.
    private func scrollUntilHittable(_ app: XCUIApplication, _ target: XCUIElement, description: String,
                                     maxSwipes: Int = 12, file: StaticString = #filePath, line: UInt = #line) {
        _ = target.waitForExistence(timeout: 3)
        var swipes = 0
        while !target.exists && swipes < maxSwipes {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(target.waitForExistence(timeout: UITestWait.defaultTimeout),
                      "\(description) fehlt auch nach \(swipes) Wischern.", file: file, line: line)
        var nudges = 0
        var ready = target.waitUntilHittable(timeout: 3)
        while !ready.matched && nudges < 4 {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
            nudges += 1
            ready = target.waitUntilHittable(timeout: 3)
        }
        XCTAssertTrue(ready.matched,
                      "\(description) nicht antippbar nach \(swipes) Wischern und \(nudges) Zügen — zuletzt: \(ready.last)",
                      file: file, line: line)
    }

    /// SwiftUI-`Link` erscheint im Zugänglichkeitsbaum auf iOS 27 als Link, auf iOS 26.5 als Button
    /// (belegt im CI-Lauf auf iOS 26.5, Issue #215); gesucht wird daher nach Beschriftung und beiden Typen.
    private func legalLink(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(
            format: "label == %@ AND (elementType == %d OR elementType == %d)",
            label, XCUIElement.ElementType.link.rawValue, XCUIElement.ElementType.button.rawValue
        )).firstMatch
    }

    /// Öffnet die Paywall über fork.knife und prüft beide Rechtslinks: vorhanden, im Fenster, antippbar,
    /// ohne zu tippen (kein Browseraufruf). Liefert die Links zurück.
    @discardableResult
    private func assertLegalLinks(_ app: XCUIApplication) -> (privacy: XCUIElement, terms: XCUIElement) {
        tapWhenHittable(app.buttons["fork.knife"], "fork.knife")
        assertPaywall(app, feature: "den Rezeptplan")
        let privacy = legalLink(app, "Datenschutz")
        let terms = legalLink(app, "Nutzungsbedingungen (EULA)")
        scrollUntilHittable(app, privacy, description: "Link „Datenschutz“")
        scrollUntilHittable(app, terms, description: "Link „Nutzungsbedingungen (EULA)“")
        let window = app.windows.firstMatch.frame
        for (name, link) in [("Datenschutz", privacy), ("Nutzungsbedingungen (EULA)", terms)] {
            XCTAssertTrue(window.contains(link.frame), "Link „\(name)“ liegt nicht im Fenster: \(link.frame) in \(window)")
        }
        return (privacy, terms)
    }

    // MARK: - Issue #215: Rechtslinks (AC-1, AC-2, AC-6, AC-7)

    func testLegalLinksReachableOnPaywall() {
        let app = launchLocked()
        let links = assertLegalLinks(app)

        // Gegenprobe: „Käufe wiederherstellen“ steht vor dem Rechtsblock.
        let restore = app.buttons["Käufe wiederherstellen"]
        XCTAssertTrue(restore.exists, "„Käufe wiederherstellen“ fehlt")
        XCTAssertLessThanOrEqual(restore.frame.maxY, links.privacy.frame.minY,
                                 "„Käufe wiederherstellen“ liegt nicht oberhalb der Links")

        // Abo-Text-Anfang und Link-Zeile liegen zugleich im Fenster; sonst einmal kurz zurückwischen.
        let notice = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Restock Pro – Jährlich")).firstMatch
        let window = app.windows.firstMatch.frame
        if !(notice.exists && window.contains(notice.frame)) { app.swipeDown() }
        XCTAssertTrue(notice.waitForExistence(timeout: UITestWait.defaultTimeout), "Abo-Text „Restock Pro – Jährlich …“ fehlt")
        XCTAssertTrue(window.contains(notice.frame), "Anfang des Abo-Texts liegt nicht im Fenster: \(notice.frame)")
        XCTAssertTrue(window.contains(links.terms.frame), "Link-Zeile liegt nach dem Zurückwischen nicht im Fenster")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "paywall-unten"
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testLegalLinksReachableAtLargestTextSize() {
        let app = launchLocked(extraArguments: ["-UIPreferredContentSizeCategoryName",
                                                "UICTContentSizeCategoryAccessibilityXXXL"])
        let links = assertLegalLinks(app)
        XCTAssertFalse(links.privacy.frame.intersects(links.terms.frame),
                       "Die Links überlappen sich: \(links.privacy.frame) und \(links.terms.frame)")
    }

    // MARK: - AC-5, AC-6

    func testRecipePlanLockedOpensPaywall() {
        let app = launchLocked()
        tapWhenHittable(app.buttons["fork.knife"], "fork.knife")
        assertPaywall(app, feature: "den Rezeptplan")
        XCTAssertFalse(app.buttons["Tag hinzufügen"].exists, "Der Menüplan öffnet sich trotz Sperre")
        closePaywall(app)
        XCTAssertTrue(app.buttons["fork.knife"].waitUntilHittable().matched, "Startseite nach „Schließen“ nicht bedienbar")
    }

    func testExpensesAnalysisLockedOpensPaywall() {
        let app = launchLocked()
        tapWhenHittable(app.buttons["chart.bar"], "chart.bar")
        assertPaywall(app, feature: "die Ausgaben-Analyse")
        closePaywall(app)
        XCTAssertTrue(app.buttons["chart.bar"].waitUntilHittable().matched, "Startseite nach „Schließen“ nicht bedienbar")
    }

    func testSettingsProRowOpensPaywall() {
        let app = launchLocked()
        tapWhenHittable(app.buttons["gearshape"], "Zahnrad")
        // Das Label der Zeile enthält auch die Unterzeile („Restock Pro freischalten, Ausgaben-Analyse & …“).
        let proRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Restock Pro freischalten")).firstMatch
        scrollTo(proRow, in: app)
        XCTAssertTrue(proRow.exists, "Zeile „Restock Pro freischalten“ fehlt in den Einstellungen")
        XCTAssertFalse(app.staticTexts["Pro aktiv"].exists, "„Pro aktiv“ steht ohne Premium")
        proRow.tap()
        assertPaywall(app, feature: "alle Pro-Features")
        closePaywall(app)
        XCTAssertTrue(proRow.waitUntilHittable().matched, "Einstellungen nach „Schließen“ nicht sichtbar")
    }

    // MARK: - AC-7 (Gegenprobe)

    func testPremiumAccessOpensMenuPlanWithoutPaywall() {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-developerMode", "NO",
                                "-premiumForScreenshots", "-clearMenuPlanForUITests"]
        UITestLaunch.start(app, expecting: app.buttons["fork.knife"], description: "Menüplan-Knopf fork.knife")
        tapWhenHittable(app.buttons["fork.knife"], "fork.knife")
        XCTAssertTrue(app.buttons["Tag hinzufügen"].waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Menüplan öffnet sich mit Premium nicht")
        XCTAssertFalse(app.staticTexts["Restock Pro"].exists, "Die Paywall erscheint trotz Premium")
    }

    // MARK: - AC-8 (Dev-Passwort, nur Falsch-Pfad)

    func testWrongDevPasswordShowsErrorAndKeepsSheetOpen() {
        let app = launchLocked()
        tapWhenHittable(app.buttons["gearshape"], "Zahnrad")
        let version = app.staticTexts["Version"]
        scrollTo(version, in: app)
        XCTAssertTrue(version.waitUntilHittable().matched, "Zeile „Version“ nicht antippbar")

        // Fünf Tipps als ein Mehrfachtipp-Ereignis: Einzeltipps brauchen auf langsamen Läufern je
        // bis zu 4 s und reißen das 2-s-Fenster der Zählung. Bei verschlucktem Ereignis einmal
        // wiederholen, mit 2,5 s Pause, damit die Zählung vorher sicher zurückgesetzt ist.
        let sheetTitle = app.staticTexts["Developer Mode"]
        for attempt in 0..<2 where !sheetTitle.exists {
            if attempt == 1 { Thread.sleep(forTimeInterval: 2.5) }
            version.tap(withNumberOfTaps: 5, numberOfTouches: 1)
            _ = sheetTitle.waitForExistence(timeout: UITestWait.defaultTimeout)
        }
        XCTAssertTrue(sheetTitle.exists, "Das Sheet „Developer Mode“ erscheint nach fünf Tipps nicht")

        let field = app.secureTextFields["Passwort"]
        tapWhenHittable(field, "Feld „Passwort“")
        expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: field)
        waitForExpectations(timeout: 10)
        field.typeText("falsch")
        let unlock = app.buttons["Entsperren"]
        tapWhenHittable(unlock, "„Entsperren“")

        XCTAssertTrue(app.staticTexts["Falsches Passwort"].waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Keine Fehlermeldung bei falschem Passwort")
        XCTAssertTrue(sheetTitle.exists, "Das Sheet schloss sich trotz falschem Passwort")
        XCTAssertFalse(unlock.isEnabled, "Die Eingabe wurde nach dem Fehlversuch nicht geleert")
        app.buttons["Abbrechen"].tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: sheetTitle)
        waitForExpectations(timeout: UITestWait.defaultTimeout)
    }
}
