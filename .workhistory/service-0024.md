# service-0024: Feature detail Sessions sub-tab + Spawn flow

Ticket: `.tickets/done/service-feature-sessions-tab.md`

## Summary

Replaces the Sessions-sub-tab `EmptyState` stub (landed in
service-0016) with `FeatureSessionsTab`: a list of agent sessions
scoped to the feature, grouped by state when there are ≥4 (Active /
Awaiting / Idle / Ended), flat otherwise. Each row uses the
existing `SessionRow` from `Features/Projects/Detail/` so the
visual stays consistent with the global Sessions tab.

Adds `SpawnSessionSheet` — the modal form that creates a new
`AgentSession`. Reachable from two places:
- The Sessions sub-tab's footer button.
- The Tickets sub-tab's `Spawn session` footer button (previously
  a stub from service-0016 / service-0021).

On success the sheet dismisses, prepends the new session to the
view-model's `agentSessions`, and pushes
`.agentSession(sessionID:)` onto the active tab's stack so the
user lands directly on the (legacy prototype) terminal.

## Changes

- `Features/FeatureDetail/Tabs/FeatureSessionsTab.swift` — sub-tab
  body. Group threshold = 4. Footer `Spawn session` pill is
  disabled with a "Create a ticket first" hint when the feature
  has zero tickets, matching the ticket note's safeguard.
- Same file: `SpawnSessionSheet` — ticket picker (default = most
  recently updated), advanced disclosure with optional
  `tmux_session` override and starting `state` segmented control.
  Submits `CreateAgentSessionRequest` and hands the result back
  via the `onSpawned` closure.
- `Features/FeatureDetail/FeatureDetailView.swift`:
  - `sessionsSummary` → `sessionsBody: FeatureSessionsTab(...)`.
  - New `@State showSpawnSessionSheet` plus a `.sheet` modifier
    presenting `SpawnSessionSheet`. The success closure prepends
    to `agentSessions` and pushes `.agentSession(sessionID:)`.
  - Tickets-tab footer's `Spawn session` button now flips
    `showSpawnSessionSheet`, and is disabled when the feature
    has no tickets.
- `remote-codingTests/FeatureSessionsTabTests.swift` — Swift
  `Testing` cases covering feature-scoped session loading, the
  state-group spec (every `SessionState` is grouped), spawn
  prepend, and `tmuxSession` / `state` override propagation.

## Decisions

- **`SessionRow` reuse from `Features/Projects/Detail/`** — the
  visual matches the global Sessions list exactly. Promoting it
  to `Core/Components/` is one rename away but the existing
  location works for three call sites today and the move would
  churn imports without semantic value.
- **Two entry points to the same `SpawnSessionSheet`.** The
  Tickets-tab footer and the Sessions-tab footer share state on
  `FeatureDetailView`. Owning the binding at the view level
  keeps the two paths in sync (e.g., a long-press menu added
  later can flip the same flag).
- **Advanced disclosure ships closed.** The default-state path
  (no override, server picks state) is the common case; the
  disclosure surfaces the override controls without making them
  mandatory.
- **`Spawn` button disabled when no tickets exist** — the
  ticket spec calls for this safeguard. The feature view shows
  a small "Create a ticket first" hint under the disabled
  button so the user knows where to go.
- **Push to `.agentSession(sessionID:)` after spawn.** The
  destination today is the legacy terminal prototype; when
  `service-terminal-shell` lands, this push will reach the v2
  surface unchanged.

## Notes

- This is the **last sub-tab ticket**. After landing, every
  Feature detail sub-tab body is real. The remaining queued
  tickets are the create / edit modals
  (`service-projects-create`, `service-projects-edit`,
  `service-feature-create`).
- Branched from `service-0023` (still open). Base will retarget
  to `main` once #28 / #29 / #30 land.
- iOS gates were not exercised in this session (Linux runner
  without Xcode); the suite needs to run on a Mac via the
  `ios-gates` skill before merge.
