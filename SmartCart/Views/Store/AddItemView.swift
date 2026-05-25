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
    @State private var showScanner = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField(String(localized: "item.name.placeholder"), text: $name)
                            .onChange(of: name) { _, newValue in
                                if !newValue.isEmpty { autoAssign(name: newValue) }
                            }
                        Button {
                            showScanner = true
                        } label: {
                            Image(systemName: "barcode.viewfinder")
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 6) {
                        QuantityStepperField(quantity: $quantity, unit: $unit)
                            .fixedSize()
                        TextField(String(localized: "item.unit.placeholder"), text: $unit)
                            .multilineTextAlignment(.center)
                            .frame(width: 72)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
                        Spacer()
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
        .sheet(isPresented: $showScanner) {
            BarcodeScannerSheet { _, productName in
                if let productName {
                    name = productName
                    autoAssign(name: productName)
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
        let rawQty = Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 1
        let qtyAmount = (rawQty > 0 && !rawQty.isNaN) ? rawQty : 1
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
