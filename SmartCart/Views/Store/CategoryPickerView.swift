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
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var editingCategory: EditTarget?
    @State private var deletingCategory: String?

    private struct EditTarget: Identifiable {
        let name: String
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

    var body: some View {
        List {
            if let store, let name = creatableName {
                Section {
                    Button {
                        if let created = store.addCustomCategory(name) {
                            choose(created)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.accent)
                                .font(.system(size: 20))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(format: String(localized: "category.picker.create"), name, store.name))
                                    .foregroundStyle(Color.accent)
                                Text(String(format: String(localized: "category.picker.create.hint"), StoreCategories.suggestedEmoji(for: name)))
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .accessibilityIdentifier("categoryPicker.create")
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
        .scrollContentBackground(.hidden)
        .background(Color.canvas)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: Text(store == nil ? String(localized: "category.picker.search.only") : String(localized: "category.picker.search")))
        .navigationTitle(String(localized: "item.category.section"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingCategory) { target in
            if let store {
                CustomCategoryEditor(store: store, name: target.name) { newName in
                    if selection == target.name { selection = newName }
                }
            }
        }
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

    private func row(_ category: String, emoji: String, title: String, subtitle: String?) -> some View {
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
        .accessibilityIdentifier("categoryPicker.row.\(category)")
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
    let onSaved: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var newName: String
    @State private var emoji: String

    init(store: Store, name: String, onSaved: @escaping (String) -> Void) {
        self.store = store
        self.name = name
        self.onSaved = onSaved
        _newName = State(initialValue: name)
        _emoji = State(initialValue: store.categoryEmoji(name))
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "category.editor.name")) {
                    TextField(String(localized: "category.editor.name"), text: $newName)
                        .accessibilityIdentifier("categoryEditor.name")
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
                    Button(String(localized: "action.save")) {
                        let result = store.updateCustomCategory(name, name: newName, emoji: emoji)
                        onSaved(result)
                        Haptics.success()
                        dismiss()
                    }
                    .disabled(StoreCategories.normalizedName(newName).isEmpty)
                }
            }
        }
        .devFeedback(context: "Kategorie bearbeiten")
    }
}
