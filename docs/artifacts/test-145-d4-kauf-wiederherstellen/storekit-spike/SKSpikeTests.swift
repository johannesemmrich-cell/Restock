import XCTest
import StoreKit
import StoreKitTest

final class SKSpikeTests: XCTestCase {
  let ids: Set<String> = ["com.johannesemmrich.smartcart.premium.monthly",
                          "com.johannesemmrich.smartcart.premium.yearly",
                          "com.johannesemmrich.smartcart.premium.lifetime"]

  func session() throws -> SKTestSession {
    let url = try XCTUnwrap(Bundle.module.url(forResource: "Restock", withExtension: "storekit"))
    let s = try SKTestSession(contentsOf: url)
    s.resetToDefaultState(); s.clearTransactions(); s.disableDialogs = true
    return s
  }

  func testA_LoadProducts() async throws {
    _ = try session()
    let p = try await Product.products(for: ids)
    print("SPIKE A: \(p.count) Produkte: " + p.map { "\($0.id)=\($0.displayPrice)" }.sorted().joined(separator: ", "))
    XCTAssertEqual(p.count, 3)
  }

  func testB_PurchaseLifetime() async throws {
    _ = try session()
    let p = try await Product.products(for: ids)
    let life = try XCTUnwrap(p.first { $0.id.hasSuffix("lifetime") })
    let r = try await life.purchase()
    print("SPIKE B: Ergebnis \(r)")
    guard case .success(let v) = r else { return XCTFail("kein success: \(r)") }
    let t = try v.payloadValue; await t.finish()
    var ent: [String] = []
    for await e in Transaction.currentEntitlements { if case .verified(let t) = e { ent.append(t.productID) } }
    print("SPIKE B: Berechtigungen \(ent)")
    XCTAssertTrue(ent.contains(life.id))
  }

  func testC_FailedPurchase() async throws {
    let s = try session()
    s.failTransactionsEnabled = true
    s.failureError = .unknown
    let p = try await Product.products(for: ids)
    let life = try XCTUnwrap(p.first { $0.id.hasSuffix("lifetime") })
    do { let r = try await life.purchase(); XCTFail("kein Fehler: \(r)") }
    catch { print("SPIKE C: Fehler \(error)") }
  }

  func testD_AskToBuyPending() async throws {
    let s = try session()
    s.askToBuyEnabled = true
    let p = try await Product.products(for: ids)
    let life = try XCTUnwrap(p.first { $0.id.hasSuffix("lifetime") })
    let r = try await life.purchase()
    print("SPIKE D: Ergebnis \(r)")
    guard case .pending = r else { return XCTFail("nicht pending: \(r)") }
  }
}
