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

    var body: some View {
        List {
            if !store.pendingItems.isEmpty {
                Section(header: listHeader) {
                    ForEach(store.pendingItems) { item in
                        ItemRow(item: item) {
                            toggle(item: item)
                        }
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
                Section(String(localized: "list.completed")) {
                    ForEach(store.completedItems) { item in
                        ItemRow(item: item) {
                            toggle(item: item)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                context.delete(item)
                            } label: {
                                Label(String(localized: "action.delete"), systemImage: "trash")
                            }
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Label(String(localized: "list.clear.completed"), systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }

            if store.items.isEmpty {
                emptyState
            }
        }
        .navigationTitle(store.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddItem = true
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

    private var listHeader: some View {
        HStack {
            Text(String(localized: "list.pending"))
            Spacer()
            if total > 0 {
                Text("~\(total, format: .currency(code: Locale.current.currency?.identifier ?? "EUR"))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "cart")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
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
        .listRowBackground(Color.clear)
    }

    private func toggle(item: ShoppingItem) {
        withAnimation {
            if item.isCompleted {
                item.markPending()
            } else {
                completionOrder.append(item.name)
                item.markCompleted()
                store.recordCompletionOrder(completionOrder)
            }
        }
    }

    private func clearCompleted() {
        for item in store.completedItems {
            context.delete(item)
        }
        completionOrder.removeAll()
    }
}
