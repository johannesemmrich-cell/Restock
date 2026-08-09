import XCTest
import SwiftData
@testable import Restock

/// Beweist den Fix für "bekannte Dinge vorschlagen klappt zu schlecht" (Nutzer: zu wenige
/// Vorschläge). Zwei getrennte Ursachen: (A) `completedItemCandidates` deckelte auf 3 Treffer,
/// (B) `ReceiptResolutionService` schlug nur bereits ABGEHAKTE Artikel vor, nicht auch noch
/// offene — ein gerade erst zur Liste hinzugefügter Artikel tauchte beim Scannen nie als
/// Vorschlag auf, bis er einmal abgehakt wurde.
final class ReceiptParserSuggestionTests: XCTestCase {

    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    // MARK: - (A) Limit

    func testCompletedItemCandidatesDefaultLimitIsFive() throws {
        let context = try makeInMemoryContext()
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#123456")
        context.insert(store)
        let names = ["Mandeln", "Mandarinen", "Mandelmilch", "Mandelmus", "Mandelöl", "Mandelkerne"]
        let items = names.map { name -> ShoppingItem in
            let item = ShoppingItem(name: name, store: store)
            item.isCompleted = true
            context.insert(item)
            return item
        }

        let candidates = ReceiptParserService.completedItemCandidates(for: "Mand", in: items)

        XCTAssertEqual(candidates.count, 5, "Standard-Limit muss 5 sein, nicht 3")
    }

    // MARK: - (B) Vorschläge auch für noch offene (nicht abgehakte) Artikel

    func testResolutionServiceSuggestsFromPendingNotOnlyCompletedItems() async throws {
        let context = try makeInMemoryContext()
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#123456")
        context.insert(store)
        // Bewusst NICHT abgehakt — genau der Fall, der vorher aus den Vorschlägen fiel.
        let pending = ShoppingItem(name: "Mozzarella", store: store)
        context.insert(pending)
        try context.save()

        let parsed = [ReceiptLine(name: "Mozarela", price: 2.99)]
        let resolved = await ReceiptResolutionService.resolve(
            parsed: parsed, store: store, allRecords: [], allowAIResolution: false
        )

        let suggestionNames = resolved.first?.suggestions.map(\.name) ?? []
        XCTAssertTrue(
            suggestionNames.contains("Mozzarella"),
            "Ein noch offener (nicht abgehakter) Artikel muss trotzdem als Vorschlag auftauchen, gefunden: \(suggestionNames)"
        )
    }
}
