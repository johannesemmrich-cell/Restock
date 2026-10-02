import SwiftUI

/// Developer Mode: Messung der Bon-Namensauflösung je Stufe (Issue #14). Zeigt, wie viele
/// gespeicherte Bon-Zeilen jede Stufe aufgelöst hat und wie oft der Nutzer das Ergebnis im Review
/// umbenannt oder abgewählt hat — die Nulllinie, um Regel-Hebel und KI-Stufe mit Daten zu bewerten.
/// Spec: `docs/specs/services/receipt-resolution-stats.md`.
struct ReceiptResolutionStatsView: View {
    @State private var showResetConfirmation = false
    /// Zähler liegen in UserDefaults, nicht in SwiftData — nach dem Zurücksetzen neu zeichnen.
    @State private var statsVersion = 0

    var body: some View {
        let stats = ReceiptResolutionStats()
        let all = ReceiptResolutionStage.allCases.map { stats.counts(for: $0) }
        let sum = ReceiptResolutionStats.Counts(
            total: all.map(\.total).reduce(0, +),
            changed: all.map(\.changed).reduce(0, +),
            deselected: all.map(\.deselected).reduce(0, +))

        List {
            Section {
                ForEach(ReceiptResolutionStage.allCases, id: \.self) { stage in
                    stageRow(title(of: stage), key: stage.rawValue, counts: stats.counts(for: stage))
                }
                stageRow(String(localized: "Alle Stufen"), key: "all", counts: sum)
            } header: {
                columns(String(localized: "Stufe"), String(localized: "Gesamt"),
                        String(localized: "Geändert"), String(localized: "Abgewählt"))
            } footer: {
                Text("Gezählt beim Speichern eines Bons, nur Zahlen. Stufe KI läuft nur auf Geräten mit Apple Intelligence. Nicht-Produkt wird noch nicht unterschieden (siehe #90).")
            }

            Section {
                // Eigenes Bedienhilfe-Label: sonst tragen dieser Knopf und der Bestätigungsknopf im
                // Dialog dasselbe Label und sind für VoiceOver/UI-Tests nicht unterscheidbar.
                Button("Zurücksetzen", role: .destructive) { showResetConfirmation = true }
                    .accessibilityLabel("Zähler zurücksetzen")
                    .accessibilityIdentifier("resolutionStatsResetButton")
            }
        }
        .id(statsVersion)
        .navigationTitle("Bon-Auflösung")
        // `.alert` statt `confirmationDialog`: unter iOS 26 erscheint der Dialog als verankertes
        // Popover ohne „Abbrechen“-Knopf (nur Tippen daneben) — die Bestätigung soll beide
        // Antworten sichtbar anbieten.
        .alert("Bon-Auflösung zurücksetzen?", isPresented: $showResetConfirmation) {
            Button("Abbrechen", role: .cancel) {}
            Button("Zurücksetzen", role: .destructive) {
                ReceiptResolutionStats().reset()
                statsVersion += 1
            }
        } message: {
            Text("Alle Zähler werden auf 0 gesetzt.")
        }
        .devFeedback(context: "Bon-Auflösung")
    }

    /// Einzeilig, damit alle sieben Stufen und die Summenzeile ohne Scrollen sichtbar sind.
    private func stageRow(_ title: String, key: String, counts: ReceiptResolutionStats.Counts) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .foregroundStyle(Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            value("\(counts.total)", width: Self.totalWidth, id: "resolutionStage.\(key).total")
            value(withPercent(counts.changed, of: counts.total), width: Self.percentWidth, id: "resolutionStage.\(key).changed")
            value(withPercent(counts.deselected, of: counts.total), width: Self.percentWidth, id: "resolutionStage.\(key).deselected")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("resolutionStage.\(key)")
    }

    private static let totalWidth: CGFloat = 44
    private static let percentWidth: CGFloat = 76

    private func columns(_ stage: String, _ total: String, _ changed: String, _ deselected: String) -> some View {
        HStack(spacing: 8) {
            Text(stage)
            Spacer(minLength: 4)
            Text(total).frame(width: Self.totalWidth, alignment: .trailing)
            Text(changed).frame(width: Self.percentWidth, alignment: .trailing)
            Text(deselected).frame(width: Self.percentWidth, alignment: .trailing)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private func value(_ text: String, width: CGFloat, id: String) -> some View {
        Text(text)
            .font(.subheadline)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: width, alignment: .trailing)
            .accessibilityIdentifier(id)
    }

    private func withPercent(_ part: Int, of total: Int) -> String {
        guard total > 0 else { return "\(part) (–)" }
        return "\(part) (\(Int((Double(part) / Double(total) * 100).rounded())) %)"
    }

    private func title(of stage: ReceiptResolutionStage) -> String {
        switch stage {
        case .alias: return String(localized: "Alias")
        case .dictionary: return String(localized: "Wörterbuch")
        case .completed: return String(localized: "Abgehakt")
        case .history: return String(localized: "Historie")
        case .ai: return String(localized: "KI")
        case .rawText: return String(localized: "Rohtext")
        case .nonProduct: return String(localized: "Nicht-Produkt")
        }
    }
}
