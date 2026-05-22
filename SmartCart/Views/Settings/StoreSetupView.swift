import SwiftUI
import SwiftData

struct StoreSetupView: View {
    @Environment(\.modelContext) private var context
    @Query private var allStores: [Store]
    @State private var showAddCustomStore = false

    var body: some View {
        List {
            Section(String(localized: "stores.active")) {
                ForEach(allStores.filter { $0.isActive }) { store in
                    StoreRow(store: store)
                }
            }
            if !allStores.filter({ !$0.isActive }).isEmpty {
                Section(String(localized: "stores.inactive")) {
                    ForEach(allStores.filter { !$0.isActive }) { store in
                        StoreRow(store: store)
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
        .navigationTitle(String(localized: "stores.title"))
        .sheet(isPresented: $showAddCustomStore) {
            AddCustomStoreView()
        }
    }
}

struct StoreRow: View {
    @Bindable var store: Store

    private var freq: Binding<VisitFrequency> {
        Binding(
            get: { VisitFrequency.closest(to: store.visitsPerWeek) },
            set: { store.visitsPerWeek = $0.rawValue }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(store.emoji)
                    .font(.system(size: 22))
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

    private let allCategories = Category.grocery + Category.drugstore

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
