import XCTest
@testable import Restock

/// Erweiterung des Preiskatalogs (PO 2026-10-22, `docs/specs/models/price-catalog-expansion.md`):
/// neue Bereiche Drogerie, Haushalt und Sport, Marken und Kurzformen als Namen, reguläre Mehrzahl,
/// Tippfehler-Toleranz und Sperr-Endungen gegen Grundwort-Fehltreffer („Fahrradschlauch" ist
/// kein „Lauch"). Vorher trafen von den 100 Drogerie-Stichwörtern des `AssignmentService` 52 einen
/// Katalogpreis, „Hack", „Spüli", „Tabs", „Milka", „Joghurts" und „Banan" gar keinen.
@MainActor
final class PriceCatalogExpansionTests: XCTestCase {

    private func first(_ name: String) -> String? {
        PriceCatalog.match(name)?.names.first
    }

    private func price(_ name: String) -> Double? {
        PriceEstimator.estimate(for: name, category: "", unit: "", quantityAmount: 1)
    }

    // MARK: - Neue Bereiche

    func testNewAreasHaveCatalogEntries() {
        let drugstore = ["Zahnpasta", "Duschbad", "Shampoo", "Deo", "Rasierer", "Wattepads", "Haarfarbe",
                         "Mizellenwasser", "Babyöl", "Augentropfen", "Wimperntusche", "Desinfektionsspray"]
        let household = ["Spülmittel", "Spülmaschinentabs", "Waschmittel", "Weichspüler", "Müllbeutel",
                         "Küchenrolle", "Toilettenpapier", "Schwämme", "Batterien", "Glühbirne",
                         "Scheuermilch", "Wäscheklammern", "Geschirrtuch", "Kleiderbügel"]
        let sports = ["Tennisbälle", "Trinkflasche", "Yogamatte", "Sportsocken", "Fahrradschlauch",
                      "Trekkingnahrung", "Trek-Nahrung", "Outdoor Mahlzeit", "Fahrradhelm", "Isomatte",
                      "Schwimmbrille", "Gaskartusche", "Fahrradpumpe", "Flickzeug"]
        for name in drugstore + household + sports {
            XCTAssertNotNil(PriceCatalog.match(name), "\(name) ohne Katalogpreis")
            let item = ShoppingItem(name: name, category: AssignmentService.category(for: name))
            XCTAssertEqual(item.priceSource, "estimate", "\(name) muss ein Katalogtreffer sein, keine Pauschale")
            XCTAssertNotNil(item.estimatedPrice, name)
        }
        XCTAssertGreaterThanOrEqual(PriceCatalog.drugstore.count, 40)
        XCTAssertGreaterThanOrEqual(PriceCatalog.householdMore.count, 60)
        XCTAssertGreaterThanOrEqual(PriceCatalog.sports.count, 70)
        XCTAssertGreaterThanOrEqual(PriceCatalog.entries.count, 500, "mindestens ~150 neue Einträge zu den 308 vom 2026-10-19")
    }

    func testSportPricesAreInPlausibleRange() throws {
        // Ein Fahrradschlauch kostet weder 2,49 € (Lauch) noch 40 € (Fahrradschloss).
        XCTAssertEqual(try XCTUnwrap(price("Fahrradschlauch")), 5.99, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(price("Tennisbälle")), 5.99, accuracy: 0.001)
        XCTAssertGreaterThan(try XCTUnwrap(PriceCatalog.match("Zelt")?.typical), try XCTUnwrap(price("Trinkflasche")))
        // Über der Plausibilitätsgrenze (30 €) bleibt es bei „Preis?" statt einer Schätzung.
        XCTAssertNil(price("Zelt"))
        XCTAssertGreaterThan(PriceEstimator.maxPlausibleLineTotal, try XCTUnwrap(price("Fahrradhelm")))
    }

    /// Stichwörter, mit denen `AssignmentService` Drogerieartikel zuordnet: vorher 52 von 100 mit
    /// Katalogpreis, gemessen 97 (Rest: „cleaning", „oral", „shaving" — keine Artikel).
    func testDrugstoreKeywordCoverage() {
        let keywords = AssignmentService.drugstoreKeywords
        let missing = keywords.filter { PriceCatalog.match($0) == nil }.sorted()
        XCTAssertEqual(keywords.count, 100, "Zahl der Drogerie-Stichwörter (bewusst anpassen, wenn die Liste wächst)")
        XCTAssertLessThanOrEqual(missing.count, 5, "Drogerie-Stichwörter ohne Katalogpreis: \(missing)")
    }

    // MARK: - Marken und Kurzformen

    func testBrandsMapToTheirProduct() {
        XCTAssertEqual(first("Oatly"), "hafermilch")
        XCTAssertEqual(first("Alpro"), "sojamilch")
        XCTAssertEqual(first("Philadelphia"), "frischkäse")
        XCTAssertEqual(first("Senseo"), "kaffeepads")
        XCTAssertEqual(first("Rama"), "margarine")
        XCTAssertEqual(first("Nivea"), "bodylotion")
        XCTAssertEqual(first("Tempo"), "taschentücher")
        XCTAssertEqual(first("Somat"), "spülmaschinentabs")
        XCTAssertEqual(first("Finish"), "spülmaschinentabs")
        // Marken zu Alt-Stichwörtern tragen deren unveränderte Werte.
        XCTAssertEqual(price("Milka"), price("Schokolade"))
        XCTAssertEqual(price("Pril"), price("Spülmittel"))
        XCTAssertEqual(price("Persil"), price("Waschmittel"))
        XCTAssertEqual(price("Ariel"), 8.00)
    }

    func testShortFormsMapToTheirProduct() {
        XCTAssertEqual(price("Hack"), 4.00, "wie Hackfleisch")
        XCTAssertEqual(price("Spüli"), 1.80, "wie Spülmittel")
        XCTAssertEqual(first("Tabs"), "spülmaschinentabs")
        XCTAssertEqual(price("Duschbad"), price("Duschgel"))
        XCTAssertEqual(first("Klopapier"), "toilettenpapier")
        XCTAssertEqual(first("Zewa"), "küchenrolle")
    }

    func testLegacyEntriesStayUntouched() {
        // Marken und Kurzformen stehen in eigenen Einträgen; `legacy` ist die Messbasis „vorher".
        XCTAssertEqual(PriceCatalog.legacy.count, 32)
        let legacyNames = Set(PriceCatalog.legacy.flatMap(\.names))
        for name in ["hack", "spüli", "milka", "persil", "duschbad", "zewa", "tabs"] {
            XCTAssertFalse(legacyNames.contains(name), name)
        }
    }

    // MARK: - Mehrzahl

    func testRegularPluralFindsSingularEntry() {
        XCTAssertEqual(first("Joghurts"), "joghurt")
        XCTAssertEqual(first("Erdbeerjoghurts"), "joghurt", "Mehrzahl eines Kompositums")
        XCTAssertEqual(first("Mozzarellas"), "mozzarella")
        XCTAssertEqual(first("Schnitzeln"), "schnitzel")
        XCTAssertTrue(PriceCatalog.match("Weine")?.names.contains("wein") ?? false)
        XCTAssertTrue(PriceCatalog.match("Biere")?.names.contains("bier") ?? false)
        XCTAssertEqual(price("Brote"), 2.50)
        XCTAssertEqual(PriceCatalog.singularCandidates(of: "bananen"), ["banan", "banane"], "-en und -n")
    }

    func testPluralRuleDoesNotCreateFalseHits() {
        XCTAssertNil(PriceCatalog.match("Reise"), "Reise ist nicht Reis + e")
        XCTAssertNil(PriceCatalog.match("Urlaubsreise"))
        XCTAssertNil(PriceCatalog.match("Reisen"))
        XCTAssertNil(PriceCatalog.match("Eisen"), "Stamm „eis“ ist kürzer als 4 Zeichen")
        XCTAssertNil(PriceCatalog.match("Tees"), "Stamm „tee“ ist kürzer als 4 Zeichen")
        XCTAssertNil(PriceCatalog.match("Hacke"), "Hacke ist kein Hack + e")
        XCTAssertNil(PriceCatalog.match("Strohballen"), "Ballen ist nicht die Mehrzahl von Ball")
        XCTAssertEqual(PriceCatalog.singularCandidates(of: "tees"), [])
        XCTAssertEqual(PriceCatalog.singularCandidates(of: "joghurts"), ["joghurt"])
    }

    // MARK: - Tippfehler

    func testTypoToleranceFindsUniqueCorrection() {
        XCTAssertEqual(first("Banan"), "bananen")
        XCTAssertEqual(first("Tomatn"), "tomaten")
        XCTAssertEqual(first("Jogurt"), "joghurt")
        XCTAssertEqual(first("Hafermlch"), "hafermilch")
        XCTAssertEqual(first("Spagetti"), "spaghetti")
        XCTAssertEqual(first("Mlich"), "milch", "Vertauschung zweier Nachbarn")
        XCTAssertEqual(price("Brotchen"), 2.50, "Ersetzung ab 7 Buchstaben (ö → o)")
    }

    func testTypoToleranceRejectsShortAmbiguousAndRealWords() {
        XCTAssertNil(PriceCatalog.match("Mlch"), "unter 5 Buchstaben keine Korrektur")
        XCTAssertNil(PriceCatalog.match("Kase"), "unter 5 Buchstaben keine Korrektur")
        XCTAssertNil(PriceCatalog.match("Duschel"), "Duschgel oder Duschöl/Duschbad: mehrdeutig")
        XCTAssertNil(PriceCatalog.match("Olivenl"), "Oliven oder Olivenöl: mehrdeutig")
        XCTAssertNil(PriceCatalog.match("Seite"), "Ersetzung in 5 Buchstaben zählt nicht (Seife)")
        XCTAssertNil(PriceCatalog.match("Biene"), "Ersetzung in 5 Buchstaben zählt nicht (Birne)")
        XCTAssertNil(PriceCatalog.match("Schlüssel"), "keine Schüssel")
        // Ein exakter Treffer hat Vorrang, die Tippfehler-Stufe läuft dann gar nicht.
        XCTAssertEqual(first("Banan Milch"), "milch")
        // Weiterhin ohne Katalogpreis: der Pauschalen-Testname aus PriceEstimator*Tests.
        XCTAssertNil(PriceCatalog.match("artikel ohne keyword-treffer"))
        XCTAssertNil(PriceCatalog.match("Unbekanntes Zeug"))
    }

    func testOneEditDistance() {
        func apart(_ a: String, _ b: String, substitution: Bool = true) -> Bool {
            PriceCatalog.isOneEditApart(Array(a), Array(b), allowingSubstitution: substitution)
        }
        XCTAssertTrue(apart("banan", "banane"), "Einfügen")
        XCTAssertTrue(apart("tomatenn", "tomaten"), "Löschen")
        XCTAssertTrue(apart("mlich", "milch"), "Vertauschen")
        XCTAssertTrue(apart("seite", "seife"), "Ersetzen")
        XCTAssertFalse(apart("seite", "seife", substitution: false))
        XCTAssertFalse(apart("milch", "milch"), "gleich ist kein Schritt")
        XCTAssertFalse(apart("mlcih", "milch"), "zwei Schritte")
        XCTAssertFalse(apart("banan", "bananen"), "zwei Schritte")
    }

    // MARK: - Grundwort-Fehltreffer

    func testFahrradschlauchIsNotLauch() throws {
        XCTAssertEqual(first("Fahrradschlauch"), "fahrradschlauch")
        XCTAssertNotEqual(try XCTUnwrap(price("Fahrradschlauch")), 2.49, accuracy: 0.001, "nicht der Lauchpreis")
        XCTAssertEqual(first("Gartenschlauch"), "gartenschlauch")
        // Die Sperr-Endung wirkt auch ohne eigenen Katalogeintrag.
        XCTAssertFalse(PriceCatalog.wordMatches(key: "lauch", word: "fahrradschlauch"))
        XCTAssertFalse(PriceCatalog.wordMatches(key: "lauch", word: "duschschlauch"))
        // Gegenproben: Lauch bleibt Lauch, Knoblauch bleibt Knoblauch, Bärlauch ist ein Lauch.
        XCTAssertEqual(first("Lauch"), "lauch")
        XCTAssertEqual(first("Porree"), "lauch")
        XCTAssertEqual(first("Knoblauch"), "knoblauch")
        XCTAssertTrue(PriceCatalog.wordMatches(key: "lauch", word: "bärlauch"))
    }

    func testBlockedHeadEndingsPreventKnownFalseHits() {
        XCTAssertNil(PriceCatalog.match("Kaufpreis"), "kein Reis")
        XCTAssertNil(PriceCatalog.match("Geburtstagsfeier"), "keine Eier")
        XCTAssertNil(PriceCatalog.match("Panorama"), "keine Rama")
        XCTAssertNil(PriceCatalog.match("Krawatte"), "keine Watte")
        XCTAssertEqual(first("Schwein"), "schweinefleisch", "kein Wein")
        XCTAssertFalse(PriceCatalog.wordMatches(key: "wein", word: "schwein"))
        XCTAssertTrue(PriceCatalog.wordMatches(key: "wein", word: "rotwein"))
    }

    func testExistingCompoundRuleStillWorks() {
        XCTAssertEqual(price("Laugenbrötchen groß"), 2.50, "Grundwort brötchen")
        XCTAssertEqual(first("Tomatenmark"), "tomatenmark", "nicht Tomaten")
        XCTAssertEqual(price("Kartoffelchips"), 1.80)
        XCTAssertEqual(first("Käsekuchen"), "kuchen")
        XCTAssertEqual(first("Hafermilch"), "hafermilch")
        XCTAssertNil(PriceCatalog.match("Reisig"))
        XCTAssertNil(PriceCatalog.match("Brotmesser"))
    }
}
