import Foundation
import SwiftData

/// Einmalige Aufräumung (gemeldet 18.10.2026, `docs/specs/fast/fix-ai-receipt-name-broet.md`): Ein
/// Bon, dessen Zeilen alle als "Bröt." gespeichert wurden, hinterlässt Zuordnungen Bontext → "Bröt."
/// (Stufe 1, gewinnt bei jedem künftigen Scan) und gelernte Preise unter dem Schlüssel "bröt.", die
/// jedes neue "Brötchen" auf der Liste bekommt. Beides wird hier entfernt. Von den Kaufdatensätzen
/// nur das eindeutige Fehlermuster (`isBugPattern`): Kürzel-Name, derselbe Laden, derselbe Tag,
/// mindestens `recordPatternThreshold` Datensätze mit Bon-Preis — ein echter Einkauf erzeugt nie drei
/// gleichnamige Datensätze an einem Tag. Einzelne Kürzel-Datensätze bleiben, sie können echte Käufe
/// sein, die nur falsch heißen.
enum AbbreviatedNameCleanup {
    static let flagKey = "abbreviatedNameCleanupV1Applied"
    static let recordPatternThreshold = 3

    /// Kaufdatensätze, die zum Fehlermuster gehören (reine Entscheidung, siehe Typkommentar).
    static func bugPatternRecords(in records: [PurchaseRecord], calendar: Calendar = .current) -> [PurchaseRecord] {
        let candidates = records.filter {
            ReceiptNameAIResolver.endsWithAbbreviation($0.itemName) && $0.actualPrice != nil
        }
        let groups = Dictionary(grouping: candidates) { record in
            [record.itemName.lowercased(), record.storeName.lowercased(),
             String(describing: calendar.startOfDay(for: record.date))].joined(separator: "|")
        }
        return groups.values.filter { $0.count >= recordPatternThreshold }.flatMap { $0 }
    }

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
        var removed = 0
        if let stores = try? context.fetch(FetchDescriptor<Store>()) {
            for store in stores { removed += removeAbbreviatedLearnedPrices(from: store) }
        }
        if let records = try? context.fetch(FetchDescriptor<PurchaseRecord>()) {
            let doomed = bugPatternRecords(in: records)
            for record in doomed { context.delete(record) }
            removed += doomed.count
        }
        if removed > 0 { try? context.save() }
        UserDefaults.standard.set(true, forKey: flagKey)
    }
}
