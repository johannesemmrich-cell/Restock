import SwiftUI
import SwiftData

struct StoreDetailView: View {
    @Bindable var store: Store
    @Environment(\.modelContext) private var context
    @State private var showAddItem = false
    @State private var showClearConfirm = false
    @State private var showReceiptScanner = false
    @State private var showShareSheet = false
    @State private var showTemplatePicker = false
    @State private var showSaveTemplateAlert = false
    @State private var templateName = ""
    @State private var editingItem: ShoppingItem?
    @State private var completionOrder: [String] = []
    @State private var quickAddText: String = ""
    @State private var isSyncing = false
    @State private var showConfetti = false
    @State private var periodicSyncTask: Task<Void, Never>?
    @FocusState private var isQuickAddFocused: Bool
    @Query private var allRecords: [PurchaseRecord]
    @ObservedObject private var templateService = TemplateService.shared

    private var total: Double {
        store.pendingItems.compactMap { $0.estimatedPrice }.reduce(0, +)
    }
    private var completionProgress: Double {
        guard !store.items.isEmpty else { return 0 }
        return Double(store.completedItems.count) / Double(store.items.count)
    }

    var body: some View {
        List {
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
                        .buttonStyle(.plain)
                    }
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
                                    .background(store.color, in: Capsule())
                            } else if let hint = historicQuantityHint(for: parsed.name) {
                                Text(hint)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(store.color.opacity(0.7), in: Capsule())
                            }
                            Text(parsed.name)
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            Image(systemName: "return")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        if let dup = quickAddDuplicate(for: parsed.name) {
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
            .animation(.easeInOut(duration: 0.15), value: quickAddParsed?.name)

            Section {
                if !store.items.isEmpty {
                    progressHeader
                }
                frequencyRow
            }
            .listRowBackground(Color.cardBackground)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            let urgentItems = store.pendingItems.filter { $0.isUrgent }
            let regularItems = store.pendingItems.filter { !$0.isUrgent }

            if !urgentItems.isEmpty {
                Section {
                    ForEach(urgentItems) { item in
                        pendingRow(item)
                    }
                } header: {
                    Label("Dringend", systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 12, weight: .semibold))
                        .textCase(nil)
                }
            }

            if !regularItems.isEmpty {
                Section(String(localized: "list.pending")) {
                    ForEach(regularItems) { item in
                        pendingRow(item)
                    }
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
                                    withAnimation { context.delete(item) }
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
                    }
                } header: {
                    HStack {
                        Text(String(localized: "list.completed"))
                        Spacer()
                        Button(String(localized: "list.clear.completed")) {
                            showClearConfirm = true
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .textCase(nil)
                    }
                }
            }

            if store.items.isEmpty {
                Section {
                    emptyState
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle(store.emoji + " " + store.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    if isSyncing {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Button {
                        showShareSheet = true
                        Haptics.impact(.light)
                    } label: {
                        Image(systemName: store.shareID != nil ? "person.2.fill" : "person.2")
                    }
                    Menu {
                        if !store.completedItems.isEmpty {
                            Button("Kassenbon scannen", systemImage: "doc.text.viewfinder") {
                                showReceiptScanner = true
                                Haptics.impact(.light)
                            }
                        }
                        Button("Als Vorlage speichern", systemImage: "plus.rectangle.on.folder") {
                            templateName = store.name
                            showSaveTemplateAlert = true
                            Haptics.impact(.light)
                        }
                        .disabled(store.pendingItems.isEmpty)
                        if !templateService.templates.isEmpty {
                            Button("Vorlage laden", systemImage: "folder") {
                                showTemplatePicker = true
                                Haptics.impact(.light)
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    Button {
                        showAddItem = true
                        Haptics.impact(.light)
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddItem) { AddItemView() }
        .sheet(isPresented: $showShareSheet) { StoreShareSheet(store: store) }
        .sheet(isPresented: $showReceiptScanner) { ReceiptScannerView(store: store) }
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
            Text("\(store.pendingItems.count) Artikel werden gespeichert")
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
            LiveActivityService.shared.start(for: store)
            if store.shareID != nil {
                Task { await syncSharedStore() }
                periodicSyncTask = Task {
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(30))
                        if !Task.isCancelled { await syncSharedStore() }
                    }
                }
            }
        }
        .onDisappear {
            periodicSyncTask?.cancel()
            periodicSyncTask = nil
            LiveActivityService.shared.end(for: store)
            if store.shareID != nil {
                Task { try? await SharedStoreService.shared.push(store: store) }
            }
        }
        .onChange(of: store.pendingItems.count) {
            LiveActivityService.shared.update(for: store)
        }
        .onChange(of: store.pendingItems.count) { oldCount, newCount in
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

    // MARK: - Pending row

    @ViewBuilder
    private func pendingRow(_ item: ShoppingItem) -> some View {
        ItemRow(item: item) { toggle(item: item) }
            .contentShape(Rectangle())
            .onTapGesture { editingItem = item }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    withAnimation { context.delete(item) }
                } label: {
                    Label(String(localized: "action.delete"), systemImage: "trash")
                }
                Button {
                    withAnimation { item.isUrgent.toggle() }
                    Haptics.impact(item.isUrgent ? .medium : .light)
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
                    let myDevice = UIDevice.current.name
                    withAnimation { item.assignedTo = item.assignedTo == myDevice ? "" : myDevice }
                    Haptics.impact(.light)
                } label: {
                    Label(item.assignedTo.isEmpty ? "Mir zuweisen" : "Freigeben",
                          systemImage: item.assignedTo.isEmpty ? "person.badge.plus" : "person.badge.minus")
                }
                .tint(.indigo)
            }
    }

    // MARK: - Progress header

    private var progressHeader: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(format: String(localized: "list.progress"),
                            store.completedItems.count, store.items.count))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient.success)
                            .frame(width: geo.size.width * completionProgress, height: 6)
                            .animation(.spring(response: 0.4), value: completionProgress)
                    }
                }
                .frame(height: 6)
            }

            if total > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(localized: "list.estimated.total"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(total, format: .currency(code: Locale.current.currency?.identifier ?? "EUR"))
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
    }

    private func clearCompleted() {
        withAnimation {
            for item in store.completedItems { context.delete(item) }
            completionOrder.removeAll()
        }
    }

    // MARK: - QuickAdd helpers

    private func quickAddDuplicate(for name: String) -> ShoppingItem? {
        let nameLower = name.lowercased()
        guard nameLower.count >= 3 else { return nil }
        return store.pendingItems.first { item in
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
    }

    private func syncSharedStore() async {
        guard let shareID = store.shareID else { return }
        isSyncing = true
        defer { Task { @MainActor in isSyncing = false } }

        guard let (remoteItems, _) = try? await SharedStoreService.shared.pull(shareID: shareID) else { return }

        await MainActor.run {
            let localByID = Dictionary(uniqueKeysWithValues: store.items.map { ($0.id, $0) })
            let remoteByID = Dictionary(uniqueKeysWithValues: remoteItems.map { ($0.id, $0) })

            // Remove items deleted remotely
            for item in store.items where remoteByID[item.id] == nil {
                context.delete(item)
            }

            // Add or update remote items
            for remote in remoteItems {
                if let local = localByID[remote.id] {
                    local.name = remote.name
                    local.isCompleted = remote.isCompleted
                    local.isUrgent = remote.isUrgent
                    local.quantity = remote.quantity
                    local.quantityAmount = remote.quantityAmount
                    local.unit = remote.unit
                    local.note = remote.note
                    local.category = remote.category
                    local.assignedTo = remote.assignedTo
                } else {
                    let item = ShoppingItem(
                        name: remote.name, category: remote.category,
                        quantity: remote.quantity, quantityAmount: remote.quantityAmount,
                        unit: remote.unit, note: remote.note, store: store
                    )
                    item.id = remote.id
                    item.isCompleted = remote.isCompleted
                    item.isUrgent = remote.isUrgent
                    item.assignedTo = remote.assignedTo
                    context.insert(item)
                }
            }

            try? context.save()
        }
        await SharedStoreService.shared.markSynced(shareID: shareID)
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }
}
