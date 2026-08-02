import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("selectedCountry") private var selectedCountry = Locale.current.region?.identifier ?? "DE"
    @AppStorage(UserIdentity.storageKey, store: UserDefaults(suiteName: "group.com.johannesemmrich.SmartCart"))
    private var userDisplayName = ""
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true

    @State private var selectedStores: Set<String> = []
    @State private var presetStores: [Store] = []
    @State private var step = 0
    @State private var nameInput = ""
    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if step == 0 {
                    welcomeStep
                } else if step == 1 {
                    nameStep
                } else if step == 2 {
                    countryStep
                } else if step == 3 {
                    storeStep
                } else {
                    tutorialStep
                }
            }
            .animation(.easeInOut, value: step)
        }
    }

    // MARK: - Name

    private var nameStep: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Color.accent)

                VStack(spacing: 8) {
                    Text(String(localized: "onboarding.name.title"))
                        .font(.title2.bold())
                    Text(String(localized: "onboarding.name.subtitle"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                TextField(String(localized: "onboarding.name.placeholder"), text: $nameInput)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($isNameFocused)
                    .font(.system(size: 20, weight: .medium))
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.surface, in: RoundedRectangle(cornerRadius: RCRadius.control))
                    .overlay(RoundedRectangle(cornerRadius: RCRadius.control).strokeBorder(Color.hairline))
                    .padding(.horizontal, 32)
                    .submitLabel(.done)
                    .onSubmit { confirmName() }
            }
            Spacer()
            Button {
                confirmName()
            } label: {
                Text(String(localized: "onboarding.name.cta"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.restockPrimary)
            .controlSize(.large)
            .disabled(nameInput.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .onAppear {
            nameInput = userDisplayName
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { isNameFocused = true }
        }
    }

    private func confirmName() {
        let trimmed = nameInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        userDisplayName = trimmed
        step = 2
    }

    // MARK: - Welcome

    private var welcomeStep: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "cart.badge.plus")
                    .font(.system(size: 80))
                    .foregroundStyle(Color.accent)
                    .symbolEffect(.bounce, options: .repeating.speed(0.3))

                Text("Restock")
                    .font(.system(size: 36, weight: .bold))

                Text(String(localized: "onboarding.welcome.subtitle"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
            Button {
                step = 1
            } label: {
                Text(String(localized: "onboarding.welcome.cta"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.restockPrimary)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Country

    private var countryStep: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text(String(localized: "onboarding.country.title"))
                    .font(.title2)
                    .fontWeight(.bold)
                Text(String(localized: "onboarding.country.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 24)

            List {
                ForEach(Store.availableCountries, id: \.code) { country in
                    HStack {
                        Text(country.flag)
                            .font(.system(size: 28))
                        Text(country.name)
                            .font(.system(size: 17))
                        Spacer()
                        if selectedCountry == country.code {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accent)
                                .fontWeight(.semibold)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedCountry = country.code
                        presetStores = Store.presets(for: country.code)
                        selectedStores = []
                    }
                }
            }

            Button {
                if presetStores.isEmpty {
                    presetStores = Store.presets(for: selectedCountry)
                    selectedStores = []
                }
                step = 3
            } label: {
                Text(String(localized: "onboarding.country.cta"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.restockPrimary)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .onAppear {
            presetStores = Store.presets(for: selectedCountry)
            selectedStores = []
        }
    }

    // MARK: - Store selection

    private var storeStep: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text(String(localized: "onboarding.stores.title"))
                    .font(.title2)
                    .fontWeight(.bold)
                Text(String(localized: "onboarding.stores.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 24)

            if !presetStores.isEmpty {
                HStack {
                    Spacer()
                    Button {
                        if selectedStores.count == presetStores.count {
                            selectedStores = []
                        } else {
                            selectedStores = Set(presetStores.map { $0.name })
                        }
                    } label: {
                        Text(selectedStores.count == presetStores.count ? "Auswahl aufheben" : "Alle auswählen")
                            .font(.subheadline)
                    }
                    .buttonStyle(.pressable)
                }
                .padding(.horizontal, 24)
            }

            List {
                ForEach(presetStores) { store in
                    let isSelected = selectedStores.contains(store.name)
                    HStack {
                        Text(store.emoji)
                            .font(.system(size: 24))
                        Text(store.name)
                            .font(.system(size: 17))
                        Spacer()
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? Color.accent : Color.hairlineStrong)
                            .font(.system(size: 22))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isSelected {
                            selectedStores.remove(store.name)
                        } else {
                            selectedStores.insert(store.name)
                        }
                    }
                }
            }

            Button {
                step = 4
            } label: {
                Text(String(localized: "onboarding.stores.cta"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.restockPrimary)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Tutorial

    private var tutorialStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 8) {
                        Text("So funktioniert Restock")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Zwei Funktionen, die dir am meisten Zeit sparen")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    TutorialCard(
                        icon: "plus.circle.fill",
                        iconColor: Color.accent,
                        title: "Schnell hinzufügen",
                        description: "Tippe einfach ein, was du brauchst — Restock erkennt Menge und Einheit automatisch.\n\nBeispiele: \"500g Hackfleisch\", \"2 Liter Milch\", \"3 Äpfel\""
                    )

                    TutorialCard(
                        icon: "camera.viewfinder",
                        iconColor: .purple,
                        title: "Kassenbon scannen",
                        description: "Fotografiere deinen Kassenbon in der Einkaufsliste. Restock liest die Artikel und Preise automatisch aus und lernt damit, was welches Produkt kostet."
                    )

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
            }

            Button {
                finishOnboarding()
            } label: {
                Text("Los geht's!")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.restockPrimary)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }

    private func finishOnboarding() {
        for store in presetStores {
            store.isActive = selectedStores.contains(store.name)
            context.insert(store)
        }
        // Flush sofort, bevor HomeView direkt im Anschluss frisch gemountet wird — sonst könnte
        // dessen erster @Query-Fetch je nach Autosave-Timing noch den alten Stand sehen.
        try? context.save()
        Task {
            notificationsEnabled = await NotificationService.shared.requestPermission()
        }
        hasCompletedOnboarding = true
    }
}

private struct TutorialCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(iconColor)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Text(description)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: RCRadius.card))
        .overlay(RoundedRectangle(cornerRadius: RCRadius.card).strokeBorder(Color.hairline))
    }
}

// MARK: - Onboarding strings (added to Localizable.strings separately)
