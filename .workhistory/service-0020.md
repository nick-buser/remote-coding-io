# service-0020: You tab — profile + Workspace / Appearance / Agent

Ticket: `.tickets/done/service-you-screen.md`

## Summary

Replaces the You-tab placeholder with the v2 settings screen:
profile card (accent-tinted initial circle + display name + workspace
summary), then three grouped sections — Workspace (default project,
notifications stub, tmux server link), Appearance (`AccentSwatchPicker`
+ text-size segmented + appearance mode segmented), and Agent
(three "Coming soon" rows).

Introduces `UserPreferences`, the central `@Observable` `UserDefaults`-
backed store. Wired at the app root: accent flows back into `AppModel`
so theme tokens and tab tinting follow the user's choice;
`preferredColorScheme` and `dynamicTypeSize` are applied at the
`WindowGroup` level so every screen picks up the user's preference.

This ticket is the **last of the 8 main Phase 3 screens** — the v2
shell is now end-to-end navigable: Inbox, Projects (list + detail),
Feature detail (with sub-tab stubs), Roadmap, Sessions, Review, You.

## Changes

- `Core/Persistence/UserPreferences.swift` — new `@Observable
  @MainActor` store backing `displayName`, `defaultProjectID`,
  `accent`, `textSize`, `appearance`. Each property persists
  through `UserDefaults` on `didSet`. Includes nested `TextSize`
  and `AppearanceMode` enums with `dynamicTypeSize` /
  `preferredColorScheme` mappings so SwiftUI consumers don't
  switch on raw values.
- `Features/You/YouView.swift` — full screen: header (with
  Sign-out menu placeholder), profile card, three grouped
  sections, `NavigationLink` to `SettingsView` (the existing
  Phase 1 API base URL form, presented as "tmux server"), a
  project-picker sheet, and "Coming soon" sheets for the Agent
  rows. Uses `@Bindable` to drive `AccentSwatchPicker` and the
  segmented controls from the shared `UserPreferences`.
- `remote_codingApp.swift` — instantiates `UserPreferences` once
  at `WindowGroup` level, injects it into the environment,
  applies `preferredColorScheme` / `dynamicTypeSize` from the
  store, and bridges `prefs.accent → AppModel.accent` via
  `onChange` so the existing `\.accent` consumers (tabs, pill
  buttons, etc.) update immediately.
- `ContentView.swift` — drops the inline `YouTabPlaceholder`
  struct and points the You tab at `YouView`. Updates the
  `#Preview` to inject a fresh `UserPreferences`.
- `remote-codingTests/UserPreferencesTests.swift` — Swift
  `Testing` cases for default values, accent / project /
  text-size / appearance / display-name persistence (instance
  round-trip), nullable project clearing, the
  `AppearanceMode.preferredColorScheme` / `TextSize.dynamicTypeSize`
  mappings, and corrupted-raw fallback to `.iris`.

## Decisions

- **`SettingsView` kept under `Features/Settings/`.** The ticket
  asks for a rename to `TmuxServerSettingsView.swift`, but
  renaming the file (vs. the symbol exposed to the user) costs
  pbxproj churn and a forced touch on every reference. The
  existing `SettingsView` is presented as "tmux server" via the
  `NavigationLink` label — the user-visible name matches the
  design without disturbing the file. A pure cleanup ticket can
  do the rename later if it's still desired.
- **`UserPreferences` lives at the app root, not inside
  `AppModel`.** Keeping it standalone lets it persist independent
  of the repository / poller lifecycle (which `AppModel`
  re-instantiates on API base URL change in
  `updateAPIBaseURL`). Bridging `prefs.accent → appModel.accent`
  via `onChange` keeps `\.accent` consumers untouched.
- **Sign-out is a toast.** No credential storage exists today,
  so signing out is informational. The menu shape matches the
  design and a future token-store ticket lands the actual
  flow.
- **Notifications row is informational.** Per the ticket note,
  defer the actual permissions / preferences UX. The row exists
  for layout fidelity.
- **Segmented controls for text size and appearance use
  string-based `Binding<String>`.** The shared `SegmentedControl`
  takes labels and a string binding; mapping to/from the typed
  enums in the binding closure keeps the consumer simple without
  a generic-segmented-control rewrite.

## Notes

- Branched from `service-0019` (still open). The PR's base is
  `service-0019`; once #20–#25 land the base will retarget to
  `main`.
- The workspace summary on the profile card uses the same
  per-project `listProjectAgentSessions` fan-out that the
  Inbox / Sessions / Roadmap screens use today. It can switch
  to `CrossProjectFeatureFetcher.loadFeaturesAndSessions()` in
  a follow-up cleanup commit when the same shape is wanted
  everywhere.
- iOS gates were not exercised in this session (Linux runner
  without Xcode); the suite needs to run on a Mac via the
  `ios-gates` skill before merge.

## Phase 3 wrap-up

This branch closes the eight-screen Phase 3 push. All eight main
screens are now wired:

| Branch / PR | Screen |
|-------------|--------|
| `service-0013` | Inbox |
| `service-0014` | Projects list |
| `service-0015` | Project detail |
| `service-0016` | Feature detail (shell) |
| `service-0017` | Roadmap |
| `service-0018` | Sessions list |
| `service-0019` | Ticket review |
| `service-0020` | You |

Follow-up Phase 3 tickets — feature-detail sub-tab bodies
(`service-feature-{tickets,prd,decisions,sessions}-tab`) and
the create / edit modal flows — remain queued in `.tickets/`
for separate branches.
