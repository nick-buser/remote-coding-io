---
prefix: infra
title: Build shared UI component kit — primitives every screen reuses
status: done
branch: infra-0003
---

## Description

Add the small set of reusable primitives the v2 design composes screens from. Each component is parameter-driven: it accepts `accent`, `colorScheme` (or reads them from the environment), and it never paints its own large-area background — it composes inside the parent's surface.

Depends on `infra-design-tokens.md`. Built before any screen ticket so screens compose primitives instead of re-deriving design values.

See `docs/feature_plans/10-design-system.md` for component inventory and visual specs.

## Acceptance criteria

- [x] `Core/Components/Pip.swift` — `Pip(accent:size:radius:)` view; renders a filled rounded square. Defaults: 8pt, r:3.
- [x] `Core/Components/StatusGlyph.swift` — `StatusGlyph(status:size:)`. Status maps:
  - `.shipped` / `.done` → solid green disc with white ✓.
  - `.review` → iris ring with iris-tinted fill (40% alpha).
  - `.doing` / `.inProgress` → orange ring with conic-gradient (60% sweep).
  - `.planned` → dashed muted ring.
  - `.todo` → solid muted ring, empty.
  Accepts both `TicketStatus` and `FeatureStatus` (use a small `StatusGlyphRole` enum to avoid coupling).
- [x] `Core/Components/RoundedCard.swift` — `RoundedCard(radius:padding:)`. Light: white bg, no border, 4% shadow. Dark: card bg, 0.5pt hairline.
- [x] `Core/Components/MetaPill.swift` — `MetaPill(icon: String?, iconColor: Color?, label: String)` inline label with optional leading dot.
- [x] `Core/Components/PillButton.swift` — `PillButton(role:accent:wide:action:)`. Roles: `.primary`, `.secondary`, `.ghost`. Wide grows in HStack.
- [x] `Core/Components/SegmentedControl.swift` — `SegmentedControl(items:selection:)` matching Apple-style chip-tinted track + white pill active item.
- [x] `Core/Components/ScrollChips.swift` and `Chip` — horizontal scrolling filter chip row. Per-chip: label, optional count (mono trailing), optional dot (accent leading), `active` state.
- [x] `Core/Components/BackChevron.swift` — `BackChevron(label:accent:)` for the leading slot of `QuietHeader`.
- [x] `Core/Components/NavIconButton.swift` — `NavIconButton(name:accent:tinted:)`. Names: `.plus`, `.search`, `.filter`, `.calendar`, `.dots`, `.share`, `.compose`. Tinted variant uses the accent.
- [x] `Core/Components/Chevron.swift` — trailing 7×12 disclosure indicator.
- [x] `Core/Components/EmptyState.swift` — `EmptyState(systemImage:title:body:)`. 72pt outlined circle + glyph, 22pt title, 14pt body, centered.
- [x] `Core/Components/ProgressBar.swift` — `ProgressBar(value:accent:height:)`; defaults to 4pt.
- [x] `Core/Components/Header/QuietHeader.swift` — replaces the design's `QuietHeader`: leading slot, centered label, trailing slot, large optional title, subtitle.
- [x] `Core/Components/Header/LargeTitleHeader.swift` — replaces the design's `NavHeader` for top-level tabs that show a 34pt large title.
- [x] `Core/Components/KindIcon.swift` and `KindDot.swift` — colored 32pt rounded square with kind glyph (Inbox rows) and 8pt rounded-2pt dot (activity feed).
- [x] `Core/Components/AccentSwatchPicker.swift` — five accent circles with selected ring; binds to a `@Binding<AccentColor>`.
- [x] Each component has at least one `#Preview` covering the variants in light and dark.
- [x] Snapshot tests (or rendered previews + golden images) for `Pip`, `StatusGlyph`, `MetaPill`, `Chip`, `SegmentedControl`, `KindIcon` ensure visual regressions are caught.
- [x] Project builds and the existing screens compile (they don't have to use the new components yet — the screen tickets will swap them in).

## Notes

- Build the components as `Equatable` value views where practical so SwiftUI can short-circuit redraws.
- `KindIcon` glyphs: `?` (question), `◐` (review), `↑` (commit), `◆` (decision), `✓` (test), `✎` (doc). The design uses these characters directly — they render fine in SF Pro Text 16pt weight 600 white.
- `NavIconButton` uses SF Symbols where possible (`plus`, `magnifyingglass`, `line.3.horizontal.decrease`, `calendar`, `ellipsis`, `square.and.arrow.up`, `square.and.pencil`). Match the design's stroke widths via `.symbolRenderingMode(.monochrome)` and `.imageScale(.medium)`.
- `RoundedCard` should expose its inner padding as a parameter — the design uses 12 / 16 / 18 / 20 / 22pt padding depending on context.
- `SegmentedControl` should be plain SwiftUI (don't use `Picker(.segmented)`) to match the design's specific track tint and active-pill shadow.
- The `IOSGlassPill` recipe (blur + shine) is captured in the iOS frame chrome — that lives inside `LargeTitleHeader` / `QuietHeader`, not as a standalone component, since it's only used inside the nav header.
- Keep components in `Core/Components/`. Avoid creating per-feature components in this ticket — those belong with their screens.
