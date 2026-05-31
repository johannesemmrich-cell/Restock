import SwiftUI
import SwiftData

struct AllItemsView: View {
    @Query(filter: #Predicate<Store> { $0.isActive }) private var stores: [Store]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private var storesWithItems: [Store] {
        stores.filter { !$0.pendingItems.isEmpty }
    }

    private var totalPending: Int {
        stores.reduce(0) { $0 + $1.pendingItems.count }
    }

    private var allUrgentItems: [(item: ShoppingItem, store: Store)] {
        storesWithItems.flatMap { store in
            store.pendingItems.filter { $0.isUrgent }.map { (item: $0, store: store) }
        }
    }

    private var storesWithNonUrgentItems: [Store] {
        storesWithItems.filter { store in
            store.pendingItems.contains { !$0.isUrgent }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if storesWithItems.isEmpty {
                    ContentUnavailableView(
                        "Alles erledigt",
                        systemImage: "checkmark.circle",
                        description: Text("Keine offenen Artikel in deinen Listen.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    if !allUrgentItems.isEmpty {
                        Section {
                            ForEach(allUrgentItems, id: \.item.id) { entry in
                                itemRow(entry.item, storeColor: entry.store.color, storeEmoji: entry.store.emoji)
                            }
                        } header: {
                            Label("Dringend", systemImage: "exclamationmark.circle.fill")
                                .foregroundStyle(.orange)
                                .font(.system(size: 12, weight: .semibold))
                                .textCase(nil)
                        }
                    }

                    ForEach(storesWithNonUrgentItems) { store in
                        Section {
                            ForEach(store.pendingItems.filter { !$0.isUrgent }) { item in
                                itemRow(item, storeColor: store.color, storeEmoji: nil)
                            }
                        } header: {
                            HStack(spacing: 6) {
                                Text(store.emoji)
                                Text(store.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(store.color)
                                Spacer()
                                Text("\(store.pendingItems.filter { !$0.isUrgent }.count) Artikel")
                                    .font(.system(size: 11))
                                    .foregroundStyle(store.color.opacity(0.7))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Alle Artikel (\(totalPending))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
