---
prefix: service
title: Rebuild Project detail with hero, stats strip, segmented sections
status: todo
branch:
---

## Description

Rewrite `ProjectDetailView` to the v2 hybrid layout — zen hero (large name + tagline) + 4-up stats strip + segmented control (Features / Tickets / Docs / Sessions). Default tab `Features` shows status-grouped feature lists.

Depends on `service-projects-list.md`, `service-app-route-coordinator.md`, `service-repo-tickets.md`, `service-repo-agent-sessions.md`, `infra-component-kit.md`. See `docs/feature_plans/30-screens.md` (section 3).

## Acceptance criteria

- [ ] `Features/Projects/ProjectDetailView.swift` rewritten to:
  - `QuietHeader(label: project.name, leading: BackChevron("Projects"), trailing: dots)` for the top bar.
  - Hero: 34pt display project.name + 15pt fg2 tagline.
  - 4-up stats strip in a `RoundedCard`: `Active`, `Open`, `Live`, `Total`.
  - `SegmentedControl(["Features", "Tickets", "Docs", "Sessions"])`.
  - Body switches:
    - **Features**: `FeatureGroupedList` with sections "In progress", "In review", "Planned", "Shipped" — each section a `RoundedCard` of `FeatureRow`s. Hide empty sections.
    - **Tickets**: flat `TicketList` across all features in the project (uses `repository.listTickets` per feature, parallelized).
    - **Docs**: list of all docs across all features in the project.
    - **Sessions**: list of `AgentSession`s scoped to this project.
- [ ] `FeatureRow` renders: 16pt status glyph, mono FEAT-018 + 6pt accent pip + mono milestone, 15pt title (single line), progress bar (60×4 accent fill), mono `<done>/<total>`, green `● <n> live` when sessions, mono target date right.
- [ ] Tap a `FeatureRow` → `AppRoute.featureDetail(featureID:)`.
- [ ] Stats strip values:
  - Active = features with status `in_progress`.
  - Open = sum of tickets with status ≠ `done` across project's features.
  - Live = `AgentSession`s with state `active` or `awaiting-input`.
  - Total = total features.
- [ ] Trailing nav icons: `search` (placeholder) and `dots` (opens menu with `Edit`, `Pin/Unpin`, `Open in tmux`, `Delete` — see `service-projects-edit.md`).
- [ ] Pull-to-refresh re-fetches all data.
- [ ] Loading / error states explicit.
- [ ] Tests: section grouping correctness; stats math; mock-driven roundtrip.
- [ ] `#Preview` for tmux-agent project (PRJ-01) shows non-empty sections.

## Notes

- Avoid n+1 fetches when computing stats — fetch features once, then ticket counts in parallel by feature ID.
- The Tickets / Docs / Sessions sub-tabs render flat lists scoped to the project; in the Feature Detail screen the same lists exist but scoped per-feature. Reuse the row components (`TicketRow`, `DocRow`, `SessionRow`) — ticket rows show the parent FEAT pip, doc rows show the parent feature title.
- The dots menu's `Open in tmux` updates `project.tmux_session_name` — refresh the row's status section after the call returns.
- Don't show all four sub-tabs if the project has zero data in one — keep them visible (consistency) but render the empty state inside.
