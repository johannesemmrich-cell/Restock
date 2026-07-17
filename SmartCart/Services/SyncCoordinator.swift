import CloudKit
import Foundation
import SwiftData

/// Central place that applies remote shared-store state (items + members) onto the local
/// SwiftData store. Used by StoreDetailView's pull/push cycle, JoinStoreSheet, and the
/// CloudKit push-notification handler in AppDelegate so all three paths merge consistently.
@MainActor
final class SyncCoordinator {
    static let shared = SyncCoordinator()
    private init() {}

    /// Set once at app launch (`SmartCartApp.init`) so the push-notification handler,
    /// which has no view hierarchy, can still look up and update SwiftData stores.
    var modelContext: ModelContext?

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
            await apply(items: result.items, members: result.members, deletedIDs: result.deletedIDs, modifiedAt: result.modifiedAt, to: store)
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
            await apply(items: result.items, members: result.members, deletedIDs: result.deletedIDs, modifiedAt: nil, to: store)
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

    /// Looks up a locally known store by its CloudKit shareID and pulls its latest state.
    /// Entry point for the silent-push notification handler.
    func pullStore(shareID: String) async {
        guard let context = modelContext else { return }
        guard let stores = try? context.fetch(FetchDescriptor<Store>()) else { return }
        guard let store = stores.first(where: { $0.shareID == shareID }) else { return }
        await pull(store: store)
    }

    /// Re-registers push subscriptions for every store this device currently shares or has
    /// joined. Called at app launch since subscriptions aren't guaranteed to survive a
    /// reinstall/data reset even though CloudKit persists them server-side otherwise.
    func resubscribeAll() async {
        guard let context = modelContext else { return }
        guard let stores = try? context.fetch(FetchDescriptor<Store>()) else { return }
        for store in stores {
            guard let shareID = store.shareID else { continue }
            try? await SharedStoreService.shared.subscribe(shareID: shareID)
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
    func apply(items remoteItems: [SharedItemData], members: [String], deletedIDs: Set<UUID> = [], modifiedAt: Date?, to store: Store) async {
        guard let context = modelContext ?? store.modelContext else { return }

        for name in members { store.addMember(name) }

        let localByID = Dictionary(uniqueKeysWithValues: store.items.map { ($0.id, $0) })

        for item in store.items where deletedIDs.contains(item.id) {
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
                local.assignedTo = remote.assignedTo
                local.addedBy = remote.addedBy
                local.lastModified = remote.lastModified
            } else {
                let item = ShoppingItem(
                    name: remote.name, category: remote.category,
                    quantity: remote.quantity, quantityAmount: remote.quantityAmount,
                    unit: remote.unit, note: remote.note, store: store
                )
                item.id = remote.id
                item.isCompleted = remote.isCompleted
                item.isUrgent = remote.isUrgent
                item.assignedTo = remote.assignedTo
                item.addedBy = remote.addedBy
                item.lastModified = remote.lastModified
                context.insert(item)
            }
        }

        do {
            try context.save()
            if let shareID = store.shareID, let modifiedAt {
                await SharedStoreService.shared.markSynced(shareID: shareID, at: modifiedAt)
            }
        } catch {
            // Leave the watermark where it was so the next pull retries this merge.
        }
    }
}
