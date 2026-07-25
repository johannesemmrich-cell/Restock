import SwiftUI
import SwiftData

struct StoreDetailView: View {
    @Bindable var store: Store
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme

    // Not read directly — its only job is to make SwiftUI re-invoke `body` (and thus re-derive
    // `store.pendingItems`, which internally consults this same key) the moment the user flips
    // the setting in SettingsView, instead of waiting for some unrelated state change to force a
    // redraw. Store-scoped, matching the key SettingsView's Toggle actually writes to.
    @AppStorage("autoSortByLearnedOrder", store: UserDefaults(suiteName: "group.com.johannesemmrich.SmartCart"))
    private var autoSortByLearnedOrder = true

    @State private var showAddItem = false
    @State private var showClearConfirm = false
    @State private var showReceiptScanner = false
    @State private var showActualPriceEntry = false
    @State private var showShareSheet = false
    @State private var showTemplatePicker = false
    @State private var showSaveTemplateAlert = false
    @State private var templateName = ""
    @State private var editingItem: ShoppingItem?
    @State private var completionOrder: [String] = []
    @State private var quickAddText: String = ""
    @State private var isSyncing = false
    @State private var syncFailed = false
    @State private var syncGeneration = 0
    @State private var showConfetti = false
    @FocusState private var isQuickAddFocused: Bool
    @Query private var allRecords: [PurchaseRecord]
    @ObservedObject private var templateService = TemplateService.shared
    @EnvironmentObject private var premium: PremiumService
    @State private var showPaywall = false
    @State private var paywallContext: PaywallContext = .premium(feature: "dieses Feature")

    // Local mirror of `store.groupByCategory` (which is UserDefaults-backed, so writing it alone
    // would never invalidate this view). The "···" menu toggle writes both: the Store property
    // for persistence, and this @State so SwiftUI re-renders immediately.
    @State private var groupByCategory: Bool

    init(store: Store) {
        self.store = store
        // Seed the mirror from the persisted per-store preference so even the very first
        // render already uses the layout the user chose last time.
        _groupByCategory = State(initialValue: store.groupByCategory)
    }

    private func total(for items: [ShoppingItem]) -> Double {
        items.compactMap { $0.estimatedLineTotal }.reduce(0, +)
    }

    /// "x von y" progress (count and bar below) counts only recently-completed items (see
    /// `Store.recentlyCompletedItems`) so it reflects the current shopping trip rather than
    /// growing forever — items stay listed in "Erledigt" regardless, this only affects the count.
    private var completionProgress: Double {
        let recentCount = store.recentlyCompletedItems.count
        let total = store.pendingItems.count + recentCount
        guard total > 0 else { return 0 }
        return Double(recentCount) / Double(total)
    }

    var body: some View {
        // Re-runs body (and thus `groupedRegularItems`' section derivation) whenever a sync
        // merge lands in SwiftData. Without this dependency, a remotely changed category shows
        // up inside the item (EditItemView/ItemRow observe the item directly) while the item
        // still sits in its old category section here.
        let _ = SyncCoordinator.shared.applyGeneration
        // Einmal pro Body-Durchlauf holen statt der ungecachten `store.pendingItems` (Filter +
        // Sort + UserDefaults-Zugriff) an bis zu 6 Stellen in diesem body einzeln neu aufzurufen.
        let pending = store.pendingItems
        List {
            Section {
                storeHero(pending: pending)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 4, trailing: 16))

            if syncFailed && store.shareID != nil {
                Section {
                    Button {
                        let generation = nextSyncGeneration()
                        Task {
                            let ok = await SyncCoordinator.shared.pull(store: store)
                            await MainActor.run { applySyncResult(ok, generation: generation) }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 13))
                            Text(syncFailureText)
                                .font(.system(size: 13))
                            Spacer()
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13))
                        }
                        .foregroundStyle(.orange)
                    }
                    .buttonStyle(.pressable)
                }
                .listRowBackground(Color.orange.opacity(0.1))
            }

            Section {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(store.color)
                        .font(.system(size: 18))
                    TextField(String(localized: "home.quickadd.placeholder"), text: $quickAddText)
                        .focused($isQuickAddFocused)
                        .submitLabel(.continue)
                        .onSubmit { quickAdd() }
                    if !quickAddText.isEmpty {
                        Button { quickAddText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color(.systemGray3))
                        }
                        .buttonStyle(.pressable)
                    }
                }
                if isQuickAddFocused {
                    ProductSuggestionChips(suggestions: quickAddSuggestions, tint: store.color, onSelect: applyQuickAddSuggestion)
                }
                if let parsed = quickAddParsed {
                    VStack(spacing: 4) {
                        HStack(spacing: 8) {
                            if parsed.quantityAmount != 1 || !parsed.unit.isEmpty {
                                Text(parsed.unit.isEmpty ? "\(parsed.quantity)×"
                                     : (parsed.quantityAmount != 1 ? "\(parsed.quantity) \(parsed.unit)" : parsed.unit))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(store.color, in: RoundedRectangle(cornerRadius: RCRadius.tag))
                            } else if let hint = historicQuantityHint(for: parsed.name) {
                                Text(hint)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(store.color.opacity(0.7), in: RoundedRectangle(cornerRadius: RCRadius.tag))
                            }
                            Text(parsed.name)
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            Image(systemName: "return")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        if let dup = quickAddDuplicate(for: parsed.name, in: pending) {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 11))
                                Text("'\(dup.name)' bereits in der Liste")
                                    .font(.system(size: 12))
                                Spacer()
                            }
                            .foregroundStyle(.orange)
                        }
                    }
                    .padding(.horizontal, 6).padding(.vertical, 5)
                    .background(store.color.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(store.color.opacity(0.2), lineWidth: 1))
                    .contentShape(Rectangle())
                    .onTapGesture { quickAdd() }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                }
            }
            .listRowBackground(Color.surface)
            .animation(.easeInOut(duration: 0.15), value: quickAddParsed?.name)

            Section {
                if !store.items.isEmpty {
                    progressHeader(pending: pending)
                }
                frequencyRow
            }
            .listRowBackground(Color.surface)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            let urgentItems = pending.filter { $0.isUrgent }
            let regularItems = pending.filter { !$0.isUrgent }

            if !urgentItems.isEmpty {
                Section {
                    ForEach(urgentItems) { item in
                        pendingRow(item)
                    }
                } header: {
                    Label("Dringend", systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(0.6)
                }
                .listRowBackground(Color.surface)
            }

            if !regularItems.isEmpty {
                if groupByCategory {
                    ForEach(groupedRegularItems(regularItems), id: \.category) { group in
                        Section {
                            ForEach(group.items) { item in
                                pendingRow(item)
                            }
                        } header: {
                            Text("\(group.emoji) \(group.category)")
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(0.6)
                        }
                        .listRowBackground(Color.surface)
                    }
                } else {
                    Section(String(localized: "list.pending")) {
                        ForEach(regularItems) { item in
                            pendingRow(item)
                        }
                    }
                    .listRowBackground(Color.surface)
                }
            }

            if !store.completedItems.isEmpty {
                Section {
                    ForEach(store.completedItems) { item in
                        ItemRow(item: item) { toggle(item: item) }
                            .contentShape(Rectangle())
                            .onTapGesture { editingItem = item }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    withAnimation { deleteItem(item) }
                                } label: {
                                    Label(String(localized: "action.delete"), systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    toggle(item: item)
                                } label: {
                                    Label(String(localized: "item.action.uncheck"), systemImage: "arrow.uturn.backward")
                                }
                                .tint(.orange)
                            }
                            .contextMenu {
                                if store.shareID != nil {
                                    assignMenuItems(for: item)
                                }
                            }
                    }
                } header: {
                    HStack {
                        Text(String(localized: "list.completed"))
                        Spacer()
                        Button(String(localized: "list.clear.completed")) {
                            showClearConfirm = true
                        }
                        .buttonStyle(.pressable)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .textCase(nil)
                    }
                }
                .listRowBackground(Color.surface)
            }

            if store.items.isEmpty {
                Section {
                    emptyState
                }
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.canvas)
        .navigationTitle(store.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ChipToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 20) {
                    if isSyncing {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Button {
                        if premium.hasSharedListsAccess {
                            showShareSheet = true
                        } else {
                            paywallContext = .sharedLists
                            showPaywall = true
                        }
                        Haptics.impact(.light)
                    } label: {
                        Image(systemName: store.shareID != nil ? "person.2.fill" : "person.2")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.ink)
                    }
                    .buttonStyle(.pressable)
                    Menu {
                        Toggle(isOn: Binding(
                            get: { groupByCategory },
                            set: { newValue in
                                withAnimation { groupByCategory = newValue }
                                store.groupByCategory = newValue
                                Haptics.impact(.light)
                            }
                        )) {
                            Label("Nach Kategorie gruppieren", systemImage: "square.grid.3x1.below.line.grid.1x2")
                        }
                        Divider()
                        if !store.completedItems.isEmpty {
                            Button("Kassenbon scannen", systemImage: "doc.text.viewfinder") {
                                if premium.hasPremiumAccess {
                                    showReceiptScanner = true
                                } else {
                                    paywallContext = .premium(feature: "den Kassenbon-Scan")
                                    showPaywall = true
                                }
                                Haptics.impact(.light)
                            }
                            Button("Preis eintragen", systemImage: "eurosign.circle") {
                                if premium.hasPremiumAccess {
                                    showActualPriceEntry = true
                                } else {
                                    paywallContext = .premium(feature: "das manuelle Eintragen von Preisen")
                                    showPaywall = true
                                }
                                Haptics.impact(.light)
                            }
                        }
                        Button("Als Vorlage speichern", systemImage: "plus.rectangle.on.folder") {
                            if premium.hasPremiumAccess {
                                templateName = store.name
                                showSaveTemplateAlert = true
                            } else {
                                paywallContext = .premium(feature: "Vorlagen")
                                showPaywall = true
                            }
                            Haptics.impact(.light)
                        }
                        .disabled(pending.isEmpty)
                        if !templateService.templates.isEmpty {
                            Button("Vorlage laden", systemImage: "folder") {
                                if premium.hasPremiumAccess {
                                    showTemplatePicker = true
                                } else {
                                    paywallContext = .premium(feature: "Vorlagen")
                                    showPaywall = true
                                }
                                Haptics.impact(.light)
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.ink)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.pressable)
                    Button {
                        showAddItem = true
                        Haptics.impact(.light)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17))
                            .foregroundStyle(Color.ink)
                    }
                    .buttonStyle(.pressable)
                }
                .toolbarChip()
            }
        }
        .sheet(isPresented: $showAddItem) { AddItemView() }
        .sheet(isPresented: $showShareSheet) { StoreShareSheet(store: store) }
        .sheet(isPresented: $showReceiptScanner) { ReceiptScannerView(store: store) }
        .sheet(isPresented: $showActualPriceEntry) { ActualPriceEntryView(store: store) }
        .sheet(isPresented: $showPaywall) { PaywallView(context: paywallContext) }
        .sheet(item: $editingItem) { item in EditItemView(item: item) }
        .sheet(isPresented: $showTemplatePicker) {
            TemplatePickerSheet(service: templateService) { template in
                loadTemplate(template)
            }
        }
        .alert("Vorlage speichern", isPresented: $showSaveTemplateAlert) {
            TextField("Name", text: $templateName)
            Button("Speichern") { saveAsTemplate() }
            Button("Abbrechen", role: .cancel) { templateName = "" }
        } message: {
            Text("\(pending.count) Artikel werden gespeichert")
        }
        .confirmationDialog(
            String(localized: "list.clear.confirm"),
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "list.clear.completed"), role: .destructive) {
                clearCompleted()
            }
        }
        .devFeedback(context: "Liste: \(store.name)")
        .onAppear {
            // Erst die aus der Dynamic Island gequeueten Haken persistieren, DANN die Activity
            // starten — sonst startet start(for:) für eine per Island komplett abgehakte Liste
            // kurz eine neue Activity, die der Drain eine Zeile später sofort wieder beendet (Flash).
            applyPendingCheckoffs()
            LiveActivityService.shared.start(for: store)
            // Kein eigener wiederkehrender Poll-Loop mehr hier — SyncCoordinator.startPeriodicPulls()
            // deckt bereits alle geteilten Stores app-weit alle 15s ab (Push + CloudKit-Notifications
            // bleiben der schnelle Pfad; Polling ist nur das Fallback-Netz), ein zusätzlicher lokaler
            // 10s-Loop hätte nur doppelt gepollt und doppelte Merge/Re-Render-Kaskaden ausgelöst,
            // genau während man die Liste aktiv ansieht. Der sofortige Pull unten bleibt für ein
            // knackiges erstes Laden.
            if store.shareID != nil {
                let generation = nextSyncGeneration()
                Task {
                    await MainActor.run { isSyncing = true }
                    let ok = await SyncCoordinator.shared.pull(store: store)
                    await MainActor.run {
                        isSyncing = false
                        applySyncResult(ok, generation: generation)
                    }
                }
            }
        }
        .onDisappear {
            LiveActivityService.shared.end(for: store)
            if store.shareID != nil {
                let generation = nextSyncGeneration()
                Task {
                    let ok = await SyncCoordinator.shared.push(store: store)
                    await MainActor.run { applySyncResult(ok, generation: generation) }
                }
            }
        }
        .onChange(of: pending.count) { oldCount, newCount in
            LiveActivityService.shared.update(for: store)
            if newCount == 0, oldCount > 0, !store.completedItems.isEmpty {
                showConfetti = true
                Task {
                    try? await Task.sleep(for: .seconds(3.5))
                    await MainActor.run { showConfetti = false }
                }
            }
        }
        .overlay {
            if showConfetti {
                ConfettiView()
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Category grouping

    /// Splits the (already sorted) non-urgent pending items into category sections for the
    /// optional grouped view. Same derivation as `HomeView.groupedByCategory`: manually-set
    /// categories stick as the user chose them, everything else keeps re-deriving from the
    /// current name so stale stored values and keyword-rule updates apply immediately.
    /// `Dictionary(grouping:)` preserves encounter order within each group, so inside a section
    /// the items keep the exact `store.pendingItems` order (learned aisle / insertion order).
    private func groupedRegularItems(_ items: [ShoppingItem]) -> [(category: String, emoji: String, items: [ShoppingItem])] {
        let grouped = Dictionary(grouping: items) {
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

    // MARK: - Pending row

    @ViewBuilder
    private func pendingRow(_ item: ShoppingItem) -> some View {
        ItemRow(item: item) { toggle(item: item) }
            .contentShape(Rectangle())
            .onTapGesture { editingItem = item }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    withAnimation { deleteItem(item) }
                } label: {
                    Label(String(localized: "action.delete"), systemImage: "trash")
                }
                Button {
                    withAnimation { item.isUrgent.toggle() }
                    item.lastModified = Date()
                    Haptics.impact(item.isUrgent ? .medium : .light)
                    syncPush()
                } label: {
                    Label(item.isUrgent ? "Normal" : "Dringend",
                          systemImage: item.isUrgent ? "exclamationmark.circle" : "exclamationmark.circle.fill")
                }
                .tint(.orange)
            }
            .swipeActions(edge: .leading) {
                Button { toggle(item: item) } label: {
                    Label(String(localized: "item.action.check"), systemImage: "checkmark")
                }
                .tint(.green)
                Button {
                    let me = UserIdentity.displayName
                    withAnimation { item.assignedTo = item.assignedTo == me ? "" : me }
                    item.lastModified = Date()
                    Haptics.impact(.light)
                    syncPush()
                } label: {
                    Label(item.assignedTo.isEmpty ? "Mir zuweisen" : "Freigeben",
                          systemImage: item.assignedTo.isEmpty ? "person.badge.plus" : "person.badge.minus")
                }
                .tint(.indigo)
            }
            .contextMenu {
                if store.shareID != nil {
                    assignMenuItems(for: item)
                }
            }
    }

    /// Shared context-menu content for assigning `item` to any member of `store` (not just
    /// yourself). Only meaningful for shared lists — callers must gate on `store.shareID != nil`
    /// before showing this, mirroring `EditItemView`'s "Zugewiesen an" picker gating exactly.
    @ViewBuilder
    private func assignMenuItems(for item: ShoppingItem) -> some View {
        ForEach(store.members, id: \.self) { member in
            Button {
                assign(item, to: item.assignedTo == member ? "" : member)
            } label: {
                Label(member, systemImage: item.assignedTo == member ? "checkmark.circle.fill" : "person.circle")
            }
        }
        if !item.assignedTo.isEmpty {
            Button {
                assign(item, to: "")
            } label: {
                Label("Niemandem zuweisen", systemImage: "person.crop.circle.badge.xmark")
            }
        }
    }

    /// Assigns `item` to `member` (or unassigns it if `member` is empty), mirroring exactly what
    /// the "Mir zuweisen" swipe action already does so shared-list sync sees a normal edit.
    private func assign(_ item: ShoppingItem, to member: String) {
        withAnimation { item.assignedTo = member }
        item.lastModified = Date()
        Haptics.impact(.light)
        syncPush()
    }

    // MARK: - Store hero

    private func storeHero(pending: [ShoppingItem]) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text(store.name)
                Text("· \(pending.count)")
                    .foregroundStyle(Color.accent)
            }
            .font(.wordmark(18))
            Text(VisitFrequency.closest(to: store.visitsPerWeek).label)
                .font(.system(size: 12))
                .foregroundStyle(Color.heroText.opacity(0.75))
        }
        .foregroundStyle(Color.heroText)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color.heroSurface)
        .clipShape(RoundedRectangle(cornerRadius: RCRadius.hero))
        .heroShadow(colorScheme)
    }

    // MARK: - Progress header

    private func progressHeader(pending: [ShoppingItem]) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(format: String(localized: "list.progress"),
                            store.recentlyCompletedItems.count, pending.count + store.recentlyCompletedItems.count))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.hairlineStrong)
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.accent)
                            .frame(width: geo.size.width * completionProgress, height: 6)
                            .animation(.spring(response: 0.4), value: completionProgress)
                    }
                }
                .frame(height: 6)
            }

            if total(for: pending) > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(localized: "list.estimated.total"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(total(for: pending), format: .currency(code: Locale.current.currency?.identifier ?? "EUR"))
                        .font(.system(size: 16, weight: .semibold))
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "cart")
                .font(.system(size: 40))
                .foregroundStyle(store.color.opacity(0.4))
            Text(String(localized: "list.empty.title"))
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(String(localized: "list.empty.subtitle"))
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Button {
                showAddItem = true
            } label: {
                Label(String(localized: "action.add"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(store.color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Quick add

    private var quickAddParsed: QuickAddResult? {
        guard !quickAddText.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let r = QuickAddParser.parse(quickAddText)
        guard r.name != quickAddText.trimmingCharacters(in: .whitespaces) || !r.unit.isEmpty else { return nil }
        return r
    }

    private var quickAddSuggestions: [String] {
        guard !quickAddText.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return QuickAddParser.knownProductSuggestions(for: QuickAddParser.parse(quickAddText).name, in: allRecords)
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
        let normalized = quickAddText
            .trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let parsedName = QuickAddParser.parse(quickAddText).name
        if normalized.hasSuffix(parsedName) {
            quickAddText = String(normalized.dropLast(parsedName.count)) + suggestion
        } else if normalized.hasPrefix(parsedName) {
            quickAddText = suggestion + String(normalized.dropFirst(parsedName.count))
        } else {
            quickAddText = suggestion
        }
    }

    private func quickAdd() {
        let trimmed = quickAddText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        Haptics.impact(.light)
        let parsed = QuickAddParser.parse(trimmed)
        let category = AssignmentService.category(for: parsed.name)

        // Apply historic quantity when user didn't specify one
        var finalQty = parsed.quantity
        var finalAmount = parsed.quantityAmount
        var finalUnit = parsed.unit
        if parsed.quantityAmount == 1 && parsed.unit.isEmpty,
           let nameLower = Optional(parsed.name.lowercased()), nameLower.count >= 3 {
            let matching = allRecords.filter { record in
                let rn = record.itemName.lowercased()
                return rn == nameLower || (rn.count >= 3 && (rn.contains(nameLower) || nameLower.contains(rn)))
            }
            if !matching.isEmpty {
                let recent = Array(matching.sorted { $0.date > $1.date }.prefix(5))
                let avg = recent.map { $0.quantityAmount }.reduce(0, +) / Double(recent.count)
                let histUnit = recent.compactMap { $0.unit.isEmpty ? nil : $0.unit }.first ?? ""
                if avg > 0 && !(avg == 1 && histUnit.isEmpty) {
                    finalAmount = avg
                    finalQty = avg == Double(Int(avg)) ? "\(Int(avg))" : String(format: "%.1f", avg)
                    finalUnit = histUnit
                }
            }
        }

        context.insert(ShoppingItem(
            name: parsed.name,
            category: category,
            quantity: finalQty,
            quantityAmount: finalAmount,
            unit: finalUnit,
            store: store
        ))
        quickAddText = ""
        DispatchQueue.main.async { isQuickAddFocused = true }
        syncPush()
    }

    /// Names the concrete failure instead of a generic "sync broken": a permanent server-side
    /// write rejection (CloudKit security roles) and a missing iCloud login need completely
    /// different reactions than a flaky network, but they'd all look identical otherwise.
    private var syncFailureText: String {
        switch SyncCoordinator.shared.lastFailureKind {
        case .permissionDenied:
            return "Keine Schreibberechtigung für diese geteilte Liste — deine Änderungen erreichen die anderen Mitglieder nicht"
        case .notAuthenticated:
            return "Nicht bei iCloud angemeldet — Änderungen werden nicht geteilt (Einstellungen → beim iPhone anmelden)"
        case .other:
            return "Sync fehlgeschlagen — Änderungen werden möglicherweise nicht mit anderen geteilt"
        }
    }

    /// Bumps and returns the current sync generation. Call this synchronously on the main actor
    /// right before kicking off an async sync call so the result can later be matched against
    /// whatever the *latest* generation is when it completes.
    @MainActor
    private func nextSyncGeneration() -> Int {
        syncGeneration += 1
        return syncGeneration
    }

    /// Applies a sync result only if it's still the most recent attempt in flight. Because
    /// CloudKit round-trip latency varies, an older/slower call can complete after a newer one —
    /// without this guard its stale result could stomp the newer one's `syncFailed` state.
    @MainActor
    private func applySyncResult(_ ok: Bool, generation: Int) {
        guard generation == syncGeneration else { return }
        syncFailed = !ok
    }

    /// Uploads the current list right after a local edit instead of waiting for the user to
    /// leave the screen, so changes show up on other members' devices within seconds.
    private func syncPush() {
        guard store.shareID != nil else { return }
        let generation = nextSyncGeneration()
        Task {
            let ok = await SyncCoordinator.shared.push(store: store)
            await MainActor.run { applySyncResult(ok, generation: generation) }
        }
    }

    /// Deletes an item, tombstoning it first if the store is shared so a periodic pull racing
    /// in between can't see "gone locally, still present remotely" and resurrect it as new.
    private func deleteItem(_ item: ShoppingItem) {
        let itemID = item.id
        guard let shareID = store.shareID else {
            context.delete(item)
            return
        }
        let generation = nextSyncGeneration()
        Task {
            await SharedStoreService.shared.recordLocalDeletion(shareID: shareID, itemID: itemID)
            await MainActor.run { withAnimation { context.delete(item) } }
            let ok = await SyncCoordinator.shared.push(store: store)
            await MainActor.run { applySyncResult(ok, generation: generation) }
        }
    }

    // MARK: - Frequency row

    private var frequencyRow: some View {
        let current = VisitFrequency.closest(to: store.visitsPerWeek)
        return HStack {
            Image(systemName: "calendar")
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(String(localized: "store.frequency.label"))
                .foregroundStyle(.secondary)
            Spacer()
            Menu {
                ForEach(VisitFrequency.allCases) { option in
                    Button {
                        store.visitsPerWeek = option.rawValue
                    } label: {
                        if option == current {
                            Label(option.label, systemImage: "checkmark")
                        } else {
                            Text(option.label)
                        }
                    }
                }
            } label: {
                Text(current.label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(store.color)
            }
        }
        .font(.system(size: 14))
        .padding(.vertical, 2)
    }

    // MARK: - Actions

    private func toggle(item: ShoppingItem) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            if item.isCompleted {
                item.markPending()
                Haptics.impact(.light)
            } else {
                completionOrder.append(item.name)
                item.markCompleted()
                store.recordCompletionOrder(completionOrder)
                Haptics.success()
            }
        }
        // Flush immediately so HomeView's @Query sees the change without delay
        try? context.save()
        LiveActivityService.shared.update(for: store)
        syncPush()
    }

    private func clearCompleted() {
        guard let shareID = store.shareID else {
            withAnimation {
                for item in store.completedItems { context.delete(item) }
                completionOrder.removeAll()
            }
            return
        }
        let deletedIDs = store.completedItems.map(\.id)
        let generation = nextSyncGeneration()
        Task {
            // Tombstone every id before any of them is actually deleted locally, so a periodic
            // pull racing in the middle of this batch can't resurrect the ones not yet tombstoned.
            for itemID in deletedIDs {
                await SharedStoreService.shared.recordLocalDeletion(shareID: shareID, itemID: itemID)
            }
            await MainActor.run {
                withAnimation {
                    for item in store.completedItems where deletedIDs.contains(item.id) { context.delete(item) }
                    completionOrder.removeAll()
                }
            }
            let ok = await SyncCoordinator.shared.push(store: store)
            await MainActor.run { applySyncResult(ok, generation: generation) }
        }
    }

    /// Same semantics as `WidgetStoreLoader.drainPendingCheckoffs` (keep in sync): complete
    /// exactly the item UUIDs queued by the Dynamic-Island intent; already-completed IDs
    /// (double-drain, sync merge, double-tap duplicates) are no-ops. Micro-window: app and
    /// widget could theoretically claim the same UUID simultaneously — accepted, no
    /// cross-process lock (see the drain comment in ShoppingListWidget.swift).
    private func applyPendingCheckoffs() {
        let defaults = UserDefaults(suiteName: "group.com.johannesemmrich.SmartCart")
        var applied = 0

        // UUID-Queue: exakt die gequeueten Items erledigen (nicht "die ersten N" —
        // count-basiert würde nach Widget-Checkoff/Sync-Merge das falsche Item treffen).
        let idKey = "pendingCheckoffIDs_\(store.name)"
        if let queuedIDs = defaults?.stringArray(forKey: idKey), !queuedIDs.isEmpty {
            defaults?.removeObject(forKey: idKey)
            for idString in queuedIDs {
                guard let id = UUID(uuidString: idString),
                      let item = store.items.first(where: { $0.id == id }),
                      !item.isCompleted else { continue }
                item.markCompleted()
                store.recordCompletionOrder([item.name])
                applied += 1
            }
        }

        // Legacy (einmaliger Übergang): Zähler-Key einer alten App-Version noch
        // count-basiert drainen, damit ein Update mitten im Einkauf nichts verliert.
        let legacyKey = "pendingCheckoffs_\(store.name)"
        let legacyCount = defaults?.integer(forKey: legacyKey) ?? 0
        if legacyCount > 0 {
            defaults?.removeObject(forKey: legacyKey)
            for _ in 0..<legacyCount {
                guard let item = store.pendingItems.first else { break }
                item.markCompleted()
                store.recordCompletionOrder([item.name])
                applied += 1
            }
        }

        guard applied > 0 else { return }
        try? context.save()
        LiveActivityService.shared.update(for: store)
    }

    // MARK: - QuickAdd helpers

    private func quickAddDuplicate(for name: String, in items: [ShoppingItem]) -> ShoppingItem? {
        let nameLower = name.lowercased()
        guard nameLower.count >= 3 else { return nil }
        return items.first { item in
            let n = item.name.lowercased()
            return n == nameLower || (n.count >= 3 && (n.contains(nameLower) || nameLower.contains(n)))
        }
    }

    private func historicQuantityHint(for name: String) -> String? {
        let nameLower = name.lowercased()
        guard nameLower.count >= 3 else { return nil }
        let matching = allRecords.filter { record in
            let rn = record.itemName.lowercased()
            return rn == nameLower || (rn.count >= 3 && (rn.contains(nameLower) || nameLower.contains(rn)))
        }
        guard !matching.isEmpty else { return nil }
        let recent = Array(matching.sorted { $0.date > $1.date }.prefix(5))
        let avgAmount = recent.map { $0.quantityAmount }.reduce(0, +) / Double(recent.count)
        guard avgAmount > 0 else { return nil }
        let lastUnit = recent.compactMap { $0.unit.isEmpty ? nil : $0.unit }.first ?? ""
        guard !(avgAmount == 1 && lastUnit.isEmpty) else { return nil }
        let qtyStr = avgAmount == Double(Int(avgAmount)) ? "\(Int(avgAmount))" : String(format: "%.1f", avgAmount)
        return lastUnit.isEmpty ? "\(qtyStr)×" : "\(qtyStr) \(lastUnit)"
    }

    // MARK: - Templates

    private func saveAsTemplate() {
        let name = templateName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        templateService.saveTemplate(name: name, from: store)
        templateName = ""
        Haptics.success()
    }

    private func loadTemplate(_ template: ListTemplate) {
        for item in template.items {
            context.insert(ShoppingItem(
                name: item.name,
                category: item.category,
                quantity: item.quantity,
                quantityAmount: item.quantityAmount,
                unit: item.unit,
                store: store
            ))
        }
        Haptics.success()
        syncPush()
    }

}

// MARK: - Confetti

private struct ConfettiView: View {
    private struct Particle: Identifiable {
        let id: Int
        let color: Color
        let x: CGFloat
        let width: CGFloat
        let height: CGFloat
        let duration: Double
        let delay: Double
        let startAngle: Double
        let endAngle: Double
    }

    private let particles: [Particle]
    @State private var isDropping = false

    init() {
        let palette: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .cyan, .mint, .teal]
        particles = (0..<100).map { i in
            Particle(
                id: i,
                color: palette[i % palette.count],
                x: CGFloat.random(in: 0.02...0.98),
                width: CGFloat.random(in: 7...14),
                height: CGFloat.random(in: 4...8),
                duration: Double.random(in: 1.8...3.2),
                delay: Double.random(in: 0...0.9),
                startAngle: Double.random(in: -30...30),
                endAngle: Double.random(in: 180...540)
            )
        }
    }

    var body: some View {
        GeometryReader { geo in
            ForEach(particles) { p in
                RoundedRectangle(cornerRadius: 2)
                    .fill(p.color)
                    .frame(width: p.width, height: p.height)
                    .rotationEffect(.degrees(isDropping ? p.endAngle : p.startAngle))
                    .offset(
                        x: geo.size.width * (p.x - 0.5),
                        y: isDropping ? geo.size.height * 0.5 + 40 : -geo.size.height * 0.5 - 30
                    )
                    .animation(
                        .easeIn(duration: p.duration).delay(p.delay),
                        value: isDropping
                    )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear { isDropping = true }
    }
}

// MARK: - Template Picker Sheet

private struct TemplatePickerSheet: View {
    @ObservedObject var service: TemplateService
    let onSelect: (ListTemplate) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(service.templates.sorted { $0.createdAt > $1.createdAt }) { template in
                    Button {
                        onSelect(template)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("\(template.storeEmoji) \(template.storeName) · \(template.items.count) Artikel")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            service.delete(id: template.id)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Vorlage laden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ChipToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("Abbrechen").toolbarChip(prominent: false) }
                        .buttonStyle(.pressable)
}
            }
        }
    }
}
