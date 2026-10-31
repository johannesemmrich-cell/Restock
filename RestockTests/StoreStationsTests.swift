import XCTest
import SwiftData
@testable import Restock

/// Issue #234, Durchgang 1: Laden-Stationen („Gänge“). Spec: `docs/specs/models/store-stations.md`.
///
/// Reine Auflösung (`StoreCategories.station(...)`), Lidl-Vorlage, `Store`-Hülle (Feld
/// `stationConfigJSON`, Gang-Name/-Rang, Merken), Sortierung mit Gang-Rang und Lernen innerhalb
/// eines Gangs. Sortiermodus und Einkaufsweg liegen in der App-Gruppe unter der Laden-ID; jeder
/// angelegte Laden räumt sie in `tearDown` wieder ab (`removeRouteData`).
@MainActor
final class StoreStationsTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var stores: [Store] = []
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private let marker = StoreCategories.otherStationMarker

    /// Die zwölf Gänge der Vorlage in Tabellen-Reihenfolge (Spec, Abschnitt Lidl-Vorlage).
    private let templateNames = [
        "Obst & Gemüse", "Frische Säfte, Salate, gekühlte Getränke", "Nüsse, Süßigkeiten, Kaffee, Tee",
        "Brot & Backwaren", "Konserven & Gewürze", "Frisches Fleisch & Fisch", "Kühltheke Fertiges",
        "Käse", "Milchprodukte", "Tiefkühl", "Drogerie", "Getränke",
    ]
    private let templateEmojis = ["🥦", "🥗", "☕️", "🥖", "🥫", "🥩", "🧊", "🧀", "🥛", "❄️", "🧴", "🥤"]

    override func setUpWithError() throws {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
    }

    override func tearDown() {
        // Sortiermodus, Einkaufsweg und laufender Einkauf liegen in der App-Gruppe (Store.routeDefaults).
        stores.forEach { $0.removeRouteData() }
        stores = []
        container = nil
        context = nil
        super.tearDown()
    }

    // MARK: - Hilfen

    private func makeStore(_ name: String = "UT-Stationsladen", template: Bool = true) -> Store {
        let store = Store(name: name, emoji: "🛒", colorHex: "#0050AA")
        context.insert(store)
        stores.append(store)
        if template { store.applyStationConfig(StoreCategories.lidlTemplate) }
        return store
    }

    /// Artikel wie aus der Liste angelegt: Kategorie automatisch, nicht von Hand gesetzt.
    @discardableResult
    private func add(_ name: String, to store: Store, added: TimeInterval = 0, urgent: Bool = false) -> ShoppingItem {
        let item = ShoppingItem(name: name, category: AssignmentService.category(for: name), store: store)
        item.addedDate = t0.addingTimeInterval(added)
        item.isUrgent = urgent
        context.insert(item)
        return item
    }

    private func item(_ name: String, in store: Store) throws -> ShoppingItem {
        try XCTUnwrap(store.items?.first { $0.name == name }, "„\(name)“ fehlt im Laden")
    }

    private var lidl: StationConfig { StoreCategories.lidlTemplate }

    /// Auflösung mit automatischer Kategorie, ohne Merkung und ohne Handwahl.
    private func resolve(_ name: String, config: StationConfig? = nil) -> String? {
        StoreCategories.station(forItemNamed: name, category: AssignmentService.category(for: name),
                                manuallySet: false, remembered: nil, config: config ?? lidl)
    }

    private func station(_ name: String, builtIns: [String] = [], keywords: [String] = []) -> Station {
        Station(name: name, emoji: "🏷️", builtIns: builtIns, keywords: keywords)
    }

    private func config(_ stations: [Station], hidden: [String] = []) -> StationConfig {
        StationConfig(stations: stations, hidden: hidden, date: t0)
    }

    // MARK: - T1: Laden ohne Gänge verhält sich wie bisher (AC-1)

    /// T1 / AC-1: GIVEN `stationConfigJSON` leer, kaputt („{“) oder mit null Gängen WHEN
    /// `hasStations` und `pendingItems` THEN `false` und dieselbe Reihenfolge wie bisher. Die
    /// Gegenprobe mit Vorlage zeigt, dass die Artikel mit Gängen anders stünden (sonst bewiese der
    /// Vergleich nichts).
    func testStoreWithoutUsableConfigBehavesAsBefore() throws {
        let emptyConfig = try XCTUnwrap(String(data: try JSONEncoder().encode(
            StationConfig(stations: [], hidden: ["Werkzeug"], date: t0)), encoding: .utf8))
        for json in ["", "{", emptyConfig] {
            let store = makeStore("UT-Ohne-\(json.count)", template: false)
            store.stationConfigJSON = json
            add("Smoothie", to: store, added: 0)
            add("Milch", to: store, added: 10)
            add("Gouda", to: store, added: 20)
            add("Apfel", to: store, added: 30)
            XCTAssertFalse(store.hasStations, "„\(json)“ darf nicht als Laden mit Gängen gelten")

            store.sortMode = .route
            XCTAssertEqual(store.pendingItems.map(\.name), ["Apfel", "Milch", "Gouda", "Smoothie"],
                           "„\(json)“: Einkaufsweg ohne Lernen folgt der festen Kategorie-Reihenfolge")
            store.sortMode = .category
            XCTAssertEqual(store.pendingItems.map(\.name), ["Apfel", "Milch", "Gouda", "Smoothie"],
                           "„\(json)“: Modus Kategorie unverändert")
            store.sortMode = .added
            XCTAssertEqual(store.pendingItems.map(\.name), ["Smoothie", "Milch", "Gouda", "Apfel"],
                           "„\(json)“: Modus Hinzugefügt unverändert")
        }

        // Gegenprobe: dieselben Artikel im Laden mit Vorlage.
        let withStations = makeStore("UT-Mit-Vorlage")
        add("Smoothie", to: withStations, added: 0)
        add("Milch", to: withStations, added: 10)
        add("Gouda", to: withStations, added: 20)
        add("Apfel", to: withStations, added: 30)
        XCTAssertTrue(withStations.hasStations)
        withStations.sortMode = .route
        XCTAssertEqual(withStations.pendingItems.map(\.name), ["Apfel", "Smoothie", "Gouda", "Milch"])
    }

    // MARK: - T2/T3: Zuordnung mit der Vorlage (AC-3, AC-4, AC-5)

    /// T2 / AC-3, AC-4: GIVEN Vorlage angewendet WHEN `stationName(of:)` für typische Artikel
    /// THEN Kühltheke Fertiges, Käse, Obst & Gemüse, Milchprodukte, Sonstiges (`nil`).
    func testStationNameForTypicalItems() throws {
        let store = makeStore()
        for name in ["Salami", "Gouda", "Apfel", "Milch", "Batterien"] { add(name, to: store) }
        XCTAssertEqual(store.stationName(of: try item("Salami", in: store)), "Kühltheke Fertiges")
        XCTAssertEqual(store.stationName(of: try item("Gouda", in: store)), "Käse")
        XCTAssertEqual(store.stationName(of: try item("Apfel", in: store)), "Obst & Gemüse")
        XCTAssertEqual(store.stationName(of: try item("Milch", in: store)), "Milchprodukte")
        XCTAssertNil(store.stationName(of: try item("Batterien", in: store)), "Elektronik ist offen → Sonstiges")
    }

    /// T3 / AC-4, AC-5 (`testTemplateRoutesTypicalItems` der Spec): Grenzfälle der Vorlage.
    func testTemplateRoutesTypicalItems() {
        XCTAssertEqual(resolve("Salatgurke"), "Obst & Gemüse", "„salat“ ist kein Stichwort, Gurke bleibt beim Gemüse")
        XCTAssertEqual(resolve("Bratwurst"), "Frisches Fleisch & Fisch", "„bratwurst“ (9) schlägt „wurst“ (5)")
        XCTAssertEqual(resolve("Leberkäse"), "Kühltheke Fertiges", "„leberkäse“ (9) schlägt „käse“ (4)")
        XCTAssertEqual(resolve("Hustensaft"), "Drogerie", "„hustensaft“ schlägt „saft“")
        XCTAssertEqual(resolve("Teewurst"), "Kühltheke Fertiges", "endet auf „wurst“, nicht auf „tee“")
        XCTAssertEqual(resolve("Eistee"), "Frische Säfte, Salate, gekühlte Getränke", "„eistee“ (6) schlägt „tee“ (3)")
        XCTAssertNil(resolve("Hammer"), "Werkzeug ist ausgeblendet → Sonstiges")
        XCTAssertNil(resolve("Qwertz"), "Unerkannt → „Lebensmittel“ → Sonstiges")
        XCTAssertEqual(AssignmentService.category(for: "Qwertz"), "Lebensmittel", "Vorbedingung des Rückfalls")
    }

    // MARK: - T4/T5: Stichwort-Regel (AC-4)

    /// T4 / AC-4: GIVEN Stichwort „salat“ WHEN „Geflügelsalat“ und „Salatgurke“ THEN der Erste
    /// trifft (Wort endet darauf), der Zweite nicht und fällt auf seine feste Kategorie zurück.
    func testKeywordMatchesWordEndingOnly() {
        let cfg = config([
            station("Gemüse", builtIns: ["Obst & Gemüse"]),
            station("Salate", keywords: ["salat"]),
        ])
        XCTAssertEqual(resolve("Geflügelsalat", config: cfg), "Salate")
        XCTAssertEqual(resolve("Salatgurke", config: cfg), "Gemüse", "Kein Treffer am Wortanfang")
        XCTAssertEqual(resolve("Bio Salat", config: cfg), "Salate", "Jedes Wort des Namens zählt einzeln")
    }

    /// T5 / AC-4: GIVEN zwei treffende Stichwörter WHEN Auflösung THEN das längere gewinnt, bei
    /// gleicher Länge der frühere Gang (Reihenfolge in der Konfiguration, nicht im Namen).
    func testLongestKeywordWinsTieGoesToEarlierStation() {
        let wurstFirst = config([station("Kühltheke", keywords: ["wurst"]), station("Metzger", keywords: ["bratwurst"])])
        XCTAssertEqual(resolve("Bratwurst", config: wurstFirst), "Metzger", "Das längere Stichwort gewinnt, auch aus späterem Gang")

        let cheeseFirst = config([station("Käseecke", keywords: ["gouda"]), station("Salatbar", keywords: ["salat"])])
        XCTAssertEqual(resolve("Salat Gouda", config: cheeseFirst), "Käseecke", "Gleichstand (5/5): früherer Gang")
        let saladFirst = config([station("Salatbar", keywords: ["salat"]), station("Käseecke", keywords: ["gouda"])])
        XCTAssertEqual(resolve("Salat Gouda", config: saladFirst), "Salatbar", "Gleichstand (5/5): früherer Gang")
    }

    // MARK: - T6/T7: Reihenfolge der Stufen, ausgeblendete Kategorien (AC-5, AC-6)

    /// T6 / AC-6: Merkung > von Hand gesetzte Kategorie > Stichwort > automatische Kategorie > Sonstiges.
    func testResolutionPriority() {
        let cfg = config([
            station("Kühltheke", keywords: ["salami"]),
            station("Käse"),
            station("Wurstwaren", builtIns: ["Fleisch & Wurst"]),
            station("Milch", builtIns: ["Milchprodukte"]),
        ])
        func res(_ name: String, _ category: String, manual: Bool, remembered: String?) -> String? {
            StoreCategories.station(forItemNamed: name, category: category, manuallySet: manual,
                                    remembered: remembered, config: cfg)
        }
        // Stufe 1: Merkung schlägt Handwahl und Stichwort.
        XCTAssertEqual(res("Salami", "Milchprodukte", manual: true, remembered: "Käse"), "Käse")
        XCTAssertEqual(res("Salami", "Milchprodukte", manual: true, remembered: " käse "), "Käse", "Vergleich über compareKey")
        // Stufe 1: Marke hält den Artikel in Sonstiges, gegen Handwahl und Stichwort.
        XCTAssertNil(res("Salami", "Milchprodukte", manual: true, remembered: marker))
        // Veraltete Merkung → weiter zu Stufe 2 (Handwahl feste Kategorie im Gang) vor Stichwort.
        XCTAssertEqual(res("Salami", "Milchprodukte", manual: true, remembered: "Gelöschter Gang"), "Milch")
        // Stufe 2: Handwahl eines Gang-Namens.
        XCTAssertEqual(res("Salami", "Käse", manual: true, remembered: nil), "Käse")
        // Stufe 2 übergeht eine eigene Kategorie, die kein Gang ist → Stichwort.
        XCTAssertEqual(res("Salami", "Meine Ecke", manual: true, remembered: nil), "Kühltheke")
        // Stufe 3 vor Stufe 4: Salami ist automatisch „Fleisch & Wurst“ (Gang Wurstwaren), das Stichwort gewinnt.
        XCTAssertEqual(AssignmentService.category(for: "Salami"), "Fleisch & Wurst", "Vorbedingung")
        XCTAssertEqual(res("Salami", "Fleisch & Wurst", manual: false, remembered: nil), "Kühltheke")
        // Stufe 4: ohne Stichwort die automatische Kategorie aus dem Namen; eine nicht von Hand
        // gesetzte gespeicherte Kategorie zählt nicht.
        XCTAssertEqual(res("Bratwurst", "Milchprodukte", manual: false, remembered: nil), "Wurstwaren")
        // Stufe 5: nichts trifft.
        XCTAssertNil(res("Qwertz", "Lebensmittel", manual: false, remembered: nil))
    }

    /// T7 / AC-5: GIVEN ausgeblendete feste Kategorie, die zugleich in `builtIns` steht WHEN Artikel
    /// dieser Kategorie THEN Sonstiges — automatisch und von Hand gesetzt; Stichwort und Merkung
    /// wirken weiter.
    func testHiddenBuiltInNeverMapsToStation() {
        let cfg = config([station("Werkstatt", builtIns: ["Werkzeug"], keywords: ["schraube"])], hidden: ["Werkzeug"])
        XCTAssertEqual(AssignmentService.category(for: "Hammer"), "Werkzeug", "Vorbedingung")
        XCTAssertNil(resolve("Hammer", config: cfg), "Automatisch: ausgeblendet → Sonstiges")
        XCTAssertNil(StoreCategories.station(forItemNamed: "Hammer", category: "Werkzeug", manuallySet: true,
                                             remembered: nil, config: cfg), "Von Hand: ausgeblendet → Sonstiges")
        XCTAssertEqual(resolve("Schraube", config: cfg), "Werkstatt", "Stichwort wirkt weiter")
        XCTAssertEqual(StoreCategories.station(forItemNamed: "Hammer", category: "Werkzeug", manuallySet: false,
                                               remembered: "Werkstatt", config: cfg), "Werkstatt", "Merkung wirkt weiter")
    }

    // MARK: - T8: Vorlage (AC-3)

    /// T8 / AC-3: GIVEN Lidl-Vorlage WHEN geprüft THEN 12 Gänge in Tabellen-Reihenfolge, eindeutige
    /// Namen, gültige feste Kategorien, keine doppelt, `hidden` ohne Überschneidung, Stichwörter
    /// 3…15 je Gang; „Lebensmittel“ (Rückfall für Unerkanntes) in keinem Gang.
    func testTemplateIsConsistent() {
        let stations = lidl.stations
        XCTAssertEqual(stations.map(\.name), templateNames)
        XCTAssertEqual(stations.map(\.emoji), templateEmojis)
        XCTAssertEqual(Set(stations.map { StoreCategories.compareKey($0.name) }).count, 12, "Namen eindeutig")

        let builtIns = stations.flatMap(\.builtIns)
        let known = Set(AssignmentService.categoryOrder)
        XCTAssertEqual(builtIns.filter { !known.contains($0) }, [], "Unbekannte feste Kategorie")
        XCTAssertEqual(builtIns.count, Set(builtIns).count, "Feste Kategorie in zwei Gängen")
        XCTAssertFalse(builtIns.contains("Lebensmittel"), "Lebensmittel gehört in keinen Gang (Sonstiges)")
        XCTAssertEqual(lidl.hidden.filter { !known.contains($0) }, [], "Unbekannte ausgeblendete Kategorie")
        XCTAssertEqual(Set(lidl.hidden), ["Werkzeug", "Eisenwaren", "Garten", "Pflanzen", "Farbe & Lack",
                                          "Sanitär", "Boden & Fliesen", "Holz", "Baumaterial"])
        XCTAssertTrue(Set(lidl.hidden).isDisjoint(with: builtIns), "hidden überschneidet builtIns")
        for station in stations {
            XCTAssertLessThanOrEqual(station.keywords.count, 15, "\(station.name): zu viele Stichwörter")
            for keyword in station.keywords {
                XCTAssertGreaterThanOrEqual(keyword.count, 3, "\(station.name): Stichwort „\(keyword)“ zu kurz")
                XCTAssertFalse(keyword.contains(" "), "\(station.name): „\(keyword)“ ist kein einzelnes Wort")
            }
        }
        XCTAssertEqual(stations[10].builtIns.sorted(), ["Babybedarf", "Haarpflege", "Hygieneartikel", "Körperpflege",
                                                        "Kosmetik", "Medikamente", "Reinigung", "Zahnpflege"].sorted())
        XCTAssertEqual(stations[4].builtIns.sorted(), ["Gewürze & Backen", "Konserven"])
    }

    // MARK: - T9/T10: Sortierung mit Gang-Rang (AC-2, AC-7, AC-8, AC-9)

    /// T9 / AC-7, AC-8 (reine Logik): Mit Rang gilt Dringend > Rang > gelernte Position (bekannte vor
    /// unbekannten) > Hinzufügedatum, in den Modi Einkaufsweg und Kategorie; Hinzugefügt unverändert.
    func testSortedIndicesWithStationRank() {
        var model = ShoppingRouteModel()
        model.itemPositions = ["batterien": 0.0, "apfel": 1.0, "gouda": 0.2, "feta": 0.9]
        func entry(_ key: String, _ rank: Int, added: TimeInterval, urgent: Bool = false) -> ShoppingRoute.SortInput {
            .init(key: key, category: "egal", isUrgent: urgent, addedDate: t0.addingTimeInterval(added), stationRank: rank)
        }
        let items = [
            entry("batterien", 12, added: 0), entry("emmentaler", 7, added: 1), entry("feta", 7, added: 5),
            entry("milch", 8, added: 10), entry("gouda", 7, added: 20), entry("salami", 6, added: 30),
            entry("apfel", 0, added: 40), entry("brot", 3, added: 50, urgent: true),
        ]
        let expected = ["brot", "apfel", "salami", "gouda", "feta", "emmentaler", "milch", "batterien"]
        for mode in [StoreSortMode.route, .category] {
            let order = ShoppingRoute.sortedIndices(items, mode: mode, model: model,
                                                    staticCategoryOrder: AssignmentService.categoryOrder).map { items[$0].key }
            XCTAssertEqual(order, expected, "Modus \(mode): Rang vor Position, Position vor Datum")
        }
        let added = ShoppingRoute.sortedIndices(items, mode: .added, model: model,
                                                staticCategoryOrder: AssignmentService.categoryOrder).map { items[$0].key }
        XCTAssertEqual(added, ["brot", "batterien", "emmentaler", "feta", "milch", "gouda", "salami", "apfel"])
    }

    /// T9 / AC-2, AC-7, AC-8 (über den Laden): `pendingItems` setzt den Rang selbst. Batterien hat die
    /// früheste gelernte Position und steht trotzdem als Sonstiges am Ende.
    func testPendingItemsFollowStationOrder() {
        let store = makeStore()
        add("Batterien", to: store, added: 0)
        add("Emmentaler", to: store, added: 1)
        add("Feta", to: store, added: 5)
        add("Milch", to: store, added: 10)
        add("Gouda", to: store, added: 20)
        add("Salami", to: store, added: 30)
        add("Apfel", to: store, added: 40)
        add("Brot", to: store, added: 50, urgent: true)
        var model = ShoppingRouteModel()
        model.itemPositions = ["batterien": 0.0, "apfel": 1.0, "gouda": 0.2, "feta": 0.9]
        store.routeModel = model

        let expected = ["Brot", "Apfel", "Salami", "Gouda", "Feta", "Emmentaler", "Milch", "Batterien"]
        store.sortMode = .route
        XCTAssertEqual(store.pendingItems.map(\.name), expected)
        store.sortMode = .category
        XCTAssertEqual(store.pendingItems.map(\.name), expected)
        store.sortMode = .added
        XCTAssertEqual(store.pendingItems.map(\.name),
                       ["Brot", "Batterien", "Emmentaler", "Feta", "Milch", "Gouda", "Salami", "Apfel"])
    }

    /// T9 / AC-3: Rang = Index des Gangs, Sonstiges = Anzahl der Gänge.
    func testStationRank() throws {
        let store = makeStore()
        for name in ["Apfel", "Salami", "Milch", "Batterien"] { add(name, to: store) }
        XCTAssertEqual(store.stationRank(of: try item("Apfel", in: store)), 0)
        XCTAssertEqual(store.stationRank(of: try item("Salami", in: store)), 6)
        XCTAssertEqual(store.stationRank(of: try item("Milch", in: store)), 8)
        XCTAssertEqual(store.stationRank(of: try item("Batterien", in: store)), 12)
    }

    /// T10 / AC-9: GIVEN ein Einkauf Milch (Gang 9), Feta (Käse), Apfel (Gang 1), Gouda (Käse),
    /// abgeschlossen WHEN `pendingItems` THEN Apfel bleibt vor Milch (späterer Gang rückt nicht vor),
    /// innerhalb des Käse-Gangs gilt die gelernte Reihenfolge Feta vor Gouda.
    func testCheckOffLearnsOnlyWithinStation() throws {
        let store = makeStore()
        add("Gouda", to: store, added: 0)
        add("Apfel", to: store, added: 10)
        add("Feta", to: store, added: 20)
        add("Milch", to: store, added: 30)
        store.sortMode = .route
        XCTAssertEqual(store.pendingItems.map(\.name), ["Apfel", "Gouda", "Feta", "Milch"], "Vorher: Gang, dann Datum")

        for (index, name) in ["Milch", "Feta", "Apfel", "Gouda"].enumerated() {
            store.recordCheckOff(try item(name, in: store), at: t0.addingTimeInterval(Double(index) * 30))
        }
        store.finalizeStaleTrip(now: t0.addingTimeInterval(90 + 31 * 60))
        XCTAssertNotNil(store.routeModel.itemPositions["milch"], "Der Einkauf muss gelernt sein")
        XCTAssertLessThan(store.routeModel.itemPositions["milch"]!, store.routeModel.itemPositions["apfel"]!,
                          "Vorbedingung: Milch wurde vor Apfel abgehakt")

        XCTAssertEqual(store.pendingItems.map(\.name), ["Apfel", "Feta", "Gouda", "Milch"])
    }

    // MARK: - T11: Aufgezeichnete Kategorie (AC-9)

    /// T11 / AC-9: GIVEN `recordCheckOff` WHEN Artikel aus Gang und aus Sonstiges THEN der laufende
    /// Einkauf trägt den Gang-Namen bzw. die Sonstiges-Marke als Kategorie.
    func testRecordCheckOffStoresStationName() throws {
        let store = makeStore()
        add("Salami", to: store)
        add("Batterien", to: store)
        store.recordCheckOff(try item("Salami", in: store), at: t0)
        store.recordCheckOff(try item("Batterien", in: store), at: t0.addingTimeInterval(30))
        XCTAssertEqual(store.currentTrip.entries.map(\.category), ["Kühltheke Fertiges", marker])

        // Gegenprobe: Laden ohne Gänge zeichnet weiter die feste Kategorie auf.
        let plain = makeStore("UT-Ohne-Gänge", template: false)
        add("Salami", to: plain)
        plain.recordCheckOff(try item("Salami", in: plain), at: t0)
        XCTAssertEqual(plain.currentTrip.entries.map(\.category), ["Fleisch & Wurst"])
    }

    // MARK: - T12: Vorlage übernehmen und Gänge entfernen (AC-14)

    /// T12 / AC-14: GIVEN `applyStationConfig(lidlTemplate)` THEN Gang-Namen ohne feste Kategorie
    /// sind eigene Kategorien (vorhandene bleiben unverändert), Artikel bleiben unberührt;
    /// `removeStations` leert das Feld und behält eigene Kategorien und Merkungen.
    func testApplyAndRemoveStations() throws {
        let store = makeStore(template: false)
        store.addCustomCategory("Käse", emoji: "🐭")
        let salami = add("Salami", to: store)
        let before = (salami.category, salami.categoryManuallySet)

        store.applyStationConfig(lidl)

        XCTAssertTrue(store.hasStations)
        XCTAssertEqual(store.stationConfig?.stations.map(\.name), templateNames)
        let custom = Set(store.customCategories)
        for name in templateNames where !["Obst & Gemüse", "Getränke", "Milchprodukte"].contains(name) {
            XCTAssertTrue(custom.contains(name), "„\(name)“ fehlt als eigene Kategorie")
        }
        for name in ["Obst & Gemüse", "Getränke", "Milchprodukte"] {
            XCTAssertFalse(store.isCustomCategory(name), "„\(name)“ ist eine feste Kategorie und wird nicht angelegt")
        }
        XCTAssertEqual(store.categoryEmoji("Käse"), "🐭", "Vorhandene eigene Kategorie bleibt unverändert")
        XCTAssertEqual(store.categoryEmoji("Kühltheke Fertiges"), "🧊", "Emoji kommt aus dem Gang")
        XCTAssertEqual(salami.category, before.0, "Übernehmen ändert keine Artikel")
        XCTAssertEqual(salami.categoryManuallySet, before.1)

        store.rememberCategory("Käse", forItemNamed: "Gouda")
        store.rememberCategory(marker, forItemNamed: "Batterien")
        store.removeStations()

        XCTAssertEqual(store.stationConfigJSON, "")
        XCTAssertFalse(store.hasStations)
        XCTAssertTrue(store.customCategories.contains("Kühltheke Fertiges"), "Eigene Kategorien bleiben")
        XCTAssertEqual(store.categoryAssignments["gouda"], "Käse", "Merkungen bleiben")
        XCTAssertEqual(store.rememberedCategory(forItemNamed: "Gouda"), "Käse")
        XCTAssertNil(store.rememberedCategory(forItemNamed: "Batterien"), "Die Marke wird nie als Kategorie geliefert")
        XCTAssertEqual(store.stationName(of: salami), nil, "Ohne Gänge gibt es keinen Gang-Namen")
    }

    // MARK: - T13: Merken (AC-12, AC-13)

    /// T13 / AC-12, AC-13: GIVEN Laden mit Gängen WHEN Gang, Gang mit Namen einer festen Kategorie,
    /// Marke, feste Kategorie ohne Gang gemerkt THEN Gänge werden gemerkt und geliefert, die Marke
    /// wird gemerkt aber nie geliefert, eine andere feste Kategorie vergisst.
    func testRememberStationsAndMarker() throws {
        let store = makeStore()

        store.rememberCategory("Käse", forItemNamed: "Gouda")
        XCTAssertEqual(store.rememberedCategory(forItemNamed: "Gouda"), "Käse")

        store.rememberCategory("Getränke", forItemNamed: "Salami")
        XCTAssertEqual(store.categoryAssignments["salami"], "Getränke", "Gang mit Namen einer festen Kategorie wird gemerkt")
        XCTAssertEqual(store.rememberedCategory(forItemNamed: "Salami"), "Getränke")
        let salami = add("Salami", to: store)
        XCTAssertEqual(salami.category, "Getränke", "Neuer Artikel landet im gemerkten Gang (ShoppingItem.init)")
        XCTAssertTrue(salami.categoryManuallySet)
        XCTAssertEqual(store.stationName(of: salami), "Getränke", "Merkung schlägt das Stichwort „salami“")

        store.rememberCategory(marker, forItemNamed: "Gouda")
        XCTAssertEqual(store.categoryAssignments["gouda"], marker, "Die Marke wird gemerkt")
        XCTAssertNil(store.rememberedCategory(forItemNamed: "Gouda"), "… aber nie als Kategorie geliefert")
        let gouda = add("Gouda", to: store)
        XCTAssertEqual(gouda.category, AssignmentService.category(for: "Gouda"), "Die Marke steht nie in item.category")
        XCTAssertFalse(gouda.categoryManuallySet)
        XCTAssertNil(store.stationName(of: gouda), "Die Marke hält Gouda trotz Stichwort in Sonstiges")

        store.rememberCategory("Werkzeug", forItemNamed: "Gouda")
        XCTAssertNil(store.categoryAssignments["gouda"], "Feste Kategorie ohne Gang vergisst die Merkung")
        XCTAssertEqual(store.stationName(of: gouda), "Käse", "Ohne Merkung wieder das Stichwort")
    }

    // MARK: - T14: Gang anlegen aus der Auswahl (AC-11)

    /// T14 / AC-11: GIVEN Laden mit Vorlage WHEN aus der Auswahl angelegt THEN neuer Gang am Ende vor
    /// Sonstiges und gewählt; „Sonstiges“/„Other“ und die Marke werden kein Gang; ein vorhandener
    /// Gang wird gewählt statt verdoppelt; ein Rohname einer festen Kategorie wird ebenfalls ein Gang.
    func testAddStationFromPicker() throws {
        let store = makeStore()
        XCTAssertEqual(StoreCategories.resolveStation("  sonstiges ", config: lidl), .other)
        XCTAssertEqual(StoreCategories.resolveStation("Other", config: lidl), .other)
        XCTAssertEqual(StoreCategories.resolveStation(marker, config: lidl), .invalid, "Die Marke ist kein Name")
        XCTAssertEqual(StoreCategories.resolveStation("   ", config: lidl), .invalid)
        XCTAssertEqual(StoreCategories.resolveStation("käse", config: lidl), .existing("Käse"))
        XCTAssertEqual(StoreCategories.resolveStation(" Back  station ", config: lidl), .new("Back station"))

        XCTAssertEqual(store.addStation("Sonstiges"), marker, "„Sonstiges“ wählt Sonstiges")
        XCTAssertEqual(store.addStation("Other"), marker)
        XCTAssertEqual(store.addStation(" käse "), "Käse", "Vorhandener Gang wird gewählt")
        XCTAssertNil(store.addStation("  "))
        XCTAssertEqual(store.stationConfig?.stations.count, 12, "Nichts davon legt einen Gang an")

        XCTAssertEqual(store.addStation("Backstation"), "Backstation")
        XCTAssertEqual(store.stationConfig?.stations.map(\.name), templateNames + ["Backstation"], "Am Ende, vor Sonstiges")
        let created = try XCTUnwrap(store.stationConfig?.stations.last)
        XCTAssertEqual(created.emoji, StoreCategories.suggestedEmoji(for: "Backstation"))
        XCTAssertEqual(created.builtIns, [])
        XCTAssertEqual(created.keywords, [])
        XCTAssertTrue(store.isCustomCategory("Backstation"), "Neuer Gang ist auch eigene Kategorie (#85-Mechanik)")

        let batterien = add("Batterien", to: store)
        XCTAssertEqual(store.stationRank(of: batterien), 13, "Sonstiges rückt hinter den neuen Gang")

        XCTAssertEqual(store.addStation("Werkzeug"), "Werkzeug", "Rohname einer festen Kategorie wird Gang")
        XCTAssertEqual(store.stationConfig?.stations.last?.name, "Werkzeug")
        XCTAssertFalse(store.isCustomCategory("Werkzeug"), "Feste Kategorie wird nicht als eigene angelegt")
    }

    // MARK: - T15: JSON (AC-1)

    /// T15 / AC-1: GIVEN Konfiguration WHEN JSON-Hin- und Rückweg THEN gleich; nicht dekodierbarer
    /// Text → `stationConfig == nil`.
    func testConfigJSONRoundTrip() throws {
        let original = StationConfig(
            stations: [Station(name: "Käse", emoji: "🧀", builtIns: [], keywords: ["gouda", "feta"]),
                       Station(name: "Getränke", emoji: "🥤", builtIns: ["Getränke"], keywords: [])],
            hidden: ["Werkzeug"], date: t0)
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(StationConfig.self, from: data), original)

        let store = makeStore(template: false)
        store.stationConfig = original
        XCTAssertFalse(store.stationConfigJSON.isEmpty)
        XCTAssertEqual(store.stationConfig, original)
        XCTAssertTrue(store.hasStations)

        store.stationConfigJSON = "{"
        XCTAssertNil(store.stationConfig)
        XCTAssertFalse(store.hasStations)
    }

    // MARK: - T18: Texte (AC-17)

    /// T18 / AC-17: Die neuen `station.*`-Schlüssel stehen in beiden kompilierten Tabellen mit der
    /// erwarteten Platzhalterzahl (Gleichheit aller Schlüssel prüft `LocalizationKeyParityTests`).
    func testStationStringsExistInBothLanguages() throws {
        let expected: [String: Int] = [
            "station.other": 0, "station.picker.section": 1, "station.picker.create": 2,
            "station.menu.applyTemplate": 0, "station.menu.remove": 0,
            "station.template.confirm.title": 0, "station.template.confirm.message": 0,
            "station.remove.confirm.title": 0, "station.remove.confirm.message": 0,
        ]
        for localization in ["de", "en"] {
            let url = try XCTUnwrap(Bundle.main.url(forResource: "Localizable", withExtension: "strings",
                                                    subdirectory: nil, localization: localization))
            let table = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])
            for (key, count) in expected {
                let value = try XCTUnwrap(table[key], "\(localization): Schlüssel \(key) fehlt")
                XCTAssertEqual(LocalizationKeyParityTests.placeholders(in: value).count, count,
                               "\(localization): \(key) hat falsche Platzhalterzahl")
            }
            if localization == "de" {
                XCTAssertEqual(table["station.other"], "Sonstiges", "Die UI-Tests prüfen diesen Text")
                XCTAssertEqual(table["station.menu.remove"], "Gänge entfernen")
            } else {
                XCTAssertEqual(table["station.other"], "Other")
            }
        }
    }

    // MARK: - T19: Preis und feste Kategorie bleiben (AC-17)

    /// T19 / AC-17: GIVEN Laden mit Vorlage WHEN Salami (Stichwort-Gang) und Batterien (Sonstiges)
    /// angelegt THEN `item.category` bleibt die automatische Kategorie, nicht von Hand gesetzt, und
    /// Preisschätzung/feste Gruppierung sind dieselben wie im gleichen Laden ohne Gänge.
    func testStationsDoNotChangeCategoryOrPrice() throws {
        let withStations = makeStore("UT-Preisladen")
        let plain = makeStore("UT-Preisladen", template: false)
        for name in ["Salami", "Batterien"] {
            let a = add(name, to: withStations)
            let b = add(name, to: plain)
            XCTAssertEqual(a.category, AssignmentService.category(for: name), "\(name): Kategorie bleibt automatisch")
            XCTAssertFalse(a.categoryManuallySet, "\(name): nicht von Hand gesetzt")
            XCTAssertEqual(Store.displayCategory(of: a), Store.displayCategory(of: b), "\(name): ladenübergreifende Gruppe gleich")
            XCTAssertEqual(a.estimatedPrice, b.estimatedPrice, "\(name): Preisschätzung gleich")
            XCTAssertEqual(a.priceSource, b.priceSource, "\(name): Preisquelle gleich")
            XCTAssertEqual(PriceEstimator.resolve(for: a.name, category: a.category, unit: a.unit, quantityAmount: a.quantityAmount),
                           PriceEstimator.resolve(for: b.name, category: b.category, unit: b.unit, quantityAmount: b.quantityAmount))
        }
        XCTAssertEqual(withStations.stationName(of: try item("Salami", in: withStations)), "Kühltheke Fertiges")
        XCTAssertEqual(AssignmentService.category(for: "Salami"), "Fleisch & Wurst")
        XCTAssertNil(withStations.stationName(of: try item("Batterien", in: withStations)))
    }
}
