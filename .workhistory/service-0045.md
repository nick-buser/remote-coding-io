# service-0045: Cross-workspace search — projects, features, tickets

Ticket: `.tickets/service-search.md`

## Summary

Adds client-side cross-workspace search across the full project hierarchy.
`SearchViewModel` loads and caches the data bundle once per session;
`SearchView` is a reusable sheet that accepts an optional `scopeProject`
parameter to limit results to a single project. Three entry points are wired:
the Projects tab header, every `ProjectDetailView`, and the Sessions tab header.

## Changes

- **New** `Features/Search/SearchViewModel.swift`:
  - `@MainActor @Observable final class SearchViewModel`.
  - Nested types: `ProjectedFeature` (feature + parent project),
    `ProjectedTicket` (ticket + parent feature + parent project),
    `SearchResults` (three arrays + `.empty` static + `isEmpty`).
  - `load(repository:)` — fetches all projects, then features per project,
    then tickets per feature. Skips on failure with `try?` so partial loads
    still surface valid results. Sets `isLoaded = true` on success; subsequent
    calls are no-ops.
  - `invalidate()` — clears the bundle and resets `isLoaded`; called by
    `ProjectListView` on pull-to-refresh.
  - `results(for:scopeProject:)` — pure filter using
    `localizedCaseInsensitiveContains` (diacritics-insensitive).
    Project matches: `name`, `slug`, `tagline`, `description`.
    Feature matches: `title`, `slug`, `vision`.
    Ticket matches: `title`, `description`, `publicId`, `branchName`.
  - Private `matchesSearch` extensions on `Project`, `Feature`, `Ticket`.

- **New** `Features/Search/SearchView.swift`:
  - `@State var viewModel: SearchViewModel` — caller passes the shared
    instance from `AppModel.searchViewModel`.
  - Custom search bar (HStack with `magnifyingglass` icon, `TextField`,
    `xmark.circle.fill` clear button) with `@FocusState` auto-focus on
    `.task`.
  - 150ms debounce via `Task.sleep` + `Task.isCancelled` check.
  - Four body states: loading spinner, hint (empty query), empty-results
    `EmptyState`, grouped `List`.
  - Grouped `List` with three optional sections (Projects / Features / Tickets)
    each showing a header with entity count in mono. Missing sections hidden.
  - Result rows: `ProjectResultRow` (Pip + name + slug), `FeatureResultRow`
    (FEAT-### · project name · title), `TicketResultRow` (publicId · feature
    name · title). Each row dismisses the sheet on tap and calls
    `coordinator.push(route)`.
  - `.presentationDetents([.large])`.
  - `#Preview` for global and scoped variants.

- **Modified** `App/AppModel.swift`:
  - Added `let searchViewModel = SearchViewModel()` — one instance shared
    across all search presentations in a session.

- **Modified** `Features/Projects/ProjectListView.swift`:
  - Added `@State private var showSearchSheet = false`.
  - Wired existing `NavIconButton(name: .search)` to `showSearchSheet = true`.
  - Added `.sheet(isPresented: $showSearchSheet)` presenting global `SearchView`.
  - Added `appModel.searchViewModel.invalidate()` to `.refreshable` block.

- **Modified** `Features/Projects/ProjectDetailView.swift`:
  - Added `@State private var showSearchSheet = false`.
  - Wired existing `NavIconButton(name: .search)` to `showSearchSheet = true`.
  - Added `.sheet` presenting scoped `SearchView(scopeProject: viewModel.project, ...)`.

- **Modified** `Features/Sessions/SessionsListView.swift`:
  - Added `@State private var showSearchSheet = false`.
  - Added `NavIconButton(name: .search)` to header (next to `+`).
  - Added `.sheet(isPresented: $showSearchSheet)` presenting global `SearchView`.

- **New** `remote-codingTests/SearchViewModelTests.swift` — 9 tests:
  - Empty and whitespace queries return empty results.
  - Project name and slug match.
  - Feature title match with parent project populated.
  - Ticket publicId and title match.
  - Diacritics-insensitive match.
  - Scoped search limits to project.
  - Second `load()` call is a no-op (caching).
  - `invalidate()` clears the bundle.

## Decisions

- **Shared `SearchViewModel` on `AppModel`** — avoids re-fetching on every
  sheet open within a session; invalidation on pull-to-refresh keeps data fresh.
- **Client-side only** — no backend search endpoint; filtering is fast enough
  for the expected workspace sizes. Backend search can be added later as a
  progressive enhancement.
- **Scoped search reuses the same `SearchView` + `SearchViewModel`** — no
  separate view or VM class; `scopeProject` parameter is the only difference.
- **No match highlighting in v1** — plain text rows keep the implementation
  tractable.

## Notes

- No xcodebuild on this host — CI validates the build.
