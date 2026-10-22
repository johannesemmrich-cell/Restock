import Foundation

/// Ein Eintrag des Preiskatalogs (Issue #162): typische Packung und Preisspanne eines Artikels im
/// deutschen Supermarkt- und Drogeriealltag. `names` sind kleingeschriebene Namen/Varianten, die
/// `PriceCatalog.match` nur an Wortgrenzen (bzw. als Grundwort eines Kompositums) trifft — nie als
/// beliebiger Teilstring („Tomatenmark" ist nicht „Tomaten", „Teelicht" nicht „Tee", Issue #160).
struct PriceCatalogEntry: Equatable {
    /// Kleingeschriebene Namen und Varianten; mehrwortige Namen mit einfachem Leerzeichen.
    let names: [String]
    /// Typische Packungsgröße in `packageUnit`.
    let packageAmount: Double
    /// `"g"`, `"ml"` oder `"stk"`. Ein `"stk"`-Eintrag ist ein Stück-/Packungspreis; wird er auf
    /// eine Gewichts- oder Volumenmenge angewendet, gilt `typical` wie bisher als Preis je kg/l.
    let packageUnit: String
    /// Preisspanne je Packung in Euro: untere Grenze, typischer Wert, obere Grenze.
    let low: Double
    let typical: Double
    let high: Double
    /// Herkunft des Wertes, je Eintrag ausgewiesen: `"hand-<JJJJ-MM>"` (handgepflegt) oder
    /// `"openprices-de-<JJJJ-MM>"` (Median aus dem Open-Prices-Datensatz, Deutschland), siehe
    /// `scripts/build-price-catalog.py` (Issue #162).
    let source: String

    /// Art der Quelle (`"hand"`, `"openprices-de"`) und Stichtag (`"JJJJ-MM"`), aus `source`:
    /// die letzten beiden Bindestrich-Teile sind der Stichtag, der Rest die Art.
    var sourceKind: String {
        let parts = source.split(separator: "-")
        return parts.count >= 3 ? parts.dropLast(2).joined(separator: "-") : source
    }
    var sourceDate: String {
        let parts = source.split(separator: "-")
        return parts.count >= 3 ? parts.suffix(2).joined(separator: "-") : ""
    }
}

/// Anzeige des Katalogeintrags im Bearbeiten-Sheet (Issue #162): typische Packung, Spanne und
/// Quelle mit Stichtag. Reine Funktion, damit `PriceCatalogDataTests` den Text prüfen kann.
enum PriceCatalogDisplay {
    static func summary(forName name: String, locale: Locale = .current) -> String? {
        guard let entry = PriceCatalog.match(name) else { return nil }
        return summary(for: entry, locale: locale)
    }

    static func summary(for entry: PriceCatalogEntry, locale: Locale = .current) -> String {
        let euro = FloatingPointFormatStyle<Double>.Currency(code: "EUR", locale: locale).precision(.fractionLength(2))
        let package: String
        if entry.packageUnit == "stk" {
            package = String(localized: "price.catalog.package.piece")
        } else {
            let amount = entry.packageAmount.formatted(.number.locale(locale).precision(.fractionLength(0...1)))
            package = "\(amount) \(entry.packageUnit)"
        }
        return String(format: String(localized: "price.catalog.summary"),
                      package,
                      entry.typical.formatted(euro),
                      entry.low.formatted(euro),
                      entry.high.formatted(euro),
                      sourceText(for: entry))
    }

    /// „handgepflegt 10/2026“ bzw. „Open Prices DE 10/2026“; unbekannte Quellen roh.
    static func sourceText(for entry: PriceCatalogEntry) -> String {
        let date = displayDate(entry.sourceDate)
        switch entry.sourceKind {
        case "hand": return String(format: String(localized: "price.catalog.source.hand"), date)
        case "openprices-de": return String(format: String(localized: "price.catalog.source.openprices"), date)
        default: return entry.source
        }
    }

    /// `"2026-10"` → `"10/2026"`; anderes unverändert.
    static func displayDate(_ raw: String) -> String {
        let parts = raw.split(separator: "-")
        guard parts.count == 2, parts[0].count == 4, parts[1].count == 2 else { return raw }
        return "\(parts[1])/\(parts[0])"
    }

    static var allLocalizationKeys: [String] {
        ["price.catalog.summary", "price.catalog.package.piece", "price.catalog.source.hand", "price.catalog.source.openprices"]
    }
}

/// Katalog typischer Preise, Stufe zwischen eigenen/Community-Preisen und der Kategorie-Pauschale.
/// Werte handgepflegt (Stand `asOf`), gerundet auf übliche Regalpreise; ein Treffer wird als
/// „ca. … € · Schätzung" angezeigt, die Kategorie-Pauschale dagegen nicht mehr als Artikelpreis.
enum PriceCatalog {
    static let asOf = "2026-10"
    static let handSource = "hand-2026-10"

    // MARK: - Treffer

    /// Buchstabenfolgen des Namens, kleingeschrieben; Ziffern, Satzzeichen und Bindestriche
    /// trennen („H-Milch 1,5%" → ["h", "milch"], „500g Hackfleisch" → ["g", "hackfleisch"]).
    static func tokens(in name: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        for scalar in name.lowercased().unicodeScalars {
            if CharacterSet.letters.contains(scalar) {
                current.unicodeScalars.append(scalar)
            } else if !current.isEmpty {
                tokens.append(current)
                current = ""
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    // MARK: Mehrzahl (PO 2026-10-22)

    /// Kürzester Wortstamm, der nach Abtrennen einer Pluralendung übrig bleiben muss. Vier statt
    /// drei, damit „Eisen" nicht über „eis" und „Tees" nicht über „tee" laufen; kurze Namen
    /// brauchen ihre Mehrzahl als eigenen Namen.
    static let minimumPluralStemLength = 4

    /// Wortenden, die wie eine reguläre Mehrzahl aussehen, aber keine sind: „Reise"/„Urlaubsreise"
    /// ist nicht „Reis" + e, „Strohballen" nicht die Mehrzahl von „Ball", „Hacke" kein „Hack" + e.
    /// Gefunden beim Abgleich mit einer deutschen Wortliste (siehe `docs/specs/models/price-catalog-expansion.md`).
    static let nonPluralEndings: [String] = ["reise", "reisen", "ballen", "hacke", "hacken"]

    /// Mögliche Singularformen nach den regulären deutschen Pluralendungen -en, -n, -s, -e
    /// („Joghurts" → „joghurt", „Bananen" → „banane"/„banan", „Weine" → „wein"). Umlaut-Plurale
    /// („Äpfel", „Schläuche") folgen keiner Regel und stehen als eigene Namen im Katalog.
    static func singularCandidates(of word: String) -> [String] {
        guard !nonPluralEndings.contains(where: { word.hasSuffix($0) }) else { return [] }
        var result: [String] = []
        func strip(_ count: Int) {
            guard word.count - count >= minimumPluralStemLength else { return }
            result.append(String(word.dropLast(count)))
        }
        if word.hasSuffix("en") { strip(2) }
        if word.hasSuffix("n") || word.hasSuffix("s") || word.hasSuffix("e") { strip(1) }
        return result
    }

    // MARK: Grundwort eines Kompositums

    /// Gesperrte Wortenden: Endet ein Wort auf eines davon, gilt ein darin enthaltener kürzerer
    /// Katalogname nicht als Grundwort („Fahrradschlauch" ist kein „Lauch", „Schwein" kein
    /// „Wein", „Kaufpreis" kein „Reis", „Geburtstagsfeier" keine „Eier", „Panorama" keine „Rama").
    /// Bewusst eine kurze, nachprüfbare Liste statt einer Silbenanalyse: Die Grundwort-Regel
    /// selbst bleibt unverändert (Laugenbrötchen → brötchen), nur diese bekannten Wörter, deren
    /// Ende zufällig ein Katalogname ist, sind ausgenommen. Steht das längere Wort selbst im
    /// Katalog („fahrradschlauch"), gewinnt es ohnehin als längster Name.
    static let blockedHeadEndings: [String] = [
        "schlauch", "schwein", "preis", "kreis", "greis", "feier", "schleier", "geier",
        "panorama", "diorama", "drama", "krawatte", "insekt", "stopfen", "lawine", "schicken", "barbier",
        "stabs", "heimer",
    ]

    /// Ein einzelnes Wort trifft einen Katalognamen, wenn es ihm gleicht oder der Name sein
    /// Grundwort ist: Name mindestens 4 Zeichen, davor ein Bestimmungswort von mindestens 3
    /// Zeichen, und das Wort endet auf keine gesperrte Endung, die den Namen enthält.
    static func wordMatches(key: String, word: String) -> Bool {
        if word == key { return true }
        guard key.count >= 4, word.count - key.count >= 3, word.hasSuffix(key) else { return false }
        return !blockedHeadEndings.contains { blocked in
            blocked.count > key.count && blocked.hasSuffix(key) && word.hasSuffix(blocked)
        }
    }

    /// Die Wörter des Namens samt ihrer möglichen Singularformen, einmal je Name berechnet
    /// („Erdbeerjoghurts" → ["erdbeerjoghurts", "erdbeerjoghurt"]).
    static func wordForms(of words: [String]) -> [String] {
        words.flatMap { [$0] + singularCandidates(of: $0) }
    }

    /// Ein Katalogname trifft, wenn er ein ganzes Wort des Artikelnamens ist, das Grundwort eines
    /// Kompositums („Laugenbrötchen" → „brötchen", „Kartoffelchips" → „chips") oder eines davon
    /// nach Abtrennen einer regulären Pluralendung („Joghurts" → „joghurt", „Erdbeerjoghurts" →
    /// „joghurt"); `forms` kommt aus `wordForms(of:)`. Mehrwortige Namen müssen als ganze
    /// Wortfolge vorkommen (ohne Mehrzahl-Regel).
    static func matches(key: String, forms: [String], padded: String) -> Bool {
        if key.contains(" ") { return padded.contains(" \(key) ") }
        return forms.contains { wordMatches(key: key, word: $0) }
    }

    /// Bester Eintrag für einen Artikelnamen: bei mehreren Treffern gewinnt der längste Name
    /// („Hafermilch" vor „Milch", „Tomatenmark" vor „Tomaten"), bei gleicher Länge der frühere.
    /// Ohne jeden solchen Treffer greift als letzte Stufe die Tippfehler-Toleranz (`typoMatch`).
    static func match(_ name: String) -> PriceCatalogEntry? {
        let words = tokens(in: name)
        guard !words.isEmpty else { return nil }
        let padded = " " + words.joined(separator: " ") + " "
        let forms = wordForms(of: words)
        var best: (entry: PriceCatalogEntry, length: Int)?
        for entry in entries {
            for key in entry.names where matches(key: key, forms: forms, padded: padded) {
                if let current = best, current.length >= key.count { continue }
                best = (entry, key.count)
            }
        }
        if let best { return best.entry }
        return typoMatch(words: words)
    }

    // MARK: Tippfehler (PO 2026-10-22)

    /// Tippfehler-Toleranz erst ab dieser Wortlänge (Wort und Katalogname): Kurze Wörter liegen
    /// zu oft genau einen Schritt von einem anderen echten Wort entfernt („Preis"/„Reis").
    static let minimumTypoLength = 5

    /// Ein ersetzter Buchstabe zählt erst ab dieser Wortlänge als Tippfehler. Beim Abgleich mit
    /// einer deutschen Wortliste waren Ersetzungen in Wörtern mit 5–6 Buchstaben fast nur echte
    /// andere Wörter („Seite" → Seife, „Biene" → Birne, „Bahnen" → Bohnen), Einfügen/Löschen
    /// dagegen meist Einzahl/Mehrzahl oder echte Tippfehler („Jogurt", „Kondom", „Banan").
    static let minimumSubstitutionTypoLength = 7

    private struct TypoCandidate {
        let characters: [Character]
        let entryIndex: Int
    }

    /// Einwortige Katalognamen ab `minimumTypoLength` Zeichen, einmal vorberechnet.
    private static let typoCandidates: [TypoCandidate] = PriceCatalog.entries.enumerated().flatMap { pair -> [TypoCandidate] in
        pair.element.names
            .filter { !$0.contains(" ") && $0.count >= PriceCatalog.minimumTypoLength }
            .map { TypoCandidate(characters: Array($0), entryIndex: pair.offset) }
    }

    /// Letzte Stufe, nur wenn kein Name exakt, als Grundwort oder als Mehrzahl trifft: ein Wort ab
    /// 5 Buchstaben, das genau einen Bearbeitungsschritt (Einfügen, Löschen, Vertauschen zweier
    /// Nachbarn; Ersetzen erst ab `minimumSubstitutionTypoLength`) von einem Katalognamen ab 5
    /// Buchstaben entfernt ist und mit demselben Buchstaben beginnt („Banan" → Banane, „Tomatn" →
    /// Tomaten). Eindeutig heißt: Alle solchen Kandidaten aller Wörter gehören zu genau einem
    /// Eintrag, sonst kein Treffer.
    static func typoMatch(words: [String]) -> PriceCatalogEntry? {
        var found: Int?
        for word in words where word.count >= minimumTypoLength {
            let characters = Array(word)
            let allowsSubstitution = characters.count >= minimumSubstitutionTypoLength
            for candidate in typoCandidates
            where candidate.characters.first == characters.first
                && abs(candidate.characters.count - characters.count) <= 1
                && isOneEditApart(characters, candidate.characters, allowingSubstitution: allowsSubstitution) {
                if let found, found != candidate.entryIndex { return nil }
                found = candidate.entryIndex
            }
        }
        return found.map { entries[$0] }
    }

    /// Genau ein Bearbeitungsschritt (eingeschränkte Damerau-Levenshtein-Distanz 1); ohne
    /// `allowingSubstitution` zählt ein ersetzter Buchstabe nicht.
    static func isOneEditApart(_ a: [Character], _ b: [Character], allowingSubstitution: Bool = true) -> Bool {
        if a == b || abs(a.count - b.count) > 1 { return false }
        if a.count == b.count {
            let differences = a.indices.filter { a[$0] != b[$0] }
            if differences.count == 1 { return allowingSubstitution }
            return differences.count == 2 && differences[1] == differences[0] + 1
                && a[differences[0]] == b[differences[1]] && a[differences[1]] == b[differences[0]]
        }
        let (shorter, longer) = a.count < b.count ? (a, b) : (b, a)
        var index = 0
        while index < shorter.count && shorter[index] == longer[index] { index += 1 }
        return longer[(index + 1)...].elementsEqual(shorter[index...])
    }

    // MARK: - Umrechnung auf die Einheit des Artikels

    /// Preis je Einheit des Artikels (`ShoppingItem.estimatedPrice` ist immer eine Rate je Einheit):
    /// Stück/Packung → typischer Packungspreis; Gewicht/Volumen → Packungspreis geteilt durch die
    /// Packungsgröße in Gramm bzw. Millilitern, skaliert auf die Einheit. Ein `"stk"`-Eintrag gilt
    /// auf Gewicht angewendet als Preis je Kilogramm/Liter — bitgleich zum früheren `unitDivisor`.
    static func perUnitPrice(for entry: PriceCatalogEntry, itemUnit: String) -> Double {
        let gramsPerItemUnit: Double?
        switch itemUnit.trimmingCharacters(in: .whitespaces).lowercased() {
        case "g", "gramm", "ml", "milliliter": gramsPerItemUnit = 1
        case "mg", "milligramm": gramsPerItemUnit = 0.001
        case "cl", "zentiliter": gramsPerItemUnit = 10
        case "dl", "deziliter": gramsPerItemUnit = 100
        case "kg", "kilogramm", "kilo", "l", "liter": gramsPerItemUnit = 1000
        default: gramsPerItemUnit = nil
        }
        guard let gramsPerItemUnit else { return entry.typical }
        let packageGrams = entry.packageUnit == "stk" ? 1000 : entry.packageAmount
        if packageGrams == gramsPerItemUnit { return entry.typical }
        return entry.typical * gramsPerItemUnit / packageGrams
    }

    // MARK: - Einträge

    // Die Einträge (`legacy`, `dairy`, …, `entries`) stehen in `PriceCatalogEntries.swift`, erzeugt
    // von `scripts/build-price-catalog.py` aus `data/price-catalog/catalog.json` (Issue #162). Dort
    // ändern, nie in der Swift-Datei; `--check` ist der Drift-Test.
}
