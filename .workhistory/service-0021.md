# service-0021: Feature detail Tickets sub-tab — list, create, status

Ticket: `.tickets/done/service-feature-tickets-tab.md`

## Summary

Replaces the Feature detail Tickets-sub-tab `EmptyState` stub
(landed in service-0016) with a real `FeatureTicketsTab` body:
status-glyph rows with criteria dot bar, live indicator, and
estimate badge; long-press menu for status mutations; `+ New ticket`
footer button now opens a working `CreateTicketSheet`. Tap routes
through a new `TicketDetailRouter` that dispatches to
`TicketReviewView` for review-status tickets and a lightweight
`TicketDetailView` for everything else.

## Changes

- `Features/FeatureDetail/Tabs/FeatureTicketsTab.swift` — new tab
  body. Renders flat under 6 tickets, groups by status (Doing /
  Review / Todo / Done) above. Each row uses a private
  `FeatureTicketRow` (denser than the Project detail's `TicketRow`)
  with criteria dot bar + live `●` indicator derived from
  `viewModel.agentSessions`. Long-press menu wires `Mark doing /
  review / done` through `repository.updateTicket(publicID:body:)`
  and patches the local list in-place. `Edit` and `Spawn session`
  stay disabled until their follow-up tickets land.
- `Features/FeatureDetail/Tabs/CreateTicketSheet.swift` — modal
  form (Title required, Description, segmented Status, Estimate,
  optional Branch name). Submits via `createTicket(featureID:body:)`
  and hands the new ticket to the parent so the list updates
  without a reload.
- `Features/FeatureDetail/TicketDetailView.swift` — placeholder
  detail screen (header + StatusPill + estimate badge + description
  card + read-only criteria checklist). Pulls criteria via
  `repository.listCriteria(ticketPublicID:)` on appear.
- Same file: `TicketDetailRouter` — fetches the ticket by
  public id and dispatches to `TicketReviewView` (for
  `.review`) or `TicketDetailView` (anything else).
- `Features/FeatureDetail/FeatureDetailView.swift` — `ticketsSummary`
  stub replaced with `ticketsBody: FeatureTicketsTab(...)`. The
  Tickets-tab footer's `+ New ticket` `PillButton` now drives
  `showCreateTicketSheet`. Sheet attached to the view body.
- `ContentView.swift:100` — `.ticketDetail` route now mounts
  `TicketDetailRouter` instead of `TicketReviewView` directly. The
  Inbox `Open diff` flow + Project / Feature ticket drill-downs
  all funnel through the router.
- `remote-codingTests/FeatureTicketsTabTests.swift` — Swift
  `Testing` cases covering the status-group spec (every
  `TicketStatus` is grouped), mock-backed load + status update +
  create insertion, the live-indicator predicate, and the
  router's status-based dispatch.

## Decisions

- **`TicketDetailRouter` over a route-shape change.** Adding a
  separate `.ticketDoing(publicID:)` route would force every call
  site to know the status before pushing. The router fetches the
  ticket once and dispatches; callers continue to push
  `.ticketDetail(publicID:)` regardless of status, matching the
  ticket spec and keeping `AppRoute` flat.
- **Flat list under 6 tickets, grouped above.** The threshold
  matches the ticket's "≥6 tickets" rule. Below 6, the dense
  group headers feel heavy for small features; above, they help
  scan-ability.
- **Live indicator pulled from existing
  `viewModel.agentSessions`.** That set already loads with the
  feature; one filter pass per row is cheap, no extra fetch
  needed.
- **`FeatureTicketRow` is local to the tab, not a shared
  component.** The Project detail's flat `TicketRow` already has
  a different visual treatment (chip-style criteria, no live
  dot, no estimate badge); merging them would either bloat both
  or split into a configuration-heavy component. Keep them
  separate until the design forces convergence.
- **Edit and Spawn-session menu items disabled.** Edit lands
  with `service-feature-create` reuse; Spawn lands with
  `service-feature-sessions-tab`. Showing them as disabled rows
  keeps the menu shape stable.

## Notes

- Branched from `main` (post-rollup #27). Subsequent sub-tab
  branches (`service-0022 …`) will stack off the previous to
  avoid `FeatureDetailView.swift` conflicts.
- `TicketDetailView.description` reads through the schema's
  required `String` (not optional) — trim before checking
  emptiness.
- iOS gates were not exercised in this session (Linux runner
  without Xcode); the suite needs to run on a Mac via the
  `ios-gates` skill before merge.
