import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

/// `.sheet(item:)`-Ziel für einen per Share Extension hereingereichten Bon (siehe
/// `ReceiptShareHandoff`) — bündelt den aufgelösten Laden mit der Nutzlast, damit beides in
/// einem Schritt an `ReceiptScannerView.init(store:prefilled:)` weitergereicht werden kann.
private struct PendingReceiptScan: Identifiable {
    let id = UUID()
    let store: Store
    let payload: SharedReceiptPayload
}

struct HomeView: View {
    @Query(filter: #Predicate<Store> { $0.isActive }, sort: \Store.sortIndex) private var activeStores: [Store]
    @Query private var allRecords: [PurchaseRecord]
    // Items with no assigned store would otherwise be invisible everywhere on the home screen
    // (the grid, banner, counts and category list all iterate `activeStores`).
    @Query(filter: #Predicate<ShoppingItem> { !$0.isCompleted && $0.store == nil })
    private var storelessPending: [ShoppingItem]
    @Environment(\.modelContext) private var context

    @State private var showAddItem = false
    @State private var showRecipeImport = false
    @State private var showSettings = false
    @State private var showMenuPlan = false
    @State private var showPriceOverview = false
    @State private var showAddStore = false
    @State private var showAllItems = false
    @State private var bannerExpanded = false
    @Namespace private var bannerNamespace
    @State private var addItemText = ""
    @State private var quickAddSucceeded = false
    @FocusState private var isQuickAddFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    @State private var dueSoonItems: [ConsumptionPattern] = []
    @State private var headerScale: CGFloat = 1.0

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("seasonalSuggestionsEnabled") private var seasonalSuggestionsEnabled = true
    @AppStorage("homeListMode") private var listMode = false
    // V5: Karten (Standard, horizontales Grid) oder Liste (Stores untereinander) — unabhängig
    // vom obigen `listMode`, der auf eine ganz andere Ansicht (Kategorie-Liste) umschaltet.
    @AppStorage("storeViewMode") private var storeViewModeRaw = StoreViewMode.cards.rawValue
    private var storeViewMode: StoreViewMode { StoreViewMode(rawValue: storeViewModeRaw) ?? .cards }
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    // Not read directly — its only job is to make SwiftUI re-invoke `body` (and thus the store
    // cards' pending-item preview text, which depends on `Store.pendingItems`' order) when the
    // user flips the setting in SettingsView. Store-scoped, matching the key the Toggle writes to.
    @AppStorage("autoSortByLearnedOrder", store: UserDefaults(suiteName: "group.com.johannesemmrich.SmartCart"))
    private var autoSortByLearnedOrder = true
    // Persisted map itemName(lowercased) → dismissed estimatedNextPurchaseDate. A dismissal
    // hides the suggestion for its current purchase cycle only: the next real purchase shifts
    // the estimated date, which makes the item eligible for the banner again.
    @AppStorage("dismissedReplenishments") private var dismissedReplenishmentsData = Data()
    @EnvironmentObject private var premium: PremiumService
    @State private var showPaywall = false
    @State private var paywallContext: PaywallContext = .premium(feature: "dieses Feature")
    @State private var showStoreSetup = false
    @State private var storeToDelete: Store?
    @State private var showJoinStore = false
    // Lokale Kopie für ForEach — verhindert dass @Query-Re-Sort die Drag-Animation im Grid abbricht
    // (gleiches Muster wie StoreSetupView.orderedActiveStores)
    @State private var orderedStores: [Store] = []
    @State private var draggingStoreID: UUID?
    // Deep-Link-Ziel vom Homescreen-Widget (restock://store/<uuid> via widgetURL) —
    // navigationDestination(item:) pusht die passende StoreDetailView.
    @State private var deepLinkStore: Store?
    // Deep-Link-Ziel von der Share Extension (restock://receiptscan, per registriertem
    // URL-Schema — anders als beim Widget-Link oben BRAUCHT das ein echtes Schema, da die
    // Extension die App aktiv über extensionContext?.open(...) öffnet statt über den
    // widgetURL-Sondermechanismus).
    @State private var pendingReceiptScan: PendingReceiptScan?
    // Gesetzt von SmartCartApp.init(), falls der Notfall-Pfad (lokale Store-Dateien löschen +
    // neu anlegen) gegriffen hat — zeigt einmalig einen erklärenden Hinweis, statt dass die App
    // nach diesem Vorfall kommentarlos leer aussieht.
    @State private var showDataResetAlert = false

    private var seasonalSuggestions: [SeasonalService.Suggestion] {
        seasonalSuggestionsEnabled ? SeasonalService.currentSuggestions() : []
    }

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var totalPending: Int {
        activeStores.filter { !$0.isPaused }.reduce(0) { $0 + $1.pendingItems.count } + storelessPending.count
    }

    private func syncStoreOrder() {
        orderedStores = activeStores
    }

    /// Reorders `orderedStores` by moving `draggedID` next to `targetID` and persists the
    /// new order into `Store.sortIndex`, mirroring `StoreSetupView.onMove`.
    private func moveStore(draggedID: UUID, before targetID: UUID) {
        guard draggedID != targetID,
              let fromIndex = orderedStores.firstIndex(where: { $0.id == draggedID }),
              let toIndex = orderedStores.firstIndex(where: { $0.id == targetID }) else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            let store = orderedStores.remove(at: fromIndex)
            // Removing the dragged store shifts everything after `fromIndex` left by one, so if
            // the target was further down the list its own index moves down by one too.
            let insertIndex = fromIndex < toIndex ? toIndex - 1 : toIndex
            orderedStores.insert(store, at: min(max(insertIndex, 0), orderedStores.count))
            for (i, s) in orderedStores.enumerated() {
                s.sortIndex = i
            }
        }
        Haptics.impact(.light)
    }

    var body: some View {
        // Re-runs body whenever a sync merge lands in SwiftData, so the category list mode
        // (`groupedByCategory`) regroups immediately — its section derivation lives up here in
        // the parent body, not in the item rows. Same pattern as StoreDetailView/AllItemsView.
        let _ = SyncCoordinator.shared.applyGeneration
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    quickAddBar
                    if !dueSoonItems.isEmpty {
                        if premium.hasPremiumAccess {
                            replenishmentBanner
                        } else {
                            premiumTeaser(
                                icon: "arrow.clockwise.circle.fill",
                                color: Color.amber,
                                title: "\(dueSoonItems.count) Artikel bald fällig",
                                subtitle: "Nachkauf-Erinnerungen mit Restock Pro",
                                feature: "Nachkauf-Erinnerungen"
                            )
                        }
                    }
                    if !seasonalSuggestions.isEmpty {
                        if premium.hasPremiumAccess {
                            seasonalBanner
                        } else {
                            premiumTeaser(
                                icon: SeasonalService.seasonIcon,
                                color: Color.accent,
                                title: String(format: String(localized: "seasonal.count.suggestions"), seasonalSuggestions.count),
                                subtitle: String(localized: "seasonal.premium.subtitle"),
                                feature: String(localized: "seasonal.feature.label")
                            )
                        }
                    }
                    storeSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
            .background(Color.canvas)
            .navigationTitle("Restock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) { customTopBar }
            .sheet(isPresented: $showAddItem)        { AddItemView() }
            .sheet(isPresented: $showRecipeImport)  { RecipeImportView() }
            .sheet(isPresented: $showSettings)      { SettingsView() }
            .sheet(isPresented: $showMenuPlan)      { MenuPlanView() }
            .sheet(isPresented: $showPriceOverview) { PriceOverviewView() }
            .sheet(isPresented: $showAddStore) { NavigationStack { BrowseStoresView() } }
            .sheet(isPresented: $showAllItems) { AllItemsView() }
            .sheet(isPresented: $showStoreSetup) { NavigationStack { StoreSetupView() } }
            .sheet(isPresented: $showJoinStore) { JoinStoreSheet() }
            .sheet(isPresented: $showPaywall) { PaywallView(context: paywallContext) }
            .navigationDestination(item: $deepLinkStore) { store in
                StoreDetailView(store: store)
            }
            .sheet(item: $pendingReceiptScan) { pending in
                ReceiptScannerView(store: pending.store, prefilled: pending.payload)
            }
            // Tap auf das Homescreen-Widget (außerhalb der Abhak-Buttons): öffnet die App
            // direkt beim angezeigten Laden. widgetURL-Links werden vom System immer an die
            // eigene App zugestellt — ein registriertes URL-Scheme ist dafür nicht nötig.
            .onOpenURL { url in
                if url.scheme == "restock", url.host == "store",
                   let id = UUID(uuidString: url.lastPathComponent),
                   let store = activeStores.first(where: { $0.id == id }) {
                    deepLinkStore = store
                    return
                }
                // Von der Share Extension: Bon-Bild wurde in einer anderen App geteilt, dort
                // bereits erkannt+ausgewertet (siehe ReceiptShareHandoff). Dieser Zweig ist nur
                // ein Bonus, falls extensionContext?.open(...) doch mal greift — siehe
                // checkPendingReceiptScan() für den eigentlich verlässlichen Weg.
                if url.scheme == "restock", url.host == "receiptscan" {
                    checkPendingReceiptScan()
                }
            }
            .onAppear {
                if UserDefaults.standard.bool(forKey: "smartcart.dataResetOccurred") {
                    UserDefaults.standard.removeObject(forKey: "smartcart.dataResetOccurred")
                    showDataResetAlert = true
                }
                refreshDueSoon()
                registerShortcutItems()
                if QuickActionState.shared.triggerQuickAdd {
                    QuickActionState.shared.triggerQuickAdd = false
                    activateQuickAdd()
                }
                checkPendingQuickAdd()
                checkPendingReceiptScan()
                syncStoreOrder()
            }
            .alert(String(localized: "data.reset.title"), isPresented: $showDataResetAlert) {
                Button("OK") {}
            } message: {
                Text(String(localized: "data.reset.message"))
            }
            .onReceive(NotificationCenter.default.publisher(for: .quickAddRequested)) { _ in
                activateQuickAdd()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    checkPendingQuickAdd()
                    checkPendingReceiptScan()
                } else {
                    // Safety net: a drag interrupted by the app backgrounding (incoming call,
                    // Control Center, etc.) may leave `draggingStoreID` set if the drag preview's
                    // .onDisappear doesn't fire in time — don't let that permanently freeze the
                    // orderedStores/activeStores sync in `.onChange(of: activeStores)` below.
                    draggingStoreID = nil
                }
            }
            .onChange(of: allRecords.count) { refreshDueSoon() }
            .onChange(of: activeStores) {
                // Nur synchronisieren, wenn gerade nicht gedraggt wird — sonst würde das
                // @Query-Re-Sort die laufende Drag-Animation im Grid unterbrechen/flackern lassen.
                if draggingStoreID == nil { syncStoreOrder() }
            }
            .devFeedback(context: "Startseite")
            .confirmationDialog(
                "Laden löschen?",
                isPresented: Binding(get: { storeToDelete != nil }, set: { if !$0 { storeToDelete = nil } }),
                titleVisibility: .visible
            ) {
                if let store = storeToDelete {
                    Button("Löschen", role: .destructive) {
                        // Remove from the local drag-reorder mirror immediately — don't rely on
                        // the async `.onChange(of: activeStores)` resync (which is skipped mid-drag
                        // and could otherwise leave a deleted Store referenced in `orderedStores`).
                        orderedStores.removeAll { $0.id == store.id }
                        Haptics.impact(.medium)
                        storeToDelete = nil
                        // shareID VOR dem Löschen sichern, dann sofort synchron löschen (wie
                        // bisher, wie beim nicht-geteilten Fall) — die Push-Abmeldung (siehe
                        // "Teilen beenden" in StoreShareSheet) läuft unabhängig hinterher statt
                        // das Löschen zu verzögern. Ein verzögertes Löschen hätte ein Zeitfenster
                        // geöffnet, in dem der Store noch in `activeStores` sichtbar ist und durch
                        // ein zwischenzeitliches Sync-Update in `orderedStores` wiederauferstehen
                        // könnte (syncStoreOrder() überschreibt orderedStores komplett aus
                        // activeStores). No-op-Abmeldung für nicht geteilte Stores.
                        let shareID = store.shareID
                        context.delete(store)
                        if shareID != nil {
                            Task { await SharedStoreService.shared.leaveBeforeDeleting(shareID: shareID) }
                        }
                    }
                }
                Button("Abbrechen", role: .cancel) { storeToDelete = nil }
            } message: {
                if let store = storeToDelete {
                    Text("\"\(store.name)\" und alle zugehörigen Artikel werden dauerhaft gelöscht.")
                }
            }
        }
        .overlay {
            if bannerExpanded {
                ZStack {
                    (colorScheme == .dark ? Color.black.opacity(0.55) : Color.ink.opacity(0.42))
                        .ignoresSafeArea()
                        .onTapGesture { closeBanner() }
                    VStack {
                        Spacer(minLength: 55)
                        expandedBannerCard
                            .matchedGeometryEffect(id: "heroBanner", in: bannerNamespace, isSource: bannerExpanded)
                            .padding(.horizontal, 16)
                        Spacer(minLength: 55)
                    }
                }
                .transition(.opacity)
            }
        }
        .onChange(of: totalPending) { _, newValue in
            if newValue == 0 && bannerExpanded { closeBanner() }
            refreshDueSoon()
        }
    }

    // MARK: - Header

    private var storesWithPendingItems: [Store] {
        activeStores.filter { !$0.pendingItems.isEmpty }
    }

    @ViewBuilder
    private func bannerItemButton(_ item: ShoppingItem, storeEmoji: String?) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) { item.markCompleted() }
            Haptics.success()
            SyncCoordinator.shared.pushInBackground(item.store)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "square")
                    .font(.system(size: 19))
                    .foregroundStyle(Color.hairlineStrong)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        if item.isUrgent {
                            Image(systemName: "exclamationmark")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(.orange, in: RoundedRectangle(cornerRadius: RCRadius.tag))
                        }
                        Text(item.name)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.ink)
                        if let emoji = storeEmoji {
                            Text(emoji)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                    if !item.unit.isEmpty || item.quantityAmount != 1 {
                        Text(item.quantity + (!item.unit.isEmpty ? " \(item.unit)" : ""))
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
    }

    private func openBanner() {
        guard totalPending > 0 else { return }
        Haptics.impact(.light)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { bannerExpanded = true }
    }

    private func closeBanner() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { bannerExpanded = false }
    }

    private var headerCard: some View {
        VStack(spacing: 12) {
            VStack(spacing: 11) {
                Text("Restock")
                    .font(.wordmark(31))
                    .tracking(-0.3)
                Rectangle()
                    .fill(Color.accent.opacity(0.9))
                    .frame(width: 36, height: 3)
            }
            if totalPending > 0 {
                Text(String(format: String(localized: "home.header.items"), totalPending, activeStores.count))
                    .font(.system(size: 16))
                    .foregroundStyle(Color.heroText.opacity(0.75))
            } else {
                Text(String(localized: "home.header.empty"))
                    .font(.system(size: 16))
                    .foregroundStyle(Color.heroText.opacity(0.75))
            }
        }
        .foregroundStyle(Color.heroText)
        .multilineTextAlignment(.center)
        .padding(.vertical, 31)
        .frame(maxWidth: .infinity)
        .background(Color.heroSurface)
        .clipShape(RoundedRectangle(cornerRadius: RCRadius.hero))
        .heroShadow(colorScheme)
        .matchedGeometryEffect(id: "heroBanner", in: bannerNamespace, isSource: !bannerExpanded)
        .opacity(bannerExpanded ? 0 : 1)
        .contentShape(RoundedRectangle(cornerRadius: RCRadius.hero))
        .onTapGesture { openBanner() }
    }

    private var expandedBannerCard: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.hairlineStrong)
                .frame(width: 32, height: 4)
                .padding(.top, 10)

            // Header section
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .center, spacing: 8) {
                    VStack(spacing: 9) {
                        Text("Restock")
                            .font(.wordmark(25))
                            .tracking(-0.25)
                            .foregroundStyle(Color.ink)
                        Rectangle()
                            .fill(Color.accent)
                            .frame(width: 32, height: 2.5)
                    }
                    Text(String(format: String(localized: "home.header.items"), totalPending, activeStores.count))
                        .font(.system(size: 15))
                        .foregroundStyle(Color.textSecondary)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 18)
                Button { closeBanner() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.textSecondary.opacity(0.8))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.pressable)
                .padding(.horizontal, 14)
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)

            Rectangle().fill(Color.hairline).frame(height: 1)

            // Items list
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    let urgentFromStores: [(item: ShoppingItem, emoji: String?)] = storesWithPendingItems.flatMap { store in
                        store.pendingItems.filter { $0.isUrgent }.map { (item: $0, emoji: store.emoji) }
                    }
                    let urgentStoreless: [(item: ShoppingItem, emoji: String?)] = storelessPending
                        .filter { $0.isUrgent }
                        .map { (item: $0, emoji: nil) }
                    let allUrgent = urgentFromStores + urgentStoreless
                    if !allUrgent.isEmpty {
                        HStack(spacing: 5) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.orange)
                            Text("Dringend")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.orange)
                            Spacer()
                            Text("\(allUrgent.count)")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textSecondary)
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                        .padding(.bottom, 2)
                        ForEach(allUrgent, id: \.item.id) { entry in
                            bannerItemButton(entry.item, storeEmoji: entry.emoji)
                        }
                        Rectangle().fill(Color.hairline).frame(height: 1)
                            .padding(.horizontal, 18)
                            .padding(.top, 4)
                    }

                    ForEach(storesWithPendingItems) { store in
                        let nonUrgent = store.pendingItems.filter { !$0.isUrgent }
                        if !nonUrgent.isEmpty {
                            Button {
                                closeBanner()
                                deepLinkStore = store
                            } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: RCRadius.control)
                                            .fill(Color.accentContainer)
                                            .frame(width: 38, height: 38)
                                        Image(systemName: store.iconSystemName)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(Color.accent)
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(store.name)
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundStyle(Color.ink)
                                        Text(nonUrgent.prefix(3).map { $0.name }.joined(separator: ", "))
                                            .font(.system(size: 14))
                                            .foregroundStyle(Color.textSecondary)
                                            .lineLimit(2)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 0) {
                                        Text("\(nonUrgent.count)")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundStyle(Color.accent)
                                        Text("Artikel")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(Color.accent)
                                    }
                                }
                                .padding(.horizontal, 18)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.pressable)
                            Rectangle().fill(Color.hairline).frame(height: 1).padding(.horizontal, 18)
                        }
                    }

                    let storelessRegular = storelessPending.filter { !$0.isUrgent }
                    if !storelessRegular.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "tray")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.ink)
                            Text("Ohne Laden")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.ink)
                            Spacer()
                            Text("\(storelessRegular.count)")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textSecondary)
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                        .padding(.bottom, 2)
                        ForEach(storelessRegular) { item in
                            bannerItemButton(item, storeEmoji: nil)
                        }
                    }
                }
            }
            .frame(maxHeight: 300)

            Rectangle().fill(Color.hairline).frame(height: 1)

            // Footer
            Button {
                closeBanner()
                showAllItems = true
            } label: {
                Text("Einkauf starten")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.restockPrimary)
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 18)
        }
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: RCRadius.sheet))
        .overlayShadow(colorScheme)
    }

    // MARK: - Quick add

    private var parsedHint: QuickAddResult? {
        guard !addItemText.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let r = QuickAddParser.parse(addItemText)
        // Only show chip when something meaningful was parsed (name differs or unit present)
        guard r.name != addItemText.trimmingCharacters(in: .whitespaces) || !r.unit.isEmpty else { return nil }
        return r
    }

    private var quickAddSuggestions: [String] {
        guard !addItemText.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return QuickAddParser.knownProductSuggestions(for: QuickAddParser.parse(addItemText).name, in: allRecords)
    }

    /// `QuickAddParser` erkennt Menge/Einheit entweder VOR dem Namen ("200g Hafer" → Name ist
    /// Suffix von `trimmed`) oder NACH dem Namen ("Hackfleisch 3kg" → Name ist Präfix) — beide
    /// Fälle müssen beim Ersetzen per Tipp auf einen Vorschlag die bereits getippte Menge
    /// erhalten, statt sie stillschweigend zu verwerfen. Der Vergleich läuft gegen dieselbe
    /// auf Einzel-Leerzeichen normalisierte Tokenisierung, die `QuickAddParser.parse` intern
    /// für den zurückgegebenen Namen verwendet (`tokens.joined(separator: " ")`) — sonst würde
    /// z.B. ein eingefügter Name mit doppeltem Leerzeichen ("Bio  Vollmilch") weder als Suffix
    /// noch als Präfix des unveränderten `trimmed` erkannt und die Menge ginge verloren.
    private func applyQuickAddSuggestion(_ suggestion: String) {
        let normalized = addItemText
            .trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let parsedName = QuickAddParser.parse(addItemText).name
        if normalized.hasSuffix(parsedName) {
            addItemText = String(normalized.dropLast(parsedName.count)) + suggestion
        } else if normalized.hasPrefix(parsedName) {
            addItemText = suggestion + String(normalized.dropFirst(parsedName.count))
        } else {
            addItemText = suggestion
        }
    }

    private var suggestedStore: Store? {
        guard !addItemText.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let parsed = QuickAddParser.parse(addItemText)
        return AssignmentService.assign(itemName: parsed.name, to: activeStores, purchaseRecords: allRecords)
    }

    private var quickAddBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: quickAddSucceeded ? "checkmark" : "plus")
                        .foregroundStyle(Color.accent)
                        .font(.system(size: 17, weight: .semibold))
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: quickAddSucceeded)

                    TextField(String(localized: "home.quickadd.placeholder"), text: $addItemText)
                        .focused($isQuickAddFocused)
                        .submitLabel(.done)
                        .onSubmit { quickAdd() }

                    if !addItemText.isEmpty {
                        Button { addItemText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color(.systemGray3))
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .background(Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: RCRadius.card))
                .overlay(RoundedRectangle(cornerRadius: RCRadius.card).strokeBorder(Color.hairline))

                Button {
                    Haptics.impact(.light)
                    showRecipeImport = true
                } label: {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.accent)
                        .frame(width: 54, height: 54)
                        .background(Color.accentContainer)
                        .clipShape(RoundedRectangle(cornerRadius: RCRadius.control))
                }
                .buttonStyle(.pressable)
            }

            // Unit chips (shown while keyboard is open)
            if isQuickAddFocused {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["100g", "200g", "500g", "1kg", "1l", "500ml", "1 Stk.", "2 Stk.", "1 Pkg."], id: \.self) { chip in
                            Button {
                                let current = addItemText.trimmingCharacters(in: .whitespaces)
                                addItemText = current.isEmpty ? chip + " " : chip + " " + current
                                Haptics.impact(.light)
                            } label: {
                                Text(chip)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.surface, in: RoundedRectangle(cornerRadius: RCRadius.tag))
                                    .overlay(RoundedRectangle(cornerRadius: RCRadius.tag).strokeBorder(Color.hairline))
                            }
                            .buttonStyle(.pressable)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if isQuickAddFocused {
                ProductSuggestionChips(suggestions: quickAddSuggestions, tint: Color.accent, onSelect: applyQuickAddSuggestion)
            }

            // Smart parsing preview chip
            if let parsed = parsedHint {
                HStack(spacing: 8) {
                    // Quantity + unit pill (only when qty ≠ 1 or unit is present)
                    if parsed.quantityAmount != 1 || !parsed.unit.isEmpty {
                        Text(
                            parsed.unit.isEmpty
                                ? "\(parsed.quantity)×"
                                : (parsed.quantityAmount != 1 ? "\(parsed.quantity) \(parsed.unit)" : parsed.unit)
                        )
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .overlay(RoundedRectangle(cornerRadius: RCRadius.tag).strokeBorder(Color.accent.opacity(0.4)))
                    }

                    // Item name
                    Text(parsed.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    // Store suggestion
                    if let store = suggestedStore {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .semibold))
                            Text(store.name)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(store.color)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.accentContainer)
                .clipShape(RoundedRectangle(cornerRadius: RCRadius.control))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: parsedHint?.name)
    }

    // MARK: - Seasonal banner

    private var seasonalBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.accent)
                        .frame(width: 28, height: 28)
                    Image(systemName: SeasonalService.seasonIcon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.canvas)
                }
                Text(SeasonalService.seasonalTitle)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.ink)
                Spacer()
                Button(String(localized: "home.replenish.addall")) {
                    var touchedStores: [Store?] = []
                    for s in seasonalSuggestions {
                        let category = AssignmentService.category(for: s.name)
                        let store = AssignmentService.assign(itemName: s.name, to: activeStores, purchaseRecords: allRecords)
                        context.insert(ShoppingItem(name: s.name, category: category, store: store))
                        touchedStores.append(store)
                    }
                    Haptics.success()
                    SyncCoordinator.shared.pushInBackground(touchedStores)
                }
                .buttonStyle(.pressable)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.accent)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(seasonalSuggestions) { s in
                        Button {
                            let category = AssignmentService.category(for: s.name)
                            let store = AssignmentService.assign(itemName: s.name, to: activeStores, purchaseRecords: allRecords)
                            context.insert(ShoppingItem(name: s.name, category: category, store: store))
                            Haptics.impact(.light)
                            SyncCoordinator.shared.pushInBackground(store)
                        } label: {
                            VStack(spacing: 2) {
                                Text(s.name)
                                    .font(.system(size: 13, weight: .medium))
                                Text(s.reason)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.surface, in: RoundedRectangle(cornerRadius: RCRadius.control))
                            .overlay(RoundedRectangle(cornerRadius: RCRadius.control).strokeBorder(Color.hairline))
                        }
                        .buttonStyle(.pressable)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.accentContainer)
        .clipShape(RoundedRectangle(cornerRadius: RCRadius.card))
    }

    // MARK: - Premium teaser

    private func premiumTeaser(icon: String, color: Color, title: String, subtitle: String, feature: String) -> some View {
        Button {
            paywallContext = .premium(feature: feature)
            showPaywall = true
            Haptics.impact(.light)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: RCRadius.control)
                        .fill(color)
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.canvas)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.ink)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
                Text("PRO")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(RoundedRectangle(cornerRadius: RCRadius.tag).strokeBorder(color))
            }
            .padding(16)
            .background(color.opacity(0.13))
            .clipShape(RoundedRectangle(cornerRadius: RCRadius.card))
        }
        .buttonStyle(.pressable)
    }

    // MARK: - Replenishment banner

    private var replenishmentBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                HStack(alignment: .top, spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.amber)
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)
                    Text(String(localized: "home.replenish.title"))
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Color.amber)
                }
                Spacer()
                Button(String(localized: "home.replenish.addall")) {
                    addDueSoonToList()
                    Haptics.success()
                }
                .buttonStyle(.pressable)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.amber)
                .multilineTextAlignment(.trailing)
            }

            ForEach(dueSoonItems, id: \.itemName) { pattern in
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: RCRadius.tag)
                            .fill(pattern.isOverdue ? Color.danger : Color.amber)
                            .frame(width: 26, height: 26)
                        Button {
                            addSingleDueItem(pattern)
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.canvas)
                        }
                        .buttonStyle(.pressable)
                    }
                    Text(pattern.itemName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.ink)
                    Spacer()
                    Text(pattern.isOverdue
                         ? String(localized: "replenish.overdue")
                         : String(format: String(localized: "replenish.in.days"), pattern.daysUntilNeeded))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                    Button {
                        dismissDueItem(pattern)
                    } label: {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.textSecondary.opacity(0.7))
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
        .padding(16)
        .background(Color.amber.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: RCRadius.card))
    }

    // MARK: - Store grid / Category list

    private var storeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(listMode ? String(localized: "home.allitems") : String(localized: "home.stores.title"))
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                if !listMode {
                    Button { showStoreSetup = true } label: {
                        Text(String(localized: "home.stores.manage"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.accent)
                    }
                    .buttonStyle(.pressable)
                }
            }

            if listMode {
                categoryListView
            } else if activeStores.isEmpty {
                emptyStoresView
            } else if storeViewMode == .list {
                storeListView
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(orderedStores) { store in
                        NavigationLink {
                            StoreDetailView(store: store)
                        } label: {
                            StoreCard(store: store)
                                .opacity(draggingStoreID == store.id ? 0.4 : 1.0)
                                .scaleEffect(draggingStoreID == store.id ? 0.96 : 1.0)
                        }
                        .buttonStyle(.pressable)
                        .contextMenu {
                            Button {
                                withAnimation { store.isPaused.toggle() }
                                Haptics.impact(.light)
                            } label: {
                                Label(store.isPaused ? "Fortsetzen" : "Pausieren",
                                      systemImage: store.isPaused ? "play.circle" : "moon.circle")
                            }
                            Button(role: .destructive) {
                                storeToDelete = store
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                            Button {
                                store.isActive = false
                                Haptics.impact(.light)
                            } label: {
                                Label("Archivieren", systemImage: "archivebox")
                            }
                        }
                        .draggable(StoreDragPayload(storeID: store.id)) {
                            StoreCard(store: store)
                                .frame(width: 160)
                                .onAppear { draggingStoreID = store.id }
                                // The drag preview is torn down whether the drag ends in a
                                // successful drop or is cancelled/interrupted (dropped outside any
                                // registered target, app backgrounded mid-drag, system interruption,
                                // etc.) — this is the only reset path that fires unconditionally, so
                                // it's the safety net against `draggingStoreID` getting stuck forever.
                                .onDisappear { draggingStoreID = nil }
                        }
                        .dropDestination(for: StoreDragPayload.self) { items, _ in
                            defer { draggingStoreID = nil }
                            guard let payload = items.first else { return false }
                            moveStore(draggedID: payload.storeID, before: store.id)
                            return true
                        } isTargeted: { _ in }
                    }
                    addStoreCard
                    joinListCard
                }
                // Fallback so `draggingStoreID` is reset even if the drag ends over the trailing
                // static cards or empty grid space, which aren't valid per-card drop targets.
                .dropDestination(for: StoreDragPayload.self) { _, _ in
                    draggingStoreID = nil
                    return false
                } isTargeted: { _ in }
            }
        }
    }

    // MARK: - Store list (V5 — Läden-Ansicht "Liste")

    private var storeListView: some View {
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                ForEach(Array(orderedStores.enumerated()), id: \.element.id) { index, store in
                    NavigationLink {
                        StoreDetailView(store: store)
                    } label: {
                        storeListRow(store)
                            .opacity(draggingStoreID == store.id ? 0.4 : 1.0)
                    }
                    .buttonStyle(.pressable)
                    .contextMenu {
                        Button {
                            withAnimation { store.isPaused.toggle() }
                            Haptics.impact(.light)
                        } label: {
                            Label(store.isPaused ? "Fortsetzen" : "Pausieren",
                                  systemImage: store.isPaused ? "play.circle" : "moon.circle")
                        }
                        Button(role: .destructive) {
                            storeToDelete = store
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                        Button {
                            store.isActive = false
                            Haptics.impact(.light)
                        } label: {
                            Label("Archivieren", systemImage: "archivebox")
                        }
                    }
                    .draggable(StoreDragPayload(storeID: store.id)) {
                        storeListRow(store)
                            .frame(width: 300)
                            .background(Color.surface)
                            .onAppear { draggingStoreID = store.id }
                            .onDisappear { draggingStoreID = nil }
                    }
                    .dropDestination(for: StoreDragPayload.self) { items, _ in
                        defer { draggingStoreID = nil }
                        guard let payload = items.first else { return false }
                        moveStore(draggedID: payload.storeID, before: store.id)
                        return true
                    } isTargeted: { _ in }

                    if index < orderedStores.count - 1 {
                        Rectangle().fill(Color.hairline).frame(height: 1)
                            .padding(.leading, 52)
                    }
                }
            }
            .background(Color.surface, in: RoundedRectangle(cornerRadius: RCRadius.card))
            .overlay(RoundedRectangle(cornerRadius: RCRadius.card).strokeBorder(Color.hairline))

            addStoreCard
            joinListCard
        }
        .dropDestination(for: StoreDragPayload.self) { _, _ in
            draggingStoreID = nil
            return false
        } isTargeted: { _ in }
    }

    private func storeListRow(_ store: Store) -> some View {
        // Einmal holen statt der ungecachten `store.pendingItems` (Filter + Sort +
        // UserDefaults-Zugriff) unten 5× einzeln neu aufzurufen.
        let pending = store.pendingItems
        return HStack(spacing: 14) {
            Image(systemName: store.iconSystemName)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.ink)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(store.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.ink)
                    if pending.count > 0 {
                        Text("· \(pending.count)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.accent)
                    }
                    if store.shareID != nil {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.accent)
                    }
                    if store.isPaused {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                if pending.isEmpty {
                    Text("\(VisitFrequency.closest(to: store.visitsPerWeek).label) · \(String(localized: "store.empty"))")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                } else {
                    let freqLabel = VisitFrequency.closest(to: store.visitsPerWeek).label
                    let preview = pending.prefix(2).map { $0.name }.joined(separator: ", ")
                    Text("\(freqLabel) · \(preview)\(pending.count > 2 ? "…" : "")")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textSecondary.opacity(0.6))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .opacity(store.isPaused ? 0.55 : 1.0)
        .contentShape(Rectangle())
    }

    // MARK: - Category list

    private var allPendingItems: [ShoppingItem] {
        activeStores.filter { !$0.isPaused }.flatMap { $0.pendingItems } + storelessPending
    }

    private var groupedByCategory: [(category: String, emoji: String, items: [ShoppingItem])] {
        // Manually-set categories stick as the user chose them; everything else keeps re-deriving
        // from the current name so stale stored values and rule updates apply immediately.
        let grouped = Dictionary(grouping: allPendingItems) {
            $0.categoryManuallySet ? $0.category : AssignmentService.category(for: $0.name)
        }
        var result: [(category: String, emoji: String, items: [ShoppingItem])] = []
        for cat in AssignmentService.categoryOrder {
            if let items = grouped[cat], !items.isEmpty {
                result.append((category: cat, emoji: AssignmentService.categoryEmoji(cat), items: items))
            }
        }
        for key in grouped.keys.sorted() where !AssignmentService.categoryOrder.contains(key) {
            if let items = grouped[key], !items.isEmpty {
                result.append((category: key, emoji: AssignmentService.categoryEmoji(key), items: items))
            }
        }
        return result
    }

    @ViewBuilder
    private var categoryListView: some View {
        if allPendingItems.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.accent.opacity(0.5))
                Text("Keine offenen Artikel")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
            .cardStyle()
        } else {
            VStack(spacing: 10) {
                ForEach(groupedByCategory, id: \.category) { group in
                    VStack(spacing: 0) {
                        HStack(spacing: 8) {
                            Text(group.emoji)
                                .font(.system(size: 15))
                            Text(AssignmentService.displayCategory(group.category))
                                .font(.system(size: 15, weight: .semibold))
                            Spacer()
                            Text("\(group.items.count)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        ForEach(group.items) { item in
                            Divider().padding(.leading, 14)
                            categoryItemRow(item)
                        }
                    }
                    .background(Color.surface, in: RoundedRectangle(cornerRadius: RCRadius.card))
                    .overlay(RoundedRectangle(cornerRadius: RCRadius.card).strokeBorder(Color.hairline))
                }
            }
        }
    }

    @ViewBuilder
    private func categoryItemRow(_ item: ShoppingItem) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) { item.markCompleted() }
            Haptics.success()
            SyncCoordinator.shared.pushInBackground(item.store)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "square")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.hairlineStrong)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(.system(size: 15))
                        .foregroundStyle(.primary)
                    if !item.unit.isEmpty || item.quantityAmount != 1 {
                        Text(item.quantity + (item.unit.isEmpty ? "" : " \(item.unit)"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let emoji = item.store?.emoji {
                    Text(emoji)
                        .font(.system(size: 17))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
    }

    private var addStoreCard: some View {
        Button {
            showAddStore = true
            Haptics.impact(.light)
        } label: {
            VStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.accent)
                    .frame(width: 34, height: 34)
                    .overlay(
                        RoundedRectangle(cornerRadius: RCRadius.control)
                            .strokeBorder(Color.hairlineStrong, lineWidth: 1)
                    )
                Text(String(localized: "home.stores.addcustom"))
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .overlay(
                RoundedRectangle(cornerRadius: RCRadius.card)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .foregroundStyle(Color.hairlineStrong)
            )
            .contentShape(RoundedRectangle(cornerRadius: RCRadius.card))
        }
        .buttonStyle(.pressable)
    }

    private var joinListCard: some View {
        Button {
            showJoinStore = true
            Haptics.impact(.light)
        } label: {
            VStack(spacing: 10) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.accent)
                    .frame(width: 34, height: 34)
                    .overlay(
                        RoundedRectangle(cornerRadius: RCRadius.control)
                            .strokeBorder(Color.hairlineStrong, lineWidth: 1)
                    )
                Text(String(localized: "home.join.shared"))
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .overlay(
                RoundedRectangle(cornerRadius: RCRadius.card)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .foregroundStyle(Color.hairlineStrong)
            )
            .contentShape(RoundedRectangle(cornerRadius: RCRadius.card))
        }
        .buttonStyle(.pressable)
    }

    private var emptyStoresView: some View {
        VStack(spacing: 16) {
            Image(systemName: "storefront")
                .font(.system(size: 44))
                .foregroundStyle(Color.accent.opacity(0.5))
            Text(String(localized: "home.stores.empty.title"))
                .font(.headline)
                .foregroundStyle(.secondary)
            Button(String(localized: "home.stores.setup")) {
                showStoreSetup = true
            }
            .buttonStyle(.borderedProminent)
            Button {
                showJoinStore = true
            } label: {
                Label(String(localized: "home.join.shared"), systemImage: "person.badge.plus")
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .cardStyle()
    }

    // MARK: - Top bar
    //
    // Eigene Leiste statt System-Toolbar: iOS 26 zerlegt gruppierte Toolbar-Buttons in einzelne
    // Liquid-Glass-Elemente — hier behalten wir die Mockup-Chips (3er-Gruppe links, ☰ und ＋
    // als getrennte Chips rechts) exakt unter Kontrolle. Positionen/Funktionen unverändert.

    private var customTopBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 24) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Color.ink)
                }
                Button {
                    if premium.hasPremiumAccess {
                        showMenuPlan = true
                    } else {
                        paywallContext = .premium(feature: "den Menüplan")
                        showPaywall = true
                    }
                } label: {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Color.ink)
                }
                Button {
                    if premium.hasPremiumAccess {
                        showPriceOverview = true
                    } else {
                        paywallContext = .premium(feature: "die Ausgaben-Analyse")
                        showPaywall = true
                    }
                } label: {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Color.ink)
                }
            }
            .buttonStyle(.pressable)
            .toolbarChip()

            Spacer()

            Button {
                Haptics.impact(.light)
                showAllItems = true
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.ink)
                    .toolbarChip()
            }
            .buttonStyle(.pressable)

            Button {
                Haptics.impact(.light)
                showAddItem = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Color.ink)
                    .toolbarChip()
            }
            .buttonStyle(.pressable)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .background(Color.canvas)
    }

    // MARK: - Logic

    private func quickAdd() {
        let trimmed = addItemText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let parsed = QuickAddParser.parse(trimmed)
        let category = AssignmentService.category(for: parsed.name)
        let store = AssignmentService.assign(itemName: parsed.name, to: activeStores, purchaseRecords: allRecords)
        context.insert(ShoppingItem(
            name: parsed.name,
            category: category,
            quantity: parsed.quantity,
            quantityAmount: parsed.quantityAmount,
            unit: parsed.unit,
            store: store
        ))
        SyncCoordinator.shared.pushInBackground(store)
        addItemText = ""
        Haptics.success()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { quickAddSucceeded = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.spring(response: 0.4)) { quickAddSucceeded = false }
        }
        // Tastatur offen lassen — Nutzer kann direkt weitertippen
        DispatchQueue.main.async { isQuickAddFocused = true }
    }

    private func activateQuickAdd() {
        showSettings = false
        showAddItem = false
        showMenuPlan = false
        showAllItems = false
        showRecipeImport = false
        showPriceOverview = false
        showAddStore = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            isQuickAddFocused = true
        }
    }

    private func checkPendingQuickAdd() {
        let defaults = UserDefaults(suiteName: "group.com.johannesemmrich.SmartCart")
        guard defaults?.bool(forKey: "pendingQuickAdd") == true else { return }
        defaults?.removeObject(forKey: "pendingQuickAdd")
        activateQuickAdd()
    }

    // Share Extensions dürfen laut Apple offiziell nur als Today-Widget die eigene App per
    // extensionContext?.open(...) öffnen — bei RestockShareExtension (Share-Extension-Typ)
    // schlägt das in der Praxis unzuverlässig fehl. Deshalb NICHT darauf verlassen, dass
    // .onOpenURL mit restock://receiptscan jemals feuert, sondern bei jedem App-Start/
    // Vordergrund-Wechsel selbst nachschauen, ob eine Bon-Übergabe wartet — exakt das gleiche
    // Muster wie checkPendingQuickAdd() oben.
    private func checkPendingReceiptScan() {
        guard pendingReceiptScan == nil, let payload = ReceiptShareHandoff.takePending() else { return }
        let resolvedStore = payload.storeID.flatMap { id in activeStores.first { $0.id == id } }
            ?? activeStores.first
        guard let resolvedStore else { return }
        pendingReceiptScan = PendingReceiptScan(store: resolvedStore, payload: payload)
    }

    private func refreshDueSoon() {
        let allPatterns = HabitService.dueSoonItems(allRecords: allRecords)
        let pendingNames = Set(
            activeStores.flatMap { $0.pendingItems.map { $0.name.lowercased() } }
                + storelessPending.map { $0.name.lowercased() }
        )
        let dismissed = dismissedReplenishments()
        dueSoonItems = allPatterns.filter { pattern in
            guard !pendingNames.contains(pattern.itemName.lowercased()) else { return false }
            return dismissed[pattern.itemName.lowercased()] != pattern.estimatedNextPurchaseDate.timeIntervalSince1970
        }
        pruneDismissedReplenishments(keeping: allPatterns)
        if notificationsEnabled {
            HabitService.scheduleReplenishmentNotifications(patterns: dueSoonItems)
        }
    }

    private func dismissDueItem(_ pattern: ConsumptionPattern) {
        var dismissed = dismissedReplenishments()
        dismissed[pattern.itemName.lowercased()] = pattern.estimatedNextPurchaseDate.timeIntervalSince1970
        persistDismissedReplenishments(dismissed)
        NotificationService.shared.cancelReplenishment(itemName: pattern.itemName)
        dueSoonItems.removeAll { $0.itemName == pattern.itemName }
        Haptics.impact(.light)
    }

    private func dismissedReplenishments() -> [String: TimeInterval] {
        (try? JSONDecoder().decode([String: TimeInterval].self, from: dismissedReplenishmentsData)) ?? [:]
    }

    private func persistDismissedReplenishments(_ map: [String: TimeInterval]) {
        dismissedReplenishmentsData = (try? JSONEncoder().encode(map)) ?? Data()
    }

    /// Drops dismissal entries for items that no longer produce a pattern at all, so the map
    /// can't grow unboundedly over years of use.
    private func pruneDismissedReplenishments(keeping patterns: [ConsumptionPattern]) {
        let valid = Set(patterns.map { $0.itemName.lowercased() })
        let map = dismissedReplenishments().filter { valid.contains($0.key) }
        persistDismissedReplenishments(map)
    }

    private func registerShortcutItems() {
        UIApplication.shared.shortcutItems = [
            UIApplicationShortcutItem(
                type: "com.smartcart.quickadd",
                localizedTitle: String(localized: "shortcut.additem.title"),
                localizedSubtitle: String(localized: "shortcut.additem.subtitle"),
                icon: UIApplicationShortcutIcon(systemImageName: "cart.badge.plus"),
                userInfo: nil
            )
        ]
    }

    private func addDueSoonToList() {
        var touchedStores: [Store?] = []
        for pattern in dueSoonItems {
            let store = AssignmentService.assign(itemName: pattern.itemName, to: activeStores, purchaseRecords: allRecords)
            let category = AssignmentService.category(for: pattern.itemName)
            context.insert(ShoppingItem(name: pattern.itemName, category: category, store: store))
            touchedStores.append(store)
        }
        dueSoonItems = []
        SyncCoordinator.shared.pushInBackground(touchedStores)
    }

    private func addSingleDueItem(_ pattern: ConsumptionPattern) {
        let store = AssignmentService.assign(itemName: pattern.itemName, to: activeStores, purchaseRecords: allRecords)
        let category = AssignmentService.category(for: pattern.itemName)
        context.insert(ShoppingItem(name: pattern.itemName, category: category, store: store))
        dueSoonItems.removeAll { $0.itemName == pattern.itemName }
        Haptics.impact(.light)
        SyncCoordinator.shared.pushInBackground(store)
    }
}

/// Drag payload identifying which `Store` is being reordered on the home screen grid.
/// Wraps the store's stable `UUID` rather than the SwiftData model itself, since `Transferable`
/// requires a `Codable`/plain-data representation for drag-and-drop.
struct StoreDragPayload: Codable, Transferable {
    let storeID: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .storeReorder)
    }
}

extension UTType {
    // Only used for in-process drag-and-drop reordering. MUST be `exportedAs:` (non-failable,
    // declares the type at runtime) — the lookup initializer `UTType("…")` returns nil for a type
    // that isn't declared in the Info.plist, and force-unwrapping it crashed the app on launch for
    // every user with at least one store (the grid's `.draggable` evaluates this eagerly on render;
    // the empty-store simulator smoke test never rendered the grid, which is why it slipped through).
    static let storeReorder = UTType(exportedAs: "com.johannesemmrich.restock.storeReorder")
}
