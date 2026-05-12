---
prefix: service
title: Multi-scope spawn sheet
status: todo
branch:
---

## Description

Build `SpawnSheet` — a modal sheet that lets the user choose a scope
(ticket / feature / project), fill in cascading pickers, and fire
`createAgentSession`. The same sheet is used from all four entry points;
the `SpawnEntry` enum determines what is pre-filled.

Depends on `service-spawn-mock.md`. See `docs/feature_plans/70-spawn-ux.md`
for the full layout spec.

## Acceptance criteria

- [ ] `SpawnEntry` enum defined:
  ```swift
  enum SpawnEntry {
      case sessionsTab
      case project(Components.Schemas.Project)
      case feature(Components.Schemas.Feature, Components.Schemas.Project)
  }
  ```
  A ticket-entry is represented by passing the ticket into the sheet separately (the ticket's feature and project are resolved from the entry).
- [ ] Scope selector (segmented control or chip row): Ticket · Feature · Project. Hidden / locked when the entry already implies a scope (e.g. `sessionsTab` entry shows the selector; `feature` entry locks scope to Feature or Ticket).
- [ ] Project row: label (non-interactive) when pre-filled; picker list of all projects when not.
- [ ] Feature row: visible when scope ≠ Project. Label when pre-filled; picker of the selected project's features when not.
- [ ] Ticket row: visible when scope = Ticket. Picker of the selected feature's open tickets. Includes a "New ticket…" option that reveals an inline mini-form (title + estimate fields only); creating it calls `createTicket` and pre-selects the result.
- [ ] Session name preview in the sheet footer: derived from the current scope selection, greyed-out monospace text. Not editable.
- [ ] Spawn button: accent colour, disabled until scope is satisfied (project selected for project-scope; project+feature for feature-scope; project+feature+ticket for ticket-scope).
- [ ] On success: dismiss the sheet and push `AppRoute.agentSession(sessionID: created.id)` into the appropriate tab stack via `RootCoordinator`.
- [ ] On failure: show `ErrorBanner` inside the sheet without dismissing; user can correct and retry.
- [ ] `SpawnSheetViewModel` unit tests: scope change clears downstream selections; spawn disabled until prerequisites met; successful create triggers navigation; failure shows error and does not dismiss.

## Notes

- The tmux override field exists in the contract but do not expose it in this
  sheet — keep the spawn path fast. Power users can use the API directly.
- Inline ticket creation in the spawn sheet captures only title and estimate.
  Full ticket creation (description, branch, criteria) remains in
  `FeatureTicketsTab`'s create sheet.
- Do not make the sheet full-screen; use `.presentationDetents([.large])` so the
  user sees context behind it on iPad.
