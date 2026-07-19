import SwiftUI
import SwiftData

// MARK: - Selectable line model

/// One checked-off item being considered for the manually-entered total, mirroring
/// `EditableReceiptLine.isIncluded` from `ReceiptScannerView` so the include/exclude UX feels
/// consistent between the OCR and manual-entry price-learning flows.
private struct SelectablePriceItem: Identifiable {
    let item: ShoppingItem
    var isIncluded = true
    var id: UUID { item.id }
}

// MARK: - Main View

/// Lets the user teach the app real prices without scanning a receipt: after checking off items,
/// they enter the TOTAL they actually paid for a subset of those items, and the app distributes
/// the difference vs. the estimated total proportionally, updating `Store.learnedPrices` and
/// backfilling `PurchaseRecord.actualPrice` — the same two effects `ReceiptScannerView.save()`
/// produces from OCR, just driven by manual entry instead.
struct ActualPriceEntryView: View {
    @Bindable var store: Store

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var lines: [SelectablePriceItem]
    @State private var paidText: String = ""

    init(store: Store) {
        self.store = store
        _lines = State(initialValue: store.completedItems.map { SelectablePriceItem(item: $0) })
    }

    private var selectedLines: [SelectablePriceItem] {
        lines.filter(\.isIncluded)
    }

    private var estimatedSelectedTotal: Double {
        selectedLines.compactMap { $0.item.estimatedLineTotal }.reduce(0, +)
    }

    private var paidTotal: Double? {
        let raw = paidText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard let value = Double(raw), value > 0 else { return nil }
        return value
    }

    private var canSave: Bool {
        paidTotal != nil && !selectedLines.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                if lines.isEmpty {
                    ContentUnavailableView(
                        "Keine erledigten Artikel",
                        systemImage: "checkmark.circle",
                        description: Text("Hake zuerst Artikel ab, um dafür einen bezahlten Preis einzutragen.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach($lines) { $line in
                            PriceEntryLineRow(line: $line)
                        }
                    } header: {
                        Text("Erledigte Artikel")
                    } footer: {
                        Text("Wähle aus, welche Artikel im bezahlten Gesamtbetrag enthalten sind.")
                    }

                    Section {
                        HStack {
                            Text("Geschätzt (ausgewählt)")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(estimatedSelectedTotal, format: .currency(code: Locale.current.currency?.identifier ?? "EUR"))
                                .fontWeight(.semibold)
                        }
                    }

                    Section {
                        HStack {
                            Image(systemName: "eurosign.circle")
                                .foregroundStyle(.secondary)
                            TextField("0,00", text: $paidText)
                                .keyboardType(.decimalPad)
                        }
                    } header: {
                        Text("Tatsächlich bezahlt")
                    } footer: {
                        Text("Der Gesamtbetrag, den du für die ausgewählten Artikel tatsächlich bezahlt hast. Die Differenz zur Schätzung wird anteilig auf die Artikel verteilt und für zukünftige Schätzungen gelernt.")
                    }
                }
            }
            .navigationTitle("Preis eintragen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ChipToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("Abbrechen").toolbarChip(prominent: false) }
                        .buttonStyle(.pressable)
}
                ChipToolbarItem(placement: .confirmationAction) {
                    Button { save() } label: { Text("Speichern").toolbarChip(prominent: true) }
                        .buttonStyle(.pressable)
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
        .devFeedback(context: "Preis eintragen")
}

    // MARK: - Logic

    private func save() {
        guard let paidTotal else { return }
        let selected = selectedLines.map(\.item)
        guard !selected.isEmpty else { return }

        // Only items with a usable per-unit estimate can receive a fair proportional share of the
        // entered total. Items with no estimate at all (estimatedLineTotal == nil) are excluded from
        // that distribution — there's no basis for "this item's fair share" without one.
        let withEstimate = selected.filter { $0.estimatedLineTotal != nil }
        let estimatedTotal = withEstimate.compactMap { $0.estimatedLineTotal }.reduce(0, +)

        if estimatedTotal > 0 {
            let ratio = paidTotal / estimatedTotal
            for item in withEstimate {
                guard let lineTotal = item.estimatedLineTotal else { continue }
                let itemActualTotal = lineTotal * ratio
                apply(itemActualTotal: itemActualTotal, to: item)
            }
        } else {
            // Nothing selected has a usable estimate (or every estimate is zero) — there's no
            // proportional basis at all, so fall back to splitting the entered total evenly
            // across every selected item rather than doing nothing.
            let share = paidTotal / Double(selected.count)
            for item in selected {
                apply(itemActualTotal: share, to: item)
            }
        }

        Haptics.success()
        dismiss()
    }

    /// Writes one item's proportional share of the entered total into `store.learnedPrices`
    /// (per-unit, matching `ReceiptScannerView.save()`'s convention) and backfills the
    /// `PurchaseRecord` created by this item's own most recent still-unpriced `markCompleted()` call.
    private func apply(itemActualTotal: Double, to item: ShoppingItem) {
        // A zero-or-negative share (possible if an item's own estimate was exactly 0, or from
        // floating-point noise) must not be taught back as "this item costs €0" — skip it entirely
        // rather than silently poisoning future estimates for that product.
        guard itemActualTotal > 0 else { return }

        let key = item.name.lowercased()
        store.learnedPrices[key] = item.quantityAmount > 0 ? itemActualTotal / item.quantityAmount : itemActualTotal

        // `purchaseRecords` only ever grows (a new record is appended on every markCompleted(), and
        // nothing prunes old ones) — an item toggled complete/pending/complete again, or simply left
        // unchecked-off across several trips, can carry multiple records. Prefer the most recent one
        // that hasn't already been priced (by a previous receipt scan or price entry) so this can
        // never silently overwrite an earlier, already-recorded purchase; if every record already
        // has a price, don't guess — leave them as they are.
        if let record = item.purchaseRecords.filter({ $0.actualPrice == nil }).max(by: { $0.date < $1.date }) {
            record.actualPrice = itemActualTotal
        }
    }
}

// MARK: - Price Entry Line Row

private struct PriceEntryLineRow: View {
    @Binding var line: SelectablePriceItem

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: $line.isIncluded)
                .labelsHidden()

            VStack(alignment: .leading, spacing: 1) {
                Text(line.item.name)
                    .font(.system(size: 15))
                // Completed items never age out of this list on their own (Store.completedItems
                // has no recency filter), so an item finished days ago from an unrelated trip could
                // otherwise sit here silently pre-selected — show when it was checked off so a stale
                // one is easy to spot and deselect before it distorts the proportional split below.
                if let completedDate = line.item.completedDate {
                    Text(completedDate, format: .relative(presentation: .named))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .opacity(line.isIncluded ? 1 : 0.4)

            Spacer()

            if let lineTotal = line.item.estimatedLineTotal {
                Text(lineTotal, format: .currency(code: Locale.current.currency?.identifier ?? "EUR"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .opacity(line.isIncluded ? 1 : 0.4)
            } else {
                Text("—")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .opacity(line.isIncluded ? 1 : 0.4)
            }
        }
    }
}
