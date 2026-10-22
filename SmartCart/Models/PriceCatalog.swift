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
    /// Herkunft des Wertes, je Eintrag ausgewiesen (`PriceCatalog.handSource`, später auch der
    /// Open-Prices-Median, siehe #162).
    let source: String
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

    private static func e(_ names: [String], _ amount: Double, _ unit: String,
                          _ low: Double, _ typical: Double, _ high: Double) -> PriceCatalogEntry {
        PriceCatalogEntry(names: names, packageAmount: amount, packageUnit: unit,
                          low: low, typical: typical, high: high, source: handSource)
    }

    /// Die 32 Stichwörter des früheren `specificPrices` mit unveränderten Werten (Stück- bzw.
    /// Pauschalpreis je Packung/kg/l), damit bestehende Schätzungen und Tests gleich bleiben.
    static let legacy: [PriceCatalogEntry] = [
        e(["brot", "brötchen", "bread"], 1, "stk", 1.49, 2.50, 3.99),
        e(["milch", "milk"], 1, "stk", 0.99, 1.20, 1.69),
        e(["butter"], 1, "stk", 1.69, 2.20, 2.99),
        e(["eier", "eggs"], 1, "stk", 1.99, 3.00, 4.49),
        e(["käse", "cheese"], 1, "stk", 2.49, 3.50, 4.99),
        e(["joghurt", "yogurt"], 1, "stk", 0.99, 1.50, 2.29),
        e(["shampoo"], 1, "stk", 2.49, 4.50, 7.99),
        e(["duschgel", "shower gel"], 1, "stk", 1.49, 3.00, 4.99),
        e(["zahnbürste", "toothbrush"], 1, "stk", 2.49, 5.00, 8.99),
        e(["zahnpasta", "toothpaste"], 1, "stk", 1.29, 2.50, 4.49),
        e(["waschmittel", "detergent"], 1, "stk", 4.99, 8.00, 12.99),
        e(["spülmittel", "dish soap"], 1, "stk", 0.99, 1.80, 2.99),
        e(["toilettenpapier", "klopapier", "toilet paper"], 1, "stk", 2.99, 4.00, 6.49),
        e(["kaffee", "coffee"], 1, "stk", 3.99, 5.50, 8.99),
        e(["tee", "tea"], 1, "stk", 1.49, 3.00, 4.99),
        e(["wasser", "water"], 1, "stk", 0.29, 0.90, 1.49),
        e(["saft", "juice"], 1, "stk", 1.29, 2.00, 3.49),
        e(["cola", "pepsi", "fanta"], 1, "stk", 0.99, 1.50, 2.29),
        e(["chips", "crisps"], 1, "stk", 1.29, 1.80, 2.79),
        e(["schokolade", "chocolate"], 1, "stk", 0.89, 1.50, 2.99),
        e(["äpfel", "apfel", "apple", "apples"], 1, "stk", 1.99, 2.50, 3.99),
        e(["bananen", "banane", "banana"], 1, "stk", 1.29, 1.80, 2.49),
        e(["tomaten", "tomate", "tomato"], 1, "stk", 1.49, 2.00, 3.99),
        e(["kartoffeln", "kartoffel", "potato"], 1, "stk", 1.49, 2.00, 2.99),
        e(["hähnchen", "chicken"], 1, "stk", 3.49, 4.50, 6.99),
        e(["rinderhack", "hackfleisch", "ground beef"], 1, "stk", 2.99, 4.00, 5.99),
        e(["nudeln", "pasta"], 1, "stk", 0.79, 1.50, 2.49),
        e(["reis", "rice"], 1, "stk", 1.29, 2.00, 3.49),
        e(["haferflocken", "porridge", "oats"], 1, "stk", 0.99, 1.80, 2.99),
        e(["müsli", "cornflakes", "granola", "cereal"], 1, "stk", 1.79, 2.50, 3.99),
        e(["mehl", "flour"], 1, "stk", 0.69, 1.20, 1.99),
        e(["zucker", "sugar"], 1, "stk", 0.99, 1.50, 2.29),
    ]

    static let dairy: [PriceCatalogEntry] = [
        e(["mozzarella"], 125, "g", 0.79, 1.09, 1.79),
        e(["schlagsahne", "sahne", "cream", "schlagobers", "obers"], 200, "g", 0.79, 0.99, 1.39),
        e(["saure sahne", "sauerrahm"], 200, "g", 0.59, 0.79, 1.19),
        e(["schmand"], 200, "g", 0.69, 0.89, 1.29),
        e(["crème fraîche", "creme fraiche", "crème fraiche", "cremefraiche"], 150, "g", 0.79, 0.99, 1.49),
        e(["parmesan", "parmigiano"], 200, "g", 2.99, 3.99, 5.49),
        e(["grana padano", "grana"], 200, "g", 2.49, 3.29, 4.49),
        e(["gouda", "gauda"], 400, "g", 2.99, 3.79, 4.99),
        e(["emmentaler"], 400, "g", 2.99, 3.99, 4.99),
        e(["edamer", "tilsiter", "butterkäse", "maasdamer"], 400, "g", 2.79, 3.49, 4.49),
        e(["bergkäse", "cheddar"], 300, "g", 3.49, 4.49, 5.99),
        e(["camembert"], 250, "g", 1.69, 2.29, 3.49),
        e(["brie"], 200, "g", 1.79, 2.29, 3.49),
        e(["feta", "schafskäse", "hirtenkäse"], 200, "g", 1.29, 1.99, 2.99),
        e(["frischkäse", "philadelphia", "bresso", "almette"], 200, "g", 0.99, 1.49, 2.29),
        e(["hüttenkäse", "körniger frischkäse"], 200, "g", 0.99, 1.29, 1.79),
        e(["quark", "magerquark", "speisequark", "topfen"], 500, "g", 0.89, 1.19, 1.79),
        e(["skyr"], 450, "g", 1.29, 1.69, 2.29),
        e(["naturjoghurt", "fruchtjoghurt", "griechischer joghurt"], 500, "g", 0.89, 1.19, 1.79),
        e(["buttermilch"], 500, "ml", 0.59, 0.79, 1.19),
        e(["vollmilch", "frischmilch"], 1000, "ml", 0.99, 1.19, 1.59),
        e(["hafermilch", "haferdrink", "oatly"], 1000, "ml", 1.19, 1.69, 2.49),
        e(["mandelmilch", "mandeldrink"], 1000, "ml", 1.49, 1.99, 2.79),
        e(["sojamilch", "sojadrink", "alpro"], 1000, "ml", 0.99, 1.49, 2.19),
        e(["kokosmilch"], 400, "ml", 0.99, 1.39, 2.19),
        e(["kondensmilch", "kaffeesahne"], 340, "g", 0.79, 1.09, 1.59),
        e(["margarine", "rama", "lätta", "becel", "sanella"], 500, "g", 1.19, 1.69, 2.49),
        e(["pudding", "grießpudding"], 500, "g", 0.99, 1.49, 1.99),
        e(["mascarpone"], 250, "g", 1.49, 1.99, 2.79),
        e(["ricotta"], 250, "g", 1.29, 1.79, 2.49),
        e(["halloumi", "grillkäse"], 225, "g", 1.99, 2.79, 3.99),
        e(["milchreis"], 400, "g", 0.79, 1.19, 1.69),
        e(["eis", "speiseeis", "ice cream"], 500, "ml", 1.99, 2.99, 4.99),
        e(["tofu"], 200, "g", 1.29, 1.79, 2.49),
        e(["seitan"], 200, "g", 1.99, 2.49, 3.49),
    ]

    static let meatAndFish: [PriceCatalogEntry] = [
        e(["hähnchenbrust", "hähnchenbrustfilet", "hähnchenfilet"], 500, "g", 3.99, 5.49, 7.99),
        e(["hähnchenschenkel", "hähnchenkeulen"], 1000, "g", 3.49, 4.49, 6.49),
        e(["putenbrust", "putenschnitzel", "putenfilet", "pute"], 500, "g", 4.49, 5.99, 8.49),
        e(["schnitzel", "schweineschnitzel", "kotelett"], 500, "g", 3.49, 4.99, 6.99),
        e(["steak", "rindersteak", "hüftsteak", "rumpsteak"], 250, "g", 4.49, 5.99, 8.99),
        e(["rinderfilet", "filet"], 250, "g", 7.99, 10.99, 14.99),
        e(["gulasch", "rindergulasch", "braten", "schweinebraten"], 500, "g", 4.99, 6.49, 8.99),
        e(["bratwurst", "bratwürste", "rostbratwurst"], 500, "g", 2.49, 3.49, 4.99),
        e(["wiener", "wiener würstchen", "würstchen", "bockwurst"], 250, "g", 1.49, 1.99, 2.99),
        e(["salami"], 100, "g", 1.29, 1.79, 2.79),
        e(["schinken", "kochschinken", "putenschinken"], 100, "g", 1.29, 1.79, 2.49),
        e(["lachsschinken", "serrano", "parmaschinken", "prosciutto"], 100, "g", 1.99, 2.49, 3.49),
        e(["speck", "bacon", "frühstücksspeck"], 150, "g", 1.49, 1.99, 2.99),
        e(["leberwurst", "teewurst", "mettwurst"], 125, "g", 0.99, 1.49, 2.29),
        e(["mortadella", "lyoner", "fleischwurst", "aufschnitt", "wurst"], 200, "g", 1.29, 1.79, 2.49),
        e(["lachs", "lachsfilet"], 250, "g", 4.49, 5.99, 8.99),
        e(["räucherlachs"], 100, "g", 2.49, 3.49, 4.99),
        e(["thunfisch"], 150, "g", 1.29, 1.79, 2.49),
        e(["fischstäbchen"], 450, "g", 2.49, 3.29, 4.49),
        e(["garnelen", "shrimps"], 250, "g", 4.49, 5.99, 8.99),
        e(["forelle", "kabeljau", "seelachs", "fisch", "fischfilet", "scholle", "dorsch", "rotbarsch"], 300, "g", 3.49, 4.49, 6.49),
        e(["hering", "matjes", "bismarckhering"], 200, "g", 1.99, 2.79, 3.99),
        e(["sardinen", "makrele"], 125, "g", 1.29, 1.79, 2.49),
    ]

    static let produce: [PriceCatalogEntry] = [
        e(["zwiebeln", "zwiebel", "rote zwiebeln"], 1000, "g", 0.99, 1.49, 2.29),
        e(["knoblauch"], 1, "stk", 0.39, 0.59, 0.99),
        e(["gurke", "salatgurke", "gurken"], 1, "stk", 0.59, 0.89, 1.49),
        e(["paprika", "spitzpaprika"], 1000, "g", 2.99, 3.49, 4.99),
        e(["karotten", "möhren", "karotte", "möhre"], 1000, "g", 0.99, 1.29, 1.99),
        e(["süßkartoffeln", "süßkartoffel"], 1000, "g", 1.99, 2.49, 3.49),
        e(["champignons", "pilze", "champignon"], 250, "g", 1.29, 1.69, 2.49),
        e(["brokkoli", "broccoli"], 1, "stk", 0.99, 1.49, 2.29),
        e(["blumenkohl", "karfiol"], 1, "stk", 1.49, 2.29, 3.29),
        e(["zucchini"], 1000, "g", 1.99, 2.49, 3.49),
        e(["aubergine"], 1, "stk", 0.99, 1.29, 1.99),
        e(["avocado", "avocados"], 1, "stk", 0.89, 1.29, 1.99),
        e(["salat", "kopfsalat", "eisbergsalat", "römersalat"], 1, "stk", 0.99, 1.29, 1.99),
        e(["feldsalat", "rucola", "babyspinat"], 100, "g", 1.29, 1.79, 2.49),
        e(["spinat", "blattspinat"], 500, "g", 1.49, 1.99, 2.99),
        e(["lauch", "porree"], 1000, "g", 1.99, 2.49, 3.49),
        e(["kohlrabi"], 1, "stk", 0.69, 0.99, 1.49),
        e(["rote bete", "rote beete"], 500, "g", 0.99, 1.29, 1.99),
        e(["ingwer"], 100, "g", 0.49, 0.69, 0.99),
        e(["zitrone", "zitronen"], 1, "stk", 0.39, 0.49, 0.79),
        e(["limette", "limetten"], 1, "stk", 0.29, 0.39, 0.69),
        e(["orangen", "orange"], 1000, "g", 1.99, 2.49, 3.49),
        e(["mandarinen", "clementinen", "mandarine", "clementine"], 1000, "g", 1.99, 2.49, 3.49),
        e(["trauben", "weintrauben", "traube", "weintraube"], 500, "g", 1.99, 2.49, 3.49),
        e(["erdbeeren", "erdbeere"], 500, "g", 2.49, 3.49, 4.99),
        e(["himbeeren", "heidelbeeren", "blaubeeren", "brombeeren", "beeren", "himbeere", "heidelbeere", "blaubeere", "brombeere", "beere", "johannisbeeren", "johannisbeere", "stachelbeeren", "stachelbeere"], 125, "g", 1.99, 2.49, 3.49),
        e(["birnen", "birne"], 1000, "g", 1.99, 2.49, 3.49),
        e(["pflaumen", "zwetschgen", "pflaume", "zwetschge", "mirabellen"], 500, "g", 1.49, 1.99, 2.99),
        e(["kirschen", "kirsche"], 500, "g", 2.99, 3.99, 5.99),
        e(["pfirsiche", "nektarinen", "pfirsich", "nektarine", "aprikosen", "aprikose", "marillen", "marille"], 1000, "g", 2.49, 2.99, 3.99),
        e(["mango"], 1, "stk", 0.99, 1.49, 2.29),
        e(["ananas"], 1, "stk", 1.49, 1.99, 2.99),
        e(["melone", "wassermelone"], 1, "stk", 2.49, 3.49, 4.99),
        e(["honigmelone", "galiamelone"], 1, "stk", 1.99, 2.49, 3.49),
        e(["kiwi", "kiwis"], 1, "stk", 0.39, 0.49, 0.79),
        e(["petersilie", "schnittlauch", "basilikum", "dill", "koriander", "minze", "kräuter"], 1, "stk", 0.69, 0.99, 1.49),
        e(["frühlingszwiebeln", "lauchzwiebeln"], 1, "stk", 0.69, 0.89, 1.29),
        e(["sellerie", "staudensellerie"], 1, "stk", 1.29, 1.69, 2.49),
        e(["fenchel"], 1000, "g", 2.49, 2.99, 3.99),
        e(["spargel"], 500, "g", 3.99, 5.49, 7.99),
        e(["kürbis", "hokkaido"], 1000, "g", 1.49, 1.99, 2.99),
        e(["radieschen"], 1, "stk", 0.59, 0.79, 1.19),
        e(["rotkohl", "weißkohl", "wirsing", "spitzkohl", "kohl"], 1, "stk", 1.29, 1.79, 2.49),
        e(["rosenkohl", "grünkohl"], 500, "g", 1.49, 1.99, 2.99),
        e(["bohnen", "grüne bohnen"], 500, "g", 1.99, 2.49, 3.49),
        e(["mais", "maiskolben"], 285, "g", 0.69, 0.99, 1.49),
    ]

    static let bakery: [PriceCatalogEntry] = [
        e(["toast", "toastbrot", "sandwichtoast"], 500, "g", 0.99, 1.39, 1.99),
        e(["vollkornbrot", "roggenbrot", "mischbrot", "dinkelbrot", "bauernbrot"], 500, "g", 1.49, 2.19, 3.29),
        e(["croissant", "croissants"], 1, "stk", 0.59, 0.89, 1.49),
        e(["baguette"], 1, "stk", 0.89, 1.29, 1.99),
        e(["brezel", "laugenbrezel", "brezn"], 1, "stk", 0.49, 0.79, 1.19),
        e(["knäckebrot"], 250, "g", 1.29, 1.69, 2.29),
        e(["zwieback"], 225, "g", 1.29, 1.69, 2.29),
        e(["kuchen", "cake", "torte"], 1, "stk", 2.99, 3.99, 5.99),
        e(["tortilla", "tortillas", "wraps", "wrap"], 1, "stk", 1.49, 1.99, 2.69),
        e(["pita", "fladenbrot"], 1, "stk", 0.99, 1.29, 1.99),
    ]

    static let drinks: [PriceCatalogEntry] = [
        e(["bier", "beer", "pils", "weizen", "radler", "becks", "krombacher", "warsteiner", "bitburger", "veltins", "radeberger", "jever", "erdinger", "augustiner"], 500, "ml", 0.69, 0.99, 1.49),
        e(["wein", "rotwein", "weißwein", "weisswein", "rosé", "rose", "wine"], 750, "ml", 3.49, 4.99, 8.99),
        e(["sekt", "prosecco", "champagner", "rotkäppchen", "freixenet"], 750, "ml", 3.49, 4.99, 8.99),
        e(["apfelsaft", "orangensaft", "multivitaminsaft", "traubensaft"], 1000, "ml", 1.29, 1.79, 2.79),
        e(["apfelschorle", "schorle"], 1000, "ml", 0.79, 1.09, 1.59),
        e(["limonade", "limo", "sprite", "zitronenlimonade"], 1000, "ml", 0.79, 1.19, 1.79),
        e(["mineralwasser", "sprudel", "sprudelwasser", "stilles wasser", "gerolsteiner", "volvic", "evian", "vittel", "selters"], 1000, "ml", 0.29, 0.49, 0.89),
        e(["eistee", "ice tea", "icetea"], 1500, "ml", 0.99, 1.49, 1.99),
        e(["energy drink", "energydrink", "red bull"], 250, "ml", 0.89, 1.29, 1.69),
        e(["kakao", "kakaopulver", "trinkschokolade"], 500, "g", 2.49, 3.49, 4.99),
        e(["espresso", "kaffeebohnen", "filterkaffee"], 500, "g", 4.99, 6.99, 9.99),
        e(["kaffeepads", "kaffeekapseln", "kapseln", "senseo", "nespresso", "dolce gusto", "tassimo"], 1, "stk", 2.49, 3.49, 5.49),
        e(["tonic", "tonic water", "ginger ale"], 1000, "ml", 1.29, 1.79, 2.49),
        e(["kräutertee", "früchtetee", "grüner tee", "schwarztee", "pfefferminztee", "kamillentee"], 1, "stk", 1.49, 2.29, 3.49),
        e(["wodka", "vodka", "gin", "rum", "whisky", "whiskey", "likör"], 700, "ml", 8.99, 12.99, 24.99),
        e(["smoothie"], 250, "ml", 1.49, 1.99, 2.99),
    ]

    static let frozen: [PriceCatalogEntry] = [
        e(["pizza", "tiefkühlpizza", "steinofenpizza"], 350, "g", 1.99, 2.79, 3.99),
        e(["pommes", "pommes frites", "kroketten"], 750, "g", 1.49, 1.99, 2.99),
        e(["tiefkühlgemüse", "tk gemüse", "gemüsemischung"], 750, "g", 1.49, 1.99, 2.99),
        e(["erbsen", "tk erbsen"], 450, "g", 0.99, 1.29, 1.99),
        e(["rahmspinat"], 450, "g", 1.29, 1.69, 2.29),
        e(["lasagne", "fertiggericht"], 400, "g", 2.29, 2.99, 4.49),
        e(["tk beeren", "tiefkühlbeeren", "tk himbeeren"], 300, "g", 1.99, 2.49, 3.49),
        e(["eiswürfel"], 1, "stk", 0.99, 1.49, 1.99),
    ]

    static let snacks: [PriceCatalogEntry] = [
        e(["nüsse", "erdnüsse", "cashews", "cashewkerne", "mandeln", "walnüsse", "haselnüsse", "pistazien"], 200, "g", 1.99, 2.79, 3.99),
        e(["gummibärchen", "gummibären", "haribo", "fruchtgummi", "weingummi"], 200, "g", 0.99, 1.29, 1.99),
        e(["kekse", "butterkekse", "cookies", "keks", "leibniz", "prinzenrolle", "oreo"], 200, "g", 0.99, 1.49, 2.29),
        e(["salzstangen", "salzbrezeln", "brezeln"], 250, "g", 0.79, 1.09, 1.59),
        e(["popcorn"], 100, "g", 0.99, 1.29, 1.99),
        e(["riegel", "müsliriegel", "proteinriegel"], 1, "stk", 1.49, 1.99, 2.99),
        e(["nutella", "nuss nougat creme", "nussnougatcreme", "schokocreme"], 400, "g", 2.49, 3.29, 4.49),
        e(["schokoriegel", "snickers", "mars", "kitkat", "twix", "duplo", "kinderriegel"], 1, "stk", 0.59, 0.79, 1.19),
        e(["pralinen", "konfekt"], 200, "g", 2.99, 3.99, 5.99),
        e(["studentenfutter", "nussmischung"], 200, "g", 1.99, 2.49, 3.49),
        e(["trockenfrüchte", "rosinen", "datteln", "trockenobst", "cranberries"], 200, "g", 1.49, 1.99, 2.99),
        e(["cracker", "tuc"], 200, "g", 1.29, 1.69, 2.29),
        e(["reiswaffeln", "maiswaffeln", "reiswaffel", "maiswaffel"], 130, "g", 0.99, 1.29, 1.79),
        e(["kaugummi", "kaugummis"], 1, "stk", 0.99, 1.29, 1.99),
        e(["bonbons", "hustenbonbons", "lutscher"], 1, "stk", 0.99, 1.49, 2.29),
        e(["tortilla chips", "nachos"], 200, "g", 1.29, 1.79, 2.49),
    ]

    static let spicesAndBaking: [PriceCatalogEntry] = [
        e(["salz", "meersalz", "speisesalz", "jodsalz", "fleur de sel"], 500, "g", 0.29, 0.49, 0.99),
        e(["pfeffer", "pfefferkörner"], 50, "g", 1.29, 1.99, 2.99),
        e(["paprikapulver", "currypulver", "curry", "zimt", "oregano", "kurkuma", "kreuzkümmel", "muskat", "chili", "chiliflocken", "thymian", "rosmarin", "lorbeer"], 50, "g", 0.99, 1.49, 2.29),
        e(["gewürz", "gewürze", "gewürzmischung"], 50, "g", 1.29, 1.99, 2.99),
        e(["vanillezucker", "vanillinzucker"], 1, "stk", 0.39, 0.59, 0.99),
        e(["backpulver", "natron"], 1, "stk", 0.39, 0.59, 0.99),
        e(["hefe", "trockenhefe", "frischhefe"], 1, "stk", 0.19, 0.29, 0.49),
        e(["puderzucker"], 250, "g", 0.49, 0.79, 1.19),
        e(["rohrzucker", "brauner zucker"], 500, "g", 1.29, 1.79, 2.49),
        e(["honig"], 500, "g", 2.99, 4.49, 6.99),
        e(["marmelade", "konfitüre", "fruchtaufstrich", "gelee"], 450, "g", 1.49, 1.99, 2.99),
        e(["speisestärke", "stärke"], 400, "g", 0.79, 1.09, 1.49),
        e(["backkakao"], 125, "g", 0.99, 1.49, 2.29),
        e(["puddingpulver"], 1, "stk", 0.49, 0.69, 0.99),
        e(["senf"], 200, "ml", 0.69, 0.99, 1.49),
        e(["ketchup", "tomatenketchup"], 500, "ml", 1.29, 1.79, 2.49),
        e(["mayonnaise", "mayo", "remoulade"], 250, "ml", 0.99, 1.49, 2.19),
        e(["essig", "weinessig", "apfelessig", "vinegar"], 500, "ml", 0.89, 1.49, 2.99),
        e(["balsamico", "balsamicoessig"], 250, "ml", 1.99, 2.99, 4.99),
        e(["öl", "oil", "speiseöl"], 1000, "ml", 1.49, 1.99, 2.99),
        e(["olivenöl"], 500, "ml", 3.99, 5.99, 9.99),
        e(["sonnenblumenöl", "rapsöl"], 1000, "ml", 1.49, 1.99, 2.99),
        e(["sesamöl", "kokosöl"], 250, "ml", 2.49, 3.49, 4.99),
        e(["sojasauce", "sojasoße"], 150, "ml", 1.29, 1.79, 2.49),
        e(["brühe", "gemüsebrühe", "brühwürfel", "hühnerbrühe", "rinderbrühe"], 1, "stk", 0.79, 1.19, 1.79),
        e(["tomatenmark"], 200, "g", 0.69, 0.99, 1.49),
        e(["passierte tomaten", "tomatenpassata", "passata"], 500, "g", 0.69, 0.99, 1.49),
        e(["gehackte tomaten", "stückige tomaten", "dosentomaten"], 400, "g", 0.69, 0.99, 1.49),
        e(["vanille", "vanilleschote", "vanillearoma"], 1, "stk", 0.99, 1.99, 4.99),
        e(["mandeln gemahlen", "gemahlene mandeln", "haselnüsse gemahlen"], 200, "g", 1.99, 2.49, 3.49),
        e(["schokostreusel", "zuckerstreusel", "kuvertüre", "schokodrops"], 200, "g", 0.99, 1.49, 2.29),
        e(["agavendicksaft", "ahornsirup", "sirup"], 250, "ml", 2.49, 3.49, 4.99),
    ]

    static let pantry: [PriceCatalogEntry] = [
        e(["spaghetti", "penne", "fusilli", "tagliatelle", "linguine", "farfalle", "rigatoni", "lasagneplatten", "makkaroni"], 500, "g", 0.79, 1.19, 1.99),
        e(["basmatireis", "basmati", "jasminreis", "langkornreis", "vollkornreis"], 1000, "g", 1.99, 2.79, 3.99),
        e(["risottoreis", "risotto"], 500, "g", 1.49, 1.99, 2.99),
        e(["couscous", "bulgur", "polenta"], 500, "g", 1.29, 1.79, 2.49),
        e(["quinoa", "hirse", "amaranth"], 500, "g", 2.99, 3.99, 5.49),
        e(["linsen", "rote linsen", "kichererbsen", "erbsen getrocknet"], 500, "g", 1.29, 1.79, 2.49),
        e(["kidneybohnen", "weiße bohnen", "schwarze bohnen"], 400, "g", 0.59, 0.89, 1.29),
        e(["sauerkraut", "rotkraut"], 500, "g", 0.79, 1.09, 1.59),
        e(["essiggurken", "gewürzgurken", "cornichons"], 1, "stk", 0.99, 1.49, 2.19),
        e(["oliven"], 200, "g", 1.29, 1.79, 2.49),
        e(["pesto"], 190, "g", 1.29, 1.79, 2.69),
        e(["tomatensauce", "tomatensoße", "pastasauce", "pastasoße", "bolognese"], 400, "g", 0.99, 1.49, 2.29),
        e(["suppe", "dosensuppe", "tütensuppe"], 1, "stk", 1.29, 1.79, 2.49),
        e(["ravioli"], 800, "g", 1.49, 1.99, 2.79),
        e(["erdnussbutter", "erdnussmus", "mandelmus"], 350, "g", 1.99, 2.79, 3.99),
        e(["dinkelmehl", "vollkornmehl", "weizenmehl", "roggenmehl"], 1000, "g", 1.29, 1.79, 2.49),
        e(["semmelbrösel", "paniermehl", "panko"], 400, "g", 0.59, 0.89, 1.29),
        e(["grieß", "hartweizengrieß", "weichweizengrieß"], 500, "g", 0.59, 0.89, 1.29),
        e(["apfelmus", "apfelmark"], 700, "g", 1.29, 1.69, 2.29),
        e(["gnocchi", "schupfnudeln", "spätzle"], 500, "g", 1.29, 1.79, 2.49),
        e(["kartoffelpüree", "püree"], 1, "stk", 1.29, 1.69, 2.29),
        e(["knödel", "klöße", "kloßteig"], 1, "stk", 1.49, 1.99, 2.79),
        e(["asia nudeln", "mie nudeln", "reisnudeln", "glasnudeln", "ramen"], 250, "g", 1.29, 1.79, 2.49),
        e(["kokosflocken", "kokosraspeln", "chiasamen", "leinsamen", "sesam"], 200, "g", 1.29, 1.79, 2.49),
        e(["kapern", "sardellen", "anchovis"], 100, "g", 1.29, 1.79, 2.49),
        e(["instantnudeln", "yum yum"], 1, "stk", 0.39, 0.59, 0.99),
        e(["babynahrung", "babybrei", "gläschen"], 1, "stk", 0.79, 1.19, 1.79),
        e(["proteinpulver", "eiweißpulver"], 1, "stk", 14.99, 19.99, 29.99),
    ]

    static let personalCare: [PriceCatalogEntry] = [
        e(["deo", "deodorant", "deospray", "deoroller", "rexona", "axe", "deostick", "deocreme"], 1, "stk", 1.99, 2.79, 4.49),
        e(["seife", "handseife", "flüssigseife", "soap"], 1, "stk", 0.99, 1.49, 2.49),
        e(["bodylotion", "körperlotion", "creme", "handcreme", "gesichtscreme", "lotion", "nivea"], 1, "stk", 1.99, 2.99, 4.99),
        e(["rasierer", "rasierklingen", "einwegrasierer", "rasierklinge", "gillette", "wilkinson"], 1, "stk", 4.99, 7.99, 12.99),
        e(["rasierschaum", "rasiergel"], 1, "stk", 1.99, 2.79, 3.99),
        e(["tampons", "binden", "slipeinlagen"], 1, "stk", 1.99, 2.99, 4.49),
        e(["taschentücher", "tempo", "kleenex", "taschentuch", "kosmetiktücher", "tissues"], 1, "stk", 1.29, 1.79, 2.49),
        e(["küchenrolle", "küchentücher", "küchenpapier", "zewa", "haushaltsrolle", "haushaltstücher", "papiertücher", "papierhandtücher"], 1, "stk", 1.99, 2.79, 3.99),
        e(["wattepads", "wattestäbchen", "watte", "cotton pads"], 1, "stk", 0.79, 1.19, 1.79),
        e(["mundspülung", "mundwasser", "mundpflege"], 1, "stk", 2.49, 3.49, 4.99),
        e(["zahnseide", "interdentalbürsten"], 1, "stk", 1.49, 1.99, 2.99),
        e(["sonnencreme", "sonnenmilch", "sonnenspray", "sunscreen"], 1, "stk", 4.99, 7.99, 12.99),
        e(["haarspray", "haargel", "haarwachs", "schaumfestiger"], 1, "stk", 2.49, 3.49, 4.99),
        e(["spülung", "haarspülung", "conditioner", "haarkur"], 1, "stk", 2.49, 3.49, 4.99),
        e(["lippenpflege", "labello", "lippenbalsam"], 1, "stk", 1.29, 1.79, 2.79),
        e(["pflaster", "verbandsmaterial", "hansaplast"], 1, "stk", 1.99, 2.79, 3.99),
        e(["windeln", "pampers", "diapers"], 1, "stk", 7.99, 11.99, 17.99),
        e(["feuchttücher", "babytücher", "feuchte tücher"], 1, "stk", 1.29, 1.79, 2.49),
        e(["ibuprofen", "paracetamol", "aspirin", "schmerztabletten"], 1, "stk", 2.99, 4.49, 6.99),
        e(["nasenspray", "hustensaft", "halstabletten", "nasal spray"], 1, "stk", 2.49, 3.99, 5.99),
        e(["vitamine", "vitamin d", "magnesium", "zink"], 1, "stk", 3.99, 5.99, 9.99),
        e(["ohrenstäbchen"], 1, "stk", 0.79, 1.19, 1.79),
        e(["nagellack", "nagellackentferner", "nagelfeile"], 1, "stk", 1.99, 2.99, 4.99),
        e(["gesichtsmaske", "peeling"], 1, "stk", 1.49, 2.49, 3.99),
        e(["make up", "makeup", "mascara", "lippenstift"], 1, "stk", 4.99, 7.99, 12.99),
        e(["kontaktlinsenflüssigkeit", "kontaktlinsen"], 1, "stk", 4.99, 7.99, 12.99),
        e(["kondome"], 1, "stk", 5.99, 8.99, 12.99),
    ]

    static let household: [PriceCatalogEntry] = [
        e(["weichspüler", "lenor", "kuschelweich", "vernel"], 1, "stk", 1.99, 2.79, 3.99),
        e(["spülmaschinentabs", "geschirrspültabs", "spültabs", "geschirrreiniger", "tabs", "somat", "finish", "spülmaschinentabletten", "geschirrspültabletten", "geschirrtabs", "spülmaschinenpulver"], 1, "stk", 4.99, 7.99, 12.99),
        e(["allzweckreiniger", "allesreiniger", "universalreiniger", "reiniger", "meister proper"], 1, "stk", 1.49, 1.99, 2.99),
        e(["glasreiniger", "fensterreiniger"], 1, "stk", 1.49, 1.99, 2.99),
        e(["badreiniger", "kalkreiniger"], 1, "stk", 1.99, 2.49, 3.49),
        e(["wc reiniger", "toilettenreiniger", "wc ente", "klosteine", "wc tabs", "wc stein", "wc steine", "klostein", "wc gel", "domestos", "bref"], 1, "stk", 1.49, 1.99, 2.99),
        e(["schwamm", "schwämme", "spülschwamm", "topfreiniger", "scheuerschwamm", "schwammtücher", "sponge"], 1, "stk", 0.99, 1.49, 2.29),
        e(["müllbeutel", "mülltüten", "müllsäcke", "gelbe säcke", "mülltüte", "müllsack", "abfallbeutel", "abfallsäcke", "biomüllbeutel", "kompostbeutel", "garbage bag", "bin bag"], 1, "stk", 1.49, 1.99, 2.99),
        e(["alufolie"], 1, "stk", 1.99, 2.49, 3.49),
        e(["frischhaltefolie"], 1, "stk", 1.49, 1.99, 2.79),
        e(["backpapier", "muffinförmchen"], 1, "stk", 1.49, 1.99, 2.79),
        e(["gefrierbeutel", "zipbeutel", "butterbrotpapier"], 1, "stk", 1.29, 1.79, 2.49),
        e(["batterien", "batterie", "knopfzelle", "knopfzellen", "duracell", "varta"], 1, "stk", 2.99, 4.99, 7.99),
        e(["glühbirne", "glühlampe", "led lampe", "leuchtmittel", "led birne", "energiesparlampe", "ledlampe"], 1, "stk", 2.99, 4.99, 8.99),
        e(["kerzen", "teelichter", "teelicht", "kerze", "duftkerze", "candle", "tealight"], 1, "stk", 1.99, 2.99, 4.49),
        e(["streichhölzer", "feuerzeug", "feuerzeuge"], 1, "stk", 0.49, 0.99, 1.99),
        e(["entkalker"], 1, "stk", 2.49, 3.49, 4.99),
        e(["fleckentferner", "fleckensalz", "gallseife"], 1, "stk", 2.99, 3.99, 5.49),
        e(["putzlappen", "mikrofasertuch", "mikrofasertücher", "putztücher", "putztuch", "wischtuch", "wischtücher", "spültuch", "spültücher", "wischlappen"], 1, "stk", 1.99, 2.99, 4.49),
        e(["katzenfutter", "nassfutter"], 400, "g", 0.59, 0.89, 1.49),
        e(["hundefutter", "trockenfutter"], 800, "g", 0.99, 1.49, 2.49),
        e(["katzenstreu"], 1, "stk", 3.99, 5.99, 8.99),
        e(["blumen", "blumenstrauß", "tulpen", "rosen", "strauß"], 1, "stk", 2.99, 4.99, 9.99),
        e(["geschenkpapier", "geschenkband"], 1, "stk", 1.99, 2.99, 4.49),
        e(["kaffeefilter", "filtertüten"], 1, "stk", 0.99, 1.49, 2.29),
        e(["servietten"], 1, "stk", 1.29, 1.79, 2.49),
        e(["staubsaugerbeutel"], 1, "stk", 4.99, 7.99, 12.99),
        e(["handschuhe", "gummihandschuhe", "einweghandschuhe", "gloves"], 1, "stk", 1.49, 2.49, 3.99),
        e(["klarspüler", "spülmaschinensalz", "regeneriersalz"], 1, "stk", 1.49, 2.29, 3.49),
        e(["rohrreiniger", "abflussreiniger"], 1, "stk", 1.99, 2.99, 4.49),
        e(["bügelspray", "wäschestärke", "hygienespüler"], 1, "stk", 1.99, 2.99, 4.49),
        e(["grillkohle", "holzkohle", "grillanzünder", "kohle", "anzünder", "feueranzünder"], 1, "stk", 3.99, 5.99, 9.99),
        e(["zahnstocher", "strohhalme", "trinkhalme"], 1, "stk", 0.79, 1.19, 1.79),
        e(["pflanzenerde", "blumenerde", "pflanzerde"], 1, "stk", 2.99, 4.99, 7.99),
        e(["vogelfutter", "meisenknödel"], 1, "stk", 1.99, 2.99, 4.99),
    ]

    // MARK: - Erweiterung PO 2026-10-22: Marken, Kurzformen, Drogerie, Haushalt, Sport

    /// Marken, Kurz- und Regionalformen zu den 32 Alt-Stichwörtern, mit deren unveränderten Werten.
    /// Eigene Einträge statt neuer Namen in `legacy`, weil `legacy` die Grundlage der Messung
    /// „vorher" in `PriceCatalogTests` ist und dort unverändert bleiben muss.
    static let legacyAliases: [PriceCatalogEntry] = [
        e(["hack", "faschiertes"], 1, "stk", 2.99, 4.00, 5.99),
        e(["milka", "ritter sport", "lindt", "schoki", "schoko", "schokoladentafel"], 1, "stk", 0.89, 1.50, 2.99),
        e(["spüli", "pril", "fairy", "handspülmittel", "geschirrspülmittel"], 1, "stk", 0.99, 1.80, 2.99),
        e(["persil", "ariel", "spee", "weißer riese", "waschpulver", "waschgel", "waschpods", "waschcaps"], 1, "stk", 4.99, 8.00, 12.99),
        e(["hakle", "klorolle", "klorollen", "toilettenrolle", "toilettenrollen", "wc papier"], 1, "stk", 2.99, 4.00, 6.49),
        e(["jacobs", "dallmayr", "lavazza", "eduscho"], 1, "stk", 3.99, 5.50, 8.99),
        e(["teebeutel", "meßmer", "messmer"], 1, "stk", 1.49, 3.00, 4.99),
        e(["coke", "spezi", "mezzo mix"], 1, "stk", 0.99, 1.50, 2.29),
        e(["semmel", "schrippe", "weckle", "weckerl"], 1, "stk", 1.49, 2.50, 3.99),
        e(["erdäpfel", "erdapfel"], 1, "stk", 1.49, 2.00, 2.99),
        e(["paradeiser"], 1, "stk", 1.49, 2.00, 3.99),
        e(["zahncreme", "zahngel", "elmex", "sensodyne", "colgate", "blend a med", "blendamed", "aronal"], 1, "stk", 1.29, 2.50, 4.49),
        e(["schauma", "head shoulders"], 1, "stk", 2.49, 4.50, 7.99),
        e(["duschbad", "duschcreme", "duschöl", "duschschaum", "duschdas"], 1, "stk", 1.49, 3.00, 4.99),
        e(["hühnchen", "huhn"], 1, "stk", 3.49, 4.50, 6.99),
        e(["pringles", "funny frisch"], 1, "stk", 1.29, 1.80, 2.79),
        e(["kerrygold"], 1, "stk", 1.69, 2.20, 2.99),
        e(["leerdammer"], 1, "stk", 2.49, 3.50, 4.99),
    ]

    /// Lebensmittel, die vorher nur über eine falsche oder gar keine Endung trafen.
    static let foodAdditions: [PriceCatalogEntry] = [
        e(["schweinefleisch", "schweinenacken", "schweinebauch", "schweinefilet", "schwein"], 500, "g", 3.49, 4.99, 6.99),
        e(["kefir", "joghurtdrink", "trinkjoghurt", "actimel", "ayran"], 500, "ml", 0.79, 1.19, 1.99),
        e(["gorgonzola", "blauschimmelkäse"], 150, "g", 1.49, 1.99, 2.99),
        e(["grapefruit", "grapefruits", "pomelo"], 1, "stk", 0.59, 0.89, 1.29),
        e(["granatapfel"], 1, "stk", 0.99, 1.49, 2.29),
        e(["ciabatta", "focaccia"], 1, "stk", 0.99, 1.49, 2.29),
        e(["bagel", "bagels"], 1, "stk", 1.49, 1.99, 2.79),
        e(["muffin", "muffins"], 1, "stk", 1.49, 2.29, 3.49),
        e(["waffeln", "waffel"], 1, "stk", 1.29, 1.79, 2.49),
        e(["laugenstange", "laugenstangen"], 1, "stk", 0.59, 0.89, 1.29),
        e(["cappuccino", "latte macchiato", "milchkaffee"], 1, "stk", 1.99, 2.99, 4.49),
        e(["schnaps", "obstler", "kräuterschnaps"], 700, "ml", 6.99, 9.99, 19.99),
        e(["marshmallows"], 200, "g", 0.99, 1.49, 2.29),
        e(["pinienkerne", "macadamia"], 100, "g", 2.49, 3.49, 4.99),
        e(["chicken nuggets", "nuggets"], 500, "g", 2.49, 3.49, 4.99),
        e(["rösti", "kartoffelpuffer", "reibekuchen"], 500, "g", 1.29, 1.79, 2.49),
        e(["strudel", "apfelstrudel"], 1, "stk", 1.99, 2.79, 3.99),
    ]

    /// Drogerie (dm, Rossmann, Müller): Eigenmarke bis Markenartikel, typischer Wert dazwischen.
    static let drugstore: [PriceCatalogEntry] = [
        e(["haarfarbe", "haarfärbemittel", "tönung", "coloration"], 1, "stk", 2.45, 4.95, 9.95),
        e(["gesichtswasser", "mizellenwasser", "reinigungsmilch", "abschminktücher", "abschminkpads"], 1, "stk", 1.25, 2.45, 4.95),
        e(["tagescreme", "nachtcreme", "augencreme", "feuchtigkeitscreme"], 50, "ml", 1.95, 3.95, 9.95),
        e(["fußcreme", "hornhautentferner", "fußpflege"], 1, "stk", 1.45, 2.45, 4.95),
        e(["parfum", "parfüm", "eau de toilette", "eau de parfum"], 1, "stk", 4.95, 14.95, 49.95),
        e(["aftershave", "after shave", "rasierwasser"], 1, "stk", 2.45, 3.95, 7.95),
        e(["bartöl", "bartpflege", "bartbalsam"], 1, "stk", 2.95, 4.95, 9.95),
        e(["rasierapparat", "elektrorasierer", "trockenrasierer"], 1, "stk", 24.95, 49.95, 99.95),
        e(["zahnbürstenköpfe", "aufsteckbürsten", "ersatzbürsten"], 1, "stk", 3.95, 9.95, 19.95),
        e(["elektrische zahnbürste", "schallzahnbürste"], 1, "stk", 14.95, 29.95, 59.95),
        e(["haarbürste", "rundbürste", "kamm", "hair brush", "comb"], 1, "stk", 1.95, 3.95, 7.95),
        e(["haargummi", "haargummis", "haarband", "haarbänder", "haarklammern", "haarspangen", "haarnadeln", "haarnadel", "hair tie"], 1, "stk", 0.95, 1.95, 3.95),
        e(["nagelschere", "nagelknipser", "pinzette"], 1, "stk", 1.45, 2.95, 5.95),
        e(["babyöl", "babypuder", "babycreme", "wundschutzcreme", "babyshampoo", "babybad"], 1, "stk", 1.25, 1.95, 3.95),
        e(["schnuller"], 1, "stk", 2.95, 4.95, 7.95),
        e(["babyflasche", "trinklernbecher"], 1, "stk", 3.95, 6.95, 12.95),
        e(["pre nahrung", "folgemilch", "anfangsmilch", "milchnahrung", "säuglingsmilch", "aptamil", "milumil"], 1, "stk", 9.95, 14.95, 24.95),
        e(["erkältungsbalsam", "erkältungssalbe", "erkältungsbad"], 1, "stk", 2.95, 4.95, 7.95),
        e(["augentropfen", "nasentropfen", "ohrentropfen", "nasengel", "nasenöl", "augensalbe", "eye drops", "nose drops", "nasenpflege"], 1, "stk", 2.95, 4.95, 8.95),
        e(["fieberthermometer", "thermometer"], 1, "stk", 4.95, 8.95, 14.95),
        e(["desinfektionsmittel", "desinfektionsspray", "handdesinfektion", "desinfektionstücher", "sagrotan"], 1, "stk", 1.95, 3.45, 5.95),
        e(["mückenspray", "mückenschutz", "autan", "zeckenschutz"], 1, "stk", 3.95, 5.95, 8.95),
        e(["wärmflasche"], 1, "stk", 3.95, 6.95, 12.95),
        e(["multivitamin", "vitamin", "brausetabletten", "vitamintabletten", "nahrungsergänzung", "omega", "eisentabletten", "calcium"], 1, "stk", 0.95, 2.95, 9.95),
        e(["schmerzmittel", "kopfschmerztabletten"], 1, "stk", 2.99, 4.49, 6.99),
        e(["gleitgel"], 1, "stk", 4.95, 7.95, 12.95),
        e(["schwangerschaftstest"], 1, "stk", 2.95, 4.95, 9.95),
        e(["after sun", "aftersun"], 1, "stk", 2.45, 3.95, 6.95),
        e(["intimwaschlotion", "intimpflege"], 1, "stk", 1.95, 2.95, 4.95),
        e(["lidschatten", "kajal", "eyeliner", "augenbrauenstift", "concealer", "puder", "rouge", "foundation", "wimperntusche"], 1, "stk", 2.95, 5.95, 12.95),
        e(["enthaarungscreme", "wachsstreifen", "kaltwachsstreifen"], 1, "stk", 2.95, 4.95, 8.95),
        e(["mullbinden", "mullbinde", "kompressen", "elastische binde"], 1, "stk", 1.45, 2.45, 3.95),
        e(["fußbad", "badesalz", "badezusatz", "schaumbad", "badekugeln"], 1, "stk", 0.95, 1.95, 3.95),
        e(["trockenshampoo"], 1, "stk", 1.95, 3.45, 5.95),
        e(["körperspray", "bodyspray", "duftspray"], 1, "stk", 1.95, 3.45, 5.95),
        e(["reinigungsgel", "waschgel gesicht", "gesichtsreinigung"], 1, "stk", 1.95, 3.95, 7.95),
        e(["lippenpflegestift", "lippenbalm"], 1, "stk", 0.95, 1.95, 3.45),
        e(["einlagen", "inkontinenzeinlagen"], 1, "stk", 2.95, 4.95, 8.95),
        e(["stilleinlagen"], 1, "stk", 2.95, 3.95, 5.95),
        e(["fusselrolle", "kleiderbürste"], 1, "stk", 1.45, 2.45, 4.95),
    ]

    /// Haushalt: Reinigung, Wäsche, Küche, Kleinkram für Wohnung, Tier und Garten.
    static let householdMore: [PriceCatalogEntry] = [
        e(["scheuermilch", "scheuerpulver", "viss", "cif"], 1, "stk", 0.95, 1.65, 2.95),
        e(["spülbürste", "flaschenbürste"], 1, "stk", 0.95, 1.95, 3.95),
        e(["scheuertuch", "stahlwolle", "edelstahlschwamm"], 1, "stk", 0.79, 1.49, 2.49),
        e(["geschirrtuch", "geschirrtücher", "küchenhandtuch", "küchentuch"], 1, "stk", 1.49, 2.49, 4.99),
        e(["bodenreiniger", "parkettreiniger", "laminatreiniger", "wischpflege"], 1, "stk", 1.49, 2.29, 3.99),
        e(["küchenreiniger", "fettlöser", "backofenreiniger", "ofenreiniger", "grillreiniger"], 1, "stk", 1.49, 2.49, 4.49),
        e(["essigreiniger", "zitronensäure", "essigessenz"], 1, "stk", 0.79, 1.29, 2.49),
        e(["waschnetz", "wäschenetz"], 1, "stk", 0.99, 1.99, 3.99),
        e(["wäscheklammern", "wäscheklammer"], 1, "stk", 0.99, 1.99, 3.49),
        e(["kleiderbügel"], 1, "stk", 1.99, 3.99, 7.99),
        e(["farbtücher", "colorfangtücher", "farbfangtücher"], 1, "stk", 1.99, 2.99, 3.99),
        e(["entkalkungstabs", "entkalkungstabletten", "kaffeemaschinenentkalker"], 1, "stk", 2.49, 3.49, 4.99),
        e(["staubtuch", "staubtücher", "staubwedel", "staubmagnet", "swiffer"], 1, "stk", 1.99, 3.49, 5.99),
        e(["wischmopp", "mopp", "bodenwischer", "wischbezug"], 1, "stk", 3.99, 7.99, 14.99),
        e(["besen", "handfeger", "kehrschaufel", "kehrgarnitur", "kehrbesen"], 1, "stk", 2.99, 4.99, 9.99),
        e(["schneebesen"], 1, "stk", 1.49, 2.99, 5.99),
        e(["eimer", "putzeimer"], 1, "stk", 1.99, 3.99, 7.99),
        e(["mülleimer", "abfalleimer", "treteimer"], 1, "stk", 4.99, 12.99, 29.99),
        e(["wäschekorb", "wäschesammler"], 1, "stk", 4.99, 7.99, 14.99),
        e(["wäscheständer", "trockenständer"], 1, "stk", 9.99, 17.99, 34.99),
        e(["akkus", "akku", "wiederaufladbare batterien"], 1, "stk", 4.99, 8.99, 14.99),
        e(["verlängerungskabel", "mehrfachsteckdose", "steckdosenleiste", "steckerleiste"], 1, "stk", 4.99, 8.99, 14.99),
        e(["ladekabel", "usb kabel"], 1, "stk", 2.99, 6.99, 14.99),
        e(["klebeband", "tesafilm", "tesa", "paketband"], 1, "stk", 0.99, 1.99, 3.99),
        e(["sekundenkleber", "alleskleber", "kleber", "klebestift", "uhu", "pattex"], 1, "stk", 1.29, 2.49, 4.49),
        e(["wasserfilter", "filterkartuschen", "filterkartusche", "brita"], 1, "stk", 4.99, 7.99, 14.99),
        e(["vorratsdose", "frischhaltedose", "brotdose", "tupperdose", "plastikdose"], 1, "stk", 1.99, 3.99, 7.99),
        e(["tiefkühlbeutel", "brotbeutel", "obstbeutel", "haushaltsbeutel"], 1, "stk", 1.29, 1.79, 2.49),
        e(["pappteller", "pappbecher", "plastikbecher", "einwegbecher", "partybecher", "einwegbesteck", "einweggeschirr", "einwegteller"], 1, "stk", 0.99, 1.99, 3.49),
        e(["insektenspray", "fliegenfänger", "mottenschutz", "ameisenköder", "ameisengift"], 1, "stk", 2.49, 3.99, 6.99),
        e(["raumspray", "lufterfrischer", "raumduft", "febreze", "duftstecker"], 1, "stk", 1.49, 2.99, 4.99),
        e(["schuhcreme", "schuhpflege", "imprägnierspray"], 1, "stk", 1.99, 3.49, 6.99),
        e(["wäscheduft", "wäscheparfüm", "duftperlen"], 1, "stk", 3.99, 5.99, 7.99),
        e(["wasserenthärter", "calgon"], 1, "stk", 3.99, 6.99, 9.99),
        e(["leckerli", "hundeleckerli", "katzensnacks", "kauknochen", "hundekuchen"], 1, "stk", 0.99, 1.99, 3.99),
        e(["kotbeutel", "hundekotbeutel", "gassibeutel"], 1, "stk", 1.49, 2.49, 4.49),
        e(["streusalz", "auftausalz"], 1, "stk", 1.99, 2.99, 4.99),
        e(["grillbriketts", "briketts"], 1, "stk", 3.99, 5.99, 9.99),
        e(["kaminanzünder", "anzündholz", "kaminholz", "brennholz"], 1, "stk", 2.99, 4.99, 8.99),
        e(["gartenschlauch", "wasserschlauch"], 1, "stk", 9.99, 19.99, 39.99),
        e(["dünger", "blumendünger", "flüssigdünger", "rasendünger"], 1, "stk", 1.99, 3.99, 7.99),
        e(["rasensamen", "saatgut", "blumensamen"], 1, "stk", 1.49, 2.99, 9.99),
        e(["toilettenbürste", "klobürste", "wc bürste"], 1, "stk", 1.99, 3.99, 7.99),
        e(["duschvorhang"], 1, "stk", 4.99, 8.99, 14.99),
        e(["fußmatte", "türmatte", "schmutzfangmatte"], 1, "stk", 4.99, 9.99, 19.99),
        e(["handtuch", "handtücher", "badetuch", "duschtuch", "gästehandtuch", "waschlappen"], 1, "stk", 3.99, 6.99, 12.99),
        e(["spülmaschinenreiniger", "maschinenpfleger", "waschmaschinenreiniger"], 1, "stk", 1.99, 2.99, 4.49),
        e(["fensterputzer", "abzieher", "fensterwischer"], 1, "stk", 2.99, 4.99, 9.99),
        e(["glasschaber", "ceranfeldschaber", "ceranfeldreiniger"], 1, "stk", 1.99, 3.49, 5.99),
        e(["kochtopf", "pfanne", "bratpfanne"], 1, "stk", 9.99, 19.99, 39.99),
        e(["tasse", "tassen", "kaffeebecher"], 1, "stk", 1.99, 3.99, 7.99),
        e(["trinkgläser", "gläser", "wassergläser"], 1, "stk", 2.99, 5.99, 12.99),
        e(["schneidebrett", "frühstücksbrett"], 1, "stk", 2.99, 5.99, 12.99),
        e(["sparschäler", "dosenöffner", "flaschenöffner", "korkenzieher", "küchenhelfer"], 1, "stk", 1.49, 2.99, 6.99),
        e(["glühweinbecher"], 1, "stk", 1.99, 2.99, 4.99),
        e(["kerzenständer", "kerzenhalter"], 1, "stk", 2.99, 4.99, 9.99),
        e(["bilderrahmen"], 1, "stk", 2.99, 5.99, 12.99),
        e(["schreibblock", "notizblock", "collegeblock", "heft", "hefte"], 1, "stk", 0.79, 1.49, 2.99),
        e(["kugelschreiber", "kuli", "kulis", "bleistift", "bleistifte", "textmarker", "filzstifte", "buntstifte"], 1, "stk", 0.99, 2.49, 4.99),
        e(["briefumschläge", "briefumschlag", "briefmarken"], 1, "stk", 1.49, 2.99, 9.99),
        e(["rindenmulch", "mulch"], 1, "stk", 2.99, 4.99, 7.99),
        e(["rührschüssel", "salatschüssel", "müslischüssel"], 1, "stk", 2.99, 5.99, 12.99),
        e(["sieb", "abtropfsieb", "nudelsieb"], 1, "stk", 2.99, 4.99, 9.99),
        e(["küchenreibe", "gemüsereibe", "käsereibe"], 1, "stk", 2.99, 4.99, 9.99),
        e(["backform", "kuchenform", "springform", "auflaufform", "muffinform"], 1, "stk", 4.99, 8.99, 14.99),
        e(["grillschalen", "grillschale", "aluschalen", "aluschale"], 1, "stk", 1.49, 2.49, 3.99),
        e(["grillzange", "grillbesteck", "grillrost", "grillhandschuh"], 1, "stk", 4.99, 8.99, 14.99),
        e(["blumentopf", "übertopf", "pflanztopf"], 1, "stk", 1.99, 4.99, 12.99),
        e(["gießkanne"], 1, "stk", 3.99, 6.99, 12.99),
        e(["schere", "küchenschere", "bastelschere"], 1, "stk", 2.99, 4.99, 9.99),
    ]

    /// Sport und Outdoor (Decathlon & Co.): Eigenmarke als untere Grenze, typischer Wert für das
    /// Einstiegs-/Mittelsegment. Liegt der typische Wert über `PriceEstimator.maxPlausibleLineTotal`
    /// (Zelt, Laufschuhe), verwirft `PriceEstimator.resolve` die Schätzung und die Zeile zeigt
    /// „Preis?"; der Eintrag bleibt trotzdem, damit der Name nicht über ein kürzeres Grundwort
    /// einen falschen Preis bekommt.
    static let sports: [PriceCatalogEntry] = [
        e(["fahrradschlauch", "fahrradschläuche", "radschlauch", "ersatzschlauch", "schlauch"], 1, "stk", 3.99, 5.99, 9.99),
        e(["fahrradmantel", "fahrradreifen"], 1, "stk", 9.99, 17.99, 29.99),
        e(["flickzeug", "reifenflickzeug", "flicken"], 1, "stk", 2.49, 3.99, 6.99),
        e(["fahrradlicht", "fahrradlampe", "fahrradbeleuchtung", "rücklicht", "frontlicht"], 1, "stk", 7.99, 14.99, 29.99),
        e(["fahrradschloss", "bügelschloss", "kettenschloss", "faltschloss"], 1, "stk", 9.99, 19.99, 39.99),
        e(["fahrradpumpe", "luftpumpe", "standpumpe", "minipumpe"], 1, "stk", 7.99, 14.99, 24.99),
        e(["fahrradhelm", "radhelm", "skihelm", "kinderhelm"], 1, "stk", 14.99, 29.99, 59.99),
        e(["fahrradkette", "kettenöl", "kettenspray", "fahrradöl"], 1, "stk", 3.99, 6.99, 12.99),
        e(["fahrradkorb", "fahrradtasche", "satteltasche", "gepäckträgertasche"], 1, "stk", 9.99, 19.99, 39.99),
        e(["fahrradklingel", "klingel"], 1, "stk", 2.99, 4.99, 8.99),
        e(["fahrradhandschuhe", "radhandschuhe"], 1, "stk", 5.99, 9.99, 19.99),
        e(["bremsbeläge", "bremsklötze", "bremsbelag"], 1, "stk", 3.99, 7.99, 14.99),
        e(["sattel", "fahrradsattel"], 1, "stk", 9.99, 19.99, 39.99),
        e(["schaltzug", "bremszug"], 1, "stk", 2.99, 4.99, 7.99),
        e(["flaschenhalter", "fahrradflaschenhalter"], 1, "stk", 2.99, 4.99, 9.99),
        e(["reflektoren", "speichenreflektoren", "warnweste"], 1, "stk", 1.99, 3.99, 7.99),
        e(["tennisbälle", "tennisball"], 1, "stk", 3.99, 5.99, 9.99),
        e(["tischtennisbälle", "tischtennisball"], 1, "stk", 1.99, 3.49, 5.99),
        e(["tischtennisschläger"], 1, "stk", 4.99, 9.99, 24.99),
        e(["federbälle", "federball"], 1, "stk", 2.99, 4.99, 8.99),
        e(["badmintonschläger", "federballschläger"], 1, "stk", 6.99, 12.99, 29.99),
        e(["tennisschläger"], 1, "stk", 19.99, 39.99, 89.99),
        e(["fußball", "fussball", "volleyball", "basketball", "handball", "gymnastikball"], 1, "stk", 7.99, 12.99, 24.99),
        e(["wasserball", "strandball"], 1, "stk", 1.99, 3.99, 6.99),
        e(["trinkflasche", "sportflasche", "wasserflasche", "fahrradflasche"], 1, "stk", 2.99, 5.99, 12.99),
        e(["thermosflasche", "isolierflasche", "thermoskanne"], 1, "stk", 7.99, 14.99, 29.99),
        e(["yogamatte", "fitnessmatte", "gymnastikmatte", "sportmatte"], 1, "stk", 7.99, 12.99, 29.99),
        e(["isomatte", "thermomatte"], 1, "stk", 7.99, 14.99, 39.99),
        e(["schlafsack"], 1, "stk", 14.99, 29.99, 69.99),
        e(["luftmatratze"], 1, "stk", 9.99, 19.99, 39.99),
        e(["sportsocken", "laufsocken", "wandersocken", "skisocken", "tennissocken", "socken", "strümpfe"], 1, "stk", 3.99, 6.99, 12.99),
        e(["sport bh"], 1, "stk", 9.99, 14.99, 29.99),
        e(["laufschuhe", "sportschuhe", "turnschuhe", "sneaker", "hallenschuhe", "wanderschuhe"], 1, "stk", 24.99, 49.99, 99.99),
        e(["badehose", "badeanzug", "bikini"], 1, "stk", 7.99, 12.99, 24.99),
        e(["schwimmbrille", "taucherbrille"], 1, "stk", 4.99, 8.99, 19.99),
        e(["badekappe", "schwimmkappe", "badehaube"], 1, "stk", 2.99, 4.99, 8.99),
        e(["schwimmflügel", "schwimmnudel", "schwimmring"], 1, "stk", 2.99, 5.99, 9.99),
        e(["mikrofaserhandtuch", "sporthandtuch"], 1, "stk", 6.99, 9.99, 19.99),
        e(["hanteln", "hantel", "kurzhanteln", "kettlebell"], 1, "stk", 9.99, 19.99, 49.99),
        e(["springseil", "sprungseil", "widerstandsband", "fitnessband", "theraband"], 1, "stk", 3.99, 7.99, 14.99),
        e(["faszienrolle", "blackroll", "massageball"], 1, "stk", 9.99, 14.99, 29.99),
        e(["proteinshake", "eiweißshake"], 1, "stk", 1.99, 2.49, 3.49),
        e(["isotonisches getränk", "elektrolyte", "elektrolytpulver", "sportgetränk", "sportdrink", "isodrink"], 1, "stk", 0.99, 1.49, 2.99),
        e(["energiegel", "energy gel", "sportgel"], 1, "stk", 1.49, 1.99, 2.99),
        e(["energieriegel", "energy riegel", "sportriegel"], 1, "stk", 0.99, 1.49, 2.49),
        e(["trekkingnahrung", "outdoornahrung", "trek nahrung", "trekking mahlzeit", "outdoor mahlzeit", "expeditionsnahrung", "trockennahrung"], 1, "stk", 5.99, 7.99, 11.99),
        e(["gaskartusche", "campinggas", "schraubkartusche"], 1, "stk", 3.99, 5.99, 9.99),
        e(["stirnlampe", "taschenlampe"], 1, "stk", 7.99, 14.99, 29.99),
        e(["zelt", "wurfzelt"], 1, "stk", 29.99, 59.99, 149.99),
        e(["campingstuhl", "klappstuhl"], 1, "stk", 9.99, 19.99, 39.99),
        e(["rucksack", "wanderrucksack", "tagesrucksack", "sportrucksack"], 1, "stk", 9.99, 19.99, 49.99),
        e(["sporttasche", "turnbeutel"], 1, "stk", 7.99, 14.99, 29.99),
        e(["regenjacke", "funktionsjacke", "softshelljacke", "fleecejacke", "laufjacke"], 1, "stk", 19.99, 34.99, 69.99),
        e(["funktionsshirt", "laufshirt", "sportshirt", "trikot"], 1, "stk", 6.99, 9.99, 19.99),
        e(["leggings", "sporthose", "laufhose", "jogginghose", "radlerhose", "shorts"], 1, "stk", 9.99, 14.99, 29.99),
        e(["mütze", "beanie", "laufmütze", "stirnband"], 1, "stk", 4.99, 7.99, 14.99),
        e(["skibrille"], 1, "stk", 14.99, 24.99, 49.99),
        e(["schienbeinschoner", "knieschoner", "protektoren"], 1, "stk", 4.99, 9.99, 19.99),
        e(["kletterkreide", "magnesia", "chalk"], 1, "stk", 3.99, 5.99, 9.99),
        e(["sonnenbrille"], 1, "stk", 9.99, 19.99, 39.99),
        e(["frisbee", "wurfscheibe"], 1, "stk", 3.99, 6.99, 12.99),
        e(["hula hoop", "hulahoop", "hula hoop reifen"], 1, "stk", 4.99, 9.99, 19.99),
        e(["boxhandschuhe"], 1, "stk", 14.99, 24.99, 49.99),
        e(["wanderstöcke", "trekkingstöcke", "nordic walking stöcke"], 1, "stk", 9.99, 19.99, 39.99),
        e(["sporttape", "tapeverband", "kinesiotape", "kinesio tape"], 1, "stk", 3.99, 5.99, 9.99),
        e(["schwimmweste", "rettungsweste"], 1, "stk", 14.99, 24.99, 49.99),
        e(["schienbeinschützer"], 1, "stk", 4.99, 7.99, 14.99),
        e(["torwarthandschuhe"], 1, "stk", 9.99, 19.99, 39.99),
        e(["fahrradventil", "ventileinsatz", "ventilkappen"], 1, "stk", 1.49, 2.49, 3.99),
        e(["campingkocher", "gaskocher"], 1, "stk", 14.99, 24.99, 49.99),
        e(["campinggeschirr", "kochgeschirr", "campingbesteck"], 1, "stk", 7.99, 14.99, 29.99),
        e(["kühltasche", "kühlbox", "kühlakku", "kühlakkus"], 1, "stk", 2.99, 9.99, 29.99),
        e(["picknickdecke", "stranddecke"], 1, "stk", 7.99, 12.99, 24.99),
        e(["regenponcho", "poncho"], 1, "stk", 2.99, 5.99, 14.99),
        e(["sportbandage", "kniebandage", "bandage"], 1, "stk", 7.99, 14.99, 29.99),
    ]

    /// Alle Einträge in Trefferreihenfolge; bei gleich langen Namen gewinnt der frühere Eintrag,
    /// deshalb stehen die Alt-Stichwörter vorn.
    static let entries: [PriceCatalogEntry] = [
        legacy, dairy, meatAndFish, produce, bakery, drinks, frozen, snacks,
        spicesAndBaking, pantry, personalCare, household,
        legacyAliases, foodAdditions, drugstore, householdMore, sports,
    ].flatMap { $0 }
}
