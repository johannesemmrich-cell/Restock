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
            // D2a: „station.menu.applyTemplate“ und „station.template.confirm.*“ sind gestrichen (S13).
            "station.menu.remove": 0,
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

    // MARK: - Durchgang 2a: Kategorien einrichten (Spec `docs/specs/views/station-setup.md`)

    /// Alle Invarianten einer Konfiguration (S9, AC-12).
    private func assertInvariants(_ config: StationConfig, _ step: String,
                                  file: StaticString = #filePath, line: UInt = #line) {
        let keys = config.stations.map { StoreCategories.compareKey($0.name) }
        XCTAssertEqual(Set(keys).count, keys.count, "\(step): Gang-Namen nicht eindeutig", file: file, line: line)
        for name in config.stations.map(\.name) {
            XCTAssertFalse(["sonstiges", "other"].contains(StoreCategories.compareKey(name).lowercased()),
                           "\(step): „\(name)“ meint Sonstiges", file: file, line: line)
            XCTAssertFalse(name.contains("\u{E000}"), "\(step): Marke als Gang-Name", file: file, line: line)
        }
        let order = Set(AssignmentService.categoryOrder)
        let allBuiltIns = config.stations.flatMap(\.builtIns)
        for category in allBuiltIns + config.hidden {
            XCTAssertTrue(order.contains(category), "\(step): „\(category)“ ist keine feste Kategorie", file: file, line: line)
        }
        XCTAssertEqual(Set(allBuiltIns).count, allBuiltIns.count, "\(step): Kategorie in zwei Gängen", file: file, line: line)
        XCTAssertTrue(Set(allBuiltIns).isDisjoint(with: config.hidden), "\(step): hidden ∩ builtIns", file: file, line: line)
        for station in config.stations {
            guard let bound = AssignmentService.categoryOrder.first(where: {
                StoreCategories.compareKey($0) == StoreCategories.compareKey(station.name) }) else { continue }
            XCTAssertTrue(station.builtIns.contains(bound), "\(step): „\(bound)“ fehlt im gleichnamigen Gang", file: file, line: line)
        }
    }

    private func names(_ config: StationConfig?) -> [String] { config?.stations.map(\.name) ?? [] }

    private func builtIns(of name: String, in config: StationConfig?) -> [String] {
        config?.stations.first { $0.name == name }?.builtIns ?? []
    }

    /// Artikel mit von Hand gesetzter Kategorie (wie aus Bearbeiten gespeichert).
    @discardableResult
    private func addManual(_ name: String, category: String, to store: Store) -> ShoppingItem {
        let item = add(name, to: store)
        item.category = category
        item.categoryManuallySet = true
        return item
    }

    // MARK: S1: Umbenennen zieht alles mit (AC-3, AC-4)

    /// S1 / AC-3, AC-4: GIVEN Vorlage, Merkung gouda → Käse, Brie von Hand in Käse, gelernter Weg mit
    /// Käse WHEN `renameStation("Käse", to: "Käse & Co")` THEN Gang an gleicher Stelle umbenannt,
    /// Merkung, `item.category`, `itemCategories` und eigene Kategorie tragen den neuen Namen.
    func testRenameStationMovesAssignmentsPathAndItems() throws {
        let store = makeStore()
        store.rememberCategory("Käse", forItemNamed: "Gouda")
        let brie = addManual("Brie", category: "Käse", to: store)
        let gouda = add("Gouda", to: store)
        let apfel = add("Apfel", to: store)
        var model = store.routeModel
        model.itemPositions["gouda"] = 0.6
        model.itemCategories["gouda"] = "Käse"
        model.itemCategories["apfel"] = "Obst & Gemüse"
        store.routeModel = model
        let rankBefore = store.stationRank(of: brie)
        store.sortMode = .route
        let orderBefore = store.pendingItems.map(\.name)

        let renamed = store.renameStation("Käse", to: "Käse & Co", emoji: "🧀")

        XCTAssertEqual(renamed, "Käse & Co")
        XCTAssertEqual(names(store.stationConfig).firstIndex(of: "Käse & Co"), 7, "Gang bleibt an seiner Stelle")
        XCTAssertFalse(names(store.stationConfig).contains("Käse"))
        XCTAssertEqual(store.categoryAssignments["gouda"], "Käse & Co", "Merkung zieht mit")
        XCTAssertNotNil(store.categoryAssignmentDates["gouda"], "Merkung mit Datum (Abgleich)")
        XCTAssertEqual(brie.category, "Käse & Co", "Von Hand gesetzte Kategorie zieht mit")
        XCTAssertTrue(brie.categoryManuallySet)
        XCTAssertEqual(apfel.category, "Obst & Gemüse", "Automatische Kategorien bleiben unberührt")
        XCTAssertEqual(store.routeModel.itemCategories["gouda"], "Käse & Co", "Gelernter Weg zieht mit")
        XCTAssertEqual(store.routeModel.itemPositions["gouda"], 0.6, "Gelernte Position bleibt")
        XCTAssertEqual(store.customCategoryEntries["Käse"]?.isDeleted, true, "Alte eigene Kategorie mit Löschvermerk")
        XCTAssertEqual(store.customCategoryEntries["Käse & Co"]?.emoji, "🧀", "Neue eigene Kategorie lebt, Emoji aus dem Gang")
        XCTAssertEqual(store.stationName(of: gouda), "Käse & Co")
        XCTAssertEqual(store.stationName(of: brie), "Käse & Co")
        XCTAssertEqual(store.stationRank(of: brie), rankBefore, "Rang unverändert, nichts rutscht nach Sonstiges")
        XCTAssertEqual(store.pendingItems.map(\.name), orderBefore)
    }

    // MARK: S2: Kollisionen werden abgelehnt (AC-5)

    /// S2 / AC-5: GIVEN Vorlage WHEN Umbenennen von „Käse“ auf einen anderen Gang, Sonstiges/Other,
    /// die Marke oder leer THEN `nil`, nichts geändert; nur Schreibweise und neuer Name sind erlaubt.
    func testRenameRejectsCollisions() throws {
        let store = makeStore()
        store.rememberCategory("Käse", forItemNamed: "Gouda")
        var model = store.routeModel
        model.itemCategories["gouda"] = "Käse"
        store.routeModel = model
        let jsonBefore = store.stationConfigJSON
        let modelBefore = store.routeModel

        for input in ["Milchprodukte", " milchprodukte ", "sonstiges", "Other", marker, "  "] {
            XCTAssertNil(StoreCategories.renamingStation("Käse", to: input, emoji: "🧀", in: lidl),
                         "„\(input)“ muss abgelehnt werden")
            XCTAssertNil(store.renameStation("Käse", to: input, emoji: "🧀"), "Hülle: „\(input)“ abgelehnt")
            XCTAssertEqual(store.stationConfigJSON, jsonBefore, "„\(input)“: Konfiguration unverändert")
            XCTAssertEqual(store.routeModel, modelBefore, "„\(input)“: Weg unverändert")
            XCTAssertEqual(store.categoryAssignments["gouda"], "Käse", "„\(input)“: Merkung unverändert")
        }
        XCTAssertNil(StoreCategories.renamingStation("Gibt es nicht", to: "Neu", emoji: "🏷️", in: lidl),
                     "Unbekannter Gang wird nicht umbenannt")

        let recased = try XCTUnwrap(StoreCategories.renamingStation("Käse", to: "käse", emoji: "🐭", in: lidl),
                                    "Nur Schreibweise ändern ist erlaubt")
        XCTAssertEqual(names(recased)[7], "käse")
        XCTAssertEqual(recased.stations[7].emoji, "🐭")
        XCTAssertEqual(recased.stations[7].keywords, lidl.stations[7].keywords, "Stichwörter bleiben")
        let theke = try XCTUnwrap(StoreCategories.renamingStation("Käse", to: "Käsetheke", emoji: "🧀", in: lidl))
        XCTAssertEqual(names(theke)[7], "Käsetheke")
        XCTAssertEqual(names(theke).count, 12, "Umbenennen führt nie zusammen")
    }

    // MARK: S3: Name einer festen Kategorie übernimmt sie (AC-5, AC-9)

    /// S3 / AC-5, AC-9: GIVEN offene, ausgeblendete oder anderswo zugeordnete feste Kategorie WHEN ein
    /// Gang ihres Namens angelegt oder umbenannt THEN sie steht in dessen `builtIns`, nirgends sonst.
    func testRenameToFixedCategoryNameAdoptsCategory() throws {
        let base = config([station("Drogerie", builtIns: ["Körperpflege"]), station("Käse", keywords: ["gouda"])])
        let tier = try XCTUnwrap(StoreCategories.addingStation("Tierbedarf", emoji: "🐾", to: base))
        XCTAssertEqual(names(tier), ["Drogerie", "Käse", "Tierbedarf"], "Am Ende angehängt")
        XCTAssertEqual(builtIns(of: "Tierbedarf", in: tier), ["Tierbedarf"])
        XCTAssertEqual(tier.stations.last?.keywords, [])

        let store = makeStore(template: false)
        store.updateStationConfig(tier)
        XCTAssertFalse(store.isCustomCategory("Tierbedarf"), "Feste Kategorie wird keine eigene")
        XCTAssertTrue(store.isCustomCategory("Käse"), "Gang ohne festen Namen wird eigene Kategorie")

        let hiddenDrinks = config([station("Drogerie")], hidden: ["Getränke", "Werkzeug"])
        let drinks = try XCTUnwrap(StoreCategories.addingStation("getränke", emoji: "🥤", to: hiddenDrinks))
        XCTAssertEqual(drinks.stations.last?.builtIns, ["Getränke"], "Rohwert übernommen")
        XCTAssertEqual(drinks.hidden, ["Werkzeug"], "Aus hidden gelöst")

        let elsewhere = config([station("Trinken", builtIns: ["Getränke", "Snacks"])])
        let moved = try XCTUnwrap(StoreCategories.addingStation("Getränke", emoji: "🥤", to: elsewhere))
        XCTAssertEqual(builtIns(of: "Trinken", in: moved), ["Snacks"], "Aus dem anderen Gang gelöst")
        XCTAssertEqual(builtIns(of: "Getränke", in: moved), ["Getränke"])

        let renamed = try XCTUnwrap(StoreCategories.renamingStation("Käse", to: "Tierbedarf", emoji: "🐾", in: base))
        XCTAssertEqual(names(renamed), ["Drogerie", "Tierbedarf"])
        XCTAssertTrue(builtIns(of: "Tierbedarf", in: renamed).contains("Tierbedarf"))
        XCTAssertEqual(renamed.stations[1].keywords, ["gouda"], "Stichwörter bleiben beim Umbenennen")

        XCTAssertNil(StoreCategories.addingStation("Drogerie", emoji: "🧴", to: base), "Vorhandener Gang")
        XCTAssertNil(StoreCategories.addingStation("Sonstiges", emoji: "🏷️", to: base))
        XCTAssertNil(StoreCategories.addingStation(marker, emoji: "🏷️", to: base))
        XCTAssertNil(StoreCategories.addingStation("   ", emoji: "🏷️", to: base))
    }

    // MARK: S4: Zuordnen (AC-8)

    /// S4 / AC-8: GIVEN Vorlage WHEN `assigning` THEN Kategorie genau in einem Gang, nicht in hidden,
    /// keine Doppelung.
    func testAssignMovesBetweenStationsAndClearsHidden() throws {
        let elektronik = try XCTUnwrap(StoreCategories.assigning("Elektronik", toStation: "Drogerie", in: lidl))
        XCTAssertEqual(builtIns(of: "Drogerie", in: elektronik).last, "Elektronik")
        XCTAssertEqual(elektronik.stations.filter { $0.builtIns.contains("Elektronik") }.count, 1)
        XCTAssertFalse(elektronik.hidden.contains("Elektronik"))

        let werkzeug = try XCTUnwrap(StoreCategories.assigning("Werkzeug", toStation: "Drogerie", in: elektronik))
        XCTAssertFalse(werkzeug.hidden.contains("Werkzeug"), "Aus hidden gelöst")
        XCTAssertTrue(builtIns(of: "Drogerie", in: werkzeug).contains("Werkzeug"))

        let again = try XCTUnwrap(StoreCategories.assigning("Werkzeug", toStation: "Drogerie", in: werkzeug))
        XCTAssertEqual(builtIns(of: "Drogerie", in: again).filter { $0 == "Werkzeug" }.count, 1, "Keine Doppelung")

        let pflege = try XCTUnwrap(StoreCategories.assigning("Körperpflege", toStation: "Käse", in: lidl))
        XCTAssertFalse(builtIns(of: "Drogerie", in: pflege).contains("Körperpflege"), "Aus dem anderen Gang gelöst")
        XCTAssertEqual(builtIns(of: "Käse", in: pflege), ["Körperpflege"])
        XCTAssertNil(StoreCategories.assigning("Körperpflege", toStation: "Gibt es nicht", in: lidl))
    }

    // MARK: S5: Drei Zustände (AC-8, AC-9)

    /// S5 / AC-8, AC-9: GIVEN Vorlage WHEN `categoryState`, `hiding`, `opening` THEN zugeordnet,
    /// ausgeblendet, offen; die Liste folgt (Hammer erst nach dem Zuordnen im Gang).
    func testStatesAssignedHiddenOpen() throws {
        XCTAssertEqual(StoreCategories.categoryState("Backwaren", in: lidl), .assigned("Brot & Backwaren"))
        XCTAssertEqual(StoreCategories.categoryState("Werkzeug", in: lidl), .hidden)
        XCTAssertEqual(StoreCategories.categoryState("Tierbedarf", in: lidl), .open)
        XCTAssertEqual(StoreCategories.categoryState("Getränke", in: lidl), .assigned("Getränke"))

        let hidden = try XCTUnwrap(StoreCategories.hiding("Backwaren", in: lidl))
        XCTAssertEqual(StoreCategories.categoryState("Backwaren", in: hidden), .hidden)
        XCTAssertEqual(builtIns(of: "Brot & Backwaren", in: hidden), [])
        let opened = try XCTUnwrap(StoreCategories.opening("Werkzeug", in: lidl))
        XCTAssertEqual(StoreCategories.categoryState("Werkzeug", in: opened), .open)
        XCTAssertFalse(opened.hidden.contains("Werkzeug"))

        let store = makeStore()
        let hammer = add("Hammer", to: store)
        XCTAssertEqual(hammer.category, "Werkzeug", "Vorbedingung")
        XCTAssertNil(store.stationName(of: hammer), "Werkzeug ist ausgeblendet → Sonstiges")
        store.updateStationConfig(try XCTUnwrap(StoreCategories.assigning("Werkzeug", toStation: "Drogerie", in: lidl)))
        XCTAssertEqual(store.stationName(of: hammer), "Drogerie")
        store.updateStationConfig(try XCTUnwrap(StoreCategories.hiding("Werkzeug", in: try XCTUnwrap(store.stationConfig))))
        XCTAssertNil(store.stationName(of: hammer), "Wieder ausgeblendet → Sonstiges")
    }

    // MARK: S6: Gang löschen (AC-10)

    /// S6 / AC-10: GIVEN Vorlage, eigene Kategorie „Käse“ mit Merkung und Handwahl-Artikel WHEN
    /// `deleteStation("Käse")` THEN Gang, Stichwörter, Merkung, Handwahl und Wegzuordnung weg; ein
    /// fester Gang-Name lässt Artikel bei ihrer Kategorie und vergisst nur Merkungen.
    /// Abweichung von der Spec-Zeile „Gouda → Sonstiges“: Gouda hat die automatische Kategorie
    /// Milchprodukte und landet ohne das Stichwort folgerichtig in diesem Gang.
    func testDeleteStationOpensCategoriesAndCleansUp() throws {
        let store = makeStore()
        store.rememberCategory("Käse", forItemNamed: "Feta")
        let brie = addManual("Brie", category: "Käse", to: store)
        let gouda = add("Gouda", to: store)
        var model = store.routeModel
        model.itemCategories["gouda"] = "Käse"
        store.routeModel = model
        XCTAssertEqual(store.stationName(of: gouda), "Käse", "Vorbedingung: Stichwort")

        store.deleteStation("Käse")

        XCTAssertFalse(names(store.stationConfig).contains("Käse"))
        XCTAssertEqual(names(store.stationConfig).count, 11)
        XCTAssertEqual(store.stationName(of: gouda), "Milchprodukte", "Stichwort „gouda“ greift nicht mehr")
        XCTAssertNil(store.categoryAssignments["feta"], "Merkung weg")
        XCTAssertEqual(brie.category, AssignmentService.category(for: "Brie"), "Zurück auf die automatische Kategorie")
        XCTAssertFalse(brie.categoryManuallySet)
        XCTAssertEqual(store.customCategoryEntries["Käse"]?.isDeleted, true, "Eigene Kategorie mit Löschvermerk")
        XCTAssertFalse(store.routeModel.itemCategories.values.contains("Käse"))

        store.rememberCategory("Getränke", forItemNamed: "Salami")
        let cola = add("Cola", to: store)
        XCTAssertEqual(cola.category, "Getränke", "Vorbedingung")
        store.deleteStation("Getränke")
        let config = try XCTUnwrap(store.stationConfig)
        XCTAssertEqual(StoreCategories.categoryState("Getränke", in: config), .open)
        XCTAssertEqual(cola.category, "Getränke", "Feste Kategorie bleibt")
        XCTAssertNil(store.categoryAssignments["salami"], "Merkung auf festen Gang-Namen vergessen")
        XCTAssertNil(store.stationName(of: cola), "Offen → Sonstiges")

        XCTAssertNil(StoreCategories.deletingStation("Gibt es nicht", in: lidl))
        let deleted = try XCTUnwrap(StoreCategories.deletingStation("Drogerie", in: lidl))
        XCTAssertEqual(StoreCategories.categoryState("Körperpflege", in: deleted), .open, "builtIns werden offen")
        XCTAssertFalse(deleted.hidden.contains("Körperpflege"))
    }

    // MARK: S7: Verschieben (AC-6)

    /// S7 / AC-6: GIVEN Vorlage WHEN „Käse“ vor „Obst & Gemüse“ verschoben THEN Reihenfolge, Rang
    /// und `pendingItems` folgen, Inhalt der Gänge unberührt.
    func testMovingStationsChangesOrderAndRank() throws {
        let moved = StoreCategories.movingStations(from: IndexSet(integer: 7), to: 0, in: lidl)
        XCTAssertEqual(names(moved), ["Käse"] + templateNames.filter { $0 != "Käse" })
        for station in lidl.stations {
            let after = try XCTUnwrap(moved.stations.first { $0.name == station.name })
            XCTAssertEqual(after.builtIns, station.builtIns, station.name)
            XCTAssertEqual(after.keywords, station.keywords, station.name)
        }
        XCTAssertEqual(moved.hidden, lidl.hidden)

        let store = makeStore()
        let gouda = add("Gouda", to: store, added: 0)
        add("Apfel", to: store, added: 10)
        store.sortMode = .route
        XCTAssertEqual(store.pendingItems.map(\.name), ["Apfel", "Gouda"], "Vorher")
        store.updateStationConfig(moved)
        XCTAssertEqual(store.stationRank(of: gouda), 0)
        XCTAssertEqual(store.pendingItems.map(\.name), ["Gouda", "Apfel"])
        store.sortMode = .category
        XCTAssertEqual(store.pendingItems.map(\.name), ["Gouda", "Apfel"], "Auch im Modus Kategorie")
    }

    // MARK: S8: Laden ohne Gänge (AC-7, AC-11)

    /// S8 / AC-7, AC-11: GIVEN Laden ohne Gänge WHEN erster Gang angelegt THEN Laden mit Gängen, Gang
    /// als eigene Kategorie, Zeitstempel jetzt; WHEN Gänge entfernt THEN Kategorien und Merkungen bleiben.
    func testSetupOnStoreWithoutStations() throws {
        let store = makeStore(template: false)
        XCTAssertFalse(store.hasStations)
        let empty = store.stationConfig ?? StationConfig(stations: [], hidden: [], date: t0)
        let start = Date()
        store.updateStationConfig(try XCTUnwrap(StoreCategories.addingStation("Lager", emoji: "📦", to: empty)))

        XCTAssertTrue(store.hasStations)
        XCTAssertEqual(names(store.stationConfig), ["Lager"])
        XCTAssertTrue(store.isCustomCategory("Lager"))
        XCTAssertEqual(store.categoryEmoji("Lager"), "📦")
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(store.stationConfig?.date), start.addingTimeInterval(-1), "Zeitstempel jetzt")

        store.rememberCategory("Lager", forItemNamed: "Kiste")
        store.removeStations()
        XCTAssertFalse(store.hasStations)
        XCTAssertTrue(store.isCustomCategory("Lager"), "Eigene Kategorie bleibt")
        XCTAssertEqual(store.categoryAssignments["kiste"], "Lager", "Merkung bleibt")
    }

    // MARK: S9: Invarianten (AC-12)

    /// S9 / AC-12: GIVEN Vorlage WHEN 25 feste Operationen (auch abgelehnte) THEN nach jedem Schritt
    /// alle Invarianten.
    func testInvariantsHoldAfterOperationSequence() {
        let marker = self.marker
        let ops: [(String, (StationConfig) -> StationConfig?)] = [
            ("anlegen Lager", { StoreCategories.addingStation("Lager", emoji: "📦", to: $0) }),
            ("anlegen lager (doppelt)", { StoreCategories.addingStation("lager", emoji: "📦", to: $0) }),
            ("anlegen Werkzeug", { StoreCategories.addingStation("Werkzeug", emoji: "🔧", to: $0) }),
            ("zuordnen Werkzeug → Drogerie (gesperrt)", { StoreCategories.assigning("Werkzeug", toStation: "Drogerie", in: $0) }),
            ("ausblenden Werkzeug (gesperrt)", { StoreCategories.hiding("Werkzeug", in: $0) }),
            ("zuordnen Elektronik → Lager", { StoreCategories.assigning("Elektronik", toStation: "Lager", in: $0) }),
            ("zuordnen Elektronik → Käse", { StoreCategories.assigning("Elektronik", toStation: "Käse", in: $0) }),
            ("ausblenden Elektronik", { StoreCategories.hiding("Elektronik", in: $0) }),
            ("öffnen Elektronik", { StoreCategories.opening("Elektronik", in: $0) }),
            ("umbenennen Käse → Milchprodukte (Kollision)",
             { StoreCategories.renamingStation("Käse", to: "Milchprodukte", emoji: "🧀", in: $0) }),
            ("umbenennen Käse → Sonstiges", { StoreCategories.renamingStation("Käse", to: "Sonstiges", emoji: "🧀", in: $0) }),
            ("umbenennen Käse → Tierbedarf", { StoreCategories.renamingStation("Käse", to: "Tierbedarf", emoji: "🐾", in: $0) }),
            ("umbenennen Werkzeug → Basteln", { StoreCategories.renamingStation("Werkzeug", to: "Basteln", emoji: "🔧", in: $0) }),
            ("ausblenden Werkzeug", { StoreCategories.hiding("Werkzeug", in: $0) }),
            ("zuordnen Getränke → Lager (gesperrt)", { StoreCategories.assigning("Getränke", toStation: "Lager", in: $0) }),
            ("löschen Getränke", { StoreCategories.deletingStation("Getränke", in: $0) }),
            ("zuordnen Getränke → Lager", { StoreCategories.assigning("Getränke", toStation: "Lager", in: $0) }),
            ("anlegen Getränke", { StoreCategories.addingStation("Getränke", emoji: "🥤", to: $0) }),
            ("verschieben letzter → vorn",
             { StoreCategories.movingStations(from: IndexSet(integer: $0.stations.count - 1), to: 0, in: $0) }),
            ("verschieben erster → hinten",
             { StoreCategories.movingStations(from: IndexSet(integer: 0), to: $0.stations.count, in: $0) }),
            ("umbenennen Lager → lager", { StoreCategories.renamingStation("Lager", to: "lager", emoji: "📦", in: $0) }),
            ("anlegen leer", { StoreCategories.addingStation(" ", emoji: "🏷️", to: $0) }),
            ("anlegen Marke", { StoreCategories.addingStation(marker, emoji: "🏷️", to: $0) }),
            ("löschen Drogerie", { StoreCategories.deletingStation("Drogerie", in: $0) }),
            ("öffnen Körperpflege", { StoreCategories.opening("Körperpflege", in: $0) }),
        ]
        XCTAssertEqual(ops.count, 25)
        var current = lidl
        assertInvariants(current, "Start")
        var applied = 0
        for (step, op) in ops {
            if let next = op(current) { current = next; applied += 1 }
            assertInvariants(current, step)
        }
        XCTAssertGreaterThanOrEqual(applied, 15, "Die Folge muss überwiegend wirksame Schritte enthalten")
        XCTAssertEqual(StoreCategories.categoryState("Getränke", in: current), .assigned("Getränke"))
        XCTAssertEqual(StoreCategories.categoryState("Werkzeug", in: current), .hidden)
        XCTAssertEqual(StoreCategories.categoryState("Körperpflege", in: current), .open)
    }

    // MARK: S10: Name-gebundene Kategorie (AC-9)

    /// S10 / AC-9: GIVEN Gang „Getränke“ und „Drogerie“ WHEN „Getränke“ wegbewegen, ausblenden oder
    /// öffnen THEN abgelehnt; nach Umbenennen des Gangs frei.
    func testNameBoundCategoryCannotBeMovedAway() throws {
        let base = config([station("Getränke", builtIns: ["Getränke"]), station("Drogerie", builtIns: ["Körperpflege"])])
        XCTAssertNil(StoreCategories.assigning("Getränke", toStation: "Drogerie", in: base))
        XCTAssertNil(StoreCategories.hiding("Getränke", in: base))
        XCTAssertNil(StoreCategories.opening("Getränke", in: base))
        XCTAssertEqual(StoreCategories.categoryState("Getränke", in: base), .assigned("Getränke"))

        let renamed = try XCTUnwrap(StoreCategories.renamingStation("Getränke", to: "Trinken", emoji: "🥤", in: base))
        XCTAssertEqual(builtIns(of: "Trinken", in: renamed), ["Getränke"], "Kategorie bleibt nach Umbenennen im Gang")
        let freed = try XCTUnwrap(StoreCategories.assigning("Getränke", toStation: "Drogerie", in: renamed))
        XCTAssertEqual(StoreCategories.categoryState("Getränke", in: freed), .assigned("Drogerie"))
        XCTAssertNotNil(StoreCategories.hiding("Getränke", in: renamed))
    }

    // MARK: S11: Laufende Abhak-Sitzung (AC-4)

    /// S11 / AC-4: GIVEN laufende Sitzung mit zwei Einträgen in „Käse“ WHEN umbenannt THEN die
    /// Einträge tragen den neuen Namen, der Abschluss lernt nur ihn; Löschen lässt die Sitzung stehen.
    func testRenameUpdatesRunningTrip() throws {
        let store = makeStore()
        add("Gouda", to: store)
        add("Feta", to: store)
        store.recordCheckOff(try item("Gouda", in: store), at: t0)
        store.recordCheckOff(try item("Feta", in: store), at: t0.addingTimeInterval(40))
        XCTAssertEqual(store.currentTrip.entries.map(\.category), ["Käse", "Käse"], "Vorbedingung")

        XCTAssertEqual(store.renameStation("Käse", to: "Käse & Co", emoji: "🧀"), "Käse & Co")
        XCTAssertEqual(store.currentTrip.entries.map(\.category), ["Käse & Co", "Käse & Co"])

        store.finalizeStaleTrip(now: t0.addingTimeInterval(40 + 31 * 60))
        XCTAssertEqual(store.routeModel.itemCategories["gouda"], "Käse & Co", "Abschluss lernt den neuen Namen")
        XCTAssertEqual(store.routeModel.itemCategories["feta"], "Käse & Co")
        XCTAssertFalse(store.routeModel.itemCategories.values.contains("Käse"), "Nie den alten Namen")

        let other = makeStore("UT-Löschladen")
        add("Gouda", to: other)
        add("Feta", to: other)
        other.recordCheckOff(try item("Gouda", in: other), at: t0)
        other.recordCheckOff(try item("Feta", in: other), at: t0.addingTimeInterval(40))
        let tripBefore = other.currentTrip
        other.deleteStation("Käse")
        XCTAssertEqual(other.currentTrip, tripBefore, "Löschen verändert die Sitzung nicht")
    }

    // MARK: S12: Vorlage wählen (AC-13)

    /// S12 / AC-13: GIVEN Laden mit eigenem Gang „Lager“ und Merkung WHEN Lidl-Vorlage übernommen THEN
    /// genau die 12 Gänge, Merkung und eigene Kategorie „Lager“ bleiben.
    func testApplyTemplateReplacesStationsKeepsAssignments() throws {
        let store = makeStore(template: false)
        let empty = StationConfig(stations: [], hidden: [], date: t0)
        store.updateStationConfig(try XCTUnwrap(StoreCategories.addingStation("Lager", emoji: "📦", to: empty)))
        store.rememberCategory("Lager", forItemNamed: "Kiste")
        XCTAssertEqual(store.categoryAssignments["kiste"], "Lager", "Vorbedingung")
        let salami = add("Salami", to: store)
        let before = (salami.category, salami.categoryManuallySet)

        store.applyStationConfig(lidl)

        XCTAssertEqual(names(store.stationConfig), templateNames)
        XCTAssertEqual(store.categoryAssignments["kiste"], "Lager", "Merkung bleibt")
        XCTAssertTrue(store.isCustomCategory("Lager"), "Eigene Kategorie bleibt")
        XCTAssertNil(store.stationName(forItemNamed: "Kiste", category: "Lager", manuallySet: true),
                     "Ohne Gang „Lager“ wirkt die Merkung nicht")
        XCTAssertEqual(salami.category, before.0)
        XCTAssertEqual(salami.categoryManuallySet, before.1)
    }

    // MARK: S13: Texte (AC-14)

    /// S13 / AC-14: Alle `station.setup.*`-Schlüssel stehen in beiden Tabellen, nicht leer, mit der
    /// erwarteten Platzhalterzahl; die gestrichenen D1-Schlüssel fehlen.
    func testSetupStringsExistInBothLanguages() throws {
        let expected: [String: Int] = [
            "station.setup.menu": 0, "station.setup.title": 0, "station.setup.done": 0,
            "station.setup.template": 0, "station.setup.template.title": 0, "station.setup.template.message": 0,
            "station.setup.template.lidl": 0, "station.setup.section.stations": 1, "station.setup.section.open": 1,
            "station.setup.section.open.footer": 0, "station.setup.section.hidden": 1, "station.setup.sort": 0,
            "station.setup.add": 0, "station.setup.add.prompt": 0, "station.setup.assign": 0,
            "station.setup.hide": 0, "station.setup.show": 0, "station.setup.remove": 0, "station.setup.shared": 0,
            "station.setup.row.summary": 2, "station.setup.row.empty": 0, "station.setup.detail.title": 0,
            "station.setup.detail.categories": 1, "station.setup.detail.in": 1, "station.setup.detail.bound": 1,
            "station.setup.detail.keywords": 0, "station.setup.detail.delete": 0, "station.setup.delete.title": 1,
            "station.setup.delete.message": 0, "station.setup.name.rejected": 0,
        ]
        let removed = ["station.menu.applyTemplate", "station.template.confirm.title", "station.template.confirm.message"]
        for localization in ["de", "en"] {
            let url = try XCTUnwrap(Bundle.main.url(forResource: "Localizable", withExtension: "strings",
                                                    subdirectory: nil, localization: localization))
            let table = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])
            for (key, count) in expected {
                let value = try XCTUnwrap(table[key], "\(localization): Schlüssel \(key) fehlt")
                XCTAssertFalse(value.trimmingCharacters(in: .whitespaces).isEmpty, "\(localization): \(key) ist leer")
                XCTAssertEqual(LocalizationKeyParityTests.placeholders(in: value).count, count,
                               "\(localization): \(key) hat falsche Platzhalterzahl")
            }
            for key in removed {
                XCTAssertNil(table[key], "\(localization): \(key) wird nicht mehr benutzt und ist zu streichen")
            }
            if localization == "de" {
                // Diese Texte prüfen die UI-Tests V1–V8 wörtlich.
                XCTAssertEqual(table["station.setup.menu"], "Kategorien einrichten")
                XCTAssertEqual(table["station.setup.add"], "Gang hinzufügen")
                XCTAssertEqual(table["station.setup.template"], "Vorlage wählen …")
                XCTAssertEqual(table["station.setup.name.rejected"], "Diesen Namen gibt es schon oder er ist nicht erlaubt.")
                XCTAssertEqual(table["station.setup.shared"], "Gänge bleiben bis zum Abgleich auf diesem Gerät.")
            }
        }
    }

    // MARK: S14/S15: Nachträge aus der Adversary-Prüfung (F001, F002)

    /// S14 / AC-7, AC-9 (F001): GIVEN Gang-Name, der eine feste Kategorie nur in anderer Schreibweise
    /// trägt („tierbedarf“, „Getranke“) WHEN angelegt oder umbenannt THEN keine eigene Kategorie
    /// gleichen Namens, die feste Kategorie gehört zum Gang.
    func testStationNamedLikeFixedCategoryCreatesNoCustomCategory() throws {
        let store = makeStore()
        let sameKey = { (name: String) in
            store.customCategories.contains { StoreCategories.compareKey($0) == StoreCategories.compareKey(name) }
        }

        XCTAssertEqual(store.addStation("tierbedarf"), "tierbedarf")
        XCTAssertFalse(sameKey("Tierbedarf"), "„tierbedarf“ ist die feste Kategorie Tierbedarf, keine eigene")
        XCTAssertEqual(StoreCategories.categoryState("Tierbedarf", in: try XCTUnwrap(store.stationConfig)), .assigned("tierbedarf"))

        store.deleteStation("Getränke")
        XCTAssertEqual(store.renameStation("Käse", to: "Getranke", emoji: "🥤"), "Getranke")
        XCTAssertFalse(sameKey("Getränke"), "„Getranke“ ist die feste Kategorie Getränke, keine eigene")
        let config = try XCTUnwrap(store.stationConfig)
        XCTAssertTrue(builtIns(of: "Getranke", in: config).contains("Getränke"))
        XCTAssertEqual(StoreCategories.categoryState("Getränke", in: config), .assigned("Getranke"))
        let cola = add("Cola", to: store)
        XCTAssertEqual(store.stationName(of: cola), "Getranke")
    }

    /// S15 / AC-3 (F002): GIVEN Gang „Käse“ (eigene Kategorie, 🧀) WHEN nur das Emoji geändert THEN
    /// Gang und eigene Kategorie tragen das neue Emoji.
    func testEmojiChangeUpdatesCustomCategoryEmoji() {
        let store = makeStore()
        XCTAssertEqual(store.categoryEmoji("Käse"), "🧀", "Vorbedingung")

        XCTAssertEqual(store.renameStation("Käse", to: "Käse", emoji: "🐭"), "Käse")

        XCTAssertEqual(store.stationEmoji("Käse"), "🐭")
        XCTAssertEqual(store.categoryEmoji("Käse"), "🐭", "Emoji der eigenen Kategorie zieht mit")
        XCTAssertEqual(store.customCategoryEntries["Käse"]?.isDeleted, false)
    }

    /// S16 / AC-3, AC-9 (F004): GIVEN Gang „Getränke“ mit Handwahl-Artikel und Merkung WHEN umbenannt
    /// auf „Trinken“ und dann auf „getränke“ (fest → eigen → fest, andere Schreibweise) THEN Artikel und
    /// Merkung tragen den Rohwert „Getränke“, der Gang heißt wie getippt; nach „Gänge entfernen“ steht
    /// die feste Kategorie im Artikel.
    func testRenameBackToFixedNameStoresCanonicalCategory() throws {
        let store = makeStore()
        let cola = addManual("Cola", category: "Getränke", to: store)
        store.rememberCategory("Getränke", forItemNamed: "Wasser")

        XCTAssertEqual(store.renameStation("Getränke", to: "Trinken", emoji: "🥤"), "Trinken")
        XCTAssertEqual(cola.category, "Trinken", "Vorbedingung: Handwahl zieht mit")
        XCTAssertEqual(store.renameStation("Trinken", to: "getränke", emoji: "🥤"), "getränke")

        XCTAssertEqual(names(store.stationConfig).last, "getränke", "Gang-Name bleibt wie getippt")
        XCTAssertEqual(cola.category, "Getränke", "Artikel trägt den Rohwert der festen Kategorie")
        XCTAssertTrue(cola.categoryManuallySet)
        XCTAssertEqual(store.categoryAssignments["wasser"], "Getränke", "Merkung trägt den Rohwert")
        XCTAssertEqual(store.stationName(of: cola), "getränke")
        XCTAssertFalse(store.isCustomCategory("getränke"))

        store.removeStations()
        XCTAssertEqual(cola.category, "Getränke")
        XCTAssertTrue(AssignmentService.categoryOrder.contains(cola.category), "Ohne Gänge eine gültige feste Kategorie")
    }

    /// S17 / AC-10 (F005): GIVEN Gang „getränke“ (fester Name, andere Schreibweise) mit Merkung auf
    /// den Rohwert „Getränke“ WHEN `deleteStation("getränke")` THEN Merkung vergessen; ein später
    /// angelegter Gang „Getränke“ erbt sie nicht.
    func testDeleteStationWithVariantSpellingForgetsCanonicalAssignments() throws {
        let store = makeStore()
        XCTAssertEqual(store.renameStation("Getränke", to: "getränke", emoji: "🥤"), "getränke")
        store.rememberCategory("Getränke", forItemNamed: "Wasser")
        XCTAssertEqual(store.categoryAssignments["wasser"], "Getränke", "Vorbedingung: Merkung trägt den Rohwert")

        store.deleteStation("getränke")

        XCTAssertFalse(names(store.stationConfig).contains("getränke"))
        XCTAssertNil(store.categoryAssignments["wasser"], "Merkung auf den festen Namen vergessen")
        XCTAssertEqual(store.addStation("Getränke"), "Getränke")
        XCTAssertNil(store.rememberedCategory(forItemNamed: "Wasser"), "Neuer Gang „Getränke“ erbt keine Merkung")
    }
}
