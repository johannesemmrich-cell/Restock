import SwiftUI
import SwiftData
import UIKit

@main
struct SmartCartApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    let container: ModelContainer

    @AppStorage("developerMode") private var developerMode = false

    init() {
        CloudPreferencesSync.shared.start()

        let schema = Schema(versionedSchema: SchemaV1.self)
        let cloudConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .private("iCloud.com.johannesemmrich.SmartCart"))
        let localConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            container = try ModelContainer(for: schema, migrationPlan: SmartCartMigrationPlan.self, configurations: cloudConfig)
        } catch {
            // CloudKit nicht verfügbar — lokaler Fallback
            do {
                container = try ModelContainer(for: schema, migrationPlan: SmartCartMigrationPlan.self, configurations: localConfig)
            } catch {
                // Store-Korruption — löschen und neu anlegen
                Self.deleteStoreFiles()
                do {
                    container = try ModelContainer(for: schema, migrationPlan: SmartCartMigrationPlan.self, configurations: localConfig)
                } catch {
                    fatalError("Failed to create ModelContainer: \(error)")
                }
            }
        }
    }

    private static func deleteStoreFiles() {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        for name in ["default", "SmartCartCloud"] {
            for ext in ["store", "store-shm", "store-wal"] {
                try? FileManager.default.removeItem(at: appSupport.appendingPathComponent("\(name).\(ext)"))
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            OnboardingGate()
                .modelContainer(container)
                .safeAreaInset(edge: .top) {
                    if developerMode {
                        DevModeIndicator()
                    }
                }
        }
    }
}

// MARK: - Onboarding Gate

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
    @AppStorage("developerMode") private var developerMode = false
    @Query(filter: #Predicate<FeedbackItem> { !$0.isResolved })
    private var openFeedback: [FeedbackItem]
    @State private var showFeedback = false

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            Button { showFeedback = true } label: {
                HStack(spacing: 5) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("DEV")
                        .font(.system(size: 10, weight: .bold))
                    if !openFeedback.isEmpty {
                        Text("\(openFeedback.count)")
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

            Button { developerMode = false } label: {
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
        .sheet(isPresented: $showFeedback) {
            NavigationStack { FeedbackListView() }
        }
    }
}
