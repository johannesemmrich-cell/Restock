import CloudKit
import XCTest
@testable import Restock

/// Promo-Code-Einlösen, Erzeugen, Entziehen und Revalidierung (aus Dresslyst übernommen) über die
/// Naht `PromoCodeDatabase` statt echtem CloudKit — netzfrei. Jeder Test nutzt eine eigene
/// `UserDefaults`-Suite (Muster `CheckoffQueueTests`) und eine `UnlockSpy` statt des
/// `PremiumService`-Singletons; `setUp`/`tearDown` prüfen, dass nichts in der Suite zurückbleibt.
@MainActor
final class PromoCodeServiceTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!
    private var db: FakePromoCodeDatabase!
    private var spy: UnlockSpy!
    private let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUp() {
        super.setUp()
        suiteName = "PromoCodeServiceTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        db = FakePromoCodeDatabase()
        spy = UnlockSpy()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        UserDefaults().removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeService() -> PromoCodeService {
        PromoCodeService(database: db, defaults: defaults,
                         onUnlockChange: { [spy] in spy!.calls.append($0) },
                         now: { [fixedNow] in fixedNow })
    }

    // MARK: - Einlösen

    func testRedeemOpenCodeUnlocksAndMarksRecord() async {
        db.insertOpenCode("ABCD-2345", label: "Familie")
        let service = makeService()

        let ok = await service.redeem("abcd-2345")  // Groß-/Kleinschreibung egal

        XCTAssertTrue(ok)
        XCTAssertEqual(spy.calls, [true], "Freischaltung wurde nicht gemeldet")
        XCTAssertNil(service.redeemErrorMessage)
        let record = db.records["ABCD-2345"]
        XCTAssertNotNil(record?[PromoCodeSchema.redeemedBy] as? String, "redeemedBy nicht gesetzt")
        XCTAssertEqual(record?[PromoCodeSchema.redeemedAt] as? Date, fixedNow)
        XCTAssertEqual(defaults.string(forKey: PromoCodeService.redeemedCodeKey), "ABCD-2345")
    }

    func testRedeemUnknownCodeFailsWithNotFound() async {
        let service = makeService()
        let ok = await service.redeem("NOPE-NOPE")
        XCTAssertFalse(ok)
        XCTAssertEqual(service.redeemErrorMessage, PromoCodeService.RedeemError.notFound.localizedDescription)
        XCTAssertEqual(spy.calls, [], "Unbekannter Code darf nichts freischalten")
        XCTAssertNil(defaults.string(forKey: PromoCodeService.redeemedCodeKey))
    }

    func testRedeemRevokedCodeFails() async {
        db.insertOpenCode("ABCD-2345")
        db.records["ABCD-2345"]?[PromoCodeSchema.isRevoked] = Int64(1) as CKRecordValue
        let service = makeService()
        let ok = await service.redeem("ABCD-2345")
        XCTAssertFalse(ok)
        XCTAssertEqual(service.redeemErrorMessage, PromoCodeService.RedeemError.revoked.localizedDescription)
        XCTAssertEqual(spy.calls, [])
    }

    func testRedeemCodeTakenByAnotherInstallationFails() async {
        db.insertOpenCode("ABCD-2345")
        db.records["ABCD-2345"]?[PromoCodeSchema.redeemedBy] = "some-other-installation" as CKRecordValue
        let service = makeService()
        let ok = await service.redeem("ABCD-2345")
        XCTAssertFalse(ok)
        XCTAssertEqual(service.redeemErrorMessage, PromoCodeService.RedeemError.redeemedByAnother.localizedDescription)
        XCTAssertEqual(spy.calls, [])
    }

    func testRedeemSameCodeAgainOnSameInstallationSucceeds() async {
        db.insertOpenCode("ABCD-2345")
        let service = makeService()
        let first = await service.redeem("ABCD-2345")
        XCTAssertTrue(first)
        // Zweiter Versuch auf derselben Installation (gleiche UUID in derselben Suite) ist ok.
        let second = await service.redeem("ABCD-2345")
        XCTAssertTrue(second)
        XCTAssertEqual(spy.calls, [true, true])
    }

    // MARK: - Revalidierung beim App-Start

    func testRevalidateRemotelyRevokedRemovesUnlock() async {
        db.insertOpenCode("ABCD-2345")
        let service = makeService()
        _ = await service.redeem("ABCD-2345")
        spy.calls.removeAll()

        db.records["ABCD-2345"]?[PromoCodeSchema.isRevoked] = Int64(1) as CKRecordValue
        await service.revalidateLocalRedemption()
        XCTAssertEqual(spy.calls, [false], "Entzogener Code bleibt freigeschaltet")
    }

    func testRevalidateValidRedemptionKeepsUnlock() async {
        db.insertOpenCode("ABCD-2345")
        let service = makeService()
        _ = await service.redeem("ABCD-2345")
        spy.calls.removeAll()

        await service.revalidateLocalRedemption()
        XCTAssertEqual(spy.calls, [true])
    }

    func testRevalidateDeletedRecordRemovesUnlock() async {
        db.insertOpenCode("ABCD-2345")
        let service = makeService()
        _ = await service.redeem("ABCD-2345")
        spy.calls.removeAll()

        db.records["ABCD-2345"] = nil  // Record gelöscht, nicht nur entzogen
        await service.revalidateLocalRedemption()
        XCTAssertEqual(spy.calls, [false])
    }

    func testRevalidateNetworkErrorLeavesUnlockUnchanged() async {
        db.insertOpenCode("ABCD-2345")
        let service = makeService()
        _ = await service.redeem("ABCD-2345")
        spy.calls.removeAll()

        db.throwGenericOnNextFetch = true  // simulierter Netzfehler (kein CKError.unknownItem)
        await service.revalidateLocalRedemption()
        XCTAssertEqual(spy.calls, [], "Netzfehler darf den lokalen Stand nicht anfassen")
    }

    func testRevalidateWithoutStoredCodeDoesNothing() async {
        let service = makeService()
        await service.revalidateLocalRedemption()
        XCTAssertEqual(spy.calls, [])
    }

    // MARK: - Erzeugen & Entziehen (Dev-Mode)

    func testGenerateCreatesUniqueWellFormedCodes() async {
        let service = makeService()
        let codes = await service.generateCodes(count: 5, label: "Test")
        XCTAssertEqual(codes.count, 5)
        XCTAssertEqual(Set(codes).count, 5, "Codes nicht eindeutig")
        let pattern = try! NSRegularExpression(pattern: "^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{4}-[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{4}$")
        for code in codes {
            XCTAssertEqual(pattern.numberOfMatches(in: code, range: NSRange(code.startIndex..., in: code)), 1,
                           "Falsches Format: \(code)")
        }
        XCTAssertEqual(service.allCodes.count, 5)
        XCTAssertTrue(service.allCodes.allSatisfy { $0.status == .open && $0.label == "Test" })
    }

    func testSetRevokedFlipsStatus() async {
        db.insertOpenCode("ABCD-2345", label: "x")
        let service = makeService()
        await service.setRevoked(true, code: "ABCD-2345")
        XCTAssertEqual((db.records["ABCD-2345"]?[PromoCodeSchema.isRevoked] as? Int64), 1)
        await service.setRevoked(false, code: "ABCD-2345")
        XCTAssertEqual((db.records["ABCD-2345"]?[PromoCodeSchema.isRevoked] as? Int64), 0)
    }

    func testFetchAllCodesMapsFields() async {
        db.insertOpenCode("ABCD-2345", label: "Freunde")
        db.records["ABCD-2345"]?[PromoCodeSchema.redeemedBy] = "inst-1" as CKRecordValue
        db.records["ABCD-2345"]?[PromoCodeSchema.redeemedAt] = fixedNow as CKRecordValue
        let service = makeService()
        await service.fetchAllCodes()
        let record = service.allCodes.first { $0.code == "ABCD-2345" }
        XCTAssertEqual(record?.label, "Freunde")
        XCTAssertEqual(record?.status, .redeemed)
        XCTAssertEqual(record?.redeemedByInstallationID, "inst-1")
        XCTAssertEqual(record?.redeemedAt, fixedNow)
    }
}

// MARK: - Doubles

/// Zählt die Freischalt-Aufrufe, die in Produktion an `PremiumService.setHasValidPromoCode` gehen.
private final class UnlockSpy {
    var calls: [Bool] = []
}

/// In-Memory-Ersatz für die öffentliche CloudKit-Datenbank. Nur auf dem Main Actor benutzt;
/// `@unchecked Sendable` wie `ScriptedPurchaseStore`.
private final class FakePromoCodeDatabase: PromoCodeDatabase, @unchecked Sendable {
    var records: [String: CKRecord] = [:]
    var throwGenericOnNextFetch = false

    func insertOpenCode(_ code: String, label: String = "") {
        let record = CKRecord(recordType: PromoCodeSchema.recordType, recordID: CKRecord.ID(recordName: code))
        record[PromoCodeSchema.isRevoked] = Int64(0) as CKRecordValue
        record[PromoCodeSchema.label] = label as CKRecordValue
        record[PromoCodeSchema.createdAt] = Date(timeIntervalSince1970: 1_600_000_000) as CKRecordValue
        records[code] = record
    }

    func record(for recordName: String) async throws -> CKRecord {
        if throwGenericOnNextFetch {
            throwGenericOnNextFetch = false
            throw NSError(domain: "test.network", code: -1009)
        }
        guard let record = records[recordName] else { throw CKError(.unknownItem) }
        return record
    }

    func create(_ record: CKRecord) async throws {
        records[record.recordID.recordName] = record
    }

    func modifyChangedKeys(_ record: CKRecord) async throws {
        records[record.recordID.recordName] = record
    }

    func allCodeRecords() async throws -> [CKRecord] {
        Array(records.values)
    }
}
