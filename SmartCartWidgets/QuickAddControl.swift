import WidgetKit
import AppIntents
import SwiftUI

// MARK: - Control Widget

@available(iOS 18.0, *)
struct QuickAddControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.smartcart.quickadd-control") {
            ControlWidgetButton(action: QuickAddControlIntent()) {
                Label("Hinzufügen", systemImage: "cart.badge.plus")
            }
            .tint(.blue)
        }
        .displayName("Artikel hinzufügen")
        .description("Öffnet SmartCart direkt zur schnellen Artikeleingabe.")
    }
}
