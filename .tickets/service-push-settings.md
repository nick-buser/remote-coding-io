---
prefix: service
title: Push notification settings in You screen
status: todo
branch:
---

## Description

Add a Notifications group to the You screen with a master toggle, per-project
mute list, and quiet-hours pickers.

Depends on `service-push-permission.md`. See `docs/feature_plans/60-push-notifications.md`.

## Acceptance criteria

- [ ] "Notifications" group appears in `YouView` between Workspace and Agent settings, only when `AppSettings.pushToken != nil`.
- [ ] Master toggle: off calls `deregisterDevice(token:)` and clears `AppSettings.pushToken`; on calls `registerForRemoteNotifications()` (which re-triggers `service-push-permission` flow).
- [ ] If system permission is `.denied`, the toggle is disabled and a "Enable in Settings →" row opens `UIApplication.openSettingsURLString`.
- [ ] Muted projects: multi-select list of all projects. Selection is persisted in `AppSettings.mutedProjectIDs` and included in the next device re-registration call (`PUT /api/v1/devices/{token}` or re-POST the same token with updated fields).
- [ ] Quiet hours: start + end time pickers (hour granularity, 12h/24h respects locale). Stored in `AppSettings` and included in re-registration.
- [ ] Settings changes re-register the device token with updated `muted_project_ids` / `quiet_hours_*` fields.
- [ ] Tests: toggling master off calls `deregisterDevice`; changing muted projects triggers re-registration.

## Notes

- `AppSettings` is the local source of truth. If the server rejects the
  re-registration (e.g. token expired) the UI rolls back and shows an error.
- Quiet hours display uses the user's local timezone for the picker but stores
  as UTC integers in the request body.
