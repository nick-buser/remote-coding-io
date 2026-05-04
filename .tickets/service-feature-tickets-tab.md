---
prefix: service
title: Feature detail Tickets sub-tab — list, create, status update
status: todo
branch:
---

## Description

Build the Feature Detail Tickets sub-tab: status-glyph list of tickets with criteria dots, estimate badge, live-session indicator, and a `+ New ticket` footer action. Tap pushes the Review screen for tickets in `review`, otherwise pushes a `TicketDetailView` (defer the latter to a follow-up if needed — initial impl can route both to a placeholder).

Depends on `service-feature-detail.md`, `service-repo-tickets.md`, `infra-component-kit.md`. See `docs/feature_plans/30-screens.md` (section 4 + 6).

## Acceptance criteria

- [ ] `Features/FeatureDetail/Tabs/FeatureTicketsTab.swift` mounts inside the Tickets segmented control case.
- [ ] Renders a `RoundedCard` containing `TicketRow`s. Within the card: optional grouping by `status` (Doing / Todo / Review / Done) when the feature has ≥6 tickets; flat otherwise.
- [ ] `TicketRow`:
  - 14pt `StatusGlyph(status: ticket.status)`.
  - Mono `ticket.public_id` + green `● live` when there's an active `AgentSession` for this ticket + mono updated time pinned right.
  - 14pt ticket.title (single-line ellipsis).
  - Mini criteria dots: 8×4 dashes per criterion, green if done, gray if pending — `criteria_total` count from the ticket.
  - Mono `<criteria_done>/<criteria_total>` count + estimate badge (`S/M/L/XL`) bordered, right-aligned.
- [ ] Tap behavior:
  - `status == review` → push `AppRoute.ticketDetail(publicID:)` (Review screen).
  - Otherwise → push a placeholder `TicketDetailView` showing the ticket's description and criteria checklist. (Defer richer ticket detail to follow-up.)
- [ ] Long-press shows context menu: `Mark doing`, `Mark review`, `Mark done`, `Edit`, plus `Spawn session` (pre-fills `SpawnSessionSheet` with this ticket).
- [ ] Status menu actions call `repository.updateTicket(publicID:body: UpdateTicketRequest(status: ...))` and refresh.
- [ ] Footer's `+ New ticket` opens `CreateTicketSheet`:
  - Form fields: Title (required), Description (multi-line), Status (segmented, default `todo`), Estimate (text, e.g., `S/M/L`), Branch name (optional).
  - Submit calls `repository.createTicket(featureID:body:)`.
  - Field-level errors mapped from `ProblemDetails.errors`.
- [ ] Live indicator state derives from agent sessions: row shows `● live` when any of `feature.agentSessions` has `ticket_id == ticket.id` and `state ∈ {active, awaiting-input}`.
- [ ] Tests: row rendering for each status; create roundtrip; status update reflects in the list.
- [ ] `#Preview` for FEAT-018 with TMX-0042..TMX-0046.

## Notes

- The contract exposes `updateTicket` (PATCH) for arbitrary field updates including status. Use it for status changes.
- `criteria` array on `Ticket` is only populated on single-ticket GET. The list-rendered row uses `criteria_total` / `criteria_done` for the dots count — render `criteria_total` empty dashes, fill the first `criteria_done` of them green. No per-criterion lookup needed at the list level.
- Sorting: within each grouping, mocks return tickets by `updated_at DESC`. Live impl preserves server order.
- The placeholder `TicketDetailView` is fine as long as it shows description + criteria checklist (criteria from `repository.listCriteria(ticketPublicID:)`). A richer view is a follow-up ticket if the design adds one.
