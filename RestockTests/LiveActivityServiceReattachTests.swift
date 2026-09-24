import ActivityKit
import XCTest
@testable import Restock

/// Beweist den Fix für Issue #40 ("Live Activity läuft/erscheint weiter, obwohl der Nutzer die
/// Liste längst verlassen hat"). Reproduziert per echtem Simulator-Lauf gefundene Ursache:
/// `start(for:)`s Reattach-Suche (`LiveActivityService.swift`) prüfte nur den Store-Namen, nicht
/// `activityState`. Verlässt man eine Liste (→ `end()`, 4s Dismissal-Gnadenfrist) und öffnet sie
/// innerhalb dieser Frist erneut, hängt sich `start()` an die bereits beendete Activity und ruft
/// nur `.update()` auf ihr auf — ActivityKit ignoriert Updates auf einer bereits beendeten
/// Activity, es entsteht keine neue sichtbare Anzeige.
final class LiveActivityServiceReattachTests: XCTestCase {

    override func tearDown() async throws {
        // Aufräumen: eigene, eindeutig benannte Test-Stores nie über einen echten Testlauf hinweg
        // als aktive Activity stehen lassen.
        for activity in Activity<ShoppingActivityAttributes>.activities
            where activity.attributes.storeName.hasPrefix("ReattachTest-") {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    func testReopeningWithinDismissalGracePeriodStartsAFreshActiveActivity() async throws {
        try XCTSkipUnless(ActivityAuthorizationInfo().areActivitiesEnabled, "Live Activities im Testprozess deaktiviert")

        let store = Store(name: "ReattachTest-\(UUID().uuidString.prefix(8))", emoji: "🛒", colorHex: "#0050AA")
        let item = ShoppingItem(name: "Testartikel", store: store)
        store.items = [item]

        await LiveActivityService.shared.start(for: store)
        try await Task.sleep(for: .milliseconds(300))

        await LiveActivityService.shared.end(for: store)
        // Bewusst NICHT die vollen 4s Dismissal-Gnadenfrist abwarten — genau dieses Fenster ist
        // der Fehlerauslöser aus dem Bug-Report.
        try await Task.sleep(for: .milliseconds(500))

        await LiveActivityService.shared.start(for: store)
        try await Task.sleep(for: .milliseconds(300))

        let activeCount = Activity<ShoppingActivityAttributes>.activities
            .filter { $0.attributes.storeName == store.name && $0.activityState == .active }
            .count
        XCTAssertEqual(
            activeCount, 1,
            "Erneutes Öffnen der Liste innerhalb der Dismissal-Gnadenfrist muss eine neue AKTIVE Activity erzeugen, statt sich an die bereits beendete zu hängen"
        )
    }
}
