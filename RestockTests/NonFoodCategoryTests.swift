import XCTest
@testable import Restock

/// Issue #221: Kategorien für Drogerie- und Baumärkte und die Warenkunde dahinter
/// (`AssignmentService+NonFoodCategories.swift`). Spec: `docs/specs/models/non-food-categories.md`.
final class NonFoodCategoryTests: XCTestCase {

    private func cat(_ name: String) -> String { AssignmentService.category(for: name) }

    // MARK: - K1: Die neun neuen Kategorien sind vollständig verdrahtet

    /// Rohwert → Schlüssel in `Localizable.strings`, wie `displayCategory` ihn aufruft.
    private static let localizationKeys: [String: String] = [
        "Haarpflege": "category.haircare", "Zahnpflege": "category.dentalcare", "Kosmetik": "category.cosmetics",
        "Hygieneartikel": "category.hygiene", "Tierbedarf": "category.pets", "Eisenwaren": "category.fasteners",
        "Holz": "category.wood", "Boden & Fliesen": "category.flooring", "Pflanzen": "category.plants",
    ]

    private func stringsTable(_ localization: String) throws -> [String: String] {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: localization),
            "Localizable.strings für \(localization) fehlt")
        return try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])
    }

    func testNewCategoriesAreInOrderDisplayEmojiAndFlatRate() throws {
        let newOnes = AssignmentService.nonFoodCategoriesAddedIn221
        XCTAssertEqual(newOnes.count, 9)
        let de = try stringsTable("de")
        let en = try stringsTable("en")
        for category in newOnes {
            XCTAssertTrue(AssignmentService.categoryOrder.contains(category), "\(category) fehlt in categoryOrder")
            let key = try XCTUnwrap(Self.localizationKeys[category], "\(category) ohne Schlüssel im Test")
            XCTAssertEqual(de[key], category, "deutscher Anzeigename von \(category) muss dem Rohwert gleichen")
            XCTAssertFalse((en[key] ?? "").isEmpty, "englischer Anzeigename von \(category) fehlt")
            XCTAssertFalse(AssignmentService.displayCategory(category).isEmpty)
            XCTAssertNotEqual(AssignmentService.categoryEmoji(category), "🏷️", "\(category) hat kein eigenes Emoji")
            XCTAssertNotNil(PriceEstimator.categoryFlatRate(category), "\(category) hat keine Pauschale")
        }
        XCTAssertEqual(AssignmentService.categoryOrder.count, 35)
        XCTAssertEqual(Set(AssignmentService.categoryOrder).count, 35, "Kategorien müssen eindeutig sein")
    }

    func testStoreTypeListsOnlyNameRealCategories() {
        for category in Category.drugstore + Category.hardware {
            XCTAssertTrue(AssignmentService.categoryOrder.contains(category),
                          "\(category) steht in einer Ladentyp-Liste, ist aber keine Artikelkategorie")
        }
        XCTAssertFalse(Category.drugstore.contains("Haushalt"))
    }

    func testEveryMapCategoryIsKnown() {
        for entry in AssignmentService.nonFoodCategoryMap {
            XCTAssertTrue(AssignmentService.categoryOrder.contains(entry.category), "Unbekannte Kategorie \(entry.category)")
            if let group = entry.storeGroup {
                XCTAssertTrue(["drugstore", "hardware", "variety"].contains(group), "Unbekannter Ladentyp \(group)")
            }
            for keyword in entry.keywords {
                XCTAssertEqual(keyword, keyword.lowercased(), "Stichwort nicht kleingeschrieben: \(keyword)")
                XCTAssertEqual(keyword, keyword.trimmingCharacters(in: .whitespaces), "Stichwort mit Rand-Leerzeichen: \(keyword)")
            }
        }
        for rule in AssignmentService.nonFoodCategoryEndings {
            XCTAssertTrue(AssignmentService.categoryOrder.contains(rule.category), "Unbekannte Kategorie \(rule.category) in Wortend-Regel")
        }
    }

    /// Ein Stichwort darf nicht in zwei Einträgen mit verschiedener Kategorie stehen, sonst entscheidet
    /// die Listenreihenfolge statt der Warenkunde.
    func testNoKeywordMapsToTwoCategories() {
        var seen: [String: String] = [:]
        for entry in AssignmentService.nonFoodCategoryMap {
            for keyword in entry.keywords {
                if let other = seen[keyword], other != entry.category {
                    XCTFail("„\(keyword)“ steht unter \(other) und \(entry.category)")
                }
                seen[keyword] = entry.category
            }
        }
    }

    // MARK: - K2: Drogerie (dm, Rossmann, Müller)

    func testDrugstoreItemsLandInTheirShelf() {
        XCTAssertEqual(cat("Zahnpasta"), "Zahnpflege")
        XCTAssertEqual(cat("Zahnbürste"), "Zahnpflege")
        XCTAssertEqual(cat("Zahnseide"), "Zahnpflege")
        XCTAssertEqual(cat("Oral-B Aufsteckbürsten"), "Zahnpflege")
        XCTAssertEqual(cat("Haarfarbe"), "Haarpflege")
        XCTAssertEqual(cat("Shampoo"), "Haarpflege")
        XCTAssertEqual(cat("Haarspray"), "Haarpflege")
        XCTAssertEqual(cat("Lippenstift"), "Kosmetik")
        XCTAssertEqual(cat("Mascara"), "Kosmetik")
        XCTAssertEqual(cat("Nagellack"), "Kosmetik")
        XCTAssertEqual(cat("Parfum"), "Kosmetik")
        XCTAssertEqual(cat("Tagescreme"), "Kosmetik")
        XCTAssertEqual(cat("Tampons"), "Hygieneartikel")
        XCTAssertEqual(cat("Toilettenpapier"), "Hygieneartikel")
        XCTAssertEqual(cat("Küchenrolle"), "Hygieneartikel")
        XCTAssertEqual(cat("Taschentücher"), "Hygieneartikel")
        XCTAssertEqual(cat("Wattepads"), "Hygieneartikel")
        XCTAssertEqual(cat("Duschgel"), "Körperpflege")
        XCTAssertEqual(cat("Sonnencreme"), "Körperpflege")
        XCTAssertEqual(cat("Nasenspray"), "Medikamente")
        XCTAssertEqual(cat("Hustensaft"), "Medikamente")
        XCTAssertEqual(cat("Magnesium"), "Medikamente")
        XCTAssertEqual(cat("Pampers"), "Babybedarf")
        XCTAssertEqual(cat("Babybrei"), "Babybedarf")
        XCTAssertEqual(cat("Weichspüler"), "Reinigung")
        XCTAssertEqual(cat("Spülmaschinentabs"), "Reinigung")
        XCTAssertEqual(cat("Schwamm"), "Reinigung")
        XCTAssertEqual(cat("Müllbeutel"), "Haushaltswaren")
        XCTAssertEqual(cat("Alufolie"), "Haushaltswaren")
    }

    func testPetSuppliesHaveTheirOwnShelf() {
        XCTAssertEqual(cat("Katzenstreu"), "Tierbedarf")
        XCTAssertEqual(cat("Hundefutter"), "Tierbedarf")
        XCTAssertEqual(cat("Whiskas"), "Tierbedarf")
        XCTAssertEqual(cat("Vogelfutter"), "Tierbedarf")
        XCTAssertEqual(cat("Katzenmilch"), "Tierbedarf", "„katzen“ ist länger als „milch“")
        XCTAssertEqual(cat("Kratzbaum"), "Tierbedarf")
    }

    // MARK: - K3: Baumarkt (Hornbach, OBI, Bauhaus, toom)

    func testHardwareStoreItemsLandInTheirHall() {
        XCTAssertEqual(cat("Spax Schrauben 4x40"), "Eisenwaren")
        XCTAssertEqual(cat("Dübel"), "Eisenwaren")
        XCTAssertEqual(cat("Scharnier"), "Eisenwaren")
        XCTAssertEqual(cat("Vorhängeschloss"), "Eisenwaren")
        XCTAssertEqual(cat("OSB-Platte"), "Holz")
        XCTAssertEqual(cat("Dachlatten"), "Holz")
        XCTAssertEqual(cat("Terrassendielen Douglasie"), "Holz")
        XCTAssertEqual(cat("Laminat"), "Boden & Fliesen")
        XCTAssertEqual(cat("Fliesen"), "Boden & Fliesen")
        XCTAssertEqual(cat("Fliesenkleber"), "Boden & Fliesen")
        XCTAssertEqual(cat("Sockelleisten"), "Boden & Fliesen")
        XCTAssertEqual(cat("Zement"), "Baumaterial")
        XCTAssertEqual(cat("Rigips"), "Baumaterial")
        XCTAssertEqual(cat("Silikon"), "Baumaterial")
        XCTAssertEqual(cat("Bauschaum"), "Baumaterial")
        XCTAssertEqual(cat("Wandfarbe weiß"), "Farbe & Lack")
        XCTAssertEqual(cat("Kleister"), "Farbe & Lack")
        XCTAssertEqual(cat("Lichtschalter"), "Elektronik")
        XCTAssertEqual(cat("Kabelkanal"), "Elektronik")
        XCTAssertEqual(cat("Rauchmelder"), "Elektronik")
        XCTAssertEqual(cat("Wasserhahn"), "Sanitär")
        XCTAssertEqual(cat("Duschkopf"), "Sanitär")
        XCTAssertEqual(cat("Heizkörperthermostat"), "Sanitär")
        XCTAssertEqual(cat("Akkuschrauber"), "Werkzeug")
        XCTAssertEqual(cat("Schleifpapier"), "Werkzeug")
        XCTAssertEqual(cat("Leiter"), "Werkzeug")
    }

    func testGardenAndPlantsAreSeparate() {
        XCTAssertEqual(cat("Blumenerde"), "Garten")
        XCTAssertEqual(cat("Rasendünger"), "Garten")
        XCTAssertEqual(cat("Gießkanne"), "Garten")
        XCTAssertEqual(cat("Blumentopf"), "Garten", "vorher Küchenausstattung über „topf“")
        XCTAssertEqual(cat("Hochbeet"), "Garten")
        XCTAssertEqual(cat("Grillkohle"), "Garten")
        XCTAssertEqual(cat("Tomatenpflanze"), "Pflanzen")
        XCTAssertEqual(cat("Kräutertopf"), "Pflanzen")
        XCTAssertEqual(cat("Orchidee"), "Pflanzen")
        XCTAssertEqual(cat("Blumenstrauß"), "Pflanzen")
        XCTAssertEqual(cat("Thuja"), "Pflanzen")
        XCTAssertEqual(cat("Rasensamen"), "Garten")
    }

    // MARK: - K4: Lebensmittel bleiben Lebensmittel (längstes Stichwort gewinnt)

    func testFoodNamesWithNonFoodStemsStayFood() {
        XCTAssertEqual(cat("Crème fraîche"), "Milchprodukte")
        XCTAssertEqual(cat("Cremefraiche"), "Milchprodukte")
        XCTAssertEqual(cat("Eiscreme"), "Tiefkühlkost")
        XCTAssertEqual(cat("Mandelmilch"), "Milchprodukte")
        XCTAssertEqual(cat("Hafermilch"), "Milchprodukte")
        XCTAssertEqual(cat("Pflanzenöl"), "Konserven")
        XCTAssertEqual(cat("Leinsamen"), "Konserven")
        XCTAssertEqual(cat("Streusel"), "Gewürze & Backen")
        XCTAssertEqual(cat("Jasminreis"), "Konserven")
        XCTAssertEqual(cat("Nagelkäse"), "Milchprodukte")
        XCTAssertEqual(cat("Rosenkohl"), "Obst & Gemüse")
        XCTAssertEqual(cat("Bierschinken"), "Fleisch & Wurst")
        XCTAssertEqual(cat("Weingummi"), "Snacks")
        XCTAssertEqual(cat("Rohrzucker"), "Gewürze & Backen", "vorher Sanitär über „rohr“")
        XCTAssertEqual(cat("Sandwich"), "Lebensmittel")
        XCTAssertEqual(cat("Milch"), "Milchprodukte")
        XCTAssertEqual(cat("Butter"), "Milchprodukte")
        XCTAssertEqual(cat("Hackfleisch"), "Fleisch & Wurst")
        XCTAssertEqual(cat("Nudeln"), "Konserven")
    }

    func testReinigungsmilchIsNotDairy() {
        XCTAssertEqual(cat("Reinigungsmilch"), "Kosmetik")
        XCTAssertEqual(cat("Scheuermilch"), "Reinigung")
    }

    // MARK: - K5: Wortend-Regeln als letzte Stufe

    func testEndingRulesOnlyApplyWhenNothingElseMatches() {
        XCTAssertEqual(AssignmentService.nonFoodCategoryByEnding(forLowercased: "fassadenschrauben"), "Eisenwaren")
        XCTAssertEqual(AssignmentService.nonFoodCategoryByEnding(forLowercased: "igelfutter"), "Tierbedarf")
        XCTAssertEqual(AssignmentService.nonFoodCategoryByEnding(forLowercased: "spezialdünger"), "Garten")
        XCTAssertNil(AssignmentService.nonFoodCategoryByEnding(forLowercased: "deo"), "zu kurz für eine Endungsregel")
        XCTAssertNil(AssignmentService.nonFoodCategoryByEnding(forLowercased: "gang 7"))
        // Ein Lebensmittel-Stichwort geht vor jeder Endung: „Teebeutel“ ist Getränk, nicht Haushaltsware.
        XCTAssertEqual(cat("Teebeutel"), "Getränke")
        XCTAssertEqual(cat("Igelfutter"), "Tierbedarf")
        XCTAssertEqual(cat("Fassadenschrauben"), "Eisenwaren")
    }

    // MARK: - K6: Ladentyp für die Zuordnung

    private func store(_ name: String, _ categories: [String], visits: Double = 1) -> Store {
        Store(name: name, emoji: "🛒", colorHex: "#000000", visitsPerWeek: visits, categories: categories)
    }

    func testDrugstoreItemsGoToTheDrugstore() {
        let lidl = store("Lidl", Category.grocery, visits: 3)
        let dm = store("dm", Category.drugstore)
        XCTAssertEqual(AssignmentService.assign(itemName: "Haarfarbe", to: [lidl, dm])?.name, "dm")
        XCTAssertEqual(AssignmentService.assign(itemName: "Zahnseide", to: [lidl, dm])?.name, "dm")
        XCTAssertEqual(AssignmentService.assign(itemName: "Nagellack", to: [lidl, dm])?.name, "dm")
        XCTAssertEqual(AssignmentService.assign(itemName: "Milch", to: [lidl, dm])?.name, "Lidl")
        // Tierbedarf hat keinen bevorzugten Ladentyp: der meistbesuchte Supermarkt.
        XCTAssertEqual(AssignmentService.assign(itemName: "Katzenstreu", to: [lidl, dm])?.name, "Lidl")
    }

    func testHardwareItemsGoToTheHardwareStore() {
        let lidl = store("Lidl", Category.grocery, visits: 3)
        let hornbach = store("Hornbach", Category.hardware, visits: 0.5)
        XCTAssertEqual(AssignmentService.assign(itemName: "OSB-Platte", to: [lidl, hornbach])?.name, "Hornbach")
        XCTAssertEqual(AssignmentService.assign(itemName: "Spax 4x50", to: [lidl, hornbach])?.name, "Hornbach")
        XCTAssertEqual(AssignmentService.assign(itemName: "Laminat", to: [lidl, hornbach])?.name, "Hornbach")
        XCTAssertEqual(AssignmentService.assign(itemName: "Tomatenpflanze", to: [lidl, hornbach])?.name, "Hornbach")
        XCTAssertEqual(AssignmentService.assign(itemName: "Lichtschalter", to: [lidl, hornbach])?.name, "Hornbach")
        XCTAssertEqual(AssignmentService.assign(itemName: "Milch", to: [lidl, hornbach])?.name, "Lidl")
    }

    /// Ist-Verhalten, kein Beschluss (Bestand vor #221, Änderung in #224): „Werkzeug“ steht in
    /// `Category.variety` UND `Category.hardware`, darum zählt ein Sonstiges-Laden wie Action auch als
    /// Baumarkt und ein Baumarkt auch als Sonstiges-Laden; unter den Kandidaten gewinnt ohne Kaufhistorie
    /// der meistbesuchte. Ohne Baumarkt fällt Baumarkt-Ware auf den Sonstiges-Laden zurück.
    func testVarietyStoreAlsoCountsAsHardwareStoreByVisits() {
        let lidl = store("Lidl", Category.grocery, visits: 3)
        let action = store("Action", Category.variety, visits: 1)
        let hornbach = store("Hornbach", Category.hardware, visits: 0.5)
        XCTAssertEqual(AssignmentService.assign(itemName: "OSB-Platte", to: [lidl, action, hornbach])?.name, "Action")
        XCTAssertEqual(AssignmentService.assign(itemName: "Batterien", to: [lidl, action, hornbach])?.name, "Action")
        XCTAssertEqual(AssignmentService.assign(itemName: "Dübel", to: [lidl, action])?.name, "Action")
        let hornbachWeekly = store("Hornbach", Category.hardware, visits: 2)
        XCTAssertEqual(AssignmentService.assign(itemName: "Lichtschalter", to: [lidl, action, hornbachWeekly])?.name, "Hornbach")
        // Die Überlappung wirkt in beide Richtungen: Hornbach zählt über „Werkzeug“ auch als Sonstiges-Laden
        // und gewinnt Elektro-Kleinkram, sobald er öfter besucht wird (CI-Lauf 40196002586; Folge-Issue #224).
        XCTAssertEqual(AssignmentService.assign(itemName: "Batterien", to: [lidl, action, hornbachWeekly])?.name, "Hornbach")
    }

    func testStoreGroupYieldsToLongerFoodKeyword() {
        XCTAssertEqual(AssignmentService.nonFoodStoreGroup(forLowercased: "cremefraiche"), "grocery",
                       "Lebensmittel-Ausnahme: nicht mehr über „creme“ zur Drogerie")
        XCTAssertEqual(AssignmentService.nonFoodStoreGroup(forLowercased: "katzenstreu"), "grocery", "Tierbedarf ohne Ladentyp")
        XCTAssertNil(AssignmentService.nonFoodStoreGroup(forLowercased: "milch"), "kein Non-Food-Stichwort")
        XCTAssertNil(AssignmentService.nonFoodStoreGroup(forLowercased: "rosenkohl"), "„rosenkohl“ ist länger als „rose“")
        XCTAssertEqual(AssignmentService.nonFoodStoreGroup(forLowercased: "haarfarbe"), "drugstore")
        XCTAssertEqual(AssignmentService.nonFoodStoreGroup(forLowercased: "osb-platte"), "hardware")
        XCTAssertEqual(AssignmentService.nonFoodStoreGroup(forLowercased: "batterien"), "variety")
    }

    // MARK: - K7: Eigene Kategorien bekommen passende Emoji-Vorschläge

    func testSuggestedEmojiForNewShelves() {
        XCTAssertEqual(StoreCategories.suggestedEmoji(for: "Haare"), "💇")
        XCTAssertEqual(StoreCategories.suggestedEmoji(for: "Zahnpflege"), "🦷")
        XCTAssertEqual(StoreCategories.suggestedEmoji(for: "Schrauben & Dübel"), "🔩")
        XCTAssertEqual(StoreCategories.suggestedEmoji(for: "Holzzuschnitt"), "🪵")
        XCTAssertEqual(StoreCategories.suggestedEmoji(for: "Bodenbeläge"), "🧱")
        XCTAssertEqual(StoreCategories.suggestedEmoji(for: "Farben"), "🎨")
        XCTAssertEqual(StoreCategories.suggestedEmoji(for: "Pflanzen draußen"), "🌸")
    }
}
