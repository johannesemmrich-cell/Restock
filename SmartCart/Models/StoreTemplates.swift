import Foundation

// MARK: - Mustervorlagen (Issue #234, Durchgang 2b-1, `docs/specs/views/station-templates-keywords.md`)
//
// Reine Daten wie `lidlTemplate`; `Store.applyStationConfig` setzt den Zeitstempel. „Lebensmittel“
// (Rückfall für Unerkanntes) steht in keinem Gang. Nur im App-Ziel kompiliert.

extension StoreCategories {
    /// Baumarkt-Kategorien, in den Lebensmittel-Vorlagen ausgeblendet.
    private static let hardwareCategories = ["Werkzeug", "Eisenwaren", "Garten", "Pflanzen", "Farbe & Lack",
                                             "Sanitär", "Boden & Fliesen", "Holz", "Baumaterial"]

    /// Die acht Drogerie-Kategorien.
    private static let drugstoreCategories = ["Körperpflege", "Haarpflege", "Zahnpflege", "Kosmetik",
                                              "Hygieneartikel", "Reinigung", "Medikamente", "Babybedarf"]

    private static func station(_ name: String, _ emoji: String, _ builtIns: [String],
                                _ keywords: [String] = []) -> Station {
        Station(name: name, emoji: emoji, builtIns: builtIns, keywords: keywords)
    }

    /// Muster Aldi Süd, 10 Gänge.
    static let discounterTemplate = StationConfig(
        stations: [
            station("Obst & Gemüse", "🥦", ["Obst & Gemüse"]),
            station("Fleisch & Fisch", "🥩", ["Fleisch & Wurst"],
                    ["fisch", "lachs", "forelle", "garnelen", "hähnchen", "bratwurst", "hackfleisch", "steak",
                     "schnitzel"]),
            station("Backstation", "🥖", ["Backwaren"]),
            station("Wurst, Käse & Molkerei", "🧀", ["Milchprodukte"],
                    ["käse", "wurst", "würstchen", "salami", "schinken", "aufschnitt", "gouda", "mozzarella", "eier",
                     "margarine"]),
            station("Kühlregal Fertiges", "🧊", [],
                    ["tofu", "hummus", "salatbox", "dip", "tzatziki", "maultaschen", "nudelsalat", "kartoffelsalat"]),
            station("Trockensortiment", "🥫", ["Konserven", "Gewürze & Backen", "Snacks"],
                    ["kaffee", "tee", "nudeln", "reis", "mehl", "müsli", "schokolade"]),
            station("Tiefkühl", "❄️", ["Tiefkühlkost"], ["pizza", "pommes", "fischstäbchen", "eiscreme"]),
            station("Getränke", "🥤", ["Getränke"]),
            station("Drogerie & Baby", "🧴", drugstoreCategories + ["Tierbedarf"]),
            station("Aktionsware", "🛒", ["Haushaltswaren", "Küchenausstattung", "Elektronik", "Textilien",
                                         "Schreibwaren", "Spielzeug", "Dekoration"]),
        ],
        hidden: hardwareCategories,
        date: Date(timeIntervalSince1970: 0)
    )

    /// Muster Edeka/Kaufland, 12 Gänge.
    static let fullRangeTemplate = StationConfig(
        stations: [
            station("Obst & Gemüse", "🥦", ["Obst & Gemüse"]),
            station("Backwaren", "🥖", ["Backwaren"]),
            station("Fleisch, Wurst & Fisch", "🥩", ["Fleisch & Wurst"],
                    ["fisch", "lachs", "forelle", "garnelen", "hähnchen", "hackfleisch", "steak", "schnitzel"]),
            station("Käse", "🧀", [],
                    ["käse", "gouda", "edamer", "emmentaler", "mozzarella", "feta", "parmesan", "camembert", "brie",
                     "gorgonzola"]),
            station("Molkerei & Kühlung", "🥛", ["Milchprodukte"], ["eier", "margarine", "tofu", "hummus", "tzatziki", "dip"]),
            station("Konserven & Nährmittel", "🥫", ["Konserven", "Gewürze & Backen"],
                    ["nudeln", "reis", "mehl", "müsli", "haferflocken"]),
            station("Süßwaren & Snacks", "🍫", ["Snacks"], ["kaffee", "tee", "schokolade", "kekse", "gummibärchen"]),
            station("Tiefkühl", "❄️", ["Tiefkühlkost"], ["pizza", "pommes", "fischstäbchen", "eiscreme"]),
            station("Drogerie & Haushalt", "🧴", drugstoreCategories + ["Haushaltswaren", "Küchenausstattung"]),
            station("Tierbedarf", "🐾", ["Tierbedarf"]),
            station("Non-Food", "🛒", ["Elektronik", "Textilien", "Schreibwaren", "Spielzeug", "Dekoration"]),
            station("Getränke", "🥤", ["Getränke"]),
        ],
        hidden: hardwareCategories,
        date: Date(timeIntervalSince1970: 0)
    )

    /// Muster dm (abgeleitet), 11 Gänge.
    static let drugstoreTemplate = StationConfig(
        stations: [
            station("Kosmetik", "💄", ["Kosmetik"]),
            station("Haarpflege", "💇", ["Haarpflege"]),
            station("Körperpflege", "🧴", ["Körperpflege"]),
            station("Zahnpflege", "🦷", ["Zahnpflege"]),
            station("Gesundheit", "💊", ["Medikamente"]),
            station("Hygiene", "🧻", ["Hygieneartikel"]),
            station("Baby", "👶", ["Babybedarf"]),
            station("Haushalt & Reinigung", "🧼", ["Reinigung", "Haushaltswaren", "Küchenausstattung"]),
            station("Tierbedarf", "🐾", ["Tierbedarf"]),
            station("Essen & Trinken", "🌿", ["Snacks", "Getränke", "Konserven", "Gewürze & Backen"], ["kaffee", "tee"]),
            station("Kasse & Geschenke", "🛒", ["Schreibwaren", "Spielzeug", "Dekoration", "Elektronik", "Textilien"]),
        ],
        hidden: [],
        date: Date(timeIntervalSince1970: 0)
    )

    /// Muster Hornbach, 8 Gänge.
    static let hardwareTemplate = StationConfig(
        stations: [
            station("Garten & Pflanzen", "🌷", ["Garten", "Pflanzen"]),
            station("Deko & Leuchten", "💡", ["Dekoration"], ["lampe", "leuchte", "glühbirne"]),
            station("Bad & Sanitär", "🚿", ["Sanitär"]),
            station("Fliesen & Boden", "🧱", ["Boden & Fliesen"]),
            station("Farben & Tapeten", "🎨", ["Farbe & Lack"], ["tapete", "pinsel"]),
            station("Werkzeug & Maschinen", "🔧", ["Werkzeug"], ["hammer", "bohrer", "säge"]),
            station("Eisenwaren & Befestigung", "🔩", ["Eisenwaren"], ["dübel", "schraube", "nagel", "haken"]),
            station("Holz & Baustoffe", "🪵", ["Holz", "Baumaterial"]),
        ],
        hidden: [],
        date: Date(timeIntervalSince1970: 0)
    )

    /// Vorlagen für das Blatt „Vorlage wählen“, in Anzeige-Reihenfolge.
    static let allTemplates: [(id: String, template: StationConfig)] = [
        ("lidl", lidlTemplate),
        ("discounter", discounterTemplate),
        ("fullRange", fullRangeTemplate),
        ("drugstore", drugstoreTemplate),
        ("hardware", hardwareTemplate),
    ]

    /// `compareKey`s aller Gang-Namen aller Vorlagen (Regel R3, Durchgang 2b-2).
    static let templateStationNames: Set<String> = Set(allTemplates.flatMap { $0.template.stations.map { compareKey($0.name) } })
}

// Übernahme früherer eigener Kategorien (Durchgang 2b-2). Hier statt in `Store.swift`, weil
// `Store.swift` auch im Widget- und Teilen-Ziel läuft, die Vorlagen nur im App-Ziel.
extension Store {
    /// Gänge nur, wenn es mindestens einen gibt.
    private var adoptionConfig: StationConfig? { hasStations ? stationConfig : nil }

    /// Eigene Kategorien „von früher“ (Regel R3); im Laden ohne Gänge leer.
    var adoptableCategories: [String] {
        guard let config = adoptionConfig else { return [] }
        let names = (items ?? []).map(\.category) + Array(categoryAssignments.values)
        return StoreCategories.adoptableCategories(custom: customCategories, config: config,
                                                   used: Set(names.map(StoreCategories.compareKey)),
                                                   templateNames: StoreCategories.templateStationNames)
    }

    /// Eigene Kategorie als Gang am Ende übernehmen, mit ihrem Emoji. `nil` (nichts geändert), wenn
    /// der Laden keine Gänge hat oder der Name nicht annehmbar ist.
    @discardableResult
    func adoptCategory(_ name: String) -> String? {
        guard let config = adoptionConfig,
              let next = StoreCategories.addingStation(name, emoji: categoryEmoji(name), to: config) else { return nil }
        updateStationConfig(next)
        return next.stations.last?.name
    }

    /// Alle Kategorien „von früher“ in Listenreihenfolge übernehmen, mit genau einem Schreibvorgang.
    @discardableResult
    func adoptAllCategories() -> [String] {
        guard var config = adoptionConfig else { return [] }
        var adopted: [String] = []
        for name in adoptableCategories {
            guard let next = StoreCategories.addingStation(name, emoji: categoryEmoji(name), to: config),
                  let added = next.stations.last?.name else { continue }
            config = next
            adopted.append(added)
        }
        if !adopted.isEmpty { updateStationConfig(config) }
        return adopted
    }
}
