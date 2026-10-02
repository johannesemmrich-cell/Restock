import SwiftUI
import SwiftData

// Schnell-Eingabe auf der Startseite: Ziel-Zeile mit Grund (2A), Karte „Ohne Laden“ (3A) und
// Zuordnen-Sheet (3B). Design: Canvas „Schnell hinzufügen – Vorschläge“ (2026-10-02).

// MARK: - 2A · Ziel-Zeile mit Grund

/// Zeigt unter dem Schnell-Eingabe-Feld, WOHIN der Artikel geht und WARUM — und lässt den Laden
/// vor dem Hinzufügen per Chip überschreiben.
struct QuickAddTargetCard: View {
    let parsed: QuickAddResult
    let store: Store?
    let reason: AssignmentReason
    let stores: [Store]
    /// `nil` = ausdrücklich „Ohne Laden“.
    let onChoose: (Store?) -> Void

    private var hasQuantity: Bool { parsed.quantityAmount != 1 || !parsed.unit.isEmpty }

    private var quantityText: String {
        parsed.unit.isEmpty
            ? "\(parsed.quantity)×"
            : (parsed.quantityAmount != 1 ? "\(parsed.quantity) \(parsed.unit)" : parsed.unit)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if hasQuantity {
                    Text(quantityText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .overlay(RoundedRectangle(cornerRadius: RCRadius.tag).strokeBorder(Color.accent.opacity(0.4)))
                }
                Text(parsed.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(store?.color ?? Color.warning)
                        .frame(width: 34, height: 34)
                    if let store {
                        Text(store.emoji).font(.system(size: 16))
                    } else {
                        Image(systemName: "tray")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(store == nil ? "Noch kein Laden" : "Kommt auf die Liste von")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                    Text(store?.name ?? "Landet unter „Ohne Laden“")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("quickAdd.target")

            Text(reason.explanation)
                .font(.system(size: 12))
                .foregroundStyle(store == nil ? Color.warning : Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("quickAdd.reason")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(stores) { candidate in
                        chip(title: "\(candidate.emoji) \(candidate.name)",
                             selected: store?.id == candidate.id,
                             tint: candidate.color,
                             dashed: false) { onChoose(candidate) }
                            .accessibilityIdentifier("quickAdd.storeChip.\(candidate.name)")
                    }
                    chip(title: "Ohne Laden", selected: store == nil, tint: Color.warning, dashed: true) { onChoose(nil) }
                        .accessibilityIdentifier("quickAdd.storeChip.none")
                }
            }
        }
        .padding(12)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: RCRadius.card))
        .overlay(RoundedRectangle(cornerRadius: RCRadius.card).strokeBorder(Color.hairline))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("quickAdd.targetCard")
    }

    private func chip(title: String, selected: Bool, tint: Color, dashed: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.impact(.light)
            action()
        } label: {
            Text(title)
                .font(.system(size: 14, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? Color.white : Color.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? tint : Color.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.hairline, style: StrokeStyle(lineWidth: 1, dash: dashed && !selected ? [4, 3] : [])))
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

// MARK: - 2B · Bestätigung nach dem Hinzufügen

/// Toast nach dem Schnell-Hinzufügen: nennt Artikel und Laden und bietet „Laden ändern“ und
/// „Rückgängig“ als echte Knöpfe an (statt Tippen auf einen zwei Sekunden sichtbaren Text).
struct QuickAddConfirmationToast: View {
    let message: String
    let storeColor: Color?
    let changeTitle: String
    let onChange: () -> Void
    let onUndo: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(storeColor ?? Color.warning)
                    .frame(width: 10, height: 10)
                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .accessibilityIdentifier("quickAdd.toast.message")
                Spacer(minLength: 0)
            }
            if onUndo != nil || !changeTitle.isEmpty {
                HStack(spacing: 10) {
                    if !changeTitle.isEmpty {
                        button(changeTitle, id: "quickAdd.toast.change", action: onChange)
                    }
                    if let onUndo {
                        button("Rückgängig", id: "quickAdd.toast.undo", action: onUndo)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("quickAdd.toast")
    }

    private func button(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.impact(.light)
            action()
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}

// MARK: - 3A · Karte „Ohne Laden“

/// Auffällige Karte auf der Startseite, solange Artikel ohne Laden offen sind. Verschwindet von
/// selbst, sobald keiner mehr übrig ist (der Aufrufer zeigt sie nur bei nicht-leerer Liste).
struct UnassignedItemsCard: View {
    let items: [ShoppingItem]
    let onTap: () -> Void

    private var preview: String {
        let names = items.prefix(3).map(\.name).joined(separator: ", ")
        return items.count > 3 ? names + " …" : names
    }

    var body: some View {
        Button {
            Haptics.impact(.light)
            onTap()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.warning)
                        .frame(width: 40, height: 40)
                    Image(systemName: "tray")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(items.count) Artikel ohne Laden")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.ink)
                    Text(preview)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text("Zuordnen ›")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.warning)
            }
            .padding(14)
            .background(Color.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: RCRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: RCRadius.card)
                    .strokeBorder(Color.warning, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            )
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("home.unassignedCard")
    }
}

// MARK: - 3B · Zuordnen-Sheet

/// Ordnet alle offenen Artikel ohne Laden zu: pro Artikel ein Vorschlag mit Grund, ein Tipp auf
/// einen Laden ordnet zu (und merkt sich die Wahl), „Alle Vorschläge übernehmen“ erledigt den Rest.
struct UnassignedItemsSheet: View {
    @Query(filter: #Predicate<ShoppingItem> { !$0.isCompleted && $0.store == nil })
    private var items: [ShoppingItem]
    @Query(filter: #Predicate<Store> { $0.isActive }, sort: \Store.sortIndex) private var stores: [Store]
    @Query private var records: [PurchaseRecord]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// Öffnet das Anlegen eines neuen Ladens (nach dem Schließen dieses Sheets).
    let onNewStore: () -> Void

    private func suggestion(for item: ShoppingItem) -> (store: Store?, reason: AssignmentReason) {
        AssignmentService.assignDetailed(itemName: item.name, to: stores, purchaseRecords: records)
    }

    private var proposals: [(item: ShoppingItem, store: Store)] {
        items.compactMap { item in
            suggestion(for: item).store.map { (item, $0) }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tippe auf einen Laden. Restock merkt sich deine Wahl für das nächste Mal.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                    ForEach(items) { item in
                        row(item)
                    }
                }
                .padding(16)
            }
            .background(Color.canvas)
            .navigationTitle("Artikel zuordnen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .accessibilityIdentifier("unassigned.done")
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !proposals.isEmpty {
                    Button {
                        for proposal in proposals { assign(proposal.item, to: proposal.store, remember: false) }
                    } label: {
                        Text("Alle Vorschläge übernehmen (\(proposals.count))")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.restockPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.canvas)
                    .accessibilityIdentifier("unassigned.acceptAll")
                }
            }
            .onChange(of: items.count) { _, count in
                if count == 0 { dismiss() }
            }
        }
        .devFeedback(context: "Artikel zuordnen")
    }

    private func row(_ item: ShoppingItem) -> some View {
        let result = suggestion(for: item)
        return VStack(alignment: .leading, spacing: 10) {
            Text(item.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.ink)
            if let suggested = result.store {
                Text("Vorschlag: \(suggested.name). \(result.reason.explanation)")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            } else {
                Text("Kein Vorschlag. \(result.reason.explanation)")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.warning)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(stores) { candidate in
                        let isSuggestion = result.store?.id == candidate.id
                        Button {
                            Haptics.impact(.light)
                            assign(item, to: candidate, remember: true)
                        } label: {
                            Text("\(candidate.emoji) \(candidate.name)")
                                .font(.system(size: 14, weight: isSuggestion ? .semibold : .regular))
                                .foregroundStyle(isSuggestion ? Color.white : Color.ink)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(isSuggestion ? candidate.color : Color.surface, in: Capsule())
                                .overlay(Capsule().strokeBorder(Color.hairline))
                        }
                        .buttonStyle(.pressable)
                        .accessibilityIdentifier("unassigned.\(item.name).\(candidate.name)")
                    }
                    Button {
                        Haptics.impact(.light)
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { onNewStore() }
                    } label: {
                        Text("＋ Neuer Laden")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .overlay(Capsule().strokeBorder(Color.hairlineStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
        .padding(14)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: RCRadius.card))
        .overlay(RoundedRectangle(cornerRadius: RCRadius.card).strokeBorder(Color.hairline))
    }

    private func assign(_ item: ShoppingItem, to store: Store, remember: Bool) {
        store.adoptCategory(of: item, from: nil)
        item.store = store
        if remember {
            StoreAssignmentOverrideService.shared.remember(itemName: item.name, storeName: store.name)
        }
        try? context.save()
        SyncCoordinator.shared.pushInBackground(store)
        Haptics.success()
    }
}
