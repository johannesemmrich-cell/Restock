import SwiftUI
import SwiftData

struct AllItemsView: View {
    @Query(filter: #Predicate<ShoppingItem> { $0.isCompleted == false }) private var pendingItems: [ShoppingItem]
    @Query(filter: #Predicate<Store> { $0.isActive }) private var activeStores: [Store]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @AppStorage("allItemsGroupByCategory") private var groupByCategory = false

    private var urgentItems: [ShoppingItem] {
        pendingItems.filter { $0.isUrgent }
    }

    private var nonUrgentByStore: [(store: Store, items: [ShoppingItem])] {
        let grouped = Dictionary(grouping: pendingItems.filter { !$0.isUrgent }) { $0.store?.persistentModelID }
        return activeStores.compactMap { store in
            guard let items = grouped[store.persistentModelID], !items.isEmpty else { return nil }
            return (store, items)
        }
    }

    private var nonUrgentByCategory: [(category: String, emoji: String, items: [ShoppingItem])] {
        let grouped = Dictionary(grouping: pendingItems.filter { !$0.isUrgent }) { AssignmentService.category(for: $0.name) }
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

    var body: some View {
        NavigationStack {
            List {
                if pendingItems.isEmpty {
                    ContentUnavailableView(
                        "Alles erledigt",
                        systemImage: "checkmark.circle",
                        description: Text("Keine offenen Artikel in deinen Listen.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    if !urgentItems.isEmpty {
                        Section {
                            ForEach(urgentItems) { item in
                                itemRow(item, storeColor: item.store?.color ?? .gray, storeEmoji: groupByCategory ? nil : item.store?.emoji)
                            }
                        } header: {
                            Label("Dringend", systemImage: "exclamationmark.circle.fill")
                                .foregroundStyle(.orange)
                                .font(.system(size: 12, weight: .semibold))
                                .textCase(nil)
                        }
                    }

                    if groupByCategory {
                        ForEach(nonUrgentByCategory, id: \.category) { group in
                            Section {
                                ForEach(group.items) { item in
                                    itemRow(item, storeColor: .secondary, storeEmoji: nil)
                                }
                            } header: {
                                HStack(spacing: 6) {
                                    Text(group.emoji)
                                    Text(group.category)
                                        .font(.system(size: 13, weight: .semibold))
                                    Spacer()
                                    Text("\(group.items.count) Artikel")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else {
                        ForEach(nonUrgentByStore, id: \.store.persistentModelID) { entry in
                            Section {
                                ForEach(entry.items) { item in
                                    itemRow(item, storeColor: entry.store.color, storeEmoji: nil)
                                }
                            } header: {
                                HStack(spacing: 6) {
                                    Text(entry.store.emoji)
                                    Text(entry.store.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(entry.store.color)
                                    Spacer()
                                    Text("\(entry.items.count) Artikel")
                                        .font(.system(size: 11))
                                        .foregroundStyle(entry.store.color.opacity(0.7))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Alle Artikel (\(pendingItems.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { groupByCategory.toggle() }
                        Haptics.impact(.light)
                    } label: {
                        Label(
                            groupByCategory ? "Nach Läden" : "Nach Produktart",
                            systemImage: groupByCategory ? "storefront" : "tag"
                        )
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .devFeedback(context: "Alle Artikel")
    }

    @ViewBuilder
    private func itemRow(_ item: ShoppingItem, storeColor: Color, storeEmoji: String?) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if item.isUrgent {
                        Image(systemName: "exclamationmark")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.orange, in: Capsule())
                    }
                    Text(item.name)
                        .font(.system(size: 15))
                    if let emoji = storeEmoji {
                        Text(emoji)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                if !item.unit.isEmpty || item.quantityAmount != 1 {
                    Text("\(item.quantity)\(!item.unit.isEmpty ? " \(item.unit)" : "")")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                withAnimation(.spring(response: 0.3)) { item.markCompleted() }
                Haptics.success()
            } label: {
                Image(systemName: "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(storeColor.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}
