import SwiftData
import Foundation
import UIKit
import WidgetKit

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
    /// `true` when `estimatedPrice` came purely from `PriceEstimator` (catalog/category flat
    /// rate) and can therefore be safely recomputed at any time (unit changes, migrations).
    /// `false` once the price has a real-world origin — a learned receipt price or a manual
    /// entry in `EditItemView` — and must never be silently overwritten again. Additive field
    /// with a default, like `categoryManuallySet`/`completedBy` above, so SwiftData lightweight
    /// migration handles it without a schema-version bump.
    var estimatedPriceIsAutoDerived: Bool = true
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
        self.estimatedPrice = learnedPrice ?? PriceEstimator.estimate(for: name, category: category, unit: unit)
        self.estimatedPriceIsAutoDerived = (learnedPrice == nil)
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
        // Central widget-reload hook: every check-off path in every process funnels through
        // here (StoreDetailView, AllItemsView, pending-checkoff drain, the widget's own
        // intent), so the homescreen widget refreshes no matter who completed the item.
        // The system coalesces repeated calls, so loops over many items are fine.
        WidgetCenter.shared.reloadAllTimelines()
    }

    func markPending() {
        isCompleted = false
        completedDate = nil
        completedBy = ""
        lastModified = Date()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Price estimation

enum PriceEstimator {
    /// The flat prices below (`specificPrices` and the `category` fallback) represent a
    /// "typical package"/kilo/liter price — NOT a per-raw-unit price. For weight/volume units
    /// where `quantityAmount` is a raw small-unit figure (e.g. "750g" → quantityAmount=750,
    /// unit="g"), multiplying the flat price directly by `quantityAmount` in
    /// `ShoppingItem.estimatedLineTotal` would produce an absurd total (750 × 1.50 = 1125€).
    /// So here we convert the flat "per kg/liter" price down to "per raw unit" before returning,
    /// by dividing by how many raw units make up a kilo/liter. Count-based units (kg, l, stk,
    /// "", ...) get divisor 1 — unchanged behavior, since `quantityAmount` there already IS the
    /// count the flat price is meant to multiply against (see the "1 Bier vs 6 Bier" fix).
    private static func unitDivisor(for unit: String) -> Double {
        switch unit.trimmingCharacters(in: .whitespaces).lowercased() {
        case "g", "gramm": return 1000
        case "mg", "milligramm": return 1_000_000
        case "ml", "milliliter": return 1000
        case "cl", "zentiliter": return 100
        case "dl", "deziliter": return 10
        default: return 1
        }
    }

    static func estimate(for name: String, category: String, unit: String) -> Double? {
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

        let divisor = unitDivisor(for: unit)

        for entry in specificPrices {
            if entry.keywords.contains(where: { nameLower.contains($0) }) {
                return entry.price / divisor
            }
        }

        // Category fallback
        switch category {
        case "Obst & Gemüse": return 2.50 / divisor
        case "Fleisch & Wurst": return 4.50 / divisor
        case "Milchprodukte": return 2.00 / divisor
        case "Backwaren": return 2.00 / divisor
        case "Tiefkühlkost": return 3.50 / divisor
        case "Getränke": return 1.50 / divisor
        case "Snacks": return 1.80 / divisor
        case "Körperpflege": return 4.00 / divisor
        case "Kosmetik": return 6.00 / divisor
        case "Reinigung": return 3.50 / divisor
        case "Haushalt": return 5.00 / divisor
        default: return nil
        }
    }
}

// MARK: - One-time price provenance migration

/// Fixes existing items created before the `PriceEstimator` unit-divisor fix, where a flat
/// "per kg/liter" price was multiplied directly by a raw sub-unit quantity (e.g. "750g" →
/// 750 × 1.50€ = 1125€ instead of ~1.13€). Runs once per install.
///
/// The tricky part: we must NOT touch prices with a real-world origin (a receipt-learned
/// price or a manual entry), even if that value happens to numerically collide with one of
/// the ~15-20 hardcoded catalog constants (e.g. a genuine 2.50€ receipt price for 400g
/// tomatoes must not be reinterpreted as the buggy "Obst & Gemüse" flat rate and divided
/// down to 1.00€). So provenance (Phase A) is always reconstructed first, using the exact
/// same fuzzy `learnedPrices` match as `ShoppingItem.init`, independent of the numeric value.
/// Only items that come out of Phase A as auto-derived AND match the old bug's exact
/// fingerprint (sub-unit, large quantity, value equals the undivided catalog constant) get
/// rewritten in Phase B.
enum PriceProvenanceMigration {
    static let flagKey = "priceProvenanceMigrationV2Applied"
    static let minQuantityForSafeRewrite = 10.0
    private static let subUnits: Set<String> = ["g", "gramm", "mg", "milligramm", "ml", "milliliter", "cl", "zentiliter", "dl", "deziliter"]

    @MainActor
    static func runIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }
        guard let items = try? context.fetch(FetchDescriptor<ShoppingItem>()) else { return }
        for item in items {
            // Phase A: reconstruct provenance as best we can — same fuzzy search as
            // ShoppingItem.init. A matching learned price means the origin is NOT
            // auto-derived, regardless of whether the value happens to collide with a
            // catalog constant.
            let itemLower = item.name.lowercased()
            let hasLearnedMatch = item.store?.learnedPrices.contains { key, _ in
                key.count >= 3 && itemLower.count >= 3 &&
                (key.contains(itemLower) || itemLower.contains(key))
            } ?? false
            item.estimatedPriceIsAutoDerived = !hasLearnedMatch

            // Phase B: only rewrite when (per Phase A) the item is auto-derived AND the old
            // fingerprint conditions (sub-unit, quantity above threshold, value equals the
            // undivided catalog constant) are met.
            let unitKey = item.unit.trimmingCharacters(in: .whitespaces).lowercased()
            guard item.estimatedPriceIsAutoDerived,
                  subUnits.contains(unitKey),
                  item.quantityAmount > minQuantityForSafeRewrite,
                  let current = item.estimatedPrice,
                  let buggyValue = PriceEstimator.estimate(for: item.name, category: item.category, unit: ""),
                  current == buggyValue
            else { continue }
            item.estimatedPrice = PriceEstimator.estimate(for: item.name, category: item.category, unit: item.unit)
        }
        try? context.save()
        UserDefaults.standard.set(true, forKey: flagKey)
    }
}
