import Foundation

/// Prozessübergreifender Handoff einer per Share Extension erkannten Bon-Auswertung an die
/// Haupt-App — analog zum `widgetDidCheckOffItem`-Flag-Muster (`SyncCoordinator.swift`), nur mit
/// echter Nutzlast statt eines reinen Bool-Flags. Typische Nutzlastgröße (ein ganzer Bon) liegt
/// weit unter dem, was für App-Group-`UserDefaults` unangemessen wäre — ein eigenes
/// App-Group-File wäre hier unnötige Komplexität.
enum ReceiptShareHandoff {
    private static let suite = UserDefaults(suiteName: SharedModelContainer.appGroupID)
    private static let key = "pendingShareExtensionReceipt"

    static func store(_ payload: SharedReceiptPayload) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        suite?.set(data, forKey: key)
    }

    /// Liest UND löscht in einem Schritt — eine Nutzlast wird genau einmal konsumiert, damit ein
    /// erneutes Öffnen der App (ohne neuen Teilen-Vorgang) nicht denselben Bon noch einmal zeigt.
    static func takePending() -> SharedReceiptPayload? {
        guard let data = suite?.data(forKey: key) else { return nil }
        suite?.removeObject(forKey: key)
        return try? JSONDecoder().decode(SharedReceiptPayload.self, from: data)
    }
}

/// Wire-Format zwischen der Share Extension und der Haupt-App. `lines` nutzt `ResolvedReceiptLine`
/// direkt (schon `Codable`, exakt die Form, die die Auflösungs-Pipeline ohnehin liefert) statt
/// einen zweiten, praktisch identischen Typ zu pflegen.
struct SharedReceiptPayload: Codable {
    var storeID: UUID?
    var lines: [ResolvedReceiptLine]
    var rawLines: [String]
    var detectedTotal: Double?
}
