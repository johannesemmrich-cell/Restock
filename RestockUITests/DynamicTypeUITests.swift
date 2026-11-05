import XCTest
import UIKit

/// Issue #99, Paket 3 (PO-Entscheidung 2026-10-21, Punkt 4): zwei gezielte UI-Tests mit der größten
/// Bedienhilfen-Schriftgröße statt eines vollen Laufs in jeder Größe. Die Größe kommt über das
/// UIKit-Launch-Argument `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL`
/// (Argument-Domain nur dieses Prozesses, kein Zustand in der App-Gruppe, nichts aufzuräumen).
///
/// T1 prüft den Spaltenkopf „Gesamt“ der Bon-Auflösung (Issue #93: dort war er schon in
/// Normalgröße auf „Gesa…“ gekürzt, ohne dass ein Test es fing). T2 fährt Bon-Prüf-Screen und
/// Ladenliste: die Bedienelemente müssen auch in XXXL im Fenster liegen und antippbar sein.
///
/// Gekürzter Text ist von außen nicht am Label erkennbar (XCUITest liefert immer den vollen
/// Text). Geprüft wird deshalb die gerenderte Breite gegen die Breite, die der Text in seiner
/// Schrift mindestens braucht (`minimumScaleFactor` eingerechnet) — dasselbe Muster wie P11 in
/// `PurchaseUITests` für den Schließen-Chip.
///
/// Testsprache: deutsch über den Scheme-Test-Action (siehe Kopfkommentar `RestockUITests.swift`).
final class DynamicTypeUITests: XCTestCase {

    /// Größte Bedienhilfen-Stufe (AX5). Name wie in `UIContentSizeCategory.accessibilityExtraExtraExtraLarge`.
    static let contentSizeCategory = "UICTContentSizeCategoryAccessibilityXXXL"
    static let launchArguments = ["-UIPreferredContentSizeCategoryName", contentSizeCategory]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDown() {
        super.tearDown()
        // T2 speichert den gesäten Bon: Seed (Laden, Artikel, Kaufdatensätze) und der dabei
        // hochgezählte Bon-Auflösungs-Zähler liegen in der App-Gruppe und müssen weg.
        let cleaner = XCUIApplication()
        cleaner.launchArguments = [
            "-hasCompletedOnboarding", "YES",
            "-clearReceiptReviewSeedForUITests",
            "-clearReceiptResolutionStatsForUITests",
            "-clearDiscardedCommunityPricesForUITests",
        ]
        cleaner.launch()
        cleaner.terminate()
    }

    // MARK: - Hilfen

    private func waitUntilSettled(_ app: XCUIApplication) {
        let isForeground = NSPredicate(format: "state == %d", XCUIApplication.State.runningForeground.rawValue)
        expectation(for: isForeground, evaluatedWith: app)
        waitForExpectations(timeout: 30)
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Wischt nach oben, bis das Element im Bedienhilfen-Baum ist, und zieht dann in kurzen Zügen
    /// nach, bis es antippbar ist (in XXXL liegt fast alles unter dem Rand).
    ///
    /// Zwei Fehlbilder aus den CI-Läufen: Eine `List` hält nur sichtbare Zeilen im Baum, was unter
    /// dem Rand liegt, existiert noch nicht (Lauf 39563379941: „fehlt“ nach 20 s Warten ohne Wisch).
    /// Und wer wischt, bis das Element antippbar ist, wischt an einer halb verdeckten Zeile vorbei
    /// bis zum Listenende, wo sie wieder aus dem Baum fällt (Lauf 39573224713, Wiederholung: „fehlt
    /// auch nach 30 Wischern“). Deshalb: Wischen nur bis zur Existenz, danach höchstens vier kurze
    /// Züge um 30 % der Bildschirmhöhe. Scheitert mit dem zuletzt gesehenen Zustand, nie mit
    /// „failed to scroll“.
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
                      "\(description) ist auch nach \(swipes) Wischern und \(nudges) kurzen Zügen nicht antippbar — zuletzt: \(ready.last)",
                      file: file, line: line)
    }

    /// Das Element liegt waagerecht im Fenster (1 pt Toleranz für Rundung). Senkrecht wird nicht
    /// geprüft: Listen scrollen, ein Überstand nach rechts ist dagegen verlorener Text.
    private func assertInsideWindowHorizontally(_ app: XCUIApplication, _ target: XCUIElement, description: String,
                                                file: StaticString = #filePath, line: UInt = #line) {
        let window = app.windows.firstMatch.frame
        let frame = target.frame
        XCTAssertTrue(frame.minX >= window.minX - 1 && frame.maxX <= window.maxX + 1,
                      "\(description) ragt aus dem Fenster: \(frame) in \(window)", file: file, line: line)
    }

    /// Breite, die `text` in der Dynamic-Type-Schrift `style` bei Stufe XXXL mindestens braucht,
    /// wenn die Ansicht bis `minimumScaleFactor` verkleinern darf. Gemessen im Testläufer mit
    /// derselben UIKit-Schrifttabelle, die SwiftUI für `.font(.caption)` usw. benutzt.
    static func requiredWidth(for text: String, style: UIFont.TextStyle, minimumScaleFactor: CGFloat) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
        let font = UIFont.preferredFont(forTextStyle: style, compatibleWith: traits)
        let width = (text as NSString).size(withAttributes: [.font: font]).width
        return (width * minimumScaleFactor).rounded(.down)
    }

    /// Öffnet die Einstellungen und prüft, dass sie wirklich offen sind. In beiden Wiederholungsläufen
    /// (39573224713, 39581094360) kam der erste Tipp auf das Zahnrad nach dem Kaltstart nicht an: Die
    /// 30 Wischer suchten den Link auf der Startseite und meldeten „fehlt“, während derselbe Code im
    /// warmen ersten Durchlauf traf (bekanntes Bild aus `StoreSetupUITests.openSetup`). Deshalb
    /// höchstens ein zweiter Tipp, mit Messzeile — keine stille Abhilfe.
    private func openSettings(_ app: XCUIApplication, function: String = #function) {
        let gear = app.buttons.matching(NSPredicate(
            format: "identifier == 'gearshape' OR label CONTAINS[c] 'Einstellungen'")).firstMatch
        let settingsBar = app.navigationBars["Einstellungen"]
        let ready = gear.waitUntilHittable()
        XCTAssertTrue(ready.matched, "Einstellungen-Knopf (Zahnrad) nicht antippbar — zuletzt: \(ready.last)")
        let firstTap = Date()
        gear.tap()
        if !settingsBar.waitForExistence(timeout: 10) {
            let again = gear.waitUntilHittable(timeout: 0)
            if again.matched {
                let load = UITestLaunch.loadAverage().map {
                    String(format: "%.1f/%.1f/%.1f", locale: Locale(identifier: "en_US_POSIX"), $0.0, $0.1, $0.2)
                } ?? "unbekannt"
                let since = String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"),
                                   Date().timeIntervalSince(firstTap))
                NSLog("%@", "DynamicTypeUITests: zweiter Tipp auf das Zahnrad nötig — seit erstem Tipp \(since) s, "
                      + "Zahnrad: \(again.last), Last \(load) [\(function)]")
                gear.tap()
            }
        }
        XCTAssertTrue(settingsBar.waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Einstellungen nicht geöffnet.")
    }

    // MARK: - T1: Spaltenkopf „Gesamt“ der Bon-Auflösung (#93) in XXXL

    func testResolutionStatsHeaderGesamtFitsAtLargestAccessibilitySize() {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-developerMode", "YES",
                                "-clearReceiptResolutionStatsForUITests"] + Self.launchArguments
        // Start über den Helfer (Issue #105/#128): Der erste Start einer Testsitzung kommt gelegentlich ohne
        // Launch-Argumente an. In der #173-Wiederholung ist der Test immer der erste Start — dreimal belegt
        // (39573224713, 39581094360: kein Dev-Modus, „Link fehlt nach 30 Wischern“). Die DEV-Pill gibt es
        // nur mit `-developerMode YES`, sie ist deshalb die Gegenprobe.
        UITestLaunch.start(app, expecting: app.staticTexts["DEV"], description: "DEV-Pill (Entwicklermodus)")
        waitUntilSettled(app)

        openSettings(app)
        // In XXXL ist die Einstellungsliste um ein Mehrfaches länger als in Normalgröße.
        let link = app.buttons["Bon-Auflösung"]
        scrollUntilHittable(app, link, description: "Link „Bon-Auflösung“ (Entwicklermodus)", maxSwipes: 30)
        link.tap()
        XCTAssertTrue(app.navigationBars["Bon-Auflösung"].waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Bildschirm „Bon-Auflösung“ öffnet sich nicht.")

        // Die Kopfzeile wird in Listen groß geschrieben angezeigt; das Label kann „Gesamt“ oder
        // „GESAMT“ lauten — deshalb ohne Rücksicht auf Groß-/Kleinschreibung.
        let header = app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Gesamt")).firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Spaltenkopf „Gesamt“ fehlt auf dem Bildschirm „Bon-Auflösung“.")
        assertInsideWindowHorizontally(app, header, description: "Spaltenkopf „Gesamt“")

        // Kopfzeile (Normalgröße: `.font(.caption)`, `.lineLimit(1)`, `.minimumScaleFactor(0.7)`,
        // ReceiptResolutionStatsView.columns) bzw. Beschriftung je Stufe (Bedienhilfen-Größen,
        // `labeledValue`, ebenfalls `.caption`). Erster Messlauf 39573224713 ohne Fix: 40 pt statt 100 pt.
        // Kleinschreibung als Untergrenze; die Großschreibung der Anzeige braucht eher mehr Platz.
        let needed = Self.requiredWidth(for: "Gesamt", style: .caption1, minimumScaleFactor: 0.7)
        let width = header.frame.width
        XCTAssertGreaterThanOrEqual(width, needed,
            "Spaltenkopf „Gesamt“ ist in XXXL nur \(width) pt breit, der Text braucht mindestens \(needed) pt "
            + "(caption bei AX5, Skalierung bis 0,7) — Anzeige gekürzt wie in #93.")

        // Die Werte der Summenzeile bleiben im Fenster und lesbar. In XXXL liegt die Summenzeile unter
        // dem Rand und ist dort nicht im Baum (Lauf 39581094360: „fehlt“) — erst hinscrollen.
        let allTotal = element(app, "resolutionStage.all.total")
        scrollUntilHittable(app, allTotal, description: "Wert „Gesamt“ der Summenzeile „Alle Stufen“")
        assertInsideWindowHorizontally(app, allTotal, description: "Wert „Gesamt“ der Summenzeile")
        XCTAssertNotNil(Int(allTotal.label.prefix { $0.isNumber }),
                        "Wert „Gesamt“ der Summenzeile beginnt nicht mit einer Zahl: „\(allTotal.label)“")
    }

    // MARK: - T2: Bon-Prüf-Screen und Ladenliste in XXXL

    func testReceiptReviewAndStoreListStayUsableAtLargestAccessibilitySize() {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-seedReceiptReviewForUITests",
                                "-communityPricesNoticeShown", "YES", "-discardCommunityPricesForUITests"] + Self.launchArguments
        // Gegenprobe auf den Seed, siehe T1: ohne Argumente gäbe es keinen Prüf-Screen.
        UITestLaunch.start(app, expecting: element(app, "receiptReview.sectionHeader"),
                           description: "Kopfzeile des Bon-Prüf-Screens (Seed)")
        waitUntilSettled(app)
        XCTAssertTrue(app.navigationBars["Bon scannen — Lidl"].waitForExistence(timeout: 30),
                      "Das Bon-Prüf-Sheet ist nicht erschienen — Seed oder Handoff greift nicht.")

        // Bon-Prüf-Screen: Kopfzeile, erste Karte, Bon-Text und Häkchen im Fenster und bedienbar.
        let sectionHeader = element(app, "receiptReview.sectionHeader")
        XCTAssertTrue(sectionHeader.waitForExistence(timeout: UITestWait.defaultTimeout), "Kopfzeile des Prüf-Screens fehlt.")
        assertInsideWindowHorizontally(app, sectionHeader, description: "Kopfzeile des Prüf-Screens")

        let originalName = element(app, "receiptReview.line.0.originalName")
        XCTAssertTrue(originalName.waitForExistence(timeout: UITestWait.defaultTimeout), "Bon-Text der ersten Zeile fehlt.")
        assertInsideWindowHorizontally(app, originalName, description: "Bon-Text der ersten Zeile")

        let checkbox = element(app, "receiptReview.line.0.checkbox")
        scrollUntilHittable(app, checkbox, description: "Häkchen der ersten Zeile")
        assertInsideWindowHorizontally(app, checkbox, description: "Häkchen der ersten Zeile")

        let save = app.buttons["receiptReview.saveButton"]
        let saveReady = save.waitUntilHittable()
        XCTAssertTrue(saveReady.matched, "„Speichern“ ist in XXXL nicht antippbar — zuletzt: \(saveReady.last)")
        assertInsideWindowHorizontally(app, save, description: "„Speichern“-Chip")
        save.tap()

        // Ladenliste: Kachel „Lidl“ auf der Startseite, dann Schnelleingabe und Artikelzeile.
        let lidlTile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Lidl,")).firstMatch
        scrollUntilHittable(app, lidlTile, description: "Kachel „Lidl“")
        lidlTile.tap()

        let quickAdd = app.textFields["Schnell hinzufügen…"]
        XCTAssertTrue(quickAdd.waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Schnelleingabe-Feld der Ladenliste fehlt.")
        assertInsideWindowHorizontally(app, quickAdd, description: "Schnelleingabe-Feld")

        let milch = app.staticTexts["Milch"].firstMatch
        scrollUntilHittable(app, milch, description: "Artikelzeile „Milch“")
        assertInsideWindowHorizontally(app, milch, description: "Artikelzeile „Milch“")

        let more = element(app, "storeDetail.moreMenu")
        XCTAssertTrue(more.waitForExistence(timeout: UITestWait.defaultTimeout), "···-Menü der Ladenliste fehlt.")
        assertInsideWindowHorizontally(app, more, description: "···-Menü der Ladenliste")
    }

    // MARK: - Issues #214/#181: Rechtstexte und Rezeptplan-Hinweis in XXXL

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func legalText(_ app: XCUIApplication, _ predicate: String, _ args: CVarArg...) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: predicate, argumentArray: args)).firstMatch
    }

    private func openLegalDocument(_ app: XCUIApplication, _ title: String) {
        let row = app.buttons[title]
        scrollUntilHittable(app, row, description: "Zeile „\(title)“")
        row.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: UITestWait.defaultTimeout),
                      "„\(title)“ öffnet sich nicht.")
    }

    private func closeLegalDocument(_ app: XCUIApplication) {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    func testLegalTextsRenderParagraphsAtLargestAccessibilitySize() {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES"] + Self.launchArguments
        UITestLaunch.start(app, expecting: app.buttons["gearshape"], description: "Zahnrad der Startseite")
        waitUntilSettled(app)
        openSettings(app)
        let legalRow = app.buttons["Rechtliches"]
        scrollUntilHittable(app, legalRow, description: "Zeile „Rechtliches“", maxSwipes: 30)
        legalRow.tap()

        // AC-11: Datenschutzerklärung
        openLegalDocument(app, "Datenschutzerklärung")
        let heading = app.staticTexts["1. Verantwortlicher"]
        XCTAssertTrue(heading.waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Überschrift „1. Verantwortlicher“ ist kein eigenes Textelement (alles ein Block?).")
        XCTAssertFalse(legalText(app, "label CONTAINS %@ AND label CONTAINS %@", "Stand: Oktober 2026", "1. Verantwortlicher").exists,
                       "Titel und Abschnitt 1 stehen im selben Textelement.")
        for raw in ["———", "---"] {
            XCTAssertFalse(legalText(app, "label CONTAINS %@", raw).exists, "Rohe Trennlinie „\(raw)“ sichtbar.")
        }
        let address = legalText(app, "label BEGINSWITH %@ AND label CONTAINS %@ AND NOT label CONTAINS %@",
                                "Johannes Emmrich", "Eichenaue 14", "2. Welche Daten")
        XCTAssertTrue(address.waitForExistence(timeout: UITestWait.defaultTimeout), "Adress-Absatz fehlt.")
        assertInsideWindowHorizontally(app, heading, description: "Überschrift „1. Verantwortlicher“")
        assertInsideWindowHorizontally(app, address, description: "Adress-Absatz")  // AC-14
        attach(app, "datenschutz-xxxl")
        closeLegalDocument(app)

        // AC-12: Nutzungsbedingungen und Impressum
        openLegalDocument(app, "Nutzungsbedingungen")
        XCTAssertTrue(app.staticTexts["1. Geltungsbereich"].waitForExistence(timeout: UITestWait.defaultTimeout),
                      "„1. Geltungsbereich“ ist kein eigenes Textelement.")
        XCTAssertFalse(legalText(app, "label CONTAINS %@", "———").exists, "Rohe Trennlinie in den Nutzungsbedingungen.")
        attach(app, "nutzungsbedingungen-xxxl")
        closeLegalDocument(app)

        openLegalDocument(app, "Impressum")
        XCTAssertTrue(app.staticTexts["Anbieter"].waitForExistence(timeout: UITestWait.defaultTimeout),
                      "„Anbieter“ ist kein eigenes Textelement.")
        XCTAssertFalse(legalText(app, "label CONTAINS %@ AND label CONTAINS %@", "Anbieter", "Urheberrecht").exists,
                       "Impressum ist ein einziger Block.")
        XCTAssertFalse(legalText(app, "label CONTAINS %@", "———").exists, "Rohe Trennlinie im Impressum.")
        attach(app, "impressum-xxxl")
        closeLegalDocument(app)
    }

    func testRecipePlanHintShowsArrowAtLargestAccessibilitySize() {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-developerMode", "NO",
                                "-premiumForScreenshots", "-clearMenuPlanForUITests"] + Self.launchArguments
        UITestLaunch.start(app, expecting: app.buttons["fork.knife"], description: "Rezeptplan-Knopf (Startseite)")
        waitUntilSettled(app)
        let plan = app.buttons["fork.knife"]
        XCTAssertTrue(plan.waitUntilHittable().matched, "Rezeptplan-Knopf nicht antippbar.")
        plan.tap()

        let hint = legalText(app, "label BEGINSWITH %@", "Noch keine Rezepte gespeichert")
        _ = hint.waitForExistence(timeout: 3)
        var swipes = 0
        while !hint.exists && swipes < 12 { app.swipeUp(); swipes += 1 }
        XCTAssertTrue(hint.waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Hinweis fehlt (gespeicherte Rezepte im Simulator vorhanden?)")
        XCTAssertTrue(hint.label.contains("\u{2192}"), "Pfeil fehlt im Hinweis: \(hint.label)")
        XCTAssertFalse(hint.label.contains("u{2192}"), "Kaputter Pfeil im Hinweis: \(hint.label)")
        // Für die Aufnahme ganz ins Fenster ziehen, damit der Pfeil im Bild ist (AC-16).
        let window = app.windows.firstMatch.frame
        var nudges = 0
        while hint.frame.maxY > window.maxY - 20 && nudges < 6 {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
            nudges += 1
        }
        XCTAssertLessThanOrEqual(hint.frame.maxY, window.maxY, "Hinweis liegt nicht ganz im Fenster.")
        attach(app, "rezeptplan-hinweis-xxxl")
    }
}
