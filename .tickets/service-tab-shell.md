---
prefix: service
title: Replace 3-tab shell with v2 5-tab bottom navigation
status: todo
branch:
---

## Description

Replace the existing `Projects / Terminal / Settings` `TabView` in `ContentView.swift` with the v2 5-tab shell: `Inbox / Projects / Roadmap / Sessions / You`. The terminal is no longer a top-level tab — it becomes a full-screen drill-down reached from Sessions and Inbox actions in later tickets.

This ticket is the structural change only. Each tab's body is a placeholder `EmptyState` until the Phase 3 screen tickets land. The goal is to leave the app in a state where every tab is reachable, the active accent is wired through, and the `needsYou` indicator on the Inbox tab can be driven by mock data.

Depends on `infra-design-tokens.md` and `infra-component-kit.md`. See `docs/feature_plans/20-navigation-and-data.md`.

## Acceptance criteria

- [ ] `App/AppTab.swift` defines `enum AppTab { case inbox, projects, roadmap, sessions, you }` (replacing the existing 3-case enum).
- [ ] `ContentView.swift` mounts a `TabView` with five tabs in the order Inbox, Projects, Roadmap, Sessions, You.
- [ ] Each tab uses the design's tab icon (custom `Image` from SwiftUI shapes / `SVG`-equivalent, matching the SVG paths in `TabIcons2` from `ios-screens-zen.jsx`).
- [ ] Active tab tint is the user's accent (read from `@Environment(\.accent)` after the wiring in `infra-design-tokens.md`).
- [ ] The Inbox tab supports a single accent-colored 7pt dot above its icon when `AppModel.needsYou == true`. No badge counts in v2.
- [ ] `AppModel` exposes `var needsYou: Bool` (initially driven by mock activity data so the dot is exercised).
- [ ] The tab bar uses the design's recipe — `.background(.regularMaterial)` (or equivalent) with the light/dark `tabBg` tint and a 0.5pt top hairline at `tabBd`.
- [ ] Each tab body is a placeholder `EmptyState(systemImage: "...", title: "<Tab name>", body: "Coming in service-…")`. Placeholders disappear as Phase 3 tickets land.
- [ ] `SettingsView` is moved under the You tab placeholder. The existing API base URL form stays accessible via a deep-link from the placeholder.
- [ ] `TerminalView` and `terminalContext` are removed from `AppModel`. The `TerminalContext` struct stays — it'll be reused by the terminal shell ticket.
- [ ] `MockTmuxAgentRepository` is unchanged (it still seeds the same data; the terminal data flow stops being driven by `selectedTab`).
- [ ] Project builds. Existing `#Preview { ContentView() }` renders the new 5-tab shell with mock data.

## Notes

- The design's tab bar is 56pt tall total (icon + 4 gap + label). Honor the safe-area inset for the home indicator — use a normal `TabView` so SwiftUI handles it; only the visual styling needs to match.
- Don't try to perfectly replicate the SVG icons unless trivial — SF Symbols `tray`, `square.grid.2x2`, `chart.bar.xaxis`, `terminal`, `person.crop.circle` are close substitutes. Use the SVG path approach if a SF Symbol doesn't fit a tab. Either is acceptable; document the choice in the PR.
- The 4-tab → 5-tab change does not need a migration story for `UserDefaults` since the only persisted tab state was the previous `AppTab.projects` default; on first launch under the new shell, default to `.inbox`.
- Keep `TerminalContext` in `App/AppModel.swift` (or move to `Core/Domain/`) — it'll be repurposed for the terminal route in `service-app-route-coordinator.md`.
- The Settings → You move keeps the existing `APIConfiguration` form working. A future ticket (`service-you-screen.md`) replaces the placeholder with the full You screen and folds the API form into Workspace ▸ tmux server.
