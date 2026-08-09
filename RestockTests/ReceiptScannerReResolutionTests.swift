import XCTest
@testable import Restock

/// Beweist den Fix für "Namen sind nicht so gut wie vorher" bei per Share Extension geteilten
/// Bons: die Extension überspringt Stufe 5 (Apple Intelligence, Speicherlimit dort), die
/// Haupt-App muss sie beim Öffnen nachholen. `EditableReceiptLine.linesNeedingAIReresolution`/
/// `mergeAIReresolution` sind die reine, testbare Auswahl-/Merge-Logik dahinter — ohne dass ein
/// Test FoundationModels-Verfügbarkeit braucht.
final class ReceiptScannerReResolutionTests: XCTestCase {

    func testUnresolvedShareHandoffLinesAreSelectedForReResolution() {
        let unresolved = EditableReceiptLine(name: "MDHSZ", price: 1.99, originalName: "MDHSZ")
        let aliasResolved = EditableReceiptLine(name: "Mozzarella", price: 2.49, originalName: "MOZ")

        let indices = EditableReceiptLine.linesNeedingAIReresolution([unresolved, aliasResolved])

        XCTAssertEqual(indices, [0], "Nur die noch unaufgelöste Zeile (name == originalName, kein KI-Treffer) braucht Stufe 5")
    }

    func testAlreadyResolvedByAILinesAreNotReResolvedAgain() {
        let alreadyAIResolved = EditableReceiptLine(name: "MDHSZ", price: 1.99, originalName: "MDHSZ", resolvedByAI: true)

        let indices = EditableReceiptLine.linesNeedingAIReresolution([alreadyAIResolved])

        XCTAssertTrue(indices.isEmpty, "Ein bereits per KI aufgelöster Name darf nicht doppelt angefasst werden")
    }

    func testMergeAppliesAIResolvedNameSuggestionsAndFlagOnlyAtTargetedIndices() {
        let untouched = EditableReceiptLine(name: "Butter", price: 1.49, originalName: "Butter")
        let target = EditableReceiptLine(name: "MDHSZ", price: 1.99, originalName: "MDHSZ")
        let resolvedLine = ResolvedReceiptLine(
            name: "Mozzarella", originalName: "MDHSZ", price: 1.99, quantity: 1, unit: "",
            suggestions: [ReceiptSuggestion(name: "Mozzarella", itemID: UUID())],
            matchedItemID: nil, resolvedByAI: true
        )

        let merged = EditableReceiptLine.mergeAIReresolution(
            into: [untouched, target], resolved: [resolvedLine], at: [1]
        )

        XCTAssertEqual(merged[0].name, "Butter", "Nicht ausgewählte Zeile muss unverändert bleiben")
        XCTAssertEqual(merged[1].name, "Mozzarella")
        XCTAssertEqual(merged[1].suggestions.map(\.name), ["Mozzarella"])
        XCTAssertTrue(merged[1].resolvedByAI)
    }
}
