---
prefix: service
title: Wire spawn entry points across the app
status: todo
branch:
---

## Description

Replace every "Spawn session" stub in the app with a real `SpawnSheet`
presentation at the correct entry point. Remove placeholder `EmptyState`
copies in sheets.

Depends on `service-spawn-sheet.md`. See `docs/feature_plans/70-spawn-ux.md`
for the entry-point table.

## Acceptance criteria

- [ ] Sessions tab `+` button opens `SpawnSheet(entry: .sessionsTab)` — no pre-fill, scope picker visible.
- [ ] `FeatureDetail` Sessions sub-tab "Spawn session" button opens `SpawnSheet(entry: .feature(feature, project))` — project and feature labels shown, scope locked to Feature or Ticket.
- [ ] `ProjectDetail` sessions section "Spawn session" button opens `SpawnSheet(entry: .project(project))` — project label shown, scope picker visible (Feature or Project), feature picker visible for Feature scope.
- [ ] `TicketDetailView` sessions section "Spawn session" button opens `SpawnSheet` pre-filled to the ticket's project, feature, and ticket; scope locked to Ticket.
- [ ] All placeholder `EmptyState` copies inside spawn-related sheets are removed.
- [ ] No remaining `// TODO: spawn` or stub button in the codebase.
- [ ] Spawning at all four entry points against the mock navigates to the new session terminal without crashing.

## Notes

- Wire through `RootCoordinator` for post-spawn navigation — do not hard-code
  tab indices.
- `FeatureDetail` Sessions sub-tab currently shows a stub button; replace it.
  Do not add a second stub for the new scope — replace in one pass.
- Verify that the Sessions tab list refreshes after a successful spawn (the
  new session should appear without requiring a manual pull-to-refresh).
