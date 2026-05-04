---
prefix: service
title: Rebuild Terminal screen shell — dark chrome, slim context bar
status: todo
branch:
---

## Description

Replace the existing `TerminalView` with the v2 dark layout: pure black background, slim context bar (back chevron, centered session id + tmux session · pane · uptime, dots menu), buffer area, quick-keys row, and input bar. The tab bar is hidden while the terminal is presented. The buffer initially renders text from the existing REST snapshot (`getPaneOutput`) — WebSocket streaming lands in `service-terminal-websocket.md`.

Depends on `service-app-route-coordinator.md`, `service-repo-agent-sessions.md`, `infra-component-kit.md`, `infra-design-tokens.md`. See `docs/feature_plans/40-terminal.md`.

## Acceptance criteria

- [ ] `Features/Terminal/TerminalView.swift` is rewritten to the v2 layout. Old `TerminalViewModel.swift` is rebuilt to load against `AgentSession.id` (input parameter) rather than `TerminalContext`.
- [ ] On `AppRoute.agentSession(sessionID:)`:
  - View loads the session via `repository.listProjectAgentSessions(...)` or a future `getAgentSession(id:)` (mock: search the cached list by ID).
  - View resolves `tmux_session` and `pane` (parsed from `agent:N.M` to integer pane index).
  - View calls `repository.getPaneOutput(sessionName:paneID:)` to seed the buffer.
- [ ] Layout:
  - Black background, ignoring safe areas.
  - Tab bar hidden via `.toolbar(.hidden, for: .tabBar)` (or `.fullScreenCover` from the source tab).
  - **Context bar** (44pt height): `BackChevron(label: "Sessions", accent: user.accent)` leading; centered VStack { 14pt white weight 600 `session.id`, 10.5pt mono fg2 `tmux_session · pane · uptime` }; `dots` icon trailing. Bottom 0.5pt hairline at 8% white.
  - **Buffer area**: monospaced 13pt content from snapshot. Scroll to bottom on load. Padding 14pt.
  - **Quick keys row**: placeholder strip (filled by `service-terminal-quick-keys.md`).
  - **Input bar**: placeholder bar with mono "send a command" hint (filled by `service-terminal-input.md`).
  - **Home indicator**: respect safe-area; SwiftUI handles it. Don't draw our own.
- [ ] On dismiss: pop back to the source tab's previous route. Resume the workspace activity poller (it pauses while the terminal is presented).
- [ ] Loading state: spinner centered while snapshot is fetched.
- [ ] Error state: shows `EmptyState(title: "Couldn't reach pane", body: ..., retry:)`.
- [ ] Pause workspace `ActivityPoller` while presented; resume on dismiss.
- [ ] Tests:
  - Loads the snapshot when the session ID resolves.
  - Pane string `agent:2.0` parses to `(window: 2, pane: 0)`.
  - Activity poller is paused while the terminal is on screen.
- [ ] `#Preview` renders for session-07 with mock buffer content.

## Notes

- The session ID → tmux_session resolution is non-trivial: `AgentSession.tmux_session` is the canonical name (e.g., `tmux-agent__multiplexer__feat-tmx-0050`). Pass that to `getPaneOutput`.
- `pane` parsing: `agent:2.0` → window `2`, pane index `0`. The contract's pane endpoint takes `paneId` as an integer — pass the pane portion. Document that we ignore the window (tmux server uses `<window>.<pane>` but our REST takes pane index relative to the active window).
- Hide the tab bar by presenting the terminal as a `.fullScreenCover` from the originating row; this keeps the tab bar's state intact for return.
- The terminal previously lived inside the tab bar. The transition is a one-time visual change — call out in the PR's test plan that the tab bar should disappear when entering and reappear when leaving.
- Future tickets land the actual transport (WebSocket) and the renderer (`PaneTextRenderer`, then Runestone). This shell ticket gets the screen looking right with a static buffer.
