import Foundation
#if canImport(UserNotifications)
import UserNotifications

/// `UNUserNotificationCenterDelegate` adapter. Receives foreground +
/// tap callbacks from `UNUserNotificationCenter`, runs the payload
/// through `PushRouter`, and forwards both the destination and the
/// foreground-arrival signal to closures supplied at construction.
///
/// Kept separate from `AppDelegate` so the actual delegate methods can
/// be reasoned about (and tested via integration tests) without the
/// rest of the app lifecycle.
@MainActor
final class PushDelegateBridge: NSObject, UNUserNotificationCenterDelegate {
    private let router: PushRouter
    private let onNavigate: @MainActor (PushDestination) -> Void
    private let onForegroundArrival: @MainActor () -> Void

    init(
        router: PushRouter = PushRouter(),
        onNavigate: @escaping @MainActor (PushDestination) -> Void,
        onForegroundArrival: @escaping @MainActor () -> Void
    ) {
        self.router = router
        self.onNavigate = onNavigate
        self.onForegroundArrival = onForegroundArrival
        super.init()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // The user is in the app — show the banner anyway so they see the
        // alert in-app, and refresh the unread state immediately so the
        // Inbox dot doesn't wait for the next 5s polling tick.
        onForegroundArrival()
        return [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let destination = router.destination(for: response.notification.request.content.userInfo)
        onNavigate(destination)
    }
}
#endif
