import SwiftUI
import SwiftData

/// Developer Mode: doppelte Läden (Issue #156, Teil B1). Nur Anzeige: „bliebe“ markiert den Laden
/// mit der kleinsten Kennung, der bei einem späteren Zusammenführen bliebe. Hier wird nichts
/// entfernt und nichts zusammengeführt.
/// Spec: `docs/specs/services/icloud-abgleich-sichtbar.md`.
struct StoreDuplicatesView: View {
    @Query private var stores: [Store]

    var body: some View {
        let snapshots = stores.map { StoreSnapshot($0) }
        let groups = StoreDuplicateFinder.groups(snapshots)

        List {
            Section {
                countRow(String(localized: "Läden gesamt"), snapshots.count, id: "storeDuplicates.storeCount")
                countRow(String(localized: "davon aktiv"), snapshots.filter(\.isActive).count,
                         id: "storeDuplicates.activeCount")
                countRow(String(localized: "Doppelgruppen"), groups.count, id: "storeDuplicates.groupCount")
            } footer: {
                Text(String(localized: "Nur Anzeige. „bliebe“ markiert den Laden mit der kleinsten Kennung, der bei einem späteren Zusammenführen bliebe. Gleiche Namen in verschiedenen Ländern zählen nicht als Doppel."))
            }
            ForEach(groups) { group in
                Section {
                    ForEach(group.stores) { store in
                        storeRow(store, isWinner: store.id == group.winner?.id)
                    }
                } header: {
                    Text(title(of: group))
                }
            }
        }
        .navigationTitle(String(localized: "Doppelte Läden"))
        .devFeedback(context: "Doppelte Läden")
    }

    private func countRow(_ title: String, _ value: Int, id: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Color.ink)
            Spacer()
            Text("\(value)")
                .monospacedDigit()
                .foregroundStyle(Color.textSecondary)
                .accessibilityIdentifier(id)
        }
    }

    private func storeRow(_ store: StoreSnapshot, isWinner: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.name)
                    .foregroundStyle(Color.ink)
                Text(details(of: store))
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
            if isWinner {
                Text(String(localized: "bliebe"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accent)
            }
        }
    }

    private func details(of store: StoreSnapshot) -> String {
        let state = store.isActive ? String(localized: "aktiv") : String(localized: "inaktiv")
        let shortID = String(store.id.uuidString.prefix(4)) + "…"
        return String(localized: "\(state) · \(store.itemCount) Artikel · \(shortID)")
    }

    private func title(of group: StoreDuplicateGroup) -> String {
        let name = group.stores.first?.name ?? ""
        switch group.kind {
        case .sameShareID:
            return String(localized: "\(name) · geteilt · \(group.key)")
        case .samePreset:
            let country = group.stores.first?.countryCode ?? ""
            return String(localized: "\(name) · \(country) · Standardladen")
        case .sameCustomName:
            return String(localized: "\(name) · eigener Laden · nur melden")
        }
    }
}
