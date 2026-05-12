# service-0042: Mock repository support for multi-scope session spawning

Ticket: `.tickets/done/service-spawn-mock.md`

## Summary

Updates `MockTmuxAgentRepository` to handle feature- and project-scoped
session creation, adds two fixture sessions, and extends
`listProjectAgentSessions` to return all three scope types.

## Changes

- **Modified** `Core/Repositories/MockTmuxAgentRepository.swift`:
  - `createAgentSession` — full three-scope dispatch:
    - `ticketPublicId` present → existing ticket-scoped path (now passes
      `featureId: nil, projectId: nil` to the new `AgentSession` fields).
    - `featureId` non-nil → derives tmux name as
      `<project_slug>__<feature_slug>__session_<featureId>`, creates
      `AgentSession` with `featureId` set and `ticketId / projectId` nil.
    - `projectId` non-nil → derives tmux name as
      `<project_slug>__session_<projectId>`, creates session with
      `projectId` set and others nil.
    - None present → throws `MockRepositoryError.problem` (mirrors backend).
  - `listProjectAgentSessions` — extended filter: also returns sessions
    where `session.featureId` is in the project's feature set, or
    `session.projectId` matches the project directly.
  - `seedAgentSessions` Spec struct: added `featureID: Int64?` and
    `projectID: Int64?` with three dedicated inits for each scope.
    `AgentSession` constructed with new `featureId:` and `projectId:`
    arguments.
  - **session-09** (id 804): feature-scoped, feature 12
    (FEAT-019 feature-context-bundle), state `.active`, pane `agent:3.0`,
    tmux `tmux_agent__feature_context_bundle__session_12`.
  - **session-10** (id 805): project-scoped, project 1 (tmux-agent),
    state `.idle`, pane `agent:4.0`, tmux `tmux_agent__session_1`.

- **New** `remote-codingTests/SpawnMockTests.swift` — 8 tests:
  - Fixture sessions present and correctly scoped.
  - `listProjectAgentSessions` includes all three scope types.
  - `createAgentSession` happy-path for ticket, feature, and project scopes.
  - No-scope request throws.
  - Newly created feature- and project-scoped sessions appear in
    `listProjectAgentSessions`.

## Decisions

- **ID-based suffix for feature/project session names.** Uses the entity's
  database ID rather than an epoch timestamp so fixture tmux names are
  deterministic in tests.
- **Existing ticket-scoped path unchanged.** The only addition to the
  ticket-scoped branch is passing the new nil fields.
- **No changes to `listTicketAgentSessions`.** Ticket sessions are already
  filtered by `ticketId`.

## Notes

- Stacked on `phase7/02-ticket-detail`.
- `AgentSession.featureId` / `projectId` are generated from the openapi.yaml
  change in `phase7/01`; CI regenerates the types.
