import SwiftUI
import SwiftData
import CryptoKit

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allStores: [Store]

    @AppStorage("selectedLanguage") private var selectedLanguage = "system"
    @AppStorage("selectedCountry") private var selectedCountry = Locale.current.region?.identifier ?? "DE"
    @AppStorage("currencyCode") private var currencyCode = Locale.current.currency?.identifier ?? "EUR"
    @AppStorage("developerMode") private var developerMode = false

    @State private var showFeedback = false
    @State private var notificationsEnabled = false
    @State private var versionTapCount = 0
    @State private var lastTapTime: Date = .distantPast
    @State private var showDevPasswordPrompt = false
    @State private var devPasswordInput = ""
    @State private var devPasswordError = false

    private let devPasswordHash = "959276dcc2b5b3f0741df56dc2eed4a9f5dd1ad5a4daf82eb718066cde53b5d5"

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
                    .contentShape(Rectangle())
                    .onTapGesture {
                        let now = Date()
                        if now.timeIntervalSince(lastTapTime) > 2 {
                            versionTapCount = 1
                        } else {
                            versionTapCount += 1
                        }
                        lastTapTime = now
                        Haptics.impact(.light)
                        if versionTapCount >= 5 {
                            versionTapCount = 0
                            showDevPasswordPrompt = true
                        }
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

                if developerMode {
                    Section {
                        NavigationLink {
                            FeedbackListView()
                        } label: {
                            Label("Feedback", systemImage: "hand.thumbsdown")
                        }

                        Button(role: .destructive) {
                            developerMode = false
                            Haptics.impact(.medium)
                        } label: {
                            Label("Developer Mode deaktivieren", systemImage: "xmark.circle")
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                            Text("Entwickler")
                        }
                    }
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
            .alert("Developer Mode", isPresented: $showDevPasswordPrompt) {
                SecureField("Passwort", text: $devPasswordInput)
                Button("Abbrechen", role: .cancel) {
                    devPasswordInput = ""
                    devPasswordError = false
                }
                Button("Entsperren") {
                    let inputHash = SHA256.hash(data: Data(devPasswordInput.utf8))
                        .map { String(format: "%02x", $0) }
                        .joined()
                    if inputHash == devPasswordHash {
                        developerMode = true
                        devPasswordError = false
                        Haptics.impact(.heavy)
                    } else {
                        devPasswordError = true
                    }
                    devPasswordInput = ""
                }
            } message: {
                if devPasswordError {
                    Text("Falsches Passwort. Versuche es erneut.")
                } else {
                    Text("Passwort eingeben, um den Developer Mode zu aktivieren.")
                }
            }
        }
        .devFeedback(context: "Einstellungen")
    }

    private func seedStores(for countryCode: String) {
        guard allStores.filter({ $0.countryCode == countryCode }).isEmpty else { return }
        for store in Store.presets(for: countryCode) {
            context.insert(store)
        }
    }
}
