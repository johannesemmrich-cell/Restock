import SwiftData
import Foundation

@Model
class ShoppingItem {
    var id: UUID
    var name: String
    var category: String
    var quantity: String
    var quantityAmount: Double
    var unit: String
    var isCompleted: Bool
    var isUrgent: Bool = false
    var addedDate: Date
    var completedDate: Date?
    var note: String
    var estimatedPrice: Double?
    var assignedTo: String = ""

    var store: Store?

    @Relationship(deleteRule: .cascade, inverse: \PurchaseRecord.item)
    var purchaseRecords: [PurchaseRecord] = []

    init(
        name: String,
        category: String = "",
        quantity: String = "1",
        quantityAmount: Double = 1,
        unit: String = "",
        note: String = "",
        store: Store? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.quantity = quantity
        self.quantityAmount = quantityAmount
        self.unit = unit
        self.isCompleted = false
        self.isUrgent = false
        self.addedDate = Date()
        self.note = note
        self.store = store
        // Use store-specific learned price first (fuzzy: "Hackfleisch" matches "Hackfleisch Gemischt 500g"),
        // then fall back to generic estimator
        let itemLower = name.lowercased()
        let learnedPrice = store?.learnedPrices.first { key, _ in
            key.count >= 3 && itemLower.count >= 3 &&
            (key.contains(itemLower) || itemLower.contains(key))
        }?.value
        self.estimatedPrice = learnedPrice ?? PriceEstimator.estimate(for: name, category: category)
    }

    func markCompleted() {
        isCompleted = true
        completedDate = Date()
        // actualPrice left nil — real prices come from receipt scanning only, not estimates
        let record = PurchaseRecord(
            itemName: name,
            storeName: store?.name ?? "",
            quantityAmount: quantityAmount,
            unit: unit,
            actualPrice: nil
        )
        record.item = self
        purchaseRecords.append(record)
    }

    func markPending() {
        isCompleted = false
        completedDate = nil
    }
}

// MARK: - Price estimation

enum PriceEstimator {
    static func estimate(for name: String, category: String) -> Double? {
        let nameLower = name.lowercased()

        // Specific product matches
        let specificPrices: [(keywords: [String], price: Double)] = [
            (["brot", "brötchen", "bread"], 2.50),
            (["milch", "milk"], 1.20),
            (["butter"], 2.20),
            (["eier", "eggs"], 3.00),
            (["käse", "cheese"], 3.50),
            (["joghurt", "yogurt"], 1.50),
            (["shampoo"], 4.50),
            (["duschgel", "shower gel"], 3.00),
            (["zahnbürste", "toothbrush"], 5.00),
            (["zahnpasta", "toothpaste"], 2.50),
            (["waschmittel", "detergent"], 8.00),
            (["spülmittel", "dish soap"], 1.80),
            (["toilettenpapier", "toilet paper"], 4.00),
            (["kaffee", "coffee"], 5.50),
            (["tee", "tea"], 3.00),
            (["wasser", "water"], 0.90),
            (["saft", "juice"], 2.00),
            (["cola", "pepsi", "fanta"], 1.50),
            (["chips", "crisps"], 1.80),
            (["schokolade", "chocolate"], 1.50),
            (["äpfel", "apfel", "apple", "apples"], 2.50),
            (["bananen", "banane", "banana"], 1.80),
            (["tomaten", "tomato"], 2.00),
            (["kartoffeln", "potato"], 2.00),
            (["hähnchen", "chicken"], 4.50),
            (["rinderhack", "hackfleisch", "ground beef"], 4.00),
            (["nudeln", "pasta"], 1.50),
            (["reis", "rice"], 2.00),
        ]

        for entry in specificPrices {
            if entry.keywords.contains(where: { nameLower.contains($0) }) {
                return entry.price
            }
        }

        // Category fallback
        switch category {
        case "Obst & Gemüse": return 2.50
        case "Fleisch & Wurst": return 4.50
        case "Milchprodukte": return 2.00
        case "Backwaren": return 2.00
        case "Tiefkühlkost": return 3.50
        case "Getränke": return 1.50
        case "Snacks": return 1.80
        case "Körperpflege": return 4.00
        case "Kosmetik": return 6.00
        case "Reinigung": return 3.50
        case "Haushalt": return 5.00
        default: return nil
        }
    }
}
