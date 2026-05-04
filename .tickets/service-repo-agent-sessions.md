---
prefix: service
title: Add AgentSession repository methods (list / spawn)
status: todo
branch:
---

## Description

Add the `AgentSession` endpoints (`/api/v1/projects/{idOrSlug}/sessions`, `/api/v1/tickets/{publicId}/sessions`, `/api/v1/agent-sessions`) to the repository layer. `AgentSession` is the persistent PM-hub session record (with `state`, `cpu`, `start_time`, `last_active_at`, `transcript_key`, `token_usage`, `cost_estimate`) and is distinct from raw tmux `Session`. The Sessions tab and the per-feature Sessions sub-tab list `AgentSession`s, not tmux sessions.

Depends on `infra-openapi-regen.md`. See `docs/feature_plans/20-navigation-and-data.md` and `docs/feature_plans/30-screens.md`.

## Acceptance criteria

- [ ] `TmuxAgentRepository` adds:
  - `func listProjectAgentSessions(projectIDOrSlug: String) async throws -> [Components.Schemas.AgentSession]`
  - `func listTicketAgentSessions(ticketPublicID: String) async throws -> [Components.Schemas.AgentSession]`
  - `func createAgentSession(_ body: Components.Schemas.CreateAgentSessionRequest) async throws -> Components.Schemas.AgentSession`
- [ ] `LiveTmuxAgentRepository` wires to `listProjectSessions`, `listTicketSessions`, `createAgentSession` generated operations.
- [ ] `MockTmuxAgentRepository` seeds 4 agent sessions matching `data.jsx` (session-04 idle, session-05 awaiting-input, session-07 active, session-08 active) with their `state`, `pane`, `cpu`, ticket_id, start_time, last_active_at.
- [ ] Mock `createAgentSession` honors the contract description: derives `tmux_session` as `<project_slug>__<feature_slug>__<branch_slug>` when the request omits it. Returns a fully-populated record with a fresh `id` and `state == idle`.
- [ ] Repository methods return sessions sorted by `last_active_at` desc by default; the Sessions tab can re-sort client-side as needed.
- [ ] An adapter `AgentSession.uptime` computed property returns a human string (`2h 14m`) from `start_time`. Place it as an extension in `Core/Domain/AgentSessionExtensions.swift` so views can read it directly.
- [ ] Tests:
  - `listProjectAgentSessions` filters mocks by project membership.
  - `listTicketAgentSessions` filters mocks by `ticket_id`.
  - `createAgentSession` returns a record whose `tmux_session` matches the derived format when omitted.
- [ ] Project builds.

## Notes

- The mock should also mutate the activity feed when a session is created — emit an `ActivityEvent(kind: .check, ...)` so the Inbox / Activity poller picks it up. Coordinate with the activity mock (probably a small `MockState` actor that both mocks share).
- `AgentSession.state` enum is `{ idle, active, awaiting-input, ended }`. The Sessions tab groups by state; map `awaiting-input` to "Awaiting" in UI labels.
- Don't conflate `AgentSession` with `Session` (tmux raw). Keep both around. The terminal screen takes an `AgentSession.id`, resolves the `tmux_session` and `pane` strings from it, and uses those for `getPaneOutput` and the WebSocket URL.
- `transcript_key` and `token_usage` are placeholders for future Garage S3 integration — render them only when present and non-empty. Don't crash on null.
- The contract has `pane` as a string (e.g., `agent:2.0`). Parse it client-side into `(window, paneIndex)` only at the terminal screen — repositories return the string verbatim.
