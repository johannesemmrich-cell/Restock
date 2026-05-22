import SwiftUI
import SwiftData

struct StoreDetailView: View {
    @Bindable var store: Store
    @Environment(\.modelContext) private var context
    @State private var showAddItem = false
    @State private var showClearConfirm = false
    @State private var completionOrder: [String] = []

    private var total: Double {
        store.pendingItems.compactMap { $0.estimatedPrice }.reduce(0, +)
    }
    private var completionProgress: Double {
        guard !store.items.isEmpty else { return 0 }
        return Double(store.completedItems.count) / Double(store.items.count)
    }

    var body: some View {
        List {
            // Progress + total header
            if !store.items.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
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

                            Spacer(minLength: 20)

                            if total > 0 {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(String(localized: "list.estimated.total"))
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                    Text(total, format: .currency(code: Locale.current.currency?.identifier ?? "EUR"))
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.cardBackground)
            }

            if !store.pendingItems.isEmpty {
                Section(String(localized: "list.pending")) {
                    ForEach(store.pendingItems) { item in
                        ItemRow(item: item) { toggle(item: item) }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    context.delete(item)
                                } label: {
                                    Label(String(localized: "action.delete"), systemImage: "trash")
                                }
                            }
                    }
                }
            }

            if !store.completedItems.isEmpty {
                Section {
                    ForEach(store.completedItems) { item in
                        ItemRow(item: item) { toggle(item: item) }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    context.delete(item)
                                } label: {
                                    Label(String(localized: "action.delete"), systemImage: "trash")
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
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .textCase(nil)
                    }
                }
            }

            if store.items.isEmpty {
                Section {
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
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle(store.emoji + " " + store.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddItem = true
                    Haptics.impact(.light)
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showAddItem) {
            AddItemView()
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
    }

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
