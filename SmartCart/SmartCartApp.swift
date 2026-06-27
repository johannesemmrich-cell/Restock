import SwiftUI
import SwiftData
import UIKit
import AppIntents

@main
struct SmartCartApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    let container: ModelContainer
    @StateObject private var premium = PremiumService.shared

    @AppStorage("developerMode") private var developerMode = false

    init() {
        SmartCartShortcuts.updateAppShortcutParameters()
        CloudPreferencesSync.shared.start()

        let schema = Schema(versionedSchema: SchemaV1.self)
        // iOS 26 änderte die Defaults von ModelConfiguration:
        //   vorher (iOS 18): groupContainer = .none, cloudKitDatabase = .none
        //   jetzt  (iOS 26): groupContainer = .automatic, cloudKitDatabase = .automatic
        // .automatic greift auf App-Group und CloudKit zu — schlägt fehl wenn iCloud
        // nicht verfügbar ist. Deshalb immer explizit .none für lokale Configs setzen.
        let localConfig = ModelConfiguration(
            groupContainer: .none,
            cloudKitDatabase: .none
        )

        // 1. CloudKit
        if let c = try? ModelContainer(
            for: schema,
            configurations: ModelConfiguration(
                groupContainer: .none,
                cloudKitDatabase: .private("iCloud.com.johannesemmrich.SmartCart")
            )
        ) {
            container = c
            return
        }

        // 2. Lokaler Store (explizit kein CloudKit, kein Group-Container)
        if let c = try? ModelContainer(for: schema, configurations: localConfig) {
            container = c
            return
        }

        // 3. Store-Dateien löschen + nochmal
        Self.deleteStoreFiles()
        if let c = try? ModelContainer(for: schema, configurations: localConfig) {
            container = c
            return
        }

        // 4. In-Memory — kann nie fehlschlagen
        container = try! ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, groupContainer: .none, cloudKitDatabase: .none)
        )
    }

    private static func deleteStoreFiles() {
        // Normaler App-Container
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            if let contents = try? FileManager.default.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil) {
                for url in contents where url.pathExtension == "store"
                    || url.lastPathComponent.hasSuffix(".store-shm")
                    || url.lastPathComponent.hasSuffix(".store-wal") {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
        // iOS 26: Group-Container (falls SwiftData dort gespeichert hat)
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.johannesemmrich.SmartCart") {
            if let contents = try? FileManager.default.contentsOfDirectory(at: groupURL, includingPropertiesForKeys: nil) {
                for url in contents where url.pathExtension == "store"
                    || url.lastPathComponent.hasSuffix(".store-shm")
                    || url.lastPathComponent.hasSuffix(".store-wal") {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            OnboardingGate()
                .modelContainer(container)
                .environmentObject(premium)
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
