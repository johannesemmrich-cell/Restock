import Foundation
import SwiftData

/// Issue #156, Teil B1/B2: Doppel-Läden erkennen (nur anzeigen) und an ihren Quellen verhindern.
/// Hier wird nichts entfernt, umgehängt oder zusammengeführt; die Gewinnerregel (kleinste UUID)
/// ist nur Information für eine spätere, eigene Entscheidung.
/// Spec: `docs/specs/services/icloud-abgleich-sichtbar.md`.

/// Unveränderliche Sicht auf einen Laden, damit die Erkennung rein und testbar bleibt.
struct StoreSnapshot: Identifiable, Equatable {
    let id: UUID
    let name: String
    let countryCode: String
    let isCustom: Bool
    let shareID: String?
    let isActive: Bool
    let itemCount: Int

    init(id: UUID, name: String, countryCode: String, isCustom: Bool,
         shareID: String?, isActive: Bool, itemCount: Int) {
        self.id = id
        self.name = name
        self.countryCode = countryCode
        self.isCustom = isCustom
        self.shareID = shareID
        self.isActive = isActive
        self.itemCount = itemCount
    }

    init(_ store: Store) {
        self.init(id: store.id, name: store.name, countryCode: store.countryCode, isCustom: store.isCustom,
                  shareID: store.shareID, isActive: store.isActive, itemCount: store.items?.count ?? 0)
    }

    var isShared: Bool { !(shareID ?? "").isEmpty }
}

/// Eine Gruppe von Läden, die als Doppel gelten.
struct StoreDuplicateGroup: Identifiable, Equatable {
    enum Kind: Equatable {
        /// Klasse 1: gleiche, nicht leere `shareID`.
        case sameShareID
        /// Klasse 2: Standardladen, gleiches Land, gleicher normalisierter Name.
        case samePreset
        /// Klasse 3: eigener Laden, gleicher normalisierter Name; nur melden.
        case sameCustomName
    }

    let kind: Kind
    let key: String
    let stores: [StoreSnapshot]

    var id: String { "\(kind)|\(key)" }
    var reportOnly: Bool { kind == .sameCustomName }
    var winner: StoreSnapshot? { StoreDuplicateFinder.winner(of: stores) }
}

enum StoreDuplicateFinder {
    /// Trim, Groß/Klein und Diakritika werden ignoriert („Bäckerei“ = „backerei “).
    static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .lowercased()
    }

    /// Schlüssel der Klasse 2; nil für eigene oder geteilte Läden.
    private static func presetKey(_ store: StoreSnapshot) -> String? {
        guard !store.isCustom, !store.isShared else { return nil }
        return "\(store.countryCode)|\(normalizedName(store.name))"
    }

    static func groups(_ stores: [StoreSnapshot]) -> [StoreDuplicateGroup] {
        let shared = Dictionary(grouping: stores.filter(\.isShared)) { $0.shareID ?? "" }
        let presets = Dictionary(grouping: stores.filter { presetKey($0) != nil }) { presetKey($0) ?? "" }
        let custom = Dictionary(grouping: stores.filter { $0.isCustom && !$0.isShared }) { normalizedName($0.name) }
        return makeGroups(.sameShareID, shared) + makeGroups(.samePreset, presets)
            + makeGroups(.sameCustomName, custom)
    }

    private static func makeGroups(_ kind: StoreDuplicateGroup.Kind,
                                   _ byKey: [String: [StoreSnapshot]]) -> [StoreDuplicateGroup] {
        byKey.filter { $0.value.count > 1 }
            .sorted { $0.key < $1.key }
            .map { StoreDuplicateGroup(kind: kind, key: $0.key,
                                       stores: $0.value.sorted { $0.id.uuidString < $1.id.uuidString }) }
    }

    /// Kleinste UUID (Empfehlung Apple DTS), unabhängig von der Reihenfolge.
    static func winner(of stores: [StoreSnapshot]) -> StoreSnapshot? {
        stores.min { $0.id.uuidString < $1.id.uuidString }
    }

    /// Presets, für die noch kein Standardladen gleichen Landes und normalisierten Namens existiert.
    static func missingPresets(_ presets: [StoreSnapshot], existing: [StoreSnapshot]) -> [StoreSnapshot] {
        let present = Set(existing.compactMap(presetKey))
        return presets.filter { preset in
            guard let key = presetKey(preset) else { return true }
            return !present.contains(key)
        }
    }
}

/// Einfügen von Presets ohne neue Doppel (Onboarding, Länderwechsel).
enum StoreSeeding {
    /// Fügt nur fehlende Presets ein; vorhandene Läden bleiben unverändert. Liefert die Anzahl.
    @MainActor @discardableResult
    static func insertMissingPresets(_ presets: [Store], into context: ModelContext) throws -> Int {
        let existing = try context.fetch(FetchDescriptor<Store>()).map { StoreSnapshot($0) }
        let missing = Set(StoreDuplicateFinder.missingPresets(presets.map { StoreSnapshot($0) },
                                                              existing: existing).map(\.id))
        let toInsert = presets.filter { missing.contains($0.id) }
        toInsert.forEach { context.insert($0) }
        try context.save()
        return toInsert.count
    }
}

/// Beitritt zu einem geteilten Laden ohne zweiten lokalen Laden derselben `shareID`.
enum StoreShareJoin {
    @MainActor
    static func existingStore(shareID: String, in context: ModelContext) -> Store? {
        let stores = (try? context.fetch(FetchDescriptor<Store>())) ?? []
        return stores.first { $0.shareID == shareID }
    }
}
