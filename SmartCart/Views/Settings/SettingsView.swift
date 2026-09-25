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
    // Gleicher Key wie HomeView.storeViewModeRaw, damit eine Änderung hier sofort dort
    // (und umgekehrt) wirkt.
    @AppStorage("storeViewMode") private var storeViewModeRaw = StoreViewMode.cards.rawValue

    @EnvironmentObject private var premium: PremiumService
    @State private var showPaywall = false
    @State private var paywallFeature: String = "alle Pro-Features"
    @State private var showFeedback = false
    @State private var showJoinStore = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @State private var versionTapCount = 0
    @State private var lastTapTime: Date = .distantPast
    @State private var showDevPasswordPrompt = false
    @State private var devPasswordInput = ""
    @State private var devPasswordError = false

    private let devPasswordHash = "fab0966f3e9fa7a071e46259d2dfeaddbda732c8bce42a87987740cab51a7c86"

    var body: some View {
        NavigationStack {
            List {
                Section {
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
                } header: {
                    settingsHeader(String(localized: "settings.profile.section"))
                }
                .listRowBackground(Color.surface)

                Section {
                    HStack(spacing: 12) {
                        Text("Läden-Ansicht")
                        Spacer()
                        Picker("Läden-Ansicht", selection: $storeViewModeRaw) {
                            Text("Karten").tag(StoreViewMode.cards.rawValue)
                            Text("Liste").tag(StoreViewMode.list.rawValue)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                    }
                    .padding(.vertical, 2)
                } header: {
                    settingsHeader("Darstellung")
                }
                .listRowBackground(Color.surface)

                Section {
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
                } header: {
                    settingsHeader(String(localized: "settings.region"))
                }
                .listRowBackground(Color.surface)

                Section {
                    Toggle("Saisonale Vorschläge", isOn: $seasonalSuggestionsEnabled)
                    NavigationLink {
                        SiriSettingsView()
                    } label: {
                        Text("Siri & Schnellzugriff")
                    }
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Text("Benachrichtigungen")
                    }
                    NavigationLink {
                        DefaultStoresSettingsView()
                    } label: {
                        Text("Standard-Läden")
                    }
                } header: {
                    settingsHeader("Funktionen")
                }
                .listRowBackground(Color.surface)

                Section {
                    if premium.hasPremiumAccess {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Pro aktiv")
                                    .font(.system(size: 15, weight: .medium))
                                Text("Ausgaben-Analyse & Rezeptplan freigeschaltet")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(String(localized: "settings.pro.manage")) {
                                if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .buttonStyle(.pressable)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    } else {
                        Button {
                            Haptics.impact(.light)
                            paywallFeature = "alle Pro-Features"
                            showPaywall = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.accent)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Restock Pro freischalten")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(.primary)
                                    Text("Ausgaben-Analyse & Rezeptplan")
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
                        .buttonStyle(.pressable)
                    }

                    Button {
                        showJoinStore = true
                    } label: {
                        Label(String(localized: "home.join.shared"), systemImage: "person.badge.plus")
                    }
                } header: {
                    settingsHeader("Daten")
                }
                .listRowBackground(Color.surface)

                Section {
                    Button {
                        showFeedback = true
                    } label: {
                        HStack {
                            Text(String(localized: "settings.feedback.button"))
                                .foregroundStyle(Color.ink)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.textSecondary.opacity(0.6))
                        }
                    }
                    .buttonStyle(.pressable)

                    Button {
                        if let url = URL(string: "mailto:support@emmrich-business.com?subject=Restock%20Support") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Text("Support kontaktieren")
                                .foregroundStyle(Color.ink)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.textSecondary.opacity(0.6))
                        }
                    }
                    .buttonStyle(.pressable)

                    NavigationLink {
                        LegalOverviewView()
                    } label: {
                        Text("Rechtliches")
                    }

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
                } header: {
                    settingsHeader("Support")
                }
                .listRowBackground(Color.surface)

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

                        NavigationLink {
                            ReplenishmentStatsView()
                        } label: {
                            Label("Nachkauf-Statistik", systemImage: "chart.bar.xaxis")
                        }

                        NavigationLink {
                            HiddenReplenishmentsView()
                        } label: {
                            Label("Ausgeblendete Vorschläge", systemImage: "eye.slash")
                        }

                        Button(role: .destructive) {
                            developerMode = false
                            // Nachkauf-Erinnerungen sind außerhalb des Dev-Mode kein Feature mehr
                            // (siehe HomeView.refreshDueSoon) — bereits für frühere due-soon-Items
                            // geplante, noch ausstehende Benachrichtigungen sonst würden trotzdem
                            // feuern, obwohl das Feature jetzt komplett inaktiv sein soll.
                            NotificationService.shared.cancelAll()
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

                Section {
                    emmrichAppsFooter
                }
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .background(Color.canvas)
            .tint(Color.accent)
            .navigationTitle(String(localized: "settings.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ChipToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text(String(localized: "action.done")).toolbarChip() }
                        .buttonStyle(.pressable)
                }
            }
            .sheet(isPresented: $showJoinStore) { JoinStoreSheet() }
            .sheet(isPresented: $showPaywall) { PaywallView(feature: paywallFeature) }
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

    private func settingsHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(Color.textSecondary)
    }

    // MARK: - Emmrich Apps footer

    private var emmrichAppsFooter: some View {
        VStack(spacing: 8) {
            Button {
                if let url = URL(string: "https://emmrich-business.com") {
                    UIApplication.shared.open(url)
                }
            } label: {
                VStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Rectangle().frame(width: 15, height: 2.5)
                        Rectangle().frame(width: 10, height: 2.5)
                        Rectangle().frame(width: 15, height: 2.5)
                    }
                    .foregroundStyle(Color(hex: "#A98E5B") ?? Color.textSecondary)

                    Text("Emmrich Apps")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.ink)
                    Text("Dresslyst · Restock · Sunwake")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .buttonStyle(.pressable)

            Text("Restock \(appVersionString)")
                .font(.system(size: 9.5))
                .foregroundStyle(Color.textSecondary.opacity(0.7))
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func seedStores(for countryCode: String) {
        guard allStores.filter({ $0.countryCode == countryCode }).isEmpty else { return }
        for store in Store.presets(for: countryCode) {
            context.insert(store)
        }
    }
}

// MARK: - Funktionen-Unterseiten (Inhalte 1:1 aus den früheren Inline-Sektionen)

struct NotificationSettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("autoSortByLearnedOrder", store: UserDefaults(suiteName: "group.com.johannesemmrich.SmartCart"))
    private var autoSortByLearnedOrder = true
    @AppStorage("developerMode") private var developerMode = false

    var body: some View {
        List {
            Section {
                // Nachkauf-Erinnerungen sind kein Feature der normalen Version mehr — der Toggle
                // (und die dahinterliegende Planung in HomeView.refreshDueSoon) existiert nur noch
                // im Developer Mode.
                if developerMode {
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
                VStack(alignment: .leading, spacing: 2) {
                    Toggle("Automatisch nach Einkaufsreihenfolge sortieren", isOn: $autoSortByLearnedOrder)
                    Text("Restock merkt sich, in welcher Reihenfolge du Artikel abhakst, und sortiert die Liste beim nächsten Mal entsprechend.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
            .listRowBackground(Color.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Color.canvas)
        .tint(Color.accent)
        .navigationTitle("Benachrichtigungen")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Lässt den Nutzer pro Kategorie-Gruppe (dieselben vier, die `AssignmentService.assign` per
/// Keyword-Suche unterscheidet) einen festen Standard-Laden wählen — greift dort über
/// `DefaultStoreService` VOR der automatischen Kaufhistorie-/Besuchsfrequenz-Heuristik. Siehe
/// `DefaultStoreService` für den auslösenden Nutzerbericht (14.09.2026).
struct DefaultStoresSettingsView: View {
    @Query(filter: #Predicate<Store> { $0.isActive }, sort: \Store.sortIndex) private var activeStores: [Store]
    @State private var selections: [String: String] = [:]

    private let groups: [(key: String, label: String, categories: [String])] = [
        ("grocery", "Lebensmittel", Category.grocery),
        ("drugstore", "Drogerie", Category.drugstore),
        ("variety", "Sonstiges (Elektronik, Haushalt, Deko …)", Category.variety),
        ("hardware", "Baumarkt & Garten", Category.hardware),
    ]

    var body: some View {
        List {
            Section {
                Text("Lege pro Kategorie einen festen Laden fest, zu dem neue Artikel hinzugefügt werden, wenn Restock sie nicht eindeutig zuordnen kann. Das hat Vorrang vor der automatischen Zuordnung anhand deiner bisherigen Käufe.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 2)
            }
            .listRowBackground(Color.surface)

            Section {
                ForEach(groups, id: \.key) { group in
                    let candidates = activeStores.filter { store in
                        store.categories.contains(where: { group.categories.contains($0) })
                    }
                    Picker(group.label, selection: binding(for: group.key)) {
                        Text("Automatisch").tag("")
                        ForEach(candidates) { store in
                            Text("\(store.emoji) \(store.name)").tag(store.name)
                        }
                    }
                    .disabled(candidates.isEmpty)
                }
            }
            .listRowBackground(Color.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Color.canvas)
        .tint(Color.accent)
        .navigationTitle("Standard-Läden")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            for group in groups {
                selections[group.key] = DefaultStoreService.shared.storeName(for: group.key) ?? ""
            }
        }
    }

    private func binding(for groupKey: String) -> Binding<String> {
        Binding(
            get: { selections[groupKey] ?? "" },
            set: { newValue in
                selections[groupKey] = newValue
                DefaultStoreService.shared.setStoreName(newValue.isEmpty ? nil : newValue, for: groupKey)
            }
        )
    }
}

struct SiriSettingsView: View {
    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.accent)
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
                        .foregroundStyle(Color.accent)
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
                        .foregroundStyle(Color.accent)
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
                            .foregroundStyle(Color.accent)
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
                .buttonStyle(.pressable)
            }
            .listRowBackground(Color.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Color.canvas)
        .navigationTitle("Siri & Schnellzugriff")
        .navigationBarTitleDisplayMode(.inline)
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
                    .buttonStyle(.pressable)
                    .frame(maxWidth: .infinity)
                Button("Entsperren") { verify() }
                    .buttonStyle(.pressable)
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
