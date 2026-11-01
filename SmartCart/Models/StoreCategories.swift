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
        // Emoji des Lidl-Gangs „Frische Säfte, Salate …“ (jede Vorlage nutzt nur Emojis der Auswahl).
        "🥗",
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

// MARK: - Gänge einrichten (Issue #234, Durchgang 2a, `docs/specs/views/station-setup.md`)

extension StoreCategories {
    /// Zustand einer festen Kategorie in einem Laden mit Gängen. Kein viertes, stilles Feld:
    /// zugeordnet (in `builtIns` eines Gangs oder Name eines Gangs), ausgeblendet, offen.
    enum CategoryState: Equatable {
        case assigned(String)
        case hidden
        case open
    }

    /// Zustand in derselben Reihenfolge wie `stationForCategory`: Gang gleichen Namens, `hidden`,
    /// `builtIns`, sonst offen.
    static func categoryState(_ category: String, in config: StationConfig) -> CategoryState {
        if let bound = stationNamed(category, in: config) { return .assigned(bound) }
        if config.hidden.contains(category) { return .hidden }
        if let station = config.stations.first(where: { $0.builtIns.contains(category) }) { return .assigned(station.name) }
        return .open
    }

    /// Feste Kategorie (Rohwert), deren Namen `name` trägt.
    static func builtInCategory(named name: String) -> String? {
        let key = compareKey(name)
        return AssignmentService.categoryOrder.first { compareKey($0) == key }
    }

    /// Neuer Gang am Ende. `nil`, wenn der Name leer, die Marke, „Sonstiges“/„Other“ oder schon
    /// ein Gang ist. Trägt er den Namen einer festen Kategorie, übernimmt er sie.
    static func addingStation(_ input: String, emoji: String, to config: StationConfig) -> StationConfig? {
        guard case .new(let name) = resolveStation(input, config: config) else { return nil }
        var config = config
        config.stations.append(Station(name: name, emoji: emoji, builtIns: [], keywords: []))
        return adopting(builtInCategory(named: name), into: config.stations.count - 1, config)
    }

    /// Gang umbenennen und Emoji setzen. Erlaubt: neuer Name oder nur andere Schreibweise des
    /// eigenen. `builtIns` und `keywords` bleiben; nie zusammengeführt.
    static func renamingStation(_ old: String, to input: String, emoji: String, in config: StationConfig) -> StationConfig? {
        guard let index = stationIndex(old, in: config) else { return nil }
        let name: String
        switch resolveStation(input, config: config) {
        case .new(let new): name = new
        case .existing(let same) where same == config.stations[index].name: name = normalizedName(input)
        default: return nil
        }
        var config = config
        config.stations[index].name = name
        config.stations[index].emoji = emoji
        return adopting(builtInCategory(named: name), into: index, config)
    }

    /// Gänge umordnen wie `Array.move(fromOffsets:toOffset:)` (ohne SwiftUI, Datei läuft auch im
    /// Widget und in der Teilen-Erweiterung).
    static func movingStations(from source: IndexSet, to destination: Int, in config: StationConfig) -> StationConfig {
        var stations = config.stations
        let offsets = source.filter { stations.indices.contains($0) }.sorted()
        let moving = offsets.map { stations[$0] }
        for offset in offsets.reversed() { stations.remove(at: offset) }
        let target = min(max(destination - offsets.filter { $0 < destination }.count, 0), stations.count)
        stations.insert(contentsOf: moving, at: target)
        var config = config
        config.stations = stations
        return config
    }

    /// Feste Kategorie einem Gang zuordnen (aus anderen Gängen und `hidden` gelöst). Gesperrt,
    /// wenn ein anderer Gang ihren Namen trägt.
    static func assigning(_ category: String, toStation name: String, in config: StationConfig) -> StationConfig? {
        guard AssignmentService.categoryOrder.contains(category), let index = stationIndex(name, in: config) else { return nil }
        if let bound = stationNamed(category, in: config), bound != config.stations[index].name { return nil }
        return adopting(category, into: index, config)
    }

    /// Feste Kategorie ausblenden (aus allen Gängen gelöst). Gesperrt bei Name-Bindung.
    static func hiding(_ category: String, in config: StationConfig) -> StationConfig? {
        guard var config = releasing(category, in: config) else { return nil }
        config.hidden.append(category)
        return config
    }

    /// Feste Kategorie offen machen (weder Gang noch `hidden`). Gesperrt bei Name-Bindung.
    static func opening(_ category: String, in config: StationConfig) -> StationConfig? {
        releasing(category, in: config)
    }

    /// Gang entfernen: seine festen Kategorien werden offen, Stichwörter fallen weg.
    static func deletingStation(_ name: String, in config: StationConfig) -> StationConfig? {
        guard let index = stationIndex(name, in: config) else { return nil }
        var config = config
        config.stations.remove(at: index)
        return config
    }

    // MARK: Auswahl und Übernahme (Durchgang 2b-2, `docs/specs/views/station-picker-adoption.md`)

    /// Regel R3: eigene Kategorien, die kein aktueller Gang sind, als Gang annehmbar wären und
    /// (in keiner Vorlage stehen oder genutzt sind). `used` und `templateNames` als `compareKey`s;
    /// die Reihenfolge von `custom` bleibt.
    static func adoptableCategories(custom: [String], config: StationConfig,
                                    used: Set<String>, templateNames: Set<String>) -> [String] {
        custom.filter { name in
            guard case .new = resolveStation(name, config: config) else { return false }
            let key = compareKey(name)
            return !templateNames.contains(key) || used.contains(key)
        }
    }

    /// Auswahl nach dem Umbenennen eines Gangs: war er gewählt, der neue Name, sonst unverändert.
    static func renamedSelection(_ selection: String, from old: String, to new: String) -> String {
        selection != otherStationMarker && compareKey(selection) == compareKey(old) ? new : selection
    }

    /// Eigene Wahl des Dialogs nach dem Nachziehen: ohne eigene Wahl (`nil`) bleibt es dabei, damit
    /// der Artikel der Automatik folgt und nicht als Handwahl gespeichert wird.
    static func followedChoice(_ chosen: String?, next: String) -> String? {
        chosen == nil ? nil : next
    }

    /// Auswahl nach dem Löschen des gewählten Gangs (`config` danach): ohne Gänge die automatische
    /// Kategorie, sonst der Gang der automatischen Auflösung oder die Sonstiges-Marke.
    static func selectionAfterDeleting(itemName: String, automaticCategory: String, config: StationConfig) -> String {
        guard !config.stations.isEmpty else { return automaticCategory }
        return station(forItemNamed: itemName, category: automaticCategory, manuallySet: false,
                       remembered: nil, config: config) ?? otherStationMarker
    }

    // MARK: Stichwörter (Durchgang 2b-1, `docs/specs/views/station-templates-keywords.md`)

    /// Ergebnis der Prüfung eines neuen Stichworts.
    enum KeywordCheck: Equatable {
        /// Annehmen; `others` = andere Gänge (in Gang-Reihenfolge) mit demselben Stichwort.
        case accepted(others: [String])
        /// Steht im selben Gang schon.
        case duplicate
        /// Kein einzelnes Wort aus Buchstaben/Ziffern mit mindestens 3 Zeichen, oder Gang unbekannt.
        case invalid
    }

    /// Getrimmt und klein; `nil`, wenn leer, kürzer als 3 Zeichen oder mit einem Zeichen, das kein
    /// Buchstabe und keine Ziffer ist (Leerzeichen, Bindestrich, Punkt, Marke).
    static func normalizedKeyword(_ input: String) -> String? {
        let keyword = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard keyword.count >= 3,
              keyword.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) }) else { return nil }
        return keyword
    }

    static func checkKeyword(_ input: String, inStation name: String, config: StationConfig) -> KeywordCheck {
        guard let keyword = normalizedKeyword(input), let index = stationIndex(name, in: config) else { return .invalid }
        let key = keywordKey(keyword)
        let hits = { (station: Station) in station.keywords.contains { keywordKey($0) == key } }
        if hits(config.stations[index]) { return .duplicate }
        let others = config.stations.enumerated().filter { $0.offset != index && hits($0.element) }.map(\.element.name)
        return .accepted(others: others)
    }

    /// Stichwort normalisiert am Ende anhängen; `nil` bei ungültig oder doppelt im selben Gang.
    static func addingKeyword(_ input: String, toStation name: String, in config: StationConfig) -> StationConfig? {
        guard case .accepted = checkKeyword(input, inStation: name, config: config),
              let keyword = normalizedKeyword(input), let index = stationIndex(name, in: config) else { return nil }
        var config = config
        config.stations[index].keywords.append(keyword)
        return config
    }

    /// Genau dieses Stichwort aus dem Gang entfernen; `nil`, wenn Gang oder Stichwort fehlt.
    static func removingKeyword(_ keyword: String, fromStation name: String, in config: StationConfig) -> StationConfig? {
        guard let index = stationIndex(name, in: config) else { return nil }
        let key = keywordKey(keyword)
        guard let position = config.stations[index].keywords.firstIndex(where: { keywordKey($0) == key }) else { return nil }
        var config = config
        config.stations[index].keywords.remove(at: position)
        return config
    }

    /// Vergleich wie in `stationForKeywords`.
    private static func keywordKey(_ keyword: String) -> String {
        compareKey(keyword).lowercased()
    }

    private static func stationIndex(_ name: String, in config: StationConfig) -> Int? {
        let key = compareKey(name)
        return config.stations.firstIndex { compareKey($0.name) == key }
    }

    /// Kategorie aus allen Gängen und `hidden` lösen; `nil` bei unbekannter oder name-gebundener.
    private static func releasing(_ category: String, in config: StationConfig) -> StationConfig? {
        guard AssignmentService.categoryOrder.contains(category), stationNamed(category, in: config) == nil else { return nil }
        var config = config
        for index in config.stations.indices { config.stations[index].builtIns.removeAll { $0 == category } }
        config.hidden.removeAll { $0 == category }
        return config
    }

    /// Kategorie in die `builtIns` des Gangs `index` übernehmen, ohne Doppelung.
    private static func adopting(_ category: String?, into index: Int, _ config: StationConfig) -> StationConfig {
        guard let category else { return config }
        var config = config
        for i in config.stations.indices { config.stations[i].builtIns.removeAll { $0 == category } }
        config.hidden.removeAll { $0 == category }
        config.stations[index].builtIns.append(category)
        return config
    }
}
