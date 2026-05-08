# service-0016: Feature detail — hero, progress, segmented tabs (shell)

Ticket: `.tickets/done/service-feature-detail.md`

## Summary

Rewrites `FeatureDetailView` to the v2 dense-with-zen-typography
shell: `QuietHeader` top bar, hero (`Pip` + mono FEAT-### +
`StatusPill` + 28pt title + vision), single-line progress strip
(`<done> of <total> tickets · target_date` over a 2pt accent bar),
and a `SegmentedControl` toggling Tickets / PRD / Decisions /
Sessions sub-tab bodies. The Tickets sub-tab carries a footer with
`+ New ticket` and `Spawn session` `PillButton`s.

This ticket lands the **shell** only — the four sub-tab bodies stay
stubbed (`EmptyState` carrying the loaded count), since the actual
list / TipTap / append-only renderers ship under the
`service-feature-{tickets,prd,decisions,sessions}-tab` follow-ups.
The dots menu wires `Mark in progress / review / planned / shipped`
through `repository.updateFeatureStatus`.

## Changes

- `Core/Components/StatusPill.swift` — new tinted pill keyed on
  `StatusGlyphRole` (orange / iris / muted / green). Reused by
  `FeatureDetailView`'s hero today and by the future Review screen
  (`service-0019`).
- `Features/FeatureDetail/FeatureDetailView.swift` — rewritten
  end-to-end. Sets `\.accent` to the feature's accent so child
  buttons (`PillButton`, `BackChevron`) tint correctly without
  per-call accent passing. The dots menu uses SwiftUI's `Menu`
  for compact action wiring.
- `Features/FeatureDetail/FeatureDetailViewModel.swift` — owns
  `feature`, `tickets`, `docs`, `decisions`, `agentSessions`. Adds
  a `Progress` rollup (done / total / fraction), `publicLabel`,
  `statusRole`, `statusLabel`, and `accentColor` so the view stays
  thin. `load` refreshes the feature first then fans out across
  the four list endpoints with `async let` and filters
  project-scoped agent sessions down to the feature's tickets to
  avoid an N+1 lookup.
- `remote-codingTests/FeatureDetailViewModelTests.swift` — Swift
  `Testing` cases for `publicLabel`, status role / label / accent,
  load roundtrip, agent-session scoping, progress math, status
  mutation, and the section enum mapping.

## Decisions

- **Sub-tab bodies stay as `EmptyState` summaries.** Per the
  ticket scope, the Tickets / PRD / Decisions / Sessions bodies
  land in their own tickets. Each summary surface still pulls
  the count from the loaded data so the wire-up is verifiable
  end-to-end (an empty `EmptyState` would be a false positive).
- **`StatusPill` keyed on `StatusGlyphRole`, not status enums.**
  The same pill needs to render for both `FeatureStatus` and
  `TicketStatus`; mapping each domain into `StatusGlyphRole` (the
  shape `StatusGlyph` already uses) keeps the visual coupling in
  one place. `service-0019` reuses the same pill for the Review
  screen with `TicketStatusStyle.glyphRole(for:)` as the input.
- **Agent-session scoping derives from tickets.** The contract
  exposes `listTicketAgentSessions(ticketPublicID:)` but issuing
  one call per ticket is wasteful; instead the loader pulls the
  project-scoped list once and filters by `Set(tickets.map(\.id))`.
- **Edit feature menu action stubbed.** `service-feature-create`
  reuses its create sheet for edit; until that lands the menu
  item is `.disabled(true)` so the menu shape is honest.
- **Top bar uses `Menu` instead of `NavIconButton`.** The other
  screens use `NavIconButton(name: .dots)` with no menu — the
  feature detail's status quick-actions need a real menu.
  Inlined the styling so the ellipsis matches the other icons
  visually without expanding `NavIconButton`'s API.

## Notes

- Branched from `service-0015` (still open) to keep
  `ContentView.swift` from conflicting between parallel Phase 3
  PRs. The PR's base is `service-0015`; once 0014/0015 land the
  base will retarget to `main`. No `ContentView.swift` changes in
  this PR — the existing `FeatureDetailDestination` wrapper
  continues to handle the async resolve.
- `BackChevron(label:)` shows the parent project's name so the
  back affordance reads "← tmux server", matching the design.
- iOS gates were not exercised in this session (Linux runner
  without Xcode); the suite needs to run on a Mac via the
  `ios-gates` skill before merge.
