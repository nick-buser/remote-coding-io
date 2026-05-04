---
prefix: service
title: Terminal pane chip switcher row
status: todo
branch:
---

## Description

Add the horizontal pane chip switcher above the terminal buffer. Each chip represents an agent session in the same project (or feature, when scoped). Tap a chip to switch the terminal's current session — re-fetches the snapshot and (after `service-terminal-websocket.md`) reconnects the WebSocket. A trailing `+` chip opens `SpawnSessionSheet`.

Depends on `service-terminal-shell.md`, `service-repo-agent-sessions.md`. See `docs/feature_plans/40-terminal.md`.

## Acceptance criteria

- [ ] Below the context bar, a horizontal `ScrollView` of pane chips:
  - For each sibling agent session in the project (or feature, when the terminal was opened from a feature scope): chip with state dot + mono session id.
  - Active session has an accent ring + slightly brighter background.
  - Trailing `+` chip with no state dot.
- [ ] Chip tap switches `currentSessionID`:
  - Re-fetch snapshot.
  - (After WebSocket ticket) close current socket, open new one.
  - Cancel any in-flight requests for the previous session.
- [ ] `+` chip opens `SpawnSessionSheet` with project / feature scope pre-filled. On success, push the new session as the current.
- [ ] Sibling sessions are scoped to the same project. If the originating route was a feature-scoped session detail, narrow further to that feature.
- [ ] When the active session is `awaiting-input`, its chip pulses orange (matches the design's pulse).
- [ ] Tests:
  - Switching session reloads the buffer.
  - `+` chip opens the spawn sheet with correct pre-fill.
- [ ] `#Preview` renders 4 chips with one active.

## Notes

- The chip list is ordered: active session first, then by `last_active_at` desc.
- Use `LazyHStack` to avoid laying out 100 chips when the user has many sessions; in practice, the count stays small per project.
- The sheet for `+` is the same one used in `service-feature-sessions-tab.md` — keep the wiring shared.
