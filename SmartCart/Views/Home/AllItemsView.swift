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

    /// Items with no assigned store — otherwise invisible in the by-store grouping, since it
    /// only ever iterates `activeStores`.
    private var noStoreItems: [ShoppingItem] {
        pendingItems.filter { !$0.isUrgent && $0.store == nil }
    }

    private var nonUrgentByCategory: [(category: String, emoji: String, items: [ShoppingItem])] {
        // Manually-set categories stick as the user chose them; everything else keeps re-deriving
        // from the current name so stale stored values and rule updates apply immediately.
        let grouped = Dictionary(grouping: pendingItems.filter { !$0.isUrgent }) {
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

    var body: some View {
        // Re-runs body whenever a sync merge lands in SwiftData, so `nonUrgentByCategory`
        // regroups immediately. The `@Query`'s predicate (`isCompleted == false`) is untouched
        // by a remote category change, so the query alone never signals one — and the section
        // derivation lives in this body, not in the rows.
        let _ = SyncCoordinator.shared.applyGeneration
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Text("Alle Artikel")
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(0.8)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.textSecondary)
                        Spacer()
                        Picker("Sortierung", selection: $groupByCategory) {
                            Text("Kategorie").tag(true)
                            Text("Laden").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                        .onChange(of: groupByCategory) { _, _ in Haptics.impact(.light) }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 6, trailing: 16))

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
                            sectionHeaderRow("Dringend", count: urgentItems.count, tint: .orange)
                            ForEach(urgentItems) { item in
                                itemRow(item, storeColor: item.store?.color ?? .gray, storeEmoji: groupByCategory ? nil : item.store?.emoji)
                            }
                        }
                        .listRowBackground(Color.surface)
                    }

                    if groupByCategory {
                        ForEach(nonUrgentByCategory, id: \.category) { group in
                            Section {
                                sectionHeaderRow(group.category, count: group.items.count)
                                ForEach(group.items) { item in
                                    itemRow(item, storeColor: .secondary, storeEmoji: nil)
                                }
                            }
                            .listRowBackground(Color.surface)
                        }
                    } else {
                        ForEach(nonUrgentByStore, id: \.store.persistentModelID) { entry in
                            Section {
                                sectionHeaderRow(entry.store.name, count: entry.items.count)
                                ForEach(entry.items) { item in
                                    itemRow(item, storeColor: entry.store.color, storeEmoji: nil)
                                }
                            }
                            .listRowBackground(Color.surface)
                        }

                        if !noStoreItems.isEmpty {
                            Section {
                                sectionHeaderRow("Ohne Laden", count: noStoreItems.count)
                                ForEach(noStoreItems) { item in
                                    itemRow(item, storeColor: .secondary, storeEmoji: nil)
                                }
                            }
                            .listRowBackground(Color.surface)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.canvas)
            .navigationTitle("Alle Artikel (\(pendingItems.count))")
            .navigationBarTitleDisplayMode(.inline)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: groupByCategory)
            .toolbar {
                ChipToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "house")
                            .fontWeight(.medium)
                            .foregroundStyle(Color.ink)
                            .toolbarChip()
                    }
                    .buttonStyle(.pressable)
                }
                ChipToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Text("Fertig").toolbarChip(prominent: true)
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
        .devFeedback(context: "Alle Artikel")
    }

    /// Kategorie-/Laden-Header als erste Zeile INNERHALB der Karte (Spec: Versalien-Label,
    /// Zähler rechts) statt als grauer System-Section-Header außerhalb.
    private func sectionHeaderRow(_ title: String, count: Int, tint: Color = Color.textSecondary) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(tint)
            Spacer()
            Text("\(count)")
                .font(.system(size: 13))
                .monospacedDigit()
                .foregroundStyle(Color.textSecondary)
        }
        .listRowSeparator(.visible)
    }

    @ViewBuilder
    private func itemRow(_ item: ShoppingItem, storeColor: Color, storeEmoji: String?) -> some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3)) { item.markCompleted() }
                Haptics.success()
                SyncCoordinator.shared.pushInBackground(item.store)
            } label: {
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Color.hairlineStrong, lineWidth: 1.5)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.pressable)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if item.isUrgent {
                        Image(systemName: "exclamationmark")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.orange, in: RoundedRectangle(cornerRadius: RCRadius.tag))
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
            Image(systemName: "cart")
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary.opacity(0.6))
        }
        .padding(.vertical, 2)
    }
}
