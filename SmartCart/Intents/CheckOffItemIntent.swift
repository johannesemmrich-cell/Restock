import AppIntents
import ActivityKit
import Foundation
import WidgetKit

// LiveActivityIntent (statt AppIntent): Das System startet dafür den App-Prozess
// im Hintergrund und führt perform() DORT aus ("the system launches your app
// process without opening the app, performs the intent"). Nur im App-Prozess ist
// Activity<ShoppingActivityAttributes>.activities befüllt — als reiner AppIntent
// lief perform() im Widget-Extension-Prozess, sah keine Activity und fiel immer
// in den Legacy-Zähler-Fallback.
struct CheckOffItemIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Nächsten Artikel abhaken"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Laden")
    var storeName: String

    init() { storeName = "" }
    init(storeName: String) { self.storeName = storeName }

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.johannesemmrich.SmartCart")
        let activity = Activity<ShoppingActivityAttributes>.activities
            .first(where: { $0.attributes.storeName == storeName })

        // 1. Immer queuen — Hauptapp persistiert beim nächsten Store-Öffnen.
        //    Gequeut wird die UUID des aktuell angezeigten ersten Items, NICHT ein Zähler:
        //    ein Zähler ("erledige die ersten N pendingItems") erledigt das falsche Item,
        //    sobald Widget-Checkoffs oder ein Sync-Merge die Pending-Liste zwischen Anzeige
        //    und Drain verschoben haben (inkl. falschem PurchaseRecord und verfälschtem
        //    recordCompletionOrder-Lernen). Duplikate in der Queue sind harmlos — der Drain
        //    überspringt bereits erledigte Items (No-op-Guard).
        if let itemID = activity?.content.state.pendingItemIDs.first {
            let idKey = "pendingCheckoffIDs_\(storeName)"
            var queued = defaults?.stringArray(forKey: idKey) ?? []
            queued.append(itemID.uuidString)
            defaults?.set(queued, forKey: idKey)
        } else if let activity, !activity.content.state.pendingItemNames.isEmpty {
            // Fallback (nur Übergang): Live Activity aus einer App-Version ohne
            // pendingItemIDs im State (Names nicht leer, IDs leer) → alter Zähler-Key,
            // den beide Drains weiterhin einmalig legacy-drainen. So gehen mitten im
            // Einkauf gequeuete Checkoffs beim App-Update nicht verloren.
            // Ohne Activity oder mit leerer Pending-Liste (stale gerenderter Button
            // nach "alles erledigt") passiert bewusst NICHTS — ein liegengebliebener
            // Zähler würde sonst später ein neu hinzugefügtes Item ungefragt erledigen.
            let legacyKey = "pendingCheckoffs_\(storeName)"
            defaults?.set((defaults?.integer(forKey: legacyKey) ?? 0) + 1, forKey: legacyKey)
        }

        // Homescreen-Widget sofort nachziehen: dessen Timeline-Provider rechnet die hier
        // gequeueten Checkoffs aus der Anzeige heraus (siehe ShoppingListWidget), damit
        // Island- und Widget-Stand nie auseinanderlaufen.
        WidgetCenter.shared.reloadAllTimelines()

        // 2. Darwin-Notification: Hauptapp (im Hintergrund aktiv) aktualisiert Live Activity sofort.
        //    Reihenfolge zu Schritt 3 (perform() läuft als LiveActivityIntent jetzt IM App-Prozess,
        //    der Observer feuert also auch hier): handlePendingCheckoff wird als MainActor-Task
        //    gescheduled; zwischen Post und dem State-Read in Schritt 3 liegt kein await, daher
        //    lesen im Normalfall beide denselben Pre-Tap-State → beide berechnen den identischen
        //    Folge-State, das zweite update() ist idempotent. Läuft handlePendingCheckoff doch
        //    zuerst durch (inkl. gelandetem update), dekrementiert Schritt 3 die ANZEIGE einmal
        //    zu viel — reiner Anzeige-Glitch, den der nächste update(for:)/Drain-Rebuild aus dem
        //    Store korrigiert. Daten sind nie betroffen: pro Tap wird genau EINE UUID gequeut,
        //    und beide Drains überspringen bereits erledigte Items (No-op-Guard).
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName("com.johannesemmrich.SmartCart.pendingCheckoff" as CFString),
            nil, nil, true
        )

        // 3. Best-effort direktes Update aus diesem Kontext — entfernt IDs und Namen
        //    synchron aus dem Activity-State, damit ein schneller zweiter Tap die UUID
        //    des NÄCHSTEN Items enqueued statt dieselbe noch einmal.
        if let activity, !activity.content.state.pendingItemNames.isEmpty {
            let current = activity.content.state
            var remaining = current.pendingItemNames
            remaining.removeFirst()
            var remainingIDs = current.pendingItemIDs
            if !remainingIDs.isEmpty { remainingIDs.removeFirst() }
            let newState = ShoppingActivityAttributes.ContentState(
                completedCount: current.completedCount + 1,
                totalCount: current.totalCount,
                nextItemName: remaining.first,
                pendingItemNames: remaining,
                pendingItemIDs: remainingIDs,
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
