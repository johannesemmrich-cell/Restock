import UIKit
import CloudKit

extension Notification.Name {
    static let quickAddRequested = Notification.Name("com.smartcart.quickAddRequested")
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Silent push only (content-available) — no user-facing permission prompt needed,
        // used exclusively to know when a shared list changed on another member's device.
        application.registerForRemoteNotifications()

        if let item = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem,
           item.type == "com.smartcart.quickadd" {
            QuickActionState.shared.triggerQuickAdd = true
            // Return false to prevent performActionFor from being called again
            return false
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) as? CKQueryNotification,
              let recordID = notification.recordID else {
            completionHandler(.noData)
            return
        }
        Task {
            await SyncCoordinator.shared.pullStore(shareID: recordID.recordName)
            completionHandler(.newData)
        }
    }

    // Fallback for older iOS / non-scene paths
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

    // iOS 13+ scene lifecycle: route shortcut items to SceneDelegate
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // Handle shortcut items that trigger a new scene connection
        if let item = options.shortcutItem, item.type == "com.smartcart.quickadd" {
            QuickActionState.shared.triggerQuickAdd = true
        }
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

// Handles warm-launch shortcut items in the iOS 13+ scene-based lifecycle.
// UIApplicationDelegate.performActionFor is not reliably called in SwiftUI lifecycle apps;
// the scene delegate method is the authoritative path for foreground/background app state.
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        if shortcutItem.type == "com.smartcart.quickadd" {
            NotificationCenter.default.post(name: .quickAddRequested, object: nil)
        }
        completionHandler(true)
    }
}
