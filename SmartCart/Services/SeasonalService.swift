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

    static func currentSuggestions() -> [Suggestion] {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 3, 4:
            return [
                Suggestion(name: "Spargel",     reason: "Spargelzeit"),
                Suggestion(name: "Erdbeeren",   reason: "Erste Erdbeeren"),
                Suggestion(name: "Spinat",      reason: "Frühlingsspinat"),
                Suggestion(name: "Radieschen",  reason: "Saisonal"),
                Suggestion(name: "Rhabarber",   reason: "Saisonal"),
            ]
        case 5:
            return [
                Suggestion(name: "Spargel",     reason: "Spargelzeit"),
                Suggestion(name: "Erdbeeren",   reason: "Beste Saison"),
                Suggestion(name: "Zucchini",    reason: "Saisonal"),
                Suggestion(name: "Kopfsalat",   reason: "Frühsommer"),
            ]
        case 6, 7, 8:
            return [
                Suggestion(name: "Grillkohle",  reason: "Grillsaison"),
                Suggestion(name: "Tomaten",     reason: "Beste Saison"),
                Suggestion(name: "Paprika",     reason: "Saisonal"),
                Suggestion(name: "Gurken",      reason: "Sommerfrisch"),
                Suggestion(name: "Wassermelone",reason: "Sommer"),
                Suggestion(name: "Basilikum",   reason: "Sommerküche"),
                Suggestion(name: "Zucchini",    reason: "Saisonal"),
                Suggestion(name: "Mais",        reason: "Grillsaison"),
            ]
        case 9, 10:
            return [
                Suggestion(name: "Kürbis",      reason: "Herbstsaison"),
                Suggestion(name: "Champignons", reason: "Pilzsaison"),
                Suggestion(name: "Äpfel",       reason: "Erntezeit"),
                Suggestion(name: "Birnen",      reason: "Saisonal"),
                Suggestion(name: "Rotkohl",     reason: "Herbstgemüse"),
                Suggestion(name: "Kastanien",   reason: "Herbst"),
            ]
        case 11:
            return [
                Suggestion(name: "Clementinen", reason: "Vitamin C"),
                Suggestion(name: "Grünkohl",    reason: "Wintergemüse"),
                Suggestion(name: "Feldsalat",   reason: "Wintersalat"),
                Suggestion(name: "Lebkuchen",   reason: "Vorweihnachtszeit"),
            ]
        case 12:
            return [
                Suggestion(name: "Clementinen", reason: "Vitamin C"),
                Suggestion(name: "Orangen",     reason: "Wintersaison"),
                Suggestion(name: "Glühwein",    reason: "Weihnachtszeit"),
                Suggestion(name: "Lebkuchen",   reason: "Weihnachtszeit"),
                Suggestion(name: "Grünkohl",    reason: "Wintergemüse"),
                Suggestion(name: "Punsch",      reason: "Weihnachtszeit"),
            ]
        case 1, 2:
            return [
                Suggestion(name: "Orangen",     reason: "Wintersaison"),
                Suggestion(name: "Feldsalat",   reason: "Wintersalat"),
                Suggestion(name: "Grünkohl",    reason: "Wintergemüse"),
                Suggestion(name: "Clementinen", reason: "Vitamin C"),
                Suggestion(name: "Lauch",       reason: "Wintergemüse"),
            ]
        default:
            return []
        }
    }
}
