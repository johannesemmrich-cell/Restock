import SwiftUI

/// Einmaliger Hinweis vor dem ersten Preisbeitrag (Issue #186, Entwurf A): ein Systemhinweis mit
/// „Weiter teilen“ und „Nicht teilen“. Gemeinsam für Bon-Prüf-Screen und „Preis eintragen“.
///
/// Solange `pending` gesetzt ist, steht der Hinweis; die gesammelten Beiträge bleiben bis zur
/// Entscheidung auf dem Gerät. Nur die zwei Knöpfe entscheiden: Ein Ausblenden ohne Knopf setzt
/// weder Merker noch Schalter und sendet nichts.
private struct CommunityShareNoticeModifier: ViewModifier {
    @Binding var pending: [CommunityPriceService.Contribution]?
    let onFinished: () -> Void

    private var isPresented: Binding<Bool> {
        // Der Setter ist bewusst leer: Nur die Knopf-Aktionen räumen `pending` ab.
        Binding(get: { pending != nil }, set: { _ in })
    }

    func body(content: Content) -> some View {
        content.alert(
            Text(String(localized: "settings.community.notice.title")),
            isPresented: isPresented,
            presenting: pending
        ) { list in
            Button(String(localized: "settings.community.notice.share")) {
                CommunityPriceService.recordNoticeDecision(share: true, in: .standard)
                CommunityPriceService.shared.contributeInBackground(list)
                finish()
            }
            .keyboardShortcut(.defaultAction)
            Button(String(localized: "settings.community.notice.decline")) {
                CommunityPriceService.recordNoticeDecision(share: false, in: .standard)
                finish()
            }
        } message: { _ in
            Text(String(localized: "settings.community.notice.message"))
        }
    }

    private func finish() {
        pending = nil
        onFinished()
    }
}

extension View {
    /// Zeigt den Erst-Hinweis, solange `pending` Beiträge hält (Issue #186).
    func communityShareNotice(pending: Binding<[CommunityPriceService.Contribution]?>,
                              onFinished: @escaping () -> Void) -> some View {
        modifier(CommunityShareNoticeModifier(pending: pending, onFinished: onFinished))
    }
}

extension CommunityPriceService {
    /// Ende von `save()` in beiden Eingängen: Ist der Hinweis fällig, Beiträge zurückhalten und
    /// `true` liefern (der Screen bleibt offen); sonst wie bisher senden und `false` liefern.
    @MainActor
    static func holdForNoticeOrSend(_ contributions: [Contribution],
                                    into pending: inout [Contribution]?) -> Bool {
        if noticeDue(contributions, in: .standard) {
            pending = contributions
            return true
        }
        shared.contributeInBackground(contributions)
        return false
    }
}
