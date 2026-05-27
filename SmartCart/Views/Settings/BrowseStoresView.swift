import SwiftUI
import SwiftData

struct BrowseStoresView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var existingStores: [Store]
    @State private var selectedCountry: String = ""
    @State private var addedNames: Set<String> = []
    @State private var searchText: String = ""
    @State private var showCustom = false

    private var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty }

    private var presetsForCountry: [Store] {
        Store.presets(for: selectedCountry)
    }

    private var searchResults: [(preset: Store, country: (code: String, name: String, flag: String))] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return Store.availableCountries.flatMap { country in
            Store.presets(for: country.code)
                .filter { $0.name.lowercased().contains(query) }
                .map { (preset: $0, country: country) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(String(localized: "browse.search.placeholder"), text: $searchText)
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color(.systemGray3))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if !isSearching {
                // Country picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Store.availableCountries, id: \.code) { country in
                            Button {
                                selectedCountry = country.code
                            } label: {
                                HStack(spacing: 6) {
                                    Text(country.flag)
                                    Text(country.name)
                                        .font(.system(size: 14, weight: selectedCountry == country.code ? .semibold : .regular))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    selectedCountry == country.code
                                        ? Color.brand.opacity(0.15)
                                        : Color(.systemGray6)
                                )
                                .foregroundStyle(selectedCountry == country.code ? Color.brand : .primary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .padding(.bottom, 8)
                }
            }

            Divider()

            if isSearching {
                if searchResults.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.brand.opacity(0.4))
                        Text(String(localized: "browse.search.empty"))
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(searchResults, id: \.preset.id) { result in
                            presetRow(result.preset,
                                      subtitle: "\(result.country.flag) \(result.country.name)")
                        }
                    }
                }
            } else if selectedCountry.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "globe.europe.africa")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.brand.opacity(0.4))
                    Text(String(localized: "browse.select.country"))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                List {
                    if !selectedCountry.isEmpty {
                        Section {
                            ForEach(presetsForCountry) { preset in
                                presetRow(preset, subtitle: preset.categories.prefix(2).joined(separator: ", "))
                            }
                        } header: {
                            if let country = Store.availableCountries.first(where: { $0.code == selectedCountry }) {
                                Text("\(country.flag) \(country.name)")
                            }
                        }
                    }
                    Section("Eigener Laden") {
                        Button {
                            showCustom = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(Color.brand)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Eigenen Laden erstellen")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.primary)
                                    Text("Name, Emoji, Farbe & Häufigkeit")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle(String(localized: "browse.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { dismiss() }
                    .fontWeight(.semibold)
            }
        }
        .sheet(isPresented: $showCustom) { AddCustomStoreView() }
        .onAppear {
            if selectedCountry.isEmpty {
                selectedCountry = Store.availableCountries.first?.code ?? "DE"
            }
        }
    }

    @ViewBuilder
    private func presetRow(_ preset: Store, subtitle: String) -> some View {
        let alreadyAdded = existingStores.contains(where: { $0.name == preset.name })
            || addedNames.contains(preset.name)
        HStack {
            Text(preset.emoji)
                .font(.system(size: 22))
            VStack(alignment: .leading, spacing: 2) {
                Text(preset.name)
                    .font(.system(size: 16))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if alreadyAdded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button {
                    addStore(preset)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.brand)
                        .font(.system(size: 22))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }

    private func addStore(_ preset: Store) {
        let newStore = Store(
            name: preset.name,
            emoji: preset.emoji,
            colorHex: preset.colorHex,
            visitsPerWeek: preset.visitsPerWeek,
            categories: preset.categories,
            countryCode: preset.countryCode
        )
        newStore.isActive = true
        context.insert(newStore)
        addedNames.insert(preset.name)
        Haptics.success()
    }
}
