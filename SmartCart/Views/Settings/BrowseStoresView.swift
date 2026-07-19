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
    @State private var showJoin = false

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
            .background(Color.surface, in: RoundedRectangle(cornerRadius: RCRadius.control))
            .overlay(RoundedRectangle(cornerRadius: RCRadius.control).strokeBorder(Color.hairline))
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
                                        ? Color.accentContainer
                                        : Color.surface
                                )
                                .foregroundStyle(selectedCountry == country.code ? Color.accent : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: RCRadius.tag))
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
                            .foregroundStyle(Color.accent.opacity(0.4))
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
                        .listRowBackground(Color.surface)
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.canvas)
                }
            } else if selectedCountry.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "globe.europe.africa")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.accent.opacity(0.4))
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
                        .listRowBackground(Color.surface)
                    }
                    Section("Eigener Laden") {
                        Button {
                            showCustom = true
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
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Eigenen Laden erstellen")
                                        .font(.system(size: 16))
                                        .foregroundStyle(Color.ink)
                                    Text("Name, Emoji, Farbe & Häufigkeit")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.textSecondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowBackground(Color.surface)
                    Section("Geteilte Liste") {
                        Button {
                            showJoin = true
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: RCRadius.control)
                                        .fill(Color.accentContainer)
                                        .frame(width: 34, height: 34)
                                    Image(systemName: "person.badge.plus")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(Color.accent)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Geteilter Liste beitreten")
                                        .font(.system(size: 16))
                                        .foregroundStyle(Color.ink)
                                    Text("6-stelligen Code eingeben, den dir jemand geschickt hat")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.textSecondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowBackground(Color.surface)
                }
                .scrollContentBackground(.hidden)
                .background(Color.canvas)
            }
        }
        .background(Color.canvas)
        .navigationTitle(String(localized: "browse.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ChipToolbarItem(placement: .confirmationAction) {
                Button { dismiss() } label: { Text("Fertig").toolbarChip() }
                    .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showCustom) { AddCustomStoreView() }
        .sheet(isPresented: $showJoin) { JoinStoreSheet() }
        .onAppear {
            if selectedCountry.isEmpty {
                selectedCountry = Store.availableCountries.first?.code ?? "DE"
            }
        }
    }

    @ViewBuilder
    private func presetRow(_ preset: Store, subtitle: String) -> some View {
        let alreadyAdded = existingStores.contains(where: { $0.name == preset.name && $0.isActive })
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
                        .foregroundStyle(Color.accent)
                        .font(.system(size: 22))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }

    private func addStore(_ preset: Store) {
        if let existing = existingStores.first(where: { $0.name == preset.name && !$0.isActive }) {
            existing.isActive = true
        } else {
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
        }
        addedNames.insert(preset.name)
        Haptics.success()
    }
}
