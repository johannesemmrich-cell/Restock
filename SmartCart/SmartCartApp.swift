import SwiftUI
import SwiftData
import UIKit
import AppIntents
import WidgetKit

@main
struct SmartCartApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    let container: ModelContainer
    @StateObject private var premium = PremiumService.shared

    @AppStorage("developerMode") private var developerMode = false

    private static let appGroupID = "group.com.johannesemmrich.SmartCart"

    init() {
        // Runs regardless of which branch below sets `container`, and before any push
        // notification can arrive — a silent push can wake the app in the background without
        // ever presenting the WindowGroup, so this can't wait for a view's `.task` to run.
        defer { SyncCoordinator.shared.modelContext = container.mainContext }

        SmartCartShortcuts.updateAppShortcutParameters()
        CloudPreferencesSync.shared.start()

        // Einmalige Migration: alte Daten aus dem App-Container in den App-Group-Container kopieren.
        // Nötig weil App-Intents (Dynamic Island, Siri) in einem anderen Prozess laufen und
        // nur auf den App-Group-Container zugreifen können, nicht auf den App-eigenen Container.
        Self.migrateStoreToAppGroupIfNeeded()

        let schema = Schema(versionedSchema: SchemaV1.self)
        let groupConfig = ModelConfiguration(
            groupContainer: .identifier(Self.appGroupID),
            cloudKitDatabase: .none
        )

        // 1.+2. CloudKit mit App-Group, sonst lokaler App-Group-Store — über den gemeinsamen
        // Helper, den auch AddShoppingItemIntent und das Homescreen-Widget benutzen, damit
        // alle Prozesse GARANTIERT dieselbe Schema-Deklaration + Fallback-Reihenfolge öffnen
        // (ein Mismatch hier hat historisch echten Datenverlust verursacht, siehe
        // SharedModelContainer.swift).
        if let c = SharedModelContainer.make() {
            container = c
            return
        }

        // 3. Store-Dateien löschen + nochmal. Merkt sich, dass dieser Notfall-Pfad gegriffen hat
        // (.standard, übersteht das Löschen unten) — HomeView zeigt daraufhin einmalig einen
        // Hinweis, statt dass die App danach kommentarlos leer aussieht (siehe SharedModelContainer
        // für den analogen Logging-Mechanismus bei den zwei vorherigen, weniger drastischen Stufen).
        UserDefaults.standard.set(true, forKey: "smartcart.dataResetOccurred")
        Self.deleteStoreFiles()
        if let c = try? ModelContainer(for: schema, configurations: groupConfig) {
            container = c
            return
        }

        // 4. In-Memory — kann nie fehlschlagen
        container = try! ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, groupContainer: .none, cloudKitDatabase: .none)
        )
    }

    // Kopiert vorhandene Store-Dateien aus dem alten App-Container in den App-Group-Container.
    // Läuft nur einmal (wenn der Group-Container noch keine .store-Dateien hat).
    private static func migrateStoreToAppGroupIfNeeded() {
        let fm = FileManager.default
        guard
            let groupURL = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroupID),
            let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return }

        let groupAppSupport = groupURL.appendingPathComponent("Library/Application Support")

        // Bereits migriert wenn im Group-Container schon .store-Dateien existieren
        if let existing = try? fm.contentsOfDirectory(at: groupAppSupport, includingPropertiesForKeys: nil),
           existing.contains(where: { $0.pathExtension == "store" }) { return }

        guard let oldFiles = try? fm.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil) else { return }
        let storeFiles = oldFiles.filter {
            $0.pathExtension == "store" ||
            $0.lastPathComponent.hasSuffix(".store-wal") ||
            $0.lastPathComponent.hasSuffix(".store-shm")
        }
        guard !storeFiles.isEmpty else { return }

        try? fm.createDirectory(at: groupAppSupport, withIntermediateDirectories: true)
        for file in storeFiles {
            try? fm.copyItem(at: file, to: groupAppSupport.appendingPathComponent(file.lastPathComponent))
        }
    }

    /// Not `private`: HomeView's user-triggered Cloud-Reparatur button calls this directly (see
    /// dort) — braucht bewusst ein explizites Antippen statt automatisch zu feuern, da dies
    /// lokale Daten löscht, ausgelöst durch eine Heuristik (`[cloud]`-only-Fehler), die noch
    /// nicht in der Praxis erprobt ist.
    static func deleteStoreFiles() {
        let fm = FileManager.default
        // App-Group-Container (primärer Store-Speicherort)
        if let groupURL = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let groupAppSupport = groupURL.appendingPathComponent("Library/Application Support")
            if let contents = try? fm.contentsOfDirectory(at: groupAppSupport, includingPropertiesForKeys: nil) {
                for url in contents where url.pathExtension == "store"
                    || url.lastPathComponent.hasSuffix(".store-shm")
                    || url.lastPathComponent.hasSuffix(".store-wal") {
                    try? fm.removeItem(at: url)
                }
            }
        }
        // Alter App-Container (Fallback-Cleanup)
        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            if let contents = try? fm.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil) {
                for url in contents where url.pathExtension == "store"
                    || url.lastPathComponent.hasSuffix(".store-shm")
                    || url.lastPathComponent.hasSuffix(".store-wal") {
                    try? fm.removeItem(at: url)
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
                .task {
                    PriceProvenanceMigration.runIfNeeded(context: container.mainContext)
                    await SyncCoordinator.shared.resubscribeAll()
                }
                // App-wide pull for ALL shared stores: immediately on every (re)activation and
                // then every 15s while active. Without this, remote changes only arrived via
                // StoreDetailView's own polling or the (unreliable) CloudKit silent push — on
                // HomeView/AllItemsView nothing pulled at all. `initial: true` covers cold
                // launch, where the phase may already be `.active` before any change fires.
                .onChange(of: scenePhase, initial: true) { _, phase in
                    if phase == .active {
                        SyncCoordinator.shared.startPeriodicPulls()
                        // Falls das Homescreen-Widget Artikel abgehakt hat, während die App
                        // nicht lief: Änderungen liegen nur lokal (die Widget-Extension kann
                        // nicht zu CloudKit pushen) — jetzt einmalig alle geteilten Läden pushen.
                        SyncCoordinator.shared.pushWidgetCheckoffsIfNeeded()
                    } else {
                        SyncCoordinator.shared.stopPeriodicPulls()
                        // Zentraler Reload-Hook: was auch immer in dieser Session hinzugefügt/
                        // gelöscht/umbenannt wurde — beim Verlassen der App zeigt das Widget
                        // den frischen Stand.
                        WidgetCenter.shared.reloadAllTimelines()
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
            .buttonStyle(.pressable)

            Button { developerMode = false } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.black.opacity(0.6))
                    .padding(6)
                    .background(Color.orange.opacity(0.7), in: Circle())
            }
            .buttonStyle(.pressable)
            .padding(.leading, 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .sheet(isPresented: $showFeedback) {
            NavigationStack { FeedbackListView() }
        }
    }
}
