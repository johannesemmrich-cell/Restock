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
        (["drogerie", "pflege", "kosmetik"], "🧴"),
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
