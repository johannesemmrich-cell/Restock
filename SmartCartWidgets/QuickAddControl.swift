import WidgetKit
import AppIntents
import SwiftUI

// MARK: - Intent

private let appGroupID = "group.com.johannesemmrich.SmartCart"
private let pendingQuickAddKey = "pendingQuickAdd"

struct QuickAddControlIntent: AppIntent {
    static var title: LocalizedStringResource = "Schnell hinzufügen"
    static var description = IntentDescription("Öffnet SmartCart direkt zur schnellen Artikeleingabe.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: appGroupID)?.set(true, forKey: pendingQuickAddKey)
        return .result()
    }
}

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
