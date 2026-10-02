import XCTest
@testable import Restock

/// Issue #53 — die Bezugsgröße eines gelernten Preises reist über geteilte Listen mit: beim Push,
/// beim Pull und im Konflikt-Merge, immer gemeinsam mit Betrag und Zeitstempel.
final class LearnedPriceSyncTests: XCTestCase {

    private let earlier = Date(timeIntervalSince1970: 1_000_000)
    private let later = Date(timeIntervalSince1970: 2_000_000)

    private func makeStore() -> Store {
        Store(name: "Rewe", emoji: "🛒", colorHex: "#CC0000")
    }

    // MARK: - Kodierung

    func testEncodeDecodeRoundTripKeepsUnit() {
        let state = LearnedPriceSync.State(
            prices: ["eier": 0.39, "banane": 0.00249],
            dates: ["eier": earlier, "banane": later],
            units: ["eier": "stk", "banane": "g"])

        let decoded = LearnedPriceSync.decode(LearnedPriceSync.encode(state))

        XCTAssertEqual(decoded, state)
    }

    /// Ein Record aus einer älteren App-Version kennt das Feld `unit` nicht — der Preis kommt an,
    /// aber ohne Einheit (und wird nach #10 deshalb nicht angewendet).
    func testDecodeLegacyRecordWithoutUnit() {
        let json = #"{"eier":{"price":0.39,"date":1000000}}"#

        let decoded = LearnedPriceSync.decode(json)

        XCTAssertEqual(decoded.prices["eier"], 0.39)
        XCTAssertEqual(decoded.dates["eier"], earlier)
        XCTAssertNil(decoded.units["eier"])
    }

    // MARK: - Push-Merge

    func testMergeTakesUnitFromTheNewerSide() {
        let local = LearnedPriceSync.State(prices: ["eier": 0.39], dates: ["eier": later], units: ["eier": "stk"])
        let remote = LearnedPriceSync.State(prices: ["eier": 4.99], dates: ["eier": earlier], units: ["eier": "g"])

        let merged = LearnedPriceSync.merge(local: local, remote: remote)

        XCTAssertEqual(merged.prices["eier"], 0.39)
        XCTAssertEqual(merged.units["eier"], "stk", "Betrag und Einheit kommen von derselben Seite.")

        let reversed = LearnedPriceSync.merge(local: remote, remote: local)
        XCTAssertEqual(reversed.prices["eier"], 0.39)
        XCTAssertEqual(reversed.units["eier"], "stk")
    }

    func testMergeKeepsKeysFromBothSides() {
        let local = LearnedPriceSync.State(prices: ["eier": 0.39], dates: ["eier": later], units: ["eier": "stk"])
        let remote = LearnedPriceSync.State(prices: ["mehl": 0.0011], dates: ["mehl": earlier], units: ["mehl": "g"])

        let merged = LearnedPriceSync.merge(local: local, remote: remote)

        XCTAssertEqual(merged.units, ["eier": "stk", "mehl": "g"])
    }

    /// Ein älteres Gerät ohne Einheiten-Kenntnis hat denselben Preis zurückgeschrieben — die
    /// bekannte Einheit darf dadurch nicht verloren gehen.
    func testMergeKeepsRemoteUnitForSamePriceAndDateWhenLocalHasNone() {
        let local = LearnedPriceSync.State(prices: ["eier": 0.39], dates: ["eier": later], units: [:])
        let remote = LearnedPriceSync.State(prices: ["eier": 0.39], dates: ["eier": later], units: ["eier": "stk"])

        XCTAssertEqual(LearnedPriceSync.merge(local: local, remote: remote).units["eier"], "stk")
    }

    // MARK: - Pull-Anwendung

    func testApplyWritesUnitTogetherWithNewerRemotePrice() {
        let store = makeStore()
        store.learnedPrices["eier"] = 4.99
        store.learnedPriceDates["eier"] = earlier
        store.learnedPriceUnits["eier"] = "g"

        LearnedPriceSync.apply(
            LearnedPriceSync.State(prices: ["eier": 0.39], dates: ["eier": later], units: ["eier": "stk"]),
            to: store)

        XCTAssertEqual(store.learnedPrices["eier"], 0.39)
        XCTAssertEqual(store.learnedPriceDates["eier"], later)
        XCTAssertEqual(store.learnedPriceUnits["eier"], "stk")
    }

    func testApplyIgnoresOlderRemotePriceAndUnit() {
        let store = makeStore()
        store.learnedPrices["eier"] = 0.39
        store.learnedPriceDates["eier"] = later
        store.learnedPriceUnits["eier"] = "stk"

        LearnedPriceSync.apply(
            LearnedPriceSync.State(prices: ["eier": 4.99], dates: ["eier": earlier], units: ["eier": "g"]),
            to: store)

        XCTAssertEqual(store.learnedPrices["eier"], 0.39)
        XCTAssertEqual(store.learnedPriceUnits["eier"], "stk")
    }

    /// Der eigentliche Fehler aus #53: ein auf Gerät A gelernter Preis kommt auf Gerät B an und
    /// wird dort auch angewendet.
    func testPricePulledOntoFreshStoreIsApplied() {
        let store = makeStore()

        LearnedPriceSync.apply(
            LearnedPriceSync.State(prices: ["eier": 0.39], dates: ["eier": later], units: ["eier": "stk"]),
            to: store)

        let item = ShoppingItem(name: "Eier", category: "Eier", quantityAmount: 6, store: store)
        XCTAssertFalse(item.estimatedPriceIsAutoDerived,
                       "Ein synchronisierter Preis mit Einheit muss angewendet werden.")
    }

    /// Ein neuerer Preis ohne Einheit (älteres Gerät) ersetzt den Betrag — die alte Einheit darf
    /// dann nicht unter dem neuen Betrag stehen bleiben.
    func testApplyNewerPriceWithoutUnitRemovesStaleUnit() {
        let store = makeStore()
        store.learnedPrices["eier"] = 0.39
        store.learnedPriceDates["eier"] = earlier
        store.learnedPriceUnits["eier"] = "stk"

        LearnedPriceSync.apply(
            LearnedPriceSync.State(prices: ["eier": 4.99], dates: ["eier": later], units: [:]),
            to: store)

        XCTAssertEqual(store.learnedPrices["eier"], 4.99)
        XCTAssertNil(store.learnedPriceUnits["eier"])
    }

    func testApplySamePriceWithoutUnitKeepsKnownUnit() {
        let store = makeStore()
        store.learnedPrices["eier"] = 0.39
        store.learnedPriceDates["eier"] = later
        store.learnedPriceUnits["eier"] = "stk"

        LearnedPriceSync.apply(
            LearnedPriceSync.State(prices: ["eier": 0.39], dates: ["eier": later], units: [:]),
            to: store)

        XCTAssertEqual(store.learnedPriceUnits["eier"], "stk")
    }
}
