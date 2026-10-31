import SwiftUI
import SwiftData

// Issue #234, Durchgang 2a: „Kategorien einrichten“ (Spec `docs/specs/views/station-setup.md`).
// Übersicht (Vorlage, Gänge, offene und ausgeblendete feste Kategorien) und Gang-Detail. Die
// Ansicht ruft nur die reinen Funktionen in `StoreCategories` und die Hülle in `Store`; jede
// Änderung wird sofort gespeichert und über `onChange` an die Ladenliste gemeldet.

/// Übersicht als Sheet-Wurzel.
struct StationSetupView: View {
    let store: Store
    let onChange: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var editMode: EditMode = .inactive
    @State private var showTemplate = false
    @State private var showRemove = false
    @State private var showAdd = false
    @State private var newName = ""
    @State private var addRejected = false
    @State private var pendingDelete: String?

    /// Konfiguration nur mit mindestens einem Gang; sonst gilt der Laden als ohne Gänge.
    private var config: StationConfig? { store.hasStations ? store.stationConfig : nil }

    var body: some View {
        NavigationStack {
            // Leiste unter (nicht über) der Liste: sonst lägen die untersten Zeilen unter ihr und
            // ein Tipp auf sie träfe die Leiste.
            VStack(spacing: 0) {
                List {
                    // Mit Gängen steht „Vorlage wählen …“ im Kopf des Abschnitts „Gänge“, damit
                    // die Gang-Zeilen ohne Rollen sichtbar bleiben.
                    if config == nil { templateSection }
                    if let config {
                        stationSection(config)
                        openSection(config)
                        hiddenSection(config)
                    }
                }
                .environment(\.editMode, $editMode)
                .scrollContentBackground(.hidden)
                bottomBar
            }
            .background(Color.canvas)
            .tint(Color.accent)
            .navigationTitle(String(localized: "station.setup.title"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { name in
                StationDetailView(store: store, name: name, onChange: changed)
            }
            .toolbar { toolbarItems }
            .modifier(StationSetupDialogs(store: store, showTemplate: $showTemplate, showRemove: $showRemove,
                                          pendingDelete: $pendingDelete, onRemove: { editMode = .inactive },
                                          onChange: changed))
            .alert(String(localized: "station.setup.add"), isPresented: $showAdd) {
                TextField(String(localized: "station.setup.add.prompt"), text: $newName)
                    .accessibilityIdentifier("stationSetup.addStation.field")
                Button(String(localized: "action.add")) { addStation() }
                Button(String(localized: "action.cancel"), role: .cancel) { newName = "" }
            }
            .alert(String(localized: "station.setup.name.rejected"), isPresented: $addRejected) {
                Button(String(localized: "action.done"), role: .cancel) {}
            }
        }
        // Kein Herunterwischen: Schließen nur über „Fertig“ (Rollen nach oben schloss sonst das Sheet).
        .interactiveDismissDisabled()
        .devFeedback(context: "Kategorien einrichten")
    }

    // MARK: Abschnitte

    private var templateSection: some View {
        Section {
            templateButton
        } footer: {
            sharedHint
        }
        .listRowBackground(Color.surface)
    }

    private var templateButton: some View {
        Button(String(localized: "station.setup.template")) { showTemplate = true }
            .accessibilityIdentifier("stationSetup.template")
    }

    @ViewBuilder
    private var sharedHint: some View {
        if store.shareID != nil {
            Text(String(localized: "station.setup.shared"))
                .accessibilityIdentifier("stationSetup.sharedHint")
        }
    }

    private func stationSection(_ config: StationConfig) -> some View {
        Section {
            ForEach(config.stations, id: \.name) { station in
                NavigationLink(value: station.name) { StationSetupRow(station: station) }
                    .accessibilityIdentifier("stationSetup.row.\(station.name)")
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { pendingDelete = station.name } label: {
                            Label(String(localized: "action.delete"), systemImage: "trash")
                        }
                        .accessibilityIdentifier("stationSetup.row.delete.\(station.name)")
                    }
            }
            .onMove { from, to in
                store.updateStationConfig(StoreCategories.movingStations(from: from, to: to, in: config))
                changed()
            }
        } header: {
            HStack {
                Text(String(format: String(localized: "station.setup.section.stations"), config.stations.count))
                Spacer()
                templateButton.textCase(nil)
            }
        } footer: {
            sharedHint
        }
        .listRowBackground(Color.surface)
    }

    private func openSection(_ config: StationConfig) -> some View {
        let open = categories(in: config, state: .open)
        return Section {
            ForEach(open, id: \.self) { category in
                HStack {
                    StationCategoryLabel(category: category)
                    Spacer()
                    Menu(String(localized: "station.setup.assign")) {
                        ForEach(config.stations, id: \.name) { station in
                            Button(station.name) { apply(StoreCategories.assigning(category, toStation: station.name, in: config)) }
                        }
                        Button(String(localized: "station.setup.hide")) { apply(StoreCategories.hiding(category, in: config)) }
                    }
                    .accessibilityIdentifier("stationSetup.open.\(category)")
                }
            }
        } header: {
            Text(String(format: String(localized: "station.setup.section.open"), open.count))
        } footer: {
            Text(String(localized: "station.setup.section.open.footer"))
        }
        .listRowBackground(Color.surface)
    }

    private func hiddenSection(_ config: StationConfig) -> some View {
        let hidden = categories(in: config, state: .hidden)
        return Section {
            ForEach(hidden, id: \.self) { category in
                HStack {
                    StationCategoryLabel(category: category, struck: true)
                    Spacer()
                    Button(String(localized: "station.setup.show")) { apply(StoreCategories.opening(category, in: config)) }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("stationSetup.hidden.\(category)")
                }
            }
        } header: {
            Text(String(format: String(localized: "station.setup.section.hidden"), hidden.count))
        }
        .listRowBackground(Color.surface)
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if store.hasStations {
                Button(String(localized: "station.setup.sort")) {
                    withAnimation(.smooth) { editMode = editMode == .active ? .inactive : .active }
                    Haptics.impact(.light)
                }
                .fontWeight(editMode == .active ? .semibold : .regular)
                .accessibilityIdentifier("stationSetup.sort")
                .accessibilityAddTraits(editMode == .active ? .isSelected : [])
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(String(localized: "station.setup.done")) { dismiss() }
                .accessibilityIdentifier("stationSetup.done")
        }
    }

    /// „Gang hinzufügen“ und „Gänge entfernen“ stehen fest unten, damit sie bei 30 und mehr
    /// Zeilen ohne Rollen erreichbar bleiben.
    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button { showAdd = true } label: {
                Label(String(localized: "station.setup.add"), systemImage: "plus")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("stationSetup.addStation")
            if store.hasStations {
                Button(role: .destructive) { showRemove = true } label: {
                    Text(String(localized: "station.setup.remove"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Color.destructive)
                .accessibilityIdentifier("stationSetup.remove")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: Aktionen

    private func categories(in config: StationConfig, state: StoreCategories.CategoryState) -> [String] {
        AssignmentService.categoryOrder.filter { StoreCategories.categoryState($0, in: config) == state }
    }

    private func apply(_ next: StationConfig?) {
        guard let next else { return }
        withAnimation(.smooth) { store.updateStationConfig(next) }
        Haptics.impact(.light)
        changed()
    }

    private func addStation() {
        let base = store.stationConfig ?? StationConfig(stations: [], hidden: [], date: Date())
        let emoji = StoreCategories.suggestedEmoji(for: newName)
        if let next = StoreCategories.addingStation(newName, emoji: emoji, to: base) {
            apply(next)
        } else {
            addRejected = true
        }
        newName = ""
    }

    private func changed() {
        try? context.save()
        onChange()
    }

    /// Gang löschen; der letzte Gang entfernt die Gänge ganz (AC-11).
    static func delete(_ name: String, in store: Store) {
        if (store.stationConfig?.stations.count ?? 0) <= 1 {
            store.removeStations()
        } else {
            store.deleteStation(name)
        }
        Haptics.impact(.medium)
    }

    /// Rückfrage zum Löschen; beim letzten Gang die von „Gänge entfernen“ (AC-11).
    static func deleteDialog(for name: String, in store: Store) -> (title: String, message: String, button: String) {
        if (store.stationConfig?.stations.count ?? 0) <= 1 {
            return (String(localized: "station.remove.confirm.title"), String(localized: "station.remove.confirm.message"),
                    String(localized: "station.setup.remove"))
        }
        return (String(format: String(localized: "station.setup.delete.title"), name),
                String(localized: "station.setup.delete.message"), String(localized: "station.setup.detail.delete"))
    }
}

/// Rückfragen der Übersicht: Vorlage wählen, Gänge entfernen, Gang löschen (Wischen).
private struct StationSetupDialogs: ViewModifier {
    let store: Store
    @Binding var showTemplate: Bool
    @Binding var showRemove: Bool
    @Binding var pendingDelete: String?
    let onRemove: () -> Void
    let onChange: () -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(String(localized: "station.setup.template.title"), isPresented: $showTemplate,
                                titleVisibility: .visible) {
                Button(String(localized: "station.setup.template.lidl")) {
                    withAnimation(.smooth) { store.applyStationConfig(StoreCategories.lidlTemplate) }
                    Haptics.impact(.medium)
                    onChange()
                }
                .accessibilityIdentifier("stationSetup.templateLidl")
            } message: {
                Text(String(localized: "station.setup.template.message"))
            }
            .confirmationDialog(String(localized: "station.remove.confirm.title"), isPresented: $showRemove,
                                titleVisibility: .visible) {
                Button(String(localized: "station.setup.remove"), role: .destructive) {
                    withAnimation(.smooth) { store.removeStations() }
                    Haptics.impact(.medium)
                    onRemove()
                    onChange()
                }
                .accessibilityIdentifier("stationSetup.confirmRemove")
            } message: {
                Text(String(localized: "station.remove.confirm.message"))
            }
            .confirmationDialog(deleteTitle, isPresented: deleteBinding, titleVisibility: .visible,
                                presenting: pendingDelete) { name in
                Button(StationSetupView.deleteDialog(for: name, in: store).button, role: .destructive) {
                    withAnimation(.smooth) { StationSetupView.delete(name, in: store) }
                    onChange()
                }
                .accessibilityIdentifier("stationSetup.confirmDelete")
            } message: { name in
                Text(StationSetupView.deleteDialog(for: name, in: store).message)
            }
    }

    private var deleteTitle: String {
        StationSetupView.deleteDialog(for: pendingDelete ?? "", in: store).title
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }
}

/// Zeile eines Gangs in der Übersicht: Emoji, Name, Inhalt.
private struct StationSetupRow: View {
    let station: Station

    var body: some View {
        HStack(spacing: 12) {
            Text(station.emoji).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(station.name).foregroundStyle(Color.ink)
                Text(summary).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var summary: String {
        station.builtIns.isEmpty && station.keywords.isEmpty
            ? String(localized: "station.setup.row.empty")
            : String(format: String(localized: "station.setup.row.summary"), station.builtIns.count, station.keywords.count)
    }
}

/// Emoji und Anzeigename einer festen Kategorie.
private struct StationCategoryLabel: View {
    let category: String
    var struck = false

    var body: some View {
        HStack(spacing: 10) {
            Text(AssignmentService.categoryEmoji(category))
            Text(AssignmentService.displayCategory(category))
                .strikethrough(struck)
                .foregroundStyle(struck ? Color.secondary : Color.ink)
        }
    }
}

// MARK: - Gang-Detail

/// Name, Emoji, feste Kategorien und Stichwörter eines Gangs.
struct StationDetailView: View {
    let store: Store
    let onChange: () -> Void
    @Environment(\.dismiss) private var dismiss

    /// Aktueller (gespeicherter) Name; folgt dem Umbenennen.
    @State private var name: String
    @State private var draft: String
    @State private var rejected = false
    @State private var confirmDelete = false
    @State private var deleted = false

    init(store: Store, name: String, onChange: @escaping () -> Void) {
        self.store = store
        self.onChange = onChange
        _name = State(initialValue: name)
        _draft = State(initialValue: name)
    }

    private var config: StationConfig? { store.stationConfig }
    private var station: Station? { config?.stations.first { $0.name == name } }

    var body: some View {
        VStack(spacing: 0) {
            detailList
            deleteBar
        }
        .background(Color.canvas)
        .navigationTitle(String(localized: "station.setup.detail.title"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(StationSetupView.deleteDialog(for: name, in: store).title,
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(StationSetupView.deleteDialog(for: name, in: store).button, role: .destructive) {
                deleted = true
                StationSetupView.delete(name, in: store)
                onChange()
                dismiss()
            }
            .accessibilityIdentifier("stationSetup.confirmDelete")
        } message: {
            Text(StationSetupView.deleteDialog(for: name, in: store).message)
        }
        .onDisappear { commitName() }
    }

    private var detailList: some View {
        List {
            if let config, let station {
                nameSection(station)
                categorySection(config, station: station)
                Section(String(localized: "station.setup.detail.keywords")) {
                    Text(station.keywords.isEmpty
                         ? String(localized: "station.setup.row.empty")
                         : station.keywords.joined(separator: ", "))
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.surface)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func nameSection(_ station: Station) -> some View {
        Section(String(localized: "category.editor.name")) {
            TextField(String(localized: "category.editor.name"), text: $draft)
                .accessibilityIdentifier("stationSetup.detail.name")
                .submitLabel(.done)
                .onSubmit { commitName() }
            if rejected {
                Text(String(localized: "station.setup.name.rejected"))
                    .font(.footnote)
                    .foregroundStyle(Color.destructive)
            }
            // Eingeklappt, damit die 35 Kategorie-Zeilen ohne langes Rollen erreichbar bleiben.
            DisclosureGroup {
                StationEmojiGrid(selected: station.emoji) { choice in
                    if store.renameStation(name, to: name, emoji: choice) != nil { onChange() }
                }
            } label: {
                HStack {
                    Text(String(localized: "category.editor.emoji")).foregroundStyle(Color.ink)
                    Spacer()
                    Text(station.emoji)
                }
            }
        }
        .listRowBackground(Color.surface)
    }

    private func categorySection(_ config: StationConfig, station: Station) -> some View {
        Section {
            ForEach(AssignmentService.categoryOrder, id: \.self) { category in
                categoryRow(category, config: config)
            }
        } header: {
            Text(String(format: String(localized: "station.setup.detail.categories"), station.builtIns.count))
        }
        .listRowBackground(Color.surface)
    }

    private func categoryRow(_ category: String, config: StationConfig) -> some View {
        let state = StoreCategories.categoryState(category, in: config)
        let mine = state == .assigned(name)
        let bound = StoreCategories.stationNamed(category, in: config)
        return Button {
            let next = mine
                ? StoreCategories.opening(category, in: config)
                : StoreCategories.assigning(category, toStation: name, in: config)
            guard let next else { return }
            withAnimation(.smooth) { store.updateStationConfig(next) }
            Haptics.impact(.light)
            onChange()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    StationCategoryLabel(category: category)
                    if let subtitle = subtitle(state: state, bound: bound) {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if mine { Image(systemName: "checkmark").foregroundStyle(Color.accent) }
            }
        }
        // Name-gebunden (AC-9): weder abwählbar noch in einen anderen Gang zu holen.
        .disabled(bound != nil)
        .accessibilityIdentifier("stationSetup.detail.category.\(category)")
        .accessibilityAddTraits(mine ? .isSelected : [])
    }

    private func subtitle(state: StoreCategories.CategoryState, bound: String?) -> String? {
        if let bound, bound != name {
            return String(format: String(localized: "station.setup.detail.bound"), bound)
        }
        switch state {
        case .open: return String(localized: "station.setup.detail.open")
        case .hidden: return String(localized: "station.setup.detail.hidden")
        case .assigned(let other) where other != name:
            return String(format: String(localized: "station.setup.detail.in"), other)
        case .assigned: return nil
        }
    }

    private var deleteBar: some View {
        Button(role: .destructive) { confirmDelete = true } label: {
            Text(String(localized: "station.setup.detail.delete")).frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(Color.destructive)
        .controlSize(.large)
        .accessibilityIdentifier("stationSetup.detail.delete")
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    /// Namen übernehmen (Return und Verlassen). Abgelehnt: Hinweis, gespeicherter Name bleibt.
    private func commitName() {
        guard !deleted, let station else { return }
        guard StoreCategories.normalizedName(draft) != name else {
            rejected = false
            draft = name
            return
        }
        if let new = store.renameStation(name, to: draft, emoji: station.emoji) {
            name = new
            draft = new
            rejected = false
            Haptics.impact(.light)
            onChange()
        } else {
            rejected = true
        }
    }
}

/// Emoji-Auswahl in sechs Spalten wie `CustomCategoryEditor`, Auswahl sofort gespeichert.
private struct StationEmojiGrid: View {
    let selected: String
    let onPick: (String) -> Void
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(StoreCategories.emojiChoices, id: \.self) { choice in
                Button {
                    onPick(choice)
                    Haptics.impact(.light)
                } label: {
                    Text(choice)
                        .font(.system(size: 26))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selected == choice ? Color.accentContainer : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(choice)
                .accessibilityAddTraits(selected == choice ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}
