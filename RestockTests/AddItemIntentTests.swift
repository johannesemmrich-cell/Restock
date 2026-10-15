import XCTest
import SwiftData
@testable import Restock

/// Issue #98, Durchgang 8: Anlegelogik des Siri-Befehls „Artikel hinzufügen“
/// (`AddShoppingItemIntent.add`). Spec: `docs/specs/ui-tests/test-98-durchgang-8-siri-widget.md`.
///
/// **Offene Grenzen:** Der echte Siri-Ruf (Stimme, Phrasenerkennung, Registrierung der Kurzbefehle) und
/// der Systemaufruf von `perform()` laufen im Simulator nicht und sind hier nicht geprüft; ebenso kein
/// Test auf einem Gerät des Users. Geprüft wird nur, was in den App-Speicher geschrieben wird.
@MainActor
final class AddItemIntentTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
    }

    override func tearDown() {
        container = nil
        context = nil
    }

    private func makeStore(_ name: String, categories: [String]) -> Store {
        let store = Store(name: name, emoji: "🛒", colorHex: "#0050AA", categories: categories)
        context.insert(store)
        return store
    }

    // MARK: - A1 Zuordnung

    func testPurchaseHistoryDecidesTheStore() throws {
        let edeka = makeStore("UT-Edeka", categories: Category.grocery)
        _ = makeStore("UT-Rewe", categories: Category.grocery)
        for _ in 0..<3 { context.insert(PurchaseRecord(itemName: "Eier", storeName: edeka.name)) }

        let item = AddShoppingItemIntent.add(name: "Eier", quantity: 1, unit: nil, in: context)

        XCTAssertEqual(item.store?.name, "UT-Edeka")
        XCTAssertEqual(try context.fetch(FetchDescriptor<ShoppingItem>()).count, 1, "genau ein Artikel im Speicher")
    }

    func testDrugstoreItemGoesToDrugstore() {
        _ = makeStore("UT-Lidl", categories: Category.grocery)
        let dm = makeStore("UT-dm", categories: Category.drugstore)

        let item = AddShoppingItemIntent.add(name: "Zahnpasta", quantity: 1, unit: nil, in: context)

        XCTAssertEqual(item.store?.name, dm.name)
    }

    // MARK: - A2 Menge und Einheit

    func testQuantityAndUnitAreStored() {
        _ = makeStore("UT-Lidl", categories: Category.grocery)

        let weighed = AddShoppingItemIntent.add(name: "Kartoffeln", quantity: 3, unit: "kg", in: context)
        XCTAssertEqual(weighed.quantity, "3")
        XCTAssertEqual(weighed.quantityAmount, 3)
        XCTAssertEqual(weighed.unit, "kg")

        let single = AddShoppingItemIntent.add(name: "Brot", quantity: 1, unit: nil, in: context)
        XCTAssertEqual(single.quantity, "1")
        XCTAssertEqual(single.quantityAmount, 1)
        XCTAssertEqual(single.unit, "")
    }

    // MARK: - A3 Kein Laden

    func testWithoutActiveStoresItemHasNoStore() {
        let item = AddShoppingItemIntent.add(name: "Milch", quantity: 1, unit: nil, in: context)
        XCTAssertNil(item.store)
        XCTAssertEqual(item.name, "Milch")
    }

    func testInactiveStoreIsNotUsed() {
        let closed = makeStore("UT-Zu", categories: Category.grocery)
        closed.isActive = false

        let item = AddShoppingItemIntent.add(name: "Milch", quantity: 1, unit: nil, in: context)

        XCTAssertNil(item.store)
    }

    // MARK: - A4 Ist-Verhalten (kein Beschluss)

    /// Festgehalten, nicht gewollt oder verboten: Der Siri-Befehl prüft keine Duplikate und schlägt
    /// keine Menge aus der Kaufhistorie vor (anders als die Schnell-Eingabe in der App).
    func testCurrentBehaviourCreatesDuplicatesAndNoQuantitySuggestion() throws {
        let lidl = makeStore("UT-Lidl", categories: Category.grocery)
        context.insert(PurchaseRecord(itemName: "Milch", storeName: lidl.name, quantityAmount: 6, unit: "l"))

        let first = AddShoppingItemIntent.add(name: "Milch", quantity: 1, unit: nil, in: context)
        let second = AddShoppingItemIntent.add(name: "Milch", quantity: 1, unit: nil, in: context)

        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ShoppingItem>()).filter { $0.name == "Milch" }.count, 2)
        XCTAssertEqual(first.quantityAmount, 1, "kein Mengenvorschlag aus der Historie (6 l)")
        XCTAssertNotEqual(first.quantitySource, "history")
    }
}
