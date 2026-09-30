import XCTest
import SwiftData
@testable import Restock

/// TDD RED für Issue #52: „saitan" (Bon-OCR) gelernt, „seitan" (manuell eingegeben) fand den
/// gelernten Preis bisher nicht, weil `ShoppingItem.init` gelernte Preise nur per Teilstring
/// vergleicht. Diese Suite belegt den engen, konservativ kalibrierten Levenshtein-Fallback aus
/// `docs/specs/models/shopping-item-fuzzy-price-match.md` — noch bevor er implementiert ist, daher
/// schlagen alle Tests hier zunächst fehl (Kompilierfehler: `ShoppingItem.isFuzzyLearnedPriceMatch`
/// existiert noch nicht; sobald implementiert, greifen zusätzlich die einzelnen Assertions).
///
/// `isFuzzyLearnedPriceMatch(_:_:)` ist die für Phase 6 vorgesehene, isoliert testbare
/// Gate-Hilfsfunktion (Levenshtein-Distanz ≤ 1 UND kürzerer Name ≥ 5 Zeichen) — AC-2 und AC-5
/// prüfen sie direkt, weil ihre Namenspaare zufällig zusätzlich über die bestehende,
/// unveränderte Teilstring-Prüfung verknüpft sind und ein volles `ShoppingItem.init`-Szenario dort
/// nichts über die Fuzzy-Prüfung selbst aussagen würde (siehe Spec, Implementation Details).
final class ShoppingItemFuzzyPriceMatchTests: XCTestCase {

    // MARK: - AC-1: gemeldeter Fall — "saitan" gelernt, "seitan" eingegeben

    func testFuzzyMatchFindsLearnedPriceForTyposaitanSeitan() throws {
        let store = Store(name: "DM", emoji: "🛒", colorHex: "#123456")
        store.learnedPrices["saitan"] = 4.99
        store.learnedPriceUnits["saitan"] = "stk"

        let item = ShoppingItem(name: "Seitan", store: store)

        XCTAssertEqual(
            try XCTUnwrap(item.estimatedPrice), 4.99, accuracy: 0.0001,
            "Levenshtein-Distanz 1 bei 6 Zeichen (kürzerer Name 'seitan') muss den gelernten Preis finden"
        )
        XCTAssertFalse(
            item.estimatedPriceIsAutoDerived,
            "Ein per Fuzzy-Fallback gefundener gelernter Preis gilt als echt, nicht als Schätzung"
        )
    }

    // MARK: - AC-2: "reis"/"eis" — Längen-Gate weist ab (isolierte Gate-Prüfung)

    func testFuzzyGateRejectsReisEisBelowLengthGate() {
        XCTAssertFalse(
            ShoppingItem.isFuzzyLearnedPriceMatch("reis", "eis"),
            "Levenshtein-Distanz 1, aber kürzerer Name 'eis' hat nur 3 Zeichen — unter dem "
            + "Mindestlängen-Gate von 5. 'reis' enthält 'eis' als Teilstring und würde über die "
            + "bestehende Teilstring-Prüfung ohnehin schon matchen — deshalb hier isolierter "
            + "Nachweis der Gate-Funktion statt über ShoppingItem.init."
        )
    }

    // MARK: - AC-3: "milch"/"mehl" — Distanz über der Schwelle

    func testFuzzyMatchRejectsDistanceAboveThresholdMilchMehl() throws {
        let store = Store(name: "DM", emoji: "🛒", colorHex: "#123456")
        store.learnedPrices["milch"] = 1.19

        let item = ShoppingItem(name: "Mehl", store: store)

        XCTAssertTrue(
            item.estimatedPriceIsAutoDerived,
            "Levenshtein-Distanz 4 liegt über der Schwelle 1 — 'milch'/'mehl' haben zudem keine "
            + "bestehende Teilstring-Beziehung, der gelernte Preis darf also nicht übernommen werden"
        )
    }

    // MARK: - AC-4: "bananen"/"mandeln" — Distanz über der Schwelle

    func testFuzzyMatchRejectsDistanceAboveThresholdBananenMandeln() throws {
        let store = Store(name: "DM", emoji: "🛒", colorHex: "#123456")
        store.learnedPrices["bananen"] = 2.29

        let item = ShoppingItem(name: "Mandeln", store: store)

        XCTAssertTrue(
            item.estimatedPriceIsAutoDerived,
            "Levenshtein-Distanz 4 liegt über der Schwelle 1 — 'bananen'/'mandeln' haben zudem "
            + "keine bestehende Teilstring-Beziehung, der gelernte Preis darf also nicht "
            + "übernommen werden"
        )
    }

    // MARK: - AC-5: "apfel"/"apfelsaft" — Distanz über der Schwelle (isolierte Gate-Prüfung)

    func testFuzzyGateRejectsApfelApfelsaftAboveDistanceThreshold() {
        XCTAssertFalse(
            ShoppingItem.isFuzzyLearnedPriceMatch("apfel", "apfelsaft"),
            "Levenshtein-Distanz 4 liegt über der Schwelle 1. 'apfel' ist zudem ein Präfix von "
            + "'apfelsaft' und würde über die bestehende Teilstring-Prüfung ohnehin schon matchen "
            + "— deshalb hier isolierter Nachweis der Gate-Funktion statt über ShoppingItem.init."
        )
    }

    // MARK: - AC-6: mehrere fuzzy-Kandidaten — bestehendes Tie-Breaking entscheidet

    func testFuzzyMatchAppliesExistingTieBreakingAmongMultipleCandidates() throws {
        let store = Store(name: "DM", emoji: "🛒", colorHex: "#123456")
        // Beide Kandidaten haben Levenshtein-Distanz 1 zu "seitan" (Länge 6) und stehen
        // untereinander sowie zu "seitan" in keiner Teilstring-Beziehung.
        store.learnedPrices["saitan"] = 3.49
        store.learnedPriceUnits["saitan"] = "stk"
        store.learnedPriceDates["saitan"] = Date(timeIntervalSince1970: 1_000)

        store.learnedPrices["seiten"] = 5.99
        store.learnedPriceUnits["seiten"] = "stk"
        store.learnedPriceDates["seiten"] = Date(timeIntervalSince1970: 2_000) // jünger

        let item = ShoppingItem(name: "Seitan", store: store)

        XCTAssertEqual(
            try XCTUnwrap(item.estimatedPrice), 5.99, accuracy: 0.0001,
            "Bei mehreren fuzzy-passenden Kandidaten gewinnt derselbe bestehende Tie-Breaker wie "
            + "beim Teilstring-Match: zuerst jüngeres learnedPriceDates"
        )
    }

    // MARK: - AC-7: bestehender Teilstring-Treffer hat unbedingten Vorrang

    func testExistingSubstringMatchTakesPrecedenceOverFuzzyMatch() throws {
        let store = Store(name: "DM", emoji: "🛒", colorHex: "#123456")
        store.learnedPrices["hackfleisch gemischt 500g"] = 4.99
        store.learnedPriceUnits["hackfleisch gemischt 500g"] = "stk"

        let item = ShoppingItem(name: "Hackfleisch", store: store)

        XCTAssertEqual(
            try XCTUnwrap(item.estimatedPrice), 4.99, accuracy: 0.0001,
            "Der bestehende Teilstring-Treffer muss weiterhin unverändert greifen"
        )
        XCTAssertFalse(
            item.estimatedPriceIsAutoDerived,
            "Ein Teilstring-Treffer gilt als echter Preis, nicht als Schätzung"
        )
    }
}
