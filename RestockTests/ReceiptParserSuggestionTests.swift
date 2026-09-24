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

    // MARK: - (C) Nur passende Chips, max. 3 (Issue #29)

    /// Reproduziert den in #23 beobachteten Fehltreffer: "Fisch" liegt bei der bisherigen
    /// Schwelle 0,2 über dem Floor (LCS-Ratio 0,40 zu "Hafersahne"), erscheint also fälschlich
    /// als Vorschlags-Chip. Nach der Anhebung auf 0,45 darf das nicht mehr passieren.
    func testCompletedItemCandidatesExcludesLooseFalsePositives() throws {
        let context = try makeInMemoryContext()
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#123456")
        context.insert(store)
        let names = ["Hafersahne", "Flammkuchenteig", "Rote Linsen"]
        let items = names.map { name -> ShoppingItem in
            let item = ShoppingItem(name: name, store: store)
            item.isCompleted = true
            context.insert(item)
            return item
        }

        let candidates = ReceiptParserService.completedItemCandidates(for: "Fisch", in: items)

        XCTAssertTrue(
            candidates.isEmpty,
            "Inhaltlich unpassende Namen dürfen nicht mehr als Chip erscheinen, gefunden: \(candidates.map(\.item.name))"
        )
    }

    /// Nulllinie fürs Gegenteil: Eine echte, plausible Kürzung darf durch die angehobene Schwelle
    /// nicht verloren gehen.
    func testCompletedItemCandidatesKeepsPlausibleShortening() throws {
        let context = try makeInMemoryContext()
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#123456")
        context.insert(store)
        let item = ShoppingItem(name: "Bananen", store: store)
        item.isCompleted = true
        context.insert(item)

        let candidates = ReceiptParserService.completedItemCandidates(for: "Banane", in: [item])

        XCTAssertEqual(candidates.map(\.item.name), ["Bananen"])
    }

    /// Die Vorschlags-Chips im Review-Screen sind auf 3 gedeckelt (statt des Default-Limits 5,
    /// das für andere Aufrufer von `completedItemCandidates` unverändert bleibt, siehe
    /// `testCompletedItemCandidatesDefaultLimitIsFive` oben).
    func testResolutionServiceLimitsSuggestionsToThree() async throws {
        let context = try makeInMemoryContext()
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#123456")
        context.insert(store)
        let names = ["Mandeln", "Mandarinen", "Mandelmilch", "Mandelmus", "Mandelöl"]
        for name in names {
            let item = ShoppingItem(name: name, store: store)
            item.isCompleted = true
            context.insert(item)
        }
        try context.save()

        let parsed = [ReceiptLine(name: "Mand", price: 1.0)]
        let resolved = await ReceiptResolutionService.resolve(
            parsed: parsed, store: store, allRecords: [], allowAIResolution: false
        )

        XCTAssertLessThanOrEqual(resolved.first?.suggestions.count ?? 0, 3)
    }
}
