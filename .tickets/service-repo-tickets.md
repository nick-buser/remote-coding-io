---
prefix: service
title: Add Ticket and AcceptanceCriterion repository methods
status: todo
branch:
---

## Description

Extend `TmuxAgentRepository` with the Ticket + Acceptance Criterion endpoints from `../api/openapi.yaml`. Implement against the generated OpenAPI client in `LiveTmuxAgentRepository` and against fixtures in `MockTmuxAgentRepository` so previews can render Tickets without backend access.

Tickets are first-class in the v2 design (Project ▸ Feature ▸ Ticket ▸ Agent Session). Every later screen that lists tickets, shows ticket counts, or routes to a ticket review depends on this ticket.

Depends on `infra-openapi-regen.md`. See `docs/feature_plans/20-navigation-and-data.md`.

## Acceptance criteria

- [ ] `TmuxAgentRepository` adds the following methods:
  - `func listTickets(featureID: Int64, status: Components.Schemas.TicketStatus?) async throws -> [Components.Schemas.Ticket]`
  - `func getTicket(publicID: String) async throws -> Components.Schemas.Ticket`
  - `func createTicket(featureID: Int64, body: Components.Schemas.CreateTicketRequest) async throws -> Components.Schemas.Ticket`
  - `func updateTicket(publicID: String, body: Components.Schemas.UpdateTicketRequest) async throws -> Components.Schemas.Ticket`
  - `func listCriteria(ticketPublicID: String) async throws -> [Components.Schemas.AcceptanceCriterion]`
  - `func createCriterion(ticketPublicID: String, body: Components.Schemas.CreateAcceptanceCriterionRequest) async throws -> Components.Schemas.AcceptanceCriterion`
  - `func updateCriterion(id: Int64, body: Components.Schemas.UpdateAcceptanceCriterionRequest) async throws -> Components.Schemas.AcceptanceCriterion`
  - `func deleteCriterion(id: Int64) async throws`
- [ ] `LiveTmuxAgentRepository` calls the corresponding generated operations: `listTickets`, `createTicket`, `getTicket`, `updateTicket`, `listTicketCriteria`, `createTicketCriterion`, `updateCriterion`, `deleteCriterion`.
- [ ] `MockTmuxAgentRepository` returns fixture tickets sourced from `claude_design_references/.../data.jsx` (TMX-0042..TMX-0070). Each fixture ticket has `public_id`, `feature_id`, `title`, `description`, `status`, `estimate`, `branch_name`, `criteria_total`, `criteria_done`, `created_at`, `updated_at`.
- [ ] Mock criteria are returned by `listCriteria`. Counts on the parent ticket (`criteria_total`, `criteria_done`) match the per-ticket criterion list.
- [ ] `MockTmuxAgentRepository` mutates state on create / update / delete so a screen can roundtrip a new ticket / new criterion and see it in the next list call.
- [ ] Tests:
  - `listTickets(featureID:status:)` filters mocks by `feature_id` and (when set) status. Server-side filtering verified for live (request includes `?status=` query param when non-nil).
  - `createTicket` returns a 201-equivalent ticket with `public_id` matching the `^TMX-\\d{4}$` pattern.
  - `createCriterion` appends to the end of the list when `sort_order` is omitted.
  - `updateCriterion` toggles `done` and surfaces in subsequent `listCriteria` calls.
- [ ] No view layer changes — this ticket only touches `Core/Repositories/`.
- [ ] Project builds and existing tests pass.

## Notes

- `Ticket.criteria` (the inline array) is populated only on the single-ticket GET. Mock should mirror that — `getTicket(publicID:)` returns the array; `listTickets(...)` returns tickets without it.
- `AcceptanceCriterion.sort_order` is opaque to clients — the repository should always sort the returned array by `sort_order` ascending so views don't need to.
- `CreateTicketRequest.status` defaults to `todo` when omitted (per the generated default). Confirm by the live request payload; do not hard-code on the client.
- `TicketStatus` mapping: `todo`, `doing`, `review`, `done`. Keep these as-is for now — `StatusGlyph` from the component kit handles the visual mapping.
- This ticket does NOT add the per-ticket Diff / Approve / Request changes / Send back endpoints — those land in `service-repo-review.md`.
- This ticket does NOT add the per-ticket AgentSessions list — that lands in `service-repo-agent-sessions.md`.
- Keep the local `WorkspaceDocument` concept untouched here. It's separately retired in `service-repo-docs.md`.
