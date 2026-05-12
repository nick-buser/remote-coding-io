---
prefix: service
title: Ticket detail view
status: todo
branch:
---

## Description

Build `TicketDetailView` — a full-screen view showing all ticket fields, its
acceptance criteria (toggleable), and linked agent sessions. Tapping a ticket
row in `FeatureTicketsTab` navigates here.

See `docs/feature_plans/70-spawn-ux.md` for layout spec.

## Acceptance criteria

- [ ] `TicketDetailView` renders:
  - Header: `public_id` chip · status pill (tappable → sheet/picker to change status)
  - Title (inline tap-to-edit, `TextField`)
  - Description (inline tap-to-edit, multiline `TextField`)
  - Branch chip (monospace, tap copies to clipboard)
  - Estimate badge
  - Acceptance criteria section: each criterion is a toggle (done/not done) + text; swipe-to-delete; `+ Add criterion` row at the bottom
  - Agent sessions section: each session shows state badge, session id, uptime, and an "Open pane →" button; "Spawn session" button at the bottom of the section
- [ ] `AppRoute.ticketDetail(publicID:)` is wired from `FeatureTicketsTab` row taps so navigation works.
- [ ] Status and criteria toggles are optimistic: update local state immediately, call repository in background, roll back on failure with `ErrorBanner`.
- [ ] Title and description edits call `updateTicket` on commit (e.g. on `.onSubmit` or focus loss).
- [ ] Criteria use `listCriteria`, `createCriterion`, `updateCriterion`, `deleteCriterion` from the existing repository surface.
- [ ] Agent sessions section calls `listTicketAgentSessions(publicID:)`.
- [ ] "Spawn session" button in the sessions section opens `SpawnSheet` pre-filled to ticket scope (depends on `service-spawn-sheet`).
- [ ] `TicketDetailViewModel` covered by unit tests: loading, status change optimistic update + rollback, criteria toggle optimistic update + rollback.

## Notes

- Extract `AcceptanceCriterionRow` to `Core/Components/` if it currently lives
  private to another view — `TicketDetailView` and any future view should share it.
- Keep the inline edit pattern consistent with `ProjectDetailView` (tap reveals a `TextField` in place, blur/submit saves).
- Do not implement image attachments or comments — those are out of scope.
