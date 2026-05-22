import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allStores: [Store]

    @AppStorage("selectedLanguage") private var selectedLanguage = "system"
    @AppStorage("selectedCountry") private var selectedCountry = Locale.current.region?.identifier ?? "DE"
    @AppStorage("currencyCode") private var currencyCode = Locale.current.currency?.identifier ?? "EUR"

    @State private var showFeedback = false
    @State private var notificationsEnabled = false

    var body: some View {
        NavigationStack {
            List {
                Section(String(localized: "settings.region")) {
                    Picker(String(localized: "settings.country"), selection: $selectedCountry) {
                        ForEach(Store.availableCountries, id: \.code) { country in
                            Text("\(country.flag) \(country.name)").tag(country.code)
                        }
                    }
                    .onChange(of: selectedCountry) { _, newCode in
                        seedStores(for: newCode)
                    }

                    Picker(String(localized: "settings.language"), selection: $selectedLanguage) {
                        Text(String(localized: "settings.language.system")).tag("system")
                        Text("Deutsch").tag("de")
                        Text("English").tag("en")
                    }
                }

                Section(String(localized: "settings.stores")) {
                    NavigationLink(String(localized: "stores.title")) {
                        StoreSetupView()
                    }
                }

                Section(String(localized: "settings.notifications")) {
                    Toggle(String(localized: "settings.notifications.replenish"), isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { _, enabled in
                            if enabled {
                                Task {
                                    notificationsEnabled = await NotificationService.shared.requestPermission()
                                }
                            } else {
                                NotificationService.shared.cancelAll()
                            }
                        }
                }

                Section(String(localized: "settings.feedback.section")) {
                    Button {
                        showFeedback = true
                    } label: {
                        Label(String(localized: "settings.feedback.button"), systemImage: "bubble.left.and.bubble.right")
                    }
                }

                Section(String(localized: "settings.about")) {
                    HStack {
                        Text(String(localized: "settings.version"))
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text(String(localized: "settings.build"))
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                            .foregroundStyle(.secondary)
                    }

                    // Roadmap items surfaced from feedback
                    VStack(alignment: .leading, spacing: 6) {
                        Label(String(localized: "settings.coming.sync"), systemImage: "clock")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Label(String(localized: "settings.coming.prices"), systemImage: "clock")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(String(localized: "settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.done")) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showFeedback) {
                FeedbackView()
            }
        }
    }

    private func seedStores(for countryCode: String) {
        guard allStores.filter({ $0.countryCode == countryCode }).isEmpty else { return }
        for store in Store.presets(for: countryCode) {
            context.insert(store)
        }
    }
}
