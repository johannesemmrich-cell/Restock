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
    // Jede gespeicherte Eigenschaft braucht für SwiftDatas automatische CloudKit-Spiegelung
    // (SharedModelContainer.make(), erster Versuch: cloudKitDatabase: .private(...)) entweder
    // optional zu sein oder einen Standardwert zu haben — sonst schlägt ModelContainer-Init mit
    // SwiftDataError.loadIssueModelContainer fehl (live bestätigt 30.07.2026, siehe Store.swift).
    // Echte Werte kommen weiterhin ausschließlich aus init() unten.
    var id: UUID = UUID()
    var name: String = ""
    var category: String = ""
    /// True once the user has explicitly picked a category in `EditItemView` that differs from
    /// what `AssignmentService.category(for:)` would auto-detect from the name. Views that group
    /// items by category should respect this: keep re-deriving the category from the name for
    /// everything else (so keyword-rule improvements apply immediately), but never overwrite a
    /// category the user manually chose.
    var categoryManuallySet: Bool = false
    var quantity: String = "1"
    var quantityAmount: Double = 1
    var unit: String = ""
    var isCompleted: Bool = false
    var isUrgent: Bool = false
    var addedDate: Date = Date()
    var completedDate: Date?
    var note: String = ""
    var estimatedPrice: Double?
    /// `true` when `estimatedPrice` came purely from `PriceEstimator` (catalog/category flat
    /// rate) and can therefore be safely recomputed at any time (unit changes, migrations).
    /// `false` once the price has a real-world origin — a learned receipt price or a manual
    /// entry in `EditItemView` — and must never be silently overwritten again. Additive field
    /// with a default, like `categoryManuallySet`/`completedBy` above, so SwiftData lightweight
    /// migration handles it without a schema-version bump.
    var estimatedPriceIsAutoDerived: Bool = true
    /// Woher die Mengenangabe stammt: `"user"` (eingetippt oder korrigiert), `"history"` (letzter
    /// Kauf desselben Artikels in diesem Laden), `"package"` (Füllmenge im Artikelnamen), `"none"`
    /// (keine Evidenz — dann gibt es keinen Gesamtpreis, nur die Rate, siehe
    /// `estimatedLineTotal`). Der Standardwert `"user"` hält alle bestehenden Erzeugungsstellen
    /// (Quick-Add, Siri-Intent, Widget, MenuPlan, RecipeImport, HomeView-Vorschläge,
    /// StoreDetailView, SyncCoordinator) unverändert; CloudKit verlangt den Standardwert ohnehin
    /// (siehe Kopfkommentar oben). Issue #10.
    var quantitySource: String = "user"
    var assignedTo: String = ""
    var addedBy: String = ""
    /// Display name of whoever checked the item off (empty while pending). Additive field with a
    /// default, like `categoryManuallySet`, so SwiftData lightweight migration handles it without
    /// a schema-version bump. Shown in shared lists ("✓ von X"), synced via `SharedItemData`.
    var completedBy: String = ""
    var lastModified: Date = Date()

    /// Compressed photo bytes attached to this item, or nil if none. `.externalStorage` keeps the
    /// blob out of the in-memory row and lets SwiftData's existing private CloudKit mirror carry
    /// it as a CKAsset automatically — reuses that infra instead of hand-rolled file management.
    /// Deliberately NEVER synced through `SharedItemData`/`itemsJSON` (see `SharedItemPhotoService`
    /// for the separate, lazy, cross-account path) — only `hasPhoto` below travels that hot path.
    @Attribute(.externalStorage) var photoData: Data?
    /// True once a photo exists for this item, locally or (for shared-list members) uploaded by
    /// someone else but not yet downloaded to this device. The only photo-related field synced via
    /// `SharedItemData`/`itemsJSON` — a single scalar, additive with a default like `completedBy`.
    var hasPhoto: Bool = false
    var photoLastModified: Date?

    var store: Store?

    // Siehe Store.swift für die Begründung: CloudKit verlangt To-many-Relationships zwingend
    // als Optional, nicht nur mit Standardwert — bestätigt per Test (31.07.2026, RestockTests).
    // .nullify statt .cascade: PurchaseRecords sind die Datenquelle für storeübergreifende
    // Produkt-Vorschläge (QuickAddParser.knownProductSuggestions) — müssen das Löschen eines
    // Items/Stores überleben, sonst verschwindet die Vorschlagshistorie beim Aufräumen der
    // Liste (gemeldet 19.08.2026). Sicher, da PurchaseRecord vollständig denormalisiert ist
    // (eigene itemName/storeName/date/... Felder); `.item` wird außerhalb dieser Zuweisung nur
    // noch an einer Stelle optional-verkettet gelesen (ReceiptScannerView.swift, `match?.item`),
    // bereits nil-sicher — ein orphan-gewordener Record (item == nil) kann dort nichts zum
    // Absturz bringen.
    @Relationship(deleteRule: .nullify, inverse: \PurchaseRecord.item)
    var purchaseRecords: [PurchaseRecord]? = []

    init(
        name: String,
        category: String = "",
        quantity: String = "1",
        quantityAmount: Double = 1,
        unit: String = "",
        note: String = "",
        store: Store? = nil,
        quantitySource: String = "user"
    ) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.quantity = quantity
        self.quantityAmount = quantityAmount
        self.unit = unit
        self.quantitySource = quantitySource
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
        // Bei mehreren fuzzy passenden gelernten Preisen (z.B. "Hackfleisch Gemischt 500g" UND
        // "Rinderhackfleisch" für getipptes "Hackfleisch") entschied bisher `.first` — Swifts
        // Dictionary-Iterationsreihenfolge ist pro Prozess zufällig gehasht, der angezeigte
        // Preis konnte also zwischen App-Starts flippen (gefunden 19.08.2026). Datum allein als
        // Tie-Breaker reicht NICHT: haben beide Treffer kein learnedPriceDates (Normalfall bei
        // älteren, vor Einführung des Feldes gelernten Preisen — keine Backfill-Migration dafür,
        // auch PriceProvenanceMigration Phase C schreibt nur den Preis, nie das Datum), sind
        // beide `.distantPast`, der Vergleich bleibt unentschieden und max(by:) fällt zurück auf
        // dieselbe zufällige Iterationsreihenfolge — von einer unabhängigen Review-Runde per
        // mehrfachem Prozess-Neustart nachgewiesen, dass der Bug so bestehen bliebe, nur
        // seltener. Deshalb zusätzlich der Key selbst (garantiert eindeutig, alphabetisch) als
        // letzte, immer entscheidende Instanz.
        let rawLearnedMatch: (price: Double, unit: String?)? = {
            guard let store,
                  let bestKey = Self.matchingLearnedPriceKey(forLowercasedName: itemLower, in: store),
                  let price = store.learnedPrices[bestKey] else { return nil }
            // Die Bezugsgröße wird unter DEMSELBEN Schlüssel geführt (siehe
            // `Store.learnedPriceUnits`). Fehlt sie, ist der Preis ein Altdatum — die
            // Entscheidungstabelle unten verwirft ihn dann.
            return (price, store.learnedPriceUnits[bestKey])
        }()
        // `learnedPrices` is supposed to hold a PER-UNIT rate (see `estimatedLineTotal` below), but
        // a corrupted/stale entry (e.g. a full line total saved under the wrong key before an
        // earlier fix) can turn this into an absurd total once multiplied by quantityAmount (the
        // reported "Skyr 500g → 1145€" bug). Reject it here rather than ever displaying it.
        // Deliberately a MUCH higher bound than the generic estimator's `maxPlausibleLineTotal`
        // (30€) below: that one guards a hardcoded catalog guess, which should never claim a
        // pricey item — but a *learned* price came from a real receipt and can legitimately be
        // expensive (a nice steak, a bottle of wine, a whole ham). Independent review caught an
        // earlier version of this fix using the 30€ bound here too, which would have silently
        // discarded/corrupted correctly-learned prices for anything over 30€ — this only needs to
        // catch the reported bug's "off by the quantity factor" order-of-magnitude corruption,
        // not draw a tight realistic-price boundary.
        let plausibleQuantity = quantityAmount > 0 ? quantityAmount : 1
        let plausibleMatch = rawLearnedMatch.flatMap {
            $0.price * plausibleQuantity <= PriceEstimator.maxPlausibleLearnedLineTotal ? $0 : nil
        }
        // Zweite, unabhängige Prüfung NEBEN der Obergrenze oben (Issue #10): passt die
        // Bezugsgröße des gelernten Preises nicht zur Einheit dieses Artikels, ist der Wert nicht
        // verwendbar — eine pro Gramm gelernte Rate als Stückpreis ergibt die gemeldeten 0,01 €.
        // Die Obergrenze allein fängt das nie ab, sie kennt nur zu HOHE Werte.
        var learnedPrice: Double?
        switch Self.learnedRateUsage(
            learnedUnit: plausibleMatch?.unit, itemUnit: unit, quantitySource: quantitySource
        ) {
        case .apply:
            learnedPrice = plausibleMatch?.price
        case .rateOnly:
            // Die Rate vom Bon ist echt und bleibt nützlich, auch wenn keine Menge belegbar ist —
            // nur ein GESAMTpreis darf daraus nicht entstehen (`estimatedLineTotal` liefert bei
            // `quantitySource == "none"` nil). `unit` wird auf die Bezugsgröße gesetzt, damit die
            // Anzeige weiß, worauf sich die Rate bezieht ("… €/100 g" in `ItemRow`).
            learnedPrice = plausibleMatch?.price
            self.unit = "g"
        case .reject:
            learnedPrice = nil
        }
        self.estimatedPrice = learnedPrice ?? PriceEstimator.estimate(for: name, category: category, unit: self.unit, quantityAmount: quantityAmount)
        self.estimatedPriceIsAutoDerived = (learnedPrice == nil)
        // Issue #85: Hat der Nutzer diesen Artikel in diesem Laden schon einmal einer eigenen
        // Kategorie zugeordnet, landet er wieder dort. Erst nach der Preisschätzung, denn die
        // braucht die feste Kategorie — eine eigene hat keinen Katalogpreis.
        if let remembered = store?.rememberedCategory(forItemNamed: name) {
            self.category = remembered
            self.categoryManuallySet = true
        }
    }

    /// Schlüssel in `store.learnedPrices`, den `init` für einen (kleingeschriebenen) Artikelnamen
    /// wählt: Teilstring-Treffer, sonst Fuzzy-Fallback (#52); bei mehreren Treffern gewinnt das
    /// jüngste `learnedPriceDates`, bei Gleichstand der alphabetisch kleinste Schlüssel. Auch von
    /// `LegacyLearnedPriceReset` (Issue #11) genutzt, damit beide dieselbe Zuordnung treffen.
    static func matchingLearnedPriceKey(forLowercasedName itemLower: String, in store: Store) -> String? {
        let substringKeys = store.learnedPrices.keys.filter { key in
            key.count >= 3 && itemLower.count >= 3 &&
            (key.contains(itemLower) || itemLower.contains(key))
        }
        // Issue #52: Fehlertoleranter Fallback (Tippfehler/OCR, "saitan" ↔ "seitan") — nur
        // wenn die Teilstring-Prüfung nichts findet; ein Teilstring-Treffer hat Vorrang.
        let matchingKeys = !substringKeys.isEmpty ? substringKeys
            : store.learnedPrices.keys.filter { isFuzzyLearnedPriceMatch($0, itemLower) }
        return matchingKeys.max { a, b in
            let dateA = store.learnedPriceDates[a] ?? .distantPast
            let dateB = store.learnedPriceDates[b] ?? .distantPast
            return dateA != dateB ? dateA < dateB : a > b
        }
    }

    /// Fuzzy-Gate für gelernte Preise (Issue #52): Levenshtein-Distanz ≤ 1 UND der kürzere der
    /// beiden Namen hat mindestens 5 Zeichen. Bewusst konservativ ("milch"/"mehl" = 4, "eis" zu
    /// kurz), weil ein Fehltreffer hier still einen falschen Preis setzt.
    static func isFuzzyLearnedPriceMatch(_ a: String, _ b: String) -> Bool {
        min(a.count, b.count) >= 5 && levenshteinDistance(a, b) <= 1
    }

    /// Klassische Levenshtein-Distanz (Einfügen, Löschen, Ersetzen je Kosten 1), zeilenweise DP.
    private static func levenshteinDistance(_ a: String, _ b: String) -> Int {
        let s = Array(a), t = Array(b)
        guard !s.isEmpty else { return t.count }
        guard !t.isEmpty else { return s.count }
        var previous = Array(0...t.count)
        for i in 1...s.count {
            var current = [i] + Array(repeating: 0, count: t.count)
            for j in 1...t.count {
                let cost = s[i - 1] == t[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            previous = current
        }
        return previous[t.count]
    }

    /// Ergebnis der Entscheidungstabelle für einen gelernten Preis (Issue #10). Lebt als
    /// gemeinsame Funktion, nicht inline in `init`, weil der Bon-Import (`ReceiptScannerView`
    /// `save()`) denselben Preis direkt auf einen SCHON bestehenden Artikel zurückschreibt —
    /// beide Wege müssen dieselbe Entscheidung treffen, sonst zeigt genau der eben gescannte
    /// Artikel weiterhin den Cent-Betrag, den `init` verworfen hätte.
    enum LearnedRateUsage {
        /// Bezugsgröße passt zur Einheit des Artikels → Rate anwenden, Gesamtpreis = Rate × Menge.
        case apply
        /// Gewichts-Rate ohne belegte Menge → Rate anwenden, aber keinen Gesamtpreis bilden.
        case rateOnly
        /// Bezugsgröße fehlt oder passt nicht → gelernten Preis verwerfen, `PriceEstimator` greift.
        case reject
    }

    /// Entscheidungstabelle (Spec `learned-price-unit-and-quantity-source.md`, Abschnitt 3):
    ///
    /// | gelernte Bezugsgröße | Eimer des Artikels | `quantitySource` | Ergebnis |
    /// |---|---|---|---|
    /// | fehlt (Altdaten) | beliebig | beliebig | `reject` |
    /// | `"stk"` | `"stk"` | beliebig | `apply` |
    /// | `"stk"` | `"g"`, `"kg"`, `"l"`, … | beliebig | `reject` |
    /// | `"g"` | `"g"` | beliebig | `apply` |
    /// | `"g"` | `"stk"` (auch `unit == ""`) | `"none"` | `rateOnly` |
    /// | `"g"` | `"stk"` (auch `unit == ""`) | sonst | `reject` |
    /// | sonstige (`"kg"`, `"l"`, …) | identischer Eimer | beliebig | `apply` |
    /// | sonstige | abweichender Eimer | beliebig | `reject` |
    ///
    /// Grundsatz: Lieber kein Preis als ein falscher. Ein Preis pro Kilogramm oder Liter wird NICHT
    /// auf Gramm umgerechnet — die Richtung der Umrechnung wäre nur mit der in #15 nachgezogenen
    /// g/ml-Unterscheidung sicher.
    static func learnedRateUsage(learnedUnit: String?, itemUnit: String, quantitySource: String) -> LearnedRateUsage {
        guard let learnedUnit, !learnedUnit.trimmingCharacters(in: .whitespaces).isEmpty else { return .reject }
        let learnedBucket = unitBucket(learnedUnit)
        let itemBucket = unitBucket(itemUnit)
        if learnedBucket == itemBucket { return .apply }
        if learnedBucket == "g" && itemBucket == "stk" {
            return quantitySource == "none" ? .rateOnly : .reject
        }
        return .reject
    }

    /// Bildet eine Einheit auf ihren Vergleichs-Eimer ab: Stückzählung (`""`, `"stk"`, `"stück"`,
    /// `"st"`) auf `"stk"`, jede Gewichts-/Volumen-Subeinheit (`"g"`, `"mg"`, `"ml"`, `"cl"`,
    /// `"dl"` samt Langformen) auf `"g"`, alles andere (`"kg"`, `"l"`, `"el"`, `"tl"`, …) auf sich
    /// selbst, kleingeschrieben. Nur zwei Eimer statt literaler Einheiten, weil die Quelle des
    /// gelernten Preises kg und l auf denselben Faktor normiert (siehe `Store.learnedPriceUnits`).
    static func unitBucket(_ unit: String) -> String {
        let normalized = unit.trimmingCharacters(in: .whitespaces).lowercased()
        switch normalized {
        case "", "stk", "stück", "stueck", "st", "stk.", "stück.": return "stk"
        case "g", "gramm", "mg", "milligramm", "ml", "milliliter", "cl", "zentiliter", "dl", "deziliter": return "g"
        default: return normalized
        }
    }

    /// `estimatedPrice` is always a PER-UNIT rate (see the fuzzy `learnedPrices` lookup and
    /// `PriceEstimator` fallback in `init` above — both represent a single-unit price). Every
    /// display or budget-sum site must use this line TOTAL instead of the raw per-unit value,
    /// so e.g. "6 Bier" shows 6× the price of "1 Bier" rather than an identical number.
    /// `quantityAmount` should always be > 0 (see `QuantityStepperField`/`EditItemView.save()`,
    /// which normalize to 1 if parsing yields 0 or less), but guard defensively anyway: a
    /// non-positive quantity falls back to treating the line as a single unit rather than
    /// zeroing out or negating the estimate.
    /// Ohne belegte Mengenangabe (`quantitySource == "none"`, siehe dort) gibt es bewusst KEINEN
    /// Gesamtpreis: die stille `quantityAmount = 1` wäre geraten, und aus einer Pro-Gramm-Rate
    /// entstünde damit der gemeldete Cent-Betrag (Issue #10). `ItemRow` zeigt in diesem Fall die
    /// Rate selbst ("1,25 €/100 g") statt eines erfundenen Betrags.
    var estimatedLineTotal: Double? {
        guard quantitySource != "none" else { return nil }
        return estimatedPrice.map { $0 * (quantityAmount > 0 ? quantityAmount : 1) }
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
        purchaseRecords = (purchaseRecords ?? []) + [record]
        // Central widget-reload hook: every check-off path in every process funnels through
        // here (StoreDetailView, AllItemsView, pending-checkoff drain, the widget's own
        // intent), so the homescreen widget refreshes no matter who completed the item.
        // The system coalesces repeated calls, so loops over many items are fine.
        WidgetCenter.shared.reloadAllTimelines()
    }

    func markPending() {
        // Issue #30, A2: Das Zurücksetzen macht auch den Kaufdatensatz rückgängig, den das
        // zugehörige `markCompleted()` angelegt hat — sonst zählt ein Verklicker als echter Kauf
        // und erzeugt einen Kaufabstand von ≈ 0 Tagen, der die Nachkauf-Vorhersage verkürzt.
        // Nur Datensätze ab `completedDate` (also aus genau diesem Abhaken) und ohne Bon-Preis:
        // einer, dem ein Kassenbon inzwischen einen echten Preis zugeordnet hat, belegt einen
        // tatsächlichen Kauf und bleibt. Ohne `completedDate` (z. B. per Sync abgehakt, dort
        // entsteht kein Datensatz) wird nichts entfernt.
        if let completedDate {
            let undone = (purchaseRecords ?? []).filter { $0.date >= completedDate && $0.actualPrice == nil }
            if !undone.isEmpty {
                let undoneIDs = Set(undone.map(\.id))
                purchaseRecords = (purchaseRecords ?? []).filter { !undoneIDs.contains($0.id) }
                // Nur aus der Relationship lösen reicht nicht: `.nullify` ließe den Datensatz
                // verwaist, aber weiterhin als Kauf im Store stehen.
                for record in undone { modelContext?.delete(record) }
            }
        }
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

    /// Über diesem geschätzten GESAMTpreis für einen einzelnen Posten wird die Schätzung
    /// verworfen (nil) statt angezeigt — deutlich über jedem realistischen Einzelposten eines
    /// Wocheneinkaufs. Schützt vor Fällen wie "Müllbeutel 50l": die Zahl vor "l" beschreibt hier
    /// die Beutel-*Größe* (Fassungsvermögen pro Beutel), nicht die Kaufmenge, wird vom
    /// Mengen-Parser (rein sprachlich nicht zuverlässig anders lösbar — "Milch 2l" ist dieselbe
    /// Form und dort korrekt eine Kaufmenge) aber trotzdem als Menge behandelt — 50 × Pauschalpreis
    /// hätte sonst z. B. 200€ ergeben. Ein fehlender Preis ist ehrlicher als ein sicher falscher.
    /// Betrifft nur diese Funktion (automatisch geschätzte Preise) — echte gelernte/manuell
    /// eingetragene Preise (`estimatedPriceIsAutoDerived == false`) laufen nie hier durch.
    static let maxPlausibleLineTotal = 30.0

    /// Separate, viel höhere Grenze für ECHTE gelernte Preise (`Store.learnedPrices`, siehe
    /// `ShoppingItem.init` und `PriceProvenanceMigration` Phase C) — die kommen von einem echten
    /// Kassenbon und dürfen legitim teuer sein (ein gutes Steak, eine Flasche Wein, ein ganzer
    /// Schinken). `maxPlausibleLineTotal` (30€) ist dafür zu eng: ein unabhängiges Review hat
    /// gezeigt, dass eine gemeinsame Grenze korrekt gelernte Preise über 30€ fälschlich verworfen
    /// bzw. in der Migration sogar überschrieben hätte. Diese Grenze muss nur den gemeldeten Bug
    /// abfangen — ein um den Mengenfaktor verrutschter Wert (z. B. 1145€ statt 1,15€), eine
    /// Größenordnung jenseits jedes realistischen Einzelpostens — nicht eine enge, realistische
    /// Preisgrenze ziehen.
    static let maxPlausibleLearnedLineTotal = 200.0

    static func estimate(for name: String, category: String, unit: String, quantityAmount: Double = 1) -> Double? {
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
            (["haferflocken", "porridge", "oats"], 1.80),
            (["müsli", "cornflakes", "granola", "cereal"], 2.50),
            (["mehl", "flour"], 1.20),
            (["zucker", "sugar"], 1.50),
        ]

        let divisor = unitDivisor(for: unit)
        var perUnit: Double?

        for entry in specificPrices {
            if entry.keywords.contains(where: { nameLower.contains($0) }) {
                perUnit = entry.price / divisor
                break
            }
        }

        if perUnit == nil {
            // Category fallback
            // Deckt alle 26 Kategorien aus AssignmentService.categoryOrder ab (vorher nur 9 von
            // 26 — u.a. "Konserven" fehlte, weshalb z.B. "Haferflocken" ohne Preis blieb). Die
            // frühere "Haushalt"-Kategorie hieß nie so in categoryOrder (echt: "Haushaltswaren")
            // und "Kosmetik" existierte dort nie — beide waren toter Code, hier korrigiert/entfernt.
            switch category {
            case "Obst & Gemüse": perUnit = 2.50 / divisor
            case "Fleisch & Wurst": perUnit = 4.50 / divisor
            case "Milchprodukte": perUnit = 2.00 / divisor
            case "Backwaren": perUnit = 2.20 / divisor
            case "Getränke": perUnit = 1.50 / divisor
            case "Tiefkühlkost": perUnit = 3.50 / divisor
            case "Snacks": perUnit = 1.80 / divisor
            case "Gewürze & Backen": perUnit = 3.20 / divisor
            case "Konserven": perUnit = 1.70 / divisor
            case "Lebensmittel": perUnit = 2.90 / divisor
            case "Körperpflege": perUnit = 4.00 / divisor
            case "Reinigung": perUnit = 3.90 / divisor
            case "Medikamente": perUnit = 6.00 / divisor
            case "Babybedarf": perUnit = 8.00 / divisor
            case "Haushaltswaren": perUnit = 5.00 / divisor
            case "Küchenausstattung": perUnit = 9.50 / divisor
            case "Elektronik": perUnit = 14.00 / divisor
            case "Textilien": perUnit = 7.00 / divisor
            case "Schreibwaren": perUnit = 3.00 / divisor
            case "Spielzeug": perUnit = 10.00 / divisor
            case "Dekoration": perUnit = 6.50 / divisor
            case "Werkzeug": perUnit = 12.00 / divisor
            case "Garten": perUnit = 7.50 / divisor
            case "Farbe & Lack": perUnit = 15.00 / divisor
            case "Sanitär": perUnit = 11.50 / divisor
            case "Baumaterial": perUnit = 13.50 / divisor
            default: perUnit = nil
            }
        }

        guard let perUnit else { return nil }
        let plausibleQuantity = quantityAmount > 0 ? quantityAmount : 1
        guard perUnit * plausibleQuantity <= maxPlausibleLineTotal else { return nil }
        return perUnit
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
///
/// Phase C (added for the "Skyr 500g → 1145€" bug, reported 2026-08-13) additionally repairs
/// `Store.learnedPrices` itself: a corrupted entry (a full line total saved under a per-unit key,
/// before an earlier fix) survives Phase A/B untouched — those only rewrite `ShoppingItem`
/// instances — and keeps poisoning every future item with that name via the fuzzy lookup in
/// `ShoppingItem.init`. Unlike Phase B there's no hardcoded catalog constant to compare a learned
/// price against, so the fingerprint instead uses matching `PurchaseRecord` history: a sub-unit,
/// large-quantity purchase of the same (fuzzy-matched) name at the same store whose quantity would
/// make the stored price imply an implausible line total.
enum PriceProvenanceMigration {
    static let flagKey = "priceProvenanceMigrationV3Applied"
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
            item.estimatedPrice = PriceEstimator.estimate(for: item.name, category: item.category, unit: item.unit, quantityAmount: item.quantityAmount)
        }

        // Phase C: repair Store.learnedPrices entries themselves (see class doc above) — otherwise
        // a corrupted entry keeps producing wrong prices for every future item with that name, even
        // after Phase A/B fixed all *existing* items.
        if let stores = try? context.fetch(FetchDescriptor<Store>()) {
            let allRecords = (try? context.fetch(FetchDescriptor<PurchaseRecord>())) ?? []
            for store in stores {
                for (key, price) in store.learnedPrices {
                    let matchingRecords = allRecords.filter { record in
                        guard record.storeName == store.name,
                              subUnits.contains(record.unit.trimmingCharacters(in: .whitespaces).lowercased()),
                              record.quantityAmount > minQuantityForSafeRewrite
                        else { return false }
                        let rn = record.itemName.lowercased()
                        return key.count >= 3 && rn.count >= 3 && (rn.contains(key) || key.contains(rn))
                    }
                    guard let mostRecentMatch = matchingRecords.max(by: { $0.date < $1.date }),
                          price * mostRecentMatch.quantityAmount > PriceEstimator.maxPlausibleLearnedLineTotal
                    else { continue }
                    store.learnedPrices[key] = price / mostRecentMatch.quantityAmount
                }
            }
        }

        try? context.save()
        UserDefaults.standard.set(true, forKey: flagKey)
    }
}
