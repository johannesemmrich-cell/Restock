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
            Section(String(localized: "stores.active")) {
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
            }
            if !allStores.filter({ !$0.isActive }).isEmpty {
                Section(String(localized: "stores.inactive")) {
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
                }
            }
            Section {
                NavigationLink {
                    BrowseStoresView()
                } label: {
                    Label(String(localized: "stores.browse.other"), systemImage: "globe")
                }

                Button {
                    showAddCustomStore = true
                } label: {
                    Label(String(localized: "stores.add.custom"), systemImage: "plus.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
        }
        .onAppear { syncOrder() }
        .onChange(of: allStores) {
            // Nur außerhalb von EditMode synchronisieren — während Drag nicht unterbrechen
            if editMode == .inactive { syncOrder() }
        }
        .navigationTitle(String(localized: "stores.title"))
        .environment(\.editMode, $editMode)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
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
                Text("\"\\(store.name)\" und alle zugehörigen Artikel werden dauerhaft gelöscht.")
            }
        }
    }

    private func syncOrder() {
        orderedActiveStores = allStores.filter { $0.isActive }.sorted { $0.sortIndex < $1.sortIndex }
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
            HStack {
                Button {
                    emojiDraft = store.emoji
                    showEmojiEdit = true
                    Haptics.impact(.light)
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        Text(store.emoji)
                            .font(.system(size: 22))
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.blue)
                            .background(Color(.systemBackground), in: Circle())
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 1) {
                    Text(store.name)
                        .font(.system(size: 16, weight: .medium))
                    Text(freq.wrappedValue.label)
                        .font(.system(size: 12))
                        .foregroundStyle(store.color)
                }
                Spacer()
                Toggle("", isOn: $store.isActive)
                    .labelsHidden()
            }

            if store.isActive {
                Picker(String(localized: "stores.visits.label"), selection: freq) {
                    ForEach(VisitFrequency.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .tint(store.color)
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
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                    Text("Emoji-Taste auf der Tastatur tippen")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .navigationTitle("Emoji ändern")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") { showEmojiEdit = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Speichern") {
                            let e = emojiDraft.trimmingCharacters(in: .whitespaces)
                            if !e.isEmpty { store.emoji = String(e.prefix(2)) }
                            showEmojiEdit = false
                            Haptics.success()
                        }
                        .fontWeight(.semibold)
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
    @State private var selectedColor = Color.brand
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
                                Image(systemName: "checkmark").foregroundStyle(.blue)
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
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.add")) { addStore() }
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
