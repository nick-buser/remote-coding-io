---
prefix: infra
title: Backend — extend CreateAgentSessionRequest to support feature/project scope
status: todo
branch:
---

## Description

Make `ticket_public_id` optional in `CreateAgentSessionRequest` and add
optional `feature_id` / `project_id` so sessions can be spawned at any scope
in the hierarchy. This is a **parent-repo ticket** (changes live in the API
server, not in this iOS repo).

See `docs/feature_plans/70-spawn-ux.md` for the full spec.

## iOS dependency chain

The iOS multi-scope spawn UI (`SpawnSheet`, `SpawnSheetViewModel`) is **already
shipped** in phase 7. It currently works entirely against `MockTmuxAgentRepository`.
Once this backend ticket is merged, the iOS side only needs the `openapi.yaml`
regeneration step (see `infra-spawn-openapi-regen`, already done in phase 7/01 —
verify the field names below match what was already shipped to avoid a second regen):

| iOS field name | Expected API field name |
|---|---|
| `ticketPublicId` | `ticket_public_id` |
| `featureId` | `feature_id` |
| `projectId` | `project_id` |

If the backend ships field names that differ from the above, a small
`infra-spawn-openapi-regen-v2` iOS ticket will be needed to pull the updated
contract and regenerate. Check `remote-coding/remote-coding/openapi.yaml` (the
`CreateAgentSessionRequest` schema) as the source of truth for what iOS currently
expects.

## Acceptance criteria

- [ ] `CreateAgentSessionRequest.ticket_public_id` is no longer required.
- [ ] New optional fields: `feature_id: integer`, `project_id: integer`.
- [ ] Validation: exactly one of `ticket_public_id`, `feature_id`, `project_id`
  must be non-null. Return HTTP 422 with a clear error message if zero or more
  than one is supplied.
- [ ] Derived session names:
  - Ticket: `<project_slug>__<feature_slug>__<branch_slug>` (unchanged)
  - Feature: `<project_slug>__<feature_slug>__session_<epoch_sec>`
  - Project: `<project_slug>__session_<epoch_sec>`
- [ ] `AgentSession` response schema gains optional `feature_id` and `project_id`
  fields reflecting the scope (already reflected in iOS `openapi.yaml` from
  `infra-spawn-openapi-regen`; confirm field names match).
- [ ] Agent context injection adapts to scope:
  - **Ticket-scoped**: existing behaviour (ticket description + criteria as context).
  - **Feature-scoped**: feature PRD blocks + open ticket list injected as context.
  - **Project-scoped**: project description + active feature list injected as context.
- [ ] `GET /api/v1/projects/{idOrSlug}/sessions` returns all sessions in the
  project regardless of scope (ticket-, feature-, and project-scoped).
- [ ] All new fields documented in `openapi.yaml`.
- [ ] Backend tests cover: ticket-scoped (unchanged), feature-scoped create,
  project-scoped create, missing-scope 422, multi-scope 422.

## Notes

- Epoch suffix in feature/project session names prevents collisions when spawning
  multiple sessions under the same scope.
- The iOS `MockTmuxAgentRepository` already implements the full three-scope dispatch
  (feature name derivation uses entity ID rather than epoch for determinism in tests
  — the live server should use epoch). See `.workhistory/service-0042.md` for the
  mock implementation as a reference for expected behaviour.
- Once this ticket is merged, test the live path on device by opening the Sessions
  tab `+` button and spawning a project-scoped session.
