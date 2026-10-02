import Foundation

// Issue #79: Ladenliste nach gelerntem Einkaufsweg sortieren.
//
// Reine, testbare Logik (keine SwiftData-, keine UserDefaults-Abhängigkeit) — `Store` liefert nur
// die gespeicherten Werte hinein und schreibt die Ergebnisse zurück (`Store+ShoppingRoute` unten
// in `Store.swift`). Diese Datei wird wie `Store.swift` in App, Widget und Share Extension
// kompiliert; sie darf deshalb nichts aus reinen App-Dateien (z. B. `HabitService.swift`) nutzen.

/// Sortierung der offenen Artikel eines Ladens, pro Laden im ···-Menü wählbar.
enum StoreSortMode: String, CaseIterable, Codable {
    /// Gelernter Weg durch den Laden (Reihenfolge des Abhakens bei früheren Einkäufen).
    case route
    /// Nach Kategorien gruppiert, Kategorien in der gelernten Reihenfolge dieses Ladens.
    case category
    /// Reihenfolge, in der die Artikel auf die Liste kamen.
    case added

    var label: String {
        switch self {
        case .route: return String(localized: "store.sort.route")
        case .category: return String(localized: "store.sort.category")
        case .added: return String(localized: "store.sort.added")
        }
    }

    var systemImage: String {
        switch self {
        case .route: return "figure.walk"
        case .category: return "square.grid.3x1.below.line.grid.1x2"
        case .added: return "clock"
        }
    }

    /// Voreinstellung für Läden, die noch keinen eigenen Modus gespeichert haben: übernimmt die
    /// bisherigen Einstellungen (Kategorie-Gruppierung pro Laden, globaler Schalter
    /// „Automatisch nach Einkaufsreihenfolge sortieren“), damit sich nach dem Update nichts
    /// ungefragt umstellt.
    static func migratedDefault(groupByCategory: Bool, autoSortByLearnedOrder: Bool) -> StoreSortMode {
        if groupByCategory { return .category }
        return autoSortByLearnedOrder ? .route : .added
    }
}

/// Ein Einkauf in einem Laden: die in dieser Reihenfolge abgehakten Artikel. Wird gespeichert,
/// damit die Zählung nicht neu beginnt, wenn man die Ladenansicht mitten im Einkauf verlässt.
struct ShoppingTrip: Codable, Equatable {
    struct Entry: Codable, Equatable {
        var key: String
        var category: String
        var date: Date
        /// Aus einer Warteschlange nachgetragen (Dynamic Island/Widget): Reihenfolge stimmt,
        /// der Zeitpunkt aber nicht — zählt deshalb nicht für die Erkennung „zu Hause abgehakt“.
        var batched: Bool
    }

    var entries: [Entry] = []

    var lastActivity: Date? { entries.map(\.date).max() }
}

/// Gelernte Reihenfolge eines Ladens (pro Gerät gespeichert).
struct ShoppingRouteModel: Codable, Equatable {
    /// Artikelschlüssel → normalisierte Position 0 (Anfang des Weges) … 1 (Ende).
    var itemPositions: [String: Double] = [:]
    /// Artikelschlüssel → Kategorie, mit der der Artikel zuletzt abgehakt wurde.
    var itemCategories: [String: String] = [:]
}

enum ShoppingRoute {
    /// Längere Pause zwischen zwei Haken in einem Laden beginnt einen neuen Einkauf.
    static let tripGap: TimeInterval = 30 * 60
    /// Aus der Dynamic-Island-/Widget-Warteschlange nachgetragene Haken tragen den Zeitpunkt des
    /// Nachtragens, nicht des Abhakens — sie setzen deshalb den laufenden Einkauf fort (sonst
    /// würde ein Weg, halb in der App und halb per Island abgehakt, in zwei Einkäufe zerfallen).
    /// Nur ein Einkauf, der älter als dieses Fenster ist, wird vorher abgeschlossen.
    static let batchedTripGap: TimeInterval = 6 * 3600
    /// Gewicht eines neuen Einkaufs im gleitenden Mittel. Ein Ausreißer verschiebt eine Position
    /// nur um 30 % statt (wie früher) um die Hälfte; ein Umbau im Laden ist nach wenigen
    /// Einkäufen trotzdem gelernt.
    static let learningRate = 0.3
    /// Ab so vielen Artikeln zählt ein Einkauf mit vollem Gewicht. Kleinere Einkäufe spreizen
    /// ihre wenigen Artikel künstlich auf 0…1 und lernen deshalb anteilig schwächer.
    static let fullWeightTripSize = 5
    /// Zwei Haken in kürzerem Abstand gelten als „schnell nacheinander“.
    static let bulkGap: TimeInterval = 2
    /// Sind mindestens so viele der Abstände „schnell“, wurde nachträglich (zu Hause)
    /// abgehakt — die Reihenfolge sagt dann nichts über den Weg im Laden.
    static let bulkShare = 0.8

    // MARK: Schlüssel

    /// Satzzeichen, die nur am Rand ignoriert werden (siehe `ReplenishmentItemIdentity`).
    private static let edgeCharacters = CharacterSet.whitespacesAndNewlines
        .union(CharacterSet(charactersIn: ".,;:!?*-–—\"'„“”‚‘’"))

    /// Artikelschlüssel für rein formale Unterschiede: klein geschrieben, Leerzeichenfolgen zu
    /// einem Leerzeichen, Leerzeichen und Satzzeichen am Rand entfernt. Einzige Implementierung —
    /// `ReplenishmentItemIdentity.formalKey` ruft diese Funktion auf, damit Einkaufsweg und
    /// Nachkauf denselben Artikel immer gleich erkennen.
    static func itemKey(_ name: String) -> String {
        let collapsed = name.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let trimmed = collapsed.trimmingCharacters(in: edgeCharacters)
        return trimmed.isEmpty ? collapsed : trimmed
    }

    // MARK: Aufzeichnen

    /// Einkauf abschließen und lernen, wenn seit dem letzten Haken mehr als `gap` vergangen ist.
    static func finalizeIfStale(
        trip: ShoppingTrip,
        model: ShoppingRouteModel,
        now: Date,
        gap: TimeInterval = ShoppingRoute.tripGap
    ) -> (trip: ShoppingTrip, model: ShoppingRouteModel) {
        guard let last = trip.lastActivity, now.timeIntervalSince(last) > gap else { return (trip, model) }
        return (ShoppingTrip(), learn(trip, into: model))
    }

    /// Einen Haken aufzeichnen. Ein älterer Einkauf wird vorher abgeschlossen und gelernt
    /// (bei `batched` erst nach `batchedTripGap`). Jeder Artikel zählt pro Einkauf nur beim
    /// ersten Haken.
    static func recordCheckOff(
        key: String,
        category: String,
        at date: Date,
        batched: Bool = false,
        trip: ShoppingTrip,
        model: ShoppingRouteModel
    ) -> (trip: ShoppingTrip, model: ShoppingRouteModel) {
        var (trip, model) = finalizeIfStale(trip: trip, model: model, now: date, gap: batched ? batchedTripGap : tripGap)
        guard !trip.entries.contains(where: { $0.key == key }) else { return (trip, model) }
        trip.entries.append(.init(key: key, category: category, date: date, batched: batched))
        return (trip, model)
    }

    /// Haken zurückgenommen: der Artikel zählt in diesem Einkauf nicht mehr (wird er erneut
    /// abgehakt, zählt die neue Stelle).
    static func recordUncheck(key: String, trip: ShoppingTrip) -> ShoppingTrip {
        var trip = trip
        trip.entries.removeAll { $0.key == key }
        return trip
    }

    // MARK: Lernen

    /// Nachträglich abgehakt? Bewertet nur Abstände zwischen zwei direkt angetippten Haken.
    static func isBulkCheckOff(_ trip: ShoppingTrip) -> Bool {
        let tapped = trip.entries.filter { !$0.batched }.map(\.date)
        guard tapped.count >= 3 else { return false }
        let gaps = zip(tapped.dropFirst(), tapped).map { $0.timeIntervalSince($1) }
        let fast = gaps.filter { $0 < bulkGap }.count
        return Double(fast) / Double(gaps.count) >= bulkShare
    }

    /// Einen abgeschlossenen Einkauf ins Modell übernehmen.
    static func learn(_ trip: ShoppingTrip, into model: ShoppingRouteModel) -> ShoppingRouteModel {
        let entries = trip.entries
        guard entries.count >= 2, !isBulkCheckOff(trip) else { return model }
        var model = model
        let span = Double(entries.count - 1)
        let weight = min(1, span / Double(fullWeightTripSize - 1))
        for (index, entry) in entries.enumerated() {
            let observed = Double(index) / span
            if let old = model.itemPositions[entry.key] {
                model.itemPositions[entry.key] = old + learningRate * weight * (observed - old)
            } else {
                model.itemPositions[entry.key] = observed
            }
            model.itemCategories[entry.key] = entry.category
        }
        return model
    }

    // MARK: Sortieren

    /// Mittlere gelernte Position je Kategorie in diesem Laden.
    static func categoryPositions(_ model: ShoppingRouteModel) -> [String: Double] {
        var sums: [String: (total: Double, count: Int)] = [:]
        for (key, position) in model.itemPositions {
            guard let category = model.itemCategories[key] else { continue }
            let current = sums[category] ?? (0, 0)
            sums[category] = (current.total + position, current.count + 1)
        }
        return sums.mapValues { $0.total / Double($0.count) }
    }

    /// Kategorien in der Reihenfolge dieses Ladens: gelernte nach ihrer mittleren Position,
    /// danach die übrigen in der festen Supermarkt-Reihenfolge, danach alphabetisch.
    static func orderedCategories(
        _ categories: [String],
        model: ShoppingRouteModel,
        staticOrder: [String]
    ) -> [String] {
        orderedCategories(categories, learned: categoryPositions(model), staticOrder: staticOrder)
    }

    private static func orderedCategories(
        _ categories: [String],
        learned: [String: Double],
        staticOrder: [String]
    ) -> [String] {
        Array(Set(categories)).sorted { a, b in
            switch (learned[a], learned[b]) {
            case let (pa?, pb?) where pa != pb: return pa < pb
            case (.some, nil): return true
            case (nil, .some): return false
            default:
                let sa = staticOrder.firstIndex(of: a) ?? Int.max
                let sb = staticOrder.firstIndex(of: b) ?? Int.max
                if sa != sb { return sa < sb }
                return a < b
            }
        }
    }

    /// Was zum Sortieren eines offenen Artikels nötig ist.
    struct SortInput {
        var key: String
        var category: String
        var isUrgent: Bool
        var addedDate: Date
    }

    /// Reihenfolge der offenen Artikel als Indizes in `items`. Dringende immer zuerst.
    ///
    /// - `.route`: gelernte Position; ein noch nie abgehakter Artikel bekommt die mittlere
    ///   Position seiner Kategorie in diesem Laden (neuer Feta landet beim Käse). Ohne beides
    ///   stehen die Artikel dahinter, in Kategorie-Reihenfolge.
    /// - `.category`: Kategorien in Ladenreihenfolge (`orderedCategories`), darin nach Position.
    /// - `.added`: Hinzufügedatum.
    static func sortedIndices(
        _ items: [SortInput],
        mode: StoreSortMode,
        model: ShoppingRouteModel,
        staticCategoryOrder: [String]
    ) -> [Int] {
        let learnedCategories = categoryPositions(model)
        let categoryRank: [String: Int] = Dictionary(
            uniqueKeysWithValues: orderedCategories(items.map(\.category), learned: learnedCategories, staticOrder: staticCategoryOrder)
                .enumerated().map { ($1, $0) }
        )
        func routePosition(_ item: SortInput) -> Double? {
            model.itemPositions[item.key] ?? learnedCategories[item.category]
        }

        return items.indices.sorted { ia, ib in
            let a = items[ia], b = items[ib]
            if a.isUrgent != b.isUrgent { return a.isUrgent }
            switch mode {
            case .added:
                break
            case .category:
                let ra = categoryRank[a.category] ?? Int.max
                let rb = categoryRank[b.category] ?? Int.max
                if ra != rb { return ra < rb }
                let pa = model.itemPositions[a.key], pb = model.itemPositions[b.key]
                switch (pa, pb) {
                case let (x?, y?) where x != y: return x < y
                case (.some, nil): return true
                case (nil, .some): return false
                default: break
                }
            case .route:
                switch (routePosition(a), routePosition(b)) {
                case let (x?, y?) where x != y: return x < y
                case (.some, nil): return true
                case (nil, .some): return false
                case (.some, .some): break
                case (nil, nil):
                    let ra = categoryRank[a.category] ?? Int.max
                    let rb = categoryRank[b.category] ?? Int.max
                    if ra != rb { return ra < rb }
                }
            }
            if a.addedDate != b.addedDate { return a.addedDate < b.addedDate }
            return ia < ib
        }
    }

    // MARK: Von Hand verschieben (Issue #86)

    /// Abstand für Positionen vor dem ersten bzw. hinter dem letzten festen Nachbarn.
    static let manualStep = 0.02

    /// Positionen für eine Reihenfolge, die von oben nach unten gilt. Möglichst viele bisherige
    /// Werte bleiben stehen (längste streng aufsteigende Teilfolge); alle übrigen — `nil` oder
    /// nicht mehr passend — werden zwischen ihren festen Nachbarn verteilt. So verschiebt ein
    /// Ziehen nur die gezogene Zeile und nicht den ganzen gelernten Weg.
    static func positionsPreservingOrder(_ current: [Double?]) -> [Double] {
        let n = current.count
        guard n > 0 else { return [] }
        // Längste streng aufsteigende Teilfolge über die vorhandenen Werte (n ist klein).
        var length = [Int](repeating: 0, count: n)
        var previous = [Int](repeating: -1, count: n)
        var best = -1
        for i in 0..<n {
            guard let vi = current[i] else { continue }
            length[i] = 1
            for j in 0..<i {
                if let vj = current[j], vj < vi, length[j] + 1 > length[i] {
                    length[i] = length[j] + 1
                    previous[i] = j
                }
            }
            if best < 0 || length[i] > length[best] { best = i }
        }
        guard best >= 0 else {
            return n == 1 ? [0.5] : (0..<n).map { Double($0) / Double(n - 1) }
        }
        var anchors: [Int] = []
        var index = best
        while index >= 0 {
            anchors.append(index)
            index = previous[index]
        }
        anchors.reverse()

        var result = [Double](repeating: 0, count: n)
        for a in anchors { result[a] = current[a]! }
        let first = anchors[0], last = anchors[anchors.count - 1]
        for i in 0..<first { result[i] = result[first] - manualStep * Double(first - i) }
        for i in (last + 1)..<n { result[i] = result[last] + manualStep * Double(i - last) }
        for (a, b) in zip(anchors, anchors.dropFirst()) where b - a > 1 {
            for i in (a + 1)..<b {
                result[i] = result[a] + (result[b] - result[a]) * Double(i - a) / Double(b - a)
            }
        }
        return result
    }

    /// Eine von Hand festgelegte Artikel-Reihenfolge (Modus Einkaufsweg, ohne Dringende) ins
    /// Modell schreiben. Die gezogene Zeile landet zwischen ihren neuen Nachbarn; Artikel ohne
    /// eigene Position (bisher über den Kategorie-Mittelwert einsortiert) bekommen eine. Das
    /// Lernen beim Abhaken läuft danach normal weiter — die Verschiebung ist ein Startwert.
    static func applyManualOrder(
        _ items: [SortInput],
        movedKey: String?,
        model: ShoppingRouteModel
    ) -> ShoppingRouteModel {
        let learnedCategories = categoryPositions(model)
        let current: [Double?] = items.map {
            $0.key == movedKey ? nil : (model.itemPositions[$0.key] ?? learnedCategories[$0.category])
        }
        var model = model
        for (item, position) in zip(items, positionsPreservingOrder(current)) {
            if model.itemPositions[item.key] != position { model.itemPositions[item.key] = position }
            model.itemCategories[item.key] = item.category
        }
        return model
    }

    /// Eine von Hand festgelegte Abschnitts-Reihenfolge (Modus Kategorie) ins Modell schreiben.
    /// Eine Kategorie mit gelernten Artikeln wird als Ganzes verschoben (alle Positionen um
    /// denselben Betrag), damit ihr Mittelwert auf dem Zielplatz landet; eine noch ungelernte
    /// bekommt den Zielplatz für ihre offenen Artikel (`items`).
    static func applyManualCategoryOrder(
        _ categories: [String],
        movedCategory: String?,
        items: [SortInput],
        model: ShoppingRouteModel
    ) -> ShoppingRouteModel {
        let learned = categoryPositions(model)
        let current: [Double?] = categories.map { $0 == movedCategory ? nil : learned[$0] }
        var model = model
        for (category, target) in zip(categories, positionsPreservingOrder(current)) {
            if let mean = learned[category] {
                let delta = target - mean
                guard delta != 0 else { continue }
                for (key, itemCategory) in model.itemCategories where itemCategory == category {
                    if let position = model.itemPositions[key] { model.itemPositions[key] = position + delta }
                }
            } else {
                for item in items where item.category == category {
                    model.itemPositions[item.key] = target
                    model.itemCategories[item.key] = category
                }
            }
        }
        return model
    }

    /// Kategorie eines Artikels im gelernten Modell umbenennen (eigene Kategorie umbenannt).
    static func renameCategory(_ old: String, to new: String, in model: ShoppingRouteModel) -> ShoppingRouteModel {
        var model = model
        for (key, category) in model.itemCategories where category == old {
            model.itemCategories[key] = new
        }
        return model
    }
}
