import Foundation

#if DEBUG
/// In-memory `PushSystem` used by SwiftUI previews and unit tests. The
/// real `UNUserNotificationCenter` / `UIApplication` calls are recorded
/// rather than invoked, so consumers can assert behaviour without
/// touching system frameworks.
@MainActor
final class MockPushSystem: PushSystem {
    var initialStatus: PushAuthorizationStatus
    var grantsAuthorization: Bool
    var authorizationError: Error?

    private(set) var requestedAuthorization: Bool = false
    private(set) var registerForRemoteCallCount: Int = 0

    init(
        initialStatus: PushAuthorizationStatus = .notDetermined,
        grantsAuthorization: Bool = true,
        authorizationError: Error? = nil
    ) {
        self.initialStatus = initialStatus
        self.grantsAuthorization = grantsAuthorization
        self.authorizationError = authorizationError
    }

    func authorizationStatus() async -> PushAuthorizationStatus {
        initialStatus
    }

    func requestAuthorization() async throws -> Bool {
        requestedAuthorization = true
        if let authorizationError {
            throw authorizationError
        }
        if grantsAuthorization {
            initialStatus = .authorized
        } else {
            initialStatus = .denied
        }
        return grantsAuthorization
    }

    func registerForRemoteNotifications() {
        registerForRemoteCallCount += 1
    }
}
#endif
