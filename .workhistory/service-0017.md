# service-0017: Roadmap — milestone-focused page-swipe view

Ticket: `.tickets/done/service-roadmap-screen.md`

## Summary

Replaces the Roadmap `TabPlaceholder` with the v2 page-swipe layout:
`LargeTitleHeader`, project-filter chip row, and a `TabView(.page)`
with one milestone per page. Each page renders a stateful eyebrow
(NOW · / PLANNED · / SHIPPED), the milestone label, mono ID prefix,
and a `RoundedCard` of feature rows. Tap a feature → push
`AppRoute.featureDetail(featureID:)` on the Roadmap tab's stack.

Introduces `CrossProjectFeatureFetcher` — the cross-project fan-out
helper the Phase 3 plan calls for. Lands here so service-0018
(Sessions list) can reuse it.

## Changes

- `Core/Services/CrossProjectFeatureFetcher.swift` — `@MainActor`
  struct that loads `listProjects` then per-project `listFeatures`
  / `listProjectAgentSessions`. Sequential today (small N); the
  shape is sized for a future parallel upgrade in one place.
  Returns a `Bundle` value with helpers (`allFeatures`,
  `allAgentSessions`, `project(for:)`).
- `Features/Roadmap/RoadmapViewModel.swift` — `@Observable
  @MainActor`. Derives `Milestone` snapshots (raw label, id prefix,
  display label, earliest target, features, state) by grouping the
  fetched bundle's features by `feature.milestone`. Project filter
  narrows the per-milestone feature list without removing the
  milestone (so the page count stays stable). State derivation:
  all `shipped/merged` → `.shipped`; any
  `inProgress/review` → `.active`; otherwise `.planned`.
- `Features/Roadmap/RoadmapView.swift` — top header + chip row +
  `TabView(.page)` of `MilestonePage` views. The page renders
  eyebrow + 28pt label + mono id prefix + features card (or
  filtered-empty `EmptyState`) + bottom hint. `FeatureMilestoneRow`
  is a small visual private to the screen; promote when
  service-0018 needs the same shape.
- `ContentView.swift:51-62` — drops the Roadmap `TabPlaceholder`
  and mounts `RoadmapView` inside the existing
  `NavigationStack(path: coordinator.binding(for: .roadmap))`.
- `remote-codingTests/RoadmapViewModelTests.swift` — Swift
  `Testing` cases for grouping + sort, state derivation,
  project-filter narrowing (with empty-milestone case), id-prefix
  extraction / trim, and the subtitle shape.

## Decisions

- **Project filter keeps milestones, narrows features.** Removing
  a milestone whose features are all filtered out would make the
  swipe count flicker. Instead the milestone stays and the page
  renders an `EmptyState` carrying the filtered project's name —
  matching the ticket's "No features for <project>" copy.
- **Earliest-target sort with deterministic tie-break.**
  Milestones sort by their earliest feature target date; when two
  share a target (or both are nil) they tie-break on the raw
  milestone label so the order stays stable across reloads.
- **`CrossProjectFeatureFetcher` ships sequential today.** The
  Sendable-existential dance to fan out in `withTaskGroup` cleanly
  isn't worth the small N. The struct is designed so a future
  parallel-fetch upgrade is a one-file change.
- **Eyebrow `earliestTarget` reused for both "ENDS" and "STARTS".**
  The ticket's design distinguishes "Now · ends X" vs
  "Planned · starts X" but doesn't surface separate start/end
  dates. Until the contract carries a milestone start date,
  `earliestTarget` doubles as both. A follow-up can tease them
  apart when the data lands.
- **`MilestonePage` and `FeatureMilestoneRow` private to the
  view.** They're roadmap-shaped today; promotion can wait until
  a second screen needs the same composition.

## Notes

- Branched from `service-0016` (still open) to keep
  `ContentView.swift` from conflicting between parallel Phase 3
  PRs. The PR's base is `service-0016`; once #20 / #21 / #22
  land the base will be retargeted to `main`.
- Calendar / extra-filter nav icons are stubs. The ticket scope
  defers their actions to follow-ups.
- iOS gates were not exercised in this session (Linux runner
  without Xcode); the suite needs to run on a Mac via the
  `ios-gates` skill before merge.
