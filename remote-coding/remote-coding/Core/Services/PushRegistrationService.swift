import Foundation
import Observation
import os.log

/// Owns the APNs permission + token-registration lifecycle.
///
/// Trigger surfaces (Sessions tab navigation, Inbox "Open pane" tap on a
/// question) call `requestPermissionIfNeeded`. The system either ignores
/// the call (already determined) or prompts the user. On grant the
/// service calls `registerForRemoteNotifications`; the AppDelegate then
/// forwards the device token back via `applyDeviceToken`.
///
/// Token rotation is handled implicitly — iOS calls
/// `didRegisterForRemoteNotificationsWithDeviceToken` on every launch
/// when push is active, and `registerDevice` on the server is idempotent.
@MainActor
@Observable
final class PushRegistrationService {
    enum Status: Equatable {
        case unknown
        case notDetermined
        case denied
        case registered(token: String)
    }

    private(set) var status: Status = .unknown
    private(set) var lastError: Error?

    private let repositoryProvider: @MainActor () -> TmuxAgentRepository
    private let preferences: UserPreferences
    private let pushSystem: any PushSystem
    private let environment: Components.Schemas.DeviceEnvironment
    private let logger: Logger

    init(
        repositoryProvider: @escaping @MainActor () -> TmuxAgentRepository,
        preferences: UserPreferences,
        pushSystem: any PushSystem,
        environment: Components.Schemas.DeviceEnvironment = .currentBuildEnvironment,
        logger: Logger = Logger(subsystem: "io.remote-coding.push", category: "registration")
    ) {
        self.repositoryProvider = repositoryProvider
        self.preferences = preferences
        self.pushSystem = pushSystem
        self.environment = environment
        self.logger = logger
        if let token = preferences.pushToken {
            self.status = .registered(token: token)
        }
    }

    /// Idempotent. Called from view surfaces where the user has just shown
    /// intent to engage with agent activity. Safe to call repeatedly:
    /// - `.notDetermined`: prompts the user, then registers on grant.
    /// - `.authorized` / `.provisional` / `.ephemeral`: re-registers the
    ///    device with APNs so iOS re-issues the token (idempotent server-side).
    /// - `.denied`: no-op.
    func requestPermissionIfNeeded() async {
        let current = await pushSystem.authorizationStatus()
        switch current {
        case .notDetermined:
            status = .notDetermined
            do {
                let granted = try await pushSystem.requestAuthorization()
                if granted {
                    pushSystem.registerForRemoteNotifications()
                } else {
                    status = .denied
                }
            } catch {
                logger.error("requestAuthorization failed: \(error.localizedDescription, privacy: .public)")
                lastError = error
            }
        case .denied:
            status = .denied
        case .authorized, .provisional, .ephemeral:
            pushSystem.registerForRemoteNotifications()
        }
    }

    /// Reads the current system authorization status without prompting and
    /// reconciles `status`. Used by the You screen on appear so the toggle
    /// reflects reality (the user may have flipped permission in iOS
    /// Settings while the app was backgrounded).
    func refreshStatus() async {
        let current = await pushSystem.authorizationStatus()
        switch current {
        case .denied:
            status = .denied
        case .notDetermined:
            // Preserve `.registered` if we already have a token (rare, but the
            // system can briefly report `.notDetermined` while permissions are
            // being reset). Otherwise fall back.
            if case .registered = status { return }
            status = .notDetermined
        case .authorized, .provisional, .ephemeral:
            if let token = preferences.pushToken {
                status = .registered(token: token)
            } else {
                status = .unknown
            }
        }
    }

    /// Called by `AppDelegate.didRegisterForRemoteNotificationsWithDeviceToken`.
    /// Hex-encodes the raw token, persists it, and POSTs the registration
    /// body (with current mute list + quiet hours) to the backend.
    func applyDeviceToken(_ data: Data) async {
        let token = data.map { String(format: "%02x", $0) }.joined()
        let body = makeRegistrationRequest(token: token)
        do {
            _ = try await repositoryProvider().registerDevice(body)
            preferences.pushToken = token
            status = .registered(token: token)
        } catch {
            logger.error("registerDevice failed: \(error.localizedDescription, privacy: .public)")
            lastError = error
        }
    }

    /// Called by `AppDelegate.didFailToRegisterForRemoteNotificationsWithError`.
    /// Push is best-effort; we log and continue. The user-visible toggle in
    /// the You screen reflects the failure by staying in `.notDetermined`.
    func handleRegistrationFailure(_ error: Error) {
        logger.error("APNs registration failed: \(error.localizedDescription, privacy: .public)")
        lastError = error
    }

    /// Clears the stored token + asks the backend to forget it. Used by
    /// the settings master toggle (off).
    func deregister() async {
        let token = preferences.pushToken
        preferences.pushToken = nil
        status = .unknown
        guard let token else { return }
        do {
            try await repositoryProvider().deregisterDevice(token: token)
        } catch {
            logger.error("deregisterDevice failed: \(error.localizedDescription, privacy: .public)")
            lastError = error
        }
    }

    /// Re-POSTs the current token alongside the latest mute list / quiet
    /// hours. Called from the settings screen after the user changes those
    /// preferences. No-op if there's no token.
    func reregister() async {
        guard let token = preferences.pushToken else { return }
        let body = makeRegistrationRequest(token: token)
        do {
            _ = try await repositoryProvider().registerDevice(body)
        } catch {
            logger.error("re-registerDevice failed: \(error.localizedDescription, privacy: .public)")
            lastError = error
        }
    }

    /// Mutates the mute list and re-registers in one call. Used by the
    /// settings sheet so the server immediately sees the new filter.
    func setMutedProjectIDs(_ ids: [Int64]) async {
        preferences.mutedProjectIDs = ids
        await reregister()
    }

    /// Mutates quiet hours and re-registers. Both `start` and `end` must be
    /// provided to enable the window; passing `nil` for either clears the
    /// window entirely.
    func setQuietHours(start: Int?, end: Int?) async {
        preferences.quietHoursStart = start
        preferences.quietHoursEnd = end
        await reregister()
    }

    /// Drives the master toggle on the settings screen. Setting `true`
    /// triggers the permission flow (no-op if already granted); setting
    /// `false` deregisters.
    func setMasterToggle(_ enabled: Bool) async {
        if enabled {
            await requestPermissionIfNeeded()
        } else {
            await deregister()
        }
    }

    private func makeRegistrationRequest(token: String) -> Components.Schemas.DeviceRegistrationRequest {
        Components.Schemas.DeviceRegistrationRequest(
            deviceToken: token,
            environment: environment,
            mutedProjectIds: preferences.mutedProjectIDs.isEmpty ? nil : preferences.mutedProjectIDs,
            quietHoursStart: preferences.quietHoursStart,
            quietHoursEnd: preferences.quietHoursEnd
        )
    }
}

extension Components.Schemas.DeviceEnvironment {
    /// `.sandbox` for debug builds, `.production` otherwise.
    static var currentBuildEnvironment: Self {
        #if DEBUG
        return .sandbox
        #else
        return .production
        #endif
    }
}
