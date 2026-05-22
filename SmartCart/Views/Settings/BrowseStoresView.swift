import SwiftUI
import SwiftData

struct BrowseStoresView: View {
    @Environment(\.modelContext) private var context
    @Query private var existingStores: [Store]
    @State private var selectedCountry: String = ""
    @State private var addedNames: Set<String> = []

    private var presetsForCountry: [Store] {
        Store.presets(for: selectedCountry)
    }

    var body: some View {
        VStack(spacing: 0) {
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
                .padding(.vertical, 12)
            }

            Divider()

            if selectedCountry.isEmpty {
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
                    Section {
                        ForEach(presetsForCountry) { preset in
                            let alreadyAdded = existingStores.contains(where: { $0.name == preset.name })
                                || addedNames.contains(preset.name)
                            HStack {
                                Text(preset.emoji)
                                    .font(.system(size: 22))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.name)
                                        .font(.system(size: 16))
                                    Text(preset.categories.prefix(2).joined(separator: ", "))
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
                    } header: {
                        if let country = Store.availableCountries.first(where: { $0.code == selectedCountry }) {
                            Text("\(country.flag) \(country.name)")
                        }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "browse.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Pre-select first country not already home country
            if selectedCountry.isEmpty {
                selectedCountry = Store.availableCountries.first?.code ?? "DE"
            }
        }
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
