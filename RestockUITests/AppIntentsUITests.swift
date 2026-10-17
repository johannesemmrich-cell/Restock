#if canImport(AppIntentsTesting) && APPINTENTS_UITESTS
import AppIntentsTesting
import XCTest

/// Issue #145, Durchgang 3: Siri-/Kurzbefehl-Intents über den Systemweg. `AppIntentsTesting` (Xcode 27, iOS 27)
/// löst die Intents über die App-Metadaten auf und führt sie im eigenen Prozess aus, wie Siri und Kurzbefehle.
/// Geprüft wird immer der Zustand der App-Oberfläche, nie das `run()`-Ergebnis: das meldet auch Erfolg, wenn nichts
/// passiert (Gegenprobe T3). Ohne `APPINTENTS_UITESTS` ist diese Datei leer, weil das Bündel mit dem Framework auf
/// iOS 26 gar nicht lädt; nur `scripts/run-appintents-uitest.sh` setzt die Bedingung (iOS-27-Wegwerf-Simulator).
/// Spec: `docs/specs/ui-tests/test-145-durchgang-3-app-intents.md`.
///
/// **Offene Grenzen:** kein Siri-Ruf per Stimme, Dialogtext nicht lesbar, kein Tipp auf Widget, Live Activity oder
/// Control; nicht in der CI (xcode-27-Runner nur Vorschau, Signierungsfehler 800 dort unbelegt); Fehler 400
/// „is not present“ unter Last wird nur wiederholt, nicht erklärt; `CheckOffItemIntent` meldet ohne Live Activity
/// Erfolg ohne Wirkung; seit #150 ist er für Siri, Spotlight und Kurzbefehle verborgen (`isDiscoverable = false`),
/// T3 bleibt Gegenprobe der Ausführbarkeit; Kurzbefehle-App-Oberfläche und Knopftipp nicht automatisiert geprüft;
/// nichts auf Hennings Geräten geprüft.
final class AppIntentsUITests: XCTestCase {

    private static let bundleID = "com.johannesemmrich.Restock"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Der App-Group-Container überlebt den Test (siehe CLAUDE.md): Seed und per Intent angelegte Artikel räumen.
    override func tearDown() {
        super.tearDown()
        let cleaner = XCUIApplication()
        cleaner.launchArguments = ["-hasCompletedOnboarding", "YES", "-clearQuickAddAssignmentSeedForUITests"]
        cleaner.launch()
        cleaner.terminate()
    }

    private func tile(_ app: XCUIApplication, _ store: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(store),")).firstMatch
    }

    private func listLabels(_ app: XCUIApplication) -> [String] {
        app.staticTexts.allElementsBoundByIndex.map(\.label)
    }

    /// Läden Lidl und dm säen; die App bleibt laufen, weil `run()` eine laufende App braucht.
    private func launchSeeded() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-seedQuickAddAssignmentForUITests"]
        UITestLaunch.start(app, expecting: tile(app, "dm"), description: "Kachel „dm“")
        return app
    }

    /// Neustart ohne Seed: die App liest den Stand, den der Intent-Prozess geschrieben hat.
    private func relaunch(_ app: XCUIApplication) -> XCUIApplication {
        app.terminate()
        let fresh = XCUIApplication()
        fresh.launchArguments += ["-hasCompletedOnboarding", "YES"]
        fresh.launch()
        XCTAssertTrue(tile(fresh, "dm").waitUntilHittable().matched, "Kachel „dm“ nach Neustart fehlt")
        return fresh
    }

    @available(iOS 27.0, *)
    private func add(_ name: String) async throws {
        let intents = IntentDefinitions(bundleIdentifier: Self.bundleID).intents
        try await AppIntentRetry.runIntentRetrying("AddShoppingItemIntent(\(name))") {
            _ = try await intents["AddShoppingItemIntent"].makeIntent(itemName: name).run()
        }
    }

    @available(iOS 27.0, *)
    private func checkOff(store: String) async throws {
        let intents = IntentDefinitions(bundleIdentifier: Self.bundleID).intents
        try await AppIntentRetry.runIntentRetrying("CheckOffItemIntent(\(store))") {
            _ = try await intents["CheckOffItemIntent"].makeIntent(storeName: store).run()
        }
    }

    /// Öffnet die Liste von dm und wartet auf den Zähler „<n> von 2 erledigt“.
    private func openDM(_ app: XCUIApplication, expecting count: Int) {
        let dm = tile(app, "dm")
        XCTAssertTrue(dm.waitUntilHittable().matched, "Kachel „dm“ nicht antippbar")
        dm.tap()
        XCTAssertTrue(app.staticTexts["\(count) von 2 erledigt"].waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Zähler „\(count) von 2 erledigt“ fehlt, Liste: \(listLabels(app))")
    }

    /// AC-1: Ein Drogerie-Artikel per Siri-Intent landet in dm, nicht in Lidl.
    @MainActor
    func testAddIntentPutsItemIntoDm() async throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("AppIntentsTesting braucht iOS 27.0") }
        let seeded = launchSeeded()
        try await add("Zahnpasta")
        let app = relaunch(seeded)

        XCTAssertTrue(tile(app, "dm").waitForLabel(contains: "Zahnpasta").matched, "Zahnpasta fehlt in der Kachel dm")
        XCTAssertFalse(tile(app, "Lidl").label.contains("Zahnpasta"), "Zahnpasta darf nicht in der Kachel Lidl stehen")
        tile(app, "dm").tap()
        XCTAssertTrue(app.staticTexts["Zahnpasta"].waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Zahnpasta fehlt in der Liste von dm: \(listLabels(app))")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(tile(app, "Lidl").waitUntilHittable().matched, "Kachel „Lidl“ nicht antippbar")
        tile(app, "Lidl").tap()
        XCTAssertTrue(app.staticTexts["Lidl"].waitForExistence(timeout: UITestWait.defaultTimeout))
        XCTAssertFalse(app.staticTexts["Zahnpasta"].exists, "Zahnpasta darf nicht in der Liste von Lidl stehen")
    }

    /// AC-2: Liste offen (Live Activity läuft), App im Hintergrund, Abhaken per Intent → nach dem Aktivieren ist der
    /// erste Artikel erledigt, der zweite offen.
    @MainActor
    func testCheckOffIntentChecksFirstItem() async throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("AppIntentsTesting braucht iOS 27.0") }
        let seeded = launchSeeded()
        try await add("Zahnpasta")
        try await add("Duschgel")
        let app = relaunch(seeded)
        openDM(app, expecting: 0)

        XCUIDevice.shared.press(.home)
        try await checkOff(store: "dm")
        app.activate()

        XCTAssertTrue(app.staticTexts["1 von 2 erledigt"].waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Nach dem Aktivieren muss genau ein Artikel erledigt sein, Liste: \(listLabels(app))")
        let labels = listLabels(app)
        let done = try XCTUnwrap(labels.firstIndex(of: "Erledigt"), "Abschnitt „Erledigt“ fehlt: \(labels)")
        XCTAssertGreaterThan(try XCTUnwrap(labels.firstIndex(of: "Zahnpasta")), done, "Zahnpasta muss erledigt sein")
        XCTAssertLessThan(try XCTUnwrap(labels.firstIndex(of: "Duschgel")), done, "Duschgel muss offen bleiben")
        // Liste schließen beendet die Live Activity.
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    /// AC-3 (Gegenprobe zu AC-2): Die Liste wurde in diesem Lauf nie geöffnet, für diese Artikel läuft keine Live
    /// Activity; der Intent meldet Erfolg, ändert aber nichts.
    @MainActor
    func testCheckOffWithClosedListChangesNothing() async throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("AppIntentsTesting braucht iOS 27.0") }
        let seeded = launchSeeded()
        try await add("Zahnpasta")
        try await add("Duschgel")
        let app = relaunch(seeded)

        try await checkOff(store: "dm")
        openDM(app, expecting: 0)
        XCTAssertFalse(app.staticTexts["Erledigt"].exists, "Ohne Live Activity darf nichts erledigt sein: \(listLabels(app))")
    }
}
#endif
