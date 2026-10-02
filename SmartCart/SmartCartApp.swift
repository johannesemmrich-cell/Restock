import SwiftUI
import SwiftData
import UIKit
import AppIntents
import WidgetKit

@main
struct SmartCartApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    let container: ModelContainer
    @StateObject private var premium = PremiumService.shared

    @AppStorage("developerMode") private var developerMode = false
    /// Zwischenspeicher für einen `restock://join/<code>`-Link, der ankam während noch
    /// `OnboardingView` (statt `HomeView`) aktiv war — siehe `.onOpenURL` unten und
    /// `HomeView.task`, wo der Wert abgeholt und wieder gelöscht wird.
    @AppStorage("pendingJoinCode") private var pendingJoinCodeStorage: String?

    private static let appGroupID = "group.com.johannesemmrich.SmartCart"

    init() {
        // Runs regardless of which branch below sets `container`, and before any push
        // notification can arrive — a silent push can wake the app in the background without
        // ever presenting the WindowGroup, so this can't wait for a view's `.task` to run.
        defer {
            SyncCoordinator.shared.modelContext = container.mainContext
            #if DEBUG
            Self.seedSharedAssignmentForScreenshotsIfNeeded(context: container.mainContext)
            Self.clearReceiptReviewSeedForUITestsIfNeeded(context: container.mainContext)
            Self.clearReceiptResolutionStatsForUITestsIfNeeded()
            Self.clearMenuPlanForUITestsIfNeeded()
            Self.seedReceiptReviewForUITestsIfNeeded(context: container.mainContext)
            Self.seedReceiptReviewUnresolvedLineForUITestsIfNeeded(context: container.mainContext)
            Self.seedReceiptReviewWeightLineForUITestsIfNeeded(context: container.mainContext)
            Self.clearQuantitySuggestionSeedForUITestsIfNeeded(context: container.mainContext)
            Self.seedQuantitySuggestionForUITestsIfNeeded(context: container.mainContext)
            Self.clearShoppingRouteSeedForUITestsIfNeeded(context: container.mainContext)
            Self.seedShoppingRouteForUITestsIfNeeded(context: container.mainContext)
            Self.clearLegacyLearnedPriceSeedForUITestsIfNeeded(context: container.mainContext)
            Self.seedLegacyLearnedPriceForUITestsIfNeeded(context: container.mainContext)
            #endif
        }

        SmartCartShortcuts.updateAppShortcutParameters()
        CloudPreferencesSync.shared.start()

        // Einmalige Migration: alte Daten aus dem App-Container in den App-Group-Container kopieren.
        // Nötig weil App-Intents (Dynamic Island, Siri) in einem anderen Prozess laufen und
        // nur auf den App-Group-Container zugreifen können, nicht auf den App-eigenen Container.
        Self.migrateStoreToAppGroupIfNeeded()

        let schema = Schema(versionedSchema: SchemaV1.self)
        let groupConfig = ModelConfiguration(
            groupContainer: .identifier(Self.appGroupID),
            cloudKitDatabase: .none
        )

        // 1.+2. CloudKit mit App-Group, sonst lokaler App-Group-Store — über den gemeinsamen
        // Helper, den auch AddShoppingItemIntent und das Homescreen-Widget benutzen, damit
        // alle Prozesse GARANTIERT dieselbe Schema-Deklaration + Fallback-Reihenfolge öffnen
        // (ein Mismatch hier hat historisch echten Datenverlust verursacht, siehe
        // SharedModelContainer.swift).
        if let c = SharedModelContainer.make() {
            container = c
            return
        }

        // 3. Store-Dateien löschen + nochmal. Merkt sich, dass dieser Notfall-Pfad gegriffen hat
        // (.standard, übersteht das Löschen unten) — HomeView zeigt daraufhin einmalig einen
        // Hinweis, statt dass die App danach kommentarlos leer aussieht (siehe SharedModelContainer
        // für den analogen Logging-Mechanismus bei den zwei vorherigen, weniger drastischen Stufen).
        UserDefaults.standard.set(true, forKey: "smartcart.dataResetOccurred")
        Self.deleteStoreFiles()
        if let c = try? ModelContainer(for: schema, configurations: groupConfig) {
            container = c
            return
        }

        // 4. In-Memory — kann nie fehlschlagen
        container = try! ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, groupContainer: .none, cloudKitDatabase: .none)
        )
    }

    // Kopiert vorhandene Store-Dateien aus dem alten App-Container in den App-Group-Container.
    // Läuft nur einmal (wenn der Group-Container noch keine .store-Dateien hat).
    private static func migrateStoreToAppGroupIfNeeded() {
        let fm = FileManager.default
        guard
            let groupURL = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroupID),
            let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return }

        let groupAppSupport = groupURL.appendingPathComponent("Library/Application Support")

        // Bereits migriert wenn im Group-Container schon .store-Dateien existieren
        if let existing = try? fm.contentsOfDirectory(at: groupAppSupport, includingPropertiesForKeys: nil),
           existing.contains(where: { $0.pathExtension == "store" }) { return }

        guard let oldFiles = try? fm.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil) else { return }
        let storeFiles = oldFiles.filter {
            $0.pathExtension == "store" ||
            $0.lastPathComponent.hasSuffix(".store-wal") ||
            $0.lastPathComponent.hasSuffix(".store-shm")
        }
        guard !storeFiles.isEmpty else { return }

        try? fm.createDirectory(at: groupAppSupport, withIntermediateDirectories: true)
        for file in storeFiles {
            try? fm.copyItem(at: file, to: groupAppSupport.appendingPathComponent(file.lastPathComponent))
        }
    }

    /// 31.07.2026: der frühere HomeView-"Reparieren"-Button, der diese Funktion userausgelöst
    /// aufrief, wurde komplett entfernt — er hat auf einem transienten Cloud-Aussetzer (nicht dem
    /// eigentlichen, inzwischen behobenen Schema-Fehler) reagiert und dabei echte, noch nicht
    /// synchronisierte Nutzerdaten unwiederbringlich gelöscht. Wieder `private`: nur noch der
    /// automatische Notfall-Pfad unten (Stufe 3, beide ModelContainer-Versuche gescheitert) darf
    /// das auslösen, kein weiteres, auf einer Heuristik beruhendes UI-Trigger mehr.
    private static func deleteStoreFiles() {
        let fm = FileManager.default
        // App-Group-Container (primärer Store-Speicherort)
        if let groupURL = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let groupAppSupport = groupURL.appendingPathComponent("Library/Application Support")
            if let contents = try? fm.contentsOfDirectory(at: groupAppSupport, includingPropertiesForKeys: nil) {
                for url in contents where url.pathExtension == "store"
                    || url.lastPathComponent.hasSuffix(".store-shm")
                    || url.lastPathComponent.hasSuffix(".store-wal") {
                    try? fm.removeItem(at: url)
                }
            }
        }
        // Alter App-Container (Fallback-Cleanup)
        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            if let contents = try? fm.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil) {
                for url in contents where url.pathExtension == "store"
                    || url.lastPathComponent.hasSuffix(".store-shm")
                    || url.lastPathComponent.hasSuffix(".store-wal") {
                    try? fm.removeItem(at: url)
                }
            }
        }
    }

    #if DEBUG
    /// Screenshot-only seed for the "Wer bringt was mit?" marketing screenshot: a real shared
    /// store with real CloudKit members requires a second participant actually accepting a
    /// share, which a single-simulator screenshot run can't produce — `shareID`/`members` are
    /// plain UserDefaults-backed properties though (see Store.swift), so seeding them directly
    /// is safe and mirrors the existing `-premiumForScreenshots` pattern in PremiumService.swift.
    /// Only runs on `-seedSharedAssignmentForScreenshots`, DEBUG-only, never ships to users.
    private static func seedSharedAssignmentForScreenshotsIfNeeded(context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-seedSharedAssignmentForScreenshots") else { return }
        // The App-Group container persists across installs/test runs (see the class-level
        // comment on `appGroupID` above) — a stale "Lidl" store from an earlier ShotBot run
        // (e.g. testCartTeilen's seedStoreAndHabit) would otherwise sort ahead of this one and
        // `openStoreCard`'s `label CONTAINS "Lidl"` match would grab the wrong store. Wipe all
        // stores first so this screenshot mode always starts from a known, clean state.
        if let existing = try? context.fetch(FetchDescriptor<Store>()) {
            for s in existing { context.delete(s) }
        }
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#0050AA")
        store.shareID = "444-RU8"
        store.isSharedByMe = true
        store.members = ["Anna", "Tom"]
        context.insert(store)

        // English item names for the EN screenshot pass — AssignmentService.category(for:)
        // recognizes both German and English keywords (see its category dictionaries), so
        // category detection still works either way.
        let isEnglish = ProcessInfo.processInfo.arguments.contains("(en)")
        let seeds: [(name: String, quantity: String, unit: String, assignedTo: String, addedBy: String)] = isEnglish
            ? [
                ("Milk", "2", "l", "Anna", "Anna"),
                ("Bananas", "1", "kg", "Tom", "Tom"),
                ("Bread", "1", "", "", UserIdentity.displayName),
                ("Cheese", "1", "", "Anna", UserIdentity.displayName),
            ]
            : [
                ("Milch", "2", "l", "Anna", "Anna"),
                ("Bananen", "1", "kg", "Tom", "Tom"),
                ("Brot", "1", "", "", UserIdentity.displayName),
                ("Käse", "1", "", "Anna", UserIdentity.displayName),
            ]
        for seed in seeds {
            let item = ShoppingItem(name: seed.name, quantity: seed.quantity, unit: seed.unit, store: store)
            item.assignedTo = seed.assignedTo
            item.addedBy = seed.addedBy
            context.insert(item)
        }
        try? context.save()
    }

    /// Räumt die Daten des Bon-Prüf-Seeds wieder weg (Issue #28).
    ///
    /// Der App-Group-Container überlebt den einzelnen Test: Ohne dieses Aufräumen bleibt der
    /// geseedete Laden „Lidl" samt sechs Artikeln liegen, und die Bestandssuite startet im
    /// selben `xcodebuild test`-Lauf danach nicht mehr im leeren Zustand, den sie erwartet.
    /// Belegt in `docs/artifacts/feat-28-receipt-review-test-entry/`: auf leerem Gerät grün
    /// (`diag-a-baseline-erased.txt`), nach dem Seed rot im gemeinsamen Lauf
    /// (`validation-full-suite-run1-aborted.txt` — `testAddStoreAndQuickAddItemShowsPriceWithoutCrash`
    /// findet seinen Artikel nicht mehr und protokolliert davor „Lidl existiert bereits").
    /// `ReceiptReviewUITests.tearDown()` startet die App einmal mit diesem Argument.
    ///
    /// Die noch offene Nutzlast wird mit konsumiert, damit kein Prüf-Sheet in einen späteren
    /// Test hineinragt. Only runs on `-clearReceiptReviewSeedForUITests`, DEBUG-only.
    private static func clearReceiptReviewSeedForUITestsIfNeeded(context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-clearReceiptReviewSeedForUITests") else { return }
        if let items = try? context.fetch(FetchDescriptor<ShoppingItem>()) {
            for item in items { context.delete(item) }
        }
        if let stores = try? context.fetch(FetchDescriptor<Store>()) {
            for store in stores { context.delete(store) }
        }
        // `save()` legt für Zeilen ohne Artikel-Treffer eigenständige `PurchaseRecord`s an (Issue
        // #54) — ohne dieses Löschen tauchten sie in der Ausgabenansicht späterer Tests auf.
        if let records = try? context.fetch(FetchDescriptor<PurchaseRecord>()) {
            for record in records { context.delete(record) }
        }
        try? context.save()
        _ = ReceiptShareHandoff.takePending()
        // Issue #14: Speichern des Seeds zählt in `ReceiptResolutionStats` (App-Gruppe) — mit weg.
        ReceiptResolutionStats().reset()
    }

    /// Setzt den Zähler der Bon-Auflösung zurück (Issue #14) — er liegt in der App-Gruppe und
    /// überlebt sonst den Testlauf. `ReceiptResolutionStatsUITests` startet damit vor jedem Test
    /// und in `tearDown()`. Only runs on `-clearReceiptResolutionStatsForUITests`, DEBUG-only.
    private static func clearReceiptResolutionStatsForUITestsIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("-clearReceiptResolutionStatsForUITests") else { return }
        ReceiptResolutionStats().reset()
    }

    /// UI-Test-Seed für die Mengen-Vorbelegung (Issue #57, `AddItemQuantitySuggestionUITests`):
    /// Laden „Quittenhof" mit „Bio Käse" (angenommene Menge aus der Kaufhistorie, 400 g — AC-14/16)
    /// und „Parmesan" ohne belegte Menge, aber mit gelernter Gramm-Rate 0,0125 €/g (AC-15; der
    /// Konstruktor setzt `unit` dabei selbst auf "g"). Löscht vorher alle Läden und Artikel, damit
    /// jeder Test denselben Ausgangszustand hat.
    /// Only runs on `-seedQuantitySuggestionForUITests`, DEBUG-only, never ships to users.
    private static func seedQuantitySuggestionForUITestsIfNeeded(context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-seedQuantitySuggestionForUITests") else { return }
        deleteAllStoresAndItems(context: context)
        let store = Store(name: "Quittenhof", emoji: "🍐", colorHex: "#8A9A2B")
        store.learnedPrices["parmesan"] = 0.0125
        store.learnedPriceUnits["parmesan"] = "g"
        context.insert(store)
        context.insert(ShoppingItem(
            name: "Bio Käse", quantity: "400", quantityAmount: 400, unit: "g",
            store: store, quantitySource: "history"))
        context.insert(ShoppingItem(name: "Parmesan", store: store, quantitySource: "none"))
        // Früherer Kauf „Milch" (2 l) — Zwischentreffer beim Weitertippen zu „Milchreis" (F001).
        context.insert(PurchaseRecord(itemName: "Milch", storeName: "Quittenhof", quantityAmount: 2, unit: "l"))
        try? context.save()
    }

    /// Räumt den Seed oben wieder weg — `AddItemQuantitySuggestionUITests.tearDown()` startet die
    /// App einmal mit diesem Argument (App-Group-Container überlebt den Test, siehe Issue #28).
    /// Only runs on `-clearQuantitySuggestionSeedForUITests`, DEBUG-only.
    private static func clearQuantitySuggestionSeedForUITestsIfNeeded(context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-clearQuantitySuggestionSeedForUITests") else { return }
        deleteAllStoresAndItems(context: context)
        try? context.save()
    }

    /// UI-Test-Seed für die Sortierung nach Einkaufsweg (Issue #79, `ShoppingRouteUITests`):
    /// Laden „Wegeladen" mit „Brot", „Apfel", „Gouda" — in dieser Reihenfolge hinzugefügt — und
    /// einem gelernten Weg Gouda → Brot → Apfel. So unterscheiden sich alle drei Modi: Hinzugefügt
    /// (Brot, Apfel, Gouda), feste Supermarkt-Reihenfolge (Apfel, Brot, Gouda) und gelernter Weg
    /// bzw. gelernte Kategorie-Reihenfolge (Gouda, Brot, Apfel). Startet im Modus Einkaufsweg.
    /// Löscht vorher alle Läden und Artikel. Only runs on `-seedShoppingRouteForUITests`, DEBUG-only.
    private static func seedShoppingRouteForUITestsIfNeeded(context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-seedShoppingRouteForUITests") else { return }
        deleteAllStoresAndItems(context: context)
        let store = Store(name: "Wegeladen", emoji: "🧭", colorHex: "#2B6A9A")
        context.insert(store)
        let start = Date().addingTimeInterval(-3600)
        for (index, name) in ["Brot", "Apfel", "Gouda"].enumerated() {
            let item = ShoppingItem(name: name, store: store)
            item.addedDate = start.addingTimeInterval(Double(index) * 60)
            context.insert(item)
        }
        var model = ShoppingRouteModel()
        for (index, name) in ["Gouda", "Brot", "Apfel"].enumerated() {
            let key = ShoppingRoute.itemKey(name)
            model.itemPositions[key] = Double(index) / 2
            model.itemCategories[key] = AssignmentService.category(for: name)
        }
        store.routeModel = model
        store.currentTrip = ShoppingTrip()
        store.sortMode = .route
        try? context.save()
    }

    /// Räumt den Seed oben wieder weg — `ShoppingRouteUITests.tearDown()` startet die App einmal
    /// mit diesem Argument. Only runs on `-clearShoppingRouteSeedForUITests`, DEBUG-only.
    private static func clearShoppingRouteSeedForUITestsIfNeeded(context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-clearShoppingRouteSeedForUITests") else { return }
        deleteAllStoresAndItems(context: context)
        try? context.save()
    }

    /// UI-Test-Seed für den Altlast-Preis-Reset (Issue #11, `LegacyLearnedPriceResetUITests`):
    /// Laden „Altbon“ mit gelerntem Altwert 1,56 für „laugenbrötchen“ OHNE Einheit, dazu
    /// „Laugenbrötchen“ (abgehakt) und „Laugenbrötchen groß“ (offen) mit diesem Altwert sowie
    /// „Kontrollbrot“ mit manuellem Preis 2,50. Der Altzustand wird nach der Konstruktion von Hand
    /// gesetzt (der Konstruktor verwirft den Altwert seit #10 selbst). Entfernt das
    /// Migrations-Flag, damit die Migration im normalen App-Start (`.task`) läuft.
    /// Only runs on `-seedLegacyLearnedPriceForUITests`, DEBUG-only.
    private static func seedLegacyLearnedPriceForUITestsIfNeeded(context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-seedLegacyLearnedPriceForUITests") else { return }
        deleteAllStoresAndItems(context: context)
        UserDefaults.standard.removeObject(forKey: LegacyLearnedPriceReset.flagKey)
        let store = Store(name: "Altbon", emoji: "🥐", colorHex: "#AA5500")
        store.learnedPrices["laugenbrötchen"] = 1.56
        context.insert(store)
        let seeds: [(name: String, price: Double, completed: Bool)] = [
            ("Laugenbrötchen", 1.56, true),
            ("Laugenbrötchen groß", 1.56, false),
            ("Kontrollbrot", 2.50, false)
        ]
        for seed in seeds {
            let item = ShoppingItem(name: seed.name, quantityAmount: 1, store: store)
            item.estimatedPrice = seed.price
            item.estimatedPriceIsAutoDerived = false
            item.isCompleted = seed.completed
            context.insert(item)
        }
        try? context.save()
    }

    /// Räumt den Seed oben samt Migrations-Flag wieder weg — `LegacyLearnedPriceResetUITests.tearDown()`
    /// startet die App einmal mit diesem Argument. Only runs on `-clearLegacyLearnedPriceSeedForUITests`, DEBUG-only.
    private static func clearLegacyLearnedPriceSeedForUITestsIfNeeded(context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-clearLegacyLearnedPriceSeedForUITests") else { return }
        deleteAllStoresAndItems(context: context)
        UserDefaults.standard.removeObject(forKey: LegacyLearnedPriceReset.flagKey)
        try? context.save()
    }

    private static func deleteAllStoresAndItems(context: ModelContext) {
        if let items = try? context.fetch(FetchDescriptor<ShoppingItem>()) {
            for item in items { context.delete(item) }
        }
        if let stores = try? context.fetch(FetchDescriptor<Store>()) {
            for store in stores {
                store.removeRouteData()
                context.delete(store)
            }
        }
        let seededRecords = FetchDescriptor<PurchaseRecord>(predicate: #Predicate { $0.storeName == "Quittenhof" })
        if let records = try? context.fetch(seededRecords) {
            for record in records { context.delete(record) }
        }
    }

    /// Leert den Menüplan der laufenden Woche (Issue #60).
    ///
    /// Der Menüplan liegt nicht in SwiftData, sondern in `UserDefaults.standard` (`@AppStorage`
    /// in `MenuPlanView`) und überlebt damit den einzelnen Test genauso wie der
    /// App-Group-Container. `MenuPlanView` zeigt „Tag hinzufügen" absichtlich nur, solange
    /// weniger als sieben Tage verplant sind — nach genügend Läufen ist die Woche voll und
    /// `testAddingMenuPlanRecipeDoesNotCrash` findet den Knopf nicht mehr, ohne dass am Produkt
    /// etwas kaputt wäre. Dieses Argument stellt die Voraussetzung des Tests her, statt das
    /// Produktverhalten dafür zu ändern; derselbe Test räumt damit in `tearDown()` wieder auf.
    /// Only runs on `-clearMenuPlanForUITests`, DEBUG-only, never ships to users.
    private static func clearMenuPlanForUITestsIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("-clearMenuPlanForUITests") else { return }
        let defaults = UserDefaults.standard
        for key in ["menuPlanJSON", "menuIngredientsJSON", "menuPortionsJSON", "menuAddedDaysJSON"] {
            defaults.removeObject(forKey: key)
        }
    }

    /// UI-test-only seed for the receipt review screen (Issue #28): that screen is otherwise only
    /// reachable via camera OCR or a real Photos→Share jump, neither of which is deterministic in
    /// the simulator. Seeds a store with items and hands a fixed four-line receipt over through
    /// the REAL handoff path (`ReceiptShareHandoff` → `HomeView.checkPendingReceiptScan()`), so
    /// the test exercises store matching and the confidence check just like a real share does —
    /// no shortcut sheet presentation that would bypass exactly the logic #23 needs to test.
    ///
    /// Every fixture line satisfies `resolvedByAI == true` OR `name != originalName`, so
    /// `EditableReceiptLine.linesNeedingAIReresolution` is empty and `reResolveAIIfNeeded()`
    /// never runs — neither the abbreviation dictionary, a fuzzy match nor an alias learned in an
    /// earlier run can change the fixture between runs.
    /// Only runs on `-seedReceiptReviewForUITests`, DEBUG-only, never ships to users.
    private static func seedReceiptReviewForUITestsIfNeeded(context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-seedReceiptReviewForUITests") else { return }
        // Same reason as the screenshot seed above: the App-Group container survives test runs,
        // so stores would otherwise pile up across runs.
        if let existing = try? context.fetch(FetchDescriptor<Store>()) {
            for s in existing { context.delete(s) }
        }
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#0050AA")
        context.insert(store)

        let milch = ShoppingItem(name: "Milch", quantity: "1", store: store)
        let hafermilch = ShoppingItem(name: "Hafermilch", quantity: "1", store: store)
        let buttermilch = ShoppingItem(name: "Buttermilch", quantity: "1", store: store)
        let vollmilch = ShoppingItem(name: "Vollmilch", quantity: "1", store: store)
        let hackfleisch = ShoppingItem(name: "Hackfleisch", quantity: "1", store: store)
        let broetchen = ShoppingItem(name: "Brötchen", quantity: "1", store: store)
        for item in [milch, hafermilch, buttermilch, vollmilch, hackfleisch, broetchen] {
            context.insert(item)
        }
        // Erst speichern, dann die Nutzlast bauen: `matchedItemID`/`suggestions` referenzieren die
        // soeben vergebenen `id`s der Artikel.
        try? context.save()

        // `stage` je Zeile (Issue #14, `ReceiptResolutionStatsUITests`): 0 KI, 1 und 2 Abgehakt,
        // 3 Historie — die Zählung nach dem Speichern wird gegen genau diese Verteilung geprüft.
        let lines: [ResolvedReceiptLine] = [
            ResolvedReceiptLine(
                name: "Frische Vollmilch 3,5 %", originalName: "MILCH 3,5% FRISCH",
                price: 1.19, quantity: 1, unit: "", weightBasis: nil,
                suggestions: [], matchedItemID: vollmilch.id, resolvedByAI: true, stage: .ai),
            ResolvedReceiptLine(
                name: "Bio-Hackfleisch gemischt Rind & Schwein 400 g",
                originalName: "BIO-HACKFLEISCH GEMISCHT RIND SCHWEIN 400G",
                price: 4.99, quantity: 1, unit: "400g", weightBasis: nil,
                suggestions: [], matchedItemID: hackfleisch.id, resolvedByAI: false, stage: .completed),
            ResolvedReceiptLine(
                name: "Milch", originalName: "MILCH",
                price: 0.99, quantity: 1, unit: "", weightBasis: nil,
                suggestions: [
                    ReceiptSuggestion(name: "Hafermilch", itemID: hafermilch.id),
                    ReceiptSuggestion(name: "Buttermilch", itemID: buttermilch.id),
                    ReceiptSuggestion(name: "Vollmilch", itemID: vollmilch.id),
                ], matchedItemID: milch.id, resolvedByAI: false, stage: .completed),
            ResolvedReceiptLine(
                name: "Brötchen", originalName: "BROETCHEN",
                price: 1.56, quantity: 4, unit: "", weightBasis: nil,
                suggestions: [], matchedItemID: broetchen.id, resolvedByAI: false, stage: .history),
        ]

        // `storeConfidentlyDetected: true` ist Pflicht — sonst greift in
        // `checkPendingReceiptScan()` der Besuchsfrequenz-Notnagel, das Banner "Laden nicht sicher
        // erkannt" erscheint und "Speichern" bleibt via `storeNeedsConfirmation` gesperrt.
        ReceiptShareHandoff.store(SharedReceiptPayload(
            storeID: store.id,
            storeConfidentlyDetected: true,
            lines: lines,
            rawLines: lines.map(\.originalName),
            detectedTotal: lines.reduce(0) { $0 + $1.price }))
    }

    /// Zweiter, ausdrücklich GEGENLÄUFIGER UI-Test-Seed (Issue #50, Paket 1 —
    /// `docs/specs/testing/receipt-review-test-entry.md`, „Nachtrag Issue #50, Paket 1").
    ///
    /// Derselbe Laden „Lidl" mit denselben sechs Artikeln und denselben vier Basiszeilen wie der
    /// Seed oben, PLUS eine fünfte Zeile mit `name == originalName == "BTR"` und
    /// `resolvedByAI == false`. Diese eine Zeile verletzt „Invariante 1 — Fixture-Determinismus"
    /// ABSICHTLICH: nur so ist `EditableReceiptLine.linesNeedingAIReresolution` nicht leer, nur so
    /// läuft `reResolveAIIfNeeded()` beim Handoff überhaupt — und genau dieses nachträgliche
    /// Schreiben von `line.name` ist die Ursache von Issue #50 (Punkt 2 und 4).
    ///
    /// „BTR" ist bewusst gewählt: `ReceiptParserService.expandAbbreviations` (Stufe 2) enthält den
    /// statischen Eintrag `"btr": "Butter"`, die Zeile löst sich also deterministisch auf — ohne
    /// Apple Intelligence (im Simulator nicht verfügbar) und ohne die Fuzzy-Suche gegen abgehakte
    /// Artikel (keiner der sechs Seed-Artikel ist abgehakt).
    ///
    /// Bewusst KEINE gemeinsame Hilfsfunktion mit dem Seed oben: der ist produktiv und von 17
    /// Tests abhängig, eine Extraktion wäre ein Drive-by-Refactoring außerhalb dieses Tickets.
    /// Aufgeräumt wird über das bestehende `-clearReceiptReviewSeedForUITests`, das ohnehin ALLE
    /// Läden und Artikel löscht und jede offene Nutzlast konsumiert.
    /// Only runs on `-seedReceiptReviewUnresolvedLineForUITests`, DEBUG-only, never ships to users.
    private static func seedReceiptReviewUnresolvedLineForUITestsIfNeeded(context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-seedReceiptReviewUnresolvedLineForUITests") else { return }
        if let existing = try? context.fetch(FetchDescriptor<Store>()) {
            for s in existing { context.delete(s) }
        }
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#0050AA")
        context.insert(store)

        let milch = ShoppingItem(name: "Milch", quantity: "1", store: store)
        let hafermilch = ShoppingItem(name: "Hafermilch", quantity: "1", store: store)
        let buttermilch = ShoppingItem(name: "Buttermilch", quantity: "1", store: store)
        let vollmilch = ShoppingItem(name: "Vollmilch", quantity: "1", store: store)
        let hackfleisch = ShoppingItem(name: "Hackfleisch", quantity: "1", store: store)
        let broetchen = ShoppingItem(name: "Brötchen", quantity: "1", store: store)
        for item in [milch, hafermilch, buttermilch, vollmilch, hackfleisch, broetchen] {
            context.insert(item)
        }
        try? context.save()

        let lines: [ResolvedReceiptLine] = [
            ResolvedReceiptLine(
                name: "Frische Vollmilch 3,5 %", originalName: "MILCH 3,5% FRISCH",
                price: 1.19, quantity: 1, unit: "", weightBasis: nil,
                suggestions: [], matchedItemID: vollmilch.id, resolvedByAI: true),
            ResolvedReceiptLine(
                name: "Bio-Hackfleisch gemischt Rind & Schwein 400 g",
                originalName: "BIO-HACKFLEISCH GEMISCHT RIND SCHWEIN 400G",
                price: 4.99, quantity: 1, unit: "400g", weightBasis: nil,
                suggestions: [], matchedItemID: hackfleisch.id, resolvedByAI: false),
            ResolvedReceiptLine(
                name: "Milch", originalName: "MILCH",
                price: 0.99, quantity: 1, unit: "", weightBasis: nil,
                suggestions: [
                    ReceiptSuggestion(name: "Hafermilch", itemID: hafermilch.id),
                    ReceiptSuggestion(name: "Buttermilch", itemID: buttermilch.id),
                    ReceiptSuggestion(name: "Vollmilch", itemID: vollmilch.id),
                ], matchedItemID: milch.id, resolvedByAI: false),
            ResolvedReceiptLine(
                name: "Brötchen", originalName: "BROETCHEN",
                price: 1.56, quantity: 4, unit: "", weightBasis: nil,
                suggestions: [], matchedItemID: broetchen.id, resolvedByAI: false),
            // Die gezielte Ausnahme von Invariante 1 — siehe Kopfkommentar.
            ResolvedReceiptLine(
                name: "BTR", originalName: "BTR",
                price: 1.09, quantity: 1, unit: "", weightBasis: nil,
                suggestions: [], matchedItemID: nil, resolvedByAI: false),
        ]

        ReceiptShareHandoff.store(SharedReceiptPayload(
            storeID: store.id,
            storeConfidentlyDetected: true,
            lines: lines,
            rawLines: lines.map(\.originalName),
            detectedTotal: lines.reduce(0) { $0 + $1.price }))
    }

    /// Dritter UI-Test-Seed (Issue #54, `docs/specs/views/receipt-save-purchase-quantity.md`):
    /// Laden „Lidl" ohne Artikel und NUR die Gewichtszeile „BANANE CHIQUITA" (0,706 kg x 2,49,
    /// Gesamtpreis 1,76, `weightBasis` 706, `matchedItemID` nil). So nimmt `save()` den
    /// `else`-Zweig und legt einen neuen `PurchaseRecord` an. Eigener Seed statt einer fünften
    /// Zeile im Seed oben, weil sie dort Positionszähler und Summe bestehender Tests verschöbe.
    /// `resolvedByAI: true` hält die Zeile aus `reResolveAIIfNeeded()` heraus (Invariante 1), damit
    /// der Name unverändert „BANANE CHIQUITA" bleibt. Aufgeräumt über
    /// `-clearReceiptReviewSeedForUITests` (Läden, Artikel und alle `PurchaseRecord`s).
    /// Only runs on `-seedReceiptReviewWeightLineForUITests`, DEBUG-only, never ships to users.
    private static func seedReceiptReviewWeightLineForUITestsIfNeeded(context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-seedReceiptReviewWeightLineForUITests") else { return }
        if let existing = try? context.fetch(FetchDescriptor<Store>()) {
            for s in existing { context.delete(s) }
        }
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#0050AA")
        context.insert(store)
        try? context.save()

        let lines: [ResolvedReceiptLine] = [
            ResolvedReceiptLine(
                name: "BANANE CHIQUITA", originalName: "BANANE CHIQUITA",
                price: 1.76, quantity: 1, unit: "", weightBasis: 706,
                suggestions: [], matchedItemID: nil, resolvedByAI: true),
        ]
        ReceiptShareHandoff.store(SharedReceiptPayload(
            storeID: store.id,
            storeConfidentlyDetected: true,
            lines: lines,
            rawLines: lines.map(\.originalName),
            detectedTotal: lines.reduce(0) { $0 + $1.price }))
    }
    #endif

    var body: some Scene {
        WindowGroup {
            OnboardingGate()
                .modelContainer(container)
                .environmentObject(premium)
                .safeAreaInset(edge: .top) {
                    if developerMode {
                        DevModeIndicator()
                    }
                }
                // Fängt restock://join/<code> auch ab, wenn noch OnboardingView statt HomeView
                // aktiv ist (HomeView.onOpenURL existiert dann noch gar nicht in der Hierarchie —
                // SwiftUI liefert das Event sonst spurlos ins Leere). Schreibt nur in den
                // App-Storage-Zwischenspeicher; HomeView.task holt ihn ab, sobald sie erscheint
                // (siehe dortiger Kommentar). Die store/receiptscan-Fälle bleiben exklusiv
                // HomeViews eigenem onOpenURL überlassen — die brauchen ohnehin erst nach dem
                // Onboarding vorhandene Stores/Kontext.
                .onOpenURL { url in
                    if url.scheme == "restock", url.host == "join" {
                        pendingJoinCodeStorage = url.lastPathComponent
                    }
                }
                .task {
                    PriceProvenanceMigration.runIfNeeded(context: container.mainContext)
                    LegacyLearnedPriceReset.runIfNeeded(context: container.mainContext)
                    await SyncCoordinator.shared.resubscribeAll()
                }
                // App-wide pull for ALL shared stores: immediately on every (re)activation and
                // then every 15s while active. Without this, remote changes only arrived via
                // StoreDetailView's own polling or the (unreliable) CloudKit silent push — on
                // HomeView/AllItemsView nothing pulled at all. `initial: true` covers cold
                // launch, where the phase may already be `.active` before any change fires.
                .onChange(of: scenePhase, initial: true) { _, phase in
                    if phase == .active {
                        SyncCoordinator.shared.startPeriodicPulls()
                        // Falls das Homescreen-Widget Artikel abgehakt hat, während die App
                        // nicht lief: Änderungen liegen nur lokal (die Widget-Extension kann
                        // nicht zu CloudKit pushen) — jetzt einmalig alle geteilten Läden pushen.
                        SyncCoordinator.shared.pushWidgetCheckoffsIfNeeded()
                    } else {
                        SyncCoordinator.shared.stopPeriodicPulls()
                        // Zentraler Reload-Hook: was auch immer in dieser Session hinzugefügt/
                        // gelöscht/umbenannt wurde — beim Verlassen der App zeigt das Widget
                        // den frischen Stand.
                        WidgetCenter.shared.reloadAllTimelines()
                        // Issue #30, C3: Nachkauf-Nachrichten auch ohne App-Start neu planen.
                        ReplenishmentBackgroundRefresh.schedule()
                    }
                }
        }
        .backgroundTask(.appRefresh(ReplenishmentBackgroundRefresh.taskIdentifier)) { [container] in
            await ReplenishmentBackgroundRefresh.run(container: container)
        }
    }
}

// MARK: - Onboarding Gate

struct OnboardingGate: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            HomeView()
        } else {
            OnboardingView()
        }
    }
}

// MARK: - Dev Mode Indicator

private struct DevModeIndicator: View {
    @AppStorage("developerMode") private var developerMode = false
    @Query(filter: #Predicate<FeedbackItem> { !$0.isResolved })
    private var openFeedback: [FeedbackItem]
    @State private var showFeedback = false

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            Button { showFeedback = true } label: {
                HStack(spacing: 5) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("DEV")
                        .font(.system(size: 10, weight: .bold))
                    if !openFeedback.isEmpty {
                        Text("\(openFeedback.count)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.red, in: Capsule())
                    }
                }
                .foregroundStyle(.black.opacity(0.75))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.orange, in: Capsule())
            }
            .buttonStyle(.pressable)

            Button {
                developerMode = false
                // Siehe SettingsView.swift ("Developer Mode deaktivieren") für dieselbe
                // Begründung — dieser Pill-Button ist der zweite Ausstiegspunkt aus dem Dev-Mode.
                NotificationService.shared.cancelAll()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.black.opacity(0.6))
                    .padding(6)
                    .background(Color.orange.opacity(0.7), in: Circle())
            }
            .buttonStyle(.pressable)
            .padding(.leading, 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .sheet(isPresented: $showFeedback) {
            NavigationStack { FeedbackListView() }
        }
    }
}
