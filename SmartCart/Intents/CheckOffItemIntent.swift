import AppIntents
import ActivityKit

struct CheckOffItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Nächsten Artikel abhaken"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Laden")
    var storeName: String

    init() { storeName = "" }
    init(storeName: String) { self.storeName = storeName }

    func perform() async throws -> some IntentResult {
        // Finde die aktive Live Activity für diesen Store
        guard let activity = Activity<ShoppingActivityAttributes>.activities
            .first(where: { $0.attributes.storeName == storeName }),
              !activity.content.state.pendingItemNames.isEmpty
        else { return .result() }

        let current = activity.content.state
        var remaining = current.pendingItemNames
        remaining.removeFirst()

        // Live Activity sofort optimistisch aktualisieren — kein SwiftData nötig
        let newState = ShoppingActivityAttributes.ContentState(
            completedCount: current.completedCount + 1,
            totalCount: current.totalCount,
            nextItemName: remaining.first,
            pendingItemNames: remaining,
            storeColorHex: current.storeColorHex
        )
        await activity.update(ActivityContent(state: newState, staleDate: nil))

        // Persistierung wird von der Hauptapp beim nächsten Öffnen des Stores erledigt
        let defaults = UserDefaults(suiteName: "group.com.johannesemmrich.SmartCart")
        let key = "pendingCheckoffs_\(storeName)"
        defaults?.set((defaults?.integer(forKey: key) ?? 0) + 1, forKey: key)

        return .result()
    }
}
