import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        if shortcutItem.type == "com.smartcart.quickadd" {
            QuickActionState.shared.triggerQuickAdd = true
        }
        completionHandler(true)
    }
}
