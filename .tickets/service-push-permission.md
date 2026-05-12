---
prefix: service
title: APNs permission + device token registration
status: todo
branch:
---

## Description

Request push permission at the right moment, register the device token with
the backend, and handle token rotation.

Depends on `infra-push-openapi-regen.md`. See `docs/feature_plans/60-push-notifications.md`.

## Acceptance criteria

- [ ] `UNUserNotificationCenter.requestAuthorization(options:)` is called the first time the user taps "Open pane" on an Inbox question row or navigates to the Sessions tab — never on cold launch.
- [ ] On grant, `UIApplication.shared.registerForRemoteNotifications()` is called.
- [ ] `AppDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` encodes the token as a lowercase hex string and calls `repository.registerDevice(...)` with environment set to `sandbox` for debug builds and `production` for release.
- [ ] Re-registration on every launch is idempotent (server returns 200, no error surfaced).
- [ ] If registration fails, the error is logged but not shown to the user (push is best-effort).
- [ ] The current token is stored in `AppSettings` so the settings screen can read it without a round-trip.
- [ ] `AppDelegate.application(_:didFailToRegisterForRemoteNotificationsWithError:)` logs but does not crash.

## Notes

- Environment detection: `#if DEBUG` → `.sandbox`, otherwise `.production`.
- No UI in this ticket. Push settings toggle (`service-push-settings`) reads
  `AppSettings.pushToken` and calls `deregisterDevice` when turning off.
