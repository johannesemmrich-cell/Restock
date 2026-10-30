import XCTest

/// Aufnahme der App-Store-Bilder (Issue #175, Durchgang B3, Spec `docs/specs/appstore/b3-betrieb-restschritte.md`, AC-1).
///
/// Kein Prüftest, sondern ein Aufnahmewerkzeug: Ohne Umgebungsvariable `RESTOCK_STORE_SHOTS_DIR`
/// (gesetzt über `TEST_RUNNER_RESTOCK_STORE_SHOTS_DIR` beim `xcodebuild`-Aufruf) überspringt er sich,
/// läuft also in CI und in Xcode nie. Mit Variable schreibt er je Sprache fünf Bilder nach
/// `<dir>/<de|en>/<NN>-<name>.png` (volle Bildschirmgröße über `app.screenshot()`) und hängt sie
/// zusätzlich ans Testergebnis.
///
/// Bilder: (1) Startseite mit Läden, (2) Einkaufsliste, (3) Schnell-hinzufügen mit Ladenvorschlag,
/// (4) Bon-Prüfung, (5) Pro-Übersicht. Daten: (1)–(3) aus `-seedQuickAddAssignmentForUITests`
/// (Läden „Lidl“ und „dm“), die Artikel tippt der Test über die Schnell-Eingabe in der jeweiligen
/// Sprache ein (echter Weg samt Zuordnung); (4) aus `-seedReceiptReviewForUITests`; (5) ohne Seed,
/// Preise aus dem Ersatz-Appstore `-purchaseScenarioForUITests success` (nur im Prozess, kein Zustand).
/// Aufräumen im `tearDown()` mit beiden passenden Aufräum-Argumenten. Keine echten Namen oder Fotos.
///
/// Sprache: Launch-Argumente `-AppleLanguages (xx)` / `-AppleLocale`; der Aufnahmelauf setzt
/// zusätzlich `-testLanguage`/`-testRegion`, weil das Scheme `language = "de"` fest einstellt.
/// Nie `-developerMode` (Argument-Domain-Falle).
final class StoreScreenshotCaptureUITests: XCTestCase {

    private struct Language {
        let code: String
        let locale: String
        let items: [String]
        let suggestion: String
    }

    private static let german = Language(
        code: "de", locale: "de_DE",
        items: ["Milch", "1 kg Bananen", "Nudeln", "Brot", "Eier", "Zahnpasta", "Shampoo"],
        suggestion: "Duschgel")
    private static let english = Language(
        code: "en", locale: "en_DE",  // Region DE: Preise in €, wie Katalog und Paywall
        items: ["Milk", "1 kg Bananas", "Pasta", "Bread", "Eggs", "Toothpaste", "Shampoo"],
        suggestion: "Shower gel")

    private var outputDir: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        guard let dir = ProcessInfo.processInfo.environment["RESTOCK_STORE_SHOTS_DIR"], !dir.isEmpty else {
            throw XCTSkip("Nur im Aufnahmelauf: RESTOCK_STORE_SHOTS_DIR fehlt.")
        }
        outputDir = URL(fileURLWithPath: dir, isDirectory: true)
    }

    /// Der App-Group-Container überlebt den Lauf (CLAUDE.md): beide Seeds wieder entfernen.
    override func tearDown() {
        super.tearDown()
        guard outputDir != nil else { return }
        let cleaner = XCUIApplication()
        cleaner.launchArguments = ["-hasCompletedOnboarding", "YES", "-clearQuickAddAssignmentSeedForUITests",
                                   "-clearReceiptReviewSeedForUITests", "-clearMenuPlanForUITests"]
        cleaner.launch()
        cleaner.terminate()
    }

    func testCaptureGerman() throws {
        try capture(Self.german)
    }

    func testCaptureEnglish() throws {
        try capture(Self.english)
    }

    /// Nur Englisch (PO 2026-10-29): zwei Ansichten, deren Texte vollständig in `en.lproj` stehen
    /// (Artikel hinzufügen, Menüplan). Eigene Methode, damit en/01–05 beim Nachaufnehmen bleiben.
    func testCaptureEnglishExtras() throws {
        try captureAddItem(Self.english)
        try captureMenuPlan(Self.english)
    }

    // MARK: - Ablauf

    private func capture(_ lang: Language) throws {
        try captureListShots(lang)
        try captureReceiptReview(lang)
        try capturePaywall(lang)
    }

    private func languageArguments(_ lang: Language) -> [String] {
        ["-AppleLanguages", "(\(lang.code))", "-AppleLocale", lang.locale]
    }

    /// Bilder 1–3: Startseite, Liste „Lidl“, Ziel-Karte beim Tippen.
    private func captureListShots(_ lang: Language) throws {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-seedQuickAddAssignmentForUITests",
                                "-premiumForScreenshots", "-quickAddToastDurationForUITests", "1"]
            + languageArguments(lang)
        UITestLaunch.start(app, expecting: tile("Lidl", in: app), description: "Kachel „Lidl“")

        let field = app.textFields.element(boundBy: 0)
        tapWhenHittable(field, "Schnell-Eingabe")
        for item in lang.items {
            field.typeText(item)
            // Tasten kommen verspätet an (Lauf 2026-10-28: „Bread“ wurde als „Bre“ angelegt) — erst
            // Return, wenn der ganze Text im Feld steht.
            let typed = UITestWait.poll(timeout: UITestWait.defaultTimeout,
                                        read: { field.value as? String ?? "" }, done: { $0 == item })
            XCTAssertTrue(typed.matched, "Feld zeigt „\(typed.last)“ statt „\(item)“")
            XCTAssertTrue(element(app, "quickAdd.targetCard").waitForExistence(timeout: 10),
                          "Ziel-Karte für „\(item)“ fehlt")
            field.typeText("\n")
            waitUntilGone(element(app, "quickAdd.targetCard"))
        }
        dismissKeyboard(app)
        waitUntilGone(element(app, "quickAdd.toast"))
        settle()
        try save(app, lang, "01-start")

        tapWhenHittable(tile("Lidl", in: app), "Kachel „Lidl“")
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: UITestWait.defaultTimeout), "Liste „Lidl“ leer")
        settle()
        try save(app, lang, "02-liste")

        tapWhenHittable(app.navigationBars.buttons.firstMatch, "Zurück")
        let homeField = app.textFields.element(boundBy: 0)
        tapWhenHittable(homeField, "Schnell-Eingabe")
        homeField.typeText(lang.suggestion)
        _ = UITestWait.poll(timeout: UITestWait.defaultTimeout,
                            read: { homeField.value as? String ?? "" }, done: { $0 == lang.suggestion })
        let target = element(app, "quickAdd.target")
        let proposed = target.waitForLabel(contains: "dm")
        XCTAssertTrue(proposed.matched, "Ziel-Karte schlägt nicht „dm“ vor: \(proposed.lastLabel)")
        settle()
        try save(app, lang, "03-schnell-hinzufuegen")
        app.terminate()
    }

    /// Bild 4: Bon-Prüfung aus dem festen Bon-Seed.
    private func captureReceiptReview(_ lang: Language) throws {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-seedReceiptReviewForUITests", "-premiumForScreenshots"]
            + languageArguments(lang)
        app.launch()
        XCTAssertTrue(app.buttons["receiptReview.saveButton"].waitForExistence(timeout: 30),
                      "Bon-Prüf-Screen erscheint nicht")
        settle()
        try save(app, lang, "04-bon-pruefung")
        app.terminate()
    }

    /// Bild 5: Pro-Übersicht aus den Einstellungen, ohne Premium, Preise vom Ersatz-Appstore.
    private func capturePaywall(_ lang: Language) throws {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-purchaseScenarioForUITests", "success"]
            + languageArguments(lang)
        UITestLaunch.start(app, expecting: app.buttons["gearshape"], description: "Zahnrad")
        app.buttons["gearshape"].tap()
        let proRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Restock Pro")).firstMatch
        var swipes = 0
        while !proRow.exists && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        tapWhenHittable(proRow, "Zeile „Restock Pro …“")
        XCTAssertTrue(app.staticTexts["Restock Pro"].waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Pro-Übersicht erscheint nicht")
        settle(2)
        try save(app, lang, "05-pro")
        app.terminate()
    }

    /// Bild en/06: „Add Item“ mit Namen „Toothpaste“ (AddItemView, alle Texte über en.lproj-Schlüssel).
    private func captureAddItem(_ lang: Language) throws {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-seedQuickAddAssignmentForUITests",
                                "-premiumForScreenshots"] + languageArguments(lang)
        UITestLaunch.start(app, expecting: tile("Lidl", in: app), description: "Kachel „Lidl“")
        // Oberster „plus“-Knopf = Werkzeugleiste (die Kachel „Add Store“ trägt dasselbe Symbol weiter unten).
        let plus = app.buttons.matching(identifier: "plus").allElementsBoundByIndex
            .filter { $0.exists && $0.frame.minY.isFinite }
            .min { $0.frame.minY < $1.frame.minY }
        let addButton = try XCTUnwrap(plus, "Knopf „plus“ fehlt")
        tapWhenHittable(addButton, "Knopf „plus“")
        let name = app.textFields["Item name"]
        tapWhenHittable(name, "Feld „Item name“")
        name.typeText("Toothpaste")
        _ = UITestWait.poll(timeout: UITestWait.defaultTimeout,
                            read: { name.value as? String ?? "" }, done: { $0 == "Toothpaste" })
        settle()
        try save(app, lang, "06-artikel-hinzufuegen")
        app.terminate()
    }

    /// Bild en/07: Menüplan (Pro), leerer Plan nach `-clearMenuPlanForUITests` (MenuPlanView, alle Texte über en.lproj).
    private func captureMenuPlan(_ lang: Language) throws {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-premiumForScreenshots", "-clearMenuPlanForUITests"]
            + languageArguments(lang)
        UITestLaunch.start(app, expecting: app.buttons["fork.knife"], description: "Menüplan-Knopf fork.knife")
        app.buttons["fork.knife"].tap()
        XCTAssertTrue(app.buttons["Add Day"].waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Menüplan öffnet sich nicht")
        settle()
        try save(app, lang, "07-menueplan")
        app.terminate()
    }

    // MARK: - Hilfen

    private func tile(_ storeName: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(storeName),")).firstMatch
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func tapWhenHittable(_ element: XCUIElement, _ what: String) {
        let result = element.waitUntilHittable()
        XCTAssertTrue(result.matched, "\(what) nicht antippbar, zuletzt: \(result.last)")
        element.tap()
    }

    private func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval = UITestWait.defaultTimeout) {
        _ = UITestWait.poll(timeout: timeout, read: { element.exists }, done: { !$0 })
    }

    /// Leeres Feld + Return schließt die Tastatur (wie in `QuickAddAssignmentUITests`).
    private func dismissKeyboard(_ app: XCUIApplication) {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else { return }
        app.textFields.element(boundBy: 0).typeText("\n")
        waitUntilGone(keyboard, timeout: 10)
    }

    private func settle(_ seconds: TimeInterval = 1.5) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func save(_ app: XCUIApplication, _ lang: Language, _ name: String) throws {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "\(lang.code)-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
        let dir = outputDir.appendingPathComponent(lang.code, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try shot.pngRepresentation.write(to: dir.appendingPathComponent("\(name).png"))
    }
}
