import SwiftUI
import SwiftData

/// Developer Mode: Messwerte zur Nachkauf-Vorhersage (Issue #30, D1). Zeigt, wie Vorschläge im
/// Banner angenommen werden, wie genau die Vorhersage rückwirkend über die Kaufhistorie lag, und
/// für jeden Artikel, wie gerechnet wird und warum er (nicht) vorgeschlagen wird. Grundlage, um
/// Schwellenwerte wie Mindestkäufe, Streuung und Fenster mit Daten einzustellen.
struct ReplenishmentStatsView: View {
    @Query private var allRecords: [PurchaseRecord]
    @State private var showResetConfirmation = false
    /// Zähler liegen in UserDefaults, nicht in SwiftData — nach dem Zurücksetzen neu zeichnen.
    @State private var metricsVersion = 0

    var body: some View {
        let metrics = ReplenishmentMetrics()
        let backtest = HabitService.backtest(allRecords: allRecords)
        let now = Date()
        let snoozes = ReplenishmentSnoozes().entries()
        let blocked = ReplenishmentBlocklist().keys
        let patterns = HabitService.patterns(allRecords: allRecords)
            .map { pattern in snoozes[pattern.itemKey].map { pattern.applying($0) } ?? pattern }
            .sorted { $0.itemName.localizedCaseInsensitiveCompare($1.itemName) == .orderedAscending }
        let shown = metrics.count(.shown)

        List {
            Section {
                statRow("Gezeigt", "\(shown)")
                statRow("Übernommen", "\(metrics.count(.accepted))", detail: percent(metrics.count(.accepted), of: shown))
                statRow("Hab noch", "\(metrics.count(.snoozed))", detail: percent(metrics.count(.snoozed), of: shown))
                statRow("Nicht mehr vorschlagen", "\(metrics.count(.blocked))", detail: percent(metrics.count(.blocked), of: shown))
                statRow("Übernommen, dann ohne Kauf gelöscht", "\(metrics.count(.removedAfterAccept))")
            } header: {
                Text("Reaktionen im Banner")
            } footer: {
                Text("Jeder Vorschlag (Artikel + letzter Kauf) zählt einmal als gezeigt. Gezählt wird ab dieser Version.")
            }

            Section {
                statRow("Bewertete Käufe", "\(backtest.evaluated)")
                statRow("Davon vorschlagbar", "\(backtest.covered)", detail: percent(backtest.covered, of: backtest.evaluated))
                statRow("Davon im Fenster gekauft", "\(backtest.withinWindow)", detail: percent(backtest.withinWindow, of: backtest.covered))
                statRow(
                    "Mittlere Abweichung",
                    backtest.meanAbsoluteErrorDays.map { String(format: "%.1f Tage", $0) } ?? "–"
                )
            } header: {
                Text("Rückblick über die Kaufhistorie")
            } footer: {
                Text("Für jeden Kauf mit mindestens \(HabitService.minimumPurchases) früheren Kauftagen wird aus den früheren Käufen der Termin errechnet und mit dem tatsächlichen Kauf verglichen.")
            }

            Section {
                if patterns.isEmpty {
                    Text("Noch kein Artikel mit mindestens 2 Kauftagen")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(patterns, id: \.itemName) { pattern in
                        patternRow(pattern, now: now, isBlocked: blocked.contains(pattern.itemKey))
                    }
                }
            } header: {
                Text("Artikel (\(patterns.count))")
            }
        }
        .id(metricsVersion)
        .navigationTitle("Nachkauf-Statistik")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Zurücksetzen") { showResetConfirmation = true }
            }
        }
        .confirmationDialog("Banner-Zähler zurücksetzen?", isPresented: $showResetConfirmation, titleVisibility: .visible) {
            Button("Zurücksetzen", role: .destructive) {
                ReplenishmentMetrics().reset()
                metricsVersion += 1
            }
        } message: {
            Text("Der Rückblick über die Kaufhistorie bleibt unverändert.")
        }
    }

    private func statRow(_ title: String, _ value: String, detail: String? = nil) -> some View {
        HStack {
            Text(title)
            Spacer()
            if let detail {
                Text(detail)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .monospacedDigit()
        }
    }

    private func patternRow(_ pattern: ConsumptionPattern, now: Date, isBlocked: Bool) -> some View {
        let state: (label: String, color: Color) = isBlocked
            ? (label: "ausgeblendet", color: .secondary)
            : status(of: pattern, now: now)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(pattern.itemName)
                    .font(.headline)
                Spacer()
                Text(state.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(state.color)
            }
            Text("\(pattern.reasonText) · \(pattern.purchaseCount) Kauftage · Streuung \(String(format: "%.2f", pattern.intervalVariation))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Termin \(pattern.estimatedNextPurchaseDate.formatted(date: .abbreviated, time: .omitted)) · Fenster \(pattern.dueWindowDays) T. · Menge \(String(format: "%g", pattern.typicalQuantity)) \(pattern.unit)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func status(of pattern: ConsumptionPattern, now: Date) -> (label: String, color: Color) {
        switch HabitService.ineligibility(of: pattern, at: now) {
        case .tooFewPurchases: return ("zu wenige Käufe", .secondary)
        case .irregular: return ("unregelmäßig", .secondary)
        case .habitEnded: return ("Gewohnheit beendet", .secondary)
        case nil:
            if pattern.isSnoozed && !pattern.isDueSoon(at: now) && !pattern.isOverdue(at: now) {
                return ("hab noch", .secondary)
            }
            if pattern.isOverdue(at: now) { return ("überfällig", .danger) }
            if pattern.isDueSoon(at: now) { return ("fällig", .amber) }
            return ("aktiv", .accent)
        }
    }

    private func percent(_ part: Int, of total: Int) -> String? {
        guard total > 0 else { return nil }
        return "\(Int((Double(part) / Double(total) * 100).rounded())) %"
    }
}
