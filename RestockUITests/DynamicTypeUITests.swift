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
        app.launch()
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
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-seedReceiptReviewForUITests"] + Self.launchArguments
        app.launch()
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
}
