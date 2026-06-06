import SwiftData
import SwiftUI

@Model
class Store {
    var id: UUID
    var name: String
    var emoji: String
    var colorHex: String
    var visitsPerWeek: Double
    var isActive: Bool
    var isPaused: Bool = false
    var categories: [String]
    var countryCode: String
    var isCustom: Bool
    // Learned aisle order: item name -> average completion position
    var itemOrderMap: [String: Double]
    // Learned prices per store: item name (lowercased) -> last confirmed price from receipt
    var learnedPrices: [String: Double]

    @Relationship(deleteRule: .cascade, inverse: \ShoppingItem.store)
    var items: [ShoppingItem] = []

    var shareID: String? {
        get { UserDefaults.standard.string(forKey: "shareID_\(id.uuidString)") }
        set {
            if let v = newValue { UserDefaults.standard.set(v, forKey: "shareID_\(id.uuidString)") }
            else { UserDefaults.standard.removeObject(forKey: "shareID_\(id.uuidString)") }
        }
    }

    var isSharedByMe: Bool {
        get { UserDefaults.standard.bool(forKey: "isSharedByMe_\(id.uuidString)") }
        set { UserDefaults.standard.set(newValue, forKey: "isSharedByMe_\(id.uuidString)") }
    }

    init(
        name: String,
        emoji: String,
        colorHex: String,
        visitsPerWeek: Double = 1.0,
        categories: [String] = [],
        countryCode: String = "DE",
        isCustom: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.visitsPerWeek = visitsPerWeek
        self.isActive = true
        self.isPaused = false
        self.categories = categories
        self.countryCode = countryCode
        self.isCustom = isCustom
        self.itemOrderMap = [:]
        self.learnedPrices = [:]
    }

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    var pendingItems: [ShoppingItem] {
        items.filter { !$0.isCompleted }.sorted { a, b in
            if a.isUrgent != b.isUrgent { return a.isUrgent }
            let posA = itemOrderMap[a.name.lowercased()] ?? 999
            let posB = itemOrderMap[b.name.lowercased()] ?? 999
            return posA < posB
        }
    }

    var completedItems: [ShoppingItem] {
        items.filter { $0.isCompleted }
    }

    func recordCompletionOrder(_ completedNames: [String]) {
        for (index, name) in completedNames.enumerated() {
            let key = name.lowercased()
            if let existing = itemOrderMap[key] {
                itemOrderMap[key] = (existing + Double(index)) / 2.0
            } else {
                itemOrderMap[key] = Double(index)
            }
        }
    }
}

// MARK: - Preset stores per country

extension Store {
    static func presets(for countryCode: String) -> [Store] {
        switch countryCode {
        case "DE":
            return [
                Store(name: "Lidl",     emoji: "🛒", colorHex: "#2563EB", visitsPerWeek: 2, categories: Category.grocery,   countryCode: "DE"), // Blau
                Store(name: "Edeka",    emoji: "🛒", colorHex: "#D97706", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "DE"), // Amber/Gold
                Store(name: "Rewe",     emoji: "🛒", colorHex: "#DC2626", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "DE"), // Rot
                Store(name: "Aldi",     emoji: "🛒", colorHex: "#1E40AF", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "DE"), // Dunkelblau
                Store(name: "DM",       emoji: "🧴", colorHex: "#DB2777", visitsPerWeek: 1, categories: Category.drugstore, countryCode: "DE"), // Pink
                Store(name: "Rossmann", emoji: "🧴", colorHex: "#EA580C", visitsPerWeek: 1, categories: Category.drugstore, countryCode: "DE"), // Orange
                Store(name: "Penny",    emoji: "🛒", colorHex: "#7C3AED", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "DE"), // Lila
                Store(name: "Kaufland", emoji: "🛒", colorHex: "#0F766E", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "DE"), // Teal
                Store(name: "Netto",    emoji: "🛒", colorHex: "#F59E0B", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "DE"), // Amber
                Store(name: "Action",      emoji: "🏷️", colorHex: "#E53935", visitsPerWeek: 1,   categories: Category.variety,   countryCode: "DE"), // Rot
                Store(name: "Müller",     emoji: "🧴", colorHex: "#5B21B6", visitsPerWeek: 1,   categories: Category.drugstore, countryCode: "DE"), // Violett
                Store(name: "Hornbach",   emoji: "🏗️", colorHex: "#E53935", visitsPerWeek: 0.5, categories: Category.hardware,  countryCode: "DE"),
                Store(name: "OBI",        emoji: "🔨", colorHex: "#FF6F00", visitsPerWeek: 0.5, categories: Category.hardware,  countryCode: "DE"),
                Store(name: "Bauhaus",    emoji: "🔧", colorHex: "#1565C0", visitsPerWeek: 0.5, categories: Category.hardware,  countryCode: "DE"),
                Store(name: "Hagebaumarkt", emoji: "🏗️", colorHex: "#4CAF50", visitsPerWeek: 0.5, categories: Category.hardware, countryCode: "DE"),
            ]
        case "AT":
            return [
                Store(name: "Billa",  emoji: "🛒", colorHex: "#DC2626", visitsPerWeek: 2, categories: Category.grocery,   countryCode: "AT"), // Rot
                Store(name: "Spar",   emoji: "🛒", colorHex: "#16A34A", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "AT"), // Grün
                Store(name: "Hofer",  emoji: "🛒", colorHex: "#1D4ED8", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "AT"), // Blau
                Store(name: "Lidl",   emoji: "🛒", colorHex: "#2563EB", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "AT"), // Blau
                Store(name: "DM",     emoji: "🧴", colorHex: "#DB2777", visitsPerWeek: 1, categories: Category.drugstore, countryCode: "AT"), // Pink
                Store(name: "Müller", emoji: "🧴", colorHex: "#EA580C", visitsPerWeek: 1, categories: Category.drugstore, countryCode: "AT"), // Orange
                Store(name: "Action",  emoji: "🏷️", colorHex: "#E53935", visitsPerWeek: 1,   categories: Category.variety,  countryCode: "AT"), // Rot
                Store(name: "Hornbach", emoji: "🏗️", colorHex: "#E53935", visitsPerWeek: 0.5, categories: Category.hardware, countryCode: "AT"),
                Store(name: "OBI",      emoji: "🔨", colorHex: "#FF6F00", visitsPerWeek: 0.5, categories: Category.hardware, countryCode: "AT"),
            ]
        case "CH":
            return [
                Store(name: "Migros", emoji: "🛒", colorHex: "#FF6600", visitsPerWeek: 2, categories: Category.grocery, countryCode: "CH"),
                Store(name: "Coop", emoji: "🛒", colorHex: "#E2001A", visitsPerWeek: 1, categories: Category.grocery, countryCode: "CH"),
                Store(name: "Lidl", emoji: "🛒", colorHex: "#0050AA", visitsPerWeek: 1, categories: Category.grocery, countryCode: "CH"),
                Store(name: "Aldi", emoji: "🛒", colorHex: "#005CA9", visitsPerWeek: 1, categories: Category.grocery, countryCode: "CH"),
                Store(name: "Denner", emoji: "🛒", colorHex: "#E2001A", visitsPerWeek: 1, categories: Category.grocery, countryCode: "CH"),
                Store(name: "DM",       emoji: "🧴", colorHex: "#CC1033", visitsPerWeek: 1,   categories: Category.drugstore, countryCode: "CH"),
                Store(name: "Hornbach", emoji: "🏗️", colorHex: "#E53935", visitsPerWeek: 0.5, categories: Category.hardware,  countryCode: "CH"),
                Store(name: "OBI",      emoji: "🔨", colorHex: "#FF6F00", visitsPerWeek: 0.5, categories: Category.hardware,  countryCode: "CH"),
            ]
        case "US":
            return [
                Store(name: "Walmart", emoji: "🛒", colorHex: "#0071CE", visitsPerWeek: 1, categories: Category.grocery, countryCode: "US"),
                Store(name: "Target", emoji: "🎯", colorHex: "#CC0000", visitsPerWeek: 1, categories: Category.grocery + Category.drugstore, countryCode: "US"),
                Store(name: "Kroger", emoji: "🛒", colorHex: "#0066CC", visitsPerWeek: 2, categories: Category.grocery, countryCode: "US"),
                Store(name: "Whole Foods", emoji: "🌿", colorHex: "#00674B", visitsPerWeek: 1, categories: Category.grocery, countryCode: "US"),
                Store(name: "CVS",        emoji: "💊", colorHex: "#CC0000", visitsPerWeek: 1,   categories: Category.drugstore, countryCode: "US"),
                Store(name: "Walgreens",  emoji: "💊", colorHex: "#E31837", visitsPerWeek: 1,   categories: Category.drugstore, countryCode: "US"),
                Store(name: "Home Depot", emoji: "🏗️", colorHex: "#E53935", visitsPerWeek: 0.5, categories: Category.hardware,  countryCode: "US"),
                Store(name: "Lowe's",     emoji: "🔨", colorHex: "#1565C0", visitsPerWeek: 0.5, categories: Category.hardware,  countryCode: "US"),
            ]
        case "GB":
            return [
                Store(name: "Tesco", emoji: "🛒", colorHex: "#005DA0", visitsPerWeek: 2, categories: Category.grocery, countryCode: "GB"),
                Store(name: "Sainsbury's", emoji: "🛒", colorHex: "#FF7B00", visitsPerWeek: 1, categories: Category.grocery, countryCode: "GB"),
                Store(name: "Asda", emoji: "🛒", colorHex: "#7DC241", visitsPerWeek: 1, categories: Category.grocery, countryCode: "GB"),
                Store(name: "Morrisons", emoji: "🛒", colorHex: "#009BDE", visitsPerWeek: 1, categories: Category.grocery, countryCode: "GB"),
                Store(name: "Lidl", emoji: "🛒", colorHex: "#0050AA", visitsPerWeek: 1, categories: Category.grocery, countryCode: "GB"),
                Store(name: "Boots", emoji: "💊", colorHex: "#003B71", visitsPerWeek: 1,   categories: Category.drugstore, countryCode: "GB"),
                Store(name: "B&Q",   emoji: "🔨", colorHex: "#FF6F00", visitsPerWeek: 0.5, categories: Category.hardware,  countryCode: "GB"),
            ]
        case "BE":
            return [
                Store(name: "Carrefour", emoji: "🛒", colorHex: "#1D4ED8", visitsPerWeek: 2, categories: Category.grocery,   countryCode: "BE"), // Blau
                Store(name: "Delhaize",  emoji: "🦁", colorHex: "#DC2626", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "BE"), // Rot
                Store(name: "Colruyt",   emoji: "🛒", colorHex: "#D97706", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "BE"), // Amber
                Store(name: "Lidl",      emoji: "🛒", colorHex: "#2563EB", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "BE"), // Blau
                Store(name: "Aldi",      emoji: "🛒", colorHex: "#1E40AF", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "BE"), // Dunkelblau
                Store(name: "Okay",      emoji: "🛒", colorHex: "#EA580C", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "BE"), // Orange
                Store(name: "Action",          emoji: "🏷️", colorHex: "#E53935", visitsPerWeek: 1, categories: Category.variety,   countryCode: "BE"), // Rot
                Store(name: "DM",             emoji: "🧴", colorHex: "#DB2777", visitsPerWeek: 1, categories: Category.drugstore, countryCode: "BE"), // Pink
                Store(name: "Di",             emoji: "🧴", colorHex: "#00A651", visitsPerWeek: 1, categories: Category.drugstore, countryCode: "BE"), // Grün
                Store(name: "Carrefour Express", emoji: "🛒", colorHex: "#0050C8", visitsPerWeek: 1,   categories: Category.grocery,  countryCode: "BE"), // Blau
                Store(name: "Brico",    emoji: "🔨", colorHex: "#FF6F00", visitsPerWeek: 0.5, categories: Category.hardware, countryCode: "BE"),
                Store(name: "Hornbach", emoji: "🏗️", colorHex: "#E53935", visitsPerWeek: 0.5, categories: Category.hardware, countryCode: "BE"),
            ]
        case "NL":
            return [
                Store(name: "Albert Heijn", emoji: "🛒", colorHex: "#0072CE", visitsPerWeek: 2, categories: Category.grocery,   countryCode: "NL"), // AH-Blau
                Store(name: "Jumbo",        emoji: "🛒", colorHex: "#D97706", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "NL"), // Gelb/Amber
                Store(name: "Lidl",         emoji: "🛒", colorHex: "#2563EB", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "NL"), // Blau
                Store(name: "Aldi",         emoji: "🛒", colorHex: "#1E40AF", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "NL"), // Dunkelblau
                Store(name: "Action",       emoji: "🏷️", colorHex: "#E53935", visitsPerWeek: 1, categories: Category.variety,   countryCode: "NL"), // Rot (niederländische Kette)
                Store(name: "Plus",         emoji: "🛒", colorHex: "#16A34A", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "NL"), // Grün
                Store(name: "Kruidvat",     emoji: "🧴", colorHex: "#7C3AED", visitsPerWeek: 1, categories: Category.drugstore, countryCode: "NL"), // Lila
                Store(name: "Etos",     emoji: "🧴", colorHex: "#DB2777", visitsPerWeek: 1,   categories: Category.drugstore, countryCode: "NL"), // Pink
                Store(name: "Gamma",    emoji: "🔨", colorHex: "#FF6F00", visitsPerWeek: 0.5, categories: Category.hardware,  countryCode: "NL"),
                Store(name: "Hornbach", emoji: "🏗️", colorHex: "#E53935", visitsPerWeek: 0.5, categories: Category.hardware,  countryCode: "NL"),
            ]
        case "FR":
            return [
                Store(name: "Carrefour",    emoji: "🛒", colorHex: "#1D4ED8", visitsPerWeek: 2, categories: Category.grocery,                    countryCode: "FR"), // Blau
                Store(name: "E.Leclerc",    emoji: "🛒", colorHex: "#0F766E", visitsPerWeek: 1, categories: Category.grocery,                    countryCode: "FR"), // Teal
                Store(name: "Intermarché",  emoji: "🛒", colorHex: "#DC2626", visitsPerWeek: 1, categories: Category.grocery,                    countryCode: "FR"), // Rot
                Store(name: "Lidl",         emoji: "🛒", colorHex: "#2563EB", visitsPerWeek: 1, categories: Category.grocery,                    countryCode: "FR"), // Blau
                Store(name: "Aldi",         emoji: "🛒", colorHex: "#1E40AF", visitsPerWeek: 1, categories: Category.grocery,                    countryCode: "FR"), // Dunkelblau
                Store(name: "Monoprix",     emoji: "🛒", colorHex: "#7C3AED", visitsPerWeek: 1, categories: Category.grocery + Category.drugstore, countryCode: "FR"), // Lila
                Store(name: "Pharmacie",    emoji: "💊", colorHex: "#16A34A", visitsPerWeek: 1,   categories: Category.drugstore, countryCode: "FR"), // Grün
                Store(name: "Leroy Merlin", emoji: "🏗️", colorHex: "#4CAF50", visitsPerWeek: 0.5, categories: Category.hardware,  countryCode: "FR"),
                Store(name: "Castorama",    emoji: "🔨", colorHex: "#1565C0", visitsPerWeek: 0.5, categories: Category.hardware,  countryCode: "FR"),
            ]
        case "IT":
            return [
                Store(name: "Esselunga", emoji: "🛒", colorHex: "#DC2626", visitsPerWeek: 2, categories: Category.grocery,   countryCode: "IT"), // Rot
                Store(name: "Conad",     emoji: "🛒", colorHex: "#D97706", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "IT"), // Amber
                Store(name: "Coop",      emoji: "🛒", colorHex: "#16A34A", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "IT"), // Grün
                Store(name: "Lidl",      emoji: "🛒", colorHex: "#2563EB", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "IT"), // Blau
                Store(name: "Aldi",      emoji: "🛒", colorHex: "#1E40AF", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "IT"), // Dunkelblau
                Store(name: "Farmacia",     emoji: "💊", colorHex: "#16A34A", visitsPerWeek: 1,   categories: Category.drugstore, countryCode: "IT"), // Grün
                Store(name: "Leroy Merlin", emoji: "🏗️", colorHex: "#4CAF50", visitsPerWeek: 0.5, categories: Category.hardware,  countryCode: "IT"),
            ]
        case "ES":
            return [
                Store(name: "Mercadona",     emoji: "🛒", colorHex: "#16A34A", visitsPerWeek: 2, categories: Category.grocery,                    countryCode: "ES"), // Grün
                Store(name: "Carrefour",     emoji: "🛒", colorHex: "#1D4ED8", visitsPerWeek: 1, categories: Category.grocery,                    countryCode: "ES"), // Blau
                Store(name: "Lidl",          emoji: "🛒", colorHex: "#2563EB", visitsPerWeek: 1, categories: Category.grocery,                    countryCode: "ES"), // Blau
                Store(name: "Aldi",          emoji: "🛒", colorHex: "#1E40AF", visitsPerWeek: 1, categories: Category.grocery,                    countryCode: "ES"), // Dunkelblau
                Store(name: "El Corte Inglés", emoji: "🏬", colorHex: "#0F766E", visitsPerWeek: 1, categories: Category.grocery + Category.drugstore, countryCode: "ES"), // Teal
                Store(name: "Farmacia",      emoji: "💊", colorHex: "#16A34A", visitsPerWeek: 1,   categories: Category.drugstore, countryCode: "ES"), // Grün
                Store(name: "Leroy Merlin", emoji: "🏗️", colorHex: "#4CAF50", visitsPerWeek: 0.5, categories: Category.hardware,  countryCode: "ES"),
            ]
        default:
            return []
        }
    }

    static var allPresets: [Store] {
        availableCountries.flatMap { presets(for: $0.code) }
    }

    static let availableCountries: [(code: String, name: String, flag: String)] = [
        ("DE", "Deutschland",      "🇩🇪"),
        ("AT", "Österreich",       "🇦🇹"),
        ("CH", "Schweiz",          "🇨🇭"),
        ("BE", "Belgique / België","🇧🇪"),
        ("NL", "Nederland",        "🇳🇱"),
        ("FR", "France",           "🇫🇷"),
        ("IT", "Italia",           "🇮🇹"),
        ("ES", "España",           "🇪🇸"),
        ("GB", "United Kingdom",   "🇬🇧"),
        ("US", "United States",    "🇺🇸"),
    ]
}

enum Category {
    static let grocery   = ["Lebensmittel", "Obst & Gemüse", "Fleisch & Wurst", "Milchprodukte", "Backwaren", "Tiefkühlkost", "Getränke", "Snacks", "Konserven"]
    static let drugstore = ["Körperpflege", "Kosmetik", "Reinigung", "Medikamente", "Haushalt", "Babybedarf"]
    /// Variety / discount stores (Action, Woolworth, etc.) — general merchandise, small appliances, seasonal, stationery
    static let variety   = ["Haushaltswaren", "Elektronik", "Saisonales", "Schreibwaren", "Werkzeug", "Spielzeug", "Dekoration"]
    static let hardware  = ["Werkzeug", "Baumaterial", "Garten", "Farbe & Lack", "Sanitär"]
}
