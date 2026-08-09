import Foundation
import SwiftData

// Assigns a shopping item to the most appropriate store based on:
// 1. Category match (e.g. drugstore items → DM)
// 2. Past purchase history (learned store preference)
// 3. Visit frequency (frequent items → most-visited store)

extension AssignmentService {

    // MARK: - Category to store-type mapping
    //
    // drugstoreKeywords/varietyStoreKeywords/hardwareStoreKeywords/nonFoodCompoundEndings
    // moved to AssignmentService+Category.swift (needed there by `category(for:)`, and by
    // `assign` below via the same internal-not-private visibility) — that file also carries
    // target membership in SmartCartWidgets, which this file deliberately does not (it needs
    // ReceiptParserService, too heavy/irrelevant for the widget extension).

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

    // MARK: - Lenient name comparison for purchase-history matching

    /// Qualifier words that shouldn't prevent two names from counting as the "same" item for
    /// store-assignment purposes ("Bio Eier" vs. "Eier" — a receipt scan often stores the fuller
    /// name, a manually typed Quick-Add the bare one). Kept small and conservative: comparison
    /// still requires the REMAINING word set to match exactly, so e.g. "Eierlikör" (one token,
    /// never split into "eier") never collides with "Eier".
    private static let qualifierStopWords: Set<String> = [
        "bio", "basic", "regional", "frisch", "fresh", "premium", "fein", "nature", "natur", "demeter",
    ]

    /// Word-level, diacritic-folded, qualifier-stripped token set used for lenient purchase-history
    /// name comparison. Falls back to the un-stripped token set if stripping qualifiers would empty
    /// it out (so a purchase record whose name is only "Bio" isn't reduced to a set that matches
    /// everything).
    private static func coreNameTokens(_ name: String) -> Set<String> {
        let folded = name.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        let cleaned = folded.replacingOccurrences(of: #"[^a-z0-9\s]"#, with: " ", options: .regularExpression)
        let tokens = cleaned.split(separator: " ").map(String.init)
        let filtered = tokens.filter { !qualifierStopWords.contains($0) }
        return Set(filtered.isEmpty ? tokens : filtered)
    }

    /// Lenient equality for two item names (purchase-record vs. manually typed, or vice versa) —
    /// exact match OR identical core-token sets after stripping common qualifiers. NOT substring
    /// matching, which would risk false positives like "Eierlikör" containing "Eier".
    static func namesRepresentSameItem(_ a: String, _ b: String) -> Bool {
        if a.caseInsensitiveCompare(b) == .orderedSame { return true }
        return coreNameTokens(a) == coreNameTokens(b)
    }

    // MARK: - Assign store

    static func dominantStore(for itemName: String, in stores: [Store], purchaseRecords: [PurchaseRecord]) -> Store? {
        let relevant = purchaseRecords.filter {
            namesRepresentSameItem($0.itemName, itemName)
        }
        guard relevant.count >= 1 else { return nil }

        var counts: [String: Int] = [:]
        for record in relevant {
            counts[record.storeName, default: 0] += 1
        }

        let total = relevant.count
        guard let (dominantName, dominantCount) = counts.max(by: { $0.value < $1.value }),
              Double(dominantCount) / Double(total) > 0.5 else { return nil }

        return stores.first { $0.name.lowercased() == dominantName.lowercased() }
    }

    static func assign(itemName: String, to activeStores: [Store], purchaseRecords: [PurchaseRecord] = []) -> Store? {
        guard !activeStores.isEmpty else { return nil }

        let nameLower = itemName.lowercased()

        // 0a. Explicit user correction (Quick-Add toast) always wins — it's a stronger signal
        // than a merely inferred purchase-history pattern, and doesn't need >1 purchase to apply.
        if let overrideName = StoreAssignmentOverrideService.shared.storeName(for: itemName),
           let overrideStore = activeStores.first(where: { $0.name.lowercased() == overrideName.lowercased() }) {
            return overrideStore
        }

        // 0b. History-based: if a dominant store is found, use it
        if let dominant = dominantStore(for: itemName, in: activeStores, purchaseRecords: purchaseRecords) {
            return dominant
        }

        // 1. Hardware/DIY items → hardware store, variety store as fallback
        let isHardware = hardwareStoreKeywords.contains(where: { nameLower.contains($0) })
        if isHardware {
            let hardwareStores = activeStores.filter { $0.categories.contains(where: { Category.hardware.contains($0) }) }
            if let best = hardwareStores.max(by: { $0.visitsPerWeek < $1.visitsPerWeek }) {
                return best
            }
            // No hardware store → fall through to variety
            let varietyFallback = activeStores.filter { $0.categories.contains(where: { Category.variety.contains($0) }) }
            if let best = varietyFallback.max(by: { $0.visitsPerWeek < $1.visitsPerWeek }) {
                return best
            }
        }

        // 2. Variety/discount store items → variety store
        let isVariety = varietyStoreKeywords.contains(where: { nameLower.contains($0) })
            || nonFoodCompoundEndings.contains(where: { nameLower.hasSuffix($0) })
        if isVariety {
            let varietyStores = activeStores.filter { store in
                store.categories.contains(where: { Category.variety.contains($0) })
            }
            if let best = varietyStores.max(by: { $0.visitsPerWeek < $1.visitsPerWeek }) {
                return best
            }
        }

        // 3. Drugstore items → drugstore-type store (DM, Rossmann, etc.)
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

    // MARK: - Store detection from receipt text (Share Extension)

    /// Mindest-Ähnlichkeit für einen Laden-Treffer — bewusst HÖHER als
    /// `ReceiptParserService.completedItemAutoApplyThreshold` (0,6), nicht identisch. Ladennamen
    /// stehen auf Bons als Logo/Kopfzeile klar gedruckt; die einzige real beobachtete
    /// OCR-Verwucherung dieser Session war ein einzelnes fehlendes Zeichen ("LIDL"→"LDL",
    /// Score 0,857) — anders als bei Artikel-Kürzeln ("MDHSZ"→"Mozzarella") braucht es hier keine
    /// großzügige Schwelle für starke Abkürzungen. Eine niedrigere Schwelle hätte hier zudem ein
    /// eigenes, nachgerechnetes Fehltreffer-Risiko: "Land" (als eigenständiges Wort in einer
    /// Kopfzeile) erreicht gegen den Ladennamen "Kaufland" bereits 0,667 — echte Suffix-Beziehung,
    /// exakt dieselbe Komposita-Falle wie bei Artikelnamen ("Milch" in "Kondensmilch").
    private static let storeDetectionThreshold = 0.75

    /// Erkennt, zu welchem der übergebenen Läden ein gescannter Bon gehört, anhand der ersten
    /// paar rekonstruierten OCR-Zeilen (Kopfbereich, wo Logo/Ladenname stehen — auf den Bons
    /// dieser Session stand "LIDL"/"LDL" jeweils als eigenständige erste Zeile). Vergleicht gegen
    /// einzelne WÖRTER, nicht ganze Zeilen: eine mehrteilige Kopfzeile wie "DM Drogerie Markt"
    /// würde das Längenverhältnis von `lcsSimilarity` sonst so verdünnen, dass ein kurzer
    /// Ladenname wie "DM" nie einen hohen Score erreichen könnte, selbst bei exakter
    /// Übereinstimmung (nachgerechnet: nur 0,21 statt der nötigen Schwelle).
    static func detectStore(fromReceiptLines lines: [String], candidates: [Store]) -> Store? {
        guard !candidates.isEmpty else { return nil }
        let headerTokens = lines.prefix(8)
            .joined(separator: " ")
            .components(separatedBy: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "-./,")))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count >= 2 }

        var best: (store: Store, score: Double)?
        for store in candidates {
            for token in headerTokens {
                let score = ReceiptParserService.lcsSimilarity(store.name, token)
                if score >= storeDetectionThreshold, best == nil || score > best!.score {
                    best = (store, score)
                }
            }
        }
        return best?.store
    }
}
