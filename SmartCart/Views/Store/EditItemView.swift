import SwiftUI
import SwiftData

struct EditItemView: View {
    @Bindable var item: ShoppingItem
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Store> { $0.isActive }) private var activeStores: [Store]

    @State private var name: String
    @State private var quantity: String
    @State private var unit: String
    @State private var note: String
    @State private var selectedStore: Store?
    @State private var showDeleteConfirm = false

    init(item: ShoppingItem) {
        self.item = item
        _name = State(initialValue: item.name)
        _quantity = State(initialValue: item.quantity)
        _unit = State(initialValue: item.unit)
        _note = State(initialValue: item.note)
        _selectedStore = State(initialValue: item.store)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "item.details.section")) {
                    HStack {
                        Image(systemName: "tag")
                            .foregroundStyle(.secondary)
                        TextField(String(localized: "item.name.placeholder"), text: $name)
                    }

                    HStack {
                        Image(systemName: "number")
                            .foregroundStyle(.secondary)
                        TextField(String(localized: "item.quantity.placeholder"), text: $quantity)
                            .keyboardType(.decimalPad)
                            .frame(width: 70)
                        Divider().frame(height: 20)
                        TextField(String(localized: "item.unit.placeholder"), text: $unit)
                    }

                    HStack {
                        Image(systemName: "note.text")
                            .foregroundStyle(.secondary)
                        TextField(String(localized: "item.note.placeholder"), text: $note)
                    }
                }

                Section(String(localized: "item.store.section")) {
                    ForEach(activeStores) { store in
                        HStack {
                            Text(store.emoji)
                            Text(store.name)
                            Spacer()
                            if selectedStore?.id == store.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(store.color)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectedStore = store }
                    }
                    HStack {
                        Text("–")
                        Text(String(localized: "item.store.none"))
                        Spacer()
                        if selectedStore == nil {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selectedStore = nil }
                }

                Section {
                    Button {
                        withAnimation {
                            if item.isCompleted { item.markPending() } else { item.markCompleted() }
                        }
                        Haptics.success()
                        dismiss()
                    } label: {
                        Label(
                            item.isCompleted
                                ? String(localized: "item.action.uncheck")
                                : String(localized: "item.action.check"),
                            systemImage: item.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle"
                        )
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label(String(localized: "item.action.delete"), systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(String(localized: "item.edit.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.save")) {
                        save()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog(
                String(localized: "item.delete.confirm"),
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button(String(localized: "item.action.delete"), role: .destructive) {
                    context.delete(item)
                    dismiss()
                }
            }
        }
    }

    private func save() {
        item.name = name.trimmingCharacters(in: .whitespaces)
        item.quantity = quantity.isEmpty ? "1" : quantity
        item.quantityAmount = Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 1
        item.unit = unit
        item.note = note
        item.store = selectedStore
        item.estimatedPrice = PriceEstimator.estimate(for: item.name, category: item.category)
        Haptics.success()
        dismiss()
    }
}
