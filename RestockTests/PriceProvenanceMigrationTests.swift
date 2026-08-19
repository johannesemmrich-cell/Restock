import XCTest
import SwiftData
@testable import Restock

/// Beweist den Fix für den Skyr-Preisfehler, der am 13.08.2026 erneut gemeldet wurde — diesmal
/// ausschließlich bei Lidl. Anders als die früheren, bereits behobenen Ursachen in
/// `ReceiptParserPriceTests` (falsches Preis-Parsing beim Scannen) ging es hier um einen bereits
/// VOR diesen Fixes fälschlich als Pro-Gramm-Preis gespeicherten Wert in `Store.learnedPrices`,
/// der die früheren Fixes überlebt hat, weil keiner von ihnen den bereits gespeicherten
/// (kaputten) Wert selbst korrigiert — nur künftige Scans lernten danach richtig.
///
/// Zwei unabhängige Verteidigungslinien werden hier geprüft:
/// 1. `ShoppingItem.init` darf einen `learnedPrices`-Treffer nie übernehmen, wenn er zusammen mit
///    der Menge einen unplausiblen Gesamtpreis ergäbe (Zeile bleibt korrekt, egal WARUM der
///    gespeicherte Wert kaputt ist).
/// 2. `PriceProvenanceMigration` repariert den kaputten `learnedPrices`-Eintrag selbst, anhand
///    passender Kaufhistorie — damit auch die Anzeige "Preis pro Einheit" künftig stimmt, nicht
///    nur die einzelne Zeile.
final class PriceProvenanceMigrationTests: XCTestCase {

    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    // MARK: - Verteidigungslinie 1: ShoppingItem.init verwirft unplausible gelernte Preise

    func testShoppingItemRejectsImplausibleLearnedPriceAndFallsBackToEstimator() {
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#123456")
        // Kaputter Alt-Wert: ein voller Zeilenpreis (2,29€), fälschlich als Pro-Gramm-Preis
        // gespeichert — genau das gemeldete Symptom, unabhängig davon wie er entstanden ist.
        store.learnedPrices["skyr"] = 2.29

        let item = ShoppingItem(name: "Skyr", category: "Milchprodukte", quantityAmount: 500, unit: "g", store: store)

        let total = try? XCTUnwrap(item.estimatedLineTotal)
        XCTAssertNotNil(total)
        XCTAssertLessThan(total ?? .infinity, 30.0, "Ein einzelner Posten darf nie einen absurden Gesamtpreis zeigen, egal was in learnedPrices steht")
        XCTAssertNotEqual(total ?? 0, 2.29 * 500, "Der kaputte gelernte Wert darf nicht ungeprüft × 500 übernommen werden")
        XCTAssertTrue(item.estimatedPriceIsAutoDerived, "Ein verworfener gelernter Preis muss als Schätzung markiert sein, nicht als 'echt'")
    }

    // MARK: - ShoppingItem.init: deterministischer Tie-Breaker bei mehreren fuzzy-Treffern ohne Datum
    //
    // Gefunden 19.08.2026 von einer unabhängigen Review-Runde, per mehrfachem Prozess-Neustart
    // empirisch nachgewiesen: eine erste Fix-Fassung nutzte NUR learnedPriceDates als
    // Tie-Breaker — haben beide fuzzy-Treffer kein Datum (Normalfall bei älteren Einträgen,
    // keine Backfill-Migration), blieb der ursprüngliche Zufalls-Bug bestehen, nur seltener.

    func testShoppingItemPicksDeterministicWinnerWhenMultipleLearnedPricesMatchWithoutDates() {
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#123456")
        // Bewusst OHNE zugehörige learnedPriceDates-Einträge — genau der Fall, in dem Datum
        // allein als Tie-Breaker nicht reicht.
        store.learnedPrices["hackfleisch gemischt 500g"] = 3.49
        store.learnedPrices["rinderhackfleisch"] = 5.99

        let item = ShoppingItem(name: "Hackfleisch", category: "Fleisch & Wurst", store: store)

        XCTAssertEqual(item.estimatedPrice, 3.49, "Bei gleichem (fehlendem) Datum muss der alphabetisch frühere Key ('hackfleisch gemischt 500g') deterministisch gewinnen, nicht die zufällige Dictionary-Reihenfolge")
    }

    /// Beweist den Fix für ein von einem unabhängigen Review gefundenes Problem in der ERSTEN
    /// Version dieses Fixes: eine gemeinsame 30€-Grenze für geschätzte UND gelernte Preise hätte
    /// einen echten, korrekt gelernten Preis für ein teures Produkt (hier: 400g Filet für 32€)
    /// fälschlich verworfen, nur weil der Gesamtpreis über 30€ liegt. Gelernte Preise kommen von
    /// einem echten Kassenbon und dürfen legitim teuer sein — die Plausibilitätsgrenze muss nur
    /// den gemeldeten Bug (eine Größenordnung zu hoch) abfangen, keine enge Preisobergrenze ziehen.
    func testShoppingItemAcceptsLegitimatelyExpensiveLearnedPrice() throws {
        let store = Store(name: "Rewe", emoji: "🛒", colorHex: "#654321")
        store.learnedPrices["rinderfilet"] = 32.0 / 400.0 // korrekt: 0,08€/g für ein 400g-Filet

        let item = ShoppingItem(name: "Rinderfilet", category: "Fleisch & Wurst", quantityAmount: 400, unit: "g", store: store)

        XCTAssertEqual(try XCTUnwrap(item.estimatedLineTotal), 32.0, accuracy: 0.01, "Ein echter, teurer gelernter Preis darf nicht verworfen werden")
        XCTAssertFalse(item.estimatedPriceIsAutoDerived, "Ein akzeptierter gelernter Preis gilt als 'echt', nicht als Schätzung")
    }

    func testShoppingItemStillUsesPlausibleLearnedPrice() throws {
        // Non-Regression: ein korrekt gespeicherter Pro-Gramm-Preis muss weiterhin verwendet werden.
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#123456")
        store.learnedPrices["skyr"] = 2.29 / 500 // korrekt: Preis pro Gramm

        let item = ShoppingItem(name: "Skyr", category: "Milchprodukte", quantityAmount: 500, unit: "g", store: store)

        XCTAssertEqual(try XCTUnwrap(item.estimatedLineTotal), 2.29, accuracy: 0.01)
        XCTAssertFalse(item.estimatedPriceIsAutoDerived, "Ein plausibler gelernter Preis gilt als 'echt', nicht als reine Schätzung")
    }

    // MARK: - Verteidigungslinie 2: Migration repariert den gespeicherten Wert selbst

    @MainActor
    func testMigrationRepairsCorruptedStoreLearnedPrice() throws {
        let context = try makeInMemoryContext()

        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#123456")
        // Derselbe kaputte Alt-Wert wie oben — VOR jeder Nutzung durch ShoppingItem.init
        // (die Migration muss den Dictionary-Eintrag selbst korrigieren, nicht nur einzelne Items).
        store.learnedPrices["skyr natur 500g"] = 2.29
        context.insert(store)

        // Kaufhistorie, die belegt: dieses Produkt wird bei Lidl typischerweise in 500g-Packungen
        // gekauft — genau das Fingerprint-Signal, das Phase C nutzt, um den kaputten Wert zu
        // erkennen (sub-unit Einheit, große Menge, unplausibler impliziter Gesamtpreis).
        let record = PurchaseRecord(itemName: "Skyr Natur 500g", storeName: "Lidl", quantityAmount: 500, unit: "g", actualPrice: 2.29)
        context.insert(record)

        try context.save()

        UserDefaults.standard.removeObject(forKey: PriceProvenanceMigration.flagKey)
        defer { UserDefaults.standard.removeObject(forKey: PriceProvenanceMigration.flagKey) }

        PriceProvenanceMigration.runIfNeeded(context: context)

        let repairedStore = try XCTUnwrap(try context.fetch(FetchDescriptor<Store>()).first)
        let repairedPrice = try XCTUnwrap(repairedStore.learnedPrices["skyr natur 500g"])
        XCTAssertEqual(repairedPrice, 2.29 / 500, accuracy: 0.0001, "Migration muss den vollen Zeilenpreis durch den echten Pro-Gramm-Preis ersetzen")

        // End-to-end: ein NEU angelegtes Item mit diesem Namen muss jetzt den richtigen
        // Gesamtpreis zeigen, nicht mehr 1145€.
        let newItem = ShoppingItem(name: "Skyr Natur 500g", quantityAmount: 500, unit: "g", store: repairedStore)
        XCTAssertEqual(try XCTUnwrap(newItem.estimatedLineTotal), 2.29, accuracy: 0.01)
    }

    /// Derselbe von einem unabhängigen Review gefundene Fall wie oben, aber für Phase C der
    /// Migration: ein korrekt gelernter Preis für teuren Parmesan (25€/500g) darf nicht als
    /// "kaputt" erkannt und überschrieben werden, nur weil ein späterer, legitimer 700g-Kauf
    /// desselben Produkts einen Gesamtpreis über der ALTEN 30€-Grenze ergäbe (0,05€/g × 700g =
    /// 35€). Mit der neuen, viel höheren `maxPlausibleLearnedLineTotal` (200€) bleibt das unangetastet.
    @MainActor
    func testMigrationLeavesLegitimatelyExpensiveLearnedPriceUntouched() throws {
        let context = try makeInMemoryContext()

        let store = Store(name: "Rewe", emoji: "🛒", colorHex: "#654321")
        let correctPerGramPrice = 25.0 / 500.0 // 0,05€/g, aus einem echten 25€/500g-Kauf gelernt
        store.learnedPrices["parmesan"] = correctPerGramPrice
        context.insert(store)

        // Späterer, legitimer größerer Kauf desselben Produkts (700g statt 500g) — der Gesamtpreis
        // dafür (35€) liegt über der alten 30€-Grenze, aber der GELERNTE Preis selbst ist weiterhin
        // korrekt und darf nicht verändert werden.
        let record = PurchaseRecord(itemName: "Parmesan", storeName: "Rewe", quantityAmount: 700, unit: "g", actualPrice: 35.0)
        context.insert(record)
        try context.save()

        UserDefaults.standard.removeObject(forKey: PriceProvenanceMigration.flagKey)
        defer { UserDefaults.standard.removeObject(forKey: PriceProvenanceMigration.flagKey) }

        PriceProvenanceMigration.runIfNeeded(context: context)

        let untouchedStore = try XCTUnwrap(try context.fetch(FetchDescriptor<Store>()).first)
        XCTAssertEqual(try XCTUnwrap(untouchedStore.learnedPrices["parmesan"]), correctPerGramPrice, accuracy: 0.0001, "Ein korrekt gelernter, teurer Pro-Gramm-Preis darf nicht überschrieben werden, nur weil eine spätere Kaufmenge den Gesamtpreis über eine zu enge Grenze treibt")
    }

    @MainActor
    func testMigrationLeavesPlausibleStoreLearnedPricesUntouched() throws {
        let context = try makeInMemoryContext()

        let store = Store(name: "Rewe", emoji: "🛒", colorHex: "#654321")
        let plausiblePerGram = 1.99 / 500.0
        store.learnedPrices["skyr natur"] = plausiblePerGram
        context.insert(store)

        let record = PurchaseRecord(itemName: "Skyr Natur", storeName: "Rewe", quantityAmount: 500, unit: "g", actualPrice: 1.99)
        context.insert(record)
        try context.save()

        UserDefaults.standard.removeObject(forKey: PriceProvenanceMigration.flagKey)
        defer { UserDefaults.standard.removeObject(forKey: PriceProvenanceMigration.flagKey) }

        PriceProvenanceMigration.runIfNeeded(context: context)

        let untouchedStore = try XCTUnwrap(try context.fetch(FetchDescriptor<Store>()).first)
        XCTAssertEqual(try XCTUnwrap(untouchedStore.learnedPrices["skyr natur"]), plausiblePerGram, accuracy: 0.0001, "Ein bereits korrekter Pro-Einheit-Preis darf von der Migration nicht verändert werden")
    }
}
