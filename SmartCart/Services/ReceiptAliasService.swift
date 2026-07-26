import Foundation

/// Lernt Zuordnungen von Kassenbon-KÜRZELN ("BEURRIER EXT", "SHAK.MOUTARDE") zu echten
/// Artikelnamen. Gefüllt beim Speichern eines Scans in `ReceiptScannerView.save()`: hat der
/// User eine erkannte Position umbenannt (z. B. "Shak.moutarde" → "Senf") oder eine früher
/// gelernte Zuordnung bestätigt, wird das Kürzel→Name-Mapping gemerkt und beim nächsten Scan
/// automatisch angewendet (`resolve` in `ReceiptScannerView.process()`), sodass wiederkehrende
/// Bon-Kürzel direkt unter ihrem echten Artikelnamen erscheinen und damit auch das
/// `PurchaseRecord`-Matching und `Store.learnedPrices` den richtigen Artikel treffen.
/// UserDefaults-basiert im Stil von `TemplateService` — bewusst KEIN SwiftData-Schema-Update,
/// um Migrationen zu vermeiden. Mappings gelten global (kettenweite Kürzel sind in jeder
/// Filiale gleich), Preise werden weiterhin pro Store gelernt.
final class ReceiptAliasService {
    static let shared = ReceiptAliasService()
    private let storageKey = "smartcart.receiptNameAliases"
    // App-Group-Suite statt .standard: die Share Extension (eigener Prozess, eigener
    // .standard-Container) muss dieselben gelernten Kürzel sehen wie die Haupt-App, sonst würde
    // Stufe 1 der Namensauflösung (siehe ReceiptResolutionService.resolve) beim Scannen eines
    // geteilten Bon-Bilds immer leer laufen.
    private static let suite = UserDefaults(suiteName: SharedModelContainer.appGroupID) ?? .standard
    private var aliases: [String: String] = [:]

    private init() { load() }

    /// Gelernten Artikelnamen für einen rohen Bon-Text nachschlagen (normalisiert, exakt).
    func resolve(_ receiptText: String) -> String? {
        aliases[normalize(receiptText)]
    }

    /// Mapping Bon-Kürzel → Artikelname lernen. Benennt der User zurück auf den rohen
    /// Bon-Text, wird das Mapping gelöscht, damit keine veraltete Zuordnung hängen bleibt.
    func learn(receiptText: String, itemName: String) {
        let key = normalize(receiptText)
        let name = itemName.trimmingCharacters(in: .whitespaces)
        guard key.count >= 3, !name.isEmpty else { return }
        if normalize(name) == key {
            if aliases.removeValue(forKey: key) != nil { persist() }
            return
        }
        guard aliases[key] != name else { return }
        aliases[key] = name
        persist()
    }

    private func normalize(_ s: String) -> String {
        // Satzzeichen durch Leerzeichen ERSETZEN (nicht löschen) — sonst würde "Shak.moutarde"
        // zu "shakmoutarde" (zusammengeklebt) statt zu "shak moutarde", und würde damit weiterhin
        // NICHT mit "Shak moutarde" (schon mit Leerzeichen) übereinstimmen.
        s.lowercased()
            .replacingOccurrences(of: #"[.,;:!*]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    private func load() {
        // Einmalige, selbstheilende Migration: bestehende Installationen haben ihre gelernten
        // Kürzel noch in .standard (wo dieser Service vor der Share Extension lebte). Ohne das
        // wären sie für Bestandsnutzer nach diesem Wechsel plötzlich unsichtbar, bis sie zufällig
        // erneut gelernt werden. Greift nur, solange die Suite noch nichts hat — danach ein No-op.
        if let legacyData = UserDefaults.standard.data(forKey: storageKey),
           Self.suite.data(forKey: storageKey) == nil {
            Self.suite.set(legacyData, forKey: storageKey)
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
        guard let data = Self.suite.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        aliases = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(aliases) else { return }
        Self.suite.set(data, forKey: storageKey)
    }
}
