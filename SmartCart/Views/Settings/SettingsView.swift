import SwiftUI
import SwiftData
import CryptoKit
import UIKit

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allStores: [Store]

    @AppStorage(UserIdentity.storageKey, store: UserDefaults(suiteName: "group.com.johannesemmrich.SmartCart"))
    private var userDisplayName = ""
    @AppStorage("selectedLanguage") private var selectedLanguage = "system"
    @AppStorage("selectedCountry") private var selectedCountry = Locale.current.region?.identifier ?? "DE"
    @AppStorage("currencyCode") private var currencyCode = Locale.current.currency?.identifier ?? "EUR"
    @AppStorage("developerMode") private var developerMode = false
    @AppStorage("seasonalSuggestionsEnabled") private var seasonalSuggestionsEnabled = true
    @AppStorage("autoSortByLearnedOrder", store: UserDefaults(suiteName: "group.com.johannesemmrich.SmartCart"))
    private var autoSortByLearnedOrder = true

    @EnvironmentObject private var premium: PremiumService
    @State private var showPaywall = false
    @State private var paywallContext: PaywallContext = .premium(feature: "alle Pro-Features")
    @State private var showFeedback = false
    @State private var showJoinStore = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @State private var versionTapCount = 0
    @State private var lastTapTime: Date = .distantPast
    @State private var showDevPasswordPrompt = false
    @State private var devPasswordInput = ""
    @State private var devPasswordError = false

    private let devPasswordHash = "5636a8a19206c71e37f9c7ae5a1b9f241f6f303a6e9fb78b93732d4f84b36def"

    var body: some View {
        NavigationStack {
            List {
                Section(String(localized: "settings.profile.section")) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                        TextField(String(localized: "settings.profile.name.placeholder"), text: $userDisplayName)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .onChange(of: userDisplayName) { _, new in
                                let trimmed = new.trimmingCharacters(in: .whitespaces)
                                if trimmed != new { userDisplayName = trimmed }
                            }
                    }
                }

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

                Section("Restock Pro") {
                    if premium.isPremiumUnlocked {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Pro aktiv")
                                    .font(.system(size: 15, weight: .medium))
                                Text("Alle Features freigeschaltet")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Verwalten") {
                                if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    } else {
                        Button {
                            Haptics.impact(.light)
                            paywallContext = .premium(feature: "alle Pro-Features")
                            showPaywall = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(LinearGradient.brand)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Restock Pro freischalten")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(.primary)
                                    Text("Kassenbon-Scan, Menüplan, Ausgaben & mehr")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("Teilen & Zusammenarbeit") {
                    if premium.isSharedListsUnlocked {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Geteilte Listen aktiv")
                                    .font(.system(size: 15, weight: .medium))
                                Text("Echtzeit-Sync mit anderen Personen")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    } else {
                        Button {
                            Haptics.impact(.light)
                            paywallContext = .sharedLists
                            showPaywall = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(LinearGradient.brand)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Geteilte Listen freischalten")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(.primary)
                                    Text("Einmaliger Kauf · 4,99 €")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        showJoinStore = true
                    } label: {
                        Label("Geteiltem Store beitreten", systemImage: "person.badge.plus")
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
                    Toggle("Saisonale Vorschläge", isOn: $seasonalSuggestionsEnabled)
                    VStack(alignment: .leading, spacing: 2) {
                        Toggle("Automatisch nach Einkaufsreihenfolge sortieren", isOn: $autoSortByLearnedOrder)
                        Text("Restock merkt sich, in welcher Reihenfolge du Artikel abhakst, und sortiert die Liste beim nächsten Mal entsprechend.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }

                Section("Siri & Schnellzugriff") {
                    HStack(spacing: 12) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.purple)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Siri")
                                .font(.system(size: 15, weight: .medium))
                            Text("\"Hey Siri, füge Milch zu Restock hinzu\"")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)

                    HStack(spacing: 12) {
                        Image(systemName: "switch.2")
                            .font(.system(size: 18))
                            .foregroundStyle(.blue)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Kontrollzentrum")
                                .font(.system(size: 15, weight: .medium))
                            Text("Widget hinzufügen: Einstellungen > Kontrollzentrum")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.orange)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("App-Icon lange drücken")
                                .font(.system(size: 15, weight: .medium))
                            Text("Öffnet die App direkt zur Schnelleingabe")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)

                    Button {
                        if let url = URL(string: "shortcuts://") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "square.grid.2x2.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Color(red: 0.7, green: 0.2, blue: 1.0))
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Homescreen-Kurzbefehl")
                                    .font(.system(size: 15, weight: .medium))
                                Text("Kurzbefehle-App öffnen → Restock-Kurzbefehl zum Homescreen hinzufügen")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Section(String(localized: "settings.feedback.section")) {
                    Button {
                        showFeedback = true
                    } label: {
                        Label(String(localized: "settings.feedback.button"), systemImage: "bubble.left.and.bubble.right")
                    }
                }

                Section("Über Restock") {
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

                    NavigationLink {
                        LegalOverviewView()
                    } label: {
                        Label("Rechtliches", systemImage: "doc.plaintext")
                    }

                    Button {
                        if let url = URL(string: "mailto:j.emmrich@icloud.com?subject=Restock%20Support") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Support kontaktieren", systemImage: "envelope")
                            .foregroundStyle(.primary)
                    }
                }

                if developerMode {
                    Section {
                        NavigationLink {
                            FeedbackListView()
                        } label: {
                            Label("Feedback", systemImage: "hand.thumbsdown")
                        }

                        NavigationLink {
                            TodoListView()
                        } label: {
                            Label("Todos & Ideen", systemImage: "checklist")
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
            .sheet(isPresented: $showJoinStore) { JoinStoreSheet() }
            .sheet(isPresented: $showPaywall) { PaywallView(context: paywallContext) }
            .sheet(isPresented: $showFeedback) {
                FeedbackView()
            }
            .sheet(isPresented: $showDevPasswordPrompt) {
                DevPasswordSheet(
                    passwordHash: devPasswordHash,
                    onUnlock: {
                        developerMode = true
                        showDevPasswordPrompt = false
                        Haptics.impact(.heavy)
                    },
                    onCancel: { showDevPasswordPrompt = false }
                )
                .presentationDetents([.height(220)])
            }
            .task {
                // Downgrade the stored preference if system permission was revoked in the
                // meantime (system Settings app) — but never auto-enable against the user's
                // explicit choice to keep the toggle off.
                if notificationsEnabled, await NotificationService.shared.isAuthorized() == false {
                    notificationsEnabled = false
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

private struct DevPasswordSheet: View {
    let passwordHash: String
    let onUnlock: () -> Void
    let onCancel: () -> Void

    @State private var input = ""
    @State private var showError = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("Developer Mode")
                .font(.headline)
            if showError {
                Text("Falsches Passwort")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            SecureField("Passwort", text: $input)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit { verify() }
                .padding(.horizontal)
            HStack(spacing: 16) {
                Button("Abbrechen", role: .cancel) { onCancel() }
                    .frame(maxWidth: .infinity)
                Button("Entsperren") { verify() }
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
                    .disabled(input.isEmpty)
            }
            .padding(.horizontal)
        }
        .padding()
        .onAppear { focused = true }
    }

    private func verify() {
        let hash = SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        if hash == passwordHash {
            onUnlock()
        } else {
            showError = true
            input = ""
        }
    }
}
