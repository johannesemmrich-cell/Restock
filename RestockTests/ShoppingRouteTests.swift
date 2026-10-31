import XCTest
@testable import Restock

/// Issue #79: Ladenliste nach gelerntem Einkaufsweg sortieren. Reine Logik in `ShoppingRoute`
/// (ohne SwiftData/UserDefaults), Spec: `docs/specs/models/shopping-route-order.md`.
final class ShoppingRouteTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private let staticOrder = ["Obst & Gemüse", "Brot", "Käse", "Milch", "Drogerie"]

    /// Einkauf aus `(key, category)` im Abstand von 30 s (im Laden, nicht nachgetragen).
    private func trip(_ items: [(String, String)], gap: TimeInterval = 30, start: Date? = nil) -> ShoppingTrip {
        let begin = start ?? t0
        return ShoppingTrip(entries: items.enumerated().map { index, item in
            .init(key: item.0, category: item.1, date: begin.addingTimeInterval(Double(index) * gap), batched: false)
        })
    }

    private func input(_ key: String, _ category: String, urgent: Bool = false, added: TimeInterval = 0) -> ShoppingRoute.SortInput {
        .init(key: key, category: category, isUrgent: urgent, addedDate: t0.addingTimeInterval(added))
    }

    private func sortedKeys(_ items: [ShoppingRoute.SortInput], _ mode: StoreSortMode, _ model: ShoppingRouteModel) -> [String] {
        ShoppingRoute.sortedIndices(items, mode: mode, model: model, staticCategoryOrder: staticOrder).map { items[$0].key }
    }

    // MARK: Schlüssel

    func testItemKeyIgnoresOnlyFormalDifferences() {
        XCTAssertEqual(ShoppingRoute.itemKey("  Milch. "), "milch")
        XCTAssertEqual(ShoppingRoute.itemKey("Bio   Milch"), "bio milch")
        XCTAssertEqual(ShoppingRoute.itemKey("H-Milch"), "h-milch")
        XCTAssertNotEqual(ShoppingRoute.itemKey("H-Milch"), ShoppingRoute.itemKey("Milch"))
    }

    func testReplenishmentFormalKeyUsesSameKey() {
        for name in ["  Milch. ", "H-Milch", "Eier (10)", "Milch 1,5%"] {
            XCTAssertEqual(ReplenishmentItemIdentity.formalKey(name), ShoppingRoute.itemKey(name))
        }
    }

    // MARK: Lernen

    func testFirstTripSetsNormalizedPositions() {
        let model = ShoppingRoute.learn(
            trip([("banane", "Obst & Gemüse"), ("brot", "Brot"), ("gouda", "Käse"), ("milch", "Milch"), ("zahnpasta", "Drogerie")]),
            into: ShoppingRouteModel()
        )
        XCTAssertEqual(model.itemPositions["banane"], 0)
        XCTAssertEqual(model.itemPositions["brot"], 0.25)
        XCTAssertEqual(model.itemPositions["gouda"], 0.5)
        XCTAssertEqual(model.itemPositions["milch"], 0.75)
        XCTAssertEqual(model.itemPositions["zahnpasta"], 1)
        XCTAssertEqual(model.itemCategories["gouda"], "Käse")
    }

    func testNormalizedPositionIndependentOfTripLength() {
        // Milch als letzter von 3 und als letzter von 5 Artikeln: beide Male Ende des Weges.
        let short = ShoppingRoute.learn(trip([("a", "x"), ("b", "x"), ("milch", "Milch")]), into: ShoppingRouteModel())
        let long = ShoppingRoute.learn(trip([("a", "x"), ("b", "x"), ("c", "x"), ("d", "x"), ("milch", "Milch")]), into: ShoppingRouteModel())
        XCTAssertEqual(short.itemPositions["milch"], 1)
        XCTAssertEqual(long.itemPositions["milch"], 1)
    }

    func testLaterTripMovesPositionByLearningRate() {
        var model = ShoppingRouteModel()
        model.itemPositions["milch"] = 0
        model.itemCategories["milch"] = "Milch"
        // Volles Gewicht ab 5 Artikeln: Milch diesmal am Ende → 0 + 0,3 × (1 − 0) = 0,3.
        let learned = ShoppingRoute.learn(trip([("a", "x"), ("b", "x"), ("c", "x"), ("d", "x"), ("milch", "Milch")]), into: model)
        XCTAssertEqual(learned.itemPositions["milch"]!, 0.3, accuracy: 1e-9)
    }

    func testSmallTripLearnsWithReducedWeight() {
        var model = ShoppingRouteModel()
        model.itemPositions["milch"] = 0
        // 2 Artikel: Gewicht (2 − 1) / (5 − 1) = 0,25 → 0 + 0,3 × 0,25 × 1 = 0,075.
        let learned = ShoppingRoute.learn(trip([("a", "x"), ("milch", "Milch")]), into: model)
        XCTAssertEqual(learned.itemPositions["milch"]!, 0.075, accuracy: 1e-9)
    }

    func testSingleItemTripIsNotLearned() {
        let model = ShoppingRoute.learn(trip([("milch", "Milch")]), into: ShoppingRouteModel())
        XCTAssertTrue(model.itemPositions.isEmpty)
    }

    func testBulkCheckOffAtHomeIsNotLearned() {
        let bulk = trip([("a", "x"), ("b", "x"), ("c", "x"), ("d", "x")], gap: 1)
        XCTAssertTrue(ShoppingRoute.isBulkCheckOff(bulk))
        XCTAssertEqual(ShoppingRoute.learn(bulk, into: ShoppingRouteModel()), ShoppingRouteModel())
    }

    func testTwoQuickNeighboursInStoreAreStillLearned() {
        // Nebeneinander stehende Artikel schnell hintereinander — der Rest im normalen Tempo.
        var t = trip([("a", "x"), ("b", "x"), ("c", "x"), ("d", "x"), ("e", "x")], gap: 40)
        t.entries[2].date = t.entries[1].date.addingTimeInterval(1)
        XCTAssertFalse(ShoppingRoute.isBulkCheckOff(t))
        XCTAssertEqual(ShoppingRoute.learn(t, into: ShoppingRouteModel()).itemPositions.count, 5)
    }

    func testBatchedQueueEntriesDoNotCountAsBulk() {
        // Per Dynamic Island abgehakt, beim Öffnen der App in einem Rutsch nachgetragen.
        var t = trip([("a", "x"), ("b", "x"), ("c", "x"), ("d", "x")], gap: 0.01)
        for i in t.entries.indices { t.entries[i].batched = true }
        XCTAssertFalse(ShoppingRoute.isBulkCheckOff(t))
        XCTAssertEqual(ShoppingRoute.learn(t, into: ShoppingRouteModel()).itemPositions["d"], 1)
    }

    // MARK: Aufzeichnen

    func testCheckOffsWithinTripGapContinueSameTrip() {
        var state = (trip: ShoppingTrip(), model: ShoppingRouteModel())
        state = ShoppingRoute.recordCheckOff(key: "a", category: "x", at: t0, trip: state.trip, model: state.model)
        // Ansicht verlassen, 20 Minuten später weiter — kein Neubeginn der Zählung.
        state = ShoppingRoute.recordCheckOff(key: "b", category: "x", at: t0.addingTimeInterval(20 * 60), trip: state.trip, model: state.model)
        XCTAssertEqual(state.trip.entries.map(\.key), ["a", "b"])
        XCTAssertTrue(state.model.itemPositions.isEmpty, "Gelernt wird erst, wenn der Einkauf vorbei ist")
    }

    func testCheckOffAfterTripGapLearnsPreviousTripAndStartsNewOne() {
        var state = (trip: ShoppingTrip(), model: ShoppingRouteModel())
        state = ShoppingRoute.recordCheckOff(key: "a", category: "x", at: t0, trip: state.trip, model: state.model)
        state = ShoppingRoute.recordCheckOff(key: "b", category: "x", at: t0.addingTimeInterval(60), trip: state.trip, model: state.model)
        state = ShoppingRoute.recordCheckOff(key: "c", category: "x", at: t0.addingTimeInterval(60 + 31 * 60), trip: state.trip, model: state.model)
        XCTAssertEqual(state.trip.entries.map(\.key), ["c"])
        XCTAssertEqual(state.model.itemPositions["a"], 0)
        XCTAssertEqual(state.model.itemPositions["b"], 1)
    }

    func testQueuedCheckOffsContinueTripInsteadOfStartingNewOne() {
        // 3 Artikel in der App, Rest per Dynamic Island; nachgetragen erst 50 Minuten später.
        var state = (trip: trip([("a", "x"), ("b", "x"), ("c", "x")]), model: ShoppingRouteModel())
        let drain = t0.addingTimeInterval(50 * 60)
        for key in ["d", "e"] {
            state = ShoppingRoute.recordCheckOff(key: key, category: "x", at: drain, batched: true, trip: state.trip, model: state.model)
        }
        XCTAssertEqual(state.trip.entries.map(\.key), ["a", "b", "c", "d", "e"], "Ein Weg darf nicht in zwei Einkäufe zerfallen")
        XCTAssertTrue(state.model.itemPositions.isEmpty)
        let learned = ShoppingRoute.learn(state.trip, into: state.model)
        XCTAssertEqual(learned.itemPositions["c"], 0.5)
        XCTAssertEqual(learned.itemPositions["e"], 1)
    }

    func testQueuedCheckOffAfterLongGapStartsNewTrip() {
        var state = (trip: trip([("a", "x"), ("b", "x")]), model: ShoppingRouteModel())
        state = ShoppingRoute.recordCheckOff(key: "c", category: "x", at: t0.addingTimeInterval(7 * 3600), batched: true, trip: state.trip, model: state.model)
        XCTAssertEqual(state.trip.entries.map(\.key), ["c"])
        XCTAssertEqual(state.model.itemPositions["b"], 1)
    }

    func testFinalizeIfStale() {
        let open = trip([("a", "x"), ("b", "x")])
        let recent = ShoppingRoute.finalizeIfStale(trip: open, model: ShoppingRouteModel(), now: t0.addingTimeInterval(10 * 60))
        XCTAssertEqual(recent.trip, open)
        XCTAssertTrue(recent.model.itemPositions.isEmpty)

        let stale = ShoppingRoute.finalizeIfStale(trip: open, model: ShoppingRouteModel(), now: t0.addingTimeInterval(45 * 60))
        XCTAssertTrue(stale.trip.entries.isEmpty)
        XCTAssertEqual(stale.model.itemPositions["b"], 1)
    }

    func testDuplicateCheckOffCountsOnlyOnce() {
        var state = (trip: trip([("a", "x"), ("b", "x")]), model: ShoppingRouteModel())
        state = ShoppingRoute.recordCheckOff(key: "a", category: "x", at: t0.addingTimeInterval(90), trip: state.trip, model: state.model)
        XCTAssertEqual(state.trip.entries.map(\.key), ["a", "b"])
    }

    func testUncheckAndRecheckMovesItemToNewPosition() {
        var t = ShoppingRoute.recordUncheck(key: "a", trip: trip([("a", "x"), ("b", "x")]))
        XCTAssertEqual(t.entries.map(\.key), ["b"])
        t = ShoppingRoute.recordCheckOff(key: "a", category: "x", at: t0.addingTimeInterval(120), trip: t, model: ShoppingRouteModel()).trip
        XCTAssertEqual(t.entries.map(\.key), ["b", "a"])
    }

    // MARK: Sortieren

    private var learnedModel: ShoppingRouteModel {
        // Weg: Käse vorne, dann Brot, Obst hinten.
        ShoppingRoute.learn(
            trip([("gouda", "Käse"), ("emmentaler", "Käse"), ("brot", "Brot"), ("banane", "Obst & Gemüse"), ("apfel", "Obst & Gemüse")]),
            into: ShoppingRouteModel()
        )
    }

    func testRouteModeFollowsLearnedOrder() {
        let items = [input("apfel", "Obst & Gemüse"), input("brot", "Brot"), input("gouda", "Käse")]
        XCTAssertEqual(sortedKeys(items, .route, learnedModel), ["gouda", "brot", "apfel"])
    }

    func testRouteModeUrgentItemsFirst() {
        let items = [input("gouda", "Käse"), input("apfel", "Obst & Gemüse", urgent: true)]
        XCTAssertEqual(sortedKeys(items, .route, learnedModel), ["apfel", "gouda"])
    }

    func testUnknownItemIsPlacedByItsCategoryInThisStore() {
        // Feta nie gekauft: steht beim Käse (Mittel 0,125), nicht am Ende.
        let items = [input("apfel", "Obst & Gemüse"), input("brot", "Brot"), input("feta", "Käse", added: 100)]
        XCTAssertEqual(sortedKeys(items, .route, learnedModel), ["feta", "brot", "apfel"])
    }

    func testItemsWithoutAnyLearnedPositionGoLastInCategoryOrder() {
        let items = [input("duschgel", "Drogerie"), input("milch", "Milch"), input("brot", "Brot")]
        XCTAssertEqual(sortedKeys(items, .route, learnedModel), ["brot", "milch", "duschgel"])
    }

    func testRouteModeWithoutLearningFallsBackToCategoryOrder() {
        let items = [input("duschgel", "Drogerie"), input("milch", "Milch"), input("apfel", "Obst & Gemüse")]
        XCTAssertEqual(sortedKeys(items, .route, ShoppingRouteModel()), ["apfel", "milch", "duschgel"])
    }

    func testCategoryModeOrdersCategoriesByLearnedRouteThenStaticOrder() {
        let items = [
            input("apfel", "Obst & Gemüse"), input("duschgel", "Drogerie"), input("milch", "Milch"),
            input("brot", "Brot"), input("emmentaler", "Käse"), input("gouda", "Käse", added: 10),
        ]
        // Gelernt: Käse (0,125) < Brot (0,5) < Obst (0,875); ungelernt dahinter: Milch, Drogerie.
        XCTAssertEqual(sortedKeys(items, .category, learnedModel), ["gouda", "emmentaler", "brot", "apfel", "milch", "duschgel"])
    }

    func testAddedModeUsesAddedDate() {
        let items = [input("gouda", "Käse", added: 30), input("apfel", "Obst & Gemüse", added: 10), input("brot", "Brot", added: 20)]
        XCTAssertEqual(sortedKeys(items, .added, learnedModel), ["apfel", "brot", "gouda"])
    }

    func testOrderedCategories() {
        let ordered = ShoppingRoute.orderedCategories(
            ["Drogerie", "Obst & Gemüse", "Käse", "Unbekannt", "Milch", "Käse"],
            model: learnedModel,
            staticOrder: staticOrder
        )
        XCTAssertEqual(ordered, ["Käse", "Obst & Gemüse", "Milch", "Drogerie", "Unbekannt"])
    }

    // MARK: Regression ohne Gänge (Issue #234, T17, AC-1)

    /// Gelernt: gouda 0,1 (Käse), brot 0,5 (Brot), apfel 0,9 (Obst & Gemüse) — Kategorie-Mittel
    /// Käse 0,1 < Brot 0,5 < Obst 0,9; Milch, Drogerie, „Unbekannt“ ungelernt.
    private var frozenModel: ShoppingRouteModel {
        var model = ShoppingRouteModel()
        for (key, position, category) in [("gouda", 0.1, "Käse"), ("brot", 0.5, "Brot"), ("apfel", 0.9, "Obst & Gemüse")] {
            model.itemPositions[key] = position
            model.itemCategories[key] = category
        }
        return model
    }

    /// Feste Eingaben: Feta ungelernt (erbt im Einkaufsweg das Käse-Mittel), Milch/Duschgel/„x“
    /// ohne Position und ohne gelernte Kategorie, Zahnbürste dringend, „x“ ohne feste Kategorie.
    private var frozenInputs: [ShoppingRoute.SortInput] {
        [
            input("apfel", "Obst & Gemüse", added: 50),
            input("brot", "Brot", added: 40),
            input("gouda", "Käse", added: 30),
            input("feta", "Käse", added: 5),
            input("milch", "Milch", added: 20),
            input("duschgel", "Drogerie", added: 10),
            input("zahnbürste", "Drogerie", urgent: true, added: 60),
            input("x", "Unbekannt", added: 0),
        ]
    }

    /// T17 / AC-1: GIVEN `SortInput` ohne `stationRank` WHEN `sortedIndices` in allen drei Modi
    /// THEN exakt die vor Issue #234 berechneten Reihenfolgen (festgeschrieben, aus dem Code von
    /// `sortedIndices` hergeleitet: Dringende zuerst; Einkaufsweg nach Position bzw. Kategorie-
    /// Mittel, Gleichstand nach Hinzufügedatum, ungelernte nach Kategorie-Rang; Kategorie nach
    /// gelernter, dann fester Reihenfolge, darin bekannte Position vor unbekannter; Hinzugefügt
    /// nach Datum).
    func testSortWithoutStationRankKeepsFrozenOrders() {
        let items = frozenInputs
        XCTAssertTrue(items.allSatisfy { $0.stationRank == nil }, "Ohne Angabe ist der Gang-Rang nil")
        XCTAssertEqual(sortedKeys(items, .route, frozenModel),
                       ["zahnbürste", "feta", "gouda", "brot", "apfel", "milch", "duschgel", "x"])
        XCTAssertEqual(sortedKeys(items, .category, frozenModel),
                       ["zahnbürste", "gouda", "feta", "brot", "apfel", "milch", "duschgel", "x"])
        XCTAssertEqual(sortedKeys(items, .added, frozenModel),
                       ["zahnbürste", "x", "feta", "duschgel", "milch", "gouda", "brot", "apfel"])
    }

    /// T17 / AC-1: Ein ausdrücklich übergebenes `stationRank: nil` sortiert genau wie ohne Angabe.
    func testExplicitNilStationRankEqualsDefault() {
        let explicit = frozenInputs.map {
            ShoppingRoute.SortInput(key: $0.key, category: $0.category, isUrgent: $0.isUrgent,
                                    addedDate: $0.addedDate, stationRank: nil)
        }
        for mode in StoreSortMode.allCases {
            XCTAssertEqual(sortedKeys(explicit, mode, frozenModel), sortedKeys(frozenInputs, mode, frozenModel),
                           "Modus \(mode): nil-Rang muss den bisherigen Pfad nehmen")
        }
    }

    // MARK: Voreinstellung

    func testMigratedDefaultKeepsPreviousSettings() {
        XCTAssertEqual(StoreSortMode.migratedDefault(groupByCategory: true, autoSortByLearnedOrder: true), .category)
        XCTAssertEqual(StoreSortMode.migratedDefault(groupByCategory: true, autoSortByLearnedOrder: false), .category)
        XCTAssertEqual(StoreSortMode.migratedDefault(groupByCategory: false, autoSortByLearnedOrder: true), .route)
        XCTAssertEqual(StoreSortMode.migratedDefault(groupByCategory: false, autoSortByLearnedOrder: false), .added)
    }

    // MARK: Test-Uhr (Issue #98, Durchgang 1)

    /// Ohne Launch-Argument liefert die Test-Uhr die echte Zeit (AC-8).
    func testRouteClockWithoutOffsetIsRealTime() {
        XCTAssertLessThan(abs(RouteClock.now.timeIntervalSinceNow), 1)
    }
}
