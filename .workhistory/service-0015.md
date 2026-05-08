# service-0015: Project detail — hero, 4-up stats, segmented sections

Ticket: `.tickets/done/service-project-detail.md`

## Summary

Rewrites `ProjectDetailView` to the v2 hybrid layout: `QuietHeader`
top bar, large hero (project name + tagline), 4-up stats strip
(`Active`, `Open`, `Live`, `Total`) in a `RoundedCard`, and a
`SegmentedControl` switching between Features / Tickets / Docs /
Sessions sub-bodies. The Features body groups by status into
"In progress / In review / Planned / Shipped" sections; Tickets,
Docs, and Sessions render flat lists scoped to the project.

`FeatureRow`, `TicketRow`, `DocRow`, and `SessionRow` are introduced
as standalone visuals under `Features/Projects/Detail/` so the
Feature detail screens (service-0016+) can reuse them.

## Changes

- `Features/Projects/ProjectDetailView.swift` — rewritten end-to-end.
  Replaces the legacy `List` + `Picker` shape with the v2
  composition. Bookmarks the existing `ProjectDetailDestination`
  wrapper (`ContentView.swift:132-161`), which still resolves the
  project asynchronously and hands the value to this view.
- `Features/Projects/ProjectDetailViewModel.swift` — `@Observable
  @MainActor`. Owns project + features + per-feature ticket / doc
  maps + project-scoped agent sessions, plus a `Stats` rollup
  derived in a computed property. Sequential per-feature fan-out
  (mirrors `ProjectListViewModel`'s loader); `service-0017` will
  collapse this onto `CrossProjectFeatureFetcher`.
- `Features/Projects/Detail/FeatureRow.swift` — status glyph + mono
  meta row + 60pt `ProgressBar` + criteria pill + live-session dot.
  Adds `FeatureStatusStyle` (FeatureStatus → StatusGlyphRole +
  label) for reuse.
- `Features/Projects/Detail/TicketRow.swift` — status glyph + mono
  public-id + criteria pill. Ships with `TicketStatusStyle` shared
  with the future Review screen (service-0019).
- `Features/Projects/Detail/DocRow.swift` — kind glyph + label +
  word count + parent feature label.
- `Features/Projects/Detail/SessionRow.swift` — state dot + state
  label + uptime + tmux session name (mono, middle-truncated).
- `remote-codingTests/ProjectDetailViewModelTests.swift` — Swift
  `Testing` cases for stats math, section grouping, mock-backed
  load, and the status / section enum mappings.

## Decisions

- **Sequential per-feature fan-out** over `withTaskGroup`. Same
  reasoning as service-0014 — the Sendable-existential isolation
  tax isn't worth the small N. service-0017's
  `CrossProjectFeatureFetcher` will be the unified replacement.
- **Status glyph mapping kept per-domain.** `FeatureStatusStyle`
  and `TicketStatusStyle` both produce `StatusGlyphRole` but live
  next to their respective rows. A shared `Domain → StatusGlyph`
  table is premature with only two domains.
- **Sub-tab body switching via raw-`String` segmented control.**
  Matches the existing `SegmentedControl(items:[String], selection:
  Binding<String>)` API. The view uses a typed
  `ProjectDetailSection` enum locally and rounds-trips through
  `rawValue` so the binding stays simple.
- **Doc / agent-session detail destinations unwired.** Tap on a
  doc pushes `.docDetail(docID:)` (current `RoutePlaceholder`); tap
  on an agent session pushes `.agentSession(sessionID:)` (legacy
  prototype). Both placeholders go away when their respective
  Phase 3 / Phase 4 tickets land.
- **Legacy `LocalProjectNote` / `DocumentEditorView` path dropped
  from this view.** The note files stay on disk untouched (they're
  unreferenced now); a cleanup commit can remove them once the
  feature-detail PRD tab lands and confirms `Doc` covers the
  surface.

## Notes

- The dots-menu trailing icon on the top bar is a stub. Project
  Edit / Pin / Open in tmux / Delete actions land in
  `service-projects-edit.md` and the terminal phase.
- The stats-strip `Live` cell uses
  `Theme.Semantic.green` when > 0 — matches the design's "live"
  visual emphasis.
- iOS gates were not exercised in this session (Linux runner
  without Xcode); the suite needs to run on a Mac via the
  `ios-gates` skill before merge.
- service-0015 was branched from `service-0014` (still open) to
  avoid `ContentView.swift` conflicts when Phase 3 PRs sit in
  parallel. The PR's base is `service-0014`; once 0014 lands the
  base will be retargeted to `main`.
