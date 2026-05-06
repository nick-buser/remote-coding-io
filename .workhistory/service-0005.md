# service-0005: Replace 3-tab shell with v2 5-tab bottom navigation

Ticket: `.tickets/done/service-tab-shell.md`

## Summary

Swapped the prototype `Projects / Terminal / Settings` `TabView` for the
v2 shell `Inbox / Projects / Roadmap / Sessions / You`. This is the
structural inflection point that unblocks every Phase 3 screen ticket:
each tab is reachable, each tab body is an `EmptyState` placeholder
parameterised with the ticket that will replace it, and the terminal is
no longer a top-level destination — `service-app-route-coordinator` (the
next branch) pushes it as a full-screen drill-down via the
`agentSession` route. The branch is intentionally narrow: no routing,
no real screens, no styling beyond the active-accent tint and the
material tab background.

## Changes

- `AppTab` rewritten as `inbox / projects / roadmap / sessions / you`,
  promoted to `String, Codable, CaseIterable` so the upcoming
  coordinator can persist it.
- `AppModel.terminalContext` + `AppModel.openTerminal(...)` removed.
  `TerminalContext` is preserved verbatim — the route coordinator
  reuses it as the `agentSession` route payload.
- `AppModel.needsYou: Bool` added, defaulting to `true` until
  `service-repo-activity` wires it to real data.
- `ContentView` rewritten around the new `Tab(value:)` syntax with five
  placeholders. Tab tint pulls from `\.accent`; the bar uses
  `Theme.Surface.tabBg` with `.toolbarBackground(.visible, for: .tabBar)`.
- The Inbox dot uses `.badge(Text("●"))` — it reads as a single
  accent-coloured dot but it's the system badge surface, not the
  pixel-exact 7pt dot from the design.
- `TerminalView` accepts a `TerminalContext?` via init instead of
  reading from `AppModel`; previous `appModel.openTerminal(...)` call
  sites in `ProjectDetailView` and `FeatureDetailView` became
  `service-app-route-coordinator` TODOs that render the row but no-op
  on tap. Visual behaviour at those rows is unchanged.
- `SettingsView` was preserved behind a `NavigationLink` in the You
  placeholder so the API base URL form remains reachable until
  `service-you-screen` folds it into Workspace ▸ tmux server.

## Decisions

- **`.badge(Text("●"))` over a custom `UITabBarAppearance` overlay.**
  The design calls for a 7pt accent dot above the icon. The system
  badge is close enough for the placeholder phase and avoids carrying
  appearance state through `UITabBarAppearance` swizzles. If product
  review rejects the look, the follow-up is local to `ContentView`.
- **`AppTab` defaulted to `.inbox` with no UserDefaults migration
  story.** The v1 default was `.projects`; the v1→v2 case set is
  disjoint anyway, so a saved `"projects"` from a previous build will
  decode to `.projects` correctly. There's nothing else to migrate.
- **`TerminalContext` left in `App/AppModel.swift`.** It will move to
  `Core/Domain/` when the route coordinator wraps it in the
  `agentSession` route — no value in shuffling it now.
- **Previous `openTerminal` call sites became inline no-ops, not
  removed.** Removing the rows would have changed visual behaviour —
  the row stays, the action is parked behind a route-coordinator TODO.
  Keeps the diff tight and the failure mode obvious to the next
  ticket.

## Notes

- The placeholder `TabPlaceholder` and `YouTabPlaceholder` private
  views in `ContentView.swift` get deleted as Phase 3 screens land.
  Each is keyed off the ticket name in its `message:` so it's easy to
  grep when wiring a real screen.
- `service-app-route-coordinator` will replace each tab body's
  `NavigationStack` with one bound to a coordinator path, and replace
  the `TabPlaceholder` `NavigationStack` wrapping with the coordinator
  variant. Plan accordingly when reading this code in the next branch.
- The `TerminalView` `context: TerminalContext?` parameter is
  `Optional` only so the preview / empty state stays representable.
  Production callers will always pass a concrete context once the
  route is wired.
