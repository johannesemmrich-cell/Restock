import SwiftUI
import SwiftData

struct StoreDetailView: View {
    @Bindable var store: Store
    @Environment(\.modelContext) private var context
    @State private var showAddItem = false
    @State private var showClearConfirm = false
    @State private var showReceiptScanner = false
    @State private var editingItem: ShoppingItem?
    @State private var completionOrder: [String] = []
    @State private var quickAddText: String = ""
    @Query private var allRecords: [PurchaseRecord]

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
                        .submitLabel(.done)
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
                    HStack(spacing: 8) {
                        if parsed.quantityAmount != 1 || !parsed.unit.isEmpty {
                            Text(parsed.unit.isEmpty ? "\(parsed.quantity)×"
                                 : (parsed.quantityAmount != 1 ? "\(parsed.quantity) \(parsed.unit)" : parsed.unit))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(store.color, in: Capsule())
                        }
                        Text(parsed.name)
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Image(systemName: "return")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
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

            if !store.pendingItems.isEmpty {
                Section(String(localized: "list.pending")) {
                    ForEach(store.pendingItems) { item in
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
                                Button {
                                    toggle(item: item)
                                } label: {
                                    Label(String(localized: "item.action.check"), systemImage: "checkmark")
                                }
                                .tint(.green)
                            }
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
                    if !store.completedItems.isEmpty {
                        Button {
                            showReceiptScanner = true
                            Haptics.impact(.light)
                        } label: {
                            Image(systemName: "doc.text.viewfinder")
                        }
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
        .sheet(isPresented: $showReceiptScanner) {
            ReceiptScannerView(storeName: store.name)
        }
        .sheet(item: $editingItem) { item in EditItemView(item: item) }
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
        }
        .onDisappear {
            LiveActivityService.shared.end(for: store)
        }
        .onChange(of: store.pendingItems.count) {
            LiveActivityService.shared.update(for: store)
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
        context.insert(ShoppingItem(
            name: parsed.name,
            category: category,
            quantity: parsed.quantity,
            quantityAmount: parsed.quantityAmount,
            unit: parsed.unit,
            store: store
        ))
        quickAddText = ""
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
    }

    private func clearCompleted() {
        withAnimation {
            for item in store.completedItems { context.delete(item) }
            completionOrder.removeAll()
        }
    }
}
