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
                    ForEach(storesWithItems) { store in
                        Section {
                            ForEach(store.pendingItems) { item in
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(.system(size: 15))
                                        if !item.unit.isEmpty || item.quantityAmount != 1 {
                                            Text("\(item.quantity)\(!item.unit.isEmpty ? " \(item.unit)" : "")")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Button {
                                        withAnimation(.spring(response: 0.3)) {
                                            item.markCompleted()
                                        }
                                        Haptics.success()
                                    } label: {
                                        Image(systemName: "circle")
                                            .font(.system(size: 24))
                                            .foregroundStyle(store.color.opacity(0.5))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 2)
                            }
                        } header: {
                            HStack(spacing: 6) {
                                Text(store.emoji)
                                Text(store.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(store.color)
                                Spacer()
                                Text("\(store.pendingItems.count) Artikel")
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
}
