---
prefix: service
title: Rebuild Projects list with v2 design — pinned + all sections
status: done
branch: service-0014
---

## Description

Replace the existing `ProjectListView` with the v2 design. Two grouped sections (Pinned, All projects), each a rounded card of `ProjectRow`s. Pull-to-refresh, search, and the create-project plus button are wired here.

Depends on `service-tab-shell.md`, `infra-component-kit.md`. See `docs/feature_plans/30-screens.md` (section 2).

## Acceptance criteria

- [ ] `Features/Projects/ProjectListView.swift` is rewritten to the v2 layout: `LargeTitleHeader(title: "Projects", subtitle: "<n> projects · <m> live sessions")` + Pinned section + All projects section.
- [ ] `Features/Projects/ProjectListViewModel.swift` is `@Observable @MainActor` with `projects: [Project]`, `isLoading`, `error`, `liveSessionCounts: [Int64: Int]`, `featureCounts: [Int64: (active: Int, total: Int)]`.
- [ ] `ProjectRow` (in `Features/Projects/ProjectRow.swift`) renders:
  - 38pt rounded square (radius 9pt) tinted with `project.accent`, white glyph from `project.icon` (font 18, weight 600).
  - Title (16pt, weight 600) + 10pt yellow pinned star when `project.pinned`.
  - Tagline (13pt, fg2, single line ellipsis).
  - MetaPill row: `MetaPill(icon: "●", iconColor: statusColor, label: statusLabel)`, `MetaPill(label: "<n> live")` when `liveSessions > 0`, `MetaPill(label: "<active>/<total> features")`.
  - Trailing chevron.
- [ ] Tap pushes `AppRoute.projectDetail(idOrSlug:)`.
- [ ] Long-press shows context menu with `Pin / Unpin`, `Edit`, `Open in tmux`, `Delete` actions. Edit and Delete are stubbed to no-ops in this ticket — they're wired in `service-projects-edit.md`.
- [ ] Trailing nav icons: `search` (placeholder — opens nothing yet) and `plus` (opens `CreateProjectSheet` — see `service-projects-create.md` for the sheet).
- [ ] Live session counts are fetched lazily as rows scroll into view (not for every project on first load). Use `task(id:)` per row to debounce.
- [ ] Feature counts are fetched once on first load via `repository.listFeatures(projectIDOrSlug:status:)` for each project (parallelized).
- [ ] Status colors / labels:
  - `.active` → green dot, "Active".
  - `.maintenance` → orange dot, "Maint.".
  - `.paused` → muted dot, "Paused".
- [ ] Pull-to-refresh re-runs the load.
- [ ] Loading shows `ProgressView` centered. Error renders `EmptyState(title: "Couldn't load projects", body: error.message)` with a `Retry` button.
- [ ] Tests: view model sorts pinned first, then `last_touched_at` desc; respects mock fixtures' pinned state.
- [ ] `#Preview` renders the screen with the 4-project mock fixture.

## Notes

- Server-side ordering is undefined; do client sort: pinned-first, then `last_touched_at` desc. Keep it stable across refreshes.
- `project.icon` from the contract is a string. Map to SF Symbols where possible (`terminal`, `iphone`, `doc.text`, `shippingbox`, etc.). Fallback: render the literal character if it's a single Unicode glyph (the design uses `◇`, `⌗`, `✺`, `∎`).
- Don't load data inside the row — load it in the view model, key by project ID.
- The "search" nav icon is a placeholder. A search sheet ticket lands later; this ticket just renders the icon.
- Avoid the dense version's stats strip on this screen — it's only on the project detail. Projects list stays sparse.
