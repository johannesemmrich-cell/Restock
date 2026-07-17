import SwiftUI
import SwiftData
import UIKit

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

    @AppStorage("seasonalSuggestionsEnabled") private var seasonalSuggestionsEnabled = true
    @AppStorage("homeListMode") private var listMode = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
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

    private var seasonalSuggestions: [SeasonalService.Suggestion] {
        seasonalSuggestionsEnabled ? SeasonalService.currentSuggestions() : []
    }

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var totalPending: Int {
        activeStores.filter { !$0.isPaused }.reduce(0) { $0 + $1.pendingItems.count } + storelessPending.count
    }

    var body: some View {
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
                                color: .orange,
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
                                color: .green,
                                title: "\(seasonalSuggestions.count) saisonale Vorschläge",
                                subtitle: "Saisonale Ideen mit Restock Pro",
                                feature: "saisonale Vorschläge"
                            )
                        }
                    }
                    storeSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
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
            .onAppear {
                refreshDueSoon()
                registerShortcutItems()
                if QuickActionState.shared.triggerQuickAdd {
                    QuickActionState.shared.triggerQuickAdd = false
                    activateQuickAdd()
                }
                checkPendingQuickAdd()
            }
            .onReceive(NotificationCenter.default.publisher(for: .quickAddRequested)) { _ in
                activateQuickAdd()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    checkPendingQuickAdd()
                }
            }
            .onChange(of: allRecords.count) { refreshDueSoon() }
            .devFeedback(context: "Startseite")
            .confirmationDialog(
                "Laden löschen?",
                isPresented: Binding(get: { storeToDelete != nil }, set: { if !$0 { storeToDelete = nil } }),
                titleVisibility: .visible
            ) {
                if let store = storeToDelete {
                    Button("Löschen", role: .destructive) {
                        context.delete(store)
                        Haptics.impact(.medium)
                        storeToDelete = nil
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
                    Color.black.opacity(0.45)
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
                Image(systemName: "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(0.65))
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        if item.isUrgent {
                            Image(systemName: "exclamationmark")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(.white.opacity(0.25), in: Capsule())
                        }
                        Text(item.name)
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                        if let emoji = storeEmoji {
                            Text(emoji)
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    if !item.unit.isEmpty || item.quantityAmount != 1 {
                        Text(item.quantity + (!item.unit.isEmpty ? " \(item.unit)" : ""))
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func openBanner() {
        guard totalPending > 0 else { return }
        Haptics.impact(.medium)
        withAnimation(.spring(response: 0.82, dampingFraction: 0.78)) { bannerExpanded = true }
    }

    private func closeBanner() {
        withAnimation(.spring(response: 0.68, dampingFraction: 0.88)) { bannerExpanded = false }
    }

    private var headerCard: some View {
        ZStack(alignment: .bottomLeading) {
            Circle()
                .fill(.white.opacity(0.07))
                .frame(width: 140, height: 140)
                .offset(x: 210, y: -30)
            Circle()
                .fill(.white.opacity(0.05))
                .frame(width: 90, height: 90)
                .offset(x: 260, y: 20)
            VStack(alignment: .leading, spacing: 4) {
                Text("Restock")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                if totalPending > 0 {
                    HStack(spacing: 6) {
                        Text(String(format: String(localized: "home.header.items"), totalPending, activeStores.count))
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.8))
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                } else {
                    Text(String(localized: "home.header.empty"))
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(20)
        }
        .frame(height: 130)
        .frame(maxWidth: .infinity)
        .background(LinearGradient.brand)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.brand.opacity(0.4), radius: 16, x: 0, y: 6)
        .matchedGeometryEffect(id: "heroBanner", in: bannerNamespace, isSource: !bannerExpanded)
        .opacity(bannerExpanded ? 0 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .onTapGesture { openBanner() }
    }

    private var expandedBannerCard: some View {
        VStack(spacing: 0) {
            // Header section
            ZStack(alignment: .bottomLeading) {
                Circle()
                    .fill(.white.opacity(0.07))
                    .frame(width: 130, height: 130)
                    .offset(x: 230, y: -15)
                Circle()
                    .fill(.white.opacity(0.05))
                    .frame(width: 85, height: 85)
                    .offset(x: 275, y: 20)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Restock")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                    Text(String(format: String(localized: "home.header.items"), totalPending, activeStores.count))
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(20)
                Button { closeBanner() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.white.opacity(0.7))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(14)
            }
            .frame(height: 110)
            .frame(maxWidth: .infinity)

            Rectangle().fill(.white.opacity(0.2)).frame(height: 0.5)

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
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                        .padding(.bottom, 2)
                        ForEach(allUrgent, id: \.item.id) { entry in
                            bannerItemButton(entry.item, storeEmoji: entry.emoji)
                        }
                        Rectangle().fill(.white.opacity(0.1)).frame(height: 0.5)
                            .padding(.horizontal, 18)
                            .padding(.top, 4)
                    }

                    ForEach(storesWithPendingItems) { store in
                        let nonUrgent = store.pendingItems.filter { !$0.isUrgent }
                        if !nonUrgent.isEmpty {
                            HStack(spacing: 6) {
                                Text(store.emoji).font(.system(size: 13))
                                Text(store.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.85))
                                Spacer()
                                Text("\(nonUrgent.count)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .padding(.horizontal, 18)
                            .padding(.top, 12)
                            .padding(.bottom, 2)
                            ForEach(nonUrgent) { item in
                                bannerItemButton(item, storeEmoji: nil)
                            }
                        }
                    }

                    let storelessRegular = storelessPending.filter { !$0.isUrgent }
                    if !storelessRegular.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "tray")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.85))
                            Text("Ohne Laden")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.85))
                            Spacer()
                            Text("\(storelessRegular.count)")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.5))
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

            Rectangle().fill(.white.opacity(0.15)).frame(height: 0.5)

            // Footer
            Button {
                closeBanner()
                showAllItems = true
            } label: {
                HStack(spacing: 4) {
                    Text("Vollständige Liste")
                        .font(.system(size: 13, weight: .medium))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
        }
        .background(LinearGradient.brand)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.brand.opacity(0.55), radius: 28, x: 0, y: 14)
    }

    // MARK: - Quick add

    private var parsedHint: QuickAddResult? {
        guard !addItemText.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let r = QuickAddParser.parse(addItemText)
        // Only show chip when something meaningful was parsed (name differs or unit present)
        guard r.name != addItemText.trimmingCharacters(in: .whitespaces) || !r.unit.isEmpty else { return nil }
        return r
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
                    Image(systemName: quickAddSucceeded ? "checkmark.circle.fill" : "plus.circle.fill")
                        .foregroundStyle(quickAddSucceeded ? .green : .blue)
                        .font(.system(size: 18))
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
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)

                Button {
                    Haptics.impact(.light)
                    showRecipeImport = true
                } label: {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(LinearGradient.brand)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
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
                                    .foregroundStyle(.blue)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
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
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue, in: Capsule())
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
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue.opacity(0.18), lineWidth: 1)
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: parsedHint?.name)
    }

    // MARK: - Seasonal banner

    private var seasonalBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("\(SeasonalService.currentSeason)stipps", systemImage: SeasonalService.seasonIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.green)
                Spacer()
                Button("Alle hinzufügen") {
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
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.green)
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
                            .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.25), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.green.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Premium teaser

    private func premiumTeaser(icon: String, color: Color, title: String, subtitle: String, feature: String) -> some View {
        Button {
            paywallContext = .premium(feature: feature)
            showPaywall = true
            Haptics.impact(.light)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Pro")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(LinearGradient.brand, in: Capsule())
            }
            .padding(14)
            .background(color.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Replenishment banner

    private var replenishmentBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(String(localized: "home.replenish.title"), systemImage: "arrow.clockwise.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.orange)
                Spacer()
                Button(String(localized: "home.replenish.addall")) {
                    addDueSoonToList()
                    Haptics.success()
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.orange)
            }

            ForEach(dueSoonItems, id: \.itemName) { pattern in
                HStack(spacing: 8) {
                    Circle()
                        .fill(pattern.isOverdue ? Color.destructive : Color.warning)
                        .frame(width: 7, height: 7)
                    Text(pattern.itemName)
                        .font(.system(size: 14))
                    Spacer()
                    Text(pattern.isOverdue
                         ? String(localized: "replenish.overdue")
                         : String(format: String(localized: "replenish.in.days"), pattern.daysUntilNeeded))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Button {
                        addSingleDueItem(pattern)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                    Button {
                        dismissDueItem(pattern)
                    } label: {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(Color.warning.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.warning.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Store grid / Category list

    private var storeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(listMode ? "Alle Artikel" : String(localized: "home.stores.title"))
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { listMode.toggle() }
                    Haptics.impact(.light)
                } label: {
                    Image(systemName: listMode ? "rectangle.grid.2x2" : "list.bullet")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                if !listMode {
                    Button { showStoreSetup = true } label: {
                        Text("Verwalten")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if listMode {
                categoryListView
            } else if activeStores.isEmpty {
                emptyStoresView
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(activeStores) { store in
                        NavigationLink {
                            StoreDetailView(store: store)
                        } label: {
                            StoreCard(store: store)
                        }
                        .buttonStyle(.plain)
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
                    }
                    addStoreCard
                    joinListCard
                }
            }
        }
    }

    // MARK: - Category list

    private var allPendingItems: [ShoppingItem] {
        activeStores.filter { !$0.isPaused }.flatMap { $0.pendingItems } + storelessPending
    }

    private var groupedByCategory: [(category: String, emoji: String, items: [ShoppingItem])] {
        // Always compute category from current name so stale stored values and rule updates apply immediately
        let grouped = Dictionary(grouping: allPendingItems) { AssignmentService.category(for: $0.name) }
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
                    .foregroundStyle(Color.brand.opacity(0.5))
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
                            Text(group.category)
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
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
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
                Image(systemName: "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.brand.opacity(0.45))
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
        .buttonStyle(.plain)
    }

    private var addStoreCard: some View {
        Button {
            showAddStore = true
            Haptics.impact(.light)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color.brand.opacity(0.6))
                Text("Laden hinzufügen")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.brand.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .background(Color.brand.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .foregroundStyle(Color.brand.opacity(0.25))
            )
        }
        .buttonStyle(.plain)
    }

    private var joinListCard: some View {
        Button {
            showJoinStore = true
            Haptics.impact(.light)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color.indigo.opacity(0.7))
                Text("Geteilter Liste beitreten")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.indigo.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .background(Color.indigo.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .foregroundStyle(Color.indigo.opacity(0.25))
            )
        }
        .buttonStyle(.plain)
    }

    private var emptyStoresView: some View {
        VStack(spacing: 16) {
            Image(systemName: "storefront")
                .font(.system(size: 44))
                .foregroundStyle(Color.brand.opacity(0.5))
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
                Label("Geteilter Liste beitreten", systemImage: "person.badge.plus")
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .cardStyle()
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            HStack(spacing: 16) {
                Button { showSettings = true } label: {
                    Image(systemName: "gear").foregroundStyle(.primary)
                }
                Button {
                    if premium.hasPremiumAccess {
                        showMenuPlan = true
                    } else {
                        paywallContext = .premium(feature: "den Menüplan")
                        showPaywall = true
                    }
                } label: {
                    Image(systemName: "fork.knife").foregroundStyle(.primary)
                }
                Button {
                    if premium.hasPremiumAccess {
                        showPriceOverview = true
                    } else {
                        paywallContext = .premium(feature: "die Ausgaben-Analyse")
                        showPaywall = true
                    }
                } label: {
                    Image(systemName: "chart.line.uptrend.xyaxis").foregroundStyle(.primary)
                }
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 16) {
                Button {
                    Haptics.impact(.light)
                    showAllItems = true
                } label: {
                    Image(systemName: "list.bullet.rectangle")
                        .foregroundStyle(.primary)
                }
                Button {
                    Haptics.impact(.light)
                    showAddItem = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
            }
        }
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
                localizedTitle: String(localized: "Artikel hinzufügen"),
                localizedSubtitle: String(localized: "Zur Einkaufsliste hinzufügen"),
                icon: UIApplicationShortcutIcon(systemImageName: "cart.badge.plus"),
                userInfo: nil
            )
        ]
    }

    private func addDueSoonToList() {
        var touchedStores: [Store?] = []
        for pattern in dueSoonItems {
            let store = AssignmentService.assign(itemName: pattern.itemName, to: activeStores, purchaseRecords: allRecords)
            context.insert(ShoppingItem(name: pattern.itemName, store: store))
            touchedStores.append(store)
        }
        dueSoonItems = []
        SyncCoordinator.shared.pushInBackground(touchedStores)
    }

    private func addSingleDueItem(_ pattern: ConsumptionPattern) {
        let store = AssignmentService.assign(itemName: pattern.itemName, to: activeStores, purchaseRecords: allRecords)
        context.insert(ShoppingItem(name: pattern.itemName, store: store))
        dueSoonItems.removeAll { $0.itemName == pattern.itemName }
        Haptics.impact(.light)
        SyncCoordinator.shared.pushInBackground(store)
    }
}
