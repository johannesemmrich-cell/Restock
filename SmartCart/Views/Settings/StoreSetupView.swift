import SwiftUI
import SwiftData

struct StoreSetupView: View {
    @Environment(\.modelContext) private var context
    @Query private var allStores: [Store]
    @State private var showAddCustomStore = false
    @State private var selectedCountry = Locale.current.region?.identifier ?? "DE"

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
                Button {
                    showAddCustomStore = true
                } label: {
                    Label(String(localized: "stores.add.custom"), systemImage: "plus")
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(store.emoji)
                    .font(.system(size: 20))
                Text(store.name)
                    .font(.system(size: 16, weight: .medium))
                Spacer()
                Toggle("", isOn: $store.isActive)
                    .labelsHidden()
            }

            if store.isActive {
                HStack {
                    Text(String(localized: "stores.visits.label"))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Stepper(
                        value: $store.visitsPerWeek,
                        in: 0.5...14,
                        step: 0.5
                    ) {
                        Text(visitsLabel(store.visitsPerWeek))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func visitsLabel(_ v: Double) -> String {
        if v < 1 { return String(localized: "store.visits.biweekly") }
        let count = Int(v.rounded())
        return String(format: String(localized: "store.visits.perweek"), count)
    }
}

struct AddCustomStoreView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var emoji = "🛒"
    @State private var colorHex = "#0050AA"
    @State private var visitsPerWeek = 1.0
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
                    Stepper(
                        value: $visitsPerWeek,
                        in: 0.5...14,
                        step: 0.5
                    ) {
                        Text("\(String(localized: "stores.visits.label")): \(Int(visitsPerWeek))x/\(String(localized: "week"))")
                            .font(.system(size: 14))
                    }
                }

                Section(String(localized: "stores.categories")) {
                    ForEach(allCategories, id: \.self) { category in
                        HStack {
                            Text(category)
                            Spacer()
                            if selectedCategories.contains(category) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
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
            colorHex: colorHex,
            visitsPerWeek: visitsPerWeek,
            categories: Array(selectedCategories),
            isCustom: true
        )
        context.insert(store)
        dismiss()
    }
}
