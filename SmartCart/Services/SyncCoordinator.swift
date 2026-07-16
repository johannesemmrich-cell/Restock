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
            await apply(items: result.items, members: result.members, to: store)
            return true
        } catch {
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
            await apply(items: result.items, members: result.members, to: store)
            return true
        } catch {
            return false
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
    func apply(items remoteItems: [SharedItemData], members: [String], to store: Store) async {
        guard let context = modelContext ?? store.modelContext else { return }

        for name in members { store.addMember(name) }

        let localByID = Dictionary(uniqueKeysWithValues: store.items.map { ($0.id, $0) })
        let remoteByID = Dictionary(uniqueKeysWithValues: remoteItems.map { ($0.id, $0) })

        for item in store.items where remoteByID[item.id] == nil {
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
            if let shareID = store.shareID {
                await SharedStoreService.shared.markSynced(shareID: shareID)
            }
        } catch {
            // Leave the watermark where it was so the next pull retries this merge.
        }
    }
}
