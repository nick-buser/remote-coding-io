---
prefix: service
title: Push notification settings in You screen
status: done
branch: phase6/05-push-settings
---

## Description

Add a Notifications group to the You screen with a master toggle, per-project
mute list, and quiet-hours pickers.

Depends on `service-push-permission.md`. See `docs/feature_plans/60-push-notifications.md`.

## Acceptance criteria

- [x] "Notifications" group appears in `YouView` between Workspace and Appearance — always rendered so the user sees the toggle even before granting permission. Sub-rows are conditional on push being active.
- [x] Master toggle: off calls `pushService.setMasterToggle(false)` → `deregisterDevice(token:)` + clears `pushToken`; on calls `pushService.setMasterToggle(true)` → permission flow.
- [x] If system permission is `.denied`, the toggle is disabled and a "Enable in Settings →" row opens `UIApplication.openSettingsURLString`.
- [x] Muted projects: multi-select sheet listing all projects. Selection persisted in `UserPreferences.mutedProjectIDs` and re-registered via `setMutedProjectIDs(_:)`.
- [x] Quiet hours: start + end pickers (hour granularity, wheel `DatePicker`). UTC-stored, local-displayed; re-registered via `setQuietHours(start:end:)`.
- [x] Settings changes re-register the device token with updated `muted_project_ids` / `quiet_hours_*` fields.
- [x] Tests: master toggle off calls deregister; setting muted projects with an active token re-registers with the new list; quiet-hours pickers wire through to the body.

## Notes

- `UserPreferences` is the local source of truth (the original plan referenced
  `AppSettings`; this lives in `UserPreferences` per the implementation
  decision in `service-push-permission`).
- Server rejection on re-registration is logged but not surfaced — the
  existing `lastError` field on the service captures it; a UI rollback
  pattern can be added if the case proves common.
- Quiet hours wheel picker uses the user's local timezone for display and
  converts to UTC hours on commit.
- The group always renders (vs the original "only when pushToken != nil")
  so denied users can see the "Enable in Settings →" CTA.
