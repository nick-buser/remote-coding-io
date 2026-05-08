# service-0023: Feature detail Decisions sub-tab — append-only log

Ticket: `.tickets/done/service-feature-decisions-tab.md`

## Summary

Replaces the Decisions-sub-tab `EmptyState` stub (landed in
service-0016) with `FeatureDecisionsTab`: an append-only list
(newest-first), a `+ Log decision` footer button that opens a
small create sheet, and a long-press `Remove (typo)` destructive
action gated behind a confirmation dialog.

Decisions render as quiet prose — no `RoundedCard` wrapper. The
trailing actor chip is iris-tinted for `.agent`, neutral for
`.human`, matching the dense version of the v2 design.

## Changes

- `Features/FeatureDetail/Tabs/FeatureDecisionsTab.swift` — sub-tab
  body. Sorts the view model's decisions newest-first, renders
  each as a `DecisionRow`, and exposes a `confirmationDialog`
  for the delete path so accidental long-press doesn't drop a
  decision.
- Same file: `DecisionRow` — timestamp + title + body + actor
  chip composition. Wraps the actor chip styling so the agent /
  human distinction stays in one place.
- Same file: `LogDecisionSheet` — modal form (Title required,
  Body, Actor segmented, Actor name optional). Pre-fills
  `actorName` with the user's `displayName` from
  `UserPreferences` when actor is human and the field is empty.
  Submits via `repository.createFeatureDecision(featureID:body:)`
  and prepends the result.
- `Features/FeatureDetail/FeatureDetailView.swift` — replaces
  `decisionsSummary` with `decisionsBody: FeatureDecisionsTab(...)`.
- `remote-codingTests/FeatureDecisionsTabTests.swift` — Swift
  `Testing` cases for newest-first sort, create-prepend
  behavior, whitespace trimming on title, delete removal, and
  actor enum coverage.

## Decisions

- **Append-only by design; `Remove` is for typos only.** The
  destructive action is hidden behind context-menu / long-press
  *and* a confirmation dialog. Both gates match the ticket note's
  "intentionally append-only" stance.
- **Actor name pre-fill from `UserPreferences.displayName`.**
  When the user picks Human, the form fills the actor name with
  their preferred display name unless they've already typed
  something. Saves a tap on the common case.
- **`DecisionRow` lives next to the tab.** It's narrow-purpose
  (no chevron, no nav target, no parent scoping) and the row's
  visual is intentionally quieter than every other list-row in
  the app. Promoting to `Core/Components/` would require either
  bloating the row or splitting into another variant.
- **Body is rendered in the system font, not mono.** Per the
  ticket note — decisions are prose, not commands.

## Notes

- Branched from `service-0022` (still open) to keep
  `FeatureDetailView.swift` from conflicting between parallel
  sub-tab PRs. Base will retarget to `main` once #28 / #29 land.
- The `confirmationDialog`'s `presenting:` form pins the
  destructive copy to the decision's title so the user knows
  exactly what's about to drop.
- iOS gates were not exercised in this session (Linux runner
  without Xcode); the suite needs to run on a Mac via the
  `ios-gates` skill before merge.
