import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("selectedCountry") private var selectedCountry = Locale.current.region?.identifier ?? "DE"

    @State private var selectedStores: Set<String> = []
    @State private var presetStores: [Store] = []
    @State private var step = 0

    var body: some View {
        NavigationStack {
            Group {
                if step == 0 {
                    welcomeStep
                } else if step == 1 {
                    countryStep
                } else {
                    storeStep
                }
            }
            .animation(.easeInOut, value: step)
        }
    }

    // MARK: - Welcome

    private var welcomeStep: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "cart.badge.plus")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)
                    .symbolEffect(.bounce, options: .repeating.speed(0.3))

                Text("SmartCart")
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
            .buttonStyle(.borderedProminent)
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
                                .foregroundStyle(.blue)
                                .fontWeight(.semibold)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedCountry = country.code
                        presetStores = Store.presets(for: country.code)
                        selectedStores = Set(presetStores.map { $0.name })
                    }
                }
            }

            Button {
                if presetStores.isEmpty {
                    presetStores = Store.presets(for: selectedCountry)
                    selectedStores = Set(presetStores.map { $0.name })
                }
                step = 2
            } label: {
                Text(String(localized: "onboarding.country.cta"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .onAppear {
            presetStores = Store.presets(for: selectedCountry)
            selectedStores = Set(presetStores.map { $0.name })
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
                            .foregroundStyle(isSelected ? .blue : Color(.systemGray3))
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
                finishOnboarding()
            } label: {
                Text(String(localized: "onboarding.stores.cta"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(selectedStores.isEmpty)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }

    private func finishOnboarding() {
        for store in presetStores {
            store.isActive = selectedStores.contains(store.name)
            context.insert(store)
        }
        Task {
            _ = await NotificationService.shared.requestPermission()
        }
        hasCompletedOnboarding = true
    }
}

// MARK: - Onboarding strings (added to Localizable.strings separately)
