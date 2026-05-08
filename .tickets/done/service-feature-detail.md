---
prefix: service
title: Rebuild Feature detail with hero, progress, segmented tabs
status: done
branch: service-0016
---

## Description

Rewrite `FeatureDetailView` to the v2 dense-with-zen-typography layout: hero (status pill + title + vision), single-line progress, `SegmentedControl(["Tickets", "PRD", "Decisions", "Sessions"])`, and footer actions `+ New ticket` and `Spawn session`.

Depends on `service-project-detail.md`, `service-repo-tickets.md`, `service-repo-docs.md`, `service-repo-decisions.md`, `service-repo-agent-sessions.md`, `infra-component-kit.md`. See `docs/feature_plans/30-screens.md` (section 4).

## Acceptance criteria

- [ ] `Features/FeatureDetail/FeatureDetailView.swift` rewritten to v2 layout (hero + progress + segmented + body + footer).
- [ ] `Features/FeatureDetail/FeatureDetailViewModel.swift` is `@Observable @MainActor` and loads feature, tickets, docs, decisions, agent sessions in parallel.
- [ ] Hero renders: `Pip(accent: feature.accent)` + mono FEAT-018 + status pill (color-coded: in-progress orange, review iris, planned muted, shipped green) + 28pt feature.title + 16pt feature.vision (fg2).
- [ ] Progress line: HStack `<done> of <total> tickets` (mono left) + `target_date` (mono right). 2pt bar with accent fill.
- [ ] Segmented control body switches:
  - **Tickets**: ticket list (covered in `service-feature-tickets-tab.md` — initial body is a placeholder until that ticket lands).
  - **PRD**: docs list (covered in `service-feature-prd-tab.md`).
  - **Decisions**: decisions list (covered in `service-feature-decisions-tab.md`).
  - **Sessions**: agent sessions list (covered in `service-feature-sessions-tab.md`).
- [ ] Footer actions row visible only on Tickets sub-tab: `PillButton("+ New ticket", primary, wide)` and `PillButton("Spawn session", wide)`.
  - `+ New ticket` opens `CreateTicketSheet` (lands in `service-feature-tickets-tab.md`).
  - `Spawn session` opens `SpawnSessionSheet` (lands in `service-feature-sessions-tab.md`).
- [ ] Trailing nav icons: `share` (placeholder) and `dots` (opens menu with `Mark in review`, `Mark planned`, `Mark shipped`, `Edit feature`).
- [ ] Status menu items call `repository.updateFeatureStatus(id:status:)` with the chosen status.
- [ ] Pull-to-refresh.
- [ ] Loading / error / empty states explicit.
- [ ] Tests: hero binding to feature; progress percent computation; sub-tab switching preserves scroll position per-tab.
- [ ] `#Preview` for FEAT-018 shows the in-progress hero.

## Notes

- This ticket lands the *shell* of feature detail; the four sub-tab tickets land the body content. Stub each tab body as `EmptyState(title: "<tab name> coming")` until those tickets land.
- The status pill colors should match `StatusGlyph` semantics. Pull color from a shared helper to avoid drift.
- Don't reach for the previous `FeatureDetailView` editor screens — they were a `WorkspaceDocument` artifact retired in `service-repo-docs.md`.
- The dots menu's `Edit feature` opens a sheet similar to the project edit sheet (covered in `service-feature-create.md` — that ticket reuses the create sheet for edit).
