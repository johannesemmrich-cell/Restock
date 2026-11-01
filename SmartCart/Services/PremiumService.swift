import StoreKit
import SwiftUI

// MARK: - Naht vor StoreKit (Issue #145, Durchgang 4)
//
// Der Dienst kennt kein `Product`/`Transaction` mehr, sondern nur diese Werttypen; StoreKit-Objekte
// sind außerhalb von StoreKit nicht konstruierbar. Standard ist `StoreKitPurchaseStore`; nur im
// DEBUG-Build wählt `-purchaseScenarioForUITests <name>` den `FakePurchaseStore`.

struct PurchaseOffer: Equatable, Sendable {
    let id: String
    let displayPrice: String
    /// Rohpreis für Rabattrechnungen der Paywall; `nil` → die Paywall nimmt ihren Rückfallwert.
    let price: Decimal?

    init(id: String, displayPrice: String, price: Decimal? = nil) {
        self.id = id
        self.displayPrice = displayPrice
        self.price = price
    }
}

enum PurchaseOutcome: Equatable, Sendable {
    case purchased, cancelled, pending
}

enum RestoreOutcome: Equatable, Sendable {
    case found, none, failed, cancelled
}

/// Fehler der Naht, die der Dienst unterscheiden muss.
enum PurchaseStoreError: Error, Equatable {
    /// `sync()` wurde abgebrochen (StoreKit: `StoreKitError.userCancelled` — laut Apple-Foren teils auch ohne Netz).
    case cancelled
}

struct EntitlementRecord: Equatable, Sendable {
    let productID: String
    let isRevoked: Bool
}

protocol PurchaseStore: Sendable {
    func loadOffers(ids: Set<String>) async throws -> [PurchaseOffer]
    func purchase(offerID: String) async throws -> PurchaseOutcome
    func sync() async throws
    func entitlements() async -> [EntitlementRecord]
    func updates() -> AsyncStream<Void>
}

// MARK: - StoreKit

/// Kapselt unverändert die bisherigen StoreKit-Aufrufe des Dienstes.
actor StoreKitPurchaseStore: PurchaseStore {
    enum StoreKitPurchaseError: Error { case productNotLoaded }

    private var loadedProducts: [String: Product] = [:]

    func loadOffers(ids: Set<String>) async throws -> [PurchaseOffer] {
        let products = try await Product.products(for: ids)
        for product in products { loadedProducts[product.id] = product }
        return products.map { PurchaseOffer(id: $0.id, displayPrice: $0.displayPrice, price: $0.price) }
    }

    func purchase(offerID: String) async throws -> PurchaseOutcome {
        guard let product = loadedProducts[offerID] else { throw StoreKitPurchaseError.productNotLoaded }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verification.payloadValue
            await transaction.finish()
            return .purchased
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .cancelled
        }
    }

    /// `StoreKitError.userCancelled` (abgebrochene Anmeldung, laut Apple-Foren 692177/727101 teils auch ohne
    /// Netz) wird zu `PurchaseStoreError.cancelled`, damit der Dienst ihn von echten Fehlern trennt.
    func sync() async throws {
        do {
            try await AppStore.sync()
        } catch StoreKitError.userCancelled {
            throw PurchaseStoreError.cancelled
        }
    }

    func entitlements() async -> [EntitlementRecord] {
        var records: [EntitlementRecord] = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                records.append(EntitlementRecord(productID: transaction.productID,
                                                 isRevoked: transaction.revocationDate != nil))
            }
        }
        return records
    }

    nonisolated func updates() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task.detached {
                for await result in Transaction.updates {
                    if case .verified(let transaction) = result {
                        await transaction.finish()
                        continuation.yield(())
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

// MARK: - PremiumService

@MainActor
final class PremiumService: ObservableObject {
    static let shared = PremiumService(store: PremiumService.defaultStore(arguments: ProcessInfo.processInfo.arguments))

    static let monthlyID  = "com.johannesemmrich.smartcart.premium.monthly"
    static let yearlyID   = "com.johannesemmrich.smartcart.premium.yearly"
    static let lifetimeID = "com.johannesemmrich.smartcart.premium.lifetime"

    private static let knownIDs: Set<String> = [monthlyID, yearlyID, lifetimeID]

    @Published private(set) var products: [PurchaseOffer] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published var isPurchasing = false

    @AppStorage("developerMode") private var developerMode = false

    /// Freischaltung über einen eingelösten `PromoCodeService`-Code (Freunde/Familie/Live-Tester,
    /// aus Dresslyst übernommen). Wird von `PromoCodeService` nach Einlösen/Entzugs-Recheck gesetzt.
    @Published private(set) var hasValidPromoCode: Bool = UserDefaults.standard.bool(forKey: "promoCode.isValid")

    func setHasValidPromoCode(_ value: Bool) {
        hasValidPromoCode = value
        UserDefaults.standard.set(value, forKey: "promoCode.isValid")
    }

    /// Restock Pro schaltet nur noch die Ausgaben-Statistik und den Rezeptplan frei — alle
    /// anderen früheren Pro-Features (Kassenbon-Scan, manuelles Eintragen von Preisen, Vorlagen,
    /// geteilte Listen, saisonale Vorschläge) sind seit der Abo-Umstellung im Free-Plan
    /// enthalten und prüfen dieses Flag nicht mehr.
    var hasPremiumAccess: Bool {
        #if DEBUG
        // Für Screenshot-Automation: Premium ohne Developer-Mode-UI freischalten.
        if ProcessInfo.processInfo.arguments.contains("-premiumForScreenshots") {
            return true
        }
        #endif
        return developerMode || hasPurchasedAccess || hasValidPromoCode
    }

    /// Zugang allein aus Käufen, ohne Dev-Modus — Grundlage für „Kauf gefunden“ beim Wiederherstellen.
    private var hasPurchasedAccess: Bool {
        !purchasedProductIDs.isDisjoint(with: Self.knownIDs)
    }

    func offer(for id: String) -> PurchaseOffer? {
        products.first { $0.id == id }
    }

    private let store: any PurchaseStore
    private var transactionListener: Task<Void, Never>?

    /// `autostart: false` (Tests): weder Update-Strom noch erstes Laden starten von selbst.
    init(store: any PurchaseStore, autostart: Bool = true) {
        self.store = store
        guard autostart else { return }
        startListening()
        Task {
            await loadProducts()
            await refreshPurchases()
        }
    }

    deinit { transactionListener?.cancel() }

    /// Wählt die Naht: StoreKit, außer im DEBUG-Build mit bekanntem `-purchaseScenarioForUITests <name>`.
    static func defaultStore(arguments: [String]) -> any PurchaseStore {
        #if DEBUG
        if let index = arguments.firstIndex(of: "-purchaseScenarioForUITests"),
           index + 1 < arguments.count,
           let fake = FakePurchaseStore(scenarioName: arguments[index + 1]) {
            return fake
        }
        #endif
        return StoreKitPurchaseStore()
    }

    func startListening() {
        transactionListener?.cancel()
        let updates = store.updates()
        transactionListener = Task { [weak self] in
            for await _ in updates {
                await self?.refreshPurchases()
            }
        }
    }

    func loadProducts() async {
        products = (try? await store.loadOffers(ids: Self.knownIDs)) ?? []
    }

    @discardableResult
    func purchase(offerID: String) async throws -> PurchaseOutcome {
        isPurchasing = true
        defer { isPurchasing = false }
        let outcome = try await store.purchase(offerID: offerID)
        if outcome == .purchased {
            await refreshPurchases()
        }
        return outcome
    }

    /// `.found` nur aus Käufen, nie aus dem Dev-Modus (sonst wäre „gefunden“ dort immer wahr).
    /// Abgebrochene Anmeldung (`PurchaseStoreError.cancelled`) → `.cancelled`, jeder andere Fehler → `.failed`.
    func restorePurchases() async -> RestoreOutcome {
        do {
            try await store.sync()
        } catch PurchaseStoreError.cancelled {
            await refreshPurchases()
            return .cancelled
        } catch {
            await refreshPurchases()
            return .failed
        }
        await refreshPurchases()
        return hasPurchasedAccess ? .found : .none
    }

    func refreshPurchases() async {
        let records = await store.entitlements()
        purchasedProductIDs = Set(records
            .filter { !$0.isRevoked && Self.knownIDs.contains($0.productID) }
            .map(\.productID))
    }
}
