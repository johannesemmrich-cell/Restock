import XCTest
@testable import Restock

/// QuickAddParser ist reine Text-Logik ohne UIKit/SwiftData-Abhängigkeit, wird aber an drei
/// Stellen verwendet (AddItemView, HomeView-Schnellhinzufügen, StoreDetailView) und hat mit
/// `knownProductSuggestions` direkt die vom Nutzer als "verschwunden" gemeldete
/// Produkt-Vorschlags-Funktion — bisher ohne jede Testabdeckung.
final class QuickAddParserTests: XCTestCase {

    // MARK: - parse: Menge/Einheit/Name

    func testPlainNameWithoutQuantityDefaultsToOne() {
        let r = QuickAddParser.parse("Milch")
        XCTAssertEqual(r.name, "Milch")
        XCTAssertEqual(r.quantity, "1")
        XCTAssertEqual(r.quantityAmount, 1)
        XCTAssertEqual(r.unit, "")
    }

    func testLeadingNumberSetsQuantity() {
        let r = QuickAddParser.parse("2 Milch")
        XCTAssertEqual(r.name, "Milch")
        XCTAssertEqual(r.quantityAmount, 2)
    }

    func testLeadingMultiplierSuffixSetsQuantity() {
        let r = QuickAddParser.parse("2x Milch")
        XCTAssertEqual(r.name, "Milch")
        XCTAssertEqual(r.quantityAmount, 2)
    }

    func testGluedNumberAndUnitSplitCorrectly() {
        let r = QuickAddParser.parse("200g Mehl")
        XCTAssertEqual(r.name, "Mehl")
        XCTAssertEqual(r.quantityAmount, 200)
        XCTAssertEqual(r.unit, "g")
    }

    func testCommaDecimalWithSeparateUnitToken() {
        let r = QuickAddParser.parse("1,5 kg Äpfel")
        XCTAssertEqual(r.name, "Äpfel")
        XCTAssertEqual(r.quantityAmount, 1.5)
        XCTAssertEqual(r.unit, "kg")
    }

    func testUppercaseUnitTokenIsRecognized() {
        let r = QuickAddParser.parse("3 EL Olivenöl")
        XCTAssertEqual(r.name, "Olivenöl")
        XCTAssertEqual(r.quantityAmount, 3)
        XCTAssertEqual(r.unit, "EL")
    }

    func testGermanWordNumberIsParsed() {
        let r = QuickAddParser.parse("zwei Bananen")
        XCTAssertEqual(r.name, "Bananen")
        XCTAssertEqual(r.quantityAmount, 2)
    }

    func testHalfWordNumberIsParsedAsFraction() {
        let r = QuickAddParser.parse("halbe Gurke")
        XCTAssertEqual(r.name, "Gurke")
        XCTAssertEqual(r.quantityAmount, 0.5)
    }

    func testTrailingGluedQuantityAndUnit() {
        let r = QuickAddParser.parse("Hackfleisch 3kg")
        XCTAssertEqual(r.name, "Hackfleisch")
        XCTAssertEqual(r.quantityAmount, 3)
        XCTAssertEqual(r.unit, "kg")
    }

    func testTrailingSeparateQuantityAndUnit() {
        let r = QuickAddParser.parse("Hackfleisch 3 kg")
        XCTAssertEqual(r.name, "Hackfleisch")
        XCTAssertEqual(r.quantityAmount, 3)
        XCTAssertEqual(r.unit, "kg")
    }

    func testTrailingPlainNumberWithoutUnit() {
        let r = QuickAddParser.parse("Milch 2")
        XCTAssertEqual(r.name, "Milch")
        XCTAssertEqual(r.quantityAmount, 2)
        XCTAssertEqual(r.unit, "")
    }

    func testTrailingMultiplierSuffixWithoutUnit() {
        let r = QuickAddParser.parse("Milch 4x")
        XCTAssertEqual(r.name, "Milch")
        XCTAssertEqual(r.quantityAmount, 4)
    }

    func testNumberOnlyInputIsTreatedAsNameNotQuantity() {
        let r = QuickAddParser.parse("2")
        XCTAssertEqual(r.name, "2")
        XCTAssertEqual(r.quantityAmount, 1)
    }

    func testEmptyInputReturnsEmptyNameWithDefaultQuantity() {
        let r = QuickAddParser.parse("   ")
        XCTAssertEqual(r.name, "")
        XCTAssertEqual(r.quantity, "1")
    }

    // MARK: - hint(for:)

    func testHintReturnsNilForPlainNameWithoutQuantityOrUnit() {
        XCTAssertNil(QuickAddParser.hint(for: "Milch"))
    }

    func testHintFormatsQuantityAndUnit() {
        XCTAssertEqual(QuickAddParser.hint(for: "2x Milch"), "2× · Milch")
        XCTAssertEqual(QuickAddParser.hint(for: "200g Mehl"), "200× · g · Mehl")
    }

    // MARK: - knownProductSuggestions (die vom Nutzer vermisste Autocomplete-Funktion)

    func testSuggestionsMatchByPrefixCaseInsensitive() {
        let records = [
            PurchaseRecord(itemName: "Eier", storeName: "Edeka"),
            PurchaseRecord(itemName: "eierlikör", storeName: "Edeka"),
        ]
        let result = QuickAddParser.knownProductSuggestions(for: "Ei", in: records)
        XCTAssertEqual(Set(result), ["Eier", "eierlikör"])
    }

    func testSuggestionsRequireAtLeastTwoCharacters() {
        let records = [PurchaseRecord(itemName: "Eier", storeName: "Edeka")]
        XCTAssertEqual(QuickAddParser.knownProductSuggestions(for: "E", in: records), [])
    }

    func testSuggestionsExcludeExactMatch() {
        let records = [PurchaseRecord(itemName: "Milch", storeName: "Edeka")]
        XCTAssertEqual(QuickAddParser.knownProductSuggestions(for: "Milch", in: records), [])
    }

    func testSuggestionsDedupeCaseInsensitiveKeepingFirstSeen() {
        let older = PurchaseRecord(itemName: "milch", storeName: "Edeka")
        older.date = Date().addingTimeInterval(-86400 * 10)
        let newer = PurchaseRecord(itemName: "Milch", storeName: "Rewe")
        newer.date = Date()
        let result = QuickAddParser.knownProductSuggestions(for: "Mi", in: [older, newer])
        XCTAssertEqual(result, ["Milch"])
    }

    func testSuggestionsAreSortedByMostRecentFirst() {
        let old = PurchaseRecord(itemName: "Apfelmus", storeName: "Edeka")
        old.date = Date().addingTimeInterval(-86400 * 30)
        let recent = PurchaseRecord(itemName: "Apfelsaft", storeName: "Edeka")
        recent.date = Date()
        let result = QuickAddParser.knownProductSuggestions(for: "Apfel", in: [old, recent])
        XCTAssertEqual(result, ["Apfelsaft", "Apfelmus"])
    }

    func testSuggestionsRespectLimit() {
        let records = (0..<10).map { i -> PurchaseRecord in
            let r = PurchaseRecord(itemName: "Apfel\(i)", storeName: "Edeka")
            r.date = Date().addingTimeInterval(-Double(i) * 60)
            return r
        }
        XCTAssertEqual(QuickAddParser.knownProductSuggestions(for: "Apfel", in: records, limit: 3).count, 3)
    }

    // MARK: - Erweiterter Kandidatenpool + Diakritik/Teilstring (Nutzer: "zu wenig vorgeschlagen")

    func testSuggestionsIncludeItemNamesNotOnlyPurchaseRecords() {
        let result = QuickAddParser.knownProductSuggestions(for: "Ei", in: [], itemNames: ["Eier"])
        XCTAssertEqual(result, ["Eier"], "Noch nicht abgehakte Listen-Artikel müssen auch als Vorschlag zählen, nicht nur Kaufhistorie")
    }

    func testSuggestionsFoldDiacriticsForMatching() {
        let records = [PurchaseRecord(itemName: "Äpfel", storeName: "Edeka")]
        let result = QuickAddParser.knownProductSuggestions(for: "Ap", in: records)
        XCTAssertEqual(result, ["Äpfel"])
    }

    func testSuggestionsFallBackToSubstringWhenPrefixMatchesAreFew() {
        let records = [PurchaseRecord(itemName: "Apfelmus", storeName: "Edeka")]
        let result = QuickAddParser.knownProductSuggestions(for: "fel", in: records)
        XCTAssertEqual(result, ["Apfelmus"], "Ohne Präfix-Treffer muss die Teilstring-Suche als Fallback greifen")
    }
}
