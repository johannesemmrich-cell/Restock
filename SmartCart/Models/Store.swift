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
    // Früher: gelernte Einkaufsreihenfolge (absolute Abhak-Position). Seit Issue #79 weder gelesen
    // noch geschrieben — die Werte waren durch die 50/50-Mittelung und die bei jedem Öffnen der
    // Ladenansicht neu beginnende Zählung verzerrt. Ersetzt durch `routeModel` (pro Gerät, siehe
    // `ShoppingRoute.swift`). Das Feld bleibt nur fürs SwiftData-/CloudKit-Schema stehen.
    var itemOrderMap: [String: Double] = [:]
    // Learned prices per store: item name (lowercased) -> last confirmed price from receipt
    var learnedPrices: [String: Double] = [:]
    /// Zeitstempel pro `learnedPrices`-Eintrag — ausschließlich fürs Sync-Merge geteilter Listen
    /// nötig (bei einem Preis-Konflikt zwischen zwei Geräten/Mitgliedern gewinnt der spätere,
    /// siehe `LearnedPriceSync.merge`). Additiv wie `categoryManuallySet`/`completedBy`
    /// bei `ShoppingItem`, kein Schema-Versionsbump nötig.
    var learnedPriceDates: [String: Date] = [:]
    /// Bezugsgröße pro `learnedPrices`-Eintrag: `"stk"` (Stückpreis) oder `"g"` (Gewichts- bzw.
    /// Volumen-Subeinheit — g, mg, ml, cl, dl). Ohne diese Angabe ist ein gelernter Preis nicht
    /// anwendbar: 4,99 € für eine 400-g-Packung ergeben korrekt 0,0125 €/g, als Stückpreis
    /// gelesen aber 0,01 € auf der Liste (Issue #10). Additiv wie `learnedPriceDates` oben —
    /// kein Schema-Versionsbump, CloudKit-tauglich, weil skalar mit Standardwert.
    ///
    /// Fehlt ein Schlüssel hier, stammt der Preis aus der Zeit vor dieser Änderung und wird von
    /// `ShoppingItem.init` NIE angewendet (PO-Entscheidung; Reparatur der Altdaten: Issue #11).
    ///
    /// Gramm und Milliliter liegen bewusst im selben Eimer: die Quelle
    /// (`ReceiptParserService.weightBasisFromName` bzw. der Gewichtszeilen-Zweig) normiert kg UND
    /// l auf denselben Faktor 1000, aus dem gespeicherten Preis ist beides nicht mehr zu
    /// unterscheiden. Eine dritte, literal genaue Einheit wäre vorgetäuschte Genauigkeit → #15.
    ///
    /// Reist bei geteilten Listen gemeinsam mit Betrag und Zeitstempel (`LearnedPriceSync` in
    /// `SharedStoreService.swift`, Issue #53).
    var learnedPriceUnits: [String: String] = [:]
    /// Eigene Kategorien dieses Ladens (Issue #85): Name → Emoji. Nur lebende Kategorien.
    /// Additiv wie `learnedPriceDates` — kein Schema-Versionsbump, CloudKit-tauglich.
    var customCategoryEmojis: [String: String] = [:]
    /// Name → Zeitpunkt der letzten Änderung, auch für gelöschte Kategorien (Löschvermerk) —
    /// nur fürs Abgleichen geteilter Läden (`StoreCategories.merge`), wie `learnedPriceDates`.
    var customCategoryDates: [String: Date] = [:]
    /// Gemerkte Zuordnung Artikelschlüssel (`ShoppingRoute.itemKey`) → eigene Kategorie: ein
    /// neu hinzugefügter „Feta“ landet in diesem Laden wieder in „Kühltheke hinten“
    /// (`ShoppingItem.init`).
    var categoryAssignments: [String: String] = [:]
    /// Artikelschlüssel → Zeitpunkt der letzten Änderung der Zuordnung, auch fürs Vergessen
    /// (Löschvermerk) — nur fürs Abgleichen geteilter Läden (Issue #94), wie `customCategoryDates`.
    var categoryAssignmentDates: [String: Date] = [:]
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

    /// Frühere Ansichtseinstellung pro Laden („Nach Kategorie gruppieren“). Seit Issue #79 nur noch
    /// gelesen, um den Anfangswert von `sortMode` zu bestimmen.
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
        self.learnedPriceUnits = [:]
        self.customCategoryEmojis = [:]
        self.customCategoryDates = [:]
        self.categoryAssignments = [:]
        self.categoryAssignmentDates = [:]
    }

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    /// Ehemals das monochrome SF-Symbol für die Laden-Kacheln — alle Views zeigen inzwischen
    /// direkt `emoji` (z. B. IKEAs 🛋️ statt nur "sofa"). Nicht mehr von UI-Code genutzt, hier
    /// nur noch für Referenz/Tests belassen.
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

    // MARK: Einkaufsweg (Issue #79)

    /// App-Group-Suite statt `.standard`, weil diese Datei auch im Widget und in der Share
    /// Extension läuft und dort dieselbe Sortierung gelten muss.
    /// Einmal angelegt statt bei jedem Zugriff — `pendingItems` liest daraus und wird pro
    /// Darstellung der Startseite oft aufgerufen.
    private static let routeDefaults = UserDefaults(suiteName: "group.com.johannesemmrich.SmartCart") ?? .standard

    /// Wird bei jeder Änderung an Sortiermodus oder gelernter Reihenfolge hochgezählt. Views, die
    /// `pendingItems` anzeigen, beobachten den Schlüssel per `@AppStorage`, damit sie sofort neu
    /// sortieren (UserDefaults-Werte lösen sonst kein Neuzeichnen aus).
    static let routeRevisionKey = "shoppingRouteRevision"

    private static func bumpRouteRevision() {
        let defaults = routeDefaults
        defaults.set(defaults.integer(forKey: routeRevisionKey) &+ 1, forKey: routeRevisionKey)
    }

    /// Sortierung der offenen Artikel, pro Laden. Ohne gespeicherten Wert gilt, was die früheren
    /// Einstellungen ergeben (`StoreSortMode.migratedDefault`). Die Haupt-App schreibt diesen
    /// Wert beim ersten Lesen fest: `groupByCategory` liegt in `UserDefaults.standard` und ist
    /// für Widget und Share Extension unsichtbar — ohne das Festschreiben sortierten sie denselben
    /// Laden anders als die App (und der Legacy-Drain träfe einen anderen Artikel).
    var sortMode: StoreSortMode {
        get {
            let defaults = Store.routeDefaults
            let key = "sortMode_\(id.uuidString)"
            if let raw = defaults.string(forKey: key), let mode = StoreSortMode(rawValue: raw) {
                return mode
            }
            let migrated = StoreSortMode.migratedDefault(
                groupByCategory: groupByCategory,
                autoSortByLearnedOrder: defaults.object(forKey: "autoSortByLearnedOrder") as? Bool ?? true
            )
            if Bundle.main.bundleURL.pathExtension != "appex" {
                defaults.set(migrated.rawValue, forKey: key)
            }
            return migrated
        }
        set {
            Store.routeDefaults.set(newValue.rawValue, forKey: "sortMode_\(id.uuidString)")
            Store.bumpRouteRevision()
        }
    }

    /// Gelernte Reihenfolge dieses Ladens — bewusst pro Gerät (nicht in SwiftData/CloudKit und
    /// nicht in geteilten Listen): zwei Personen laufen durch denselben Laden oft verschieden.
    var routeModel: ShoppingRouteModel {
        get { Store.decode(ShoppingRouteModel.self, key: "shoppingRoute_\(id.uuidString)") ?? ShoppingRouteModel() }
        set { Store.encode(newValue, key: "shoppingRoute_\(id.uuidString)") }
    }

    /// Der laufende Einkauf in diesem Laden (noch nicht gelernt).
    var currentTrip: ShoppingTrip {
        get { Store.decode(ShoppingTrip.self, key: "shoppingTrip_\(id.uuidString)") ?? ShoppingTrip() }
        set { Store.encode(newValue, key: "shoppingTrip_\(id.uuidString)") }
    }

    private static func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = routeDefaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func encode<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        routeDefaults.set(data, forKey: key)
    }

    /// Kategorie wie überall in der Liste: manuell gesetzt bleibt, sonst aus dem aktuellen Namen.
    static func displayCategory(of item: ShoppingItem) -> String {
        item.categoryManuallySet ? item.category : AssignmentService.category(for: item.name)
    }

    /// Einen Haken für den Einkaufsweg aufzeichnen. `batched`: aus der Dynamic-Island-/Widget-
    /// Warteschlange nachgetragen (Reihenfolge stimmt, Zeitpunkt nicht).
    func recordCheckOff(_ item: ShoppingItem, batched: Bool = false, at date: Date = Date()) {
        let before = routeModel
        let result = ShoppingRoute.recordCheckOff(
            key: ShoppingRoute.itemKey(item.name),
            category: Store.displayCategory(of: item),
            at: date,
            batched: batched,
            trip: currentTrip,
            model: before
        )
        currentTrip = result.trip
        if result.model != before {
            routeModel = result.model
            Store.bumpRouteRevision()
        }
    }

    /// Haken zurückgenommen — zählt für den laufenden Einkauf nicht mehr.
    func recordUncheck(_ item: ShoppingItem) {
        currentTrip = ShoppingRoute.recordUncheck(key: ShoppingRoute.itemKey(item.name), trip: currentTrip)
    }

    /// Einen seit `ShoppingRoute.tripGap` ruhenden Einkauf abschließen und lernen (beim Öffnen
    /// der Ladenansicht), damit die Liste schon vor dem ersten Haken des nächsten Einkaufs
    /// im gelernten Weg steht.
    func finalizeStaleTrip(now: Date = Date()) {
        let trip = currentTrip
        guard !trip.entries.isEmpty else { return }
        let result = ShoppingRoute.finalizeIfStale(trip: trip, model: routeModel, now: now)
        guard result.trip != trip else { return }
        currentTrip = result.trip
        routeModel = result.model
        Store.bumpRouteRevision()
    }

    /// Sortiermodus, gelerntes Modell und laufenden Einkauf dieses Ladens entfernen — für einen
    /// Laden, der gelöscht wird (die Schlüssel hängen an seiner `id` und blieben sonst liegen).
    func removeRouteData() {
        let defaults = Store.routeDefaults
        for key in ["sortMode_", "shoppingRoute_", "shoppingTrip_"] {
            defaults.removeObject(forKey: key + id.uuidString)
        }
        Store.bumpRouteRevision()
    }

    /// Kategorien in der gelernten Reihenfolge dieses Ladens (für die gruppierte Ansicht).
    func orderedCategories(_ categories: [String]) -> [String] {
        ShoppingRoute.orderedCategories(categories, model: routeModel, staticOrder: AssignmentService.categoryOrder)
    }

    private static func sortInput(_ item: ShoppingItem) -> ShoppingRoute.SortInput {
        ShoppingRoute.SortInput(
            key: ShoppingRoute.itemKey(item.name),
            category: displayCategory(of: item),
            isUrgent: item.isUrgent,
            addedDate: item.addedDate
        )
    }

    // MARK: Von Hand verschieben (Issue #86)

    /// Neue Artikel-Reihenfolge aus dem Modus „Reihenfolge anpassen“ (Einkaufsweg) übernehmen.
    /// `items` sind die nicht dringenden offenen Artikel in der neuen Reihenfolge.
    func applyManualOrder(_ items: [ShoppingItem], moved: ShoppingItem?) {
        routeModel = ShoppingRoute.applyManualOrder(
            items.map(Store.sortInput),
            movedKey: moved.map { ShoppingRoute.itemKey($0.name) },
            model: routeModel
        )
        Store.bumpRouteRevision()
    }

    /// Neue Abschnitts-Reihenfolge aus dem Modus „Reihenfolge anpassen“ (Kategorie) übernehmen.
    func applyManualCategoryOrder(_ categories: [String], moved: String?) {
        let pending = (items ?? []).filter { !$0.isCompleted && !$0.isUrgent }
        routeModel = ShoppingRoute.applyManualCategoryOrder(
            categories,
            movedCategory: moved,
            items: pending.map(Store.sortInput),
            model: routeModel
        )
        Store.bumpRouteRevision()
    }

    /// „Gelernte Reihenfolge zurücksetzen“: bis neu gelernt ist, gilt die Kategorie-Reihenfolge.
    func resetRoute() {
        routeModel = ShoppingRouteModel()
        currentTrip = ShoppingTrip()
        Store.bumpRouteRevision()
    }

    // MARK: Eigene Kategorien (Issue #85)

    /// Eigene Kategorien samt Löschvermerken, für Abgleich und Anzeige.
    var customCategoryEntries: [String: CustomCategoryEntry] {
        get {
            var entries: [String: CustomCategoryEntry] = [:]
            for (name, date) in customCategoryDates {
                entries[name] = CustomCategoryEntry(emoji: customCategoryEmojis[name], date: date)
            }
            // Ein Emoji ohne Datum (sollte nicht vorkommen) zählt als lebend und uralt.
            for (name, emoji) in customCategoryEmojis where entries[name] == nil {
                entries[name] = CustomCategoryEntry(emoji: emoji, date: .distantPast)
            }
            return entries
        }
        set {
            customCategoryEmojis = newValue.compactMapValues(\.emoji)
            customCategoryDates = newValue.mapValues(\.date)
        }
    }

    /// Lebende eigene Kategorien, alphabetisch.
    var customCategories: [String] { StoreCategories.activeNames(customCategoryEntries) }

    func isCustomCategory(_ category: String) -> Bool { customCategoryEmojis[category] != nil }

    /// Emoji für Abschnittsüberschriften: eigenes Emoji, sonst das der festen Kategorie.
    func categoryEmoji(_ category: String) -> String {
        customCategoryEmojis[category] ?? AssignmentService.categoryEmoji(category)
    }

    func resolveCategory(_ input: String) -> StoreCategories.Resolution {
        StoreCategories.resolve(
            input,
            builtIn: AssignmentService.categoryOrder,
            displayName: AssignmentService.displayCategory,
            custom: customCategories
        )
    }

    /// Kategorie aus dem Suchfeld anlegen. Liefert die zu verwendende Kategorie: eine feste oder
    /// vorhandene, wenn der Name schon existiert, sonst die neue; `nil` bei leerem Namen.
    @discardableResult
    func addCustomCategory(_ input: String, emoji: String? = nil) -> String? {
        switch resolveCategory(input) {
        case .invalid:
            return nil
        case .builtIn(let category), .existingCustom(let category):
            return category
        case .new(let name):
            var entries = customCategoryEntries
            entries[name] = CustomCategoryEntry(emoji: emoji ?? StoreCategories.suggestedEmoji(for: name), date: Date())
            customCategoryEntries = entries
            return name
        }
    }

    /// Eigene Kategorie umbenennen und/oder ihr Emoji ändern. Liefert den gültigen Namen danach.
    /// Kollidiert der neue Name mit einer festen oder anderen eigenen Kategorie, wandern die
    /// Artikel dorthin und die alte Kategorie wird gelöscht.
    @discardableResult
    func updateCustomCategory(_ old: String, name input: String, emoji: String) -> String {
        guard isCustomCategory(old) else { return old }
        let now = Date()
        var entries = customCategoryEntries
        let name = StoreCategories.normalizedName(input)
        if name.isEmpty || name == old {
            entries[old] = CustomCategoryEntry(emoji: emoji, date: now)
            customCategoryEntries = entries
            return old
        }
        let target: String
        switch StoreCategories.resolve(
            name,
            builtIn: AssignmentService.categoryOrder,
            displayName: AssignmentService.displayCategory,
            custom: customCategories.filter { $0 != old }
        ) {
        case .invalid:
            return old
        case .builtIn(let category), .existingCustom(let category):
            target = category
        case .new(let newName):
            target = newName
            entries[newName] = CustomCategoryEntry(emoji: emoji, date: now)
        }
        entries[old] = CustomCategoryEntry(emoji: nil, date: now)
        customCategoryEntries = entries
        for item in items ?? [] where item.category == old {
            item.category = target
            item.categoryManuallySet = target != AssignmentService.category(for: item.name)
            item.lastModified = now
        }
        let targetIsCustom = isCustomCategory(target)
        for (key, value) in categoryAssignments where value == old {
            setAssignment(targetIsCustom ? target : nil, forKey: key, at: now)
        }
        routeModel = ShoppingRoute.renameCategory(old, to: target, in: routeModel)
        Store.bumpRouteRevision()
        return target
    }

    /// Eigene Kategorie löschen: ihre Artikel bekommen wieder die automatische Kategorie.
    func deleteCustomCategory(_ name: String) {
        guard isCustomCategory(name) else { return }
        let now = Date()
        var entries = customCategoryEntries
        entries[name] = CustomCategoryEntry(emoji: nil, date: now)
        customCategoryEntries = entries
        for item in items ?? [] where item.category == name {
            item.category = AssignmentService.category(for: item.name)
            item.categoryManuallySet = false
            item.lastModified = now
        }
        for (key, value) in categoryAssignments where value == name {
            setAssignment(nil, forKey: key, at: now)
        }
        // Gelernte Positionen bleiben, aber nicht mehr unter dem gelöschten Namen — sonst erbte
        // eine später gleich benannte Kategorie dessen Platz.
        var model = routeModel
        model.itemCategories = model.itemCategories.filter { $0.value != name }
        routeModel = model
        Store.bumpRouteRevision()
    }

    /// Zuordnung merken (eigene Kategorie) bzw. vergessen (feste Kategorie gewählt).
    func rememberCategory(_ category: String, forItemNamed name: String) {
        let key = ShoppingRoute.itemKey(name)
        if isCustomCategory(category) {
            if categoryAssignments[key] != category { setAssignment(category, forKey: key, at: Date()) }
        } else if categoryAssignments[key] != nil {
            setAssignment(nil, forKey: key, at: Date())
        }
    }

    /// Zuordnung setzen oder vergessen (`nil`) und den Zeitpunkt fürs Abgleichen festhalten.
    private func setAssignment(_ category: String?, forKey key: String, at date: Date) {
        categoryAssignments[key] = category
        categoryAssignmentDates[key] = date
    }

    /// Gemerkte Zuordnungen samt Vergessen-Vermerken, für den Abgleich geteilter Läden (Issue #94).
    var categoryAssignmentEntries: [String: CategoryAssignmentEntry] {
        get {
            var entries: [String: CategoryAssignmentEntry] = [:]
            for (key, date) in categoryAssignmentDates {
                entries[key] = CategoryAssignmentEntry(category: categoryAssignments[key], date: date)
            }
            // Zuordnung ohne Datum (vor Issue #94 gemerkt) zählt als lebend und uralt.
            for (key, category) in categoryAssignments where entries[key] == nil {
                entries[key] = CategoryAssignmentEntry(category: category, date: .distantPast)
            }
            return entries
        }
        set {
            categoryAssignments = newValue.compactMapValues(\.category)
            categoryAssignmentDates = newValue.mapValues(\.date)
        }
    }

    /// Gemerkte eigene Kategorie für einen Artikelnamen in diesem Laden, falls sie noch existiert.
    func rememberedCategory(forItemNamed name: String) -> String? {
        guard let category = categoryAssignments[ShoppingRoute.itemKey(name)], isCustomCategory(category) else { return nil }
        return category
    }

    /// Ein Artikel wechselt in diesen Laden: eine eigene Kategorie des alten Ladens, die es hier
    /// nicht gibt, weicht der hier gemerkten eigenen Kategorie oder der automatischen.
    func adoptCategory(of item: ShoppingItem, from oldStore: Store?) {
        guard oldStore?.isCustomCategory(item.category) == true, !isCustomCategory(item.category) else { return }
        let automatic = AssignmentService.category(for: item.name)
        item.category = rememberedCategory(forItemNamed: item.name) ?? automatic
        item.categoryManuallySet = item.category != automatic
    }

    /// Offene Artikel in einer Kategorie (für die Kategorieliste).
    func pendingCount(inCategory category: String) -> Int {
        (items ?? []).filter { !$0.isCompleted && $0.category == category }.count
    }

    var pendingItems: [ShoppingItem] {
        let pending = (items ?? []).filter { !$0.isCompleted }
        let inputs = pending.map(Store.sortInput)
        return ShoppingRoute.sortedIndices(
            inputs,
            mode: sortMode,
            model: routeModel,
            staticCategoryOrder: AssignmentService.categoryOrder
        ).map { pending[$0] }
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
