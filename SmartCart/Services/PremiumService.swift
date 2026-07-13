import StoreKit
import SwiftUI

@MainActor
final class PremiumService: ObservableObject {
    static let shared = PremiumService()

    static let monthlyID     = "com.johannesemmrich.smartcart.premium.monthly"
    static let yearlyID      = "com.johannesemmrich.smartcart.premium.yearly"
    static let lifetimeID    = "com.johannesemmrich.smartcart.premium.lifetime"
    static let sharedListsID = "com.johannesemmrich.smartcart.sharedlists"

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published var isPurchasing = false

    @AppStorage("developerMode") private var developerMode = false

    var isPremiumUnlocked: Bool {
        #if DEBUG
        // Für Screenshot-Automation: Premium ohne Developer-Mode-UI freischalten.
        if ProcessInfo.processInfo.arguments.contains("-premiumForScreenshots") {
            return true
        }
        #endif
        return developerMode
            || purchasedProductIDs.contains(Self.lifetimeID)
            || purchasedProductIDs.contains(Self.monthlyID)
            || purchasedProductIDs.contains(Self.yearlyID)
    }

    var isSharedListsUnlocked: Bool {
        isPremiumUnlocked || purchasedProductIDs.contains(Self.sharedListsID)
    }

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    private var transactionListener: Task<Void, Error>?

    private init() {
        transactionListener = Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.refreshPurchases()
                }
            }
        }
        Task {
            await loadProducts()
            await refreshPurchases()
        }
    }

    deinit { transactionListener?.cancel() }

    func loadProducts() async {
        let ids: Set<String> = [Self.monthlyID, Self.yearlyID, Self.lifetimeID, Self.sharedListsID]
        products = (try? await Product.products(for: ids)) ?? []
    }

    @discardableResult
    func purchase(_ product: Product) async throws -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verification.payloadValue
            await transaction.finish()
            await refreshPurchases()
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await refreshPurchases()
    }

    private func refreshPurchases() async {
        var active: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.revocationDate == nil {
                active.insert(transaction.productID)
            }
        }
        purchasedProductIDs = active
    }
}
