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

    /// Ein Katalogname trifft, wenn er ein ganzes Wort des Artikelnamens ist oder das Grundwort
    /// eines Kompositums („Laugenbrötchen" → „brötchen", „Kartoffelchips" → „chips"): dafür muss
    /// der Name mindestens 4 Zeichen haben und ein Bestimmungswort von mindestens 3 Zeichen
    /// davorstehen. Mehrwortige Namen müssen als ganze Wortfolge vorkommen.
    static func matches(key: String, tokens: [String], padded: String) -> Bool {
        if key.contains(" ") { return padded.contains(" \(key) ") }
        return tokens.contains { token in
            token == key || (key.count >= 4 && token.count - key.count >= 3 && token.hasSuffix(key))
        }
    }

    /// Bester Eintrag für einen Artikelnamen: bei mehreren Treffern gewinnt der längste Name
    /// („Hafermilch" vor „Milch", „Tomatenmark" vor „Tomaten"), bei gleicher Länge der frühere.
    static func match(_ name: String) -> PriceCatalogEntry? {
        let words = tokens(in: name)
        guard !words.isEmpty else { return nil }
        let padded = " " + words.joined(separator: " ") + " "
        var best: (entry: PriceCatalogEntry, length: Int)?
        for entry in entries {
            for key in entry.names where matches(key: key, tokens: words, padded: padded) {
                if let current = best, current.length >= key.count { continue }
                best = (entry, key.count)
            }
        }
        return best?.entry
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
        e(["schlagsahne", "sahne", "cream"], 200, "g", 0.79, 0.99, 1.39),
        e(["saure sahne", "sauerrahm"], 200, "g", 0.59, 0.79, 1.19),
        e(["schmand"], 200, "g", 0.69, 0.89, 1.29),
        e(["crème fraîche", "creme fraiche", "crème fraiche"], 150, "g", 0.79, 0.99, 1.49),
        e(["parmesan", "parmigiano"], 200, "g", 2.99, 3.99, 5.49),
        e(["grana padano", "grana"], 200, "g", 2.49, 3.29, 4.49),
        e(["gouda", "gauda"], 400, "g", 2.99, 3.79, 4.99),
        e(["emmentaler"], 400, "g", 2.99, 3.99, 4.99),
        e(["edamer", "tilsiter", "butterkäse", "maasdamer"], 400, "g", 2.79, 3.49, 4.49),
        e(["bergkäse", "cheddar"], 300, "g", 3.49, 4.49, 5.99),
        e(["camembert"], 250, "g", 1.69, 2.29, 3.49),
        e(["brie"], 200, "g", 1.79, 2.29, 3.49),
        e(["feta", "schafskäse", "hirtenkäse"], 200, "g", 1.29, 1.99, 2.99),
        e(["frischkäse"], 200, "g", 0.99, 1.49, 2.29),
        e(["hüttenkäse", "körniger frischkäse"], 200, "g", 0.99, 1.29, 1.79),
        e(["quark", "magerquark", "speisequark"], 500, "g", 0.89, 1.19, 1.79),
        e(["skyr"], 450, "g", 1.29, 1.69, 2.29),
        e(["naturjoghurt", "fruchtjoghurt", "griechischer joghurt"], 500, "g", 0.89, 1.19, 1.79),
        e(["buttermilch"], 500, "ml", 0.59, 0.79, 1.19),
        e(["vollmilch", "frischmilch"], 1000, "ml", 0.99, 1.19, 1.59),
        e(["hafermilch", "haferdrink"], 1000, "ml", 1.19, 1.69, 2.49),
        e(["mandelmilch", "mandeldrink"], 1000, "ml", 1.49, 1.99, 2.79),
        e(["sojamilch", "sojadrink"], 1000, "ml", 0.99, 1.49, 2.19),
        e(["kokosmilch"], 400, "ml", 0.99, 1.39, 2.19),
        e(["kondensmilch", "kaffeesahne"], 340, "g", 0.79, 1.09, 1.59),
        e(["margarine"], 500, "g", 1.19, 1.69, 2.49),
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
        e(["forelle", "kabeljau", "seelachs", "fisch", "fischfilet"], 300, "g", 3.49, 4.49, 6.49),
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
        e(["blumenkohl"], 1, "stk", 1.49, 2.29, 3.29),
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
        e(["trauben", "weintrauben"], 500, "g", 1.99, 2.49, 3.49),
        e(["erdbeeren"], 500, "g", 2.49, 3.49, 4.99),
        e(["himbeeren", "heidelbeeren", "blaubeeren", "brombeeren", "beeren"], 125, "g", 1.99, 2.49, 3.49),
        e(["birnen", "birne"], 1000, "g", 1.99, 2.49, 3.49),
        e(["pflaumen", "zwetschgen"], 500, "g", 1.49, 1.99, 2.99),
        e(["kirschen"], 500, "g", 2.99, 3.99, 5.99),
        e(["pfirsiche", "nektarinen", "pfirsich", "nektarine", "aprikosen"], 1000, "g", 2.49, 2.99, 3.99),
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
        e(["bier", "beer", "pils", "weizen", "radler"], 500, "ml", 0.69, 0.99, 1.49),
        e(["wein", "rotwein", "weißwein", "weisswein", "rosé", "rose", "wine"], 750, "ml", 3.49, 4.99, 8.99),
        e(["sekt", "prosecco", "champagner"], 750, "ml", 3.49, 4.99, 8.99),
        e(["apfelsaft", "orangensaft", "multivitaminsaft", "traubensaft"], 1000, "ml", 1.29, 1.79, 2.79),
        e(["apfelschorle", "schorle"], 1000, "ml", 0.79, 1.09, 1.59),
        e(["limonade", "limo", "sprite", "zitronenlimonade"], 1000, "ml", 0.79, 1.19, 1.79),
        e(["mineralwasser", "sprudel", "sprudelwasser", "stilles wasser"], 1000, "ml", 0.29, 0.49, 0.89),
        e(["eistee"], 1500, "ml", 0.99, 1.49, 1.99),
        e(["energy drink", "energydrink", "red bull"], 250, "ml", 0.89, 1.29, 1.69),
        e(["kakao", "kakaopulver", "trinkschokolade"], 500, "g", 2.49, 3.49, 4.99),
        e(["espresso", "kaffeebohnen", "filterkaffee"], 500, "g", 4.99, 6.99, 9.99),
        e(["kaffeepads", "kaffeekapseln", "kapseln"], 1, "stk", 2.49, 3.49, 5.49),
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
        e(["kekse", "butterkekse", "cookies", "keks"], 200, "g", 0.99, 1.49, 2.29),
        e(["salzstangen", "salzbrezeln", "brezeln"], 250, "g", 0.79, 1.09, 1.59),
        e(["popcorn"], 100, "g", 0.99, 1.29, 1.99),
        e(["riegel", "müsliriegel", "proteinriegel"], 1, "stk", 1.49, 1.99, 2.99),
        e(["nutella", "nuss nougat creme", "nussnougatcreme", "schokocreme"], 400, "g", 2.49, 3.29, 4.49),
        e(["schokoriegel", "snickers", "mars", "kitkat", "twix", "duplo", "kinderriegel"], 1, "stk", 0.59, 0.79, 1.19),
        e(["pralinen", "konfekt"], 200, "g", 2.99, 3.99, 5.99),
        e(["studentenfutter", "nussmischung"], 200, "g", 1.99, 2.49, 3.49),
        e(["trockenfrüchte", "rosinen", "datteln", "trockenobst", "cranberries"], 200, "g", 1.49, 1.99, 2.99),
        e(["cracker", "tuc"], 200, "g", 1.29, 1.69, 2.29),
        e(["reiswaffeln", "maiswaffeln"], 130, "g", 0.99, 1.29, 1.79),
        e(["kaugummi", "kaugummis"], 1, "stk", 0.99, 1.29, 1.99),
        e(["bonbons", "hustenbonbons", "lutscher"], 1, "stk", 0.99, 1.49, 2.29),
        e(["tortilla chips", "nachos"], 200, "g", 1.29, 1.79, 2.49),
    ]

    static let spicesAndBaking: [PriceCatalogEntry] = [
        e(["salz", "meersalz", "speisesalz", "jodsalz"], 500, "g", 0.29, 0.49, 0.99),
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
        e(["deo", "deodorant", "deospray", "deoroller"], 1, "stk", 1.99, 2.79, 4.49),
        e(["seife", "handseife", "flüssigseife"], 1, "stk", 0.99, 1.49, 2.49),
        e(["bodylotion", "körperlotion", "creme", "handcreme", "gesichtscreme"], 1, "stk", 1.99, 2.99, 4.99),
        e(["rasierer", "rasierklingen", "einwegrasierer"], 1, "stk", 4.99, 7.99, 12.99),
        e(["rasierschaum", "rasiergel"], 1, "stk", 1.99, 2.79, 3.99),
        e(["tampons", "binden", "slipeinlagen"], 1, "stk", 1.99, 2.99, 4.49),
        e(["taschentücher", "tempo"], 1, "stk", 1.29, 1.79, 2.49),
        e(["küchenrolle", "küchentücher", "küchenpapier"], 1, "stk", 1.99, 2.79, 3.99),
        e(["wattepads", "wattestäbchen", "watte"], 1, "stk", 0.79, 1.19, 1.79),
        e(["mundspülung", "mundwasser"], 1, "stk", 2.49, 3.49, 4.99),
        e(["zahnseide", "interdentalbürsten"], 1, "stk", 1.49, 1.99, 2.99),
        e(["sonnencreme", "sonnenmilch", "sonnenspray"], 1, "stk", 4.99, 7.99, 12.99),
        e(["haarspray", "haargel", "haarwachs", "schaumfestiger"], 1, "stk", 2.49, 3.49, 4.99),
        e(["spülung", "haarspülung", "conditioner", "haarkur"], 1, "stk", 2.49, 3.49, 4.99),
        e(["lippenpflege", "labello", "lippenbalsam"], 1, "stk", 1.29, 1.79, 2.79),
        e(["pflaster", "verbandsmaterial"], 1, "stk", 1.99, 2.79, 3.99),
        e(["windeln", "pampers"], 1, "stk", 7.99, 11.99, 17.99),
        e(["feuchttücher", "babytücher"], 1, "stk", 1.29, 1.79, 2.49),
        e(["ibuprofen", "paracetamol", "aspirin", "schmerztabletten"], 1, "stk", 2.99, 4.49, 6.99),
        e(["nasenspray", "hustensaft", "halstabletten"], 1, "stk", 2.49, 3.99, 5.99),
        e(["vitamine", "vitamin d", "magnesium", "zink"], 1, "stk", 3.99, 5.99, 9.99),
        e(["ohrenstäbchen"], 1, "stk", 0.79, 1.19, 1.79),
        e(["nagellack", "nagellackentferner", "nagelfeile"], 1, "stk", 1.99, 2.99, 4.99),
        e(["gesichtsmaske", "peeling"], 1, "stk", 1.49, 2.49, 3.99),
        e(["make up", "makeup", "mascara", "lippenstift"], 1, "stk", 4.99, 7.99, 12.99),
        e(["kontaktlinsenflüssigkeit", "kontaktlinsen"], 1, "stk", 4.99, 7.99, 12.99),
        e(["kondome"], 1, "stk", 5.99, 8.99, 12.99),
    ]

    static let household: [PriceCatalogEntry] = [
        e(["weichspüler"], 1, "stk", 1.99, 2.79, 3.99),
        e(["spülmaschinentabs", "geschirrspültabs", "spültabs", "geschirrreiniger"], 1, "stk", 4.99, 7.99, 12.99),
        e(["allzweckreiniger", "allesreiniger", "universalreiniger", "reiniger"], 1, "stk", 1.49, 1.99, 2.99),
        e(["glasreiniger", "fensterreiniger"], 1, "stk", 1.49, 1.99, 2.99),
        e(["badreiniger", "kalkreiniger"], 1, "stk", 1.99, 2.49, 3.49),
        e(["wc reiniger", "toilettenreiniger", "wc ente", "klosteine"], 1, "stk", 1.49, 1.99, 2.99),
        e(["schwamm", "schwämme", "spülschwamm", "topfreiniger"], 1, "stk", 0.99, 1.49, 2.29),
        e(["müllbeutel", "mülltüten", "müllsäcke", "gelbe säcke"], 1, "stk", 1.49, 1.99, 2.99),
        e(["alufolie"], 1, "stk", 1.99, 2.49, 3.49),
        e(["frischhaltefolie"], 1, "stk", 1.49, 1.99, 2.79),
        e(["backpapier", "muffinförmchen"], 1, "stk", 1.49, 1.99, 2.79),
        e(["gefrierbeutel", "zipbeutel", "butterbrotpapier"], 1, "stk", 1.29, 1.79, 2.49),
        e(["batterien", "batterie"], 1, "stk", 2.99, 4.99, 7.99),
        e(["glühbirne", "glühlampe", "led lampe", "leuchtmittel"], 1, "stk", 2.99, 4.99, 8.99),
        e(["kerzen", "teelichter", "teelicht", "kerze", "duftkerze"], 1, "stk", 1.99, 2.99, 4.49),
        e(["streichhölzer", "feuerzeug", "feuerzeuge"], 1, "stk", 0.49, 0.99, 1.99),
        e(["entkalker"], 1, "stk", 2.49, 3.49, 4.99),
        e(["fleckentferner", "fleckensalz", "gallseife"], 1, "stk", 2.99, 3.99, 5.49),
        e(["putzlappen", "mikrofasertuch", "mikrofasertücher", "putztücher"], 1, "stk", 1.99, 2.99, 4.49),
        e(["katzenfutter", "nassfutter"], 400, "g", 0.59, 0.89, 1.49),
        e(["hundefutter", "trockenfutter"], 800, "g", 0.99, 1.49, 2.49),
        e(["katzenstreu"], 1, "stk", 3.99, 5.99, 8.99),
        e(["blumen", "blumenstrauß", "tulpen", "rosen", "strauß"], 1, "stk", 2.99, 4.99, 9.99),
        e(["geschenkpapier", "geschenkband"], 1, "stk", 1.99, 2.99, 4.49),
        e(["kaffeefilter", "filtertüten"], 1, "stk", 0.99, 1.49, 2.29),
        e(["servietten"], 1, "stk", 1.29, 1.79, 2.49),
        e(["staubsaugerbeutel"], 1, "stk", 4.99, 7.99, 12.99),
        e(["handschuhe", "gummihandschuhe", "einweghandschuhe"], 1, "stk", 1.49, 2.49, 3.99),
        e(["klarspüler", "spülmaschinensalz", "regeneriersalz"], 1, "stk", 1.49, 2.29, 3.49),
        e(["rohrreiniger", "abflussreiniger"], 1, "stk", 1.99, 2.99, 4.49),
        e(["bügelspray", "wäschestärke", "hygienespüler"], 1, "stk", 1.99, 2.99, 4.49),
        e(["grillkohle", "holzkohle", "grillanzünder"], 1, "stk", 3.99, 5.99, 9.99),
        e(["zahnstocher", "strohhalme", "trinkhalme"], 1, "stk", 0.79, 1.19, 1.79),
        e(["pflanzenerde", "blumenerde"], 1, "stk", 2.99, 4.99, 7.99),
        e(["vogelfutter", "meisenknödel"], 1, "stk", 1.99, 2.99, 4.99),
    ]

    /// Alle Einträge in Trefferreihenfolge; bei gleich langen Namen gewinnt der frühere Eintrag,
    /// deshalb stehen die Alt-Stichwörter vorn.
    static let entries: [PriceCatalogEntry] = [
        legacy, dairy, meatAndFish, produce, bakery, drinks, frozen, snacks,
        spicesAndBaking, pantry, personalCare, household,
    ].flatMap { $0 }
}
