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
        // Bezugsgröße (Issue #10): beides sind Stückpreise, sonst würden sie für den unten
        // angelegten Artikel ohne Einheit gar nicht mehr angewendet und der Tie-Breaker wäre
        // nicht mehr messbar. Aussage des Tests unverändert.
        store.learnedPriceUnits["hackfleisch gemischt 500g"] = "stk"
        store.learnedPriceUnits["rinderhackfleisch"] = "stk"

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
        store.learnedPriceUnits["rinderfilet"] = "g" // Bezugsgröße (Issue #10)

        let item = ShoppingItem(name: "Rinderfilet", category: "Fleisch & Wurst", quantityAmount: 400, unit: "g", store: store)

        XCTAssertEqual(try XCTUnwrap(item.estimatedLineTotal), 32.0, accuracy: 0.01, "Ein echter, teurer gelernter Preis darf nicht verworfen werden")
        XCTAssertFalse(item.estimatedPriceIsAutoDerived, "Ein akzeptierter gelernter Preis gilt als 'echt', nicht als Schätzung")
    }

    func testShoppingItemStillUsesPlausibleLearnedPrice() throws {
        // Non-Regression: ein korrekt gespeicherter Pro-Gramm-Preis muss weiterhin verwendet werden.
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#123456")
        store.learnedPrices["skyr"] = 2.29 / 500 // korrekt: Preis pro Gramm
        store.learnedPriceUnits["skyr"] = "g" // Bezugsgröße (Issue #10)

        let item = ShoppingItem(name: "Skyr", category: "Milchprodukte", quantityAmount: 500, unit: "g", store: store)

        XCTAssertEqual(try XCTUnwrap(item.estimatedLineTotal), 2.29, accuracy: 0.01)
        XCTAssertFalse(item.estimatedPriceIsAutoDerived, "Ein plausibler gelernter Preis gilt als 'echt', nicht als reine Schätzung")
    }

    // MARK: - Issue #10: Eine Pro-Gramm-Rate darf nie als Stückpreis durchgehen
    //
    // Der am 25.09.2026 gemeldete Fall ("Seitan zeigt 0,01 €") und der am 26.09.2026 im
    // Simulator reproduzierte Fall ("Hackfleisch zeigt 0,01 €", Beleg
    // docs/artifacts/fix-10-preis-einheit/repro-heute-lidl-liste.png). Anders als der
    // Skyr-Fall oben ist der gelernte Wert hier NICHT kaputt: 4,99 € für eine 400-g-Packung
    // ergeben korrekt 0,0125 € pro Gramm. Kaputt ist, dass die Rate ihre Bezugsgröße nicht
    // mitführt — beim Anlegen ohne Mengenangabe multipliziert `ShoppingItem.init` sie mit
    // einem Stück. Die bestehende Plausibilitätsprüfung greift nicht: sie kennt nur eine
    // Obergrenze (200 €), und 0,0125 liegt weit darunter.
    //
    // Spec: docs/specs/models/learned-price-unit-and-quantity-source.md — AC2.

    func testLearnedGramPriceIsNotAppliedToItemWithoutQuantity() throws {
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#0050AA")
        let perGram = 4.99 / 400 // korrekt gelernte Rate aus "BIO-HACKFLEISCH … 400G"
        store.learnedPrices["hackfleisch"] = perGram

        // Wie beim Schnell-Hinzufügen: nur ein Name, keine Menge, keine Einheit.
        let item = ShoppingItem(name: "Hackfleisch", category: "Fleisch & Wurst", store: store)

        XCTAssertNotEqual(
            item.estimatedLineTotal ?? 0, perGram, accuracy: 0.0001,
            "Eine pro Gramm gelernte Rate darf nicht als Stückpreis übernommen werden — genau das "
            + "erzeugt die gemeldeten 0,01 € auf der Liste."
        )
        XCTAssertTrue(
            item.estimatedPriceIsAutoDerived,
            "Passt die Bezugsgröße des gelernten Preises nicht zur Einheit des Artikels, muss der "
            + "Preis verworfen und als Schätzung gekennzeichnet werden (PriceEstimator greift)."
        )
    }

    /// AC-3: Der Gegenfall zum gemeldeten Fehler — passt die Bezugsgröße zur Einheit des Artikels,
    /// muss die vom Bon gelernte Rate angewendet werden und exakt den bezahlten Betrag ergeben.
    /// Ohne diesen Nachweis wäre die Entscheidungstabelle auch dann "grün", wenn sie gelernte
    /// Preise pauschal verwirft — der Fehler wäre weg, der Nutzen auch.
    func testLearnedGramPriceAppliesToItemWithGramQuantity() throws {
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#0050AA")
        store.learnedPrices["hackfleisch"] = 4.99 / 400 // Rate aus "BIO-HACKFLEISCH … 400G"
        store.learnedPriceUnits["hackfleisch"] = "g"

        let item = ShoppingItem(name: "Hackfleisch", quantityAmount: 400, unit: "g", store: store)

        XCTAssertEqual(
            try XCTUnwrap(item.estimatedLineTotal), 4.99, accuracy: 0.01,
            "400 g zu 1,25 Cent je Gramm müssen genau die bezahlten 4,99 € ergeben"
        )
        XCTAssertFalse(
            item.estimatedPriceIsAutoDerived,
            "Ein angewendeter gelernter Preis ist ein echter Preis, keine Schätzung"
        )
    }

    /// AC-4: Die Gegenrichtung — ein gelernter STÜCKpreis darf nie mit einer Grammzahl
    /// multipliziert werden (0,39 € × 400 g = 156 € für eine Packung Eier).
    func testLearnedPieceRateIsRejectedForWeightItem() {
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#0050AA")
        store.learnedPrices["eier"] = 0.39 // Preis pro Stück, vom Bon "4 Stk x 0,39"
        store.learnedPriceUnits["eier"] = "stk"

        let item = ShoppingItem(name: "Eier", category: "Eier", quantityAmount: 400, unit: "g", store: store)

        XCTAssertTrue(
            item.estimatedPriceIsAutoDerived,
            "Ein Stückpreis passt nicht zu einem Artikel in Gramm — er muss verworfen werden und "
            + "der PriceEstimator greifen"
        )
        XCTAssertNotEqual(
            item.estimatedPrice ?? 0, 0.39, accuracy: 0.0001,
            "Der verworfene Stückpreis darf nicht als Rate übernommen werden"
        )
        XCTAssertNotEqual(
            item.estimatedLineTotal ?? 0, 0.39 * 400, accuracy: 0.01,
            "Stückpreis × Grammzahl ist der Fehler in umgekehrter Richtung (156 € für Eier)"
        )
    }

    /// AC-6: Zeile 5 der Entscheidungstabelle (PO-Entscheidung 2, Stufe 4). Ohne belegbare Menge
    /// (`quantitySource == "none"`) bleibt die echte Bon-Rate erhalten — aber es entsteht KEIN
    /// Gesamtpreis daraus, denn die stille `quantityAmount = 1` wäre geraten und ergäbe genau die
    /// gemeldeten 0,01 €. `unit` wird auf die Bezugsgröße gesetzt, damit die Anzeige weiß, worauf
    /// sich die Rate bezieht. `quantitySource` kommt hier direkt über den Konstruktor: In #10 gibt
    /// es noch keinen Aufrufer, der den Wert setzt — die Weiche wird mit `suggestQuantity` in
    /// Issue #57 erreichbar, muss aber jetzt schon nachweisbar richtig entscheiden.
    func testLearnedGramRateWithoutEvidenceIsKeptAsRate() throws {
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#0050AA")
        let perGram = 4.99 / 400
        store.learnedPrices["hackfleisch"] = perGram
        store.learnedPriceUnits["hackfleisch"] = "g"

        let item = ShoppingItem(
            name: "Hackfleisch", category: "Fleisch & Wurst", store: store, quantitySource: "none"
        )

        XCTAssertEqual(
            try XCTUnwrap(item.estimatedPrice), perGram, accuracy: 0.000001,
            "Die echte Rate vom Bon bleibt erhalten, sie ist kein Schätzwert"
        )
        XCTAssertNil(
            item.estimatedLineTotal,
            "Ohne belegte Menge darf aus der Rate kein Gesamtbetrag entstehen — genau dieser "
            + "Betrag war der gemeldete Fehler (0,01 €)"
        )
        XCTAssertEqual(item.unit, "g", "Die Anzeige muss wissen, worauf sich die Rate bezieht")
        XCTAssertFalse(
            item.estimatedPriceIsAutoDerived,
            "Die Rate stammt vom Kassenbon, nicht vom Schätzer"
        )
    }

    /// AC-7: Gramm und Kilogramm werden NIE stillschweigend ineinander umgerechnet. Der Test ist
    /// so gebaut, dass eine Umrechnung um den Faktor 1000 sichtbar würde: die gelernte Rate ist
    /// 0,99 €/1000 g; für "1 kg" wäre das umgerechnet genau 0,99 €. Stattdessen muss der Wert
    /// verworfen werden (die Richtung der Umrechnung ist erst mit der g/ml-Trennung aus #15 sicher).
    func testLearnedGramRateIsRejectedForKilogramItem() {
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#0050AA")
        let perGram = 0.99 / 1000 // 0,99 € für ein Kilo, gelernt als Rate pro Gramm
        store.learnedPrices["mehl"] = perGram
        store.learnedPriceUnits["mehl"] = "g"

        let item = ShoppingItem(name: "Mehl", category: "Backen", quantityAmount: 1, unit: "kg", store: store)

        XCTAssertTrue(
            item.estimatedPriceIsAutoDerived,
            "Eine Pro-Gramm-Rate passt nicht zu einem Artikel in Kilogramm — verwerfen, nicht raten"
        )
        XCTAssertNotEqual(
            item.estimatedLineTotal ?? 0, 0.99, accuracy: 0.0001,
            "Es darf NICHT um den Faktor 1000 umgerechnet werden (0,99 € wäre genau das Ergebnis "
            + "einer solchen stillen Umrechnung)"
        )
        XCTAssertNotEqual(
            item.estimatedPrice ?? 0, perGram, accuracy: 0.000001,
            "Die unpassende Rate darf auch nicht unverändert übernommen werden"
        )
    }

    /// AC-8: Die Eimer-Zuordnung selbst — sie entscheidet in jeder Zeile der Entscheidungstabelle,
    /// ob "passt" oder "passt nicht". Nur zwei Eimer, weil die Quelle des gelernten Preises kg und
    /// l auf denselben Faktor normiert (Trennung: Issue #15).
    func testUnitBucketMapsSynonymsAndUnknownUnits() {
        for unit in ["", "Stk", "Stück", "st", "STK.", "stueck"] {
            XCTAssertEqual(ShoppingItem.unitBucket(unit), "stk", "'\(unit)' zählt Stücke")
        }
        for unit in ["g", "mg", "ml", "cl", "dl", "Gramm", " ml "] {
            XCTAssertEqual(ShoppingItem.unitBucket(unit), "g", "'\(unit)' ist eine Sub-Einheit")
        }
        XCTAssertEqual(ShoppingItem.unitBucket("kg"), "kg", "kg bleibt ein eigener Eimer")
        XCTAssertEqual(ShoppingItem.unitBucket("l"), "l", "l bleibt ein eigener Eimer")
        XCTAssertEqual(ShoppingItem.unitBucket("el"), "el", "Unbekannte Einheiten bleiben sie selbst")
        XCTAssertEqual(ShoppingItem.unitBucket("KG"), "kg", "Die Schreibweise darf nicht entscheiden")
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

        // End-to-end, mit Issue #10 bewusst umgestellt: Die Migration repariert den Zahlenwert
        // weiterhin (Zusicherung oben, unveränderte Schutzwirkung), sie schreibt aber KEINEN
        // `learnedPriceUnits`-Eintrag. Der reparierte Wert gilt damit als einheitenloses Altdatum
        // und wird nicht mehr angewendet (PO-Entscheidung 1) — das neu angelegte Item bekommt
        // einen Schätzpreis statt der 2,29 €. Reparatur der Altdaten: Issue #11.
        let newItem = ShoppingItem(name: "Skyr Natur 500g", quantityAmount: 500, unit: "g", store: repairedStore)
        XCTAssertTrue(newItem.estimatedPriceIsAutoDerived,
                      "Ein gelernter Preis ohne Bezugsgröße darf nie angewendet werden, auch nicht nach der Reparatur")
        XCTAssertNotEqual(newItem.estimatedPrice ?? 0, 2.29 / 500, accuracy: 0.0001,
                          "Der reparierte, aber einheitenlose Altwert darf nicht als Preis übernommen werden")
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
