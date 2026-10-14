import Foundation

/// Abhak-Warteschlange von Dynamic Island, Sperrbildschirm und Homescreen-Widget — die eine
/// gemeinsame Quelle für App (`StoreDetailView`) und Widget (`ShoppingListWidget`), kompiliert in
/// beiden Zielen (Issue #98, Durchgang 8; vorher zwei wortgleiche Kopien „keep in sync“).
///
/// Schlüssel in der App-Gruppe: `pendingCheckoffIDs_<Laden>` (Artikel-UUIDs, Queue-Reihenfolge)
/// und der Legacy-Zähler `pendingCheckoffs_<Laden>` einer alten App-Version. Speichern und
/// Anzeige-Update bleiben beim Aufrufer.
enum CheckoffQueue {

    /// Hängt die UUID an die Warteschlange des Ladens an. Gequeut wird die UUID, NICHT ein Zähler:
    /// ein Zähler („erledige die ersten N pendingItems“) erledigt das falsche Item, sobald
    /// Widget-Checkoffs oder ein Sync-Merge die Pending-Liste zwischen Anzeige und Drain verschoben
    /// haben. Duplikate sind harmlos — der Drain überspringt bereits erledigte Items.
    static func enqueue(
        itemID: UUID,
        storeName: String,
        defaults: UserDefaults? = UserDefaults(suiteName: SharedModelContainer.appGroupID)
    ) {
        let idKey = "pendingCheckoffIDs_\(storeName)"
        var queued = defaults?.stringArray(forKey: idKey) ?? []
        queued.append(itemID.uuidString)
        defaults?.set(queued, forKey: idKey)
    }

    /// Offene Artikel abzüglich der schon gequeueten Checkoffs (noch nicht gedraint). Ohne diese
    /// Korrektur zeigte das Widget Artikel erneut, die in der Live Activity schon abgehakt sind —
    /// und ein Tipp dort UND hier würde nach dem Drain doppelt zählen.
    static func effectivePending(
        for store: Store,
        defaults: UserDefaults? = UserDefaults(suiteName: SharedModelContainer.appGroupID)
    ) -> [ShoppingItem] {
        var pending = store.pendingItems
        let queuedIDs = Set(
            (defaults?.stringArray(forKey: "pendingCheckoffIDs_\(store.name)") ?? [])
                .compactMap(UUID.init(uuidString:))
        )
        if !queuedIDs.isEmpty {
            pending.removeAll { queuedIDs.contains($0.id) }
        }
        // Legacy-Zähler (Queue einer alten App-Version, s. drain): count-basiert.
        let legacyCount = defaults?.integer(forKey: "pendingCheckoffs_\(store.name)") ?? 0
        if legacyCount > 0 {
            pending = Array(pending.dropFirst(legacyCount))
        }
        return pending
    }

    /// Arbeitet die Warteschlange in den Laden ab: erledigt exakt die gequeueten UUIDs; bereits
    /// erledigte IDs (Doppel-Drain, Sync-Merge, Doppeltipp-Duplikate) und unbekannte sind No-ops.
    /// Rückgabe: Anzahl tatsächlich abgehakter Artikel.
    ///
    /// Bekannte Mikro-Lücke (dokumentiert, bewusst kein prozessübergreifendes Schloss): lesen App
    /// und Widget dieselbe Queue gleichzeitig, können beide eine UUID beanspruchen — der
    /// `!item.isCompleted`-Schutz macht das beim später Laufenden zum No-op, sobald das erste
    /// Speichern gelandet ist; ein wirklich gleichzeitiger Zugriff könnte doppelt buchen. Akzeptiert.
    ///
    /// Jeder gedrainte Haken geht in Queue-Reihenfolge in den laufenden Einkauf des Ladens
    /// (`Store.recordCheckOff`, Issue #79) — mit `batched: true`, weil die Queue die echte
    /// Abhak-Reihenfolge hält, aber nicht den Zeitpunkt: zählt für den Einkaufsweg, nicht für die
    /// Erkennung „zu Hause nachgetragen“.
    @discardableResult
    static func drain(
        for store: Store,
        defaults: UserDefaults? = UserDefaults(suiteName: SharedModelContainer.appGroupID)
    ) -> Int {
        var applied = 0

        // UUID-Queue: exakt die gequeueten Items erledigen (nicht "die ersten N" —
        // count-basiert würde nach Widget-Checkoff/Sync-Merge das falsche Item treffen).
        let idKey = "pendingCheckoffIDs_\(store.name)"
        if let queuedIDs = defaults?.stringArray(forKey: idKey), !queuedIDs.isEmpty {
            defaults?.removeObject(forKey: idKey)
            for idString in queuedIDs {
                guard let id = UUID(uuidString: idString),
                      let item = store.items?.first(where: { $0.id == id }),
                      !item.isCompleted else { continue }
                item.markCompleted()
                store.recordCheckOff(item, batched: true)
                applied += 1
            }
        }

        // Legacy (einmaliger Übergang): Zähler-Key einer alten App-Version noch
        // count-basiert drainen, damit ein Update mitten im Einkauf nichts verliert.
        let legacyKey = "pendingCheckoffs_\(store.name)"
        let legacyCount = defaults?.integer(forKey: legacyKey) ?? 0
        if legacyCount > 0 {
            defaults?.removeObject(forKey: legacyKey)
            for _ in 0..<legacyCount {
                guard let item = store.pendingItems.first else { break }
                item.markCompleted()
                store.recordCheckOff(item, batched: true)
                applied += 1
            }
        }
        return applied
    }
}
