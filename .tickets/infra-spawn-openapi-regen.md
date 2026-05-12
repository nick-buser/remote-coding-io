---
prefix: infra
title: Pull spawn-scope contract + regenerate Swift client
status: todo
branch:
---

## Description

After `infra-spawn-scope` merges in the parent repo, pull the updated
`openapi.yaml` into `remote-coding/remote-coding/openapi.yaml`, run the Swift
OpenAPI Generator, and confirm the generated `CreateAgentSessionRequest` and
`AgentSession` types reflect the new optional fields.

Depends on `infra-spawn-scope.md`. See `docs/feature_plans/70-spawn-ux.md`.

## Acceptance criteria

- [ ] `openapi.yaml` updated so `CreateAgentSessionRequest.ticket_public_id` is optional and `feature_id` / `project_id` optional integer fields are present.
- [ ] `AgentSession` schema gains optional `feature_id` and `project_id` integer fields.
- [ ] Generated Swift types (`CreateAgentSessionRequest`, `AgentSession`) updated accordingly.
- [ ] `TmuxAgentRepository.createAgentSession` still compiles — no signature change required (method already accepts the full generated request body).
- [ ] `ListProjectAgentSessions` (GET `/api/v1/projects/{idOrSlug}/sessions`) openapi response schema includes feature- and project-scoped sessions (no iOS change needed beyond picking up the updated type).
- [ ] Build succeeds; existing tests pass.

## Notes

No UI in this ticket — purely the data layer. The mock update (`service-spawn-mock`) depends on this ticket completing so the generated types are known before the mock is written.
