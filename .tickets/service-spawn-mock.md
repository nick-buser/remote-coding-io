---
prefix: service
title: Mock repository support for multi-scope session spawning
status: todo
branch:
---

## Description

Update `MockTmuxAgentRepository` to handle feature- and project-scoped session
creation and add two fixture sessions so previews and tests work before the
real sheet or backend lands.

Depends on `infra-spawn-openapi-regen.md`. See `docs/feature_plans/70-spawn-ux.md`.

## Acceptance criteria

- [ ] `MockTmuxAgentRepository.createAgentSession` handles all three scopes:
  - `ticketPublicId` present → existing ticket-scoped path (unchanged).
  - `ticketPublicId == nil`, `featureId != nil` → look up the feature, derive tmux name `<feature_slug>__session_<featureId>`, create `AgentSession` with `ticketId = nil` and `featureId` set.
  - Both nil, `projectId != nil` → derive `<project_slug>__session_<projectId>`, create `AgentSession` with `ticketId = nil` and `projectId` set.
  - None present → throw a validation error (mirrors backend behaviour).
- [ ] Two new fixture sessions added to `seedAgentSessions`:
  - **session-09** — feature-scoped, feature 19 (FEAT-019 feature-context-bundle), state `active`, tmux name `tmux_agent__feature_context_bundle__session_1714054800`, id 804.
  - **session-10** — project-scoped, project 1 (tmux-agent), state `idle`, tmux name `tmux_agent__session_1714050000`, id 805.
- [ ] `listProjectAgentSessions` returns session-09 and session-10 alongside ticket-bound sessions when queried for project 1.
- [ ] `AgentSession` mock structs include `featureId` and `projectId` fields once the generated type supports them (coordinate with `infra-spawn-openapi-regen`).
- [ ] All existing tests still pass.

## Notes

- Use a fixed ID-based suffix (e.g. `session_<featureId>`) instead of a real
  epoch when constructing mock tmux names so fixtures are deterministic in tests.
- `listProjectAgentSessions` currently filters by `ticketId`-based project
  membership. Extend the filter to also include sessions where `featureId`
  belongs to the project or `projectId` matches directly.
