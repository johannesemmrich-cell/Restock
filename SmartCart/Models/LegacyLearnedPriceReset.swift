import Foundation
import SwiftData

/// Einmalige Migration (Issue #11, `docs/specs/models/legacy-price-reset-migration.md`): Vor #9/#10
/// wurde auf Rewe-Bons die Zeilensumme als Stückpreis gelernt. Diese Altwerte stehen in
/// `Store.learnedPrices` ohne `learnedPriceUnits`-Pendant und sind dort seit #10 inert — bereits
/// gespeicherte `ShoppingItem.estimatedPrice`-Werte tragen sie aber weiter. Artikel, deren Preis
/// exakt (±0,005) einem solchen einheitslosen Altwert entspricht, werden auf die Katalogschätzung
/// zurückgesetzt. Die gelernten Preise selbst bleiben unangetastet.
enum LegacyLearnedPriceReset {
    static let flagKey = "legacyLearnedPriceResetV1Applied"
    static let tolerance = 0.005

    /// Reine Entscheidung ohne ModelContext (Entscheidungstabelle der Spec, Zeilen 1–7).
    static func shouldReset(
        hasStore: Bool, isAutoDerived: Bool, estimatedPrice: Double?,
        matchedLearnedPrice: Double?, matchedLearnedUnit: String?
    ) -> Bool {
        guard hasStore, !isAutoDerived,
              let estimatedPrice,
              let matchedLearnedPrice else { return false }
        if let matchedLearnedUnit, !matchedLearnedUnit.isEmpty { return false }
        return abs(estimatedPrice - matchedLearnedPrice) <= tolerance
    }

    @MainActor
    static func runIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }
        guard let items = try? context.fetch(FetchDescriptor<ShoppingItem>()) else { return }
        for item in items {
            let key = item.store.flatMap {
                ShoppingItem.matchingLearnedPriceKey(forLowercasedName: item.name.lowercased(), in: $0)
            }
            guard shouldReset(
                hasStore: item.store != nil,
                isAutoDerived: item.estimatedPriceIsAutoDerived,
                estimatedPrice: item.estimatedPrice,
                matchedLearnedPrice: key.flatMap { item.store?.learnedPrices[$0] },
                matchedLearnedUnit: key.flatMap { item.store?.learnedPriceUnits[$0] }
            ) else { continue }
            item.estimatedPrice = PriceEstimator.estimate(
                for: item.name, category: item.category, unit: item.unit, quantityAmount: item.quantityAmount)
            item.estimatedPriceIsAutoDerived = true
        }
        try? context.save()
        UserDefaults.standard.set(true, forKey: flagKey)
    }
}
