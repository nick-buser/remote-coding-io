# infra-0002: Add Core/Theme module — surfaces, accents, type scale

Ticket: `.tickets/done/infra-design-tokens.md`

## Summary

Landed the v2 design tokens under `remote-coding/Core/Theme/` so every later
screen ticket can compose against named constants instead of hex literals.
Without this, each Phase 3 screen would have re-derived its own colors and
spacing from the JSX source — drifting from the design and from each other —
and the `infra-component-kit` follow-on (this branch's PR) would have nothing
to compose against.

The shape mirrors the design's `T = { light, dark }` table: every accessor
takes an explicit `ColorScheme` so the terminal screen — which is *always*
dark, even when the system is light — can pass `.dark` explicitly without
fighting the environment.

## Changes

- New `Core/Theme/` module with one file per token family:
  `Theme.swift` (namespace + `Theme.srgb(_:_:_:opacity:)`),
  `Surface.swift` (bg / card / sep / chip / tabBg / tabBd / homeBar +
  always-dark `terminalBg` / `terminalChrome` / `terminalInput`),
  `Text.swift` (fg / fg2 / fg3),
  `Accent.swift` (`AccentColor` enum + oklch → sRGB conversion +
  `@Environment(\.accent)` key),
  `Semantic.swift` (green / orange / red / yellow constants),
  `Spacing.swift` (s1–s6),
  `Radius.swift` (r1–r8),
  `Typography.swift` (`.themeTitle()` / `.themeDisplayLarge()` /
  `.themeDisplayMedium()` / `.themeBody()` / `.themeCaption()` /
  `.themeMono(_:)` / `.themeMonoSm()`).
- `AppModel` carries the active `accent`; `remote_codingApp` injects it
  via `.environment(\.accent, ...)` at the root so any view can read the
  user's accent without prop-drilling.
- `AccentColorTests` exercises every accent in both schemes through the
  oklch conversion path: each yields an in-gamut sRGB triple, slate is
  identical across schemes, iris is recognisably purple.
- `docs/architecture-state.md` snapshot of as-built architecture for
  future-me / future-Claude — it dates the gaps (no service layer, no
  `AppContainer`, generated types leaking into views) so later tickets
  don't accidentally re-derive their plan from a stale `CLAUDE.md`.

## Decisions

- **Explicit `ColorScheme` parameters, no implicit defaults.** Surface and
  text accessors are functions, not computed properties on
  `EnvironmentValues`. The terminal needs to opt into dark in a
  light-mode app; baking the environment in would have forced an
  explicit override at every terminal call site instead of one place.
- **oklch is converted at runtime, not at compile time.** A constant table
  of pre-converted sRGB triples would be smaller and faster, but it
  would also disconnect the source-of-truth values from the design
  document. Runtime conversion through OKLab keeps the values in
  `Accent.swift` line-for-line with the design plan and lets a future
  display-P3 mode swap the encoder without touching the per-accent
  table. Conversion cost is negligible — five calls per screen at most.
- **Slate is neutral in both schemes.** The design spec explicitly says
  slate's dark variant matches its light variant. Encoded as a
  single-arm pattern (`case (.slate, _)`) so the rule reads at the
  switch instead of being a comment.
- **`@Environment(\.accent)` defaults to `.iris` and lives in
  `Accent.swift`.** Per-screen scoped accents (project / feature)
  override locally with `.environment(\.accent, project.accent)`. The
  default isn't a UX choice — it's a "must compile if no one set it"
  fallback. Stored persistence + the You-screen UI for changing the
  default land with `service-you-screen`.
- **Mono falls back to SF Mono via `.monospaced` design.** JetBrains
  Mono can be embedded later without changing call sites. Shipping the
  font binary now would commit the bundle to it before we know whether
  the design actually needs it on iOS.
- **Existing prototype views are left alone.** The ticket explicitly
  carved them out — they'll be rewritten by Phase 3 screen tickets, and
  refactoring them now would conflict with that work.

## Notes

- The Surface tab-bar tokens are *tints to layer over* a `.regularMaterial`
  background — SwiftUI doesn't expose `backdrop-filter`, so the tab bar
  component will need both: a system material for blur and the
  `tabBg(scheme)` color on top for hue. Worth noting because the value
  alone (`Color(opacity: 0.86)`) reads weak without the material under
  it.
- `architecture-state.md` flags one tension: views currently import
  `Components.Schemas.*` directly. Rule #5 in `CLAUDE.md` says they
  shouldn't. Phase 3 screens will widen this. Resolution belongs to the
  reviewers of `service-app-route-coordinator` or whichever ticket
  blinks first; no action in this branch.
- The `OKLCH.Triple` / `OKLCH.SRGB` types exist for tests, not callers —
  if you find them in screen code, that's a sign the conversion has
  leaked above the theme boundary.
- Future-you, when the design adds a sixth accent: the only place to
  touch is `AccentColor` (add the case) + `oklchTriple(for:)` (add the
  pattern). Tests will pick it up automatically because they iterate
  over `AccentColor.allCases`.
