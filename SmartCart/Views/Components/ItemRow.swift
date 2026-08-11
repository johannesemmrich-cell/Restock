import SwiftUI

struct ItemRow: View {
    let item: ShoppingItem
    var onToggle: () -> Void

    @State private var isAnimating = false

    private var addedByLabel: String? {
        guard item.store?.shareID != nil, !item.addedBy.isEmpty else { return nil }
        if item.addedBy == UserIdentity.displayName {
            return String(localized: "item.addedby.you")
        }
        return String(format: String(localized: "item.addedby.format"), item.addedBy)
    }

    /// "✓ von <Name>" for completed items in shared lists. Reuses the addedBy strings
    /// ("von dir" / "von %@") so no new localization keys are needed. Takes the place of the
    /// addedBy label, which is already hidden once an item is completed — for a checked-off
    /// item, who completed it matters more than who added it.
    private var completedByLabel: String? {
        guard item.store?.shareID != nil, item.isCompleted, !item.completedBy.isEmpty else { return nil }
        if item.completedBy == UserIdentity.displayName {
            return "✓ " + String(localized: "item.addedby.you")
        }
        return "✓ " + String(format: String(localized: "item.addedby.format"), item.completedBy)
    }

    /// Mirrors the grouping logic in `HomeView`/`AllItemsView`: a manually-set category sticks,
    /// otherwise re-derive from the current name so this caption never shows a stale category
    /// left over from before a keyword-rule update.
    private var displayCategory: String {
        item.categoryManuallySet ? item.category : AssignmentService.category(for: item.name)
    }

    var body: some View {
        HStack(spacing: 14) {
            Button(action: {
                onToggle()
                if !item.isCompleted { isAnimating = true }
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(item.isCompleted ? Color.accent : Color.clear)
                        .frame(width: 22, height: 22)
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(item.isCompleted ? Color.accent : Color.hairlineStrong, lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if item.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.canvas)
                    }
                }
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isAnimating)
                .onChange(of: isAnimating) { _, val in
                    if val { DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { isAnimating = false } }
                }
            }
            .buttonStyle(.pressable)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if item.isUrgent && !item.isCompleted {
                        Image(systemName: "exclamationmark")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.orange, in: RoundedRectangle(cornerRadius: RCRadius.tag))
                    }
                    Text(item.name)
                        .font(.system(size: 16))
                        .foregroundStyle(item.isCompleted ? .tertiary : .primary)
                        .strikethrough(item.isCompleted, color: Color(.tertiaryLabel))
                    if item.hasPhoto {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 6) {
                    if item.quantity != "1" || !item.unit.isEmpty {
                        Text("\(item.quantity)\(item.unit.isEmpty ? "" : " \(item.unit)")")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    if !displayCategory.isEmpty {
                        Text("·")
                            .font(.system(size: 12))
                            .foregroundStyle(.quaternary)
                        Text(displayCategory)
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    if !item.assignedTo.isEmpty && !item.isCompleted {
                        Text("·")
                            .font(.system(size: 12))
                            .foregroundStyle(.quaternary)
                        HStack(spacing: 3) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 9))
                            Text(item.assignedTo)
                                .lineLimit(1)
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(.indigo.opacity(0.85))
                    }
                    if let addedByLabel, !item.isCompleted {
                        Text("·")
                            .font(.system(size: 12))
                            .foregroundStyle(.quaternary)
                        Text(addedByLabel)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    if let completedByLabel {
                        Text("·")
                            .font(.system(size: 12))
                            .foregroundStyle(.quaternary)
                        Text(completedByLabel)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Bei offenen Artikeln immer die Schätzung zeigen (hilft beim Budgetieren). Bei
            // bereits abgehakten Artikeln dagegen nur einen ECHTEN Preis (Kassenbon-Rückschreibung
            // oder manuelle Eingabe, estimatedPriceIsAutoDerived == false) — eine reine Schätzung
            // ist für einen schon gekauften Artikel nicht hilfreich, aber ein per Bon bestätigter
            // Preis soll sichtbar sein (sonst gibt es für das Kassenbon-Rückschreiben aus
            // ReceiptScannerView.save() keinerlei sichtbare Bestätigung).
            if let price = item.estimatedLineTotal, !item.isCompleted || !item.estimatedPriceIsAutoDerived {
                Text(price, format: .currency(code: Locale.current.currency?.identifier ?? "EUR"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.25), value: item.isCompleted)
    }
}
