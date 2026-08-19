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

    // MARK: - assign() / bestFallback (19.08.2026, "Hast du eine Partnerschaft mit Rewe?")
    //
    // bestFallback selbst ist `private` (nur über assign() erreichbar) — laut einer
    // unabhängigen Review-Runde gab es dafür bisher gar keine Tests, obwohl es der
    // eigentliche Kern-Fix dieser Session war. Deckt beide Teile ab: den ursprünglichen Bug
    // (Gleichstand → Array-Reihenfolge) UND die Regression aus der ersten Fix-Fassung
    // (echte Unterschiede wurden fälschlich mitverworfen).

    func testAssignReturnsNilWhenTiedGroceryStoresHaveNoPurchaseEvidence() {
        let edeka = Store(name: "Edeka", emoji: "🛒", colorHex: "#D97706", visitsPerWeek: 1.0, categories: ["Lebensmittel"])
        let rewe = Store(name: "Rewe", emoji: "🛒", colorHex: "#DC2626", visitsPerWeek: 1.0, categories: ["Lebensmittel"])

        let result = AssignmentService.assign(itemName: "Milch", to: [edeka, rewe], purchaseRecords: [])

        XCTAssertNil(result, "Bei echtem Gleichstand ohne jede Kaufhistorie darf nicht geraten werden — genau der 'Partnerschaft mit Rewe?'-Bug")
    }

    func testAssignPicksTiedGroceryStoreWithPurchaseEvidence() {
        let edeka = Store(name: "Edeka", emoji: "🛒", colorHex: "#D97706", visitsPerWeek: 1.0, categories: ["Lebensmittel"])
        let rewe = Store(name: "Rewe", emoji: "🛒", colorHex: "#DC2626", visitsPerWeek: 1.0, categories: ["Lebensmittel"])
        let purchases = records("Butter", storeName: "Rewe", count: 1)

        let result = AssignmentService.assign(itemName: "Milch", to: [edeka, rewe], purchaseRecords: purchases)

        XCTAssertEqual(result?.name, "Rewe", "Bei Gleichstand muss der Store mit echter Kaufhistorie gewinnen, auch wenn die Historie einen anderen Artikelnamen betrifft")
    }

    func testAssignPicksHigherVisitsPerWeekStoreWithoutNeedingEvidence() {
        let lidl = Store(name: "Lidl", emoji: "🛒", colorHex: "#2563EB", visitsPerWeek: 2.0, categories: ["Lebensmittel"])
        let edeka = Store(name: "Edeka", emoji: "🛒", colorHex: "#D97706", visitsPerWeek: 1.0, categories: ["Lebensmittel"])

        let result = AssignmentService.assign(itemName: "Milch", to: [lidl, edeka], purchaseRecords: [])

        XCTAssertEqual(result?.name, "Lidl", "Ohne Gleichstand ist die Besuchsfrequenz ein echtes Signal und muss weiterhin zählen — Regression aus der ersten Fix-Fassung, die visitsPerWeek auch hier fälschlich verwarf")
    }

    func testAssignAppliesSameTieBreakToHardwareStores() {
        let obi = Store(name: "OBI", emoji: "🔨", colorHex: "#EA580C", visitsPerWeek: 0.5, categories: ["Werkzeug"])
        let bauhaus = Store(name: "Bauhaus", emoji: "🔨", colorHex: "#111827", visitsPerWeek: 0.5, categories: ["Werkzeug"])

        let result = AssignmentService.assign(itemName: "Bohrmaschine", to: [obi, bauhaus], purchaseRecords: [])

        XCTAssertNil(result, "Derselbe Schutz muss auch für Baumarkt-Artikel gelten, nicht nur für Lebensmittel")
    }

    /// Gefunden 19.08.2026 von einer unabhängigen Review-Runde: bleiben nach der
    /// Evidenz-Filterung 2+ Stores mit IDENTISCHER Kaufanzahl übrig, entschied `max(by:)`
    /// allein wieder rein durch Array-Reihenfolge — derselbe Bug, nur eine Ebene tiefer
    /// versteckt als der ursprünglich gemeldete.
    func testAssignBreaksEvidenceTieByStoreNameWhenPurchaseCountsAreEqual() {
        let edeka = Store(name: "Edeka", emoji: "🛒", colorHex: "#D97706", visitsPerWeek: 1.0, categories: ["Lebensmittel"])
        let rewe = Store(name: "Rewe", emoji: "🛒", colorHex: "#DC2626", visitsPerWeek: 1.0, categories: ["Lebensmittel"])
        let purchases = records("Butter", storeName: "Edeka", count: 1) + records("Käse", storeName: "Rewe", count: 1)

        // Beide Reihenfolgen prüfen — "Edeka" steht hier zufällig sowohl alphabetisch als auch
        // als Array-Element zuerst; ein Test nur mit dieser einen Reihenfolge hätte auch die
        // alte, unvollständige Fix-Fassung (reine Array-Reihenfolge statt echtem Tie-Breaker)
        // bestanden, ohne den Tie-Breaker selbst zu beweisen (gefunden 19.08.2026 von einer
        // unabhängigen Review-Runde).
        let resultEdekaFirst = AssignmentService.assign(itemName: "Milch", to: [edeka, rewe], purchaseRecords: purchases)
        XCTAssertEqual(resultEdekaFirst?.name, "Edeka")

        let resultReweFirst = AssignmentService.assign(itemName: "Milch", to: [rewe, edeka], purchaseRecords: purchases)
        XCTAssertEqual(resultReweFirst?.name, "Edeka", "Bei gleicher Kaufanzahl an beiden Stores muss das Ergebnis deterministisch sein (alphabetisch früherer Store), unabhängig von der Reihenfolge im übergebenen Array")
    }

    /// Beweist den in derselben Review-Runde gefundenen Rest-Bug: `name` allein ist kein
    /// garantiert eindeutiger Tie-Breaker, da nichts in der App doppelte Store-Namen verhindert.
    func testAssignBreaksEvidenceTieByStoreIdWhenNamesAlsoCollide() {
        let rewe1 = Store(name: "Rewe", emoji: "🛒", colorHex: "#DC2626", visitsPerWeek: 1.0, categories: ["Lebensmittel"])
        let rewe2 = Store(name: "Rewe", emoji: "🛒", colorHex: "#DC2626", visitsPerWeek: 1.0, categories: ["Lebensmittel"])
        // purchaseCounts wird über den (identischen) Namen nachgeschlagen — beide Stores lesen
        // also zwangsläufig denselben Evidenz-Wert, ganz ohne separate Kaufhistorie pro Store.
        let purchases = records("Butter", storeName: "Rewe", count: 1)

        let resultOrderA = AssignmentService.assign(itemName: "Milch", to: [rewe1, rewe2], purchaseRecords: purchases)
        let resultOrderB = AssignmentService.assign(itemName: "Milch", to: [rewe2, rewe1], purchaseRecords: purchases)

        XCTAssertEqual(resultOrderA?.id, resultOrderB?.id, "Bei zwei gleichnamigen Stores muss dieselbe id gewinnen, unabhängig von der Reihenfolge im übergebenen Array")
    }
}
