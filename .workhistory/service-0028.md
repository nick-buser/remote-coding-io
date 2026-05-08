# service-0028: Rebuild Terminal screen shell — dark chrome, slim context bar

Ticket: `.tickets/done/service-terminal-shell.md`

## Summary

Replaces the legacy `TerminalView` prototype with the v2 dark layout: pure-black
full-screen background, slim context bar, static buffer seeded from REST snapshot,
and placeholder strips for quick keys and input bar.

## Changes

- `Core/Repositories/TmuxAgentRepository.swift` — protocol gains
  `getAgentSession(id: Int64) async throws -> Components.Schemas.AgentSession`.
- `Core/Repositories/MockTmuxAgentRepository.swift` — `getAgentSession(id:)`
  searches the in-memory `agentSessions` array by ID; seeds session-07 (id=802)
  pane output for preview content.
- `Core/Repositories/LiveTmuxAgentRepository.swift` — stub throws
  `.unsupported("getAgentSession(id:) requires a contract update.")` until the
  OpenAPI contract adds the endpoint.
- `Core/Domain/AgentSessionExtensions.swift` — `var paneIndex: Int` parses
  `"agent:N.M"` → integer M (after last `.`), fallback 0. `var paneDisplayLabel`
  returns the `"N.M"` portion after `":"`.
- `Features/Terminal/TerminalViewModel.swift` — rebuilt `@Observable @MainActor`
  class. Holds `session`, `siblingSessions`, `output`, `renderedBuffer`,
  `input`, `isLoading`, `isSending`, `errorMessage`, `showSpawnSheet`,
  `socketStatus`. `load(sessionID:repository:activityPoller:)` stops the poller,
  resolves the session, seeds the buffer. `reload` and `sendInput` complete the
  API surface.
- `Features/Terminal/TerminalView.swift` — rewritten to v2 layout: pure black,
  `.toolbar(.hidden)` for both nav and tab bars, `.preferredColorScheme(.dark)`.
  Context bar 44pt height with `BackChevron` leading, centered VStack (session id
  14pt bold + tmux·pane·uptime 10.5pt mono fg2), ellipsis trailing, `terminalChrome`
  bg, 0.5pt white-8% hairline. Buffer renders monospace content. Quick-keys and
  input bar placeholders. `.onDisappear` resumes `activityPoller`.
- `ContentView.swift` — `AppRoute.agentSession(sessionID:)` routes to
  `TerminalView(sessionID: sessionID)`.
- `remote-codingTests/TerminalViewModelTests.swift` — snapshot load, unknown ID
  error, pane index parsing, poller pause/resume coverage.

## Decisions

- **`getAgentSession(id:)` on the protocol before the contract lands.** The mock
  enables development and previews. The live stub means the terminal doesn't work
  against a real server until the endpoint ships — acceptable for this sprint.
- **`paneIndex` lives on `AgentSessionExtensions`** to keep parsing centralized
  and avoid duplicating `"agent:N.M"` logic across views.
- **Tab bar hidden via `.toolbar(.hidden, for: .tabBar)`** rather than
  `.fullScreenCover`. Keeps the navigation stack intact and matches the design.

## Notes

- First PR in the stacked chain targeting `main` directly (PR #38).
- Stack order: service-terminal-shell → pane-switcher → renderer-boundary →
  quick-keys → input → websocket → infra-runestone → service-runestone.
