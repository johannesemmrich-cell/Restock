import XCTest
@testable import Restock

/// Beweist den Fix für "Eier ohne Laden hinzugefügt" (Nutzer meldete: ein Artikel, der bereits
/// einem Laden zugeordnet war, wurde bei Schnell-hinzufügen trotzdem ohne Laden angelegt).
/// Root Cause: `dominantStore` verglich Namen strikt exakt — ein per Bon-Scan gespeicherter
/// `PurchaseRecord.itemName` wie "Bio Eier" matchte die manuell getippte Eingabe "Eier" nicht.
final class AssignmentServiceTests: XCTestCase {

    private func records(_ itemName: String, storeName: String, count: Int) -> [PurchaseRecord] {
        (0..<count).map { _ in PurchaseRecord(itemName: itemName, storeName: storeName) }
    }

    func testDominantStoreMatchesDespiteQualifierPrefix() {
        let edeka = Store(name: "Edeka", emoji: "🛒", colorHex: "#D97706")
        let purchases = records("Bio Eier", storeName: "Edeka", count: 2)

        let result = AssignmentService.dominantStore(for: "Eier", in: [edeka], purchaseRecords: purchases)

        XCTAssertEqual(result?.name, "Edeka", "Eine bereits vorhandene Kaufhistorie mit Qualifier-Präfix muss trotzdem greifen")
    }

    func testDominantStoreDoesNotMatchUnrelatedCompoundWord() {
        let edeka = Store(name: "Edeka", emoji: "🛒", colorHex: "#D97706")
        let purchases = records("Eierlikör", storeName: "Edeka", count: 2)

        let result = AssignmentService.dominantStore(for: "Eier", in: [edeka], purchaseRecords: purchases)

        XCTAssertNil(result, "Eierlikör darf nicht als Treffer für Eier zählen — sonst zu aggressives Matching")
    }

    func testDominantStoreStillMatchesExactNameCaseInsensitively() {
        let edeka = Store(name: "Edeka", emoji: "🛒", colorHex: "#D97706")
        let purchases = records("eier", storeName: "Edeka", count: 2)

        let result = AssignmentService.dominantStore(for: "EIER", in: [edeka], purchaseRecords: purchases)

        XCTAssertEqual(result?.name, "Edeka")
    }

    func testDominantStoreMatchesDespiteDiacriticDifference() {
        let edeka = Store(name: "Edeka", emoji: "🛒", colorHex: "#D97706")
        let purchases = records("Äpfel", storeName: "Edeka", count: 2)

        let result = AssignmentService.dominantStore(for: "Apfel", in: [edeka], purchaseRecords: purchases)

        XCTAssertEqual(result?.name, "Edeka")
    }
}
