# service-0043: Multi-scope spawn sheet

Ticket: `.tickets/done/service-spawn-sheet.md`

## Summary

Builds `SpawnSheet` — a modal sheet that lets the user choose a scope
(Ticket / Feature / Project), fill in cascading pickers, and fire
`createAgentSession`. `SpawnSheetViewModel` owns all state and async
operations; the view is a thin shell.

## Changes

- **New** `Features/Spawn/SpawnSheetViewModel.swift`:
  - `SpawnEntry` enum: `.sessionsTab`, `.project(Project)`,
    `.feature(Feature, Project)`. Entry determines pre-fills and which
    scopes are available in the picker.
  - `SpawnScope` enum: `.ticket`, `.feature`, `.project`.
  - `init(entry:repository:coordinator:)` — configures locked fields,
    initial scope, and available scopes from the entry.
  - `isSpawnEnabled` — computed: `selectedProject != nil` for project
    scope; also needs feature / ticket for narrower scopes.
  - `sessionNamePreview` — derived from current selection; shows greyed
    monospace preview in the sheet footer.
  - `loadInitial()` — loads only the needed level (projects for
    sessionsTab; features if project locked; tickets if both locked).
  - `onProjectSelected`, `onFeatureSelected`, `onScopeChanged` — each
    clears downstream selections and reloads the next level.
  - `loadTickets()` — loads non-done tickets for the selected feature.
  - `createInlineTicket()` — creates a ticket with title + estimate from
    the inline mini-form and pre-selects it.
  - `spawn()` — builds `CreateAgentSessionRequest` for the current scope,
    calls repository, pushes `.agentSession(sessionID:)` on success.
  - Optional `preselectedTicket` for TicketDetailView use case (scope
    locked to `.ticket`, ticket not changeable).

- **New** `Features/Spawn/SpawnSheet.swift`:
  - `Form`-based sheet with `NavigationStack` wrapper.
  - Scope `Picker` (segmented) hidden when only one scope available.
  - Project row: locked label or inline `Picker` list.
  - Feature row: hidden for project scope; locked label or `Picker`.
  - Ticket row: hidden unless scope = `.ticket`; preselected ticket shows
    as label; otherwise `Picker` list + "New ticket…" inline mini-form
    row that creates a ticket and pre-selects it.
  - Footer preview of the derived session name.
  - Error displayed in a `Form` section without dismissing the sheet.
  - `.presentationDetents([.large])`.

- **New** `remote-codingTests/SpawnSheetViewModelTests.swift` — 9 tests:
  - Scope change clears ticket/downstream selection.
  - Feature selection clears ticket selection.
  - `isSpawnEnabled` for each scope with and without prerequisites.
  - Successful spawn triggers coordinator navigation.
  - Failed spawn shows error without navigating.
  - Uses isolated `UserDefaults` suite for coordinator.
  - Private `SpawnFailingRepository` for failure tests.

## Decisions

- **`SpawnSheetViewModel` drives navigation directly** via the injected
  `RootCoordinator`. The view calls `dismiss()` after `spawn()` returns
  with no error; the coordinator already pushed the session route.
- **Ticket scope locked to not showing ended tickets.** `loadTickets`
  filters `.done` tickets out; `.review` and `.doing` are included since
  spawning a session on a review-stage ticket is valid.
- **No `tmux_session` override field** exposed in the UI (power-user
  feature; the API contract has it but the ticket explicitly deferred it).
- **`preselectedTicket`** handles the TicketDetailView use case without
  adding a fourth `SpawnEntry` case, keeping the enum to three variants
  matching the spec.

## Notes

- Stacked on `phase7/03-spawn-mock`.
- The existing `SpawnSessionSheet` in `FeatureSessionsTab.swift` is
  replaced in `service-spawn-wiring`.
- No xcodebuild on this host — CI validates the build.
