import Foundation
import SwiftData

// Assigns a shopping item to the most appropriate store based on:
// 1. Category match (e.g. drugstore items → DM)
// 2. Past purchase history (learned store preference)
// 3. Visit frequency (frequent items → most-visited store)

struct AssignmentService {

    // MARK: - Category to store-type mapping

    private static let drugstoreKeywords: Set<String> = [
        "shampoo", "conditioner", "duschgel", "seife", "deo", "deodorant",
        "zahnbürste", "zahnpasta", "mundwasser", "rasierer", "rasierklinge",
        "creme", "lotion", "sonnencreme", "lippenpflege", "mascara",
        "wattepads", "wattestäbchen", "pflaster", "paracetamol", "ibuprofen",
        "vitamine", "vitamin", "windeln", "babynahrung", "babyöl",
        "haarspray", "haargel", "parfum", "nagellack", "make-up", "foundation",
        "lippenstift", "waschmittel", "spülmittel", "allzweckreiniger",
        "toilettenpapier", "papiertücher", "tampons", "binden", "kondome",
        "zahnbürstenköpfe", "oral", "elektrische zahnbürste", "mundpflege",
        "shower gel", "soap", "toothbrush", "toothpaste", "shaving",
        "sunscreen", "plaster", "vitamins", "diapers", "detergent",
        "cleaning", "toilet paper", "tissues", "cotton pads",
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

    static func assign(itemName: String, to activeStores: [Store]) -> Store? {
        guard !activeStores.isEmpty else { return nil }

        let nameLower = itemName.lowercased()

        // 1. Check history: if this item was always bought at one store, prefer it
        // (handled externally via HabitService — here we rely on category logic)

        // 2. Category-based: drugstore items → drugstore-type store
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

    static func category(for itemName: String) -> String {
        let nameLower = itemName.lowercased()

        if drugstoreKeywords.contains(where: { nameLower.contains($0) }) {
            return detectDrugstoreCategory(nameLower)
        }

        let categoryMap: [(keywords: [String], category: String)] = [
            (["obst", "gemüse", "salat", "fruit", "vegetable", "apple", "banana", "tomato", "potato", "äpfel", "bananen", "kartoffel"], "Obst & Gemüse"),
            (["fleisch", "wurst", "hähnchen", "rind", "schwein", "fisch", "meat", "chicken", "beef", "pork", "fish", "lachs", "thunfisch"], "Fleisch & Wurst"),
            (["milch", "käse", "joghurt", "butter", "sahne", "quark", "milk", "cheese", "yogurt", "cream"], "Milchprodukte"),
            (["brot", "brötchen", "toast", "croissant", "bread", "roll", "backware", "kuchen", "cake"], "Backwaren"),
            (["tiefkühl", "frozen", "eis", "ice cream", "pizza", "pommes"], "Tiefkühlkost"),
            (["wasser", "saft", "cola", "bier", "wein", "kaffee", "tee", "water", "juice", "beer", "wine", "coffee", "tea", "drink", "getränk"], "Getränke"),
            (["chips", "nüsse", "schokolade", "gummibären", "kekse", "snack", "nuts", "chocolate", "candy", "cookies"], "Snacks"),
            (["nudeln", "reis", "mehl", "pasta", "rice", "flour", "öl", "oil", "essig", "vinegar", "konserv", "dosen", "sauce"], "Konserven"),
        ]

        for entry in categoryMap {
            if entry.keywords.contains(where: { nameLower.contains($0) }) {
                return entry.category
            }
        }

        return "Lebensmittel"
    }

    private static func detectDrugstoreCategory(_ nameLower: String) -> String {
        if ["shampoo", "conditioner", "duschgel", "seife", "deo", "haarspray", "shower", "soap", "hair"].contains(where: { nameLower.contains($0) }) {
            return "Körperpflege"
        }
        if ["waschmittel", "spülmittel", "reiniger", "detergent", "cleaning"].contains(where: { nameLower.contains($0) }) {
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
