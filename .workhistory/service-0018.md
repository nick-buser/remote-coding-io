# service-0018: Sessions tab — awaiting hero + grouped list

Ticket: `.tickets/done/service-sessions-list.md`

## Summary

Replaces the Sessions `TabPlaceholder` with the v2 hybrid layout:
`LargeTitleHeader`, "AWAITING YOU" hero block (counter + 1–3
`RoundedCard`s with `Open pane` actions), `ScrollChips` filter row,
and Active / Awaiting / Idle status-grouped sections rendering
`SessionRow`s. Tap any row → push `.agentSession`. The plus button
opens a stub spawn sheet; the pickers ship with
`service-feature-sessions-tab`.

Builds on `CrossProjectFeatureFetcher` from service-0017 — the same
helper now powers both the Roadmap and Sessions screens.

## Changes

- `Features/Sessions/SessionsListViewModel.swift` — `@Observable
  @MainActor`. Owns the workspace bundle, ticket cache, and
  `SessionFilter` selection. Pure derivation methods compute the
  awaiting / active / idle partitions, hero-vs-section split (hero
  wins for ≤ 3 awaiting), filter counts, and per-row metadata
  (project + ticket + feature label + accent).
- `Features/Sessions/SessionsListView.swift` — header + hero block
  + chip row + grouped sections. Reuses `SessionRow` from
  service-0015 (`Features/Projects/Detail/`). The awaiting hero
  cards use 18pt-radius `RoundedCard`s per the design.
- `ContentView.swift:60-70` — drops the Sessions `TabPlaceholder`
  and mounts `SessionsListView` inside the existing
  `NavigationStack(path: coordinator.binding(for: .sessions))`.
- `remote-codingTests/SessionsListViewModelTests.swift` — Swift
  `Testing` cases for load, partition counts, hero-vs-section
  invariant, filter predicate (including ended-state exclusion),
  metadata resolution, and the subtitle shape.

## Decisions

- **Hero ↔ section split keyed on count.** When awaiting count ≤ 3
  the hero shows them and the Awaiting section is empty; above 3
  the hero hides its cards and the Awaiting section renders the
  full list. The hero's counter and copy ("AWAITING YOU · n
  sessions") stay regardless. Matches the ticket note: "hero wins
  when count ≤ 3; section wins beyond that".
- **`.ended` sessions filtered out everywhere.** They'd otherwise
  show up under Idle counts; the filter predicate excludes them
  upstream so all four chip counts and the grouping match what
  the user expects to see.
- **Per-row metadata via cached lookup.** Loading project +
  feature + ticket data once during `load` lets the row resolve
  its metadata synchronously. The ticket cache shape is
  `[Int64: [Ticket]]` keyed by project id; the row walks the
  flattened list to find the matching ticket id.
- **Spawn sheet stubbed.** The ticket scope says the pickers
  (project → feature → ticket) ship with
  `service-feature-sessions-tab`. The plus button is wired so the
  sheet shape exists today.
- **Activity-event-driven refresh deferred.** The ticket suggests
  subscribing to the workspace `ActivityPoller` so commit /
  review / approve events kick a refresh. Keeping that out of this
  PR — pull-to-refresh covers the immediate case and the
  Inbox already drives the same poller, so the user-visible delay
  is small.

## Notes

- Branched from `service-0017` (still open) to avoid
  `ContentView.swift` conflicts when parallel Phase 3 PRs sit
  in flight. The PR's base is `service-0017`; once #20 / #21 /
  #22 / #23 land the base will retarget to `main`.
- `SessionRow` already lives at
  `Features/Projects/Detail/SessionRow.swift` from service-0015;
  this PR consumes it as-is. When the v2 design surfaces a
  different cross-project row variant the file can promote to
  `Features/Shared/Rows/` without a contract change here.
- iOS gates were not exercised in this session (Linux runner
  without Xcode); the suite needs to run on a Mac via the
  `ios-gates` skill before merge.
