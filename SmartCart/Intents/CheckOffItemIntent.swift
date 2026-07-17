import AppIntents
import ActivityKit
import Foundation

struct CheckOffItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Nächsten Artikel abhaken"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Laden")
    var storeName: String

    init() { storeName = "" }
    init(storeName: String) { self.storeName = storeName }

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.johannesemmrich.SmartCart")
        let key = "pendingCheckoffs_\(storeName)"

        // 1. Immer queuen — Hauptapp persistiert beim nächsten Store-Öffnen
        defaults?.set((defaults?.integer(forKey: key) ?? 0) + 1, forKey: key)

        // 2. Darwin-Notification: Hauptapp (im Hintergrund aktiv) aktualisiert Live Activity sofort
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName("com.johannesemmrich.SmartCart.pendingCheckoff" as CFString),
            nil, nil, true
        )

        // 3. Best-effort direktes Update aus diesem Kontext
        if let activity = Activity<ShoppingActivityAttributes>.activities
            .first(where: { $0.attributes.storeName == storeName }),
           !activity.content.state.pendingItemNames.isEmpty {
            let current = activity.content.state
            var remaining = current.pendingItemNames
            remaining.removeFirst()
            let newState = ShoppingActivityAttributes.ContentState(
                completedCount: current.completedCount + 1,
                totalCount: current.totalCount,
                nextItemName: remaining.first,
                pendingItemNames: remaining,
                storeColorHex: current.storeColorHex
            )
            if remaining.isEmpty {
                // Letztes Item abgehakt → Activity beenden (4s Verzögerung,
                // damit der letzte Haken kurz sichtbar bleibt)
                await activity.end(
                    ActivityContent(state: newState, staleDate: nil),
                    dismissalPolicy: .after(Date().addingTimeInterval(4))
                )
            } else {
                await activity.update(ActivityContent(state: newState, staleDate: Date().addingTimeInterval(7200)))
            }
        }

        return .result()
    }
}
