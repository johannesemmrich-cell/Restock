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
        s.lowercased()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        aliases = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(aliases) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
