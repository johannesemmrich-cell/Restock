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
        HStack(spacing: 8) {
            Image(systemName: "hammer.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.black.opacity(0.8))
            Text("DEVELOPER MODE")
                .font(.caption.weight(.bold))
                .foregroundStyle(.black.opacity(0.8))

            Spacer()

            if openCount > 0 {
                Text("\(openCount)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red, in: Capsule())
            }

            Button {
                onDeactivate()
            } label: {
                Text("✕")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.black.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.15), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Color.orange)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}
