import SwiftUI
import SwiftData

struct AddItemView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Store> { $0.isActive }) private var activeStores: [Store]

    @State private var name = ""
    @State private var quantity = ""
    @State private var unit = ""
    @State private var selectedStore: Store?
    @State private var autoAssigned = false
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "item.name.placeholder"), text: $name)
                        .onChange(of: name) { _, newValue in
                            if !newValue.isEmpty {
                                autoAssign(name: newValue)
                            }
                        }

                    HStack {
                        QuantityStepperField(quantity: $quantity, unit: $unit)
                        Spacer()
                        TextField(String(localized: "item.unit.placeholder"), text: $unit)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    TextField(String(localized: "item.note.placeholder"), text: $note)
                        .foregroundStyle(.secondary)
                }

                Section(header: Text(String(localized: "item.store.section"))) {
                    if autoAssigned {
                        HStack {
                            Image(systemName: "wand.and.stars")
                                .foregroundStyle(.purple)
                                .font(.system(size: 13))
                            Text(String(localized: "item.store.auto"))
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                    ForEach(activeStores) { store in
                        HStack {
                            Text(store.emoji)
                            Text(store.name)
                            Spacer()
                            if selectedStore?.id == store.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedStore = store
                            autoAssigned = false
                        }
                    }
                    HStack {
                        Text("–")
                        Text(String(localized: "item.store.none"))
                        Spacer()
                        if selectedStore == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedStore = nil
                        autoAssigned = false
                    }
                }
            }
            .navigationTitle(String(localized: "item.add.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.add")) { addItem() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                }
            }
        }
        .devFeedback(context: "Artikel hinzufügen")
    }

    private func autoAssign(name: String) {
        let store = AssignmentService.assign(itemName: name, to: activeStores)
        if store != nil {
            selectedStore = store
            autoAssigned = true
        }
    }

    private func addItem() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let category = AssignmentService.category(for: trimmedName)
        let qtyAmount = Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 1
        let item = ShoppingItem(
            name: trimmedName,
            category: category,
            quantity: quantity.isEmpty ? "1" : quantity,
            quantityAmount: qtyAmount,
            unit: unit,
            note: note,
            store: selectedStore
        )
        context.insert(item)
        dismiss()
    }
}
