# infra-0003: Build shared UI component kit — primitives every screen reuses

Ticket: `.tickets/done/infra-component-kit.md`

## Summary

Landed the shared UI primitives the v2 zen design composes from, under
`remote-coding/Core/Components/`. Every Phase 3 screen now has a named
component for `Pip`, `RoundedCard`, `MetaPill`, `PillButton`,
`SegmentedControl`, `ScrollChips` / `Chip`, `BackChevron`,
`NavIconButton`, `Chevron`, `EmptyState`, `ProgressBar`, `QuietHeader`,
`LargeTitleHeader`, `KindIcon` / `KindDot`, `StatusGlyph`, and
`AccentSwatchPicker`. Without this, each screen ticket would have
re-derived its own button shapes / segment chrome / status glyphs from
the JSX source — drifting from the design and from each other. With
this, screens are mostly composition over parameters.

The components are layered against the `Core/Theme/` tokens infra-0002
landed: surfaces / text / accents / spacing / radius / typography.
None of the components paint their own large-area background — they
compose inside the parent's surface — so a row that places a
`RoundedCard` over `Theme.Surface.bg(scheme)` looks right in both light
and dark with no overrides.

## Changes

- Four feature commits land the components in tranches:
  1. Primitives — `Pip`, `RoundedCard`, `MetaPill`, `Chevron`,
     `ProgressBar`.
  2. Status / icon / chip — `StatusGlyph` (+ `StatusGlyphRole`),
     `KindIcon` / `KindDot` (+ `ActivityKind`), `Chip` / `ScrollChips`,
     `AccentSwatchPicker`.
  3. Buttons / segments / headers — `PillButton`, `SegmentedControl`,
     `BackChevron`, `NavIconButton`, `EmptyState`, `QuietHeader`,
     `LargeTitleHeader`. Headers live under `Components/Header/`.
  4. Render-smoke tests — `ComponentRenderTests.swift` covers `Pip`,
     `StatusGlyph`, `MetaPill`, `Chip`, `SegmentedControl`, `KindIcon`
     via `ImageRenderer` bitmaps with size + colour assertions.
- Each component ships with at least one `#Preview` covering its
  variants in light and dark.
- The lead `chore(infra-0003)` commit moves
  `.tickets/infra-design-tokens.md` to `.tickets/done/`, adds
  `.workhistory/infra-0002.md`, and promotes
  `.tickets/infra-component-kit.md` to `status: active` — the same
  bundle pattern infra-0002 used for infra-0001.

## Decisions

- **`StatusGlyphRole` enum, not direct generated enums.** Both
  `TicketStatus` and `FeatureStatus` map into a single visual role so
  the component layer doesn't depend on `Components.Schemas.*`. Each
  caller adapts its own status into the role at the boundary. Keeps
  Rule #5 in `CLAUDE.md` (views shouldn't import generated types) honest
  for the component kit even though screens still leak it elsewhere.
- **`ActivityKind` mirrors the OpenAPI `kind` field but lives in the
  visual layer.** Same reason as `StatusGlyphRole` — `KindIcon` /
  `KindDot` should not pull `Components.Schemas.ActivityEvent` into
  their import surface, especially because the activity feed will be
  built mock-first before the live repository exists.
- **Plain SwiftUI `SegmentedControl`, not `Picker(.segmented)`.** The
  design's track tint and active-pill 6%-shadow recipe can't be
  expressed through the Picker style. Custom impl uses
  `Theme.Radius.r2` (9pt) which matches the design's 7-9pt range.
- **`EmptyState` parameter is named `message`, not `body`.** `body` is
  the View protocol requirement — shadowing it confused autocomplete
  in adopters. One-character readability win, costs nothing.
- **Render-smoke tests over snapshot tests for now.** True
  `swift-snapshot-testing` golden-image diffing needs a new SPM
  dependency. The `ImageRenderer` bitmap approach catches the
  regressions that bite hardest — view tree failing to build, accent
  map silently flipping, status role losing its semantic colour —
  without committing to a new dependency. A future visual-regression
  ticket can swap in real golden images; `ImageRenderer` already
  produces the bitmap, only persistence is missing.
- **Headers live in `Components/Header/`, not flat in `Components/`.**
  Two of them (`QuietHeader`, `LargeTitleHeader`) plus future variants
  cluster naturally. Keeps the top of `Components/` from filling with
  chrome before the product surfaces.
- **`PillButton` reads `accent` from `@Environment` when not provided.**
  Feature-scoped buttons inherit the project / feature accent without
  prop-drilling. The explicit-arg form stays for cases where the button
  needs to override (destructive actions, system flows).
- **`NavIconButton` `tinted` defaults vary by name.** The design uses
  accent colour for `plus` / `compose` and `fg` for `filter` /
  `search` / `dots`. Captured as a per-name default rather than forcing
  every adopter to remember which is which.

## Notes

- The `IOSGlassPill` "liquid glass" recipe (`backdrop-filter: blur(12px)
  saturate(180%)` plus inset shines in the JSX) is *not* a standalone
  component. The design only uses it inside the iOS frame chrome —
  `LargeTitleHeader` / `QuietHeader` will adopt it when those headers
  ship in their final iOS chrome form. Don't add a generic
  `GlassPill.swift`; it would invite unrelated callers.
- `ActivityKind` was added speculatively to keep `KindIcon` /
  `KindDot` independent of generated types. The Inbox screen ticket
  will be the first real adopter — if its needs diverge, the right
  move is to widen `ActivityKind` rather than re-introduce a direct
  schema import.
- `ComponentRenderTests` uses `@MainActor` + `ImageRenderer` and runs
  in the existing `remote-codingTests` target. The tests only run on
  iOS simulators (the renderer is iOS / macOS); CI is the iPhone 17
  destination from `/ios-gates`. If a future Linux CI lane is added,
  these tests need a `#if canImport(UIKit)` guard.
- Existing prototype views were left alone per the ticket's explicit
  carve-out. Phase 3 screen tickets will swap them to compose against
  the component kit. Don't refactor them ahead of those tickets — it
  would conflict with the screen rewrites already scoped.
- The `fg`, `fg2`, `fg3` typography hooks the components reach for
  come from `Theme.Text.*(scheme)`. If a component reads colour
  literals instead, that's a sign the theme boundary leaked.

## Follow-ups

- Phase 0 closes with `docs-update-agents-shell` (this branch's
  successor on `docs-0005`) — reflects the 5-tab shell and the
  terminal-as-drill-down change in `AGENTS.md` and `ios_apps/CLAUDE.md`
  before screen tickets begin.
- After Phase 0, the repository tickets (`service-repo-tickets` /
  `-docs` / `-decisions` / `-activity` / `-agent-sessions` / `-review`)
  and the tab shell tickets (`service-tab-shell` /
  `-app-route-coordinator`) can run in parallel.
- A future ticket can add `swift-snapshot-testing` and convert the
  render-smoke tests to true golden-image diffs. Not urgent — the
  current tests already catch the regressions that matter.
