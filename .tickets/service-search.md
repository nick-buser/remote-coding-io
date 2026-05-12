---
prefix: service
title: Cross-workspace search — projects, features, tickets
status: todo
branch:
---

## Description

Add a search surface that lets the user find any project, feature, or ticket by
name/title across the entire workspace. Search runs client-side against already-
cached data so it works offline and requires no new backend endpoint. The entry
point is a search icon already present in the `ProjectDetailView` toolbar and a
global search trigger from the Sessions and Projects tabs.

## Acceptance criteria

- [ ] **`Features/Search/SearchView.swift`** — full-screen search sheet:
  - `@FocusState` text field that auto-focuses on presentation.
  - Results update as the user types (debounced 150ms via `Task.sleep`).
  - Results grouped into three sections: **Projects**, **Features**, **Tickets**.
    Each section header shows the entity count in mono. Empty sections are hidden.
  - Empty state when query is non-empty and no matches: "No results for "<query>"."
  - Loading spinner while the data bundle is being fetched on first open.
- [ ] **`Features/Search/SearchViewModel.swift`**:
  - `@MainActor @Observable` class.
  - `load(repository:)` — fetches `listProjects()` then features + tickets across
    all projects in parallel. Caches the bundle; re-uses on subsequent opens in
    the same app session.
  - `results(for query: String) -> SearchResults` — pure function; filters:
    - Project: `name`, `slug`, `tagline`, `description`.
    - Feature: `title`, `slug`, `vision`.
    - Ticket: `title`, `description`, `publicId`, `branchName`.
    - Case-insensitive, diacritics-insensitive (`localizedCaseInsensitiveContains`).
  - `struct SearchResults { projects: [Project]; features: [Feature]; tickets: [Ticket] }`
- [ ] **Result rows**:
  - `ProjectResultRow`: accent `Pip` + project name + slug mono.
  - `FeatureResultRow`: FEAT-### mono + title + parent project name in fg2.
  - `TicketResultRow`: publicId mono + title + parent feature name in fg2.
  - Tapping any row pushes the correct `AppRoute` via `coordinator.push(...)` and
    dismisses the search sheet.
- [ ] **Entry points**:
  - `ProjectDetailView` top bar search icon (currently a stub) → opens search sheet
    pre-scoped to that project (omit cross-project results).
  - `SessionsListView` and `ProjectListView` top bar: global search icon opens the
    full cross-workspace sheet.
  - Keyboard shortcut: dismiss sheet on Escape / Cancel button.
- [ ] **`remote-codingTests/SearchViewModelTests.swift`** — at least 5 tests:
  - Empty query returns empty results.
  - Project name match, feature title match, ticket publicId match (exact).
  - Diacritics-insensitive match ("feature" matches "featuré").
  - Results contain only items from the selected project when scoped.
- [ ] `#Preview` with mock results shown.

## Notes

- No backend `GET /search` endpoint exists. Client-side filtering is intentional for
  v1; backend search can be added later without changing this screen.
- The data bundle is loaded once and shared across all search sheet presentations
  within a session. Pull-to-refresh on the Projects list should invalidate the cache
  (`SearchViewModel.invalidate()`).
- Don't try to highlight matched substrings in v1 — just plain text rows.
- Scoped search (within a single project) reuses the same `SearchView` / `SearchViewModel`;
  pass a `scopeProject: Project?` parameter to `SearchView.init` to filter.
- The search icon `NavIconButton(name: .search)` already appears in `ProjectDetailView`;
  wire it here instead of adding a new button.
