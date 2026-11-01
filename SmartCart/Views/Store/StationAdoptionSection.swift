import SwiftUI

// Issue #234, Durchgang 2b-2 (`docs/specs/views/station-picker-adoption.md`): Abschnitt „Eigene
// Kategorien von früher“ in „Kategorien einrichten“. Welche Kategorien erscheinen, entscheidet
// `Store.adoptableCategories` (Regel R3); Übernehmen läuft über `Store.adoptCategory`/`adoptAllCategories`.

/// Nur sichtbar, wenn es Kategorien „von früher“ gibt.
struct StationAdoptionSection: View {
    let store: Store
    let onChange: () -> Void

    var body: some View {
        let names = store.adoptableCategories
        if !names.isEmpty {
            Section {
                ForEach(names, id: \.self) { name in
                    row(name)
                }
            } header: {
                HStack {
                    Text(String(format: String(localized: "station.adopt.section"), names.count))
                        .accessibilityIdentifier("stationSetup.adopt.section")
                    Spacer()
                    Button(String(localized: "station.adopt.all")) { adoptAll() }
                        .textCase(nil)
                        .accessibilityIdentifier("stationSetup.adopt.all")
                }
            } footer: {
                Text(String(localized: "station.adopt.footer"))
            }
            .listRowBackground(Color.surface)
        }
    }

    private func row(_ name: String) -> some View {
        HStack(spacing: 10) {
            Text(store.categoryEmoji(name))
            Text(name).foregroundStyle(Color.ink)
            Spacer()
            Button(String(localized: "station.adopt.take")) { adopt(name) }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("stationSetup.adopt.take.\(name)")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("stationSetup.adopt.row.\(name)")
    }

    private func adopt(_ name: String) {
        let adopted = withAnimation(.smooth) { store.adoptCategory(name) }
        guard adopted != nil else { return }
        Haptics.impact(.light)
        onChange()
    }

    private func adoptAll() {
        let adopted = withAnimation(.smooth) { store.adoptAllCategories() }
        guard !adopted.isEmpty else { return }
        Haptics.impact(.medium)
        onChange()
    }
}
