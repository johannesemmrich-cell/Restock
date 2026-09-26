import SwiftUI

/// Developer Mode: Vorschläge, die im Banner „Zeit zum Nachkaufen“ per „Nicht mehr vorschlagen“
/// ausgeblendet oder per „Hab noch“ verschoben wurden (Issue #30, C1). Eigenes Untermenü, damit
/// die Einstellungen nicht überladen werden; beides lässt sich hier rückgängig machen.
struct HiddenReplenishmentsView: View {
    // Die Listen liegen in UserDefaults (ReplenishmentBlocklist/ReplenishmentSnoozes) — über
    // @AppStorage beobachtet, damit die Ansicht nach jeder Änderung neu zeichnet.
    @AppStorage(ReplenishmentBlocklist.defaultsKey) private var blockedData = Data()
    @AppStorage(ReplenishmentSnoozes.defaultsKey) private var snoozedData = Data()

    var body: some View {
        let blocked = ReplenishmentBlocklist().names()
        // Abgelaufene Verschiebungen (Artikel steht wieder im Banner) nicht mehr anzeigen; der
        // Eintrag selbst wird erst beim nächsten Kauf aufgeräumt (`ReplenishmentSnoozes.prune`).
        let now = Date().timeIntervalSince1970
        let snoozes = ReplenishmentSnoozes().entries().values
            .filter { $0.snoozedUntil >= now }
            .sorted { $0.snoozedUntil < $1.snoozedUntil }

        List {
            Section {
                if blocked.isEmpty {
                    Text("Keine ausgeblendeten Artikel")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(blocked, id: \.self) { name in
                        HStack {
                            Text(name)
                            Spacer()
                            Button("Wieder vorschlagen") {
                                ReplenishmentBlocklist().unblock(name)
                                Haptics.impact(.light)
                            }
                            .font(.subheadline)
                            .buttonStyle(.borderless)
                        }
                    }
                }
            } header: {
                Text("Nicht mehr vorschlagen")
            } footer: {
                Text("Diese Artikel erscheinen nicht mehr im Banner „Zeit zum Nachkaufen“, bis du sie hier wieder freigibst.")
            }

            Section {
                if snoozes.isEmpty {
                    Text("Keine verschobenen Artikel")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(snoozes, id: \.itemName) { snooze in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(snooze.itemName)
                                Text("bis \(Date(timeIntervalSince1970: snooze.snoozedUntil).formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Zurücksetzen") {
                                ReplenishmentSnoozes().remove(snooze.itemName)
                                Haptics.impact(.light)
                            }
                            .font(.subheadline)
                            .buttonStyle(.borderless)
                        }
                    }
                }
            } header: {
                Text("Hab noch")
            } footer: {
                Text("„Hab noch“ verschiebt den Termin um die Hälfte des üblichen Abstands (1–14 Tage) und gilt bis zum nächsten Kauf.")
            }
        }
        .navigationTitle("Ausgeblendete Vorschläge")
        .devFeedback(context: "Ausgeblendete Vorschläge")
    }
}
