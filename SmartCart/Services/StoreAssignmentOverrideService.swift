import Foundation

/// Merkt sich eine manuelle Laden-Korrektur, die der Nutzer über den Quick-Add-Toast trifft
/// ("Zu Lidl hinzugefügt" antippen → anderen Laden wählen), damit derselbe Artikelname beim
/// nächsten Mal direkt richtig zugeordnet wird — ohne auf `AssignmentService.dominantStore`s
/// Kaufhistorie-Schwelle (>50 % der bisherigen Käufe) zu warten, die bei einer frischen Korrektur
/// noch gar keine Datenbasis hat. Wird in `AssignmentService.assign` als allererste Stufe geprüft
/// (vor Kaufhistorie), da eine explizite Nutzer-Korrektur immer Vorrang vor einem nur abgeleiteten
/// Muster haben soll. UserDefaults-basiert im Stil von `ReceiptAliasService` — bewusst KEIN
/// SwiftData-Schema-Update. App-Group-Suite (nicht `.standard`), damit `AddItemIntent` (Siri,
/// läuft out-of-process) dieselbe Korrektur sieht wie die Haupt-App.
final class StoreAssignmentOverrideService {
    static let shared = StoreAssignmentOverrideService()
    private let storageKey = "smartcart.storeAssignmentOverrides"
    private static let suite = UserDefaults(suiteName: SharedModelContainer.appGroupID) ?? .standard
    /// Wert ist der Laden-NAME, nicht die UUID — gleiches Muster wie `PurchaseRecord.storeName`/
    /// `dominantStore`, überlebt dadurch ein Löschen+Neuanlegen desselben Ladens unter gleichem
    /// Namen, und Auflösung gegen `activeStores` läuft überall identisch (Name, case-insensitive).
    private var overrides: [String: String] = [:]

    private init() { load() }

    /// Gemerkten Laden-Namen für einen Artikelnamen nachschlagen (normalisiert, exakt).
    func storeName(for itemName: String) -> String? {
        overrides[normalize(itemName)]
    }

    /// Korrektur merken. Leerer/zu kurzer Name wird ignoriert statt eine nutzlose Zuordnung zu
    /// speichern (gleiche Guard-Schwelle wie `ReceiptAliasService.learn`).
    func remember(itemName: String, storeName: String) {
        let key = normalize(itemName)
        guard key.count >= 2, !storeName.isEmpty else { return }
        guard overrides[key] != storeName else { return }
        overrides[key] = storeName
        persist()
    }

    private func normalize(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    private func load() {
        guard let data = Self.suite.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        overrides = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(overrides) else { return }
        Self.suite.set(data, forKey: storageKey)
    }
}

/// Nutzer-konfigurierter Standard-Laden pro Kategorie-Gruppe (Lebensmittel/Drogerie/Sonstiges/
/// Baumarkt — dieselben vier Gruppen, die `AssignmentService.assign` schon per Keyword-Suche
/// unterscheidet). Ausgangspunkt war ein Nutzerbericht (14.09.2026): Artikel landeten trotz
/// nie dort getätigter Käufe immer bei Rewe, weil der bisherige Fallback rein auf
/// `Store.visitsPerWeek` beruhte — einer manuell im Laden-Setup gesetzten Zahl, deren Wirkung
/// auf die automatische Zuordnung den meisten Nutzern gar nicht bewusst ist. Hier kann der
/// Nutzer stattdessen einen Laden EXPLIZIT pro Kategorie festlegen; das schlägt in `assign` die
/// automatische Kaufhistorie-/Besuchsfrequenz-Heuristik (`bestFallback`), genau wie
/// `StoreAssignmentOverrideService` oben das schon für einzelne Artikelnamen tut.
/// Gleiches UserDefaults-Muster (App-Group-Suite, kein SwiftData-Schema-Update).
final class DefaultStoreService {
    static let shared = DefaultStoreService()
    private let storageKey = "smartcart.defaultStoresByCategoryGroup"
    private static let suite = UserDefaults(suiteName: SharedModelContainer.appGroupID) ?? .standard
    /// Key ist die Kategorie-Gruppe ("grocery"/"drugstore"/"variety"/"hardware" — dieselben
    /// Literale, die `AssignmentService.assign` an `preferredDefault(for:among:)` übergibt),
    /// Value der Laden-NAME (nicht die UUID — gleiches Muster wie `overrides` oben, überlebt
    /// dadurch ein Löschen+Neuanlegen desselben Ladens unter gleichem Namen).
    private var defaults: [String: String] = [:]

    private init() { load() }

    func storeName(for groupKey: String) -> String? {
        defaults[groupKey]
    }

    func setStoreName(_ storeName: String?, for groupKey: String) {
        if let storeName, !storeName.isEmpty {
            defaults[groupKey] = storeName
        } else {
            defaults.removeValue(forKey: groupKey)
        }
        persist()
    }

    private func load() {
        guard let data = Self.suite.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        defaults = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(defaults) else { return }
        Self.suite.set(data, forKey: storageKey)
    }
}
