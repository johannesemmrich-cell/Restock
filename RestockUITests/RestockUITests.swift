import XCTest

/// Bewusst minimal gehalten: nur EIN Smoke-Test, der vorher einzeln gegen einen frisch
/// gebooteten Simulator (kein wiederverwendeter Entwicklungs-Simulator mit bereits erteilten
/// Berechtigungen/State) verifiziert wurde. Onboarding wird über den Standard-"-key value"
/// Kommandozeilen-Trick übersprungen (NSUserDefaults liest `-hasCompletedOnboarding YES` in
/// die Argument-Domain ein, exakt das, was `@AppStorage("hasCompletedOnboarding")` in
/// SmartCartApp.swift abfragt) — kein App-Code dafür nötig. Löst weder Kamera- noch
/// Foto-Bibliotheks-Berechtigung aus (HomeView triggert das nicht beim Erscheinen) und ruft
/// keinen FoundationModels-Pfad auf (die sind laut Code-Review nur hinter explizit geöffneten
/// Sheets für Rezept-Erkennung/Beleg-Scan erreichbar, nicht auf dem Home-Screen).
final class RestockUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunchesToHomeScreen() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES"]
        app.launch()

        // Kein system NavigationBar-Titel: HomeView versteckt die Standard-Nav-Bar und zeigt
        // "Restock" stattdessen als großen, hartkodierten (nicht lokalisierten) Text im
        // Hero-Card oben auf dem Screen — bestätigt per Screenshot während der Entwicklung
        // dieses Tests.
        XCTAssertTrue(
            app.staticTexts["Restock"].waitForExistence(timeout: 15),
            "HomeView-Hero-Titel \"Restock\" wurde nicht innerhalb von 15s angezeigt"
        )
    }
}
