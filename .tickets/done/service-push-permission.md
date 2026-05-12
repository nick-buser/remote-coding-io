---
prefix: service
title: APNs permission + device token registration
status: done
branch: phase6/03-push-permission
---

## Description

Request push permission at the right moment, register the device token with
the backend, and handle token rotation.

Depends on `infra-push-openapi-regen.md`. See `docs/feature_plans/60-push-notifications.md`.

## Acceptance criteria

- [x] `UNUserNotificationCenter.requestAuthorization(options:)` is called the first time the user taps "Open pane" on an Inbox question row or navigates to the Sessions tab — never on cold launch.
- [x] On grant, `UIApplication.shared.registerForRemoteNotifications()` is called.
- [x] `AppDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` encodes the token as a lowercase hex string and calls `repository.registerDevice(...)` with environment set to `sandbox` for debug builds and `production` for release.
- [x] Re-registration on every launch is idempotent (server returns 200, no error surfaced).
- [x] If registration fails, the error is logged but not shown to the user (push is best-effort).
- [x] The current token is stored in `UserPreferences` (in place of the planned `AppSettings`) so the settings screen can read it without a round-trip.
- [x] `AppDelegate.application(_:didFailToRegisterForRemoteNotificationsWithError:)` logs but does not crash.

## Notes

- Environment detection: `#if DEBUG` → `.sandbox`, otherwise `.production`.
- Push state lives in `UserPreferences` rather than a new `AppSettings`
  container — fewer moving parts and matches the existing pattern.
- No UI in this ticket. Push settings toggle (`service-push-settings`) reads
  `UserPreferences.pushToken` and calls `deregisterDevice` when turning off.
