import SwiftUI
import SwiftData

/// Issue #184: Opt-in-Schalter, Open-Food-Facts-Anmeldung, Filiale je Laden (OpenStreetMap) und
/// letzter Beitrag. Der Schalter fragt beim Einschalten nach (Bonfoto wird öffentlich, CC BY-SA).
struct OpenPricesSettingsView: View {
    @Query(filter: #Predicate<Store> { $0.isActive }, sort: \Store.sortIndex) private var stores: [Store]
    @AppStorage(OpenPricesContribution.enabledKey) private var enabled = OpenPricesContribution.enabledDefault
    @State private var showConfirm = false
    @State private var username = ""
    @State private var password = ""
    @State private var loginError: String?
    @State private var isLoggingIn = false
    @State private var loggedInAs: String?
    @State private var locations: [String: OpenPricesLocation] = [:]
    @State private var lastResult: OpenPricesLastResult?

    private let service = OpenPricesContributionService.shared

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "settings.openprices.toggle"), isOn: Binding(
                    get: { enabled },
                    set: { newValue in
                        // Einschalten erst nach dem Hinweis; Ausschalten sofort.
                        if newValue { showConfirm = true } else { enabled = false }
                    }))
                .accessibilityIdentifier("openPrices.toggle")
                Text(String(localized: "settings.openprices.footer"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(String(format: String(localized: "settings.openprices.environment"), OpenPricesContribution.environment.displayName))
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .listRowBackground(Color.surface)

            Section(String(localized: "settings.openprices.account")) {
                if let loggedInAs {
                    Text(String(format: String(localized: "settings.openprices.loggedin"), loggedInAs))
                    Button(role: .destructive) {
                        Task { await service.logout(); refresh() }
                    } label: {
                        Text(String(localized: "settings.openprices.logout"))
                    }
                } else {
                    TextField(String(localized: "settings.openprices.username"), text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("openPrices.username")
                    SecureField(String(localized: "settings.openprices.password"), text: $password)
                        .accessibilityIdentifier("openPrices.password")
                    Button {
                        login()
                    } label: {
                        if isLoggingIn { ProgressView() } else { Text(String(localized: "settings.openprices.login")) }
                    }
                    .disabled(isLoggingIn || username.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty)
                    if let loginError {
                        Text(String(format: String(localized: "settings.openprices.login.failed"), loginError))
                            .font(.footnote)
                            .foregroundStyle(Color.destructive)
                    }
                }
            }
            .listRowBackground(Color.surface)

            Section {
                ForEach(stores) { store in
                    NavigationLink {
                        OpenPricesPlaceSearchView(store: store) { location in
                            OpenPricesLocationStore.shared.set(location, for: store.id)
                            refresh()
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(store.emoji) \(store.name)")
                            Text(locations[store.id.uuidString]?.displayName ?? String(localized: "settings.openprices.location.choose"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            } header: {
                Text(String(localized: "settings.openprices.locations"))
            } footer: {
                Text(String(localized: "settings.openprices.locations.footer"))
            }
            .listRowBackground(Color.surface)

            Section {
                if let lastResult {
                    Text(String(format: String(localized: "settings.openprices.last"),
                                lastResult.date.formatted(date: .numeric, time: .shortened),
                                lastResult.sent, lastResult.skipped, lastResult.failed))
                        .font(.footnote)
                    if lastResult.message != "ok" {
                        Text(lastResult.message).font(.footnote).foregroundStyle(.secondary)
                    }
                } else {
                    Text(String(localized: "settings.openprices.last.none")).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .listRowBackground(Color.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Color.surface.ignoresSafeArea())
        .navigationTitle(String(localized: "settings.openprices.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refresh)
        .alert(String(localized: "settings.openprices.confirm.title"), isPresented: $showConfirm) {
            Button(String(localized: "settings.openprices.confirm.ok")) { enabled = true }
            Button(String(localized: "action.cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "settings.openprices.confirm.message"))
        }
        .devFeedback(context: "Open Prices")
    }

    private func refresh() {
        locations = OpenPricesLocationStore.shared.all()
        Task {
            let loggedIn = await service.isLoggedIn
            let name = await service.username
            let result = await service.lastResult()
            loggedInAs = loggedIn ? (name ?? "?") : nil
            lastResult = result
        }
    }

    private func login() {
        isLoggingIn = true
        loginError = nil
        let name = username.trimmingCharacters(in: .whitespaces)
        let secret = password
        Task {
            do {
                try await service.login(username: name, password: secret)
                password = ""
            } catch {
                loginError = OpenPricesContributionService.message(for: error)
            }
            isLoggingIn = false
            refresh()
        }
    }
}

/// Nominatim-Suche für die Filiale eines Ladens; Auswahl ruft `onSelect` und geht zurück.
struct OpenPricesPlaceSearchView: View {
    let store: Store
    let onSelect: (OpenPricesLocation) -> Void
    var search: PlaceSearchAPI = NominatimClient()

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [OpenPricesLocation] = []
    @State private var searched = false
    @State private var isSearching = false

    var body: some View {
        List {
            Section {
                TextField(String(localized: "settings.openprices.location.search"), text: $query)
                    .onSubmit(runSearch)
                    .submitLabel(.search)
                    .accessibilityIdentifier("openPrices.placeQuery")
            }
            Section {
                if isSearching {
                    ProgressView()
                } else if searched && results.isEmpty {
                    Text(String(localized: "settings.openprices.location.none")).foregroundStyle(.secondary)
                }
                ForEach(results) { place in
                    Button {
                        onSelect(place)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(place.displayName).font(.body)
                            Text(place.id).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .tint(.primary)
                }
            }
        }
        .navigationTitle(store.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if query.isEmpty { query = store.name } }
    }

    private func runSearch() {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isSearching = true
        Task {
            let found = (try? await search.search(text)) ?? []
            results = found
            searched = true
            isSearching = false
        }
    }
}
