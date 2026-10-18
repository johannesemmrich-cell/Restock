import Foundation
import SwiftData

/// Einmalige Aufräumung (gemeldet 18.10.2026, `docs/specs/fast/fix-ai-receipt-name-broet.md`): Ein
/// Bon, dessen Zeilen alle als "Bröt." gespeichert wurden, hinterlässt Zuordnungen Bontext → "Bröt."
/// (Stufe 1, gewinnt bei jedem künftigen Scan) und gelernte Preise unter dem Schlüssel "bröt.", die
/// jedes neue "Brötchen" auf der Liste bekommt. Beides wird hier entfernt. Kaufdatensätze bleiben
/// unangetastet: darunter können echte Käufe sein, die nur falsch heißen.
enum AbbreviatedNameCleanup {
    static let flagKey = "abbreviatedNameCleanupV1Applied"

    /// Entfernt in `store` alle gelernten Preise, deren Schlüssel ein Kürzel ist. Liefert die Zahl
    /// der entfernten Schlüssel.
    @discardableResult
    static func removeAbbreviatedLearnedPrices(from store: Store) -> Int {
        let doomed = store.learnedPrices.keys.filter { ReceiptNameAIResolver.endsWithAbbreviation($0) }
        for key in doomed {
            store.learnedPrices.removeValue(forKey: key)
            store.learnedPriceUnits.removeValue(forKey: key)
            store.learnedPriceDates.removeValue(forKey: key)
            store.learnedPriceOrigins.removeValue(forKey: key)
        }
        return doomed.count
    }

    @MainActor
    static func runIfNeeded(context: ModelContext, aliases: ReceiptAliasService = .shared) {
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }
        aliases.removeAbbreviatedTargets()
        if let stores = try? context.fetch(FetchDescriptor<Store>()) {
            var removed = 0
            for store in stores { removed += removeAbbreviatedLearnedPrices(from: store) }
            if removed > 0 { try? context.save() }
        }
        UserDefaults.standard.set(true, forKey: flagKey)
    }
}
