import SwiftUI
import SwiftData

@main
struct SmartCartApp: App {
    let container: ModelContainer

    @AppStorage("developerMode") private var developerMode = false
    @AppStorage("devFeedbackItems") private var storedData = Data()
    @State private var showDevFeedbackList = false

    init() {
        do {
            container = try ModelContainer(for: Store.self, ShoppingItem.self, PurchaseRecord.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    private var openFeedbackCount: Int {
        let items = (try? JSONDecoder().decode([DevFeedbackItem].self, from: storedData)) ?? []
        return items.filter { !$0.isResolved }.count
    }

    var body: some Scene {
        WindowGroup {
            OnboardingGate()
                .modelContainer(container)
                .safeAreaInset(edge: .top) {
                    if developerMode {
                        DevModeIndicator(
                            openCount: openFeedbackCount,
                            onTap: { showDevFeedbackList = true },
                            onDeactivate: { developerMode = false }
                        )
                    }
                }
                .sheet(isPresented: $showDevFeedbackList) {
                    NavigationStack {
                        FeedbackListView()
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button("Fertig") { showDevFeedbackList = false }
                                }
                            }
                    }
                }
        }
    }
}

// MARK: - Onboarding Gate

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

// MARK: - Dev Mode Indicator

private struct DevModeIndicator: View {
    let openCount: Int
    let onTap: () -> Void
    let onDeactivate: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            Button(action: onTap) {
                HStack(spacing: 5) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("DEV")
                        .font(.system(size: 10, weight: .bold))
                    if openCount > 0 {
                        Text("\(openCount)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.red, in: Capsule())
                    }
                }
                .foregroundStyle(.black.opacity(0.75))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.orange, in: Capsule())
            }
            .buttonStyle(.plain)

            Button(action: onDeactivate) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.black.opacity(0.6))
                    .padding(6)
                    .background(Color.orange.opacity(0.7), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}
