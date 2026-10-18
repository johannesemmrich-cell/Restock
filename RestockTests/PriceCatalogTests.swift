import XCTest
import SwiftData
@testable import Restock

/// Issues #160 (Pauschale ist kein Artikelpreis, Wortgrenzen), #161 (eigener Preis aus anderem
/// Laden) und #162 (Katalog mit Packung und Spanne). Vorher: 32 Stichwörter per Teilstring, sonst
/// Kategorie-Pauschale; von 100 Alltagsartikeln (siehe `commonGroceries`) trafen 39 einen
/// Produktpreis, „Tomatenmark" bekam den Tomatenpreis und fünf Milchprodukte standen mit
/// „ca. 2,00 €" untereinander. Nachher: siehe die einzelnen Tests.
@MainActor
final class PriceCatalogTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: CatalogEstimateRefresh.flagKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: CatalogEstimateRefresh.flagKey)
        super.tearDown()
    }

    private func makeStore(_ name: String) -> Store {
        Store(name: name, emoji: "🛒", colorHex: "#123456")
    }

    private func price(_ name: String, category: String = "", unit: String = "", quantity: Double = 1) -> Double? {
        PriceEstimator.estimate(for: name, category: category, unit: unit, quantityAmount: quantity)
    }

    // MARK: - #160 Screenshot: fünfmal „ca. 2,00 €"

    func testScreenshotItemsGetDistinctCatalogPricesInsteadOfFlatRate() throws {
        let names = ["Mozzarella", "Schlagsahne", "Parmesan", "Marmelade", "Tomatenmark", "Gauda"]
        var prices: [String: Double] = [:]
        for name in names {
            let item = ShoppingItem(name: name, category: AssignmentService.category(for: name))
            XCTAssertEqual(item.priceSource, "estimate", "\(name) muss ein Katalogtreffer sein, keine Pauschale")
            XCTAssertEqual(item.priceOrigin, "estimate", name)
            let value = try XCTUnwrap(item.estimatedPrice, "\(name) ohne Preis")
            XCTAssertNotEqual(value, 2.00, accuracy: 0.001, "\(name) darf nicht mehr die Pauschale 2,00 € tragen")
            prices[name] = value
        }
        XCTAssertGreaterThanOrEqual(Set(prices.values.map { Int($0 * 100) }).count, 5,
                                    "Sechs verschiedene Artikel, mindestens fünf verschiedene Preise: \(prices)")
        XCTAssertGreaterThan(try XCTUnwrap(prices["Parmesan"]), try XCTUnwrap(prices["Mozzarella"]),
                             "Parmesan (200 g) ist teurer als Mozzarella (125 g)")
        XCTAssertLessThan(try XCTUnwrap(prices["Tomatenmark"]), 1.50, "Tomatenmark ist kein Kilo Tomaten")
    }

    // MARK: - #160 Wortgrenzen statt Teilstring

    func testWordBoundaryPreventsFalseSubstringMatches() {
        // Vorher: „tee" in Teelicht (3,00 €), „wasser" in Wassermelone (0,90 €), „eier" in Eierlikör,
        // „zucker" in Zuckererbsen, „brot" in Brotmesser, „tomaten" in Tomatenmark (2,00 €).
        XCTAssertFalse(PriceCatalog.match("Teelicht")?.names.contains("tee") ?? false, "Teelicht ist kein Tee")
        XCTAssertNotEqual(price("Wassermelone") ?? 0, 0.90, accuracy: 0.001, "Wassermelone ist kein Wasser")
        XCTAssertFalse(PriceCatalog.match("Eierlikör")?.names.contains("eier") ?? false, "Eierlikör sind keine Eier")
        XCTAssertNil(PriceCatalog.match("Brotmesser"))
        XCTAssertNil(PriceCatalog.match("Zuckererbsen Glas")?.names.first(where: { $0 == "zucker" }))
        XCTAssertNotEqual(price("Tomatenmark") ?? 0, 2.00, accuracy: 0.001, "Tomatenmark ist nicht Tomaten")
        XCTAssertNil(PriceCatalog.match("Wasserkocher"), "Wasserkocher ist kein Wasser")
        XCTAssertNil(PriceCatalog.match("Saftpresse"), "Saftpresse ist kein Saft")
    }

    func testCompoundHeadNounStillMatches() {
        // Grundwort eines Kompositums bleibt ein Treffer — die bestehende UI-Erwartung
        // „Laugenbrötchen groß" → „ca. 2,50 €" (LegacyLearnedPriceResetUITests) gilt weiter.
        XCTAssertEqual(price("Laugenbrötchen groß"), 2.50)
        XCTAssertEqual(price("Kartoffelchips"), 1.80)
        XCTAssertEqual(PriceCatalog.match("Käsekuchen")?.names.first, "kuchen")
        XCTAssertEqual(PriceCatalog.match("Bio-Eier 10er")?.names.first, "eier", "Bindestrich und Zahl trennen Wörter")
        XCTAssertEqual(PriceCatalog.match("H-Milch 1,5%")?.names.first, "milch")
        // Zu kurze Namen (< 4 Zeichen) treffen nur als ganzes Wort.
        XCTAssertNil(PriceCatalog.match("Reisig"))
        XCTAssertEqual(PriceCatalog.match("Reis")?.names.first, "reis")
    }

    func testLongestMatchingNameWins() {
        XCTAssertEqual(PriceCatalog.match("Hafermilch")?.names.first, "hafermilch", "Hafermilch vor Milch")
        XCTAssertEqual(PriceCatalog.match("Knäckebrot")?.names.first, "knäckebrot", "Knäckebrot vor Brot")
        XCTAssertEqual(PriceCatalog.match("Knoblauch")?.names.first, "knoblauch", "Knoblauch vor Lauch")
        XCTAssertEqual(PriceCatalog.match("saure Sahne")?.names.first, "saure sahne", "Wortfolge vor Einzelwort")
        XCTAssertEqual(PriceCatalog.match("Milchreis")?.names.first, "milchreis", "Milchreis vor Milch und Reis")
    }

    // MARK: - #162 Katalog: Altwerte, Packung, Spanne

    func testLegacyKeywordValuesAreUnchanged() {
        XCTAssertEqual(price("Milch"), 1.20)
        XCTAssertEqual(price("Butter"), 2.20)
        XCTAssertEqual(price("Brot"), 2.50)
        XCTAssertEqual(price("Käse"), 3.50)
        XCTAssertEqual(price("Hackfleisch"), 4.00)
        XCTAssertEqual(try XCTUnwrap(price("Milch", unit: "g")), 1.20 / 1000, accuracy: 1e-12, "Altwert gilt je kg/l")
        XCTAssertEqual(price("Milch", unit: "kg"), 1.20)
        XCTAssertEqual(try XCTUnwrap(price("Milch", unit: "cl")), 1.20 / 100, accuracy: 1e-12)
    }

    func testPackageSizeScalesWeightAndVolumeUnits() throws {
        // Mozzarella: 125 g ≈ 1,09 € → ein Stück 1,09 €, 250 g 2,18 €, 1 kg 8,72 €.
        let perPiece = try XCTUnwrap(price("Mozzarella"))
        XCTAssertEqual(perPiece, 1.09, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(price("Mozzarella", unit: "g", quantity: 250)) * 250, 2.18, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(price("Mozzarella", unit: "kg")), 8.72, accuracy: 0.001)
        // Volumen: Hafermilch 1 l ≈ 1,69 €; 500 ml die Hälfte.
        XCTAssertEqual(try XCTUnwrap(price("Hafermilch", unit: "ml", quantity: 500)) * 500, 0.845, accuracy: 0.001)
        // Unplausible Summe bleibt verworfen (Issue „Müllbeutel 50l").
        XCTAssertNil(price("Mozzarella", unit: "kg", quantity: 50))
    }

    func testCatalogEntriesAreConsistent() {
        var seen: Set<String> = []
        for entry in PriceCatalog.entries {
            XCTAssertFalse(entry.names.isEmpty)
            XCTAssertGreaterThan(entry.packageAmount, 0, "\(entry.names)")
            XCTAssertTrue(["g", "ml", "stk"].contains(entry.packageUnit), "\(entry.names): \(entry.packageUnit)")
            XCTAssertLessThanOrEqual(entry.low, entry.typical, "\(entry.names)")
            XCTAssertLessThanOrEqual(entry.typical, entry.high, "\(entry.names)")
            XCTAssertGreaterThan(entry.low, 0, "\(entry.names)")
            XCTAssertFalse(entry.source.isEmpty, "\(entry.names)")
            for name in entry.names {
                XCTAssertEqual(name, name.lowercased(), "Namen kleingeschrieben: \(name)")
                XCTAssertEqual(name, name.trimmingCharacters(in: .whitespaces), "kein Rand-Leerzeichen: \(name)")
                XCTAssertFalse(name.contains("  "), name)
                XCTAssertTrue(seen.insert(name).inserted, "Name doppelt im Katalog: \(name)")
            }
        }
        XCTAssertGreaterThanOrEqual(PriceCatalog.entries.count, 250, "Katalog deutlich größer als die 32 Altstichwörter")
    }

    /// 100 Alltagsartikel. Vorher (32 Stichwörter, Teilstring): 39 Treffer. Nachher: alle.
    static let commonGroceries: [String] = [
        "Milch", "Butter", "Eier", "Brot", "Brötchen", "Käse", "Joghurt", "Quark", "Sahne", "Mozzarella",
        "Parmesan", "Gouda", "Frischkäse", "Hafermilch", "Apfel", "Bananen", "Tomaten", "Gurke", "Paprika", "Zwiebeln",
        "Kartoffeln", "Karotten", "Salat", "Zitrone", "Avocado", "Champignons", "Brokkoli", "Erdbeeren", "Trauben", "Orangen",
        "Hackfleisch", "Hähnchenbrust", "Schnitzel", "Salami", "Schinken", "Wiener Würstchen", "Lachs", "Thunfisch", "Fischstäbchen", "Nudeln",
        "Spaghetti", "Reis", "Mehl", "Zucker", "Salz", "Pfeffer", "Olivenöl", "Essig", "Ketchup", "Senf",
        "Marmelade", "Honig", "Nutella", "Müsli", "Haferflocken", "Cornflakes", "Kaffee", "Tee", "Kakao", "Mineralwasser",
        "Apfelsaft", "Cola", "Bier", "Wein", "Chips", "Schokolade", "Kekse", "Gummibärchen", "Nüsse", "Pizza",
        "Pommes", "Eis", "Tomatenmark", "Passierte Tomaten", "Kichererbsen", "Linsen", "Mais", "Kokosmilch", "Pesto", "Toastbrot",
        "Croissants", "Tofu", "Seitan", "Skyr", "Schlagsahne", "Zahnpasta", "Shampoo", "Duschgel", "Deo", "Toilettenpapier",
        "Küchenrolle", "Taschentücher", "Spülmittel", "Waschmittel", "Weichspüler", "Müllbeutel", "Spülmaschinentabs", "Alufolie", "Backpapier", "Batterien",
    ]

    func testCoverageOfCommonGroceries() {
        XCTAssertEqual(Self.commonGroceries.count, 100)
        let missing = Self.commonGroceries.filter { PriceCatalog.match($0) == nil }
        XCTAssertTrue(missing.isEmpty, "Ohne Katalogpreis: \(missing)")
        for name in Self.commonGroceries {
            let item = ShoppingItem(name: name, category: AssignmentService.category(for: name))
            XCTAssertEqual(item.priceSource, "estimate", name)
            XCTAssertNotNil(item.estimatedPrice, name)
        }
    }

    // MARK: - #160 Pauschale ist kein Artikelpreis

    func testCategoryFlatRateIsMarkedAsCategoryAndShowsPrompt() {
        let flat = ShoppingItem(name: "artikel ohne keyword-treffer", category: "Milchprodukte")
        XCTAssertEqual(flat.estimatedPrice, 2.00, "Pauschale rechnet weiter in Summen")
        XCTAssertTrue(flat.estimatedPriceIsAutoDerived)
        XCTAssertEqual(flat.priceSource, "category")
        XCTAssertEqual(flat.priceOrigin, "category")
        XCTAssertEqual(PriceSourceDisplay.amountPrefix(origin: "category"), "ca. ")
        XCTAssertTrue(PriceSourceDisplay.showsPrompt(origin: flat.priceOrigin, hasPrice: flat.estimatedPrice != nil,
                                                     isAutoDerived: flat.estimatedPriceIsAutoDerived),
                      "Zeile zeigt „Preis?" statt eines Pauschalbetrags")

        let catalog = ShoppingItem(name: "Mozzarella", category: "Milchprodukte")
        XCTAssertFalse(PriceSourceDisplay.showsPrompt(origin: catalog.priceOrigin, hasPrice: true,
                                                      isAutoDerived: catalog.estimatedPriceIsAutoDerived),
                       "Katalogtreffer bleibt als „ca. …" sichtbar")

        XCTAssertTrue(PriceSourceDisplay.showsPrompt(origin: "estimate", hasPrice: false, isAutoDerived: true),
                      "ohne jede Schätzung ebenfalls „Preis?"")
        XCTAssertFalse(PriceSourceDisplay.showsPrompt(origin: "manual", hasPrice: true, isAutoDerived: false))
        XCTAssertFalse(PriceSourceDisplay.showsPrompt(origin: "category", hasPrice: true, isAutoDerived: false),
                       "ein echter Preis zeigt nie die Aufforderung, egal was die Kennung sagt")

        let german = Locale(identifier: "de_DE")
        XCTAssertEqual(PriceSourceDisplay.text(origin: "category", date: nil, locale: german), "Pauschale")
        XCTAssertEqual(PriceEstimator.resolve(for: "artikel ohne keyword-treffer", category: "Konserven", unit: "")?.source, "category")
        XCTAssertEqual(PriceEstimator.resolve(for: "Tomatenmark", category: "Konserven", unit: "")?.source, "estimate")
        XCTAssertNil(PriceEstimator.resolve(for: "artikel ohne keyword-treffer", category: "Eigene Kategorie", unit: ""))
    }

    func testTotalCaptionNamesEstimatedShare() {
        XCTAssertEqual(StoreDetailView.totalCaption(estimated: 3, priced: 6), "3 von 6 geschätzt")
        XCTAssertEqual(StoreDetailView.totalCaption(estimated: 0, priced: 6), "Geschätzter Betrag")
        XCTAssertTrue(StoreDetailView.totalText(12.4, estimated: 2, currencyCode: "EUR").hasPrefix("ca. "))
        XCTAssertFalse(StoreDetailView.totalText(12.4, estimated: 0, currencyCode: "EUR").hasPrefix("ca. "))
    }

    func testNewLocalizationKeysAreRegistered() {
        let keys = Set(PriceSourceDisplay.allLocalizationKeys)
        for key in ["price.source.category", "price.source.otherstore", "price.prompt",
                    "price.prompt.accessibility", "price.total.estimated.count"] {
            XCTAssertTrue(keys.contains(key), key)
        }
    }

    // MARK: - #161 Eigener Preis aus anderem Laden

    func testOtherStorePriceBeatsCatalogButNotOwnStore() throws {
        let rewe = makeStore("Rewe")
        let lidl = makeStore("Lidl")
        lidl.learnedPrices["mozzarella"] = 0.99
        lidl.learnedPriceUnits["mozzarella"] = "stk"
        lidl.learnedPriceDates["mozzarella"] = Date(timeIntervalSince1970: 1_000_000)
        let aldi = makeStore("Aldi")
        aldi.learnedPrices["mozzarella"] = 1.05
        aldi.learnedPriceUnits["mozzarella"] = "stk"
        aldi.learnedPriceDates["mozzarella"] = Date(timeIntervalSince1970: 2_000_000)

        // Jüngster fremder Eintrag gewinnt.
        let item = ShoppingItem(name: "Mozzarella", category: "Milchprodukte", store: rewe, otherStores: [rewe, lidl, aldi])
        XCTAssertEqual(try XCTUnwrap(item.estimatedPrice), 1.05, accuracy: 0.0001)
        XCTAssertFalse(item.estimatedPriceIsAutoDerived, "ein eigener Preis ist echt, keine Schätzung")
        XCTAssertEqual(item.priceSource, "otherStore:Aldi")
        XCTAssertEqual(item.priceOrigin, "otherStore")
        XCTAssertEqual(item.priceSourceDetail, "Aldi")
        XCTAssertEqual(PriceSourceDisplay.amountPrefix(origin: item.priceOrigin), "")
        XCTAssertEqual(PriceSourceDisplay.text(origin: item.priceOrigin, date: nil, detail: item.priceSourceDetail,
                                               locale: Locale(identifier: "de_DE")), "zuletzt bei Aldi")
        XCTAssertFalse(PriceSourceDisplay.showsPrompt(origin: item.priceOrigin, hasPrice: true, isAutoDerived: false))

        // Der eigene Laden hat Vorrang.
        rewe.learnedPrices["mozzarella"] = 1.29
        rewe.learnedPriceUnits["mozzarella"] = "stk"
        let own = ShoppingItem(name: "Mozzarella", category: "Milchprodukte", store: rewe, otherStores: [lidl, aldi])
        XCTAssertEqual(try XCTUnwrap(own.estimatedPrice), 1.29, accuracy: 0.0001)
        XCTAssertEqual(own.priceSource, "learned")

        // Ohne andere Läden (Siri, Widget, Sync): Katalog wie bisher.
        let alone = ShoppingItem(name: "Mozzarella", category: "Milchprodukte", store: makeStore("Edeka"))
        XCTAssertEqual(alone.priceSource, "estimate")
        XCTAssertEqual(try XCTUnwrap(alone.estimatedPrice), 1.09, accuracy: 0.0001)
    }

    func testOtherStorePriceObeysUnitTableAndCap() throws {
        let rewe = makeStore("Rewe")
        let lidl = makeStore("Lidl")
        // Gramm-Rate an einen Stückartikel mit eingetippter Menge: verworfen (Issue #10) → Katalog.
        lidl.learnedPrices["mozzarella"] = 0.008
        lidl.learnedPriceUnits["mozzarella"] = "g"
        let mismatch = ShoppingItem(name: "Mozzarella", category: "Milchprodukte", store: rewe, otherStores: [lidl])
        XCTAssertEqual(mismatch.priceSource, "estimate")
        XCTAssertTrue(mismatch.estimatedPriceIsAutoDerived)

        // Obergrenze (200 €) gilt auch für fremde Läden.
        lidl.learnedPrices["mozzarella"] = 150
        lidl.learnedPriceUnits["mozzarella"] = "stk"
        let capped = ShoppingItem(name: "Mozzarella", category: "Milchprodukte", quantityAmount: 2, store: rewe, otherStores: [lidl])
        XCTAssertEqual(capped.priceSource, "estimate")

        // Gleiches Datum: alphabetisch kleinerer Ladenname, deterministisch.
        let aldi = makeStore("Aldi")
        let date = Date(timeIntervalSince1970: 3_000_000)
        for store in [lidl, aldi] {
            store.learnedPrices["mozzarella"] = store === aldi ? 0.95 : 0.99
            store.learnedPriceUnits["mozzarella"] = "stk"
            store.learnedPriceDates["mozzarella"] = date
        }
        let tie = ShoppingItem(name: "Mozzarella", category: "Milchprodukte", store: rewe, otherStores: [lidl, aldi])
        XCTAssertEqual(tie.priceSource, "otherStore:Aldi")
        XCTAssertEqual(try XCTUnwrap(tie.estimatedPrice), 0.95, accuracy: 0.0001)
    }

    // MARK: - Auffrischung bestehender Artikel

    func testCatalogEstimateRefreshRecomputesOnlyAutoDerivedPrices() throws {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)
        let store = makeStore("Rewe")
        context.insert(store)

        // Altzustand aus dem Screenshot: Pauschale 2,00 € ohne Quellkennung.
        let mozzarella = ShoppingItem(name: "Mozzarella", category: "Milchprodukte", store: store)
        mozzarella.estimatedPrice = 2.00
        mozzarella.priceSource = ""
        // Unbekannter Artikel mit alter Kennung „estimate" → wird zur Pauschale „category".
        let unknown = ShoppingItem(name: "Unbekanntes Zeug", category: "Lebensmittel", store: store)
        unknown.estimatedPrice = 2.50
        unknown.priceSource = "estimate"
        // Eigener Preis bleibt unangetastet.
        let manual = ShoppingItem(name: "Parmesan", category: "Milchprodukte", store: store)
        manual.estimatedPrice = 4.44
        manual.estimatedPriceIsAutoDerived = false
        manual.priceSource = "manual"
        for item in [mozzarella, unknown, manual] { context.insert(item) }
        try context.save()

        CatalogEstimateRefresh.runIfNeeded(context: context)

        XCTAssertEqual(try XCTUnwrap(mozzarella.estimatedPrice), 1.09, accuracy: 0.0001)
        XCTAssertEqual(mozzarella.priceSource, "estimate")
        XCTAssertTrue(mozzarella.estimatedPriceIsAutoDerived)
        XCTAssertEqual(try XCTUnwrap(unknown.estimatedPrice), 2.90, accuracy: 0.0001, "Pauschale „Lebensmittel\"")
        XCTAssertEqual(unknown.priceSource, "category")
        XCTAssertEqual(manual.estimatedPrice, 4.44)
        XCTAssertEqual(manual.priceSource, "manual")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: CatalogEstimateRefresh.flagKey))

        // Zweiter Lauf: Flag gesetzt, nichts wird mehr angefasst.
        mozzarella.estimatedPrice = 2.00
        CatalogEstimateRefresh.runIfNeeded(context: context)
        XCTAssertEqual(mozzarella.estimatedPrice, 2.00)

        XCTAssertNil(CatalogEstimateRefresh.refreshed(isAutoDerived: false, name: "Parmesan", priceCategory: "Milchprodukte",
                                                      unit: "", quantityAmount: 1))
        XCTAssertEqual(CatalogEstimateRefresh.priceCategory(for: unknown), "Lebensmittel")
        let custom = ShoppingItem(name: "Mozzarella", category: "Meine Käsetheke")
        XCTAssertEqual(CatalogEstimateRefresh.priceCategory(for: custom), AssignmentService.category(for: "Mozzarella"),
                       "eigene Kategorie hat keine Pauschale, die Schätzung nimmt die automatische")
    }
}
