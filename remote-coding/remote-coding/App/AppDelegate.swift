import Foundation
#if canImport(UIKit)
import UIKit
import UserNotifications
#endif

/// Bridges UIKit application lifecycle callbacks into the SwiftUI app.
///
/// - APNs registration callbacks fan out to `PushRegistrationService` via
///   `onDeviceTokenReceived` / `onDeviceRegistrationFailed`.
/// - The cold-launch notification payload (if any) is stashed in
///   `pendingLaunchPayload` for `RootCoordinator` to consume once the
///   view hierarchy is ready.
/// - `notificationDelegate` retains the `UNUserNotificationCenterDelegate`
///   instance assigned to `UNUserNotificationCenter.current()` — owning the
///   reference here keeps it alive for the app's lifetime.
#if canImport(UIKit)
final class AppDelegate: NSObject, UIApplicationDelegate {
    var onDeviceTokenReceived: ((Data) -> Void)?
    var onDeviceRegistrationFailed: ((Error) -> Void)?

    /// One-shot stash. Set during `didFinishLaunchingWithOptions` when iOS
    /// brings the app up via a notification tap. Consume via
    /// `consumePendingLaunchPayload()` after the view hierarchy is ready.
    private var pendingLaunchPayload: [AnyHashable: Any]?

    /// Strong reference so the delegate isn't deallocated immediately
    /// after assignment to `UNUserNotificationCenter.current().delegate`.
    var notificationDelegate: UNUserNotificationCenterDelegate?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if let payload = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            pendingLaunchPayload = payload
        }
        return true
    }

    /// Returns the stashed payload (if any) and clears it. Subsequent
    /// calls return `nil`. Safe to call multiple times.
    func consumePendingLaunchPayload() -> [AnyHashable: Any]? {
        let payload = pendingLaunchPayload
        pendingLaunchPayload = nil
        return payload
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        onDeviceTokenReceived?(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        onDeviceRegistrationFailed?(error)
    }
}
#endif
