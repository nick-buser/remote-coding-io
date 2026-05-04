---
prefix: service
title: Build You tab — profile card and Workspace / Appearance / Agent settings
status: todo
branch:
---

## Description

Replace the placeholder You tab with the dense settings layout: profile card at the top, then three grouped sections (Workspace, Appearance, Agent). Folds in the existing `APIConfiguration` editor under Workspace ▸ tmux server.

Depends on `service-tab-shell.md`, `infra-component-kit.md`. See `docs/feature_plans/30-screens.md` (section 11).

## Acceptance criteria

- [ ] `Features/You/YouView.swift` mounts inside the You tab.
- [ ] Profile card at top:
  - 64pt accent-tinted circle with the user's initial (read from `UserPreferences.displayName`, default "N").
  - 22pt display `displayName`.
  - 12pt mono `<projects> projects · <liveSessions> sessions live` (sourced from the workspace summary).
- [ ] **Workspace** section (`SettingRow`s):
  - `Default project` → detail: project name (or `None`); tap opens a project picker. Persists `workspace.defaultProjectID`.
  - `Notifications` → detail: `Reviews & questions` (placeholder; no actual notification work in v2).
  - `tmux server` → detail: connection state from `/healthz` (`Connected` / `Unreachable`); tap pushes the existing API config form (renamed from `SettingsView`).
- [ ] **Appearance** section:
  - `Accent color` row: `AccentSwatchPicker` with all 5 accents. Selection persists to `appearance.accent` and updates the `@Environment(\.accent)` immediately.
  - `Text size` → segmented control (`Small / Default / Large`). Persists to `appearance.textSize`. Apply by setting `dynamicTypeSize` on the root.
  - `Appearance` → segmented control (`Light / Dark / System`). Persists to `appearance.colorScheme`. Apply by setting `preferredColorScheme` on the root.
- [ ] **Agent** section (placeholders — surfaces to be wired when contract supports them):
  - `Default model` → detail: `Claude Sonnet`. Tap shows "Coming soon" sheet.
  - `Pane budget` → detail: `6 per window`. Tap shows "Coming soon".
  - `Context bundle` → detail: `PRD + Decisions`. Tap shows "Coming soon".
- [ ] `Core/Persistence/UserPreferences.swift` is the central `@Observable` store backing all settings (uses `UserDefaults` underneath).
- [ ] Trailing dots menu in the You header has `Sign out` (clears stored credentials when those exist; for now, a no-op with a Toast).
- [ ] Tests: accent picker updates the environment value; appearance toggle changes preferredColorScheme; default project pick persists across launches.
- [ ] `#Preview` renders You in light + dark.

## Notes

- The existing `Features/Settings/SettingsView.swift` housing the API base URL form is renamed to `Features/You/TmuxServerSettingsView.swift` and pushed from the tmux server row. The form itself doesn't change shape.
- The `/healthz` connection state is a one-shot fetch on appear plus a refresh on pull-to-refresh. Don't poll continuously — once the user moves on, it doesn't matter.
- `AccentSwatchPicker` was built in `infra-component-kit.md` — reuse it.
- Defer notification settings to a future ticket. The current row is informational.
