import SwiftUI

/// Kategorie wählen oder anlegen (Issue #85, Entwurf Variante C „Suchen oder anlegen“).
///
/// Oben stehen die eigenen Kategorien des Ladens („Bei Lidl“), darunter alle festen. Findet die
/// Suche keine passende Kategorie, bietet die erste Zeile an, sie in diesem Laden anzulegen. Ohne
/// Laden (Artikel noch keinem Laden zugeordnet) gibt es nur die festen Kategorien.
struct CategoryPickerView: View {
    let store: Store?
    @Binding var selection: String
    /// Kategorie, die der Artikel ohne eigene Wahl bekäme — Rückfall, wenn die gewählte eigene
    /// Kategorie hier gelöscht wird.
    let automaticCategory: String
    /// Artikelname für die Auswahl nach dem Löschen eines Gangs (Durchgang 2b-2).
    var itemName: String = ""
    /// Nachziehen nach Umbenennen/Löschen eines Gangs, ohne die Wahl als Nutzerwahl zu markieren (F002).
    var onFollow: ((String) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var editingCategory: EditTarget?
    @State private var deletingCategory: String?
    @State private var editingStation: EditTarget?
    @State private var deletingStation: String?

    private struct EditTarget: Identifiable {
        let name: String
        /// Auswahl beim Öffnen (Gang-Modus), für `renamedSelection`.
        var selected = ""
        var id: String { name }
    }

    private var customCategories: [String] {
        (store?.customCategories ?? []).filter { StoreCategories.matches($0, query: query) }
    }

    /// Feste Kategorien alphabetisch nach Anzeigename; eine gewählte Alt-Kategorie, die weder fest
    /// noch eigene ist, steht mit drin, damit die Auswahl nie ins Leere zeigt.
    private var builtInCategories: [String] {
        var categories = AssignmentService.categoryOrder
        if !selection.isEmpty, !categories.contains(selection), store?.isCustomCategory(selection) != true {
            categories.append(selection)
        }
        return categories
            .filter { StoreCategories.matches($0, query: query) || StoreCategories.matches(AssignmentService.displayCategory($0), query: query) }
            .sorted { AssignmentService.displayCategory($0).localizedStandardCompare(AssignmentService.displayCategory($1)) == .orderedAscending }
    }

    /// Name, der angelegt würde — nur wenn die Suche keine vorhandene Kategorie genau trifft.
    private var creatableName: String? {
        guard let store, case .new(let name) = store.resolveCategory(query) else { return nil }
        return name
    }

    /// Eigenes Suchfeld statt `.searchable`: das System-Suchfeld blockierte im Test das
    /// Zurückgehen zum Artikel-Dialog nach dem Anlegen.
    private var searchSection: some View {
        Section {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(
                    store == nil ? String(localized: "category.picker.search.only") : String(localized: "category.picker.search"),
                    text: $query
                )
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .accessibilityIdentifier("categoryPicker.search")
            }
        }
        .listRowBackground(Color.surface)
    }

    var body: some View {
        List {
            searchSection

            if let store, let config = store.stationConfig, store.hasStations {
                stationSections(store, config: config)
            } else {
                categorySections
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.canvas)
        .navigationTitle(String(localized: "item.category.section"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingCategory) { target in
            if let store {
                CustomCategoryEditor(store: store, name: target.name) { newName in
                    if selection == target.name { selection = newName }
                }
            }
        }
        .sheet(item: $editingStation) { target in
            if let store {
                CustomCategoryEditor(store: store, name: target.name, isStation: true) { newName in
                    let next = StoreCategories.renamedSelection(target.selected, from: target.name, to: newName)
                    if next != target.selected { follow(next) }
                }
            }
        }
        .modifier(stationDeleteDialog)
        .confirmationDialog(
            String(format: String(localized: "category.picker.delete.confirm"), deletingCategory ?? ""),
            isPresented: Binding(get: { deletingCategory != nil }, set: { if !$0 { deletingCategory = nil } }),
            titleVisibility: .visible
        ) {
            Button(String(localized: "action.delete"), role: .destructive) {
                guard let category = deletingCategory, let store else { return }
                store.deleteCustomCategory(category)
                if selection == category { selection = automaticCategory }
                deletingCategory = nil
                Haptics.impact(.medium)
            }
        } message: {
            Text(String(localized: "category.picker.delete.message"))
        }
        .devFeedback(context: "Kategorie wählen")
    }

    /// Issue #234: Läden mit Gängen zeigen nur ihre Gänge in Laden-Reihenfolge und „Sonstiges“.
    /// `selection` ist hier der Gang-Name bzw. die Sonstiges-Marke.
    @ViewBuilder
    private func stationSections(_ store: Store, config: StationConfig) -> some View {
        if case .new(let name) = StoreCategories.resolveStation(query, config: config) {
            Section {
                createButton(String(format: String(localized: "station.picker.create"), name, store.name), hint: nil) {
                    if let created = store.addStation(name) { choose(created) }
                }
            }
            .listRowBackground(Color.surface)
        }
        Section(String(format: String(localized: "station.picker.section"), store.name)) {
            ForEach(config.stations.filter { StoreCategories.matches($0.name, query: query) }, id: \.name) { station in
                row(station.name, emoji: station.emoji, title: station.name,
                    subtitle: countText(store.pendingCount(inStation: station.name)))
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deletingStation = station.name
                        } label: {
                            Label(String(localized: "action.delete"), systemImage: "trash")
                        }
                        .accessibilityIdentifier("categoryPicker.station.delete.\(station.name)")
                        Button {
                            editingStation = EditTarget(name: station.name, selected: selection)
                        } label: {
                            Label(String(localized: "action.edit"), systemImage: "pencil")
                        }
                        .tint(.indigo)
                        .accessibilityIdentifier("categoryPicker.station.edit.\(station.name)")
                    }
            }
            let other = String(localized: "station.other")
            if StoreCategories.matches(other, query: query) {
                row(StoreCategories.otherStationMarker, emoji: "", title: other,
                    subtitle: countText(store.pendingCount(inStation: nil)), identifier: "categoryPicker.row.other")
            }
        }
        .listRowBackground(Color.surface)
    }

    @ViewBuilder
    private var categorySections: some View {
            if let store, let name = creatableName {
                Section {
                    createButton(String(format: String(localized: "category.picker.create"), name, store.name),
                                 hint: String(format: String(localized: "category.picker.create.hint"),
                                              StoreCategories.suggestedEmoji(for: name))) {
                        if let created = store.addCustomCategory(name) {
                            choose(created)
                        }
                    }
                }
                .listRowBackground(Color.surface)
            }

            if let store, !customCategories.isEmpty {
                Section(String(format: String(localized: "category.picker.store.section"), store.name)) {
                    ForEach(customCategories, id: \.self) { category in
                        row(category, emoji: store.categoryEmoji(category), title: category,
                            subtitle: countText(store.pendingCount(inCategory: category)))
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deletingCategory = category
                                } label: {
                                    Label(String(localized: "action.delete"), systemImage: "trash")
                                }
                                Button {
                                    editingCategory = EditTarget(name: category)
                                } label: {
                                    Label(String(localized: "action.edit"), systemImage: "pencil")
                                }
                                .tint(.indigo)
                            }
                    }
                }
                .listRowBackground(Color.surface)
            }

            if !builtInCategories.isEmpty {
                Section(String(localized: "category.picker.all")) {
                    ForEach(builtInCategories, id: \.self) { category in
                        row(category, emoji: AssignmentService.categoryEmoji(category),
                            title: AssignmentService.displayCategory(category), subtitle: nil)
                    }
                }
                .listRowBackground(Color.surface)
            }
    }

    /// Erste Zeile „… anlegen“, wenn die Suche nichts genau trifft.
    private func createButton(_ title: String, hint: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Color.accent)
                    .font(.system(size: 20))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(Color.accent)
                    if let hint {
                        Text(hint)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .accessibilityIdentifier("categoryPicker.create")
    }

    private func row(_ category: String, emoji: String, title: String, subtitle: String?,
                     identifier: String? = nil) -> some View {
        Button {
            choose(category)
        } label: {
            HStack(spacing: 12) {
                Text(emoji)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(Color.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if selection == category {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accent)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier(identifier ?? "categoryPicker.row.\(category)")
    }

    /// Rückfrage und Wirkung wie in „Kategorien einrichten“ (`StationSetupView.deleteDialog`/`delete`).
    private var stationDeleteDialog: StationPickerDeleteDialog {
        StationPickerDeleteDialog(store: store, pending: $deletingStation) { name in
            guard let store else { return }
            let before = selection
            let wasSelected = before != StoreCategories.otherStationMarker
                && StoreCategories.compareKey(before) == StoreCategories.compareKey(name)
            StationSetupView.delete(name, in: store)
            let config = store.hasStations ? store.stationConfig : nil
            // Ohne Gänge gilt auch die Marke nicht mehr: dann die automatische Kategorie.
            guard wasSelected || (config == nil && before == StoreCategories.otherStationMarker) else { return }
            follow(StoreCategories.selectionAfterDeleting(
                itemName: itemName, automaticCategory: automaticCategory,
                config: config ?? StationConfig(stations: [], hidden: [], date: Date())))
        }
    }

    private func follow(_ next: String) {
        if let onFollow { onFollow(next) } else { selection = next }
    }

    private func countText(_ count: Int) -> String? {
        count > 0 ? String(format: String(localized: "category.picker.count"), count) : nil
    }

    private func choose(_ category: String) {
        selection = category
        Haptics.impact(.light)
        dismiss()
    }
}

/// Name und Emoji einer eigenen Kategorie ändern.
struct CustomCategoryEditor: View {
    let store: Store
    let name: String
    /// Gang-Modus (Durchgang 2b-2): speichert über `renameStation`, Ablehnung lässt den Editor offen.
    let isStation: Bool
    let onSaved: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var newName: String
    @State private var emoji: String
    @State private var rejected = false

    init(store: Store, name: String, isStation: Bool = false, onSaved: @escaping (String) -> Void) {
        self.store = store
        self.name = name
        self.isStation = isStation
        self.onSaved = onSaved
        _newName = State(initialValue: name)
        _emoji = State(initialValue: isStation ? store.stationEmoji(name) : store.categoryEmoji(name))
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "category.editor.name")) {
                    TextField(String(localized: "category.editor.name"), text: $newName)
                        .accessibilityIdentifier("categoryEditor.name")
                        .onChange(of: newName) { rejected = false }
                    if rejected {
                        Text(String(localized: "station.setup.name.rejected"))
                            .font(.footnote)
                            .foregroundStyle(Color.destructive)
                    }
                }
                .listRowBackground(Color.surface)
                Section(String(localized: "category.editor.emoji")) {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(StoreCategories.emojiChoices, id: \.self) { choice in
                            Button {
                                emoji = choice
                                Haptics.impact(.light)
                            } label: {
                                Text(choice)
                                    .font(.system(size: 26))
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(emoji == choice ? Color.accentContainer : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(choice)
                            .accessibilityAddTraits(emoji == choice ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Color.canvas)
            .navigationTitle(String(localized: "category.editor.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.save")) { save() }
                    .disabled(StoreCategories.normalizedName(newName).isEmpty)
                }
            }
        }
        .devFeedback(context: "Kategorie bearbeiten")
    }

    private func save() {
        let result: String
        if isStation {
            guard let renamed = store.renameStation(name, to: newName, emoji: emoji) else {
                rejected = true
                return
            }
            result = renamed
        } else {
            result = store.updateCustomCategory(name, name: newName, emoji: emoji)
        }
        onSaved(result)
        Haptics.success()
        dismiss()
    }
}

/// Rückfrage „Gang löschen“ in der Auswahl; Titel, Meldung und Knopf aus `StationSetupView.deleteDialog`.
private struct StationPickerDeleteDialog: ViewModifier {
    let store: Store?
    @Binding var pending: String?
    let onConfirm: (String) -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(dialog(pending ?? "").title,
                                   isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
                                   titleVisibility: .visible, presenting: pending) { name in
            Button(dialog(name).button, role: .destructive) {
                onConfirm(name)
                pending = nil
            }
        } message: { name in
            Text(dialog(name).message)
        }
    }

    private func dialog(_ name: String) -> (title: String, message: String, button: String) {
        guard let store else { return ("", "", "") }
        return StationSetupView.deleteDialog(for: name, in: store)
    }
}
