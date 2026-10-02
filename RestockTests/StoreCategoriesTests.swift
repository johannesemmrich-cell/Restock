import XCTest
@testable import Restock

/// Issue #85: eigene Kategorien pro Laden (`StoreCategories`, `Store`-API, `ShoppingItem.init`).
final class StoreCategoriesTests: XCTestCase {

    private let builtIn = ["Obst & Gemüse", "Backwaren", "Milchprodukte"]
    private func display(_ category: String) -> String { category == "Milchprodukte" ? "Dairy" : category }

    // MARK: Auflösen

    func testBuiltInNameWinsRegardlessOfCase() {
        XCTAssertEqual(StoreCategories.resolve("milchprodukte", builtIn: builtIn, displayName: display, custom: []), .builtIn("Milchprodukte"))
        XCTAssertEqual(StoreCategories.resolve(" DAIRY ", builtIn: builtIn, displayName: display, custom: []), .builtIn("Milchprodukte"))
    }

    func testExistingCustomIsReused() {
        XCTAssertEqual(
            StoreCategories.resolve("kühltheke HINTEN", builtIn: builtIn, displayName: display, custom: ["Kühltheke hinten"]),
            .existingCustom("Kühltheke hinten")
        )
    }

    func testNewNameIsNormalized() {
        XCTAssertEqual(StoreCategories.resolve("  Kühltheke   hinten ", builtIn: builtIn, displayName: display, custom: []), .new("Kühltheke hinten"))
        XCTAssertEqual(StoreCategories.resolve("   ", builtIn: builtIn, displayName: display, custom: []), .invalid)
    }

    // MARK: Emoji, Suche

    func testSuggestedEmoji() {
        XCTAssertEqual(StoreCategories.suggestedEmoji(for: "Kühltheke hinten"), "🧊")
        XCTAssertEqual(StoreCategories.suggestedEmoji(for: "Tiefkühl links"), "❄️")
        XCTAssertEqual(StoreCategories.suggestedEmoji(for: "Backstation"), "🥖")
        XCTAssertEqual(StoreCategories.suggestedEmoji(for: "Reis & Nudeln"), "🍝")
        XCTAssertEqual(StoreCategories.suggestedEmoji(for: "Gang 7"), StoreCategories.defaultEmoji)
    }

    func testSearchIgnoresCaseAndAccents() {
        XCTAssertTrue(StoreCategories.matches("Kühltheke hinten", query: "kuhl"))
        XCTAssertTrue(StoreCategories.matches("Kühltheke hinten", query: ""))
        XCTAssertFalse(StoreCategories.matches("Backstation", query: "kühl"))
    }

    // MARK: Abgleich geteilter Läden

    func testMergeLaterEntryWinsIncludingDeletion() {
        let old = Date(timeIntervalSince1970: 1_000), new = Date(timeIntervalSince1970: 2_000)
        let local = [
            "Kühltheke": CustomCategoryEntry(emoji: "🧊", date: old),
            "Backstation": CustomCategoryEntry(emoji: "🥖", date: new),
        ]
        let remote = [
            "Kühltheke": CustomCategoryEntry(emoji: nil, date: new),
            "Gang 7": CustomCategoryEntry(emoji: "🏷️", date: old),
        ]
        let merged = StoreCategories.merge(local: local, remote: remote)
        XCTAssertTrue(merged["Kühltheke"]!.isDeleted, "Die spätere Löschung gewinnt")
        XCTAssertEqual(merged["Backstation"]?.emoji, "🥖")
        XCTAssertEqual(merged["Gang 7"]?.emoji, "🏷️")
        XCTAssertEqual(StoreCategories.activeNames(merged), ["Backstation", "Gang 7"])
    }

    // MARK: Store

    func testStoreAddReturnsBuiltInInsteadOfDuplicate() {
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#2563EB")
        XCTAssertEqual(store.addCustomCategory("milchprodukte"), "Milchprodukte")
        XCTAssertTrue(store.customCategories.isEmpty)
    }

    func testStoreAddCreatesCategoryWithSuggestedEmoji() {
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#2563EB")
        XCTAssertEqual(store.addCustomCategory(" Kühltheke hinten"), "Kühltheke hinten")
        XCTAssertEqual(store.customCategories, ["Kühltheke hinten"])
        XCTAssertEqual(store.categoryEmoji("Kühltheke hinten"), "🧊")
        XCTAssertEqual(store.categoryEmoji("Milchprodukte"), AssignmentService.categoryEmoji("Milchprodukte"))
    }

    func testCategoryIsStoreSpecific() {
        let lidl = Store(name: "Lidl", emoji: "🛒", colorHex: "#2563EB")
        let edeka = Store(name: "Edeka", emoji: "🛒", colorHex: "#D97706")
        lidl.addCustomCategory("Kühltheke hinten")
        XCTAssertTrue(edeka.customCategories.isEmpty)
        XCTAssertFalse(edeka.isCustomCategory("Kühltheke hinten"))
    }

    func testNewItemLandsInRememberedCategory() {
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#2563EB")
        store.addCustomCategory("Kühltheke hinten")
        store.rememberCategory("Kühltheke hinten", forItemNamed: "Feta")

        let feta = ShoppingItem(name: " feta ", category: "Milchprodukte", store: store)
        XCTAssertEqual(feta.category, "Kühltheke hinten")
        XCTAssertTrue(feta.categoryManuallySet)

        let other = Store(name: "Edeka", emoji: "🛒", colorHex: "#D97706")
        let fetaElsewhere = ShoppingItem(name: "Feta", category: "Milchprodukte", store: other)
        XCTAssertEqual(fetaElsewhere.category, "Milchprodukte", "Die Zuordnung gilt nur im eigenen Laden")
    }

    func testChoosingBuiltInForgetsRememberedCategory() {
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#2563EB")
        store.addCustomCategory("Kühltheke hinten")
        store.rememberCategory("Kühltheke hinten", forItemNamed: "Feta")
        store.rememberCategory("Milchprodukte", forItemNamed: "Feta")
        XCTAssertNil(store.rememberedCategory(forItemNamed: "Feta"))
    }

    func testDeletingCategoryResetsItemsAndMemory() {
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#2563EB")
        store.addCustomCategory("Kühltheke hinten")
        let gouda = ShoppingItem(name: "Gouda", store: store)
        store.items = [gouda]
        gouda.category = "Kühltheke hinten"
        gouda.categoryManuallySet = true
        store.rememberCategory("Kühltheke hinten", forItemNamed: "Gouda")

        store.deleteCustomCategory("Kühltheke hinten")

        XCTAssertTrue(store.customCategories.isEmpty)
        XCTAssertTrue(store.customCategoryEntries["Kühltheke hinten"]!.isDeleted, "Löschvermerk für geteilte Läden")
        XCTAssertEqual(gouda.category, AssignmentService.category(for: "Gouda"))
        XCTAssertFalse(gouda.categoryManuallySet)
        XCTAssertNil(store.rememberedCategory(forItemNamed: "Gouda"))
    }

    func testRenamingMovesItemsAndMemory() {
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#2563EB")
        store.addCustomCategory("Kühltheke")
        let gouda = ShoppingItem(name: "Gouda", store: store)
        store.items = [gouda]
        gouda.category = "Kühltheke"
        gouda.categoryManuallySet = true
        store.rememberCategory("Kühltheke", forItemNamed: "Gouda")

        let result = store.updateCustomCategory("Kühltheke", name: "Kühltheke hinten", emoji: "❄️")

        XCTAssertEqual(result, "Kühltheke hinten")
        XCTAssertEqual(store.customCategories, ["Kühltheke hinten"])
        XCTAssertEqual(store.categoryEmoji("Kühltheke hinten"), "❄️")
        XCTAssertEqual(gouda.category, "Kühltheke hinten")
        XCTAssertEqual(store.rememberedCategory(forItemNamed: "Gouda"), "Kühltheke hinten")
    }

    // MARK: Zuordnungen teilen (Issue #94)

    func testAssignmentMergeLaterEntryWinsIncludingForgetting() {
        let old = Date(timeIntervalSince1970: 1_000), new = Date(timeIntervalSince1970: 2_000)
        let local = [
            "feta": CategoryAssignmentEntry(category: "Kühltheke", date: old),
            "gouda": CategoryAssignmentEntry(category: "Käsetheke", date: new),
        ]
        let remote = [
            "feta": CategoryAssignmentEntry(category: nil, date: new),
            "gouda": CategoryAssignmentEntry(category: "Kühltheke", date: old),
            "brot": CategoryAssignmentEntry(category: "Backstation", date: old),
        ]
        let merged = StoreCategories.mergeAssignments(local: local, remote: remote)
        XCTAssertNil(merged["feta"]?.category, "Das spätere Vergessen gewinnt")
        XCTAssertEqual(merged["gouda"]?.category, "Käsetheke", "Die spätere lokale Zuordnung gewinnt")
        XCTAssertEqual(merged["brot"]?.category, "Backstation", "Nur entfernt bekannte Zuordnungen kommen dazu")
    }

    func testRememberingStampsAssignmentForSharing() {
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#2563EB")
        store.addCustomCategory("Kühltheke")
        let before = Date()
        store.rememberCategory("Kühltheke", forItemNamed: "Feta")
        let entry = store.categoryAssignmentEntries["feta"]
        XCTAssertEqual(entry?.category, "Kühltheke")
        XCTAssertGreaterThanOrEqual(entry!.date, before)

        store.rememberCategory("Milchprodukte", forItemNamed: "Feta")
        XCTAssertNil(store.categoryAssignmentEntries["feta"]!.category, "Vergessen bleibt als Vermerk fürs Abgleichen")
        XCTAssertNil(store.rememberedCategory(forItemNamed: "Feta"))
    }

    func testRemoteAssignmentAppliesToNewItem() {
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#2563EB")
        store.addCustomCategory("Kühltheke")
        store.categoryAssignmentEntries = StoreCategories.mergeAssignments(
            local: store.categoryAssignmentEntries,
            remote: ["feta": CategoryAssignmentEntry(category: "Kühltheke", date: Date())]
        )
        let feta = ShoppingItem(name: "Feta", category: "Milchprodukte", store: store)
        XCTAssertEqual(feta.category, "Kühltheke", "Die Zuordnung eines anderen Mitglieds gilt auch hier")
    }

    func testLegacyAssignmentWithoutDateLosesToAnyRemoteState() {
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#2563EB")
        store.categoryAssignments = ["feta": "Kühltheke"]
        XCTAssertEqual(store.categoryAssignmentEntries["feta"], CategoryAssignmentEntry(category: "Kühltheke", date: .distantPast))
        let merged = StoreCategories.mergeAssignments(
            local: store.categoryAssignmentEntries,
            remote: ["feta": CategoryAssignmentEntry(category: nil, date: Date(timeIntervalSince1970: 1))]
        )
        XCTAssertNil(merged["feta"]?.category)
    }

    func testDeletingAndRenamingStampAssignments() {
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#2563EB")
        store.addCustomCategory("Kühltheke")
        store.addCustomCategory("Backstation")
        store.categoryAssignmentEntries = [
            "feta": CategoryAssignmentEntry(category: "Kühltheke", date: .distantPast),
            "brot": CategoryAssignmentEntry(category: "Backstation", date: .distantPast),
        ]
        store.updateCustomCategory("Kühltheke", name: "Kühltheke hinten", emoji: "🧊")
        store.deleteCustomCategory("Backstation")

        let entries = store.categoryAssignmentEntries
        XCTAssertEqual(entries["feta"]?.category, "Kühltheke hinten")
        XCTAssertGreaterThan(entries["feta"]!.date, .distantPast, "Umbenennen muss beim Abgleichen gewinnen")
        XCTAssertNil(entries["brot"]?.category)
        XCTAssertGreaterThan(entries["brot"]!.date, .distantPast, "Löschen muss beim Abgleichen gewinnen")
    }

    func testAssignmentsRoundTripThroughSharedRecordJSON() async {
        let entries = [
            "feta": CategoryAssignmentEntry(category: "Kühltheke", date: Date(timeIntervalSince1970: 1_000)),
            "brot": CategoryAssignmentEntry(category: nil, date: Date(timeIntervalSince1970: 2_000)),
        ]
        let service = SharedStoreService.shared
        let json = await service.encodeAssignments(entries)
        let decoded = await service.decodeAssignments(json)
        XCTAssertEqual(decoded, entries)
        let broken = await service.decodeAssignments("kaputt")
        XCTAssertEqual(broken, [:])
    }
}
