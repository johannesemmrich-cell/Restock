import Foundation

// Issue #85: Eigene Kategorien pro Laden.
//
// Reine, testbare Logik ohne SwiftData/UserDefaults — `Store` speichert die Einträge in zwei
// additiven Feldern (`customCategoryEmojis`, `customCategoryDates`) und ruft diese Funktionen auf.
// Wird wie `Store.swift` in App, Widget und Share Extension kompiliert.

/// Stand einer eigenen Kategorie für den Abgleich geteilter Läden: `emoji == nil` heißt gelöscht.
/// Der Zeitpunkt entscheidet, welche Seite gewinnt (wie bei den gelernten Preisen).
struct CustomCategoryEntry: Codable, Equatable {
    var emoji: String?
    var date: Date

    var isDeleted: Bool { emoji == nil }
}

/// Gemerkte Zuordnung Artikel → eigene Kategorie für den Abgleich geteilter Läden (Issue #94):
/// `category == nil` heißt vergessen (feste Kategorie gewählt oder Kategorie gelöscht). Wie bei
/// den Kategorien gewinnt pro Artikel der spätere Stand.
struct CategoryAssignmentEntry: Codable, Equatable {
    var category: String?
    var date: Date
}

enum StoreCategories {
    /// Emoji, wenn weder Name noch Nutzer eines vorgeben.
    static let defaultEmoji = "🏷️"

    /// Auswahl im Bearbeiten-Dialog einer eigenen Kategorie.
    static let emojiChoices = [
        "🏷️", "🧊", "❄️", "🥖", "🥐", "🍞", "🧀", "🥛", "🥚", "🥩", "🍗", "🐟",
        "🥦", "🍎", "🍌", "🥕", "🌿", "🍝", "🥫", "🫙", "🧂", "🍫", "🍪", "🍷",
        "🍺", "🥤", "☕️", "🧃", "🧴", "🧼", "🧻", "💊", "👶", "🐾", "🌸", "🛒",
        "💇", "🦷", "💄", "🔧", "🔩", "🪵", "🧱", "🎨", "🚿", "💡", "🌷", "🌱",
    ]

    /// Stichwörter → Emoji-Vorschlag für einen neuen Namen. Erste Übereinstimmung gewinnt.
    private static let emojiKeywords: [(keywords: [String], emoji: String)] = [
        (["tiefkühl", "gefrier"], "❄️"),
        (["kühl", "frische", "theke"], "🧊"),
        (["backstation", "bäcker", "back", "brot", "brötchen"], "🥖"),
        (["käse"], "🧀"),
        (["milch", "molkerei", "joghurt"], "🥛"),
        (["fleisch", "wurst", "metzger"], "🥩"),
        (["fisch"], "🐟"),
        (["obst", "gemüse", "frucht"], "🍎"),
        (["kräuter", "bio"], "🌿"),
        (["nudel", "pasta", "reis"], "🍝"),
        (["konserve", "dose"], "🥫"),
        (["gewürz"], "🧂"),
        (["süß", "schoko", "süßig", "naschen"], "🍫"),
        (["wein", "spirituose", "alkohol"], "🍷"),
        (["bier"], "🍺"),
        (["getränk", "wasser", "saft"], "🥤"),
        (["kaffee", "tee"], "☕️"),
        (["haar", "friseur"], "💇"),
        (["zahn", "mund"], "🦷"),
        (["make-up", "makeup", "schmink", "kosmetik", "parfum", "parfüm", "duft"], "💄"),
        (["drogerie", "pflege"], "🧴"),
        (["schraube", "eisenwaren", "befestigung", "beschlag"], "🔩"),
        (["holz", "brett", "latte"], "🪵"),
        (["fliese", "boden", "laminat", "parkett"], "🧱"),
        (["farbe", "lack", "tapete"], "🎨"),
        (["sanitär", "bad", "rohr", "heizung"], "🚿"),
        (["elektro", "leucht", "lampe", "kabel"], "💡"),
        (["werkzeug", "maschine"], "🔧"),
        (["garten", "erde", "dünger"], "🌱"),
        (["putz", "reinig", "wasch"], "🧼"),
        (["papier", "hygiene"], "🧻"),
        (["apotheke", "medizin"], "💊"),
        (["baby", "kind"], "👶"),
        (["tier", "hund", "katze"], "🐾"),
        (["blume", "pflanze"], "🌸"),
        (["kasse", "aktion", "angebot"], "🛒"),
    ]

    /// Leerzeichen am Rand entfernt, Folgen von Leerzeichen zu einem zusammengefasst.
    static func normalizedName(_ input: String) -> String {
        input.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Vergleichsschlüssel: ohne Groß-/Kleinschreibung und Akzente.
    static func compareKey(_ name: String) -> String {
        normalizedName(name).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE"))
    }

    enum Resolution: Equatable {
        /// Eine feste Kategorie (Rohwert, z. B. "Milchprodukte").
        case builtIn(String)
        /// Eine schon vorhandene eigene Kategorie dieses Ladens (gespeicherte Schreibweise).
        case existingCustom(String)
        /// Neu anzulegen, mit diesem Namen.
        case new(String)
        /// Leer.
        case invalid
    }

    /// Was aus einer Eingabe im Suchfeld wird. Feste Kategorien werden über Rohwert und
    /// angezeigten Namen erkannt, beides ohne Groß-/Kleinschreibung — „milchprodukte“ legt also
    /// keine eigene Kategorie neben „Milchprodukte“ an.
    static func resolve(
        _ input: String,
        builtIn: [String],
        displayName: (String) -> String,
        custom: [String]
    ) -> Resolution {
        let name = normalizedName(input)
        guard !name.isEmpty else { return .invalid }
        let key = compareKey(name)
        if let match = builtIn.first(where: { compareKey($0) == key || compareKey(displayName($0)) == key }) {
            return .builtIn(match)
        }
        if let match = custom.first(where: { compareKey($0) == key }) {
            return .existingCustom(match)
        }
        return .new(name)
    }

    /// Emoji-Vorschlag für einen neuen Kategorienamen.
    static func suggestedEmoji(for name: String) -> String {
        let key = compareKey(name)
        for entry in emojiKeywords where entry.keywords.contains(where: { key.contains(compareKey($0)) }) {
            return entry.emoji
        }
        return defaultEmoji
    }

    /// Treffer für das Suchfeld: Teilstring, ohne Groß-/Kleinschreibung und Akzente. Leere
    /// Suche trifft alles.
    static func matches(_ name: String, query: String) -> Bool {
        let q = compareKey(query)
        return q.isEmpty || compareKey(name).contains(q)
    }

    /// Lebende eigene Kategorien, alphabetisch.
    static func activeNames(_ entries: [String: CustomCategoryEntry]) -> [String] {
        entries.filter { !$0.value.isDeleted }.keys
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// Abgleich zweier Stände (geteilte Läden): pro Name gewinnt der spätere Eintrag, auch ein
    /// Löschvermerk. Namen, die nur eine Seite kennt, bleiben erhalten.
    static func merge(
        local: [String: CustomCategoryEntry],
        remote: [String: CustomCategoryEntry]
    ) -> [String: CustomCategoryEntry] {
        var merged = remote
        for (name, entry) in local {
            if let other = merged[name], other.date > entry.date { continue }
            merged[name] = entry
        }
        return merged
    }

    /// Zuordnungen abgleichen: pro Artikelschlüssel gewinnt der spätere Stand, auch „vergessen“.
    /// Bei gleichem Zeitpunkt bleibt der lokale Stand (wie bei `merge`).
    static func mergeAssignments(
        local: [String: CategoryAssignmentEntry],
        remote: [String: CategoryAssignmentEntry]
    ) -> [String: CategoryAssignmentEntry] {
        var merged = remote
        for (key, entry) in local {
            if let other = merged[key], other.date > entry.date { continue }
            merged[key] = entry
        }
        return merged
    }
}

// MARK: - Laden-Stationen („Gänge“, Issue #234)

/// Ein Gang eines Ladens: Name (Identität), Emoji, zugeordnete feste Kategorien (Rohwerte aus
/// `AssignmentService.categoryOrder`) und Stichwörter (einzelne Wörter, „gleich oder endet auf“).
struct Station: Codable, Equatable {
    var name: String
    var emoji: String
    var builtIns: [String]
    var keywords: [String]
}

/// Geordnete Gänge eines Ladens. `hidden`: ausgeblendete feste Kategorien (treffen nie einen
/// Gang). `date`: letzte Änderung (für den Abgleich geteilter Läden in D3).
struct StationConfig: Codable, Equatable {
    var stations: [Station]
    var hidden: [String]
    var date: Date
}

extension StoreCategories {
    /// Gemerkte Wahl „Sonstiges“: Private-Use-Zeichen am Anfang, kein gültiger Name, steht nie in
    /// `ShoppingItem.category`.
    static let otherStationMarker = "\u{E000}other"

    /// Namen, die „Sonstiges“ meinen und deshalb nie ein Gang werden.
    private static let otherStationNames = ["Sonstiges", "Other"]

    /// Gang eines Artikels (`nil` = Sonstiges). Erste zutreffende Stufe gewinnt: Merkung, von Hand
    /// gesetzte Kategorie, Stichwort, automatische Kategorie aus dem Namen.
    static func station(
        forItemNamed name: String,
        category: String,
        manuallySet: Bool,
        remembered: String?,
        config: StationConfig
    ) -> String? {
        if let remembered {
            if remembered == otherStationMarker { return nil }
            if let match = stationNamed(remembered, in: config) { return match }
        }
        if manuallySet, let match = stationForCategory(category, in: config) { return match }
        if let match = stationForKeywords(in: name, config: config) { return match }
        return stationForCategory(AssignmentService.category(for: name), in: config)
    }

    /// Gang mit diesem Namen (Vergleich über `compareKey`), in der gespeicherten Schreibweise.
    static func stationNamed(_ name: String, in config: StationConfig) -> String? {
        let key = compareKey(name)
        return config.stations.first { compareKey($0.name) == key }?.name
    }

    /// Gang für eine Kategorie: Gang gleichen Namens, sonst der Gang, dessen `builtIns` die
    /// (nicht ausgeblendete) feste Kategorie enthalten.
    private static func stationForCategory(_ category: String, in config: StationConfig) -> String? {
        if let match = stationNamed(category, in: config) { return match }
        guard !config.hidden.contains(category) else { return nil }
        return config.stations.first { $0.builtIns.contains(category) }?.name
    }

    /// Längstes Stichwort, dem ein Wort des Namens gleicht oder auf das es endet; bei
    /// Gleichstand der frühere Gang.
    private static func stationForKeywords(in name: String, config: StationConfig) -> String? {
        let words = compareKey(name).lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        var best: (length: Int, station: String)?
        for station in config.stations {
            for keyword in station.keywords {
                let key = compareKey(keyword).lowercased()
                guard !key.isEmpty, words.contains(where: { $0.hasSuffix(key) }) else { continue }
                if key.count > (best?.length ?? 0) { best = (key.count, station.name) }
            }
        }
        return best?.station
    }

    enum StationResolution: Equatable {
        /// Vorhandener Gang (gespeicherte Schreibweise).
        case existing(String)
        /// „Sonstiges“.
        case other
        /// Neu anzulegen, mit diesem Namen.
        case new(String)
        /// Leer oder die Marke.
        case invalid
    }

    /// Was aus einer Eingabe im Suchfeld der Auswahl eines Ladens mit Gängen wird. Aufgelöst
    /// wird nur gegen Gang-Namen, nicht gegen feste Kategorien.
    static func resolveStation(_ input: String, config: StationConfig) -> StationResolution {
        let name = normalizedName(input)
        guard !name.isEmpty, !name.contains("\u{E000}") else { return .invalid }
        let key = compareKey(name)
        if otherStationNames.contains(where: { compareKey($0) == key }) { return .other }
        if let match = stationNamed(name, in: config) { return .existing(match) }
        return .new(name)
    }
}

// MARK: - Lidl-Vorlage (Issue #234, Spec-Tabelle „Lidl-Vorlage“)

extension StoreCategories {
    /// Gänge eines Lidl-Markts in Laufreihenfolge. „Lebensmittel“ steht bewusst in keinem Gang
    /// (Rückfall für Unerkanntes → Sonstiges). Längere Stichwörter („bratwurst“, „leberkäse“,
    /// „hustensaft“, „eistee“) schlagen die kürzeren anderer Gänge.
    static let lidlTemplate = StationConfig(
        stations: [
            Station(name: "Obst & Gemüse", emoji: "🥦", builtIns: ["Obst & Gemüse"], keywords: []),
            Station(name: "Frische Säfte, Salate, gekühlte Getränke", emoji: "🥗", builtIns: [],
                    keywords: ["saft", "smoothie", "eistee", "salatbox", "nudelsalat", "kartoffelsalat",
                               "wurstsalat", "fleischsalat", "krautsalat", "eiersalat"]),
            Station(name: "Nüsse, Süßigkeiten, Kaffee, Tee", emoji: "☕️", builtIns: ["Snacks"],
                    keywords: ["kaffee", "tee", "espresso", "cappuccino", "nüsse", "mandeln", "schokolade"]),
            Station(name: "Brot & Backwaren", emoji: "🥖", builtIns: ["Backwaren"], keywords: []),
            Station(name: "Konserven & Gewürze", emoji: "🥫", builtIns: ["Konserven", "Gewürze & Backen"], keywords: []),
            Station(name: "Frisches Fleisch & Fisch", emoji: "🥩", builtIns: ["Fleisch & Wurst"],
                    keywords: ["fisch", "lachs", "forelle", "garnelen", "bratwurst", "hackfleisch",
                               "hähnchen", "steak", "schnitzel"]),
            Station(name: "Kühltheke Fertiges", emoji: "🧊", builtIns: [],
                    keywords: ["wurst", "würstchen", "salami", "schinken", "aufschnitt", "leberkäse", "tofu",
                               "hummus", "dip", "tzatziki", "matjes", "maultaschen"]),
            Station(name: "Käse", emoji: "🧀", builtIns: [],
                    keywords: ["käse", "gouda", "edamer", "emmentaler", "mozzarella", "feta", "parmesan",
                               "camembert", "brie", "gorgonzola", "halloumi"]),
            Station(name: "Milchprodukte", emoji: "🥛", builtIns: ["Milchprodukte"], keywords: ["eier", "margarine"]),
            Station(name: "Tiefkühl", emoji: "❄️", builtIns: ["Tiefkühlkost"],
                    keywords: ["fischstäbchen", "pommes", "pizza", "eiscreme", "speiseeis", "nuggets"]),
            Station(name: "Drogerie", emoji: "🧴",
                    builtIns: ["Körperpflege", "Haarpflege", "Zahnpflege", "Kosmetik", "Hygieneartikel",
                               "Reinigung", "Medikamente", "Babybedarf"],
                    keywords: ["hustensaft"]),
            Station(name: "Getränke", emoji: "🥤", builtIns: ["Getränke"], keywords: []),
        ],
        hidden: ["Werkzeug", "Eisenwaren", "Garten", "Pflanzen", "Farbe & Lack", "Sanitär",
                 "Boden & Fliesen", "Holz", "Baumaterial"],
        date: Date(timeIntervalSince1970: 0)
    )
}
