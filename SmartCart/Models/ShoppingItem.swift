import SwiftData
import Foundation
import UIKit

/// Resolves "who is using this device" consistently everywhere identity is shown or recorded
/// (item attribution, assignment, member lists). Backed by the app-group UserDefaults suite —
/// not `.standard` — so out-of-process code (e.g. `AddItemIntent`, which runs in a separate
/// process per the project's Siri/App Intents architecture) sees the same name the main app does.
/// Lives here (Models) rather than in Services because this file is also compiled into the
/// SmartCartWidgets extension target, which doesn't include the Services group.
enum UserIdentity {
    private static let suite = UserDefaults(suiteName: "group.com.johannesemmrich.SmartCart") ?? .standard
    static let storageKey = "userDisplayName"

    /// The user's chosen display name, falling back to the device name if none was set.
    static var displayName: String {
        let name = suite.string(forKey: storageKey) ?? ""
        return name.isEmpty ? UIDevice.current.name : name
    }
}

@Model
class ShoppingItem {
    var id: UUID
    var name: String
    var category: String
    /// True once the user has explicitly picked a category in `EditItemView` that differs from
    /// what `AssignmentService.category(for:)` would auto-detect from the name. Views that group
    /// items by category should respect this: keep re-deriving the category from the name for
    /// everything else (so keyword-rule improvements apply immediately), but never overwrite a
    /// category the user manually chose.
    var categoryManuallySet: Bool = false
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
    var addedBy: String = ""
    /// Display name of whoever checked the item off (empty while pending). Additive field with a
    /// default, like `categoryManuallySet`, so SwiftData lightweight migration handles it without
    /// a schema-version bump. Shown in shared lists ("✓ von X"), synced via `SharedItemData`.
    var completedBy: String = ""
    var lastModified: Date = Date()

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
        self.addedBy = UserIdentity.displayName
        self.lastModified = Date()
        // Use store-specific learned price first (fuzzy: "Hackfleisch" matches "Hackfleisch Gemischt 500g"),
        // then fall back to generic estimator
        let itemLower = name.lowercased()
        let learnedPrice = store?.learnedPrices.first { key, _ in
            key.count >= 3 && itemLower.count >= 3 &&
            (key.contains(itemLower) || itemLower.contains(key))
        }?.value
        self.estimatedPrice = learnedPrice ?? PriceEstimator.estimate(for: name, category: category)
    }

    /// `estimatedPrice` is always a PER-UNIT rate (see the fuzzy `learnedPrices` lookup and
    /// `PriceEstimator` fallback in `init` above — both represent a single-unit price). Every
    /// display or budget-sum site must use this line TOTAL instead of the raw per-unit value,
    /// so e.g. "6 Bier" shows 6× the price of "1 Bier" rather than an identical number.
    /// `quantityAmount` should always be > 0 (see `QuantityStepperField`/`EditItemView.save()`,
    /// which normalize to 1 if parsing yields 0 or less), but guard defensively anyway: a
    /// non-positive quantity falls back to treating the line as a single unit rather than
    /// zeroing out or negating the estimate.
    var estimatedLineTotal: Double? {
        estimatedPrice.map { $0 * (quantityAmount > 0 ? quantityAmount : 1) }
    }

    func markCompleted() {
        isCompleted = true
        completedDate = Date()
        completedBy = UserIdentity.displayName
        lastModified = Date()
        // actualPrice left nil — real prices come from receipt scanning or the manual
        // "Preis eintragen" flow (ActualPriceEntryView) later on, not from estimates
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
        completedBy = ""
        lastModified = Date()
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
