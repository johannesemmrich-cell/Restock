import SwiftUI
import SwiftData

@main
struct SmartCartApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Store.self, ShoppingItem.self, PurchaseRecord.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            OnboardingGate()
                .modelContainer(container)
        }
    }
}

// Shows country picker on first launch, then HomeView
struct OnboardingGate: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            HomeView()
        } else {
            OnboardingView()
        }
    }
}
