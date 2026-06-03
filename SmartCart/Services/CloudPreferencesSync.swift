import Foundation

/// Mirrors a curated subset of UserDefaults to NSUbiquitousKeyValueStore so that
/// settings, the menu plan, and saved recipes survive a device switch on the same Apple ID.
/// SwiftData models (Stores, Items, PurchaseRecords) are handled separately via CloudKit.
final class CloudPreferencesSync {
    static let shared = CloudPreferencesSync()
    private init() {}

    private let kv = NSUbiquitousKeyValueStore.default
    private let ud = UserDefaults.standard

    private let fixedKeys: Set<String> = [
        "menuPlanJSON",
        "menuIngredientsJSON",
        "savedRecipesJSON",
        "selectedCountry",
        "selectedLanguage",
        "currencyCode",
        "seasonalSuggestionsEnabled",
        "hasCompletedOnboarding",
    ]

    // Dynamic-key prefixes — e.g. "shareID_<uuid>", "isSharedByMe_<uuid>", "lastSync_<shareID>"
    private let syncedPrefixes = ["shareID_", "isSharedByMe_", "lastSync_"]

    private var ignoreUD = false
    private var pendingPush: DispatchWorkItem?

    // MARK: - Start

    func start() {
        // Pull: fill any empty local slots from iCloud (device-switch case)
        ignoreUD = true
        for (key, value) in kv.dictionaryRepresentation where isSynced(key) {
            if ud.object(forKey: key) == nil {
                ud.set(value, forKey: key)
            }
        }
        ignoreUD = false

        // Push: ensure iCloud reflects this device's current state
        for (key, value) in ud.dictionaryRepresentation() where isSynced(key) {
            kv.set(value, forKey: key)
        }
        kv.synchronize()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudChanged(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kv
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(udChanged),
            name: UserDefaults.didChangeNotification,
            object: ud
        )
    }

    // MARK: - Handlers

    @objc private func iCloudChanged(_ note: Notification) {
        guard let keys = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else { return }
        ignoreUD = true
        defer { ignoreUD = false }
        for key in keys where isSynced(key) {
            if let v = kv.object(forKey: key) { ud.set(v, forKey: key) }
            else { ud.removeObject(forKey: key) }
        }
    }

    // Debounced: UserDefaults fires constantly; we batch pushes into a single write 0.5 s later.
    @objc private func udChanged() {
        guard !ignoreUD else { return }
        pendingPush?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            for (key, value) in self.ud.dictionaryRepresentation() where self.isSynced(key) {
                self.kv.set(value, forKey: key)
            }
            self.kv.synchronize()
        }
        pendingPush = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    // MARK: - Helper

    private func isSynced(_ key: String) -> Bool {
        fixedKeys.contains(key) || syncedPrefixes.contains(where: { key.hasPrefix($0) })
    }
}
