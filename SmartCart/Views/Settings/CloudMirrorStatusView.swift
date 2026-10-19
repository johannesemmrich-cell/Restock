import SwiftUI

/// Developer Mode: Zustand des privaten iCloud-Abgleichs (Issue #156, Teil A). Zeigt die letzte
/// Einrichtung (Issue #166), den letzten Export und Import samt Ursache eines Fehlers. Behauptet nie „alles in Ordnung“: `quotaExceeded`
/// erreicht die Ereignisse nicht zuverlässig (FB13773922).
/// Spec: `docs/specs/services/icloud-abgleich-sichtbar.md`.
struct CloudMirrorStatusView: View {
    var body: some View {
        let store = CloudMirrorStatusStore()
        let export = store.lastRun(.export)
        let setup = store.lastRun(.setup)

        List {
            // Issue #166: Einrichtung der Spiegelung, läuft bei jedem App-Start.
            Section(String(localized: "Einrichtung (beim App-Start)")) { runRows(setup) }
            if let setup, !setup.succeeded, let summary = setup.summary {
                causeSection(summary, plainText: CloudMirrorMonitor.setupCauseText(for: summary))
            }
            Section(String(localized: "Letzter Export (hochladen)")) { runRows(export) }
            if let export, !export.succeeded, let summary = export.summary {
                causeSection(summary)
            }
            Section(String(localized: "Letzter Import (herunterladen)")) { runRows(store.lastRun(.import)) }
            Section(String(localized: "Seit Installation")) {
                LabeledContent(String(localized: "Exporte ok / fehlgeschlagen"),
                               value: "\(store.exportSuccessCount) / \(store.exportFailureCount)")
            }
        }
        .navigationTitle(String(localized: "iCloud-Abgleich"))
        .devFeedback(context: "iCloud-Abgleich")
    }

    @ViewBuilder
    private func runRows(_ run: CloudMirrorRun?) -> some View {
        if let run {
            LabeledContent(String(localized: "Zustand")) {
                Text(run.succeeded ? String(localized: "erfolgreich") : String(localized: "fehlgeschlagen"))
                    .foregroundStyle(run.succeeded ? Color.textSecondary : Color.destructive)
            }
            LabeledContent(String(localized: "Zeit"),
                           value: run.date.formatted(date: .numeric, time: .shortened))
            if let summary = run.summary {
                LabeledContent(String(localized: "Fehler"), value: "\(summary.domain) \(summary.code)")
            }
        } else {
            Text(String(localized: "noch kein Lauf"))
                .foregroundStyle(Color.textSecondary)
        }
    }

    /// `plainText`: Klartext der Ursache für die Überschrift („Ursache: kein iCloud-Konto“, Issue #166).
    private func causeSection(_ summary: CloudMirrorSummary, plainText: String? = nil) -> some View {
        Section {
            Text(summary.detail)
                .font(.footnote.monospaced())
                .foregroundStyle(Color.ink)
                .textSelection(.enabled)
        } header: {
            if let plainText {
                Text(String(localized: "Ursache: \(plainText)"))
            } else if let count = summary.itemCountText {
                Text(String(localized: "Ursache (\(count) Einträgen)"))
            } else {
                Text(String(localized: "Ursache"))
            }
        } footer: {
            if summary.totalItemCount > summary.failedItemCount, summary.failedItemCount > 0 {
                Text(String(localized: "Die übrigen Einträge scheiterten nur mit, weil CloudKit den ganzen Stapel ablehnt."))
            }
        }
    }
}
