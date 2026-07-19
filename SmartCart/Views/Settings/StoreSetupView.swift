import SwiftUI
import SwiftData

struct StoreSetupView: View {
    @Environment(\.modelContext) private var context
    @Query private var allStores: [Store]
    @State private var showAddCustomStore = false
    @State private var storeToDelete: Store? = nil
    @State private var editMode: EditMode = .inactive
    // Lokale Kopie für ForEach — verhindert dass @Query-Re-Sort die Drag-Animation abbricht
    @State private var orderedActiveStores: [Store] = []

    var body: some View {
        List {
            Section {
                ForEach(orderedActiveStores) { store in
                    StoreRow(store: store)
                        .swipeActions(edge: .trailing) {
                            Button {
                                withAnimation { store.isActive = false }
                                Haptics.impact(.medium)
                            } label: {
                                Label("Deaktivieren", systemImage: "pause.circle")
                            }
                            .tint(.orange)
                        }
                }
                .onMove { from, to in
                    orderedActiveStores.move(fromOffsets: from, toOffset: to)
                    for (i, s) in orderedActiveStores.enumerated() {
                        s.sortIndex = i
                    }
                }
            } header: {
                sectionLabel(String(localized: "stores.active"))
            }
            .listRowBackground(Color.surface)
            if !allStores.filter({ !$0.isActive }).isEmpty {
                Section {
                    ForEach(allStores.filter { !$0.isActive }) { store in
                        StoreRow(store: store)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    storeToDelete = store
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                                Button {
                                    withAnimation { store.isActive = true }
                                    Haptics.impact(.medium)
                                } label: {
                                    Label("Aktivieren", systemImage: "play.circle")
                                }
                                .tint(.green)
                            }
                    }
                } header: {
                    sectionLabel(String(localized: "stores.inactive"))
                }
                .listRowBackground(Color.surface)
            }
            Section {
                NavigationLink {
                    BrowseStoresView()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: RCRadius.control)
                                .fill(Color.accentContainer)
                                .frame(width: 34, height: 34)
                            Image(systemName: "globe.europe.africa")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.accent)
                        }
                        Text(String(localized: "stores.browse.other"))
                            .foregroundStyle(Color.ink)
                    }
                }

                Button {
                    showAddCustomStore = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: RCRadius.control)
                                .fill(Color.accentContainer)
                                .frame(width: 34, height: 34)
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.accent)
                        }
                        Text(String(localized: "stores.add.custom"))
                            .foregroundStyle(Color.accent)
                    }
                }
            }
            .listRowBackground(Color.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Color.canvas)
        .tint(Color.accent)
        .onAppear { syncOrder() }
        .onChange(of: allStores) {
            // Nur außerhalb von EditMode synchronisieren — während Drag nicht unterbrechen
            if editMode == .inactive { syncOrder() }
        }
        .navigationTitle(String(localized: "stores.title"))
        .environment(\.editMode, $editMode)
        .toolbar {
            ChipToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation { editMode = editMode == .active ? .inactive : .active }
                } label: {
                    Text(editMode == .active ? "Fertig" : "Bearbeiten").toolbarChip()
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showAddCustomStore) {
            AddCustomStoreView()
        }
        .confirmationDialog(
            "Markt löschen?",
            isPresented: Binding(get: { storeToDelete != nil }, set: { if !$0 { storeToDelete = nil } }),
            titleVisibility: .visible
        ) {
            if let store = storeToDelete {
                Button("Löschen", role: .destructive) {
                    context.delete(store)
                    storeToDelete = nil
                }
            }
            Button("Abbrechen", role: .cancel) { storeToDelete = nil }
        } message: {
            if let store = storeToDelete {
                Text("\"\(store.name)\" und alle zugehörigen Artikel werden dauerhaft gelöscht.")
            }
        }
    }

    private func syncOrder() {
        orderedActiveStores = allStores.filter { $0.isActive }.sorted { $0.sortIndex < $1.sortIndex }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(Color.textSecondary)
    }
}

struct StoreRow: View {
    @Bindable var store: Store
    @State private var showEmojiEdit = false
    @State private var emojiDraft = ""

    private var freq: Binding<VisitFrequency> {
        Binding(
            get: { VisitFrequency.closest(to: store.visitsPerWeek) },
            set: { store.visitsPerWeek = $0.rawValue }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    emojiDraft = store.emoji
                    showEmojiEdit = true
                    Haptics.impact(.light)
                } label: {
                    Image(systemName: store.iconSystemName)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Color.ink)
                        .frame(width: 24)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(store.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.ink)
                    Text(freq.wrappedValue.label)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.accent)
                }
                Spacer()
                Toggle("", isOn: $store.isActive)
                    .labelsHidden()
                    .tint(Color.accent)
            }

            if store.isActive {
                Picker(String(localized: "stores.visits.label"), selection: freq) {
                    ForEach(VisitFrequency.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.accent)
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showEmojiEdit) {
            NavigationStack {
                VStack(spacing: 20) {
                    Text(emojiDraft.isEmpty ? "🛒" : String(emojiDraft.prefix(2)))
                        .font(.system(size: 64))
                        .padding(.top, 24)
                    TextField("🛒", text: $emojiDraft)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 32))
                        .frame(width: 80)
                        .padding(12)
                        .background(Color.surface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.hairline))
                    Text("Emoji-Taste auf der Tastatur tippen")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .navigationTitle("Emoji ändern")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ChipToolbarItem(placement: .cancellationAction) {
                        Button { showEmojiEdit = false } label: { Text("Abbrechen").toolbarChip(prominent: false) }
                            .buttonStyle(.plain)
}
                    ChipToolbarItem(placement: .confirmationAction) {
                        Button {
                            let e = emojiDraft.trimmingCharacters(in: .whitespaces)
                            if !e.isEmpty { store.emoji = String(e.prefix(2)) }
                            showEmojiEdit = false
                            Haptics.success()
                        } label: {
                            Text("Speichern").toolbarChip(prominent: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .presentationDetents([.height(300)])
        }
    }
}

struct AddCustomStoreView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var emoji = "🛒"
    @State private var selectedColor = Color.accent
    @State private var selectedFreq = VisitFrequency.weekly
    @State private var selectedCategories: Set<String> = Set(Category.grocery)

    private let allCategories = Category.grocery + Category.drugstore + Category.variety + Category.hardware

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "stores.add.details")) {
                    HStack {
                        TextField("🛒", text: $emoji)
                            .frame(width: 50)
                            .multilineTextAlignment(.center)
                        TextField(String(localized: "stores.name.placeholder"), text: $name)
                    }
                    Picker(String(localized: "stores.visits.label"), selection: $selectedFreq) {
                        ForEach(VisitFrequency.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    ColorPicker(String(localized: "stores.color"), selection: $selectedColor, supportsOpacity: false)
                }

                Section(String(localized: "stores.categories")) {
                    ForEach(allCategories, id: \.self) { category in
                        HStack {
                            Text(category)
                            Spacer()
                            if selectedCategories.contains(category) {
                                Image(systemName: "checkmark").foregroundStyle(Color.accent)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedCategories.contains(category) {
                                selectedCategories.remove(category)
                            } else {
                                selectedCategories.insert(category)
                            }
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "stores.add.custom"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ChipToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text(String(localized: "action.cancel")).toolbarChip(prominent: false) }
                        .buttonStyle(.plain)
}
                ChipToolbarItem(placement: .confirmationAction) {
                    Button { addStore() } label: { Text(String(localized: "action.add")).toolbarChip(prominent: true) }
                        .buttonStyle(.plain)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                }
            }
        }
}

    private func addStore() {
        let store = Store(
            name: name.trimmingCharacters(in: .whitespaces),
            emoji: emoji.isEmpty ? "🛒" : String(emoji.prefix(2)),
            colorHex: selectedColor.toHex(),
            visitsPerWeek: selectedFreq.rawValue,
            categories: Array(selectedCategories),
            isCustom: true
        )
        context.insert(store)
        dismiss()
    }
}
