import Foundation
#if canImport(UIKit)
import UIKit
import UserNotifications
#endif

/// Thin seam over `UNUserNotificationCenter` + `UIApplication` so the
/// push registration service can be exercised in unit tests without
/// touching the system frameworks.
@MainActor
protocol PushSystem {
    func authorizationStatus() async -> PushAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func registerForRemoteNotifications()
}

/// Mirror of `UNAuthorizationStatus` that doesn't import UserNotifications
/// at the protocol level. Keeps mocks free of UIKit.
enum PushAuthorizationStatus: Equatable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
}

#if canImport(UIKit)
extension UNAuthorizationStatus {
    var pushAuthorizationStatus: PushAuthorizationStatus {
        switch self {
        case .notDetermined: return .notDetermined
        case .denied:        return .denied
        case .authorized:    return .authorized
        case .provisional:   return .provisional
        case .ephemeral:     return .ephemeral
        @unknown default:    return .notDetermined
        }
    }
}

@MainActor
struct LivePushSystem: PushSystem {
    func authorizationStatus() async -> PushAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus.pushAuthorizationStatus
    }

    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }
}
#endif
