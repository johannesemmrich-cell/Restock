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

    /// Normalisierter Vergleichs-Key für Ladennamen (getrimmt, klein geschrieben) — analog zu
    /// `foldedLower` bei Artikelnamen. `PurchaseRecord.storeName` ist ein zum Kaufzeitpunkt
    /// eingefrorener Text-Schnappschuss, kein Verweis auf das `Store`-Objekt: weicht er auch nur
    /// in Groß-/Kleinschreibung oder einem Leerzeichen vom aktuellen `Store.name` ab (z. B. nach
    /// einer Ladenumbenennung, einem über Bon-Scan erkannten Namen, oder einem über eine geteilte
    /// Liste beigetretenen Store), zählte dieser Kauf vorher unter einem eigenen, separaten
    /// Dictionary-Key und wurde bei der späteren Auswertung komplett übersehen — die Kaufhistorie
    /// eines real genutzten Ladens konnte so effektiv auf null fallen und die Zuordnung fiel auf
    /// die schwächere `visitsPerWeek`-Fallback-Stufe zurück (Nutzerbericht 20.09.2026: Artikel
    /// landeten trotz ausschließlicher Lidl-Käufe dauerhaft bei einem anderen Laden). Ab jetzt wird
    /// überall, wo Kaufhistorie pro Laden gezählt UND nachgeschlagen wird, konsequent dieser
    /// normalisierte Key verwendet, statt nur beim finalen Rückverweis auf `Store` zu normalisieren.
    private static func normalizedStoreKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespaces).lowercased()
    }

    static func dominantStore(for itemName: String, in stores: [Store], purchaseRecords: [PurchaseRecord]) -> Store? {
        let relevant = purchaseRecords.filter {
            namesRepresentSameItem($0.itemName, itemName)
        }
        guard relevant.count >= 1 else { return nil }

        var counts: [String: Int] = [:]
        for record in relevant {
            counts[normalizedStoreKey(record.storeName), default: 0] += 1
        }

        let total = relevant.count
        guard let (dominantKey, dominantCount) = counts.max(by: { $0.value < $1.value }),
              Double(dominantCount) / Double(total) > 0.5 else { return nil }

        return stores.first { normalizedStoreKey($0.name) == dominantKey }
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
            if let best = preferredDefault(for: "hardware", among: hardwareStores)
                ?? bestFallback(among: hardwareStores, purchaseRecords: purchaseRecords) {
                return best
            }
            // No hardware store → fall through to variety
            let varietyFallback = activeStores.filter { $0.categories.contains(where: { Category.variety.contains($0) }) }
            if let best = preferredDefault(for: "variety", among: varietyFallback)
                ?? bestFallback(among: varietyFallback, purchaseRecords: purchaseRecords) {
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
            if let best = preferredDefault(for: "variety", among: varietyStores)
                ?? bestFallback(among: varietyStores, purchaseRecords: purchaseRecords) {
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
            if let best = preferredDefault(for: "drugstore", among: drugstores)
                ?? bestFallback(among: drugstores, purchaseRecords: purchaseRecords) {
                return best
            }
        }

        // 4. High-frequency food → store with highest visit frequency
        let isFrequentFood = highFrequencyFoodKeywords.contains(where: { nameLower.contains($0) })
        if isFrequentFood {
            let groceryStores = activeStores.filter { store in
                store.categories.contains(where: { Category.grocery.contains($0) })
            }
            return preferredDefault(for: "grocery", among: groceryStores)
                ?? bestFallback(among: groceryStores, purchaseRecords: purchaseRecords)
        }

        // 5. Default: dominant grocery store by real purchase history (visit frequency only as tiebreak)
        let groceryStores = activeStores.filter { store in
            store.categories.contains(where: { Category.grocery.contains($0) })
        }
        return preferredDefault(for: "grocery", among: groceryStores)
            ?? bestFallback(among: groceryStores, purchaseRecords: purchaseRecords)
    }

    /// Nutzer-konfigurierter Standard-Laden (`DefaultStoreService`, Settings → Standard-Läden)
    /// für eine bereits nach Kategorie gefilterte Kandidatenliste. Vor jedem `bestFallback`-Aufruf
    /// geprüft: eine explizite Nutzer-Einstellung soll immer Vorrang vor der nur abgeleiteten
    /// Kaufhistorie-/Besuchsfrequenz-Heuristik haben — dasselbe Prinzip wie die Artikelname-
    /// Korrektur in Stufe 0a oben, nur auf Kategorie-Ebene statt pro Artikel. Liefert `nil`, wenn
    /// nichts konfiguriert ist ODER der konfigurierte Laden in `candidates` fehlt (deaktiviert,
    /// gelöscht, oder passt nicht mehr zur Kategorie) — der Aufrufer fällt dann automatisch auf
    /// `bestFallback` zurück, kein gesonderter Cleanup nötig.
    private static func preferredDefault(for groupKey: String, among candidates: [Store]) -> Store? {
        guard let name = DefaultStoreService.shared.storeName(for: groupKey) else { return nil }
        return candidates.first { $0.name.lowercased() == name.lowercased() }
    }

    /// Wählt aus `candidates` (bereits nach Kategorie gefiltert) den passendsten Store.
    ///
    /// PRIMÄRES Signal ist jetzt die tatsächliche Kaufanzahl an jedem Kandidaten über ALLE
    /// Artikel hinweg (nicht nur für den gerade zugeordneten Artikelnamen — das deckt bereits
    /// `dominantStore` oben ab), nicht mehr `visitsPerWeek`. Hintergrund (Nutzerbericht
    /// 14.09.2026): `visitsPerWeek` ist eine beim Laden-Setup manuell (oder per Preset) gesetzte
    /// Zahl, deren Einfluss auf die automatische Zuordnung den meisten Nutzern nicht bewusst ist
    /// — ein Nutzer, der real ausschließlich bei Lidl einkauft, aber die Zahl nie angefasst hat
    /// (oder sie für einen anderen Laden zufällig höher steht), bekam trotzdem dauerhaft den
    /// falschen Laden vorgeschlagen. Echtes Einkaufsverhalten ist ein verlässlicheres Signal als
    /// eine kaum sichtbare Einstellung. `visitsPerWeek` bleibt NUR noch relevant, wenn für KEINEN
    /// Kandidaten überhaupt Kaufhistorie vorliegt (z. B. ganz neuer Nutzer) — dort ist es
    /// weiterhin die einzige verfügbare Information (Presets: Lidl=2 vs. Rewe=1 z. B.).
    ///
    /// Bei genau einem Kandidaten gibt es nichts zu entscheiden — unbedingt zurückgeben.
    private static func bestFallback(among candidates: [Store], purchaseRecords: [PurchaseRecord]) -> Store? {
        guard candidates.count > 1 else { return candidates.first }

        var purchaseCounts: [String: Int] = [:]
        for record in purchaseRecords {
            purchaseCounts[normalizedStoreKey(record.storeName), default: 0] += 1
        }

        let withEvidence = candidates.filter { (purchaseCounts[normalizedStoreKey($0.name)] ?? 0) > 0 }
        guard !withEvidence.isEmpty else {
            // Kein Kandidat hat je einen abgeschlossenen Kauf verzeichnet — einzig verfügbares
            // Signal ist dann noch visitsPerWeek.
            return bestByVisits(among: candidates, purchaseCounts: purchaseCounts)
        }

        let topCount = withEvidence.map { purchaseCounts[normalizedStoreKey($0.name)] ?? 0 }.max()!
        let tied = withEvidence.filter { (purchaseCounts[normalizedStoreKey($0.name)] ?? 0) == topCount }
        guard tied.count > 1 else { return tied.first }
        // Gleichstand in der Kaufanzahl (z. B. je 1 früher Kauf an beiden) — visitsPerWeek
        // entscheidet als nächste Stufe, dann Name, dann `id` als garantiert eindeutiger
        // letzter Tie-Breaker (gleiches Muster wie `detectStore` unten in dieser Datei).
        return bestByVisits(among: tied, purchaseCounts: purchaseCounts)
    }

    /// Reiner visitsPerWeek-Vergleich mit demselben Kaufanzahl-/Name-/id-Tie-Breaker-Aufbau wie
    /// zuvor `bestFallback` allein — jetzt als eigener letzter Entscheidungsschritt ausgelagert,
    /// damit `bestFallback` ihn sowohl bei fehlender Kaufhistorie als auch bei einem Gleichstand
    /// in der Kaufanzahl wiederverwenden kann, ohne die Tie-Breaker-Logik zu duplizieren.
    /// `purchaseCounts` ist bereits über `normalizedStoreKey` (getrimmt, klein geschrieben)
    /// geschlüsselt (siehe Aufrufer) — Zugriff hier deshalb ebenfalls darüber, sonst würde derselbe
    /// Case-/Whitespace-Mismatch wie in `bestFallback` erneut echte Kaufanzahl-Treffer verstecken.
    private static func bestByVisits(among candidates: [Store], purchaseCounts: [String: Int]) -> Store? {
        guard let topVisits = candidates.map(\.visitsPerWeek).max() else { return nil }
        let tied = candidates.filter { $0.visitsPerWeek == topVisits }
        guard tied.count > 1 else { return tied.first }
        // `name` allein ist KEIN garantiert eindeutiger Tie-Breaker (nichts in der App verhindert
        // einen Custom-Store mit demselben Namen wie ein Preset, oder zwei beigetretene geteilte
        // Listen mit zufällig gleichem Namen). `id` (UUID) ist dagegen bei zwei verschiedenen
        // Store-Objekten immer verschieden — echter letzter Tie-Breaker.
        return tied.max(by: {
            let countA = purchaseCounts[normalizedStoreKey($0.name)] ?? 0
            let countB = purchaseCounts[normalizedStoreKey($1.name)] ?? 0
            if countA != countB { return countA < countB }
            if $0.name != $1.name { return $0.name > $1.name }
            return $0.id.uuidString > $1.id.uuidString
        })
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

    /// Erkennt, zu welchem der übergebenen Läden ein gescannter Bon gehört. Vergleicht gegen
    /// einzelne WÖRTER, nicht ganze Zeilen: eine mehrteilige Kopfzeile wie "DM Drogerie Markt"
    /// würde das Längenverhältnis von `lcsSimilarity` sonst so verdünnen, dass ein kurzer
    /// Ladenname wie "DM" nie einen hohen Score erreichen könnte, selbst bei exakter
    /// Übereinstimmung (nachgerechnet: nur 0,21 statt der nötigen Schwelle).
    ///
    /// EIN gemeinsamer Kandidaten-Pool aus zwei unterschiedlich behandelten Quellen, nicht zwei
    /// nacheinander versuchte Stufen (eine "nur wenn die erste nichts findet"-Reihenfolge wurde
    /// testweise gebaut und verworfen — sie griff nie über den Kopfbereich hinaus, sobald DORT
    /// bereits irgendein, und sei es falscher, Treffer lag, siehe Lehre unten):
    /// - Kopfbereich (erste 8 Zeilen) — UNGEFILTERT, unverändertes, ursprüngliches Verhalten.
    /// - Rest des Bons — GEFILTERT: bekannte Kassenbon-Verwaltungswörter
    ///   (`ReceiptParserService.isKnownAdminWord`) zählen hier nicht als Treffer. Sonst würde die
    ///   MwSt-Tabellenzeile, die auf so gut wie JEDEM deutschen Bon irgendwo "... Netto = Brutto"
    ///   druckt, das eingebaute Laden-Preset "Netto" mit einem perfekten Score 1.0 treffen,
    ///   unabhängig vom tatsächlichen Laden (von einer unabhängigen Verify-Runde gefunden,
    ///   24.08.2026 — sonst hätte JEDER Nutzer mit "Netto" als konfiguriertem Laden JEDEN Bon als
    ///   "Netto" fehlerkannt bekommen). Der Kopfbereich bleibt bewusst ungefiltert: er enthält
    ///   praktisch nie MwSt-Vokabular, und ein Laden, der wirklich "Netto" heißt, muss über seinen
    ///   eigenen (lesbaren) Kopfzeilen-Namen weiterhin erkennbar bleiben.
    ///
    /// BEIDE Quellen zusammen fließen in EINE Bewertung (nicht sequenziell mit früher Rückkehr) —
    /// gemeldet 24.08.2026: ein Lidl-Bon wurde als "Frankfurt" statt "Lidl" erkannt, weil das
    /// Lidl-Logo ein reines Bild ist, das Vision nicht als Text liest, der Ladenname aber im
    /// Fußbereich mehrfach lesbar steht ("Lidl Plus Rabatt", "www.lidl.de", "Lidl Punkte"),
    /// während "Frankfurt" zufällig schon in der Adresszeile IM Kopfbereich steht. Ein
    /// früher-Rückgabe-Entwurf ("Kopfbereich zuerst, Fußbereich nur als Fallback") hätte hier
    /// bereits beim Kopfbereichs-Treffer "Frankfurt" aufgehört und den besseren, häufigeren
    /// Fußbereichs-Treffer "Lidl" nie gesehen — durch einen echten Test aufgedeckt, nicht nur
    /// vermutet. Ein Unentschieden zwischen zwei VERSCHIEDENEN Läden mit demselben Top-Score wird
    /// außerdem nicht mehr durch die unspezifizierte SwiftData-Fetch-Reihenfolge von `candidates`
    /// entschieden (das war vorher der Fall — score > best.score ist strikt "größer als", der
    /// erste Laden in `candidates` gewann jedes Unentschieden rein zufällig). Zweiter Tie-Breaker
    /// ist die HÄUFIGKEIT der Treffer über der Schwelle: der eigene Markenname eines Ladens taucht
    /// auf dem eigenen Bon typischerweise mehrfach auf (Treuepunkte-Programm, Website,
    /// Dankes-Fußzeile), ein zufälliger Nebentreffer (z. B. ein Stadtname in der Adresse) meist
    /// nur einmal — genau das entscheidet den Lidl-vs-Frankfurt-Fall richtig (4 Treffer vs. 1).
    /// Danach Ladenname, danach `id` (UUID) als garantiert eindeutiger letzter Tie-Breaker —
    /// dasselbe Muster wie `bestFallback` oben in dieser Datei.
    static func detectStore(fromReceiptLines lines: [String], candidates: [Store]) -> Store? {
        guard !candidates.isEmpty else { return nil }
        let headerTokens = tokens(from: Array(lines.prefix(8)))
        let bodyTokens = tokens(from: Array(lines.dropFirst(8)))
            .filter { !ReceiptParserService.isKnownAdminWord($0.lowercased()) }
        return bestMatchingStore(forTokens: headerTokens + bodyTokens, among: candidates)
    }

    private static func tokens(from lines: [String]) -> [String] {
        lines
            .joined(separator: " ")
            .components(separatedBy: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "-./,")))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count >= 2 }
    }

    private static func bestMatchingStore(forTokens tokens: [String], among candidates: [Store]) -> Store? {
        let scored: [(store: Store, bestScore: Double, matchCount: Int)] = candidates.compactMap { store in
            var bestScore = 0.0
            var matchCount = 0
            for token in tokens {
                let score = ReceiptParserService.lcsSimilarity(store.name, token)
                guard score >= storeDetectionThreshold else { continue }
                matchCount += 1
                bestScore = max(bestScore, score)
            }
            return matchCount > 0 ? (store, bestScore, matchCount) : nil
        }
        return scored.max(by: {
            if $0.bestScore != $1.bestScore { return $0.bestScore < $1.bestScore }
            if $0.matchCount != $1.matchCount { return $0.matchCount < $1.matchCount }
            if $0.store.name != $1.store.name { return $0.store.name > $1.store.name }
            return $0.store.id.uuidString > $1.store.id.uuidString
        })?.store
    }
}
