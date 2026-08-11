import CloudKit
import Foundation
import Observation
import SwiftData
import WidgetKit

/// Central place that applies remote shared-store state (items + members) onto the local
/// SwiftData store. Used by StoreDetailView's pull/push cycle, JoinStoreSheet, and the
/// CloudKit push-notification handler in AppDelegate so all three paths merge consistently.
///
/// `@Observable` so views can depend on `applyGeneration` (see below) — the deterministic
/// "remote changes just landed" signal for the category-grouped list views.
@MainActor
@Observable
final class SyncCoordinator {
    static let shared = SyncCoordinator()
    private init() {}

    /// Set once at app launch (`SmartCartApp.init`) so the push-notification handler,
    /// which has no view hierarchy, can still look up and update SwiftData stores.
    @ObservationIgnored var modelContext: ModelContext?

    /// Monotonic counter, bumped every time `apply()` actually persists remote state into the
    /// local SwiftData store. The category-grouped views (StoreDetailView's grouped sections,
    /// HomeView's category list, AllItemsView) read this in `body` so a remote category/name
    /// change reliably re-runs their section derivation. Without it they can miss the change:
    /// the per-row category caption lives in `ItemRow` (its own observation scope, updates fine),
    /// but the parent view's section assignment isn't reliably invalidated by the sync's model
    /// mutation — and `AllItemsView`'s `@Query` predicate (`isCompleted == false`) is untouched
    /// by a category edit, so the query itself never signals either. Symptom this fixes: the
    /// item already shows the new category when opened in EditItemView, yet still sits in its
    /// old section in the list.
    private(set) var applyGeneration = 0

    enum SyncFailureKind {
        case permissionDenied   // CKError.permissionFailure: server rejected the write (schema security roles)
        case notAuthenticated   // no iCloud account signed in on this device
        case other
    }

    /// Why the most recent `pull`/`push` returned `false`. Purely diagnostic — lets the sync
    /// banner distinguish "no network right now" from "the server permanently rejects writes
    /// from this account", which would otherwise look identical and be nearly undebuggable
    /// from a TestFlight report.
    private(set) var lastFailureKind: SyncFailureKind = .other

    private func classify(_ error: Error) -> SyncFailureKind {
        guard let ck = error as? CKError else { return .other }
        switch ck.code {
        case .permissionFailure: return .permissionDenied
        case .notAuthenticated:  return .notAuthenticated
        case .partialFailure:
            let partial = ck.partialErrorsByItemID?.values.compactMap { $0 as? CKError } ?? []
            if partial.contains(where: { $0.code == .permissionFailure }) { return .permissionDenied }
            if partial.contains(where: { $0.code == .notAuthenticated }) { return .notAuthenticated }
            return .other
        default: return .other
        }
    }

    /// Pulls remote state for a shared store (if newer) and merges it into the local store.
    ///
    /// Returns `true` if the pull succeeded or there was legitimately nothing new to fetch,
    /// and `false` only if `SharedStoreService` actually threw (e.g. a CKError) — callers use
    /// this to surface sync failures in the UI without treating "nothing changed" as one.
    @discardableResult
    func pull(store: Store) async -> Bool {
        guard let shareID = store.shareID else { return true }
        do {
            guard let result = try await SharedStoreService.shared.pull(shareID: shareID) else { return true }
            await apply(items: result.items, members: result.members, deletedIDs: result.deletedIDs, prices: result.prices, priceDates: result.priceDates, modifiedAt: result.modifiedAt, to: store)
            return true
        } catch {
            lastFailureKind = classify(error)
            return false
        }
    }

    /// Pulls+merges remote state, pushes the merged result back so no other device's addition
    /// gets clobbered, then applies that same merged result locally — all in one round trip.
    ///
    /// Returns `true` if the push succeeded or there was nothing to push, `false` only if
    /// `SharedStoreService` actually threw.
    @discardableResult
    func push(store: Store) async -> Bool {
        guard let shareID = store.shareID, !shareID.isEmpty else { return true }
        do {
            guard let result = try await SharedStoreService.shared.push(store: store) else { return true }
            // syncToCloud's save already advanced the watermark to the server's modificationDate
            // (see SharedStoreService.markSynced), so apply() shouldn't override it here.
            await apply(items: result.items, members: result.members, deletedIDs: result.deletedIDs, prices: result.prices, priceDates: result.priceDates, modifiedAt: nil, to: store)
            return true
        } catch {
            lastFailureKind = classify(error)
            return false
        }
    }

    /// Fire-and-forget push for call sites that mutate shared-store items without an existing
    /// sync-failure UI (e.g. HomeView's quick-add, "Alle Artikel", Menüplan, recipe import) —
    /// unlike StoreDetailView, which tracks and surfaces push failures via a banner. No-ops for
    /// stores that aren't shared. Errors are swallowed: the mutation is already saved locally and
    /// will be included in whatever push happens next (an explicit push elsewhere, or the next
    /// periodic pull-triggered merge), so a failed opportunistic push here only delays
    /// propagation to other members — it doesn't lose data.
    func pushInBackground(_ stores: [Store?]) {
        let sharedStores = Set(stores.compactMap { $0 }).filter { $0.shareID != nil }
        guard !sharedStores.isEmpty else { return }
        Task {
            for store in sharedStores {
                await push(store: store)
            }
        }
    }

    func pushInBackground(_ store: Store?) {
        pushInBackground([store])
    }

    /// One-shot push of ALL shared stores after the homescreen widget checked items off while
    /// the app wasn't running. The widget extension writes straight into the local SwiftData
    /// store but cannot reach CloudKit itself — and it also cannot even tell WHICH stores are
    /// shared (`Store.shareID` lives in the main app's `UserDefaults.standard`, invisible to
    /// the extension process). So the widget just raises an app-group flag and the next app
    /// activation pushes every shared store once. `push` is a pull-merge-push round trip, and
    /// the widget's `lastModified` bump wins last-write-wins in `apply()`, so the checkoff
    /// can't be clobbered by the merge. Cheap no-op when the flag isn't set.
    func pushWidgetCheckoffsIfNeeded() {
        let defaults = UserDefaults(suiteName: SharedModelContainer.appGroupID)
        guard defaults?.bool(forKey: "widgetDidCheckOffItem") == true else { return }
        guard let context = modelContext else { return }
        guard let stores = try? context.fetch(FetchDescriptor<Store>()) else { return }
        let sharedStores = stores.filter { $0.shareID != nil }
        guard !sharedStores.isEmpty else {
            // Nothing shared → nothing to push, flag served its purpose.
            defaults?.removeObject(forKey: "widgetDidCheckOffItem")
            return
        }
        // Clear the flag only AFTER every shared store pushed successfully. Offline or a
        // CK error → flag stays set and the next app activation retries; clearing upfront
        // would silently drop the widget checkoff's propagation to other members.
        Task {
            var allSucceeded = true
            for store in sharedStores {
                let ok = await push(store: store)
                if !ok { allSucceeded = false }
            }
            if allSucceeded {
                defaults?.removeObject(forKey: "widgetDidCheckOffItem")
            }
        }
    }

    /// Looks up a locally known store by its CloudKit shareID and pulls its latest state.
    /// Entry point for the silent-push notification handler.
    func pullStore(shareID: String) async {
        guard let context = modelContext else { return }
        guard let stores = try? context.fetch(FetchDescriptor<Store>()) else { return }
        guard let store = stores.first(where: { $0.shareID == shareID }) else { return }
        await pull(store: store)
    }

    // MARK: - App-wide periodic pull

    @ObservationIgnored private var periodicPullTask: Task<Void, Never>?

    /// Pulls the latest remote state for every shared store this device knows about.
    /// Cheap when nothing changed: `SharedStoreService.pull` compares the server record's
    /// `modificationDate` against the per-store watermark and returns nil without merging.
    func pullAllSharedStores() async {
        guard let context = modelContext else { return }
        guard let stores = try? context.fetch(FetchDescriptor<Store>()) else { return }
        for store in stores where store.shareID != nil {
            await pull(store: store)
        }
    }

    /// App-wide polling loop for ALL shared stores, running whenever the app is active
    /// (started/stopped from `SmartCartApp` on scenePhase changes). Closes the gap where
    /// remote changes only ever arrived via the CloudKit silent push (which iOS may throttle or
    /// drop entirely): on HomeView / AllItemsView / anywhere else, nothing pulled at all, so
    /// another member's edit could take arbitrarily long to show up. The first iteration pulls
    /// immediately, so returning to the foreground also fetches right away. 15s keeps the extra
    /// public-database traffic modest since this loop multiplies across every shared store.
    /// StoreDetailView no longer runs its own additional local loop on top of this one (removed
    /// as a perf fix — it was a pure duplicate of this app-wide loop while a shared list was open).
    func startPeriodicPulls() {
        guard periodicPullTask == nil else { return }
        periodicPullTask = Task {
            while !Task.isCancelled {
                await pullAllSharedStores()
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    func stopPeriodicPulls() {
        periodicPullTask?.cancel()
        periodicPullTask = nil
    }

    /// Re-registers push subscriptions for every store this device currently shares or has
    /// joined. Called at app launch since subscriptions aren't guaranteed to survive a
    /// reinstall/data reset even though CloudKit persists them server-side otherwise.
    func resubscribeAll() async {
        guard let context = modelContext else { return }
        guard let stores = try? context.fetch(FetchDescriptor<Store>()) else { return }
        for store in stores {
            guard let shareID = store.shareID else { continue }
            do { try await SharedStoreService.shared.subscribe(shareID: shareID) }
            catch { print("[SyncCoordinator] resubscribeAll failed for shareID \(shareID): \(error)") }
        }
    }

    /// Applies remote items/members onto `store` and, only once that's actually persisted,
    /// advances the sync watermark — so a save failure or a killed app doesn't leave the
    /// watermark ahead of what was really applied (which would make the next pull skip the
    /// merge that was supposed to fix things).
    ///
    /// `deletedIDs` must be an explicit tombstone set, not "everything absent from `remoteItems`".
    /// A local item can legitimately be absent from a given remote snapshot simply because this
    /// device hasn't pushed it yet (e.g. a periodic pull racing ahead of an in-flight push) —
    /// deleting on mere absence would destroy that not-yet-synced item. Only delete what's
    /// explicitly confirmed deleted (locally or by another device) via the tombstone list.
    ///
    /// `modifiedAt` is the server's `modificationDate` for this remote state, used to advance the
    /// sync watermark to server time rather than this device's local clock. Pass `nil` when the
    /// caller (e.g. a push) already advanced the watermark itself via `SharedStoreService.markSynced`.
    func apply(items remoteItems: [SharedItemData], members: [String], deletedIDs: Set<UUID> = [], prices: [String: Double] = [:], priceDates: [String: Date] = [:], modifiedAt: Date?, to store: Store) async {
        guard let context = modelContext ?? store.modelContext else { return }

        for name in members { store.addMember(name) }

        // Last-write-wins pro Preis-Schlüssel, exakt dasselbe Prinzip wie der Item-Merge direkt
        // unten (dort per `lastModified`, hier per `learnedPriceDates`) — ein Schlüssel, der nur
        // remote existiert, wird einfach übernommen (`localDate` defaultet auf `.distantPast`).
        for (key, remotePrice) in prices {
            let remoteDate = priceDates[key] ?? .distantPast
            let localDate = store.learnedPriceDates[key] ?? .distantPast
            guard remoteDate >= localDate else { continue }
            store.learnedPrices[key] = remotePrice
            store.learnedPriceDates[key] = remoteDate
        }

        let localByID = Dictionary(uniqueKeysWithValues: (store.items ?? []).map { ($0.id, $0) })

        for item in (store.items ?? []) where deletedIDs.contains(item.id) {
            context.delete(item)
        }

        for remote in remoteItems {
            if let local = localByID[remote.id] {
                // Last-write-wins: don't let an older remote snapshot overwrite a newer local edit.
                guard remote.lastModified >= local.lastModified else { continue }
                local.name = remote.name
                local.isCompleted = remote.isCompleted
                local.isUrgent = remote.isUrgent
                local.quantity = remote.quantity
                local.quantityAmount = remote.quantityAmount
                local.unit = remote.unit
                local.note = remote.note
                local.category = remote.category
                local.categoryManuallySet = remote.categoryManuallySet
                local.assignedTo = remote.assignedTo
                local.addedBy = remote.addedBy
                local.completedBy = remote.completedBy
                local.lastModified = remote.lastModified
                // Only the flag travels here — actual bytes are fetched lazily and separately by
                // `SharedItemPhotoService`, never as part of this hot-path merge.
                local.hasPhoto = remote.hasPhoto
            } else {
                let item = ShoppingItem(
                    name: remote.name, category: remote.category,
                    quantity: remote.quantity, quantityAmount: remote.quantityAmount,
                    unit: remote.unit, note: remote.note, store: store
                )
                item.id = remote.id
                item.categoryManuallySet = remote.categoryManuallySet
                item.isCompleted = remote.isCompleted
                item.isUrgent = remote.isUrgent
                item.assignedTo = remote.assignedTo
                item.addedBy = remote.addedBy
                item.completedBy = remote.completedBy
                item.lastModified = remote.lastModified
                item.hasPhoto = remote.hasPhoto
                context.insert(item)
            }
        }

        do {
            try context.save()
            // Only after a successful save: views depending on this must never re-render into
            // state that wasn't actually persisted (a failed save leaves the merge un-applied).
            applyGeneration += 1
            // Central widget-reload hook for everything that arrives via sync: another member's
            // add/checkoff/delete has just been persisted, so the homescreen widget must refresh.
            WidgetCenter.shared.reloadAllTimelines()
            if let shareID = store.shareID, let modifiedAt {
                await SharedStoreService.shared.markSynced(shareID: shareID, at: modifiedAt)
            }
        } catch {
            // Leave the watermark where it was so the next pull retries this merge.
        }
    }
}
