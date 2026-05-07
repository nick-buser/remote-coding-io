# service-0007: Ticket + AcceptanceCriterion repository methods

Ticket: `.tickets/done/service-repo-tickets.md`

## Summary

Phase 2 of the v2 plan kicks off here. Tickets are first-class
in the v2 information hierarchy (Project ▸ Feature ▸ Ticket ▸
Agent Session) so every later screen that lists tickets, drills
into a review, or shows a criteria badge first needs the data
layer underneath it. This branch lands the eight repository
methods end-to-end (live OpenAPI client + mock + tests) without
touching the view layer — that surface change comes with the
Phase 3 screen tickets.

## Changes

- `TmuxAgentRepository` gains eight methods:
  - `listTickets(featureID:status:)`
  - `getTicket(publicID:)`
  - `createTicket(featureID:body:)`
  - `updateTicket(publicID:body:)`
  - `listCriteria(ticketPublicID:)`
  - `createCriterion(ticketPublicID:body:)`
  - `updateCriterion(id:body:)`
  - `deleteCriterion(id:)`
- `LiveTmuxAgentRepository` wraps the matching generated
  operations (`listTickets`, `getTicket`, `createTicket`,
  `updateTicket`, `listTicketCriteria`,
  `createTicketCriterion`, `updateCriterion`,
  `deleteCriterion`) and sorts criteria by `sort_order`
  ascending in `listCriteria` so views never have to.
- `MockTmuxAgentRepository` seeds 15 tickets (TMX-0042 through
  TMX-0070, mapped from the Claude Design `data.jsx` fixtures
  onto the existing mock features 11 / 12 / 21) with mixed
  `todo / doing / review / done` statuses and per-ticket
  acceptance criteria. Mutations roundtrip — every create /
  update / delete on a criterion recomputes
  `criteria_total` / `criteria_done` on the parent ticket so
  list responses stay consistent with `getTicket`.
- 11 new `remote_codingTests` cases cover the full surface:
  feature scoping, status filter, list-vs-get criteria
  semantics, TMX-#### regex on create, default `.todo` status
  on omit, mutation persistence, append-on-omit `sort_order`,
  done toggle propagation, count recompute on delete.
- The lead chore commit lands `service-0006`'s housekeeping
  (move `service-app-route-coordinator.md` to
  `.tickets/done/`, write `.workhistory/service-0006.md`).

## Decisions

- **List vs get carries different shapes for `criteria`.** The
  contract returns the inline `criteria` array only on
  `getTicket(publicID:)`; the list response omits it and rides
  on `criteria_total / criteria_done`. The mock mirrors this
  exactly — list responses strip `criteria`, get responses
  attach the sorted array. A single `criteriaByTicketID`
  dictionary backs both paths so there is one source of truth
  for counts.
- **Sort criteria server-side in `listCriteria`.** The
  contract documents `sort_order` as opaque to clients, so
  every screen that paints criteria has to sort. Doing it once
  in the repository keeps every view unaware of the
  representation.
- **`createTicket` issues `TMX-NNNN` from a sequence rather
  than mapping `nextTicketID`.** The generator's default + the
  spec say new tickets get a fresh public ID matching
  `^TMX-\d{4}$`, and the design's data starts at TMX-0042 and
  ends at TMX-0070. Seeding `nextTicketPublicSequence` to 71
  makes the first user-created ticket TMX-0071 — keeps the
  fixture range stable while letting the test assert the
  pattern without locking in a specific value.
- **`Ticket.estimate` and `Ticket.branchName` default to
  empty strings, not nil.** The schema marks both as
  required-strings on the response side; the spec lets the
  request omit them. The mock honours that asymmetry — omit on
  create, default to `""` on the response. Tests cover the
  default path.
- **Counts recompute on every criterion mutation, including
  delete.** Cheap and avoids drift between `listTickets`
  responses and `getTicket` responses. The recompute also
  bumps the parent ticket's `updated_at`, which keeps any
  future "tickets sorted by recently-updated" view honest
  without requiring an explicit touch from the caller.

## Notes

- `MockTmuxAgentRepository.seedTickets` is intentionally a
  static helper that returns a tuple. Building the seed array
  inline in `init` would have meant 200+ lines in one
  initializer; the helper keeps the data shape readable and
  the init focused on wiring.
- `xcodebuild build test` was green on the iPhone 17
  simulator. `testLaunchPerformance` was skipped this run
  because the simulator host hit `mkstemp: No space left on
  device` while writing perf result bundles — re-enable when
  the simulator's disk pressure is relieved. No code change
  here touches launch performance, so the skip is unrelated to
  the ticket.
- View-layer wiring lands separately in
  `service-feature-tickets-tab` and
  `service-feature-create`. This ticket only edits
  `Core/Repositories/` and the test target.
- The mock seed is a stopgap — `service-mock-rich-seed`
  rebuilds fixtures one-for-one with the design narrative.
  Until then the data is shape-correct (status + criteria
  distribution) but does not match the design's specific
  copy.
