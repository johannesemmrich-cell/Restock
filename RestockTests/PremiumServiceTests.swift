import XCTest
@testable import Restock

/// Issue #145, Durchgang 4: Kauf-, Abbruch-, Warte-, Fehler- und Wiederherstellungslogik von Restock Pro
/// über die Naht `PurchaseStore` statt über StoreKit (U1–U12).
/// Spec: `docs/specs/ui-tests/test-145-durchgang-4-kauf-wiederherstellen.md`.
///
/// Netzfrei und ohne StoreKit: `PremiumService(store:autostart: false)` mit dem steuerbaren
/// `ScriptedPurchaseStore` unten; das Singleton `shared` wird nie benutzt. `developerMode` wird in `setUp`
/// entfernt und in `tearDown` geprüft. Offene Grenze: Apples Kaufdialog und echte Transaktionen prüft das
/// nicht (SKTestSession per Kommandozeile auf iOS 26.5/27.0 defekt, #178).
@MainActor
final class PremiumServiceTests: XCTestCase {

    private let allIDs = [PremiumService.monthlyID, PremiumService.yearlyID, PremiumService.lifetimeID]

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "developerMode")
    }

    override func tearDown() {
        let leftover = UserDefaults.standard.object(forKey: "developerMode")
        UserDefaults.standard.removeObject(forKey: "developerMode")
        XCTAssertNil(leftover, "developerMode blieb nach dem Test gesetzt")
        super.tearDown()
    }

    private func makeService(_ store: ScriptedPurchaseStore) -> PremiumService {
        PremiumService(store: store, autostart: false)
    }

    // MARK: - Berechtigungen (U1–U4)

    func testEntitlementPerProductIDGrantsAccess() async {
        for id in allIDs {
            let store = ScriptedPurchaseStore()
            store.entitlementList = [EntitlementRecord(productID: id, isRevoked: false)]
            let service = makeService(store)
            XCTAssertFalse(service.hasPremiumAccess, "\(id): Zugang schon vor dem Lesen der Berechtigungen")
            await service.refreshPurchases()
            XCTAssertTrue(service.hasPremiumAccess, "\(id) schaltet Restock Pro nicht frei")
            XCTAssertEqual(service.purchasedProductIDs, [id])
        }
    }

    func testUnknownProductIDDoesNotGrantAccess() async {
        let store = ScriptedPurchaseStore()
        store.entitlementList = [EntitlementRecord(productID: "com.johannesemmrich.smartcart.sharedlists", isRevoked: false)]
        let service = makeService(store)
        await service.refreshPurchases()
        XCTAssertFalse(service.hasPremiumAccess, "Fremde Produktkennung schaltet frei")
        XCTAssertTrue(service.purchasedProductIDs.isEmpty, "Fremde Kennung steht in purchasedProductIDs")
    }

    func testRevokedTransactionGivesNoAccess() async {
        let store = ScriptedPurchaseStore()
        store.entitlementList = [EntitlementRecord(productID: PremiumService.lifetimeID, isRevoked: true)]
        let service = makeService(store)
        await service.refreshPurchases()
        XCTAssertFalse(service.hasPremiumAccess, "Widerrufener Einmalkauf schaltet frei")

        store.entitlementList = [EntitlementRecord(productID: PremiumService.lifetimeID, isRevoked: false)]
        await service.refreshPurchases()
        XCTAssertTrue(service.hasPremiumAccess, "Gegenprobe: nicht widerrufener Einmalkauf schaltet nicht frei")
    }

    func testNoEntitlementsMeansNoAccessWithoutDeveloperMode() async {
        let service = makeService(ScriptedPurchaseStore())
        await service.refreshPurchases()
        XCTAssertFalse(service.hasPremiumAccess, "Ohne Kauf und ohne Dev-Modus besteht Zugang")
    }

    // MARK: - Kaufen (U5–U8)

    func testPurchaseSuccessGrantsAccessAndReturnsPurchased() async throws {
        let store = ScriptedPurchaseStore()
        store.purchaseResult = .purchased
        let service = makeService(store)
        await service.loadProducts()
        XCTAssertEqual(Set(service.products.map(\.id)), Set(allIDs), "Angebote nicht geladen")

        let outcome = try await service.purchase(offerID: PremiumService.yearlyID)
        XCTAssertEqual(outcome, .purchased)
        XCTAssertTrue(service.hasPremiumAccess, "Nach erfolgreichem Kauf kein Zugang")
        XCTAssertFalse(service.isPurchasing, "isPurchasing bleibt nach dem Kauf gesetzt")
        XCTAssertEqual(store.purchasedOfferIDs, [PremiumService.yearlyID])
    }

    func testPurchaseCancelledReturnsCancelledWithoutAccess() async throws {
        let store = ScriptedPurchaseStore()
        store.purchaseResult = .cancelled
        let service = makeService(store)
        let outcome = try await service.purchase(offerID: PremiumService.monthlyID)
        XCTAssertEqual(outcome, .cancelled)
        XCTAssertFalse(service.hasPremiumAccess, "Abbruch schaltet frei")
        XCTAssertFalse(service.isPurchasing)
    }

    func testPurchasePendingReturnsPendingWithoutAccess() async throws {
        let store = ScriptedPurchaseStore()
        store.purchaseResult = .pending
        let service = makeService(store)
        let outcome = try await service.purchase(offerID: PremiumService.lifetimeID)
        XCTAssertEqual(outcome, .pending)
        XCTAssertFalse(service.hasPremiumAccess, "„Ausstehend“ schaltet sofort frei")
        XCTAssertFalse(service.isPurchasing)
    }

    func testPurchaseErrorIsThrownAndResetsIsPurchasing() async {
        let store = ScriptedPurchaseStore()
        store.purchaseError = ScriptedPurchaseError.failed
        let service = makeService(store)
        do {
            _ = try await service.purchase(offerID: PremiumService.lifetimeID)
            XCTFail("Kauffehler wurde verschluckt")
        } catch {
            XCTAssertEqual(error as? ScriptedPurchaseError, .failed, "Falscher Fehler weitergereicht: \(error)")
        }
        XCTAssertFalse(service.isPurchasing, "isPurchasing bleibt nach Fehler gesetzt")
        XCTAssertFalse(service.hasPremiumAccess)
    }

    // MARK: - Wiederherstellen (U9–U11)

    func testRestoreWithPurchaseReturnsFoundAndGrantsAccess() async {
        let store = ScriptedPurchaseStore()
        store.entitlementList = [EntitlementRecord(productID: PremiumService.lifetimeID, isRevoked: false)]
        let service = makeService(store)
        let outcome = await service.restorePurchases()
        XCTAssertEqual(outcome, .found)
        XCTAssertEqual(store.syncCalls, 1, "AppStore.sync wurde nicht genau einmal aufgerufen")
        XCTAssertTrue(service.hasPremiumAccess)
    }

    func testRestoreWithoutPurchaseReturnsNone() async {
        let service = makeService(ScriptedPurchaseStore())
        let outcome = await service.restorePurchases()
        XCTAssertEqual(outcome, RestoreOutcome.none)
        XCTAssertFalse(service.hasPremiumAccess)

        // Mit Dev-Modus besteht Zugang, aber „gefunden“ zählt nur echte Käufe.
        UserDefaults.standard.set(true, forKey: "developerMode")
        let devOutcome = await service.restorePurchases()
        XCTAssertEqual(devOutcome, RestoreOutcome.none, "Dev-Modus wird als gefundener Kauf gemeldet")
        UserDefaults.standard.removeObject(forKey: "developerMode")
    }

    func testRestoreSyncThrowingReturnsFailed() async {
        let store = ScriptedPurchaseStore()
        store.syncError = ScriptedPurchaseError.failed
        let service = makeService(store)
        let outcome = await service.restorePurchases()
        XCTAssertEqual(outcome, .failed, "Fehler von AppStore.sync wird verschluckt")
        XCTAssertFalse(service.hasPremiumAccess)
    }

    /// F002 (Adversary Runde 1, PO): Abgebrochene Apple-Anmeldung ist ein eigener Ausgang, kein Fehler.
    func testRestoreCancelledReturnsCancelledNotFailed() async {
        let store = ScriptedPurchaseStore()
        store.syncError = PurchaseStoreError.cancelled
        let service = makeService(store)
        let outcome = await service.restorePurchases()
        XCTAssertEqual(outcome, .cancelled, "Abbruch der Anmeldung wird nicht als eigener Ausgang gemeldet")
        XCTAssertNotEqual(outcome, .failed, "Abbruch der Anmeldung wird als Fehler gemeldet")
        XCTAssertEqual(store.syncCalls, 1)
        XCTAssertFalse(service.hasPremiumAccess, "Abbruch schaltet frei")
    }

    // MARK: - Update-Strom (U12)

    func testUpdateStreamUnlocksAfterPending() async throws {
        let store = ScriptedPurchaseStore()
        store.purchaseResult = .pending
        let service = makeService(store)
        service.startListening()

        let outcome = try await service.purchase(offerID: PremiumService.monthlyID)
        XCTAssertEqual(outcome, .pending)
        XCTAssertFalse(service.hasPremiumAccess)

        // Die Familie stimmt zu: StoreKit meldet die Transaktion über den Update-Strom.
        store.entitlementList = [EntitlementRecord(productID: PremiumService.monthlyID, isRevoked: false)]
        store.emitUpdate()

        let deadline = Date().addingTimeInterval(20)
        while !service.hasPremiumAccess && Date() < deadline {
            await Task.yield()
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertTrue(service.hasPremiumAccess, "Update-Strom schaltet nach Zustimmung nicht frei (Frist 20 s)")
    }

    /// F003 (Adversary Runde 1): Ein Widerruf (Erstattung) über den Update-Strom nimmt den Zugang weg.
    func testUpdateStreamRevocationRemovesAccess() async throws {
        let store = ScriptedPurchaseStore()
        store.entitlementList = [EntitlementRecord(productID: PremiumService.lifetimeID, isRevoked: false)]
        let service = makeService(store)
        service.startListening()
        await service.refreshPurchases()
        XCTAssertTrue(service.hasPremiumAccess, "Vorbedingung: Einmalkauf schaltet nicht frei")

        store.entitlementList = [EntitlementRecord(productID: PremiumService.lifetimeID, isRevoked: true)]
        store.emitUpdate()

        let deadline = Date().addingTimeInterval(20)
        while service.hasPremiumAccess && Date() < deadline {
            await Task.yield()
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertFalse(service.hasPremiumAccess, "Widerruf über den Update-Strom nimmt den Zugang nicht weg (Frist 20 s)")
        XCTAssertTrue(service.purchasedProductIDs.isEmpty, "Widerrufene Kennung bleibt in purchasedProductIDs")
    }

    // MARK: - Auswahl der Naht (AC-13)

    func testUnknownScenarioFallsBackToStoreKit() {
        XCTAssertTrue(PremiumService.defaultStore(arguments: []) is StoreKitPurchaseStore,
                      "Ohne Szenario-Argument nicht StoreKit")
        XCTAssertTrue(PremiumService.defaultStore(arguments: ["-purchaseScenarioForUITests", "gibtsnicht"]) is StoreKitPurchaseStore,
                      "Unbekanntes Szenario fällt nicht auf StoreKit zurück")
        XCTAssertTrue(PremiumService.defaultStore(arguments: ["-purchaseScenarioForUITests"]) is StoreKitPurchaseStore,
                      "Fehlender Szenarioname fällt nicht auf StoreKit zurück")
        // Gegenprobe (Unit-Tests laufen im DEBUG-Build): ein bekanntes Szenario wählt den Ersatz.
        XCTAssertTrue(PremiumService.defaultStore(arguments: ["-purchaseScenarioForUITests", "success"]) is FakePurchaseStore,
                      "Bekanntes Szenario wählt den Ersatz nicht")
    }
}

// MARK: - Steuerbarer Doppelgänger

enum ScriptedPurchaseError: Error, Equatable { case failed }

/// Steuerbare `PurchaseStore`-Attrappe: Ergebnisse und Berechtigungen werden je Test gesetzt.
/// Wird nur auf dem Main Actor benutzt; `@unchecked Sendable`, weil die Naht `Sendable` verlangt.
final class ScriptedPurchaseStore: PurchaseStore, @unchecked Sendable {
    var offers: [PurchaseOffer] = [
        PurchaseOffer(id: PremiumService.monthlyID, displayPrice: "1,99 €"),
        PurchaseOffer(id: PremiumService.yearlyID, displayPrice: "8,99 €"),
        PurchaseOffer(id: PremiumService.lifetimeID, displayPrice: "14,99 €"),
    ]
    var purchaseResult: PurchaseOutcome = .cancelled
    var purchaseError: Error?
    var syncError: Error?
    var entitlementList: [EntitlementRecord] = []
    private(set) var purchasedOfferIDs: [String] = []
    private(set) var syncCalls = 0
    private var continuation: AsyncStream<Void>.Continuation?

    func loadOffers(ids: Set<String>) async throws -> [PurchaseOffer] {
        offers.filter { ids.contains($0.id) }
    }

    func purchase(offerID: String) async throws -> PurchaseOutcome {
        if let purchaseError { throw purchaseError }
        if purchaseResult == .purchased {
            purchasedOfferIDs.append(offerID)
            entitlementList.append(EntitlementRecord(productID: offerID, isRevoked: false))
        }
        return purchaseResult
    }

    func sync() async throws {
        syncCalls += 1
        if let syncError { throw syncError }
    }

    func entitlements() async -> [EntitlementRecord] { entitlementList }

    func updates() -> AsyncStream<Void> {
        AsyncStream { continuation = $0 }
    }

    func emitUpdate() { continuation?.yield(()) }
}
