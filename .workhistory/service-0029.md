# service-0029: Terminal pane chip switcher row

Ticket: `.tickets/done/service-terminal-pane-switcher.md`

## Summary

Adds the horizontal pane chip row above the buffer and wires session switching —
tapping a chip re-fetches the snapshot and (after the WebSocket ticket) reconnects
the transport. A trailing `+` chip opens `SpawnSessionSheet`.

## Changes

- `Features/Terminal/TerminalViewModel.swift` — adds `loadSiblings(repository:)`
  (iterates all projects via `listProjectAgentSessions` to find the owning project,
  sorts active session first). `switchSession(to:repository:)` closes the socket
  and reloads. `showSpawnSheet: Bool` flag wired to the spawn-sheet binding.
- `Features/Terminal/TerminalView.swift` — `PaneChipRow` embedded below the
  context bar: `LazyHStack` of chips with state dots (green/orange/dim), accent
  ring on active chip, `+` spawn chip at the trailing end. `.task` also calls
  `loadSiblings(repository:)`.
- `remote-codingTests/PaneSwitcherTests.swift` — sibling load, active-first sort,
  switch reloads buffer, `+` chip opens spawn sheet.

## Decisions

- **Sibling discovery via full project scan** rather than passing project context
  through the route. `loadSiblings` iterates `listProjectAgentSessions` for each
  project to find the one that owns the current session — avoids any route API
  change and keeps `AppRoute.agentSession(sessionID:)` slim.
- **Active session pinned first** in chip order. Remaining chips sorted by
  `last_active_at` desc — matches the design spec.
- **`LazyHStack`** to avoid layout cost on projects with many sessions; in
  practice the count per project stays small.

## Notes

- PR #35 in the stack, targeting `phase4/01-terminal-shell`.
