import XCTest
@testable import Restock

/// Issue #54: `ReceiptScannerView.save()` schrieb für eine Bon-Zeile ohne Artikel-Treffer
/// `quantityAmount: line.quantity, unit: line.unit` in den `PurchaseRecord`. Bei Gewichtsware
/// ("0,706 kg x 2,49") steht dort 1 / "" — das Gewicht (`weightBasis`) ging verloren.
///
/// Alle Tests rufen `EditableReceiptLine.purchaseRecordQuantity()` direkt auf, genau die Methode,
/// die `save()` benutzt — keine Nachbildung der Formel.
///
/// Spec: docs/specs/views/receipt-save-purchase-quantity.md
final class ReceiptSavePurchaseQuantityTests: XCTestCase {

    private func line(
        originalName: String, price: Double = 1.76,
        quantity: Double = 1, unit: String = "", weightBasis: Double? = nil
    ) -> EditableReceiptLine {
        var l = EditableReceiptLine(name: originalName, price: price)
        l.originalName = originalName
        l.quantity = quantity
        l.unit = unit
        l.weightBasis = weightBasis
        return l
    }

    /// AC-1: Die Banane aus dem Issue — 0,706 kg x 2,49 EUR/kg, Gesamtpreis 1,76.
    func testWeightLineGivesGrams() {
        let result = line(originalName: "BANANE CHIQUITA", weightBasis: 706).purchaseRecordQuantity()
        XCTAssertEqual(result.amount, 706)
        XCTAssertEqual(result.unit, "g")
    }

    /// AC-2: Gedruckte Packungsgröße — nicht der Rohtext "500g" im Einheitenfeld.
    func testPackageSizeInNameGivesGrams() {
        let skyr = line(originalName: "SKYR NATUR 500G", unit: "500g").purchaseRecordQuantity()
        XCTAssertEqual(skyr.amount, 500)
        XCTAssertEqual(skyr.unit, "g")

        let hack = line(originalName: "BIO-HACKFLEISCH GEMISCHT RIND SCHWEIN 400G", unit: "400g")
            .purchaseRecordQuantity()
        XCTAssertEqual(hack.amount, 400)
        XCTAssertEqual(hack.unit, "g")
    }

    /// AC-3: Milliliter bleiben Milliliter, es wird nicht auf Gramm umgerechnet.
    func testLiterSizeInNameGivesMilliliters() {
        let cola = line(originalName: "COLA 1,5L", unit: "1,5l").purchaseRecordQuantity()
        XCTAssertEqual(cola.amount, 1500)
        XCTAssertEqual(cola.unit, "ml")

        let halbe = line(originalName: "MILCH 0,5L").purchaseRecordQuantity()
        XCTAssertEqual(halbe.amount, 500)
        XCTAssertEqual(halbe.unit, "ml")

        let dose = line(originalName: "LIMO 33CL").purchaseRecordQuantity()
        XCTAssertEqual(dose.amount, 330)
        XCTAssertEqual(dose.unit, "ml")
    }

    /// AC-4: Echte Stückzahl (Mengenzeile "4 x 0,39") bleibt Stückzahl ohne Einheit.
    func testQuantityGreaterOneGivesPieces() {
        let result = line(originalName: "BROETCHEN", price: 1.56, quantity: 4).purchaseRecordQuantity()
        XCTAssertEqual(result.amount, 4)
        XCTAssertEqual(result.unit, "")
    }

    /// AC-4b: Nichts bekannt → ehrlich "1 / keine Einheit".
    func testNothingKnownGivesOneWithoutUnit() {
        let result = line(originalName: "MILCH").purchaseRecordQuantity()
        XCTAssertEqual(result.amount, 1)
        XCTAssertEqual(result.unit, "")
    }

    /// AC-5 (Gegenprobe): Für Gewichtszeilen müssen Kaufdatensatz und Preis-Lernen dieselbe
    /// Wahrheit sehen — an DERSELBEN Instanz.
    func testAgreesWithLearningQuantityForWeightCases() {
        let l = line(originalName: "BANANE CHIQUITA", weightBasis: 706)
        let purchase = l.purchaseRecordQuantity()
        XCTAssertEqual(purchase.amount, l.learningQuantity(matchQuantityAmount: nil))
        XCTAssertEqual(purchase.unit, l.learningUnit(matchUnit: nil))
    }

    /// AC-6: Der Umschalter der Review-Karte setzt `weightBasis` auf nil (Gramm → Stück) und
    /// wieder zurück. Die Methode liest nur den aktuellen Zustand.
    func testSwitchingToPiecesFallsBackToQuantity() {
        var l = line(originalName: "BANANE CHIQUITA", quantity: 2, weightBasis: 706)
        XCTAssertEqual(l.purchaseRecordQuantity().amount, 706)

        l.weightBasis = nil
        let pieces = l.purchaseRecordQuantity()
        XCTAssertEqual(pieces.amount, 2)
        XCTAssertEqual(pieces.unit, "")

        l.weightBasis = 706
        let grams = l.purchaseRecordQuantity()
        XCTAssertEqual(grams.amount, 706)
        XCTAssertEqual(grams.unit, "g")
    }
}
