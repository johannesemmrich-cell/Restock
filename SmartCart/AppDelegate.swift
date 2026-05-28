import UIKit

extension Notification.Name {
    static let quickAddRequested = Notification.Name("com.smartcart.quickAddRequested")
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        if let item = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem,
           item.type == "com.smartcart.quickadd" {
            QuickActionState.shared.triggerQuickAdd = true
            return false
        }
        return true
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        if shortcutItem.type == "com.smartcart.quickadd" {
            NotificationCenter.default.post(name: .quickAddRequested, object: nil)
        }
        completionHandler(true)
    }
}
