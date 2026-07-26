import Foundation

enum SeasonalService {

    struct Suggestion: Identifiable {
        let id = UUID()
        let name: String
        let reason: String
    }

    static var currentSeason: String {
        switch Calendar.current.component(.month, from: Date()) {
        case 3, 4, 5: return "Frühling"
        case 6, 7, 8: return "Sommer"
        case 9, 10, 11: return "Herbst"
        default: return "Winter"
        }
    }

    static var seasonIcon: String {
        switch currentSeason {
        case "Frühling": return "leaf.fill"
        case "Sommer":   return "sun.max.fill"
        case "Herbst":   return "wind"
        default:         return "snowflake"
        }
    }

    /// Localized banner title (e.g. "Sommerstipps" / "Summer tips"). Kept as its own
    /// lookup rather than string concatenation with `currentSeason`, since `currentSeason`
    /// itself must stay the raw German match/icon-lookup key.
    static var seasonalTitle: String {
        switch currentSeason {
        case "Frühling": return String(localized: "seasonal.title.spring")
        case "Sommer":   return String(localized: "seasonal.title.summer")
        case "Herbst":   return String(localized: "seasonal.title.autumn")
        default:         return String(localized: "seasonal.title.winter")
        }
    }

    static func currentSuggestions() -> [Suggestion] {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 3, 4:
            return [
                Suggestion(name: String(localized: "seasonal.item.asparagus"),    reason: String(localized: "seasonal.reason.asparagusseason")),
                Suggestion(name: String(localized: "seasonal.item.strawberries"), reason: String(localized: "seasonal.reason.firststrawberries")),
                Suggestion(name: String(localized: "seasonal.item.spinach"),      reason: String(localized: "seasonal.reason.springspinach")),
                Suggestion(name: String(localized: "seasonal.item.radishes"),     reason: String(localized: "seasonal.reason.inseason")),
                Suggestion(name: String(localized: "seasonal.item.rhubarb"),      reason: String(localized: "seasonal.reason.inseason")),
            ]
        case 5:
            return [
                Suggestion(name: String(localized: "seasonal.item.asparagus"),    reason: String(localized: "seasonal.reason.asparagusseason")),
                Suggestion(name: String(localized: "seasonal.item.strawberries"), reason: String(localized: "seasonal.reason.peakseason")),
                Suggestion(name: String(localized: "seasonal.item.zucchini"),     reason: String(localized: "seasonal.reason.inseason")),
                Suggestion(name: String(localized: "seasonal.item.lettuce"),      reason: String(localized: "seasonal.reason.earlysummer")),
            ]
        case 6, 7, 8:
            return [
                Suggestion(name: String(localized: "seasonal.item.charcoal"),    reason: String(localized: "seasonal.reason.grillingseason")),
                Suggestion(name: String(localized: "seasonal.item.tomatoes"),    reason: String(localized: "seasonal.reason.peakseason")),
                Suggestion(name: String(localized: "seasonal.item.peppers"),     reason: String(localized: "seasonal.reason.inseason")),
                Suggestion(name: String(localized: "seasonal.item.cucumbers"),   reason: String(localized: "seasonal.reason.summerfresh")),
                Suggestion(name: String(localized: "seasonal.item.watermelon"),  reason: String(localized: "seasonal.reason.summer")),
                Suggestion(name: String(localized: "seasonal.item.basil"),       reason: String(localized: "seasonal.reason.summercooking")),
                Suggestion(name: String(localized: "seasonal.item.zucchini"),    reason: String(localized: "seasonal.reason.inseason")),
                Suggestion(name: String(localized: "seasonal.item.corn"),        reason: String(localized: "seasonal.reason.grillingseason")),
            ]
        case 9, 10:
            return [
                Suggestion(name: String(localized: "seasonal.item.pumpkin"),     reason: String(localized: "seasonal.reason.autumnseason")),
                Suggestion(name: String(localized: "seasonal.item.mushrooms"),   reason: String(localized: "seasonal.reason.mushroomseason")),
                Suggestion(name: String(localized: "seasonal.item.apples"),      reason: String(localized: "seasonal.reason.harvesttime")),
                Suggestion(name: String(localized: "seasonal.item.pears"),       reason: String(localized: "seasonal.reason.inseason")),
                Suggestion(name: String(localized: "seasonal.item.redcabbage"),  reason: String(localized: "seasonal.reason.autumnveg")),
                Suggestion(name: String(localized: "seasonal.item.chestnuts"),   reason: String(localized: "seasonal.reason.autumn")),
            ]
        case 11:
            return [
                Suggestion(name: String(localized: "seasonal.item.clementines"),  reason: String(localized: "seasonal.reason.vitaminc")),
                Suggestion(name: String(localized: "seasonal.item.kale"),         reason: String(localized: "seasonal.reason.winterveg")),
                Suggestion(name: String(localized: "seasonal.item.lambslettuce"), reason: String(localized: "seasonal.reason.wintersalad")),
                Suggestion(name: String(localized: "seasonal.item.gingerbread"),  reason: String(localized: "seasonal.reason.prechristmas")),
            ]
        case 12:
            return [
                Suggestion(name: String(localized: "seasonal.item.clementines"), reason: String(localized: "seasonal.reason.vitaminc")),
                Suggestion(name: String(localized: "seasonal.item.oranges"),     reason: String(localized: "seasonal.reason.winterseason")),
                Suggestion(name: String(localized: "seasonal.item.mulledwine"),  reason: String(localized: "seasonal.reason.christmastime")),
                Suggestion(name: String(localized: "seasonal.item.gingerbread"), reason: String(localized: "seasonal.reason.christmastime")),
                Suggestion(name: String(localized: "seasonal.item.kale"),        reason: String(localized: "seasonal.reason.winterveg")),
                Suggestion(name: String(localized: "seasonal.item.punch"),       reason: String(localized: "seasonal.reason.christmastime")),
            ]
        case 1, 2:
            return [
                Suggestion(name: String(localized: "seasonal.item.oranges"),     reason: String(localized: "seasonal.reason.winterseason")),
                Suggestion(name: String(localized: "seasonal.item.lambslettuce"),reason: String(localized: "seasonal.reason.wintersalad")),
                Suggestion(name: String(localized: "seasonal.item.kale"),        reason: String(localized: "seasonal.reason.winterveg")),
                Suggestion(name: String(localized: "seasonal.item.clementines"), reason: String(localized: "seasonal.reason.vitaminc")),
                Suggestion(name: String(localized: "seasonal.item.leek"),        reason: String(localized: "seasonal.reason.winterveg")),
            ]
        default:
            return []
        }
    }
}
