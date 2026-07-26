import Foundation
import SwiftData

// Assigns a shopping item to the most appropriate store based on:
// 1. Category match (e.g. drugstore items → DM)
// 2. Past purchase history (learned store preference)
// 3. Visit frequency (frequent items → most-visited store)

struct AssignmentService {

    // MARK: - Category to store-type mapping

    private static let drugstoreKeywords: Set<String> = [
        // Körperpflege
        "shampoo", "conditioner", "duschgel", "seife", "deo", "deodorant",
        "zahnbürste", "zahnpasta", "mundwasser", "rasierer", "rasierklinge",
        "creme", "lotion", "sonnencreme", "lippenpflege", "mascara",
        "wattepads", "wattestäbchen", "pflaster", "paracetamol", "ibuprofen",
        "vitamine", "vitamin", "windeln", "babynahrung", "babyöl",
        "haarspray", "haargel", "parfum", "nagellack", "make-up", "foundation",
        "lippenstift", "zahnbürstenköpfe", "oral", "elektrische zahnbürste", "mundpflege",
        "shower gel", "soap", "toothbrush", "toothpaste", "shaving",
        "sunscreen", "plaster", "vitamins", "diapers",
        // Haar & Körper
        "kamm", "haarbürste", "haarband", "haarnadel", "haargummi",
        "rasierapparat", "rasierschaum", "aftershave", "bartpflege",
        "comb", "hair brush", "hair tie",
        // Haushalt & Reinigung (DM/Rossmann)
        "waschmittel", "spülmittel", "allzweckreiniger", "detergent", "cleaning",
        "toilettenpapier", "küchenrolle", "papiertücher", "tissues", "toilet paper",
        "müllbeutel", "gefrierbeutel", "frischhaltefolie", "alufolie",
        "schwamm", "spülbürste", "scheuertuch", "putztuch",
        "garbage bag", "bin bag", "sponge",
        "handschuh", "gloves",
        // Hygiene
        "tampons", "binden", "kondome", "cotton pads", "zahnseide",
        // Apotheke / Medizin
        "nasenspray", "nasentropfen", "nasengel", "nasenöl", "nasenpflege",
        "augentropfen", "augensalbe", "ohrentropfen",
        "hustensaft", "hustenbonbons", "halstabletten",
        "nasal spray", "eye drops", "nose drops",
    ]

    // Items typically bought at variety/discount stores (Action, Woolworth, etc.)
    private static let varietyStoreKeywords: Set<String> = [
        // Elektro & Beleuchtung
        "ventilator", "lüfter", "heizlüfter", "heizung", "heizgerät", "elektroheizung",
        "lampe", "tischlampe", "stehlampe", "wandlampe", "deckenlampe", "leselampe",
        "nachtlicht", "glühbirne", "leuchtmittel", "led", "led-streifen", "ledstreifen",
        "steckdose", "mehrfachsteckdose", "verlängerungskabel", "steckleiste",
        "stecker", "adapter", "verteiler",
        "batterien", "batterie", "akku", "ladekabel", "ladegerät", "powerbank",
        "kopfhörer", "lautsprecher", "kabel", "timer", "zeitschaltuhr",
        "fan", "heater", "lamp", "bulb", "socket", "extension cord",
        "cable", "batteries", "charger", "headphones", "speaker",
        // Saisonales & Dekoration
        "kerze", "kerzen", "teelicht", "teelichter", "stumpenkerze",
        "lichterkette", "lichterketten", "lichtvorhang",
        "weihnacht", "advent", "adventsdeko", "adventskranz", "adventskalender",
        "halloween", "ostern", "osterdeko", "silvester", "karneval",
        "deko", "dekoration", "girlande", "christbaumkugel", "weihnachtsbaum",
        "ballon", "luftballon", "wimpelkette", "partydeko",
        "bilderrahmen", "wandbild", "poster", "bilderleiste",
        "vase", "schale", "figur", "skulptur", "statue",
        "wanduhr", "wecker", "uhr",
        "candle", "tealight", "christmas", "decoration", "garland",
        // Garten & Pflanzen
        "gießkanne", "blumentopf", "pflanzgefäß", "pflanzkübel",
        "blumenerde", "pflanzerde", "erde", "kompost",
        "gartenwerkzeug",
        "pflanzenstab", "rankgitter", "blumenstab",
        "insektenschutz", "fliegengitter", "mückenschutz",
        "watering can", "flower pot", "garden tool",
        // Schreibwaren & Büro
        "notizbuch", "heft", "schreibheft", "collegeblock", "ringbuch",
        "ordner", "aktenordner", "hängeregister",
        "kugelschreiber", "stift", "bleistift", "buntstift",
        "filzstift", "marker", "textmarker",
        "klebeband", "tesa", "schere", "lineal", "zirkel",
        "heftklammer", "büroklammer", "locher", "tacker",
        "briefumschlag", "briefpapier",
        "notebook", "pen", "pencil", "scissors", "tape",
        // Werkzeug & DIY (Kleinartikel, nicht Baumarkt)
        "kleber", "sekundenkleber", "pattex",
        "abklebeband",
        "screwdriver", "glue",
        // Aufbewahrung & Organisation
        "aufbewahrungsbox", "aufbewahrungskiste", "aufbewahrungskorb",
        "kiste", "truhe", "organizer", "einsatz",
        "regal", "wandregal", "steckregal", "ablage",
        "hakenleiste", "haken", "wandhaken",
        "wäschekorb", "wäscheständer", "trockenständer",
        "storage box", "basket", "shelf", "hook",
        // Textilien (Haushalt, keine Kleidung)
        "tischdecke", "tischläufer", "tischset", "untersetzer",
        "geschirrtuch", "küchentuch", "wischlappen",
        "kissen", "kissenbezug", "kissenhülle",
        "bettwäsche", "bettbezug", "bettlaken", "kopfkissenbezug",
        "handtuch", "badetuch", "gästehandtuch", "waschlappen",
        "vorhang", "gardine", "scheibengardine", "jalousie",
        "tablecloth", "tea towel", "cushion", "pillow", "towel", "curtain",
        // Spielzeug & Spiele
        "spielzeug", "spielzeuge", "puzzle", "brettspiel",
        "spielkarten", "kartenspiel", "würfelspiel",
        "lego", "playmobil", "baustein",
        "toy", "board game", "playing cards",
        // Küchenausstattung (keine Lebensmittel)
        "kochtopf", "suppentopf", "pfanne", "wok",
        "schüssel", "rührschüssel", "salatschüssel",
        "sieb", "abtropfsieb", "schneebesen", "küchenhelfer",
        "schneidebrett", "reibe", "sparschäler", "dosenöffner",
        "küchenwaage", "messbecher", "backform", "kuchenform",
        "tortenplatte", "auflaufform", "bratpfanne",
        "pot", "pan", "bowl", "chopping board", "whisk", "grater",
        // Haushaltswaren (Einweg/Plastik/Verbrauch)
        "servietten", "einwegbecher", "plastikbecher", "pappteller",
        "einwegteller", "einwegbesteck",
        "haushaltsbeutel", "plastikdose", "vorratsdose", "frischhaltedose",
        "wäscheklammer", "kleiderbügel", "wäschenetz",
        // Bad & Haushalt (nicht Körperpflege)
        "badezimmer", "toilettenbürste", "klobürste", "wc-bürste",
        "seifenspender", "seifenschale", "zahnputzbecher",
        "handtuchhalter", "toilettenpapierhalter", "klopapierhalter",
        "duschvorhang", "duschvorhangstange",
        "badteppich", "badeteppich", "wc-matte",
        // Reinigungsgeräte (nicht Reinigungsmittel)
        "besen", "kehrbesen", "kehrschaufel", "handfeger",
        "wischmopp", "mopp", "bodenwischer", "staubtuch",
        "staubsauger", "eimer", "putzeimer",
        "broom", "mop", "dustpan", "bucket",
        // Auto & Fahrrad (Kleinartikel)
        "autohalterung", "handyhalterung", "autoladekabel", "kfz",
        "fahrradschloss", "fahrradkorb", "fahrradpumpe",
        // Sonstiges Haushalt
        "spiegel", "wandspiegel", "badespiegel",
        "türstopper", "türkeil", "türschild",
        "briefkasten", "namensschild",
        "mülleimer", "abfalleimer", "abfallbehälter",
        "schirmständer", "regenschirmständer",
        // Grill & Outdoor
        "grillkohle", "grillbriketts", "briketts", "holzkohle",
        "grillanzünder", "anzünder", "feueranzünder",
        "grillrost", "grillzange", "grillhandschuh",
        "grillschale", "grillschalen", "aluschale",
        "grillspiess", "grillspieß", "grillbesteck",
        "grillthermometer", "grillabdeckung",
        "campingkocher", "campinggas", "gaskartusche",
        "feuerschale", "grill",
    ]

    private static let hardwareStoreKeywords: Set<String> = [
        // Handwerkzeug
        "hammer", "zange", "schraubenzieher", "schrauber", "akkuschrauber",
        "meißel", "stemmeisen", "feile", "raspel", "säge", "stichsäge",
        "kreissäge", "handsäge", "laubsäge", "fuchsschwanz",
        "winkelschleifer", "bandschleifer", "schwingschleifer", "schleifer",
        "bohrmaschine", "bohrschrauber", "schlagbohrmaschine",
        "wasserwaage", "zollstock", "massband", "maßband", "winkelmesser",
        "cutter", "teppichmesser", "abbrechmesser",
        "spachtel", "fugenspachtel", "glattspachtel",
        // Gartengeräte (groß / professionell)
        "schaufel", "spaten", "harke", "rechen", "hacke", "grabegabel",
        "rasenmäher", "heckenschere", "astschere", "gartenschere",
        "motorsäge", "kettensäge", "freischneider", "rasentrimmer",
        "gartenschlauch", "bewässerungsschlauch", "sprinkler", "tropfschlauch",
        "hochdruckreiniger", "gartenpumpe",
        "komposttonne", "regentonne", "regentonnen",
        // Baumaterial
        "schrauben", "schraube", "dübel", "nägel", "nagel", "bolzen", "anker",
        "fliese", "fliesen", "klinker", "pflasterstein", "terrassenplatte",
        "laminat", "parkett", "dielenboden", "vinylboden", "teppichboden",
        "gips", "zement", "mörtel", "beton", "betonmix",
        "dämmung", "isolierung", "styropor", "glaswolle", "steinwolle",
        "rigipsplatte", "gipskarton", "spanplatte", "mdf", "sperrholz",
        "dachpappe", "bitumen", "fugenmasse", "silikon",
        "mauerfarbe", "dispersionsfarbe", "wandfarbe", "deckenfarbe",
        "lack", "lasur", "holzschutz", "holzöl", "beize",
        "grundierung", "voranstrich", "klarlack",
        "tapete", "tapetenkleister", "vliestapete", "raufasertapete",
        "malerrolle", "lackrolle", "malerpinsel", "pinsel",
        "malerband", "abdeckband", "malerfolie",
        // Sanitär & Elektroinstallation
        "rohr", "abflussrohr", "abfluss", "siphon",
        "dichtung", "o-ring", "fitting", "muffe", "kupplung",
        "absperrventil", "eckventil", "armatur",
        "lichtschalter", "steckdosenrahmen", "unterputzdose", "hohlwanddose",
        "kabelkanal", "installationsrohr", "wellrohr",
        // Sicherheit & Schutz
        "schutzbrille", "arbeitsbrille", "gehörschutz",
        "schutzhandschuhe", "arbeitshandschuhe", "arbeitskleidung",
        "atemschutz", "staubmaske", "atemschutzmaske",
        "sicherheitsschuhe", "stahlkappe",
        // Englisch
        "drill", "saw", "pliers",
        "shovel", "spade", "rake", "hoe", "lawnmower",
        "paint", "varnish", "lacquer", "plaster", "cement",
        "screw", "nail", "bolt", "anchor", "rawlplug",
        "pipe", "fitting", "sealant",
    ]

    // German compound word endings that almost always indicate non-food variety items
    private static let nonFoodCompoundEndings: [String] = [
        "gerät", "apparat", "maschine", "automat",
        "leuchte", "lampe", "licht", "birne",
        "kabel", "stecker", "schalter", "halter", "ständer",
        "rahmen", "korb", "eimer", "kiste", "behälter",
        "werkzeug", "schneider", "zange", "messer",
        "bürste",
    ]

    private static let highFrequencyFoodKeywords: Set<String> = [
        "brot", "brötchen", "toast", "milch", "butter", "eier", "käse",
        "joghurt", "quark", "sahne", "obst", "gemüse", "salat", "tomaten",
        "kartoffeln", "zwiebeln", "bananen", "äpfel", "orangen", "karotten",
        "gurken", "paprika", "zucchini", "pilze", "spinat", "aufschnitt",
        "wurst", "schinken", "hackfleisch", "hähnchen", "fleisch", "fisch",
        "bread", "milk", "eggs", "cheese", "yogurt", "fruit", "vegetables",
        "salad", "tomatoes", "potatoes", "onions", "bananas", "apples",
        "chicken", "meat", "fish",
    ]

    // MARK: - Assign store

    static func dominantStore(for itemName: String, in stores: [Store], purchaseRecords: [PurchaseRecord]) -> Store? {
        let relevant = purchaseRecords.filter {
            $0.itemName.lowercased() == itemName.lowercased()
        }
        guard relevant.count >= 1 else { return nil }

        var counts: [String: Int] = [:]
        for record in relevant {
            counts[record.storeName, default: 0] += 1
        }

        let total = relevant.count
        guard let (dominantName, dominantCount) = counts.max(by: { $0.value < $1.value }),
              Double(dominantCount) / Double(total) > 0.5 else { return nil }

        return stores.first { $0.name.lowercased() == dominantName.lowercased() }
    }

    static func assign(itemName: String, to activeStores: [Store], purchaseRecords: [PurchaseRecord] = []) -> Store? {
        guard !activeStores.isEmpty else { return nil }

        let nameLower = itemName.lowercased()

        // 0. History-based: if a dominant store is found, use it
        if let dominant = dominantStore(for: itemName, in: activeStores, purchaseRecords: purchaseRecords) {
            return dominant
        }

        // 1. Hardware/DIY items → hardware store, variety store as fallback
        let isHardware = hardwareStoreKeywords.contains(where: { nameLower.contains($0) })
        if isHardware {
            let hardwareStores = activeStores.filter { $0.categories.contains(where: { Category.hardware.contains($0) }) }
            if let best = hardwareStores.max(by: { $0.visitsPerWeek < $1.visitsPerWeek }) {
                return best
            }
            // No hardware store → fall through to variety
            let varietyFallback = activeStores.filter { $0.categories.contains(where: { Category.variety.contains($0) }) }
            if let best = varietyFallback.max(by: { $0.visitsPerWeek < $1.visitsPerWeek }) {
                return best
            }
        }

        // 2. Variety/discount store items → variety store
        let isVariety = varietyStoreKeywords.contains(where: { nameLower.contains($0) })
            || nonFoodCompoundEndings.contains(where: { nameLower.hasSuffix($0) })
        if isVariety {
            let varietyStores = activeStores.filter { store in
                store.categories.contains(where: { Category.variety.contains($0) })
            }
            if let best = varietyStores.max(by: { $0.visitsPerWeek < $1.visitsPerWeek }) {
                return best
            }
        }

        // 3. Drugstore items → drugstore-type store (DM, Rossmann, etc.)
        let isDrugstore = drugstoreKeywords.contains(where: { nameLower.contains($0) })
        if isDrugstore {
            let drugstores = activeStores.filter { store in
                store.categories.contains(where: { Category.drugstore.contains($0) })
                    && !store.categories.contains(where: { Category.grocery.contains($0) })
            }
            if let best = drugstores.max(by: { $0.visitsPerWeek < $1.visitsPerWeek }) {
                return best
            }
        }

        // 3. High-frequency food → store with highest visit frequency
        let isFrequentFood = highFrequencyFoodKeywords.contains(where: { nameLower.contains($0) })
        if isFrequentFood {
            let groceryStores = activeStores.filter { store in
                store.categories.contains(where: { Category.grocery.contains($0) })
            }
            return groceryStores.max(by: { $0.visitsPerWeek < $1.visitsPerWeek })
        }

        // 4. Default: highest-frequency grocery store
        let groceryStores = activeStores.filter { store in
            store.categories.contains(where: { Category.grocery.contains($0) })
        }
        if let best = groceryStores.max(by: { $0.visitsPerWeek < $1.visitsPerWeek }) {
            return best
        }

        return activeStores.first
    }

    static let categoryOrder = [
        "Obst & Gemüse", "Fleisch & Wurst", "Milchprodukte", "Backwaren",
        "Getränke", "Tiefkühlkost", "Snacks", "Gewürze & Backen", "Konserven", "Lebensmittel",
        "Körperpflege", "Reinigung", "Medikamente", "Babybedarf", "Haushaltswaren",
        "Küchenausstattung", "Elektronik", "Textilien", "Schreibwaren", "Spielzeug",
        "Dekoration", "Werkzeug", "Garten", "Farbe & Lack", "Sanitär", "Baumaterial"
    ]

    /// Localized label for a raw category value — display only. The raw value itself
    /// (`categoryOrder`, `categoryMap`, everything `category(for:)` returns) must never be
    /// translated: it's persisted on `ShoppingItem.category` and used for sorting/grouping.
    static func displayCategory(_ category: String) -> String {
        switch category {
        case "Obst & Gemüse":     return String(localized: "category.fruitveg")
        case "Fleisch & Wurst":   return String(localized: "category.meat")
        case "Milchprodukte":     return String(localized: "category.dairy")
        case "Backwaren":         return String(localized: "category.bakery")
        case "Getränke":          return String(localized: "category.drinks")
        case "Tiefkühlkost":      return String(localized: "category.frozen")
        case "Snacks":            return String(localized: "category.snacks")
        case "Gewürze & Backen":  return String(localized: "category.spicesbaking")
        case "Konserven":         return String(localized: "category.canned")
        case "Lebensmittel":      return String(localized: "category.groceries")
        case "Körperpflege":      return String(localized: "category.personalcare")
        case "Reinigung":         return String(localized: "category.cleaning")
        case "Medikamente":       return String(localized: "category.medicine")
        case "Babybedarf":        return String(localized: "category.baby")
        case "Haushaltswaren":    return String(localized: "category.household")
        case "Küchenausstattung": return String(localized: "category.kitchenware")
        case "Elektronik":        return String(localized: "category.electronics")
        case "Textilien":         return String(localized: "category.textiles")
        case "Schreibwaren":      return String(localized: "category.stationery")
        case "Spielzeug":         return String(localized: "category.toys")
        case "Dekoration":        return String(localized: "category.decor")
        case "Werkzeug":          return String(localized: "category.tools")
        case "Garten":            return String(localized: "category.garden")
        case "Farbe & Lack":      return String(localized: "category.paint")
        case "Sanitär":           return String(localized: "category.plumbing")
        case "Baumaterial":       return String(localized: "category.building")
        default:                  return category
        }
    }

    static func categoryEmoji(_ category: String) -> String {
        switch category {
        case "Obst & Gemüse":     return "🥦"
        case "Fleisch & Wurst":   return "🥩"
        case "Milchprodukte":     return "🥛"
        case "Backwaren":         return "🍞"
        case "Getränke":          return "🥤"
        case "Tiefkühlkost":      return "❄️"
        case "Snacks":            return "🍿"
        case "Gewürze & Backen":  return "🧂"
        case "Konserven":         return "🍝"
        case "Lebensmittel":      return "🛒"
        case "Körperpflege":      return "🧴"
        case "Reinigung":         return "🧹"
        case "Medikamente":       return "💊"
        case "Babybedarf":        return "🍼"
        case "Haushaltswaren":    return "🏠"
        case "Küchenausstattung": return "🍳"
        case "Elektronik":        return "⚡️"
        case "Textilien":         return "👕"
        case "Schreibwaren":      return "✏️"
        case "Spielzeug":         return "🎮"
        case "Dekoration":        return "🪴"
        case "Werkzeug":          return "🔧"
        case "Garten":            return "🌱"
        case "Farbe & Lack":      return "🎨"
        case "Sanitär":           return "🚿"
        case "Baumaterial":       return "🏗️"
        default:                  return "🏷️"
        }
    }

    static func category(for itemName: String) -> String {
        let nameLower = itemName.lowercased()

        if hardwareStoreKeywords.contains(where: { nameLower.contains($0) }) {
            return detectHardwareCategory(nameLower)
        }
        if varietyStoreKeywords.contains(where: { nameLower.contains($0) })
            || nonFoodCompoundEndings.contains(where: { nameLower.hasSuffix($0) }) {
            return detectVarietyCategory(nameLower)
        }

        if drugstoreKeywords.contains(where: { nameLower.contains($0) }) {
            return detectDrugstoreCategory(nameLower)
        }

        let categoryMap: [(keywords: [String], category: String)] = [
            // Obst & Gemüse
            (["obst", "gemüse", "salat", "fruit", "vegetable",
              // Früchte
              "apfel", "äpfel", "birne", "birnen", "banane", "bananen",
              "orange", "orangen", "zitrone", "limette", "grapefruit",
              "mango", "ananas", "traube", "weintraube", "erdbeere",
              "heidelbeere", "blaubeere", "himbeere", "brombeere",
              "kirsche", "kirschen", "pfirsich", "nektarine", "pflaume",
              "aprikose", "kiwi", "melone", "wassermelone", "avocado",
              "papaya", "clementine", "mandarine", "feige", "granatapfel",
              "johannisbeere", "stachelbeere", "mirabelle",
              // Gemüse
              "tomate", "tomaten", "gurke", "gurken", "paprika", "paprikaschote",
              "zwiebel", "zwiebeln", "schalotte", "lauchzwiebel", "frühlingszwiebel",
              "karotte", "karotten", "möhre", "möhren", "pastinake",
              "kartoffel", "kartoffeln", "süßkartoffel", "zucchini",
              "brokkoli", "blumenkohl", "rotkohl", "weißkohl", "rosenkohl",
              "spitzkohl", "pak choi", "kohlrabi", "grünkohl",
              "spinat", "mangold", "rucola", "feldsalat", "kopfsalat",
              "eisbergsalat", "romana", "lauch", "porree", "sellerie",
              "fenchel", "rote bete", "rübe", "steckrübe", "spargel",
              "radieschen", "rettich", "kürbis", "aubergine", "artischocke",
              "champignon", "pilze", "pilz", "steinpilz", "pfifferling",
              "knoblauch", "ingwer", "chili", "chilischote", "jalapeño",
              "erbsen", "bohnen", "zuckerschoten", "edamame",
              "petersilie", "schnittlauch", "koriander", "dill", "basilikum",
              "minze", "thymian", "rosmarin",
              // Englisch
              "apple", "banana", "tomato", "potato", "cucumber", "pepper",
              "onion", "carrot", "garlic", "mushroom", "spinach", "broccoli",
              "lettuce", "cabbage", "zucchini", "courgette", "eggplant",
              "aubergine", "avocado", "strawberry", "blueberry", "raspberry"],
             "Obst & Gemüse"),

            // Fleisch & Wurst
            (["fleisch", "wurst", "hähnchen", "rind", "schwein",
              "meat", "chicken", "beef", "pork",
              "hackfleisch", "faschiertes", "gulasch", "steak", "schnitzel",
              "kotelett", "filet", "keule", "braten", "geschnetzeltes",
              "pute", "putenbrust", "truthahn", "hühnerbrust", "hühnerfilet",
              "hähnchenflügel", "hähnchenkeule", "hähnchenbrust",
              "lamm", "lammkeule", "lammkotelett", "lammfleisch",
              "fisch", "lachs", "thunfisch", "garnelen", "shrimps", "crevetten",
              "scholle", "dorsch", "kabeljau", "forelle", "makrele",
              "fischfilet", "fischstäbchen",
              "leberkäse", "leberkas", "leberkässemmel",
              "aufschnitt", "mortadella", "salami", "leberwurst",
              "würstchen", "bratwurst", "currywurst", "blutwurst",
              "speck", "schinken", "rohschinken", "kochschinken",
              "weißwurst", "wiener", "frankfurter",
              "jagdwurst", "cervelat", "mettwurst", "teewurst", "bierschinken",
              "fish", "salmon", "tuna", "shrimp", "prawn"],
             "Fleisch & Wurst"),

            // Milchprodukte
            (["milch", "käse", "joghurt", "butter", "sahne", "quark",
              "milk", "cheese", "yogurt", "cream",
              "mozzarella", "parmesan", "gouda", "emmentaler", "brie",
              "camembert", "feta", "frischkäse", "hüttenkäse", "ricotta",
              "mascarpone", "gorgonzola", "gruyère", "edamer", "tilsiter",
              "skyr", "kefir", "buttermilch", "dickmilch",
              "schmand", "crème fraîche", "cremefraiche", "creme fraiche",
              "sauerrahm", "kaffeesahne", "schlagsahne", "joghurtdrink",
              "molke", "halbfett", "magerquark"],
             "Milchprodukte"),

            // Backwaren
            (["brot", "brötchen", "toast", "croissant", "bread", "roll",
              "backware", "kuchen", "cake",
              "vollkornbrot", "sauerteigbrot", "roggenbrot", "weißbrot",
              "mischbrot", "dinkelbrot", "körnerbrot", "baguette",
              "ciabatta", "focaccia", "pita", "tortilla", "fladenbrot",
              "laugenbrezel", "laugenstange", "laugenbrötchen",
              "bagel", "knäckebrot", "zwieback", "waffel", "waffeln",
              "muffin", "muffins", "keks", "kekse", "plätzchen",
              "lebkuchen", "stollen", "gugelhupf", "hefezopf", "brioche",
              "brezel", "bretzel", "salzbrezel", "baguette"],
             "Backwaren"),

            // Getränke (vor Tiefkühlkost, damit "eistee" → Getränke)
            (["wasser", "saft", "cola", "bier", "wein", "kaffee", "tee",
              "water", "juice", "beer", "wine", "coffee", "tea", "drink", "getränk",
              "mineralwasser", "sprudelwasser", "stilles wasser",
              "limonade", "limo", "schorle", "apfelschorle",
              "orangensaft", "apfelsaft", "traubensaft", "tomatensaft",
              "multivitaminsaft", "nektar", "smoothie", "eistee",
              "energydrink", "energy drink", "iso", "sportdrink",
              "espresso", "cappuccino", "latte macchiato", "milchkaffee",
              "kakao", "heiße schokolade", "chai",
              "grüntee", "schwarztee", "kräutertee", "früchtetee",
              "sekt", "prosecco", "champagner",
              "schnaps", "whisky", "whiskey", "vodka", "rum", "gin", "likör",
              "glühwein", "radler", "weizenbier", "pils", "lager", "helles",
              "rotwein", "weißwein", "rosé", "malzbier",
              "fanta", "sprite", "pepsi", "redbull"],
             "Getränke"),

            // Tiefkühlkost
            (["tiefkühl", "frozen", "tiefgekühlt", "tk-", "gefroren",
              "ice cream", "pizza", "pommes",
              "eis ", "eisbecher", "eiscreme", "speiseeis",
              "fischstäbchen", "fischfilet", "nuggets", "chicken nuggets",
              "kroketten", "rösti", "schnitzel (tk)", "baguette (tk)",
              "tiefkühlgemüse", "tiefkühlpizza", "tiefkühlkost"],
             "Tiefkühlkost"),

            // Snacks & Süßes
            (["chips", "nüsse", "schokolade", "gummibären", "kekse", "snack",
              "nuts", "chocolate", "candy", "cookies",
              "erdnüsse", "cashews", "mandeln", "walnüsse", "haselnüsse",
              "pistazien", "pinienkerne", "macadamia", "studentenfutter",
              "popcorn", "cracker", "salzstangen", "reiswaffel", "reiskuchen",
              "müsliriegel", "schokoriegel", "praline", "pralinen",
              "gummiwürmer", "weingummi", "haribo", "marshmallows",
              "kaugummi", "bonbon", "lutschbonbon", "karamell",
              "twix", "snickers", "bounty", "milka", "kitkat", "raffaello"],
             "Snacks"),

            // Gewürze & Backen
            (["gewürz", "gewürze", "spice", "herb",
              "salz", "meersalz", "kochsalz", "fleur de sel",
              "pfeffer", "schwarzer pfeffer", "weißer pfeffer",
              "paprikapulver", "kurkuma", "curry", "zimt", "muskat", "muskatnuss",
              "oregano", "thymian", "rosmarin", "majoran", "estragon",
              "kümmel", "kreuzkümmel", "fenchelsamen", "anis", "nelken",
              "kardamom", "vanille", "vanillezucker", "vanillinzucker",
              "lorbeer", "safran", "chiliflakes", "cayennepfeffer",
              "backpulver", "natron", "hefe", "trockenhefe", "frischhefe",
              "speisestärke", "gelfix", "agar", "gelatine",
              "zucker", "puderzucker", "rohrzucker", "birkenzucker", "kokosblütenzucker",
              "backkakaopulver", "kakaopulver", "kakao (pulver)"],
             "Gewürze & Backen"),

            // Grundnahrungsmittel / Konserven
            (["nudeln", "reis", "pasta", "rice", "öl", "oil",
              "essig", "vinegar", "konserv", "dosen", "sauce",
              "spaghetti", "penne", "fusilli", "rigatoni", "farfalle",
              "tagliatelle", "linguine", "gnocchi", "lasagne",
              "couscous", "bulgur", "hirse", "quinoa", "amaranth",
              "dinkel", "gerste", "grieß", "polenta",
              "haferflocken", "porridge", "cornflakes", "müsli", "granola",
              "mehl", "weizenmehl", "dinkelmehl", "roggenmehl",
              "olivenöl", "rapsöl", "sonnenblumenöl", "kokosöl", "sesamöl",
              "weinessig", "apfelessig", "balsamico", "reisessig",
              "tomatenmark", "tomatensoße", "pelati", "passierte tomaten",
              "brühe", "fond", "bouillon", "suppe", "eintopf",
              "ketchup", "senf", "mayonnaise", "bbq", "sriracha",
              "sojasauce", "teriyaki", "soße", "dressing", "pesto",
              "marmelade", "konfitüre", "gelee", "aufstrich",
              "nuss-nougat", "erdnussbutter", "mandelmus", "tahini",
              "honig", "sirup", "agavensirup", "ahornsirup",
              "thunfisch (dose)", "sardinen (dose)", "mais (dose)",
              "kidneybohnen", "kichererbsen (dose)", "linsen (dose)",
              "fertiggericht", "instantnudeln", "ramen"],
             "Konserven"),
        ]

        // Pick the category whose matched keyword is the longest (most specific),
        // scanning across ALL entries rather than stopping at the first array match.
        // This avoids false positives from short/bare substrings (e.g. "wein" inside
        // "weingummi", "bier" inside "bierschinken", "tee" inside "teewurst") beating
        // a longer, more specific keyword listed under the correct category, purely
        // because that category happens to come first in `categoryMap`.
        var bestMatch: (keyword: String, category: String)?
        for entry in categoryMap {
            for keyword in entry.keywords where nameLower.contains(keyword) {
                if bestMatch == nil || keyword.count > bestMatch!.keyword.count {
                    bestMatch = (keyword, entry.category)
                }
            }
        }
        if let bestMatch {
            return bestMatch.category
        }

        return "Lebensmittel"
    }

    private static func detectHardwareCategory(_ nameLower: String) -> String {
        if ["bohrmaschine", "schrauber", "akkuschrauber", "säge", "schleifer",
            "hammer", "zange", "schraubenzieher", "cutter", "feile"].contains(where: { nameLower.contains($0) }) {
            return "Werkzeug"
        }
        if ["schaufel", "spaten", "harke", "rechen", "hacke", "rasenmäher",
            "heckenschere", "gartenschlauch", "bewässer", "gartenpumpe",
            "komposttonne", "regentonne"].contains(where: { nameLower.contains($0) }) {
            return "Garten"
        }
        if ["farbe", "lack", "lasur", "tapete", "malerrolle", "pinsel",
            "malerband", "spachtel", "grundierung", "klarlack"].contains(where: { nameLower.contains($0) }) {
            return "Farbe & Lack"
        }
        if ["rohr", "siphon", "abfluss", "dichtung", "fitting",
            "ventil", "armatur", "lichtschalter", "kabelkanal"].contains(where: { nameLower.contains($0) }) {
            return "Sanitär"
        }
        if ["schrauben", "schraube", "dübel", "nagel", "bolzen",
            "fliese", "zement", "gips", "mörtel", "laminat",
            "parkett", "dämmung", "isolierung", "silikon"].contains(where: { nameLower.contains($0) }) {
            return "Baumaterial"
        }
        return "Werkzeug"
    }

    private static func detectVarietyCategory(_ nameLower: String) -> String {
        if ["ventilator", "lüfter", "heizlüfter", "lampe", "glühbirne", "led", "steckdose",
            "verlängerungskabel", "batterien", "batterie", "akku", "ladekabel", "ladegerät",
            "kopfhörer", "lautsprecher", "fan", "heater", "lamp", "bulb", "batteries"].contains(where: { nameLower.contains($0) }) {
            return "Elektronik"
        }
        if ["kerze", "teelicht", "lichterkette", "deko", "dekoration", "girlande",
            "weihnacht", "advent", "halloween", "ballon", "candle", "decoration"].contains(where: { nameLower.contains($0) }) {
            return "Dekoration"
        }
        if ["schraubenzieher", "hammer", "zange", "bohrer", "schrauben", "dübel",
            "kleber", "screwdriver", "drill"].contains(where: { nameLower.contains($0) }) {
            return "Werkzeug"
        }
        if ["notizbuch", "ordner", "kugelschreiber", "stift", "bleistift", "klebeband",
            "schere", "notebook", "pen", "pencil", "scissors", "tape"].contains(where: { nameLower.contains($0) }) {
            return "Schreibwaren"
        }
        if ["spielzeug", "puzzle", "brettspiel", "spielkarten", "toy", "board game"].contains(where: { nameLower.contains($0) }) {
            return "Spielzeug"
        }
        if ["tischdecke", "kissen", "kissenbezug", "bettwäsche", "handtuch", "geschirrtuch"].contains(where: { nameLower.contains($0) }) {
            return "Textilien"
        }
        if ["topf", "pfanne", "kochtopf", "schüssel", "schneidebrett", "pot", "pan", "bowl"].contains(where: { nameLower.contains($0) }) {
            return "Küchenausstattung"
        }
        return "Haushaltswaren"
    }

    private static func detectDrugstoreCategory(_ nameLower: String) -> String {
        if ["shampoo", "conditioner", "duschgel", "seife", "deo", "haarspray", "shower", "soap", "hair"].contains(where: { nameLower.contains($0) }) {
            return "Körperpflege"
        }
        if ["waschmittel", "spülmittel", "reiniger", "detergent", "cleaning", "handschuh", "gloves"].contains(where: { nameLower.contains($0) }) {
            return "Reinigung"
        }
        if ["pflaster", "paracetamol", "ibuprofen", "vitamin", "medikament", "medicine", "plaster"].contains(where: { nameLower.contains($0) }) {
            return "Medikamente"
        }
        if ["windeln", "babynahrung", "baby", "diapers"].contains(where: { nameLower.contains($0) }) {
            return "Babybedarf"
        }
        return "Körperpflege"
    }
}
