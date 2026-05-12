# service-0038: APNs permission + device token registration

Ticket: `.tickets/done/service-push-permission.md`

## Summary

Implements the iOS side of push notifications: a `PushRegistrationService`
that owns the permission lifecycle, an `AppDelegate` bridging UIKit's APNs
callbacks into Swift, and trigger points on the Sessions tab and Inbox
question rows. Push state (token, mute list, quiet hours) lives in
`UserPreferences`.

## Changes

- **Modified** `Core/Persistence/UserPreferences.swift`:
  - New stored properties `pushToken`, `mutedProjectIDs`, `quietHoursStart`,
    `quietHoursEnd`. All persisted via UserDefaults under namespaced keys.
- **Added** `Core/Services/PushSystem.swift`:
  - `PushSystem` protocol abstracting `UNUserNotificationCenter` +
    `UIApplication` registration calls.
  - `PushAuthorizationStatus` enum mirroring `UNAuthorizationStatus` without
    importing `UserNotifications` into the protocol.
  - `LivePushSystem` real implementation.
- **Added** `Core/Services/MockPushSystem.swift` (DEBUG-only): records
  `requestAuthorization` / `registerForRemoteNotifications` calls. Used by
  previews and tests.
- **Added** `Core/Services/PushRegistrationService.swift`:
  - `requestPermissionIfNeeded()` — short-circuits on `.denied`, prompts on
    `.notDetermined`, re-registers when already authorized.
  - `applyDeviceToken(_ data: Data)` — hex-encodes the raw token, POSTs to
    `registerDevice`, persists in `UserPreferences`.
  - `handleRegistrationFailure(_:)` — logs only (best-effort push).
  - `deregister()` — clears token + DELETEs server-side.
  - `reregister()` — re-POSTs with current mute list / quiet hours
    (used by settings in the next slice).
- **Added** `App/AppDelegate.swift`: `UIApplicationDelegate` exposing two
  closure hooks (`onDeviceTokenReceived`, `onDeviceRegistrationFailed`).
- **Modified** `remote_codingApp.swift`:
  - Adopts `AppDelegate` via `@UIApplicationDelegateAdaptor`.
  - Constructs `PushRegistrationService` eagerly in `init` so it can be
    injected as a non-optional environment value.
  - `.task` wires the AppDelegate hooks to forward into the service.
- **Modified** `Features/Sessions/SessionsListView.swift`: calls
  `pushService.requestPermissionIfNeeded()` from `.task`.
- **Modified** `Features/Inbox/InboxView.swift`: calls
  `pushService.requestPermissionIfNeeded()` when the user taps the
  secondary action on a `question` row. Adds `registerDevice` /
  `deregisterDevice` / `getAgentSession` (the last filling a pre-existing
  conformance gap) to the preview-only `EmptyInboxRepository`.
- **Modified** `ContentView.swift`: preview injects `pushService`.
- **Modified** `Features/Inbox/InboxView.swift` + `SessionsListView.swift`
  previews: inject a `MockPushSystem(initialStatus: .denied)` so the preview
  never prompts.
- **Added** `remote-codingTests/PushRegistrationServiceTests.swift`:
  10 tests covering all permission branches, hex encoding, repository
  call shape, preference pass-through, deregister, re-register, and
  failure logging.
- **Modified** `remote-codingTests/UserPreferencesTests.swift`: extends
  the defaults assertion and adds two persistence tests for the new
  push fields.

## Decisions

- **`UserPreferences` over a new `AppSettings`.** The plan doc referenced
  `AppSettings.pushToken`; in practice the existing `UserPreferences` is
  the right home — same lifetime, same UserDefaults backing, same
  injection surface. Fewer files, no migration.
- **`registerForRemoteNotifications` on every applicable call to
  `requestPermissionIfNeeded`**. Calling it when already authorized is
  idempotent — iOS re-issues the token, which is exactly what we want
  for token rotation across launches. The server endpoint is idempotent.
- **`PushSystem` protocol as a thin seam.** A protocol with a Live + Mock
  implementation keeps `PushRegistrationService` testable without the
  system frameworks. The mirror enum `PushAuthorizationStatus` avoids
  pulling `UserNotifications` into test targets.
- **AppDelegate closure hooks rather than a singleton bridge.** The App
  struct holds the only references to both AppDelegate and the service;
  it can wire them together at `.task` time. No global state.
- **Filled the `getAgentSession` conformance gap in `EmptyInboxRepository`
  while editing nearby.** The class was already declared as conforming
  but missing this method; preview compilation has been silently broken
  since the terminal v2 ticket landed.

## Notes

- PR #__, stacked on `phase6/02-push-openapi-regen`.
- No xcodebuild on this host — CI will validate the full build.
