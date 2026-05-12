# service-0047: Session detail — scope context bar, SessionDetailSheet, killAgentSession

Ticket: `phase8/03-session-detail`

## Summary

Enriches the terminal view with scope context and adds a full `SessionDetailSheet`
accessible from the ··· dots button. `killAgentSession` is wired through the full
stack (OpenAPI → protocol → mock → live). `SessionRow` gains a scope subtitle line.
8 new tests cover the kill operation and scope resolution.

## Changes

- **Modified** `openapi.yaml`:
  - Added `DELETE /api/v1/agent-sessions/{id}` with `operationId: killAgentSession`.
  - Returns 204 on success; 404 / 503 on failure. Path parameter `id` is int64.

- **Modified** `Core/Repositories/TmuxAgentRepository.swift`:
  - Added `func killAgentSession(id: Int64) async throws` to the protocol.

- **Modified** `Core/Repositories/MockTmuxAgentRepository.swift`:
  - `killAgentSession(id:)` — sets `state = .ended`, `endTime = Date()`, `cpu = 0`
    by copying the session struct with mutated fields. Throws `notFound` for unknown IDs.

- **Modified** `Core/Repositories/LiveTmuxAgentRepository.swift`:
  - `killAgentSession(id:)` — delegates to `client.killAgentSession`; handles
    `.noContent`, `.notFound`, `.serviceUnavailable`, `.undocumented`.

- **Modified** `Features/Terminal/TerminalViewModel.swift`:
  - Added `showDetailSheet: Bool`, `scopeTitle: String?`, `scopeContext: ScopeContext?`.
  - Added nested `ScopeContext` struct: `kind (ticket|feature|project)`, `label`, `parentLabel`.
  - Added `loadScope(for:repository:)` — resolves ticket title, feature title, or project name
    from the session's `ticketId` / `featureId` / `projectId`; populates `scopeTitle` and
    `scopeContext`. Called at the end of `load(sessionID:repository:activityPoller:apiConfiguration:)`.

- **New** `Features/Terminal/SessionDetailSheet.swift`:
  - Scope block: icon + label + optional parent label in a `RoundedCard`.
  - Stats block: state, uptime, start time, CPU %, token usage, cost estimate.
  - Kill block: destructive "Kill session" button (hidden when `state == .ended`).
  - `onKill` async closure — caller handles `killAgentSession` and error suppression.
  - `.presentationDetents([.medium, .large])`.
  - `#Preview` with ticket-scoped session.

- **Modified** `Features/Terminal/TerminalView.swift`:
  - Dots button now sets `viewModel.showDetailSheet = true`.
  - Added `.sheet` presenting `SessionDetailSheet` with kill closure.
  - Context bar: adds `scopeTitle` as a second line between the session ID and tmux line when non-nil.

- **Modified** `Features/Projects/Detail/SessionRow.swift`:
  - Added `var scopeTitle: String? = nil` parameter.
  - Renders `scopeTitle` as a 12pt regular subtitle below the tmux session name when non-nil.

- **Modified** `Features/Sessions/SessionsListView.swift`:
  - `row(for:)` passes `scopeTitle: metadata.ticket?.title ?? metadata.project?.name` to `SessionRow`.
  - Awaiting card hero text falls back to `metadata.project?.name ?? session.tmuxSession`.

- **New** `remote-codingTests/SessionDetailTests.swift` — 5 tests:
  - `killSetsEndedState` — verifies state, endTime, cpu after kill.
  - `killUnknownSessionThrows` — expects error for missing ID.
  - `loadScopeTicket` — ticket-scoped session resolves `kind == .ticket` and `TMX-` label.
  - `loadScopeProject` — project-scoped session resolves to project name.
  - `loadScopeNoMatchLeavesNil` — unscoped session leaves `scopeTitle` nil.
  - `sessionRowRendersScopeTitle` — structural check that `SessionRow` accepts the new parameter.

## Decisions

- **`ScopeContext` on the view model, not a free struct** — keeps the resolution
  logic and its type collocated; `SessionDetailSheet` takes the type as a parameter
  via `TerminalViewModel.ScopeContext` so the sheet has no direct ViewModel dependency.
- **Kill closure pattern** — `SessionDetailSheet` receives `onKill: () async -> Void`
  instead of a repository reference; this keeps the sheet testable and avoids threading
  the repo through a sheet's initialiser.
- **`scopeTitle` nil-defaults in `SessionRow`** — backwards compatible; all existing
  call sites continue to compile without changes.

## Notes

- No xcodebuild on this host — CI validates the build.
