import Foundation
#if canImport(UIKit)
import UIKit
import UserNotifications
#endif

/// Bridges UIKit application lifecycle callbacks into the SwiftUI app.
///
/// Currently used only for APNs registration callbacks; deep-link routing
/// (`willPresent` / `didReceive`) lands in `service-push-deep-link`.
///
/// The owning `App` adopts this via `@UIApplicationDelegateAdaptor` and
/// assigns the two closure hooks once the `PushRegistrationService` exists.
#if canImport(UIKit)
final class AppDelegate: NSObject, UIApplicationDelegate {
    var onDeviceTokenReceived: ((Data) -> Void)?
    var onDeviceRegistrationFailed: ((Error) -> Void)?

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
