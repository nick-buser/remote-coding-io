# service-0014: Projects list — v2 Pinned + All sections

Ticket: `.tickets/done/service-projects-list.md`

## Summary

Replaces the legacy single-`List` `ProjectListView` with the v2 design:
`LargeTitleHeader` + Pinned section + All projects section, each
`RoundedCard`-wrapped, with `ProjectRow` rendering an accent tile,
title (plus pin star), tagline, and a `MetaPill` row of status / live
count / feature counts. Long-press exposes Pin/Unpin (wired) and
Edit / Open in tmux / Delete (stubbed for follow-up tickets).

## Changes

- `Features/Projects/ProjectListView.swift` — rewritten to the v2
  layout. `ScrollView` + sections; `.task(id: project.id)` on each
  row triggers the lazy live-count load. Pull-to-refresh re-runs
  `viewModel.load`. Empty / loading / error states render inline;
  `LoadingStateView` extraction is deferred until a 3rd screen
  needs the same shape.
- `Features/Projects/ProjectListViewModel.swift` — `@Observable
  @MainActor` with `projects`, `featureCounts: [Int64:
  FeatureCount]`, `liveSessionCounts: [Int64: Int]`. `load`
  fetches projects + feature counts (sequential, fine for the
  workspace's small N — service-0017's `CrossProjectFeatureFetcher`
  will replace this); `loadLiveSessionCount(for:)` is the per-row
  lazy entry point. `togglePin` round-trips every field through the
  PUT-shaped `UpdateProjectRequest` and patches the local snapshot.
- `Features/Projects/ProjectRow.swift` — new visual row plus two
  small helper types: `ProjectStatusStyle` (status → color/label)
  and `ProjectAccentMapper` (legacy + v2 accent strings → the
  v2 `AccentColor` set). `ProjectIconGlyph` maps known SF Symbol
  names + falls back to a single Unicode glyph to honour the
  design's `◇`/`⌗`/`✺` icons.
- `ContentView.swift` — drops the now-redundant
  `.navigationTitle("Projects")` since the screen renders its own
  in-content title and hides the system nav bar.
- `remote-codingTests/ProjectListViewModelTests.swift` — Swift
  `Testing` cases for sort, partition, subtitle shape, mock-backed
  load + feature counts, lazy live-count caching, togglePin
  resort, and the status / accent mappings.

## Decisions

- **Sequential feature-count fan-out.** `withTaskGroup` with
  `@MainActor`-annotated child tasks is the obvious parallel
  shape, but the Sendable-existential isolation tax (and the
  marginal benefit at N=2 projects) wasn't worth it here.
  `service-0017` introduces a proper `CrossProjectFeatureFetcher`
  that this loader will switch to.
- **Lazy live-count via `task(id:)`.** Each `ProjectRow` triggers
  a single `loadLiveSessionCount` on first render. The cache key
  is `liveSessionCounts[project.id]` — a pre-existing entry
  short-circuits the repo call. Refresh clears the cache via the
  `load` reset so pulled-down counts re-fetch.
- **Pin-toggle round-trips every field.** The contract's
  `UpdateProjectRequest` requires `name` and `local_repo_path`
  (the schema's `required` list) and the mock blindly assigns
  every field on the request; passing nil for nullable fields
  would clobber them. The togglePin helper rebuilds the request
  from the local snapshot and only flips `pinned`.
- **`LoadingStateView` extraction deferred.** The plan called for
  it to land here. Skipped to keep the PR tight; the inline
  if/else handling is small enough that a generic wrapper would
  be premature. The first screen that actually duplicates this
  shape (likely service-0015 or service-0016) is a better
  extraction point.

## Notes

- The Edit / Open in tmux / Delete context-menu items are
  rendered as `.disabled(true)` placeholders so the menu shape
  matches the design today; their actions land in
  `service-projects-edit.md` and the terminal phase respectively.
- `<m> live sessions` in the subtitle stays nil until at least one
  row has reported. This avoids a 0-flicker on first load —
  the subtitle just shows "<n> projects" until counts populate.
- iOS gates were not exercised in this session (Linux runner
  without Xcode); the suite needs to run on a Mac via the
  `ios-gates` skill before merge.
- service-0014 was branched from `main` (post-0013 merge), so
  no `chore: land` commit is needed. Subsequent screen tickets
  (`service-0015 …`) will be cut from the previous open branch
  to avoid `ContentView.swift` merge conflicts when multiple
  Phase 3 PRs are open in parallel.
