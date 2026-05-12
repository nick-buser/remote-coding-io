---
prefix: service
title: Session detail — scope context, stats, and actions in terminal + session card
status: todo
branch:
---

## Description

The current terminal view identifies a session only by `session-<id>` and the raw
tmux session name. Users have no way to see *what* a session is working on (which
ticket / feature / project), nor can they take lifecycle actions (kill, rename,
view CPU history) without leaving the app. This ticket enriches the terminal context
bar with scope context and adds a full session detail sheet accessible from the dots
menu.

## Acceptance criteria

### Terminal context bar enrichment
- [ ] `TerminalView.contextBar` centre block currently shows:
  ```
  session-<id>
  <tmuxSession> · <pane> · <uptime>
  ```
  Replace the centre block with a resolved scope label:
  - **Ticket-scoped**: `<publicId> · <ticket.title truncated to 28 chars>`
  - **Feature-scoped**: `FEAT-### · <feature.title truncated>`
  - **Project-scoped**: `<project.name>`
  - Fallback (scope unknown / still loading): existing `session-<id>` display.
- [ ] `TerminalViewModel` resolves the scope label on load:
  - If `session.ticketId != nil`: fetch ticket via `repository.getTicket(publicID:)`
    (already available via the session's linked ticket, or use `session.ticketId`
    mapped to `publicId` if available — add `getTicketByID(id:)` to the protocol
    if needed, otherwise resolve via project ticket cache).
  - If `session.featureId != nil`: fetch feature.
  - If `session.projectId != nil`: use the already-loaded project name.
  - Store as `var scopeContext: ScopeContext? = nil`.
  - Failures are silent — context bar falls back to `session-<id>`.

### Session detail sheet
- [ ] Tapping the context bar centre block (or the `…` dots menu → "Session info")
  opens a `SessionDetailSheet` as `.presentationDetents([.medium])`.
- [ ] **`Features/Terminal/SessionDetailSheet.swift`**:
  - Header: `session-<id>` mono, state `StatusPill`, uptime.
  - **Scope section**:
    - Project row (always present): `Pip` + project name + tappable chevron →
      `coordinator.push(.projectDetail(slug: project.slug))` + sheet dismiss.
    - Feature row (if feature-scoped or ticket-scoped): FEAT-### + feature title,
      tappable.
    - Ticket row (if ticket-scoped): publicId + ticket title, tappable.
  - **Stats section**:
    - CPU: `\(session.cpu, format: .percent)` gauge bar (0–100%).
    - Start time: relative (`InboxRelativeTime.short`) + absolute (long date on tap).
    - Last active: relative time.
    - Pane: mono `session.pane`.
  - **Actions section**:
    - "Kill session" (destructive) — calls a new `killAgentSession(id:)` repository
      method (see backend note below); on success pops terminal and updates session
      state to `.ended` in the parent list.
    - "Copy tmux name" — copies `session.tmuxSession` to clipboard.
- [ ] `SessionRow` (used in Sessions tab and project detail) gains a subtitle line
  showing the scope context: `TMX-0042 · Pane registry` for ticket-scoped,
  `FEAT-019 · feature-context-bundle` for feature-scoped, project name for
  project-scoped. Resolved lazily from the `SessionsListViewModel.metadata(for:)`
  cache — no new network calls.

### Repository changes
- [ ] Add `killAgentSession(id: Int64) async throws` to `TmuxAgentRepository` protocol.
- [ ] `MockTmuxAgentRepository.killAgentSession`: sets the session's state to `.ended`
  in the in-memory store and removes it from active lists.
- [ ] Add to `openapi.yaml`:
  ```yaml
  /api/v1/agent_sessions/{id}:
    delete:
      summary: Kill an agent session
      ...
  ```
  (This is a **shared iOS + backend ticket** for the protocol side; the actual
  backend implementation may be a separate parent-repo ticket.)

### Tests
- [ ] `TerminalViewModel` resolves ticket-scoped context correctly from mock data.
- [ ] `TerminalViewModel` falls back gracefully when scope resolution fails.
- [ ] `MockTmuxAgentRepository.killAgentSession` marks session as ended.
- [ ] `SessionRow` renders scope subtitle for ticket-, feature-, and project-scoped
  sessions using fixture data.

## Notes

- `session.ticketId` (the Int64 FK) is available but there is no `getTicket(id:)`
  method — only `getTicket(publicID:)`. If resolving a ticket-scoped session's
  context, the cleanest path is to look up the publicId from the project's ticket
  cache (already loaded in `SessionsListViewModel`). Add `func getTicket(id:)` to
  the protocol only if the cache approach is impractical.
- The "Kill session" action sends a `DELETE` to the backend. If the backend kill
  endpoint doesn't exist yet, stub it out behind the mock and leave the live path
  returning "Not implemented" — the UI should handle a 404/501 gracefully with an
  error banner rather than crashing.
- Keep `SessionDetailSheet` independent of `TerminalView` — it should be presentable
  from `SessionRow.onLongPress` in a future ticket without changes.
