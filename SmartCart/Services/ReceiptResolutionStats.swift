import Foundation

/// Zählt je Auflösungsstufe (`ReceiptResolutionStage`), wie viele Bon-Zeilen gespeichert, im
/// Review umbenannt und abgewählt wurden (Issue #14, „Messung zuerst“). Nur Zahlen, keine Namen,
/// keine Preise — lokal in der App-Gruppe, kein Sync. Gezählt wird ausschließlich in
/// `ReceiptScannerView.save()` (MainActor), die Share Extension schreibt hier nie.
/// Spec: `docs/specs/services/receipt-resolution-stats.md`.
struct ReceiptResolutionStats {
    struct Counts: Codable, Equatable {
        var total = 0, changed = 0, deselected = 0
    }

    static let storageKey = "smartcart.receiptResolutionStats.v1"

    let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults(suiteName: SharedModelContainer.appGroupID) ?? .standard) {
        self.defaults = defaults
    }

    func counts(for stage: ReceiptResolutionStage) -> Counts {
        stored()[stage.rawValue] ?? Counts()
    }

    /// Addiert die Zählung eines gespeicherten Bons auf die bisherigen Werte.
    func record(_ lines: [EditableReceiptLine]) {
        var map = stored()
        for (stage, counts) in Self.tally(lines) {
            var sum = map[stage.rawValue] ?? Counts()
            sum.total += counts.total
            sum.changed += counts.changed
            sum.deselected += counts.deselected
            map[stage.rawValue] = sum
        }
        guard let data = try? JSONEncoder().encode(map) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    func reset() {
        defaults.removeObject(forKey: Self.storageKey)
    }

    /// Reine Zählung ohne I/O. Zeilen ohne Stufe (Alt-Payload) werden übersprungen. Abgewählt
    /// zählt nie als geändert; geändert heißt: finaler Name weicht nach Trimmen und ohne
    /// Groß-/Kleinschreibung vom Namen direkt nach der Auflösung ab.
    static func tally(_ lines: [EditableReceiptLine]) -> [ReceiptResolutionStage: Counts] {
        var result: [ReceiptResolutionStage: Counts] = [:]
        for line in lines {
            guard let stage = line.stage else { continue }
            var counts = result[stage] ?? Counts()
            counts.total += 1
            if !line.isIncluded {
                counts.deselected += 1
            } else if normalized(line.name) != normalized(line.resolvedName) {
                counts.changed += 1
            }
            result[stage] = counts
        }
        return result
    }

    private static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespaces).lowercased()
    }

    private func stored() -> [String: Counts] {
        guard let data = defaults.data(forKey: Self.storageKey),
              let map = try? JSONDecoder().decode([String: Counts].self, from: data) else { return [:] }
        return map
    }
}
