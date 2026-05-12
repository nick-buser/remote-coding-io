---
prefix: infra
title: Backend — extend CreateAgentSessionRequest to support feature/project scope
status: todo
branch:
---

## Description

Make `ticket_public_id` optional in `CreateAgentSessionRequest` and add
optional `feature_id` / `project_id` so sessions can be spawned at any scope
in the hierarchy. This is a **parent-repo ticket**.

See `docs/feature_plans/70-spawn-ux.md` for the full spec.

## Acceptance criteria

- [ ] `CreateAgentSessionRequest.ticket_public_id` is no longer required.
- [ ] New optional fields: `feature_id: integer`, `project_id: integer`.
- [ ] Validation: at least one of the three must be present. If multiple are given they must be consistent.
- [ ] Derived session names:
  - Ticket: `<project_slug>__<feature_slug>__<branch_slug>` (unchanged)
  - Feature: `<project_slug>__<feature_slug>__session_<epoch_sec>`
  - Project: `<project_slug>__session_<epoch_sec>`
- [ ] `AgentSession` response schema gains optional `feature_id` and `project_id` fields reflecting the scope.
- [ ] Agent context injection adapts to scope (feature PRD + open ticket list for feature-scoped; project brief for project-scoped).
- [ ] `GET /api/v1/projects/{idOrSlug}/sessions` returns all sessions in the project regardless of scope (not just ticket-bound ones).
- [ ] All new fields documented in `openapi.yaml`.

## Notes

- Coordinate field names with iOS `infra-spawn-openapi-regen`.
- Epoch suffix in feature/project session names prevents collisions when
  spawning multiple sessions under the same scope.
