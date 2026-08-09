import SwiftData
import SwiftUI

@Model
class Store {
    // Jede gespeicherte Eigenschaft braucht für SwiftDatas automatische CloudKit-Spiegelung
    // (SharedModelContainer.make(), erster Versuch: cloudKitDatabase: .private(...)) entweder
    // optional zu sein oder einen Standardwert zu haben — sonst schlägt ModelContainer-Init mit
    // SwiftDataError.loadIssueModelContainer fehl. Live bestätigt (30.07.2026): weder in
    // Development noch Production existierte für Store/ShoppingItem/etc. je ein CloudKit-
    // Record-Typ, weil genau diese Anforderung verletzt war. Die echten Werte kommen weiterhin
    // ausschließlich aus init() unten — diese Defaults werden dort immer sofort überschrieben,
    // sind also rein für die Schema-Validierung da, nie im echten Betrieb sichtbar.
    var id: UUID = UUID()
    var name: String = ""
    var emoji: String = ""
    var colorHex: String = "#808080"
    var visitsPerWeek: Double = 1.0
    var isActive: Bool = true
    var isPaused: Bool = false
    var categories: [String] = []
    var countryCode: String = "DE"
    var isCustom: Bool = false
    // Learned aisle order: item name -> average completion position
    var itemOrderMap: [String: Double] = [:]
    // Learned prices per store: item name (lowercased) -> last confirmed price from receipt
    var learnedPrices: [String: Double] = [:]
    /// Zeitstempel pro `learnedPrices`-Eintrag — ausschließlich fürs Sync-Merge geteilter Listen
    /// nötig (bei einem Preis-Konflikt zwischen zwei Geräten/Mitgliedern gewinnt der spätere,
    /// siehe `SharedStoreService.mergePrices`). Additiv wie `categoryManuallySet`/`completedBy`
    /// bei `ShoppingItem`, kein Schema-Versionsbump nötig.
    var learnedPriceDates: [String: Date] = [:]
    var sortIndex: Int = 0

    // CloudKit verlangt für automatische Spiegelung, dass ALLE To-many-Relationships optional
    // sind — nicht nur einen Standardwert haben (anders als bei skalaren Eigenschaften). Live
    // per Test bestätigt (31.07.2026, RestockTests): SwiftData wirft sonst
    // SwiftDataError.loadIssueModelContainer mit der expliziten Meldung "CloudKit integration
    // requires that all relationships be optional" — der Grund, warum der reine
    // Default-Value-Fix bei skalaren Feldern (siehe oben) allein NICHT ausreichte. Zugriffsstellen
    // im ganzen Code nutzen weiterhin `items` als nicht-optionale Liste über den Fallback `?? []`.
    @Relationship(deleteRule: .cascade, inverse: \ShoppingItem.store)
    var items: [ShoppingItem]? = []

    var shareID: String? {
        get { UserDefaults.standard.string(forKey: "shareID_\(id.uuidString)") }
        set {
            if let v = newValue { UserDefaults.standard.set(v, forKey: "shareID_\(id.uuidString)") }
            else { UserDefaults.standard.removeObject(forKey: "shareID_\(id.uuidString)") }
        }
    }

    var isSharedByMe: Bool {
        get { UserDefaults.standard.bool(forKey: "isSharedByMe_\(id.uuidString)") }
        set { UserDefaults.standard.set(newValue, forKey: "isSharedByMe_\(id.uuidString)") }
    }

    /// Per-store view preference (StoreDetailView's "···" menu): show pending items grouped into
    /// category sections instead of one flat list. UserDefaults-backed like `shareID`/`isSharedByMe`
    /// above — deliberately NOT a SwiftData schema field, so no schema migration is needed.
    /// Defaults to `false` (flat list, i.e. the previous behavior).
    var groupByCategory: Bool {
        get { UserDefaults.standard.bool(forKey: "groupByCategory_\(id.uuidString)") }
        set { UserDefaults.standard.set(newValue, forKey: "groupByCategory_\(id.uuidString)") }
    }

    /// Display names of everyone who has joined/published this shared store, synced via SharedStoreService.
    var members: [String] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "members_\(id.uuidString)"),
                  let arr = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return arr
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: "members_\(id.uuidString)")
        }
    }

    func addMember(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !members.contains(trimmed) else { return }
        members.append(trimmed)
    }

    init(
        name: String,
        emoji: String,
        colorHex: String,
        visitsPerWeek: Double = 1.0,
        categories: [String] = [],
        countryCode: String = "DE",
        isCustom: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.visitsPerWeek = visitsPerWeek
        self.isActive = true
        self.isPaused = false
        self.categories = categories
        self.countryCode = countryCode
        self.isCustom = isCustom
        self.itemOrderMap = [:]
        self.learnedPrices = [:]
        self.learnedPriceDates = [:]
    }

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    /// Monochromes SF-Symbol für die Laden-Kacheln des Redesigns, abgeleitet vom (weiterhin
    /// editierbaren) Emoji des Ladens — Supermarkt-Wagen, Drogerie-Tropfen, Werkzeug etc.
    /// Fallback für unbekannte/eigene Emojis ist die generische Ladenfront.
    var iconSystemName: String {
        switch emoji {
        case "🛒": return "cart"
        case "🧴": return "drop"
        case "💊": return "pills"
        case "🔨": return "hammer"
        case "🏗️": return "wrench.and.screwdriver"
        case "🔧": return "wrench.adjustable"
        case "🏃": return "figure.run"
        case "🏷️": return "tag"
        case "🎯": return "target"
        case "🌿": return "leaf"
        case "🏬": return "building.2"
        case "🛋️": return "sofa"
        default:  return "storefront"
        }
    }

    /// User-facing toggle (Settings) — when off, falls back to insertion order instead of the
    /// learned aisle order. Read directly from UserDefaults rather than via `@AppStorage` since
    /// this is a model class, not a View. Uses the app-group suite (matching `UserIdentity` in
    /// ShoppingItem.swift) rather than `.standard` since this file is also compiled into the
    /// SmartCartWidgets extension target, which runs in a different process/sandbox and would
    /// otherwise never see the value the user set in the main app's Settings.
    /// `object(forKey:) as? Bool ?? true` (rather than `bool(forKey:)`) keeps the default `true`
    /// even before the user ever touches the Settings toggle, regardless of which process reads it first.
    private var autoSortByLearnedOrderEnabled: Bool {
        let suite = UserDefaults(suiteName: "group.com.johannesemmrich.SmartCart") ?? .standard
        return suite.object(forKey: "autoSortByLearnedOrder") as? Bool ?? true
    }

    var pendingItems: [ShoppingItem] {
        let sortByLearnedOrder = autoSortByLearnedOrderEnabled
        return (items ?? []).filter { !$0.isCompleted }.sorted { a, b in
            if a.isUrgent != b.isUrgent { return a.isUrgent }
            if sortByLearnedOrder {
                let posA = itemOrderMap[a.name.lowercased()] ?? 999
                let posB = itemOrderMap[b.name.lowercased()] ?? 999
                if posA != posB { return posA < posB }
                // Neither item has a learned checkout position yet — fall back to a realistic
                // supermarket aisle order instead of jumping straight to insertion order.
                let categoryA = a.categoryManuallySet ? a.category : AssignmentService.category(for: a.name)
                let categoryB = b.categoryManuallySet ? b.category : AssignmentService.category(for: b.name)
                let aisleA = AssignmentService.categoryOrder.firstIndex(of: categoryA) ?? Int.max
                let aisleB = AssignmentService.categoryOrder.firstIndex(of: categoryB) ?? Int.max
                if aisleA != aisleB { return aisleA < aisleB }
            }
            return a.addedDate < b.addedDate
        }
    }

    var completedItems: [ShoppingItem] {
        (items ?? []).filter { $0.isCompleted }
    }

    /// Items stay in `completedItems` on purpose after check-off (deleting them would make
    /// re-adding harder), but that means a running progress count/bar based on `completedItems`
    /// would grow forever across shopping trips instead of reflecting the current one. Items
    /// checked off within this window still count as "part of the current trip"; older ones drop
    /// out of any progress count derived from this (but stay fully visible in the "Erledigt"
    /// section — nothing here deletes or hides them from that list). Shared between
    /// `StoreDetailView` (the store screen's progress bar/text) and `LiveActivityService`
    /// (Dynamic Island/Lock Screen) so both always agree on the same number for the same store.
    static let recentCompletionWindow: TimeInterval = 3600

    var recentlyCompletedItems: [ShoppingItem] {
        completedItems.filter {
            guard let completedDate = $0.completedDate else { return false }
            return Date().timeIntervalSince(completedDate) < Store.recentCompletionWindow
        }
    }

    /// `completedNames` is the caller's full completion history for this session, replayed on
    /// every call (not just the newest name) — callers append-then-pass-the-whole-array so the
    /// running average always reflects each item's usual position. That replay makes duplicates
    /// dangerous: if a name appears twice (item unchecked and rechecked within one visit, or the
    /// same staple bought again on a later trip before completed items were ever cleared), the
    /// second occurrence would be processed again WITHIN this same call and average against the
    /// value the first occurrence just set — dragging the learned position toward the later,
    /// accidental repeat instead of the item's real typical spot. Only the first occurrence of
    /// each name counts per call.
    func recordCompletionOrder(_ completedNames: [String]) {
        var seen = Set<String>()
        for (index, name) in completedNames.enumerated() {
            let key = name.lowercased()
            guard seen.insert(key).inserted else { continue }
            if let existing = itemOrderMap[key] {
                itemOrderMap[key] = (existing + Double(index)) / 2.0
            } else {
                itemOrderMap[key] = Double(index)
            }
        }
    }
}

// MARK: - Preset stores per country

extension Store {
    static func presets(for countryCode: String) -> [Store] {
        switch countryCode {
        case "DE":
            return [
                Store(name: "Lidl",     emoji: "🛒", colorHex: "#2563EB", visitsPerWeek: 2, categories: Category.grocery,   countryCode: "DE"), // Blau
                Store(name: "Edeka",    emoji: "🛒", colorHex: "#D97706", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "DE"), // Amber/Gold
                Store(name: "Rewe",     emoji: "🛒", colorHex: "#DC2626", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "DE"), // Rot
                Store(name: "Aldi",     emoji: "🛒", colorHex: "#1E40AF", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "DE"), // Dunkelblau
                Store(name: "DM",       emoji: "🧴", colorHex: "#DB2777", visitsPerWeek: 1, categories: Category.drugstore, countryCode: "DE"), // Pink
                Store(name: "Rossmann", emoji: "🧴", colorHex: "#EA580C", visitsPerWeek: 1, categories: Category.drugstore, countryCode: "DE"), // Orange
                Store(name: "Penny",    emoji: "🛒", colorHex: "#7C3AED", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "DE"), // Lila
                Store(name: "Kaufland", emoji: "🛒", colorHex: "#0F766E", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "DE"), // Teal
                Store(name: "Netto",    emoji: "🛒", colorHex: "#F59E0B", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "DE"), // Amber
                Store(name: "Action",      emoji: "🏷️", colorHex: "#E53935", visitsPerWeek: 1,   categories: Category.variety,   countryCode: "DE"), // Rot
                Store(name: "Müller",     emoji: "🧴", colorHex: "#5B21B6", visitsPerWeek: 1,   categories: Category.drugstore, countryCode: "DE"), // Violett
                Store(name: "Decathlon",  emoji: "🏃", colorHex: "#007DC5", visitsPerWeek: 0.5, categories: Category.sports,    countryCode: "DE"), // Blau
                Store(name: "Hornbach",   emoji: "🏗️", colorHex: "#E53935", visitsPerWeek: 0.5, categories: Category.hardware,  countryCode: "DE"),
                Store(name: "OBI",        emoji: "🔨", colorHex: "#FF6F00", visitsPerWeek: 0.5, categories: Category.hardware,  countryCode: "DE"),
                Store(name: "Bauhaus",    emoji: "🔧", colorHex: "#1565C0", visitsPerWeek: 0.5, categories: Category.hardware,  countryCode: "DE"),
                Store(name: "Hagebaumarkt", emoji: "🏗️", colorHex: "#4CAF50", visitsPerWeek: 0.5, categories: Category.hardware, countryCode: "DE"),
                Store(name: "IKEA",       emoji: "🛋️", colorHex: "#0058A3", visitsPerWeek: 0.25, categories: Category.variety,  countryCode: "DE"),
            ]
        case "AT":
            return [
                Store(name: "Billa",  emoji: "🛒", colorHex: "#DC2626", visitsPerWeek: 2, categories: Category.grocery,   countryCode: "AT"), // Rot
                Store(name: "Spar",   emoji: "🛒", colorHex: "#16A34A", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "AT"), // Grün
                Store(name: "Hofer",  emoji: "🛒", colorHex: "#1D4ED8", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "AT"), // Blau
                Store(name: "Lidl",   emoji: "🛒", colorHex: "#2563EB", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "AT"), // Blau
                Store(name: "DM",     emoji: "🧴", colorHex: "#DB2777", visitsPerWeek: 1, categories: Category.drugstore, countryCode: "AT"), // Pink
                Store(name: "Müller", emoji: "🧴", colorHex: "#EA580C", visitsPerWeek: 1, categories: Category.drugstore, countryCode: "AT"), // Orange
                Store(name: "Action",    emoji: "🏷️", colorHex: "#E53935", visitsPerWeek: 1,   categories: Category.variety,  countryCode: "AT"), // Rot
                Store(name: "Decathlon", emoji: "🏃", colorHex: "#007DC5", visitsPerWeek: 0.5, categories: Category.sports,   countryCode: "AT"),
                Store(name: "Hornbach",  emoji: "🏗️", colorHex: "#E53935", visitsPerWeek: 0.5, categories: Category.hardware, countryCode: "AT"),
                Store(name: "OBI",       emoji: "🔨", colorHex: "#FF6F00", visitsPerWeek: 0.5, categories: Category.hardware, countryCode: "AT"),
                Store(name: "IKEA",      emoji: "🛋️", colorHex: "#0058A3", visitsPerWeek: 0.25, categories: Category.variety, countryCode: "AT"),
            ]
        case "CH":
            return [
                Store(name: "Migros",    emoji: "🛒", colorHex: "#FF6600", visitsPerWeek: 2, categories: Category.grocery,   countryCode: "CH"),
                Store(name: "Coop",      emoji: "🛒", colorHex: "#E2001A", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "CH"),
                Store(name: "Lidl",      emoji: "🛒", colorHex: "#0050AA", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "CH"),
                Store(name: "Aldi",      emoji: "🛒", colorHex: "#005CA9", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "CH"),
                Store(name: "Denner",    emoji: "🛒", colorHex: "#E2001A", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "CH"),
                Store(name: "DM",        emoji: "🧴", colorHex: "#CC1033", visitsPerWeek: 1,   categories: Category.drugstore, countryCode: "CH"),
                Store(name: "Decathlon", emoji: "🏃", colorHex: "#007DC5", visitsPerWeek: 0.5, categories: Category.sports,   countryCode: "CH"),
                Store(name: "Hornbach",  emoji: "🏗️", colorHex: "#E53935", visitsPerWeek: 0.5, categories: Category.hardware,  countryCode: "CH"),
                Store(name: "OBI",       emoji: "🔨", colorHex: "#FF6F00", visitsPerWeek: 0.5, categories: Category.hardware,  countryCode: "CH"),
                Store(name: "IKEA",      emoji: "🛋️", colorHex: "#0058A3", visitsPerWeek: 0.25, categories: Category.variety, countryCode: "CH"),
            ]
        case "US":
            return [
                Store(name: "Walmart", emoji: "🛒", colorHex: "#0071CE", visitsPerWeek: 1, categories: Category.grocery, countryCode: "US"),
                Store(name: "Target", emoji: "🎯", colorHex: "#CC0000", visitsPerWeek: 1, categories: Category.grocery + Category.drugstore, countryCode: "US"),
                Store(name: "Kroger", emoji: "🛒", colorHex: "#0066CC", visitsPerWeek: 2, categories: Category.grocery, countryCode: "US"),
                Store(name: "Whole Foods", emoji: "🌿", colorHex: "#00674B", visitsPerWeek: 1, categories: Category.grocery, countryCode: "US"),
                Store(name: "CVS",        emoji: "💊", colorHex: "#CC0000", visitsPerWeek: 1,   categories: Category.drugstore, countryCode: "US"),
                Store(name: "Walgreens",  emoji: "💊", colorHex: "#E31837", visitsPerWeek: 1,   categories: Category.drugstore, countryCode: "US"),
                Store(name: "Home Depot", emoji: "🏗️", colorHex: "#E53935", visitsPerWeek: 0.5, categories: Category.hardware,  countryCode: "US"),
                Store(name: "Lowe's",     emoji: "🔨", colorHex: "#1565C0", visitsPerWeek: 0.5, categories: Category.hardware,  countryCode: "US"),
                Store(name: "IKEA",       emoji: "🛋️", colorHex: "#0058A3", visitsPerWeek: 0.25, categories: Category.variety, countryCode: "US"),
            ]
        case "GB":
            return [
                Store(name: "Tesco", emoji: "🛒", colorHex: "#005DA0", visitsPerWeek: 2, categories: Category.grocery, countryCode: "GB"),
                Store(name: "Sainsbury's", emoji: "🛒", colorHex: "#FF7B00", visitsPerWeek: 1, categories: Category.grocery, countryCode: "GB"),
                Store(name: "Asda", emoji: "🛒", colorHex: "#7DC241", visitsPerWeek: 1, categories: Category.grocery, countryCode: "GB"),
                Store(name: "Morrisons", emoji: "🛒", colorHex: "#009BDE", visitsPerWeek: 1, categories: Category.grocery, countryCode: "GB"),
                Store(name: "Lidl", emoji: "🛒", colorHex: "#0050AA", visitsPerWeek: 1, categories: Category.grocery, countryCode: "GB"),
                Store(name: "Boots", emoji: "💊", colorHex: "#003B71", visitsPerWeek: 1,   categories: Category.drugstore, countryCode: "GB"),
                Store(name: "B&Q",   emoji: "🔨", colorHex: "#FF6F00", visitsPerWeek: 0.5, categories: Category.hardware,  countryCode: "GB"),
                Store(name: "IKEA",  emoji: "🛋️", colorHex: "#0058A3", visitsPerWeek: 0.25, categories: Category.variety, countryCode: "GB"),
            ]
        case "BE":
            return [
                Store(name: "Carrefour", emoji: "🛒", colorHex: "#1D4ED8", visitsPerWeek: 2, categories: Category.grocery,   countryCode: "BE"), // Blau
                Store(name: "Delhaize",  emoji: "🦁", colorHex: "#DC2626", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "BE"), // Rot
                Store(name: "Colruyt",   emoji: "🛒", colorHex: "#D97706", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "BE"), // Amber
                Store(name: "Lidl",      emoji: "🛒", colorHex: "#2563EB", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "BE"), // Blau
                Store(name: "Aldi",      emoji: "🛒", colorHex: "#1E40AF", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "BE"), // Dunkelblau
                Store(name: "Okay",      emoji: "🛒", colorHex: "#EA580C", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "BE"), // Orange
                Store(name: "Action",          emoji: "🏷️", colorHex: "#E53935", visitsPerWeek: 1,   categories: Category.variety,   countryCode: "BE"), // Rot
                Store(name: "DM",              emoji: "🧴", colorHex: "#DB2777", visitsPerWeek: 1,   categories: Category.drugstore, countryCode: "BE"), // Pink
                Store(name: "Di",              emoji: "🧴", colorHex: "#00A651", visitsPerWeek: 1,   categories: Category.drugstore, countryCode: "BE"), // Grün
                Store(name: "Decathlon",       emoji: "🏃", colorHex: "#007DC5", visitsPerWeek: 0.5, categories: Category.sports,    countryCode: "BE"),
                Store(name: "Carrefour Express", emoji: "🛒", colorHex: "#0050C8", visitsPerWeek: 1,   categories: Category.grocery,  countryCode: "BE"), // Blau
                Store(name: "Brico",    emoji: "🔨", colorHex: "#FF6F00", visitsPerWeek: 0.5, categories: Category.hardware, countryCode: "BE"),
                Store(name: "Hornbach", emoji: "🏗️", colorHex: "#E53935", visitsPerWeek: 0.5, categories: Category.hardware, countryCode: "BE"),
                Store(name: "IKEA",     emoji: "🛋️", colorHex: "#0058A3", visitsPerWeek: 0.25, categories: Category.variety, countryCode: "BE"),
            ]
        case "NL":
            return [
                Store(name: "Albert Heijn", emoji: "🛒", colorHex: "#0072CE", visitsPerWeek: 2, categories: Category.grocery,   countryCode: "NL"), // AH-Blau
                Store(name: "Jumbo",        emoji: "🛒", colorHex: "#D97706", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "NL"), // Gelb/Amber
                Store(name: "Lidl",         emoji: "🛒", colorHex: "#2563EB", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "NL"), // Blau
                Store(name: "Aldi",         emoji: "🛒", colorHex: "#1E40AF", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "NL"), // Dunkelblau
                Store(name: "Action",       emoji: "🏷️", colorHex: "#E53935", visitsPerWeek: 1,   categories: Category.variety,   countryCode: "NL"), // Rot (niederländische Kette)
                Store(name: "Plus",         emoji: "🛒", colorHex: "#16A34A", visitsPerWeek: 1,   categories: Category.grocery,   countryCode: "NL"), // Grün
                Store(name: "Kruidvat",     emoji: "🧴", colorHex: "#7C3AED", visitsPerWeek: 1,   categories: Category.drugstore, countryCode: "NL"), // Lila
                Store(name: "Etos",         emoji: "🧴", colorHex: "#DB2777", visitsPerWeek: 1,   categories: Category.drugstore, countryCode: "NL"), // Pink
                Store(name: "Decathlon",    emoji: "🏃", colorHex: "#007DC5", visitsPerWeek: 0.5, categories: Category.sports,    countryCode: "NL"),
                Store(name: "Gamma",        emoji: "🔨", colorHex: "#FF6F00", visitsPerWeek: 0.5, categories: Category.hardware,  countryCode: "NL"),
                Store(name: "Hornbach",     emoji: "🏗️", colorHex: "#E53935", visitsPerWeek: 0.5, categories: Category.hardware,  countryCode: "NL"),
                Store(name: "IKEA",         emoji: "🛋️", colorHex: "#0058A3", visitsPerWeek: 0.25, categories: Category.variety, countryCode: "NL"),
            ]
        case "FR":
            return [
                Store(name: "Carrefour",    emoji: "🛒", colorHex: "#1D4ED8", visitsPerWeek: 2, categories: Category.grocery,                    countryCode: "FR"), // Blau
                Store(name: "E.Leclerc",    emoji: "🛒", colorHex: "#0F766E", visitsPerWeek: 1, categories: Category.grocery,                    countryCode: "FR"), // Teal
                Store(name: "Intermarché",  emoji: "🛒", colorHex: "#DC2626", visitsPerWeek: 1, categories: Category.grocery,                    countryCode: "FR"), // Rot
                Store(name: "Lidl",         emoji: "🛒", colorHex: "#2563EB", visitsPerWeek: 1, categories: Category.grocery,                    countryCode: "FR"), // Blau
                Store(name: "Aldi",         emoji: "🛒", colorHex: "#1E40AF", visitsPerWeek: 1, categories: Category.grocery,                    countryCode: "FR"), // Dunkelblau
                Store(name: "Monoprix",     emoji: "🛒", colorHex: "#7C3AED", visitsPerWeek: 1, categories: Category.grocery + Category.drugstore, countryCode: "FR"), // Lila
                Store(name: "Pharmacie",    emoji: "💊", colorHex: "#16A34A", visitsPerWeek: 1,   categories: Category.drugstore, countryCode: "FR"), // Grün
                Store(name: "Decathlon",    emoji: "🏃", colorHex: "#007DC5", visitsPerWeek: 0.5, categories: Category.sports,   countryCode: "FR"),
                Store(name: "Leroy Merlin", emoji: "🏗️", colorHex: "#4CAF50", visitsPerWeek: 0.5, categories: Category.hardware, countryCode: "FR"),
                Store(name: "Castorama",    emoji: "🔨", colorHex: "#1565C0", visitsPerWeek: 0.5, categories: Category.hardware, countryCode: "FR"),
                Store(name: "IKEA",         emoji: "🛋️", colorHex: "#0058A3", visitsPerWeek: 0.25, categories: Category.variety, countryCode: "FR"),
            ]
        case "IT":
            return [
                Store(name: "Esselunga", emoji: "🛒", colorHex: "#DC2626", visitsPerWeek: 2, categories: Category.grocery,   countryCode: "IT"), // Rot
                Store(name: "Conad",     emoji: "🛒", colorHex: "#D97706", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "IT"), // Amber
                Store(name: "Coop",      emoji: "🛒", colorHex: "#16A34A", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "IT"), // Grün
                Store(name: "Lidl",      emoji: "🛒", colorHex: "#2563EB", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "IT"), // Blau
                Store(name: "Aldi",      emoji: "🛒", colorHex: "#1E40AF", visitsPerWeek: 1, categories: Category.grocery,   countryCode: "IT"), // Dunkelblau
                Store(name: "Farmacia",     emoji: "💊", colorHex: "#16A34A", visitsPerWeek: 1,   categories: Category.drugstore, countryCode: "IT"), // Grün
                Store(name: "Decathlon",    emoji: "🏃", colorHex: "#007DC5", visitsPerWeek: 0.5, categories: Category.sports,   countryCode: "IT"),
                Store(name: "Leroy Merlin", emoji: "🏗️", colorHex: "#4CAF50", visitsPerWeek: 0.5, categories: Category.hardware, countryCode: "IT"),
                Store(name: "IKEA",         emoji: "🛋️", colorHex: "#0058A3", visitsPerWeek: 0.25, categories: Category.variety, countryCode: "IT"),
            ]
        case "ES":
            return [
                Store(name: "Mercadona",     emoji: "🛒", colorHex: "#16A34A", visitsPerWeek: 2, categories: Category.grocery,                    countryCode: "ES"), // Grün
                Store(name: "Carrefour",     emoji: "🛒", colorHex: "#1D4ED8", visitsPerWeek: 1, categories: Category.grocery,                    countryCode: "ES"), // Blau
                Store(name: "Lidl",          emoji: "🛒", colorHex: "#2563EB", visitsPerWeek: 1, categories: Category.grocery,                    countryCode: "ES"), // Blau
                Store(name: "Aldi",          emoji: "🛒", colorHex: "#1E40AF", visitsPerWeek: 1, categories: Category.grocery,                    countryCode: "ES"), // Dunkelblau
                Store(name: "El Corte Inglés", emoji: "🏬", colorHex: "#0F766E", visitsPerWeek: 1, categories: Category.grocery + Category.drugstore, countryCode: "ES"), // Teal
                Store(name: "Farmacia",      emoji: "💊", colorHex: "#16A34A", visitsPerWeek: 1,   categories: Category.drugstore, countryCode: "ES"), // Grün
                Store(name: "Decathlon",     emoji: "🏃", colorHex: "#007DC5", visitsPerWeek: 0.5, categories: Category.sports,   countryCode: "ES"),
                Store(name: "Leroy Merlin",  emoji: "🏗️", colorHex: "#4CAF50", visitsPerWeek: 0.5, categories: Category.hardware, countryCode: "ES"),
                Store(name: "IKEA",          emoji: "🛋️", colorHex: "#0058A3", visitsPerWeek: 0.25, categories: Category.variety, countryCode: "ES"),
            ]
        default:
            return []
        }
    }

    static var allPresets: [Store] {
        availableCountries.flatMap { presets(for: $0.code) }
    }

    static let availableCountries: [(code: String, name: String, flag: String)] = [
        ("DE", "Deutschland",      "🇩🇪"),
        ("AT", "Österreich",       "🇦🇹"),
        ("CH", "Schweiz",          "🇨🇭"),
        ("BE", "Belgique / België","🇧🇪"),
        ("NL", "Nederland",        "🇳🇱"),
        ("FR", "France",           "🇫🇷"),
        ("IT", "Italia",           "🇮🇹"),
        ("ES", "España",           "🇪🇸"),
        ("GB", "United Kingdom",   "🇬🇧"),
        ("US", "United States",    "🇺🇸"),
    ]
}

enum Category {
    static let grocery   = ["Lebensmittel", "Obst & Gemüse", "Fleisch & Wurst", "Milchprodukte", "Backwaren", "Tiefkühlkost", "Getränke", "Snacks", "Konserven"]
    static let drugstore = ["Körperpflege", "Kosmetik", "Reinigung", "Medikamente", "Haushalt", "Babybedarf"]
    /// Variety / discount stores (Action, Woolworth, etc.) — general merchandise, small appliances, seasonal, stationery
    static let variety   = ["Haushaltswaren", "Elektronik", "Saisonales", "Schreibwaren", "Werkzeug", "Spielzeug", "Dekoration"]
    static let hardware  = ["Werkzeug", "Baumaterial", "Garten", "Farbe & Lack", "Sanitär"]
    static let sports    = ["Sport & Outdoor", "Fitness", "Fahrrad", "Camping", "Schwimmen", "Bekleidung"]
}
