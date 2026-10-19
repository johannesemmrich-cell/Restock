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
            let fallback = PriceEstimator.resolve(
                for: item.name, category: item.category, unit: item.unit, quantityAmount: item.quantityAmount)
            item.estimatedPrice = fallback?.price
            item.estimatedPriceIsAutoDerived = true
            item.priceSource = fallback?.source ?? "estimate"
            item.priceSourceDate = nil
        }
        try? context.save()
        UserDefaults.standard.set(true, forKey: flagKey)
    }
}

/// Einmalige Auffrischung (Issues #160/#162): Automatisch hergeleitete Preise werden mit dem
/// `PriceCatalog` neu berechnet und tragen danach `"estimate"` (Katalogtreffer) oder `"category"`
/// (Pauschale) als Quelle — sonst zeigten bestehende Artikel weiter fünfmal „ca. 2,00 €". Echte
/// Preise (`estimatedPriceIsAutoDerived == false`) bleiben unangetastet; die Spalte selbst gilt
/// laut Feldkommentar als jederzeit neu berechenbar. Läuft nach `LegacyLearnedPriceReset`.
enum CatalogEstimateRefresh {
    static let flagKey = "priceCatalogRefreshV1Applied"

    /// Kategorie für die Schätzung: eine feste Kategorie wie gespeichert, eine eigene oder leere
    /// aus dem Namen (eine eigene Kategorie hat keine Pauschale, siehe `EditItemView.save()`).
    static func priceCategory(for item: ShoppingItem) -> String {
        AssignmentService.categoryOrder.contains(item.category) ? item.category : AssignmentService.category(for: item.name)
    }

    /// Reine Entscheidung je Artikel: neuer Preis und neue Quelle, oder nil, wenn nichts zu tun ist.
    /// Community-Preise (Issue #163) sind zwar automatisch hergeleitet, aber beobachtet, nicht
    /// geschätzt — sie bleiben stehen.
    static func refreshed(isAutoDerived: Bool, priceSource: String, name: String, priceCategory: String, unit: String,
                          quantityAmount: Double) -> (price: Double?, source: String)? {
        guard isAutoDerived, !priceSource.hasPrefix(CommunityPrice.sourcePrefix) else { return nil }
        let fallback = PriceEstimator.resolve(for: name, category: priceCategory, unit: unit, quantityAmount: quantityAmount)
        return (fallback?.price, fallback?.source ?? "estimate")
    }

    @MainActor
    static func runIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }
        guard let items = try? context.fetch(FetchDescriptor<ShoppingItem>()) else { return }
        for item in items {
            guard let result = refreshed(
                isAutoDerived: item.estimatedPriceIsAutoDerived, priceSource: item.priceSource, name: item.name,
                priceCategory: priceCategory(for: item), unit: item.unit, quantityAmount: item.quantityAmount
            ) else { continue }
            item.estimatedPrice = result.price
            item.priceSource = result.source
            item.priceSourceDate = nil
        }
        try? context.save()
        UserDefaults.standard.set(true, forKey: flagKey)
    }
}
