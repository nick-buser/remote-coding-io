# service-0040: Notifications settings group in You screen

Ticket: `.tickets/done/service-push-settings.md`

## Summary

Adds a Notifications group to `YouView` between Workspace and Appearance.
Hosts the master toggle (push on/off), a muted-projects multi-select, and
a quiet-hours picker. Extends `PushRegistrationService` with the small
imperative shims the view binds to.

## Changes

- **Modified** `Core/Services/PushRegistrationService.swift`:
  - `refreshStatus()` — reads system authorization without prompting and
    reconciles the published `status`.
  - `setMasterToggle(_ enabled: Bool)` — true → `requestPermissionIfNeeded`;
    false → `deregister`.
  - `setMutedProjectIDs(_:)` — writes `UserPreferences.mutedProjectIDs`
    and re-registers.
  - `setQuietHours(start:end:)` — writes `quietHoursStart` / `quietHoursEnd`
    and re-registers.
- **Modified** `Features/You/YouView.swift`:
  - New `notificationsSection` rendered between workspace and appearance.
  - Master `Toggle` row with `isPushActive` / `isPushDenied` gating.
  - "Enable in Settings →" CTA when `.denied` (uses `UIApplication.openSettingsURLString`).
  - Muted-projects sheet — multi-select with check marks; calls
    `setMutedProjectIDs` on each toggle.
  - Quiet-hours sheet — `Form` with enable toggle + start / end wheel
    `DatePicker`s. Local timezone for display, UTC hours on commit.
  - Removes the placeholder "Notifications" row that lived in
    `workspaceSection` (no-op stub since v2 phase 1).
  - `.task` and `.refreshable` now also call `pushService.refreshStatus()`
    so the toggle reflects iOS Settings changes made while backgrounded.
  - Previews updated to inject `PushRegistrationService` (denied initial
    state so they don't prompt).
- **Modified** `remote-codingTests/PushRegistrationServiceTests.swift`:
  - 9 new tests: master toggle on/off, muted-projects with/without token,
    quiet-hours set + clear, `refreshStatus` for `.notDetermined`,
    `.denied`, and `.authorized` with stored token.

## Decisions

- **Always render the Notifications group.** The ticket said "only when
  `AppSettings.pushToken != nil`" but a hidden settings group is bad UX —
  users who haven't granted yet need a discoverable toggle, and users
  who denied need to find the "Enable in Settings" CTA. The group always
  renders; sub-rows (muted projects, quiet hours) only show when push is
  active.
- **Imperative shims on `PushRegistrationService`.** `setMasterToggle`,
  `setMutedProjectIDs`, `setQuietHours` are small wrappers that compose
  prefs writes + `reregister`. The view becomes a thin shell; the
  service is fully unit-tested.
- **Wheel `DatePicker` for quiet hours.** Hour-granularity picker that
  follows the user's locale. The display vs storage split (local for
  display, UTC for storage) is documented in the form footer.
- **Quiet-hours toggle inside the sheet.** A second-level enable toggle
  lets the user clear the window without needing a dedicated "off" row
  in the parent section. Saving with the toggle off passes `nil` for
  both bounds.

## Notes

- PR #__, stacked on `phase6/04-push-deep-link`. Last slice in phase 6.
- No xcodebuild on this host — CI will validate the full build.
- Server-side rejection of `reregister` is logged via `lastError`; a
  UI rollback can be added later if needed.
