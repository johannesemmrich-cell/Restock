import SwiftUI
import SwiftData

struct AddItemView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Store> { $0.isActive }) private var activeStores: [Store]
    @Query private var allRecords: [PurchaseRecord]

    @State private var name = ""
    @State private var quantity = ""
    @State private var unit = ""
    @State private var selectedStore: Store?
    @State private var autoAssigned = false
    @State private var note = ""
    @State private var showScanner = false
    @FocusState private var isNameFocused: Bool

    private var duplicateWarning: String? {
        guard let store = selectedStore, !name.isEmpty else { return nil }
        let nameLower = name.lowercased()
        guard nameLower.count >= 3 else { return nil }
        let match = store.pendingItems.first { item in
            let n = item.name.lowercased()
            return n == nameLower || (n.count >= 3 && (n.contains(nameLower) || nameLower.contains(n)))
        }
        return match.map { "'\($0.name)' ist bereits in der Liste" }
    }

    private var nameSuggestions: [String] {
        QuickAddParser.knownProductSuggestions(for: name, in: allRecords, itemNames: activeStores.flatMap { $0.items ?? [] }.map(\.name))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField(String(localized: "item.name.placeholder"), text: $name)
                            .focused($isNameFocused)
                            .onChange(of: name) { _, newValue in
                                if !newValue.isEmpty { autoAssign(name: newValue) }
                            }
                        Button {
                            showScanner = true
                        } label: {
                            Image(systemName: "barcode.viewfinder")
                                .foregroundStyle(Color.accent)
                        }
                        .buttonStyle(.pressable)
                    }

                    if isNameFocused {
                        ProductSuggestionChips(suggestions: nameSuggestions, tint: Color.accent) { picked in
                            name = picked
                        }
                    }

                    HStack(spacing: 6) {
                        QuantityStepperField(quantity: $quantity, unit: $unit)
                            .fixedSize()
                        TextField(String(localized: "item.unit.placeholder"), text: $unit)
                            .multilineTextAlignment(.center)
                            .frame(width: 72)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.surface, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.hairline))
                        Spacer()
                    }

                    TextField(String(localized: "item.note.placeholder"), text: $note)
                        .foregroundStyle(.secondary)
                }

                if let warning = duplicateWarning {
                    Section {
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.orange)
                    }
                    .listRowBackground(Color.orange.opacity(0.08))
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
                                    .foregroundStyle(Color.accent)
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
                                .foregroundStyle(Color.accent)
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
                ChipToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text(String(localized: "action.cancel")).toolbarChip() }
                        .buttonStyle(.pressable)
                }
                ChipToolbarItem(placement: .confirmationAction) {
                    Button { addItem() } label: { Text(String(localized: "action.add")).toolbarChip(prominent: true) }
                        .buttonStyle(.pressable)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
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
        applySuggestedQuantity(for: name)
    }

    private func applySuggestedQuantity(for name: String) {
        guard quantity.isEmpty else { return }
        let nameLower = name.lowercased()
        guard nameLower.count >= 3 else { return }
        let matching = allRecords.filter { record in
            let rn = record.itemName.lowercased()
            return rn == nameLower || (rn.count >= 3 && (rn.contains(nameLower) || nameLower.contains(rn)))
        }
        guard !matching.isEmpty else { return }
        let recent = Array(matching.sorted { $0.date > $1.date }.prefix(5))
        let avgAmount = recent.map { $0.quantityAmount }.reduce(0, +) / Double(recent.count)
        guard avgAmount > 0, !(avgAmount == 1 && recent.allSatisfy { $0.unit.isEmpty }) else { return }
        let lastUnit = recent.compactMap { $0.unit.isEmpty ? nil : $0.unit }.first ?? ""
        let qtyStr = avgAmount == Double(Int(avgAmount)) ? "\(Int(avgAmount))" : String(format: "%.1f", avgAmount)
        quantity = qtyStr
        if !lastUnit.isEmpty && unit.isEmpty { unit = lastUnit }
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
        SyncCoordinator.shared.pushInBackground(selectedStore)
        dismiss()
    }
}
