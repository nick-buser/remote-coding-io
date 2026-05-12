# service-0041: Ticket detail view

Ticket: `.tickets/done/service-ticket-detail.md`

## Summary

Rebuilds `TicketDetailView` as a fully editable ticket screen with
optimistic updates, a criteria checklist with add/delete, and a linked
agent-sessions section. Adds `TicketDetailViewModel` (observable) and
extracts `AcceptanceCriterionRow` to `Core/Components/`.

## Changes

- **New** `Features/FeatureDetail/TicketDetailViewModel.swift`:
  - `@MainActor @Observable` class; owns ticket, criteria, sessions state.
  - `load()` — parallel `listCriteria` + `listTicketAgentSessions`.
  - `commitTitle()` / `commitDescription()` — diff-guards, optimistic local
    mutate, rollback on failure.
  - `updateStatus(_:)` — optimistic status flip + rollback.
  - `toggleCriterion(id:)` — optimistic done flip + rollback.
  - `addCriterion(text:)` — trims, appends server response.
  - `deleteCriterion(id:)` — optimistic remove + full-list rollback.

- **Modified** `Features/FeatureDetail/TicketDetailView.swift` (full rewrite):
  - Editable title: `TextField` with `onChange(of: focus)` commit-on-blur.
  - Editable description: same pattern, multiline `TextField`.
  - Branch chip: copies to `UIPasteboard` on tap.
  - Hero: publicId chip + tappable `StatusPill` → `.sheet` status picker.
  - Criteria section: `ForEach` with `AcceptanceCriterionRow` + swipe-to-delete + `+ Add criterion` inline text field.
  - Sessions section: `SessionRow` list + "Spawn session" button (stub, wired in `service-spawn-wiring`).
  - Error banner: `overlay(alignment: .top)` with dismiss button; spring animation.
  - `TicketDetailRouter` unchanged logic, now constructs `TicketDetailViewModel`.

- **New** `Core/Components/AcceptanceCriterionRow.swift`:
  - Extracted from the old read-only `criterionRow(for:)` private function.
  - Now a reusable `Button` with configurable `onToggle` closure.

- **New** `remote-codingTests/TicketDetailViewModelTests.swift`:
  - 10 tests: loading (criteria + sessions), status optimistic + rollback,
    criteria toggle optimistic + rollback, add criterion (happy + no-op),
    delete criterion, commitTitle happy + no-op guard.
  - Private `FailingRepository` conforming to `TmuxAgentRepository` that
    throws `Boom()` on every mutable call — used for rollback tests.

## Decisions

- **`@State var viewModel`** on `TicketDetailView` (not `@StateObject`).
  `@Observable` + `@State` is the Swift 5.9 pattern; the outer
  `TicketDetailRouter` constructs the VM and SwiftUI owns the instance.
- **Optimistic-update pattern**: mutate local array / field first, call repo
  in background, replace or restore on failure. Matches `FeatureTicketsTab`.
- **Error banner via `overlay(alignment: .top)`** instead of an alert or
  toast so the rest of the view remains usable while the error is visible.
- **Spawn button is a stub** (`showSpawnSheet = true` with no sheet body)
  until `service-spawn-sheet` lands on the same branch chain.

## Notes

- No xcodebuild on this host — CI validates the build.
- `AcceptanceCriterionRow` is now in `Core/Components/` and can be reused
  by any future screen that shows acceptance criteria.
