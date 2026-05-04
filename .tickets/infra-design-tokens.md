---
prefix: infra
title: Add Theme module — colors, typography, spacing, radius, accents
status: todo
branch:
---

## Description

The v2 design needs a small set of consistent tokens. Add a `Theme/` module under `remote-coding/Core/Theme/` with the colors, typography, spacing, radii, and accent system the design specifies. Every later screen ticket references these constants instead of hard-coding values.

See `docs/feature_plans/10-design-system.md` for the full token list. Concrete values are lifted from `claude_design_references/.../ios-screens-zen.jsx` and `styles.css`.

## Acceptance criteria

- [ ] `Core/Theme/Surface.swift` exposes light + dark surface tokens: `bg`, `card`, `sep`, `chip`, `tabBg`, `tabBd`, `homeBar`, `terminalBg`, `terminalChrome`, `terminalInput`. Each is reachable as `Theme.Surface.bg(scheme)` (or similar) and resolves through `ColorScheme`.
- [ ] `Core/Theme/Text.swift` exposes `fg(scheme)`, `fg2(scheme)`, `fg3(scheme)` matching the design's three text levels in light + dark.
- [ ] `Core/Theme/Accent.swift` defines an `enum AccentColor` with cases `iris`, `amber`, `mint`, `rose`, `slate`, plus a `value(for: ColorScheme)` returning the oklch values from the design (light + dark variants per accent).
- [ ] `Core/Theme/Semantic.swift` defines `green`, `orange`, `red`, `yellow` constants with the values from the design (e.g., `green = Color(red: 52/255, green: 199/255, blue: 89/255)`).
- [ ] `Core/Theme/Typography.swift` provides view modifiers `.themeTitle()`, `.themeDisplayLarge()`, `.themeDisplayMedium()`, `.themeBody()`, `.themeCaption()`, `.themeMono(_ size: CGFloat)`, `.themeMonoSm()` matching the design type scale.
- [ ] `Core/Theme/Spacing.swift` exposes named constants `s1...s6` matching the spacing scale in the design plan.
- [ ] `Core/Theme/Radius.swift` exposes named constants `r1...r8` matching the radius scale in the design plan.
- [ ] `Core/Theme/Theme.swift` re-exports the above as `Theme.Surface.bg`, `Theme.Accent.iris`, `Theme.Spacing.s4`, `Theme.Radius.r5`, etc. so any view can `import` once.
- [ ] An `EnvironmentValues` extension exposes the current accent: `@Environment(\.accent)` returns an `AccentColor`. Set by the root coordinator from the user's stored preference (default `.iris`).
- [ ] A unit test verifies the accent's oklch hex conversion produces a non-nil `Color` for every case in both `ColorScheme` modes.
- [ ] No view in the existing app hard-codes a hex color or font size — search-and-replace shows only `Theme.*` references in views (existing prototype views OK to leave untouched until they're rewritten in screen tickets).
- [ ] Project builds and existing previews render.

## Notes

- SwiftUI's native `Color` does not accept oklch directly. Either convert oklch → sRGB at compile time (preferred — produces `Color(red:green:blue:opacity:)` literals) or include a tiny oklch→sRGB helper. Reference: oklch is L(0–1) C(0–~0.4) H(0–360); convert through OKLab and Lab→linear sRGB → gamma encode.
- Embedding JetBrains Mono is optional. SF Mono is acceptable; the typography modifier should fall back gracefully via `Font.system(.body, design: .monospaced)`.
- The design tokens include `chip` at `rgba(120,120,128,0.12)` light / `rgba(120,120,128,0.22)` dark. SwiftUI's `Color.gray.opacity(0.12)` is a reasonable approximation but will drift slightly with the system gray palette — use a literal sRGB color to match exactly.
- `Theme.Surface.tabBg` includes a backdrop blur. SwiftUI doesn't expose backdrop filters directly — pair the color with `.background(.thinMaterial)` or `.background(.regularMaterial)` in the tab bar component, layered with a tint.
- Do not introduce a `Color.Scheme` default. Force every API to take an explicit `ColorScheme` so views can opt out (terminal is always dark even when the system is light).
