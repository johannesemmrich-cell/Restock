#if DEBUG
import Foundation

/// Ersatz-Appstore nur für DEBUG-Builds (Issue #145, Durchgang 4), gewählt über
/// `-purchaseScenarioForUITests <name>` in `PremiumService.defaultStore(arguments:)`.
/// Hält Käufe nur im Prozess, schreibt nirgends hin (kein App-Group-Zustand, kein `UserDefaults`);
/// ein neuer App-Start beginnt daher immer leer. Im Release-Build ist diese Datei leer.
actor FakePurchaseStore: PurchaseStore {
    enum Scenario: String, CaseIterable, Sendable {
        case success, cancel, pending, fail, productMissing, restoreNone, restoreFound, restoreFail, restoreCancel
    }

    enum FakePurchaseError: LocalizedError, Equatable {
        case purchaseFailed, syncFailed

        var errorDescription: String? {
            switch self {
            case .purchaseFailed: return "Testfehler Kauf"
            case .syncFailed: return "Testfehler Wiederherstellen"
            }
        }
    }

    nonisolated let scenario: Scenario
    private var ownedIDs: Set<String> = []

    init(scenario: Scenario) {
        self.scenario = scenario
    }

    /// `nil` bei unbekanntem Namen — dann bleibt es bei StoreKit.
    init?(scenarioName: String) {
        guard let scenario = Scenario(rawValue: scenarioName) else { return nil }
        self.init(scenario: scenario)
    }

    func loadOffers(ids: Set<String>) async throws -> [PurchaseOffer] {
        guard scenario != .productMissing else { return [] }
        let all = [
            PurchaseOffer(id: PremiumService.monthlyID, displayPrice: "1,99 €", price: Decimal(string: "1.99")),
            PurchaseOffer(id: PremiumService.yearlyID, displayPrice: "8,99 €", price: Decimal(string: "8.99")),
            PurchaseOffer(id: PremiumService.lifetimeID, displayPrice: "14,99 €", price: Decimal(string: "14.99")),
        ]
        return all.filter { ids.contains($0.id) }
    }

    func purchase(offerID: String) async throws -> PurchaseOutcome {
        switch scenario {
        case .success:
            ownedIDs.insert(offerID)
            return .purchased
        case .pending:
            return .pending
        case .fail:
            throw FakePurchaseError.purchaseFailed
        case .cancel, .productMissing, .restoreNone, .restoreFound, .restoreFail, .restoreCancel:
            return .cancelled
        }
    }

    func sync() async throws {
        switch scenario {
        case .restoreFail:
            throw FakePurchaseError.syncFailed
        case .restoreCancel:
            throw PurchaseStoreError.cancelled
        case .restoreFound:
            ownedIDs.insert(PremiumService.lifetimeID)
        default:
            break
        }
    }

    func entitlements() async -> [EntitlementRecord] {
        ownedIDs.sorted().map { EntitlementRecord(productID: $0, isRevoked: false) }
    }

    /// Der Ersatz meldet nie eine Transaktion von außen.
    nonisolated func updates() -> AsyncStream<Void> {
        AsyncStream { _ in }
    }
}
#endif
