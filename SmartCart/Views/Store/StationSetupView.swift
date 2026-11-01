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
                        // Direkt unter den Gängen wie im freigegebenen Entwurf (2b-2).
                        StationAdoptionSection(store: store, onChange: changed)
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

/// Rückfragen der Übersicht: Vorlagen-Blatt, Gänge entfernen, Gang löschen (Wischen).
private struct StationSetupDialogs: ViewModifier {
    let store: Store
    @Binding var showTemplate: Bool
    @Binding var showRemove: Bool
    @Binding var pendingDelete: String?
    let onRemove: () -> Void
    let onChange: () -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showTemplate) {
                StationTemplateSheet(store: store, onChange: onChange)
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

/// Blatt „Vorlage wählen“ (Durchgang 2b-1): fünf Vorlagen, die vier Muster mit Kennzeichen. Hat der
/// Laden Gänge, fragt es vor dem Ersetzen nach.
struct StationTemplateSheet: View {
    let store: Store
    let onChange: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var pending: String?

    /// Blatt-Symbol, Name und Kennung je Vorlage (nur Anzeige).
    private static let rows: [String: (symbol: String, key: String.LocalizationValue, identifier: String)] = [
        "lidl": ("🏷️", "station.setup.template.lidl", "Lidl"),
        "discounter": ("🏷️", "station.setup.template.discounter", "Discounter"),
        "fullRange": ("🏬", "station.setup.template.fullrange", "FullRange"),
        "drugstore": ("🧴", "station.setup.template.drugstore", "Drugstore"),
        "hardware": ("🔨", "station.setup.template.hardware", "Hardware"),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(StoreCategories.allTemplates, id: \.id) { entry in
                        row(entry.id, template: entry.template)
                    }
                } header: {
                    Text(String(localized: "station.setup.template.message")).textCase(nil)
                }
                .listRowBackground(Color.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Color.canvas)
            .navigationTitle(String(localized: "station.setup.template.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "station.setup.template.cancel")) { dismiss() }
                        .accessibilityIdentifier("stationSetup.template.cancel")
                }
            }
            .confirmationDialog(String(localized: "station.setup.template.replace.title"), isPresented: replaceBinding,
                                titleVisibility: .visible, presenting: pending) { id in
                Button(String(localized: "station.setup.template.replace.confirm"), role: .destructive) { apply(id) }
                    .accessibilityIdentifier("stationSetup.templateReplace")
            } message: { _ in
                Text(String(localized: "station.setup.template.message"))
            }
        }
    }

    private func row(_ id: String, template: StationConfig) -> some View {
        let info = Self.rows[id] ?? ("🏷️", "station.setup.template.lidl", id)
        let name = String(localized: info.key)
        let count = String(format: String(localized: "station.setup.template.count"), template.stations.count)
        let hint = id == "lidl" ? nil : String(localized: "station.setup.template.hint")
        return Button {
            if store.hasStations { pending = id } else { apply(id) }
        } label: {
            HStack(spacing: 12) {
                Text(info.symbol).font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).foregroundStyle(Color.ink)
                    Text(count).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let hint {
                    Text(hint)
                        .font(.caption2)
                        .foregroundStyle(Color.amber)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .overlay(Capsule().stroke(Color.amber))
                }
            }
        }
        .accessibilityLabel([name, count, hint].compactMap { $0 }.joined(separator: ", "))
        .accessibilityIdentifier("stationSetup.template\(info.identifier)")
    }

    private var replaceBinding: Binding<Bool> {
        Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })
    }

    private func apply(_ id: String) {
        guard let template = StoreCategories.allTemplates.first(where: { $0.id == id })?.template else { return }
        withAnimation(.smooth) { store.applyStationConfig(template) }
        Haptics.impact(.medium)
        onChange()
        dismiss()
    }
}

/// Zeile eines Gangs in der Übersicht: Emoji, Name, Inhalt.
struct StationSetupRow: View {
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
        Self.summaryText(categories: station.builtIns.count, keywords: station.keywords.count)
    }

    /// „1 Kategorie · 3 Stichwörter“; Einzahl bei genau 1, „noch leer“ bei 0 und 0.
    static func summaryText(categories: Int, keywords: Int) -> String {
        guard categories > 0 || keywords > 0 else { return String(localized: "station.setup.row.empty") }
        let categoryText = categories == 1
            ? String(localized: "station.setup.row.categories.one")
            : String(format: String(localized: "station.setup.row.categories.other"), categories)
        let keywordText = keywords == 1
            ? String(localized: "station.setup.row.keywords.one")
            : String(format: String(localized: "station.setup.row.keywords.other"), keywords)
        return "\(categoryText) · \(keywordText)"
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
        ScrollViewReader { proxy in
            List {
                if let config, let station {
                    nameSection(station)
                    // Vor den 35 Kategorie-Zeilen, damit Feld und Stichwörter ohne langes Rollen erreichbar sind.
                    StationKeywordSection(store: store, station: station, scroll: proxy, onChange: onChange)
                    categorySection(config, station: station)
                }
            }
            .scrollContentBackground(.hidden)
        }
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

/// Stichwörter eines Gangs (Durchgang 2b-1): Zeilen mit Wischen zum Löschen, Feld zum Hinzufügen,
/// Hinweiszeile. Speichern über `store.updateStationConfig`.
private struct StationKeywordSection: View {
    let store: Store
    let station: Station
    let scroll: ScrollViewProxy
    let onChange: () -> Void

    private enum Message: Equatable {
        case notice(String)
        case duplicate(String)
        case invalid
    }

    @State private var draft = ""
    @State private var message: Message?

    var body: some View {
        Section {
            if station.keywords.isEmpty {
                Text(String(localized: "station.setup.row.empty")).foregroundStyle(.secondary)
            }
            ForEach(station.keywords, id: \.self) { keyword in
                Text(keyword)
                    .foregroundStyle(Color.ink)
                    .accessibilityIdentifier("stationSetup.keyword.row.\(keyword)")
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { remove(keyword) } label: {
                            Label(String(localized: "station.setup.keyword.delete"), systemImage: "trash")
                        }
                        .accessibilityIdentifier("stationSetup.keyword.delete.\(keyword)")
                    }
            }
            HStack {
                TextField(String(localized: "station.setup.keyword.placeholder"), text: draftBinding)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit { add() }
                    .accessibilityIdentifier("stationSetup.keyword.field")
                Button(String(localized: "station.setup.keyword.add")) { add() }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("stationSetup.keyword.add")
            }
            // Sonst richtet SwiftUI die Trennlinie am Knopftext aus (das Feld zählt nicht als Text).
            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
            if let message { messageRow(message).id(Self.messageID) }
        } header: {
            Text(String(format: String(localized: "station.setup.detail.keywords"), station.keywords.count))
        }
        .listRowBackground(Color.surface)
        // Bei offener Tastatur läge der Hinweis sonst unter dem sichtbaren Rand der Liste.
        .onChange(of: message) { _, new in
            guard new != nil else { return }
            withAnimation(.smooth) { scroll.scrollTo(Self.messageID, anchor: .bottom) }
        }
    }

    private static let messageID = "stationSetup.keyword.message"

    /// Eingabe des Nutzers löscht den Hinweis; das Leeren nach dem Speichern nicht.
    private var draftBinding: Binding<String> {
        // SwiftUI ruft den Setter auch mit unverändertem Text (z. B. beim Tipp auf „Hinzufügen“).
        Binding(get: { draft }, set: { if $0 != draft { message = nil }; draft = $0 })
    }

    @ViewBuilder
    private func messageRow(_ message: Message) -> some View {
        switch message {
        case .notice(let text):
            Text(text).font(.footnote).foregroundStyle(.secondary)
                .accessibilityIdentifier("stationSetup.keyword.notice")
        case .duplicate(let text):
            Text(text).font(.footnote).foregroundStyle(Color.destructive)
                .accessibilityIdentifier("stationSetup.keyword.duplicate")
        case .invalid:
            Text(String(localized: "station.setup.keyword.invalid")).font(.footnote).foregroundStyle(Color.destructive)
                .accessibilityIdentifier("stationSetup.keyword.invalid")
        }
    }

    private func add() {
        guard let config = store.stationConfig else { return }
        switch StoreCategories.checkKeyword(draft, inStation: station.name, config: config) {
        case .invalid:
            message = .invalid
        case .duplicate:
            let word = StoreCategories.normalizedKeyword(draft) ?? draft
            message = .duplicate(String(format: String(localized: "station.setup.keyword.duplicate"), word))
        case .accepted(let others):
            guard let next = StoreCategories.addingKeyword(draft, toStation: station.name, in: config),
                  let word = StoreCategories.normalizedKeyword(draft) else { return }
            withAnimation(.smooth) { store.updateStationConfig(next) }
            Haptics.impact(.light)
            onChange()
            draft = ""
            message = others.isEmpty ? nil : .notice(String(format: String(localized: "station.setup.keyword.notice"),
                                                            word, others.joined(separator: ", ")))
        }
    }

    private func remove(_ keyword: String) {
        guard let config = store.stationConfig,
              let next = StoreCategories.removingKeyword(keyword, fromStation: station.name, in: config) else { return }
        withAnimation(.smooth) { store.updateStationConfig(next) }
        Haptics.impact(.light)
        onChange()
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
                .accessibilityIdentifier("stationSetup.emoji.\(choice)")
                .accessibilityAddTraits(selected == choice ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}
