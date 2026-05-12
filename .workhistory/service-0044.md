# service-0044: Wire SpawnSheet at all entry points

Ticket: `.tickets/done/service-spawn-wiring.md`

## Summary

Wires the new `SpawnSheet` / `SpawnSheetViewModel` into every surface that
previously used `SpawnSessionSheet` or had a placeholder. Removes the old
`SpawnSessionSheet` struct. All four entry contexts now produce a fully
functional multi-scope spawn flow.

## Changes

- **Modified** `Features/Sessions/SessionsListView.swift`:
  - `.sheet(isPresented: $showSpawnSheet)` — replaced `EmptyState` placeholder
    with `SpawnSheet(entry: .sessionsTab, ...)`. Scope picker visible, nothing
    pre-filled.

- **Modified** `Features/FeatureDetail/FeatureDetailView.swift`:
  - `.sheet(isPresented: $showSpawnSessionSheet)` — replaced
    `SpawnSessionSheet(feature:tickets:accent:onSpawned:)` with
    `SpawnSheet(entry: .feature(viewModel.feature, viewModel.project), ...)`.
    Project + feature shown as locked labels; scope picker allows Feature or
    Ticket.
  - `footerActions` — removed `.disabled(viewModel.tickets.isEmpty)` from the
    "Spawn session" button; feature-scope sessions don't need a ticket.

- **Modified** `Features/FeatureDetail/Tabs/FeatureSessionsTab.swift`:
  - `footer` — collapsed the disabled-when-no-tickets branching; "Spawn
    session" always enabled and calls `showSpawnSheet = true`.
  - Deleted the `SpawnSessionSheet` struct entirely.

- **Modified** `Features/Projects/ProjectDetailView.swift`:
  - Added `@State private var showSpawnSheet = false`.
  - Added `.sheet(isPresented: $showSpawnSheet)` presenting
    `SpawnSheet(entry: .project(viewModel.project), ...)`.
  - `sessionsBody` — changed return type from `Group` to `VStack`; appended
    a "Spawn session" `PillButton` footer below the session list (or empty
    state).

- **Modified** `Features/FeatureDetail/TicketDetailViewModel.swift`:
  - Added `var feature: Components.Schemas.Feature?` and
    `var project: Components.Schemas.Project?`.
  - `load()` — after the main async-let block, silently loads feature by
    `ticket.featureId`, then project by `feat.projectId`. Failures are ignored
    so they don't surface an error banner.

- **Modified** `Features/FeatureDetail/TicketDetailView.swift`:
  - Added `.sheet(isPresented: $showSpawnSheet)` presenting
    `SpawnSheet(viewModel: makeSpawnVM(feature:project:))` when
    `viewModel.feature` and `viewModel.project` are resolved.
  - `makeSpawnVM` private helper: constructs
    `SpawnSheetViewModel(entry: .feature(feature, project), ...)` and sets
    `vm.preselectedTicket = viewModel.ticket` — scope locked to Ticket,
    project + feature shown as labels, ticket shown as a locked label.
  - "Spawn session" button in `sessionsSection` — disabled while
    `viewModel.feature == nil || viewModel.project == nil` (resolves
    after `load()` completes).

## Decisions

- **Feature entry for TicketDetailView**, not a dedicated `SpawnEntry.ticket`
  case. The existing `.feature` entry with `preselectedTicket` covers this
  use case as specified, keeping the enum at three variants.
- **Silent feature/project load failure** in `TicketDetailViewModel.load()`.
  Network errors here are not surfaced; the spawn button simply stays
  disabled. The main load error (criteria / sessions) still sets
  `errorMessage`.
- **No optimistic insert** for FeatureDetail / ProjectDetail sessions lists on
  successful spawn. The coordinator navigates to the new session immediately;
  the sessions list will refresh on next visit or pull-to-refresh.

## Notes

- Stacked on `phase7/04-spawn-sheet`.
- `SpawnSessionSheet` struct is fully removed; no other file referenced it
  outside `FeatureDetailView`.
- No xcodebuild on this host — CI validates the build.
