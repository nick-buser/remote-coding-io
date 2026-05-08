# service-0013: Inbox screen — needs-you / earlier-today + inline actions

Ticket: `.tickets/done/service-inbox-screen.md`

## Summary

Phase 3 begins. Replaces the Inbox tab's `TabPlaceholder` with the v2
two-section feed driven by the workspace `ActivityPoller` from
service-0010. Inline `Approve` and `Reply` actions on review and
question rows route into the existing `ticketDetail` /
`agentSession` routes. Filter chips collapse the sections by kind; an
"All clear" zen empty state ships with the row layout so the screen
reads cleanly when nothing needs you.

`KindIcon` was extended to cover the `.check` and `.approve` activity
kinds the OpenAPI contract emits — both already appear in the mock
seed, but Phase 1 only knew about the original 6.

## Changes

- `Features/Inbox/InboxView.swift` — top-level view mounted in
  `ContentView.swift:27-39`'s Inbox tab `NavigationStack`. Renders
  `LargeTitleHeader`, a `ScrollView`-of-`Chip` filter row, and two
  `RoundedCard` sections (Needs you / Earlier today). `.refreshable`
  drives the poller; `.task` calls `markSeen` and primes the accent
  + live-sessions caches.
- `Features/Inbox/InboxViewModel.swift` — `@Observable @MainActor`
  view-model. Pure derivation methods (`needsYouEvents`,
  `earlierTodayEvents`, `applyFilter`, `filterCounts`,
  `visibleEvents`) consume `[ActivityEvent]` from the poller; the VM
  owns only the filter selection, optimistic-hide set, accent cache,
  and live-sessions count. The numeric ticket id → public id resolver
  goes through `listTickets(featureID:)` — a future
  `getTicketByID` repo method would simplify this and is noted as a
  follow-up.
- `Features/Inbox/InboxRow.swift` — single row visual reused inside
  both cards. Inline `PillButton`s for question + review kinds.
- `Features/Inbox/InboxFilter.swift` — chip enum with `displayed`
  and per-case `matches(_:)` predicate. `.mentions` is defined but
  excluded from `displayed` until backend metadata exists.
- `Features/Inbox/InboxRelativeTime.swift` — pure `(date, now)` →
  `Just now / Nm / Nh / Nd` shape used in the row's mono timestamp.
- `Features/Inbox/ReplySheet.swift` — minimal sheet wrapping
  `repository.sendPaneInput` with `enter: true`. Per the ticket note
  this is a deliberate hand-off; refinement is a follow-up.
- `ContentView.swift:27-37` — Inbox tab body switched from
  `TabPlaceholder` to `InboxView`. Badge logic unchanged.
- `Core/Components/KindIcon.swift` — `ActivityKind` gains `.check`
  and `.approve` cases plus `init(_:Components.Schemas.ActivityKind)`
  so call sites can hand a raw API kind directly.
- `remote-codingTests/InboxViewModelTests.swift` — Swift `Testing`
  cases covering grouping, filter counts, optimistic-hide, the
  legacy/v2 accent mapping, pane id parsing, ticket public-id
  resolution against the mock seed, and the optimistic approve path.

## Decisions

- The view model does **not** own the poller. The view passes
  `appModel.activityPoller.events` into pure derivation methods,
  which keeps the VM testable without a poller fixture and lets the
  `@Observable` re-render machinery do its job from the view body.
- Approve uses an optimistic-hide pattern (`pendingHidden: Set<Int64>`)
  rather than mutating the upstream events. The next poller tick
  refreshes the upstream feed and `pendingHidden` clears, so the
  row reappears with its new `kind == .approve` shape under
  Earlier today.
- The numeric-id-to-public-id resolution is lazy and per-action.
  Listing tickets by feature id and matching on numeric id is
  cheap given today's mock + small ticket counts; a future
  `getTicketByID(_ id: Int64)` method on `TmuxAgentRepository` is
  the right shortcut.
- The legacy mock fixtures still use web-hub accent strings
  ("indigo", "teal", "blue", ...). `InboxViewModel.accentColor(forRaw:)`
  maps both the v2 set and the legacy values so rows stay visually
  distinct between projects until `service-mock-rich-seed`
  migrates the seed.
- The `compose` nav-icon is wired but stubbed — it prints to the
  console. The compose sheet that emits a free-form
  `ActivityEvent(kind: .doc | .decision)` is deferred per the
  ticket note (line 51).
- The `<m> sessions live` half of the subtitle reuses the same
  cross-project fan-out shape the Sessions list will need; the
  helper introduced in service-0017 (`CrossProjectFeatureFetcher`)
  will replace this loader. Until then, `loadLiveSessionsIfNeeded`
  does its own per-project fan-out.

## Notes

- The `Mentions` chip is intentionally excluded from
  `InboxFilter.displayed`; the chip would always read 0 because no
  contract field surfaces mentions yet. A TODO sits in
  `InboxFilter.swift` near the predicate.
- `.toolbar(.hidden, for: .navigationBar)` keeps the system nav bar
  out of the way — `LargeTitleHeader` provides the in-content title.
- The `EmptyInboxRepository` for the "All clear" preview wraps a
  shared `MockTmuxAgentRepository` and overrides only `listActivity`
  + `listProjectAgentSessions` to return `[]`. The other methods
  forward; this keeps preview parity tight without repeating the
  whole seed.
- iOS gates (`xcodebuild build test`) were **not** run in this
  session because the runner is Linux without Xcode; the build will
  be exercised in CI / on a Mac before merge. PR description calls
  this out explicitly.
- The Phase 3 plan (8 screens shipping as 8 sequential PRs) means
  later branches (`service-0014 …`) should be cut from the previous
  branch (not main) to avoid `ContentView.swift` merge conflicts —
  every screen ticket replaces a placeholder there.
