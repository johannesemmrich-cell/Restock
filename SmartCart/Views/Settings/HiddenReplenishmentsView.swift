import SwiftUI

/// Vorschläge, die im Banner „Zeit zum Nachkaufen“ per „Nicht mehr vorschlagen“
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
                    Text(String(localized: "replenish.hidden.blocked.empty"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(blocked, id: \.self) { name in
                        HStack {
                            Text(name)
                            Spacer()
                            Button(String(localized: "replenish.hidden.unblock")) {
                                ReplenishmentBlocklist().unblock(name)
                                Haptics.impact(.light)
                            }
                            .font(.subheadline)
                            .buttonStyle(.borderless)
                        }
                    }
                }
            } header: {
                Text(String(localized: "replenish.block"))
            } footer: {
                Text(String(localized: "replenish.hidden.blocked.footer"))
            }

            Section {
                if snoozes.isEmpty {
                    Text(String(localized: "replenish.hidden.snoozed.empty"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(snoozes, id: \.itemName) { snooze in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(snooze.itemName)
                                Text(String(format: String(localized: "replenish.hidden.until"), Date(timeIntervalSince1970: snooze.snoozedUntil).formatted(date: .abbreviated, time: .omitted)))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(String(localized: "replenish.hidden.reset")) {
                                ReplenishmentSnoozes().remove(snooze.itemName)
                                Haptics.impact(.light)
                            }
                            .font(.subheadline)
                            .buttonStyle(.borderless)
                        }
                    }
                }
            } header: {
                Text(String(localized: "replenish.snooze"))
            } footer: {
                Text(String(localized: "replenish.hidden.snoozed.footer"))
            }
        }
        .navigationTitle(String(localized: "settings.replenish.hidden"))
        .devFeedback(context: "Ausgeblendete Vorschläge")
    }
}
