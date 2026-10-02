import XCTest
@testable import Restock

/// Issue #86: Artikel und Kategorie-Abschnitte von Hand verschieben (`ShoppingRoute`).
final class ShoppingRouteManualOrderTests: XCTestCase {

    private let staticOrder = ["Obst & Gemüse", "Brot", "Käse", "Milch", "Drogerie"]
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func input(_ key: String, _ category: String) -> ShoppingRoute.SortInput {
        .init(key: key, category: category, isUrgent: false, addedDate: t0)
    }

    /// Gelernt: gouda 0, emmentaler 0,25, brot 0,5, banane 0,75, apfel 1.
    private var learned: ShoppingRouteModel {
        var model = ShoppingRouteModel()
        let route: [(String, String)] = [("gouda", "Käse"), ("emmentaler", "Käse"), ("brot", "Brot"), ("banane", "Obst & Gemüse"), ("apfel", "Obst & Gemüse")]
        for (index, entry) in route.enumerated() {
            model.itemPositions[entry.0] = Double(index) / 4
            model.itemCategories[entry.0] = entry.1
        }
        return model
    }

    private func routeOrder(_ items: [ShoppingRoute.SortInput], _ model: ShoppingRouteModel) -> [String] {
        ShoppingRoute.sortedIndices(items, mode: .route, model: model, staticCategoryOrder: staticOrder).map { items[$0].key }
    }

    // MARK: Positionen

    func testInterpolatesMissingValueBetweenNeighbours() {
        XCTAssertEqual(ShoppingRoute.positionsPreservingOrder([0, 0.5, nil, 1]), [0, 0.5, 0.75, 1])
    }

    func testWithoutAnyValuesSpreadsEvenly() {
        XCTAssertEqual(ShoppingRoute.positionsPreservingOrder([nil, nil, nil]), [0, 0.5, 1])
        XCTAssertEqual(ShoppingRoute.positionsPreservingOrder([nil]), [0.5])
        XCTAssertEqual(ShoppingRoute.positionsPreservingOrder([]), [])
    }

    func testKeepsLongestAscendingRunAndReplacesTheRest() {
        let result = ShoppingRoute.positionsPreservingOrder([0.2, 0.9, 0.5, 0.6])
        XCTAssertEqual(result[0], 0.2)
        XCTAssertEqual(result[1], 0.35, accuracy: 1e-9)
        XCTAssertEqual(result[2], 0.5)
        XCTAssertEqual(result[3], 0.6)
    }

    func testEdgesStepOutwards() {
        let result = ShoppingRoute.positionsPreservingOrder([nil, 0.4, nil])
        XCTAssertEqual(result[0], 0.38, accuracy: 1e-9)
        XCTAssertEqual(result[2], 0.42, accuracy: 1e-9)
    }

    // MARK: Artikel

    func testMovingToTopPlacesItemBeforeFirst() {
        let order = [input("apfel", "Obst & Gemüse"), input("gouda", "Käse"), input("brot", "Brot")]
        let model = ShoppingRoute.applyManualOrder(order, movedKey: "apfel", model: learned)
        XCTAssertEqual(routeOrder(order, model), ["apfel", "gouda", "brot"])
        XCTAssertEqual(model.itemPositions["gouda"], 0, "Nicht gezogene Artikel behalten ihre Position")
        XCTAssertEqual(model.itemPositions["brot"], 0.5)
    }

    func testMovingBetweenNeighboursUsesMidpoint() {
        let order = [input("gouda", "Käse"), input("apfel", "Obst & Gemüse"), input("brot", "Brot")]
        let model = ShoppingRoute.applyManualOrder(order, movedKey: "apfel", model: learned)
        XCTAssertEqual(model.itemPositions["apfel"]!, 0.25, accuracy: 1e-9)
        XCTAssertEqual(routeOrder(order, model), ["gouda", "apfel", "brot"])
    }

    func testUnlearnedItemsGetPositionsSoOrderSticks() {
        // Milch und Duschgel sind ungelernt und hätten keine Position — Duschgel wird vor Milch gezogen.
        let order = [input("gouda", "Käse"), input("duschgel", "Drogerie"), input("milch", "Milch")]
        let model = ShoppingRoute.applyManualOrder(order, movedKey: "duschgel", model: learned)
        XCTAssertNotNil(model.itemPositions["milch"])
        XCTAssertEqual(routeOrder(order.shuffled(), model), ["gouda", "duschgel", "milch"])
    }

    func testLearningContinuesAfterManualMove() {
        let order = [input("apfel", "Obst & Gemüse"), input("gouda", "Käse"), input("brot", "Brot")]
        var model = ShoppingRoute.applyManualOrder(order, movedKey: "apfel", model: learned)
        let before = model.itemPositions["apfel"]!
        // Ein voller Einkauf, in dem Apfel wieder am Ende abgehakt wird.
        let trip = ShoppingTrip(entries: ["gouda", "emmentaler", "brot", "banane", "apfel"].enumerated().map {
            .init(key: $1, category: "x", date: t0.addingTimeInterval(Double($0) * 30), batched: false)
        })
        model = ShoppingRoute.learn(trip, into: model)
        XCTAssertEqual(model.itemPositions["apfel"]!, before + 0.3 * (1 - before), accuracy: 1e-9)
    }

    // MARK: Abschnitte

    func testMovingCategorySectionShiftsItsItems() {
        // Gelernt: Käse 0,125 < Brot 0,5 < Obst 0,875 — Obst wird nach vorne gezogen.
        let model = ShoppingRoute.applyManualCategoryOrder(
            ["Obst & Gemüse", "Käse", "Brot"], movedCategory: "Obst & Gemüse", items: [], model: learned
        )
        XCTAssertEqual(
            ShoppingRoute.orderedCategories(["Brot", "Käse", "Obst & Gemüse"], model: model, staticOrder: staticOrder),
            ["Obst & Gemüse", "Käse", "Brot"]
        )
        XCTAssertEqual(model.itemPositions["gouda"], 0, "Andere Abschnitte bleiben, wo sie sind")
        XCTAssertEqual(
            model.itemPositions["apfel"]! - model.itemPositions["banane"]!, 0.25, accuracy: 1e-9,
            "Die Reihenfolge innerhalb des Abschnitts bleibt erhalten"
        )
    }

    func testMovingUnlearnedCategoryGivesItsItemsPositions() {
        let model = ShoppingRoute.applyManualCategoryOrder(
            ["Milch", "Käse", "Brot", "Obst & Gemüse"], movedCategory: "Milch",
            items: [input("milch", "Milch"), input("gouda", "Käse")], model: learned
        )
        XCTAssertEqual(
            ShoppingRoute.orderedCategories(["Käse", "Milch", "Brot", "Obst & Gemüse"], model: model, staticOrder: staticOrder),
            ["Milch", "Käse", "Brot", "Obst & Gemüse"]
        )
    }

    func testRenameCategoryKeepsLearnedPosition() {
        let model = ShoppingRoute.renameCategory("Käse", to: "Kühltheke", in: learned)
        XCTAssertEqual(model.itemCategories["gouda"], "Kühltheke")
        XCTAssertEqual(ShoppingRoute.categoryPositions(model)["Kühltheke"]!, 0.125, accuracy: 1e-9)
    }
}
