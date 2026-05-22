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
    var categories: [String]
    var countryCode: String
    var isCustom: Bool
    // Learned aisle order: item name -> average completion position
    var itemOrderMap: [String: Double]

    @Relationship(deleteRule: .cascade, inverse: \ShoppingItem.store)
    var items: [ShoppingItem] = []

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
        self.categories = categories
        self.countryCode = countryCode
        self.isCustom = isCustom
        self.itemOrderMap = [:]
    }

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    var pendingItems: [ShoppingItem] {
        items.filter { !$0.isCompleted }.sorted { a, b in
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
                Store(name: "Lidl", emoji: "🛒", colorHex: "#0050AA", visitsPerWeek: 2, categories: Category.grocery, countryCode: "DE"),
                Store(name: "Edeka", emoji: "🛒", colorHex: "#E2001A", visitsPerWeek: 1, categories: Category.grocery, countryCode: "DE"),
                Store(name: "Rewe", emoji: "🛒", colorHex: "#CC0000", visitsPerWeek: 1, categories: Category.grocery, countryCode: "DE"),
                Store(name: "Aldi", emoji: "🛒", colorHex: "#005CA9", visitsPerWeek: 1, categories: Category.grocery, countryCode: "DE"),
                Store(name: "DM", emoji: "🧴", colorHex: "#CC1033", visitsPerWeek: 1, categories: Category.drugstore, countryCode: "DE"),
                Store(name: "Rossmann", emoji: "🧴", colorHex: "#E2001A", visitsPerWeek: 1, categories: Category.drugstore, countryCode: "DE"),
                Store(name: "Penny", emoji: "🛒", colorHex: "#D40000", visitsPerWeek: 1, categories: Category.grocery, countryCode: "DE"),
                Store(name: "Kaufland", emoji: "🛒", colorHex: "#CC0000", visitsPerWeek: 1, categories: Category.grocery, countryCode: "DE"),
            ]
        case "AT":
            return [
                Store(name: "Billa", emoji: "🛒", colorHex: "#E2001A", visitsPerWeek: 2, categories: Category.grocery, countryCode: "AT"),
                Store(name: "Spar", emoji: "🛒", colorHex: "#00843D", visitsPerWeek: 1, categories: Category.grocery, countryCode: "AT"),
                Store(name: "Hofer", emoji: "🛒", colorHex: "#004B9B", visitsPerWeek: 1, categories: Category.grocery, countryCode: "AT"),
                Store(name: "Lidl", emoji: "🛒", colorHex: "#0050AA", visitsPerWeek: 1, categories: Category.grocery, countryCode: "AT"),
                Store(name: "DM", emoji: "🧴", colorHex: "#CC1033", visitsPerWeek: 1, categories: Category.drugstore, countryCode: "AT"),
                Store(name: "Müller", emoji: "🧴", colorHex: "#E2001A", visitsPerWeek: 1, categories: Category.drugstore, countryCode: "AT"),
            ]
        case "CH":
            return [
                Store(name: "Migros", emoji: "🛒", colorHex: "#FF6600", visitsPerWeek: 2, categories: Category.grocery, countryCode: "CH"),
                Store(name: "Coop", emoji: "🛒", colorHex: "#E2001A", visitsPerWeek: 1, categories: Category.grocery, countryCode: "CH"),
                Store(name: "Lidl", emoji: "🛒", colorHex: "#0050AA", visitsPerWeek: 1, categories: Category.grocery, countryCode: "CH"),
                Store(name: "Aldi", emoji: "🛒", colorHex: "#005CA9", visitsPerWeek: 1, categories: Category.grocery, countryCode: "CH"),
                Store(name: "Denner", emoji: "🛒", colorHex: "#E2001A", visitsPerWeek: 1, categories: Category.grocery, countryCode: "CH"),
                Store(name: "DM", emoji: "🧴", colorHex: "#CC1033", visitsPerWeek: 1, categories: Category.drugstore, countryCode: "CH"),
            ]
        case "US":
            return [
                Store(name: "Walmart", emoji: "🛒", colorHex: "#0071CE", visitsPerWeek: 1, categories: Category.grocery, countryCode: "US"),
                Store(name: "Target", emoji: "🎯", colorHex: "#CC0000", visitsPerWeek: 1, categories: Category.grocery + Category.drugstore, countryCode: "US"),
                Store(name: "Kroger", emoji: "🛒", colorHex: "#0066CC", visitsPerWeek: 2, categories: Category.grocery, countryCode: "US"),
                Store(name: "Whole Foods", emoji: "🌿", colorHex: "#00674B", visitsPerWeek: 1, categories: Category.grocery, countryCode: "US"),
                Store(name: "CVS", emoji: "💊", colorHex: "#CC0000", visitsPerWeek: 1, categories: Category.drugstore, countryCode: "US"),
                Store(name: "Walgreens", emoji: "💊", colorHex: "#E31837", visitsPerWeek: 1, categories: Category.drugstore, countryCode: "US"),
            ]
        case "GB":
            return [
                Store(name: "Tesco", emoji: "🛒", colorHex: "#005DA0", visitsPerWeek: 2, categories: Category.grocery, countryCode: "GB"),
                Store(name: "Sainsbury's", emoji: "🛒", colorHex: "#FF7B00", visitsPerWeek: 1, categories: Category.grocery, countryCode: "GB"),
                Store(name: "Asda", emoji: "🛒", colorHex: "#7DC241", visitsPerWeek: 1, categories: Category.grocery, countryCode: "GB"),
                Store(name: "Morrisons", emoji: "🛒", colorHex: "#009BDE", visitsPerWeek: 1, categories: Category.grocery, countryCode: "GB"),
                Store(name: "Lidl", emoji: "🛒", colorHex: "#0050AA", visitsPerWeek: 1, categories: Category.grocery, countryCode: "GB"),
                Store(name: "Boots", emoji: "💊", colorHex: "#003B71", visitsPerWeek: 1, categories: Category.drugstore, countryCode: "GB"),
            ]
        case "BE":
            return [
                Store(name: "Carrefour", emoji: "🛒", colorHex: "#003D8F", visitsPerWeek: 2, categories: Category.grocery, countryCode: "BE"),
                Store(name: "Delhaize", emoji: "🦁", colorHex: "#E2001A", visitsPerWeek: 1, categories: Category.grocery, countryCode: "BE"),
                Store(name: "Colruyt", emoji: "🛒", colorHex: "#E2001A", visitsPerWeek: 1, categories: Category.grocery, countryCode: "BE"),
                Store(name: "Lidl", emoji: "🛒", colorHex: "#0050AA", visitsPerWeek: 1, categories: Category.grocery, countryCode: "BE"),
                Store(name: "Aldi", emoji: "🛒", colorHex: "#005CA9", visitsPerWeek: 1, categories: Category.grocery, countryCode: "BE"),
                Store(name: "Okay", emoji: "🛒", colorHex: "#FF6600", visitsPerWeek: 1, categories: Category.grocery, countryCode: "BE"),
                Store(name: "DM", emoji: "🧴", colorHex: "#CC1033", visitsPerWeek: 1, categories: Category.drugstore, countryCode: "BE"),
            ]
        case "NL":
            return [
                Store(name: "Albert Heijn", emoji: "🛒", colorHex: "#0072CE", visitsPerWeek: 2, categories: Category.grocery, countryCode: "NL"),
                Store(name: "Jumbo", emoji: "🛒", colorHex: "#FFD700", visitsPerWeek: 1, categories: Category.grocery, countryCode: "NL"),
                Store(name: "Lidl", emoji: "🛒", colorHex: "#0050AA", visitsPerWeek: 1, categories: Category.grocery, countryCode: "NL"),
                Store(name: "Aldi", emoji: "🛒", colorHex: "#005CA9", visitsPerWeek: 1, categories: Category.grocery, countryCode: "NL"),
                Store(name: "Plus", emoji: "🛒", colorHex: "#FF6600", visitsPerWeek: 1, categories: Category.grocery, countryCode: "NL"),
                Store(name: "Kruidvat", emoji: "🧴", colorHex: "#6B2D8B", visitsPerWeek: 1, categories: Category.drugstore, countryCode: "NL"),
                Store(name: "Etos", emoji: "🧴", colorHex: "#0072CE", visitsPerWeek: 1, categories: Category.drugstore, countryCode: "NL"),
            ]
        case "FR":
            return [
                Store(name: "Carrefour", emoji: "🛒", colorHex: "#003D8F", visitsPerWeek: 2, categories: Category.grocery, countryCode: "FR"),
                Store(name: "E.Leclerc", emoji: "🛒", colorHex: "#0057A8", visitsPerWeek: 1, categories: Category.grocery, countryCode: "FR"),
                Store(name: "Intermarché", emoji: "🛒", colorHex: "#E2001A", visitsPerWeek: 1, categories: Category.grocery, countryCode: "FR"),
                Store(name: "Lidl", emoji: "🛒", colorHex: "#0050AA", visitsPerWeek: 1, categories: Category.grocery, countryCode: "FR"),
                Store(name: "Aldi", emoji: "🛒", colorHex: "#005CA9", visitsPerWeek: 1, categories: Category.grocery, countryCode: "FR"),
                Store(name: "Monoprix", emoji: "🛒", colorHex: "#E2001A", visitsPerWeek: 1, categories: Category.grocery + Category.drugstore, countryCode: "FR"),
                Store(name: "Pharmacie", emoji: "💊", colorHex: "#009F6B", visitsPerWeek: 1, categories: Category.drugstore, countryCode: "FR"),
            ]
        case "IT":
            return [
                Store(name: "Esselunga", emoji: "🛒", colorHex: "#E2001A", visitsPerWeek: 2, categories: Category.grocery, countryCode: "IT"),
                Store(name: "Conad", emoji: "🛒", colorHex: "#E2001A", visitsPerWeek: 1, categories: Category.grocery, countryCode: "IT"),
                Store(name: "Coop", emoji: "🛒", colorHex: "#E2001A", visitsPerWeek: 1, categories: Category.grocery, countryCode: "IT"),
                Store(name: "Lidl", emoji: "🛒", colorHex: "#0050AA", visitsPerWeek: 1, categories: Category.grocery, countryCode: "IT"),
                Store(name: "Aldi", emoji: "🛒", colorHex: "#005CA9", visitsPerWeek: 1, categories: Category.grocery, countryCode: "IT"),
                Store(name: "Farmacia", emoji: "💊", colorHex: "#009F6B", visitsPerWeek: 1, categories: Category.drugstore, countryCode: "IT"),
            ]
        case "ES":
            return [
                Store(name: "Mercadona", emoji: "🛒", colorHex: "#00843D", visitsPerWeek: 2, categories: Category.grocery, countryCode: "ES"),
                Store(name: "Carrefour", emoji: "🛒", colorHex: "#003D8F", visitsPerWeek: 1, categories: Category.grocery, countryCode: "ES"),
                Store(name: "Lidl", emoji: "🛒", colorHex: "#0050AA", visitsPerWeek: 1, categories: Category.grocery, countryCode: "ES"),
                Store(name: "Aldi", emoji: "🛒", colorHex: "#005CA9", visitsPerWeek: 1, categories: Category.grocery, countryCode: "ES"),
                Store(name: "El Corte Inglés", emoji: "🏬", colorHex: "#006633", visitsPerWeek: 1, categories: Category.grocery + Category.drugstore, countryCode: "ES"),
                Store(name: "Farmacia", emoji: "💊", colorHex: "#009F6B", visitsPerWeek: 1, categories: Category.drugstore, countryCode: "ES"),
            ]
        default:
            return []
        }
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
    static let grocery = ["Lebensmittel", "Obst & Gemüse", "Fleisch & Wurst", "Milchprodukte", "Backwaren", "Tiefkühlkost", "Getränke", "Snacks", "Konserven"]
    static let drugstore = ["Körperpflege", "Kosmetik", "Reinigung", "Medikamente", "Haushalt", "Babybedarf"]
}
