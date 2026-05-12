# infra-0007: Pull spawn-scope contract + regenerate Swift client

Ticket: `.tickets/infra-spawn-openapi-regen.md`

## Summary

Updates `openapi.yaml` to make `ticket_public_id` optional in
`CreateAgentSessionRequest`, adds `feature_id` / `project_id` to both the
request and the `AgentSession` response schema, and refreshes the operation
descriptions. The Swift OpenAPI Generator produces updated
`Components.Schemas.CreateAgentSessionRequest` and
`Components.Schemas.AgentSession` types at build time.

## Changes

- **Modified** `remote-coding/remote-coding/openapi.yaml`:
  - `AgentSession` schema: added `feature_id` (nullable int64, set for
    feature-scoped sessions) and `project_id` (nullable int64, set for
    project-scoped sessions).
  - `CreateAgentSessionRequest` schema: removed `required: [ticket_public_id]`;
    made `ticket_public_id`, `feature_id`, and `project_id` all optional with
    clear precedence docs. Updated description with session-name derivation
    table and agent-context injection notes.
  - `createAgentSession` operation: updated summary and description to reflect
    multi-scope spawning.
  - `listProjectSessions` operation: updated description — now returns all
    sessions regardless of scope (ticket-, feature-, project-scoped).

## Decisions

- **No Swift source edits required.** `LiveTmuxAgentRepository.createAgentSession`
  already accepts the full generated request body and passes it straight
  through to the generated client. The mock will be updated in
  `service-spawn-mock` once the generated types are known.
- **`required` array removed, not narrowed.** OpenAPI 3.1 doesn't allow
  conditional `required` per-field; removing the required array makes all
  properties optional, which matches the "at least one of the three"
  validation that the server enforces.

## Notes

- PR stacked on `phase6/05-push-settings`.
- No xcodebuild on this host — CI validates the generated Swift types.
