# Design System

Date: 2026-05-04

The v2 design uses a small, deliberate visual system — quiet typography, monochrome surfaces, accent used sparingly, and iOS-native chrome (status bar, glass nav pills, grouped lists). This plan captures the tokens and shared components the app needs, with concrete values lifted from the design source.

## Philosophy

The Zen direction in `ios-screens-zen.jsx` opens with this comment:

> Principles: one headline per screen, defer secondary info behind taps, quiet typography, monochrome surfaces, accent used sparingly as a single guide.

The implication for SwiftUI:

- Reach for `Color(.systemBackground)` / `Color(.systemGroupedBackground)` / `Color(.label)` / `Color(.secondaryLabel)` first; only override with custom hex when the design demands it.
- Accent is **per project / per feature**, not a global app accent. The same screen can show three accents simultaneously when listing three differently-scoped objects. Build accent as a value parameter on every component, not a global modifier.
- One **headline per screen** — large display title at the top of a drill-down, with quiet structural type below. Avoid stacked H1/H2/subtitle decoration.
- Prefer borderless surfaces in light mode; in dark mode the cards earn a 0.5pt hairline. The design shows this directly: `border: mode === 'dark' ? '0.5px solid …' : 'none'`.

## Tokens

### Surfaces — light

| Token | Value | Usage |
|---|---|---|
| `bg` | `#F5F5F0` | Screen background (warmer than iOS systemGroupedBackground; intentional). |
| `card` | `#FFFFFF` | Hero cards, list cards, settings rows. |
| `sep` | `rgba(60,60,67,0.10)` | Horizontal hairlines between rows. |
| `chip` | `rgba(120,120,128,0.12)` | Filter chips, segmented control track. |
| `tabBg` | `rgba(245,245,240,0.86)` + `blur(40px) saturate(180%)` | Liquid-glass tab bar background. |
| `tabBd` | `rgba(60,60,67,0.14)` | Tab bar top hairline. |
| `homeBar` | `rgba(0,0,0,0.4)` | Home indicator. |

### Surfaces — dark

| Token | Value | Usage |
|---|---|---|
| `bg` | `#000000` | Screen background. |
| `card` | `#161617` | Cards. |
| `sep` | `rgba(255,255,255,0.07)` | Hairlines. |
| `chip` | `rgba(120,120,128,0.22)` | Chips. |
| `tabBg` | `rgba(20,20,22,0.78)` + `blur(40px) saturate(180%)` | Tab bar. |
| `tabBd` | `rgba(255,255,255,0.08)` | Tab bar hairline. |
| `homeBar` | `rgba(255,255,255,0.55)` | Home indicator. |
| `terminalBg` | `#000000` | Terminal screen body. |
| `terminalChrome` | `#1C1C1E` | Terminal input bar / context bar background. |
| `terminalInput` | `#2C2C2E` | Terminal input field. |

### Text

Light:
- `fg`: `#0A0A09`
- `fg2`: `rgba(60,60,67,0.62)` (secondary)
- `fg3`: `rgba(60,60,67,0.32)` (tertiary)

Dark:
- `fg`: `#F5F5F7`
- `fg2`: `rgba(235,235,245,0.6)`
- `fg3`: `rgba(235,235,245,0.28)`

### Accents

Five named accents. Each has a light and dark variant in oklch space. These are **values**, not states — the same accent appears identically across modes when used as fill on white or on cards; the variant just compensates contrast against the screen background.

| Accent | Light | Dark |
|---|---|---|
| `iris` | `oklch(58% 0.18 280)` | `oklch(72% 0.16 280)` |
| `amber` | `oklch(65% 0.16 60)` | `oklch(78% 0.15 60)` |
| `mint` | `oklch(60% 0.13 165)` | `oklch(74% 0.13 165)` |
| `rose` | `oklch(60% 0.18 15)` | `oklch(74% 0.17 15)` |
| `slate` | `oklch(58% 0.02 260)` | (matches light variant — neutral) |

Accent usage rules:
- Tab bar active icon + label → user's selected accent (from the You screen).
- Project pip / project mark / "live" status dot → that project's accent.
- Feature pip / feature accent stripe → that feature's accent.
- Inbox kind icons use semantic colors, not accents (see below).
- Buttons (primary CTA) → context-scoped accent. The Reply button on the Inbox card uses the project's accent; the Spawn-session button in Feature Detail uses the feature's accent.

### Semantic colors

These are constants, not accents — they communicate state.

| Role | Light | Dark | Usage |
|---|---|---|---|
| `green` | `#34C759` | `#34C759` | Active session dot, ✓ glyphs, "shipped" status, passing tests. |
| `orange` | `#FF9500` | `#FF9500` | Awaiting input, in-progress orbs, question icons. |
| `red` | `#FF3B30` | `#FF3B30` | Notifications badge (used in v1; v2 uses an accent dot — keep red for destructive confirms only). |
| `yellow` | `#FFCC00` | `#FFCC00` | Pinned star. |

### Typography

Three font families, all SF / system except the mono.

| Token | Stack | Usage |
|---|---|---|
| `display` | `-apple-system, "SF Pro Display", system-ui, sans-serif` | Large titles (34pt large title, 28pt feature title, 24pt counter, 22pt project name in detail). |
| `ui` | `-apple-system, "SF Pro Text", system-ui, sans-serif` | Body, list rows, captions. |
| `mono` | `"JetBrains Mono", "SF Mono", ui-monospace, Menlo, monospace` | IDs (TMX-0050, FEAT-018), branch names, terminal output, milestone IDs, "live" pill numbers. |

In SwiftUI: `.system(size: ..., design: .default)` for ui/display, `.system(size: ..., design: .monospaced)` for mono. Pull JetBrains Mono in as an embedded font if we want the exact look — fallback to SF Mono is acceptable.

### Type scale

From the design source (Inbox, ProjectDetail, FeatureDetail, etc.):

| Use | Size | Weight | Letter spacing |
|---|---|---|---|
| Large title (Inbox, Projects, Roadmap, Sessions, You) | 34 / 41 line | 700 | -0.4 |
| Project name in detail hero | 34 | 600 | -0.5 |
| Feature title in hero | 28 | 600 | -0.4 |
| Inbox hero quote / "One question waiting" | 22–24 | 500–600 | -0.3 |
| Section label ("Active features") | 12 uppercase | 500 | +1.2 |
| Body | 14–16 | 400–500 | 0 |
| List row title | 17 | 500 | -0.1 |
| List row sub | 13 | 400 | 0 |
| ID / monospace tag | 11–12 | 500 | 0 |
| "Now · ends May 26" eyebrow | 11 uppercase | 500 | +1.5 |

### Spacing and radius

The design is consistent enough to bake into a small token set:

| Token | Value | Usage |
|---|---|---|
| `s1` | 4 | Inline gaps between icon + label. |
| `s2` | 8 | Default row gap. |
| `s3` | 12 | Card padding (compact). |
| `s4` | 16 | Screen padding, card padding (default). |
| `s5` | 24 | Screen padding (zen — "give it room"). |
| `s6` | 32 | Hero block top padding. |
| `r1` | 6 | Pip, chip, mini button. |
| `r2` | 9 | Segmented control track / item. |
| `r3` | 12 | Inbox card inner buttons. |
| `r4` | 14 | Standard rounded card on feature detail / inbox. |
| `r5` | 18 | Sessions hero card. |
| `r6` | 22 | Inbox hero card. |
| `r7` | 26 | Grouped list container (matches `IOSList`). |
| `r8` | 44 | Phone screen interior corner. |

Avoid hard-coding these all over the codebase — put them in `Theme/Spacing.swift` and `Theme/Radius.swift` and reference `Theme.s4`, `Theme.r5` etc.

## iOS device chrome

The design renders inside an `IOSDevice` (390×844 in the zen variant; 402×874 in the original ios-frame.jsx). On a real device we get most of this for free, but the chrome we build ourselves needs:

- **Status bar** — system. We do not paint our own.
- **Dynamic island** — system.
- **Nav header** — `QuietHeader` (zen) or `NavHeader` (dense). Centered label, leading slot (back chevron or empty), trailing slot (icon button row). Large title where present (`Inbox`, `Projects`, `Roadmap`, `Sessions`, `You`).
- **Glass nav pills** — for ellipsis / dots menus, follow the recipe: `backdropFilter: blur(12px) saturate(180%)`, inset shines. Use `.background(.ultraThinMaterial, in: Capsule())` with a stroke for a close approximation; fall back to `.regularMaterial` if blur looks wrong on darker surfaces.
- **Bottom tab bar** — `TabBar2` recipe: 5 tabs, custom SVG icons, no badges (a single accent dot when work needs you). 22pt icon, 10pt label below, gap 4. 56pt min width per tab, 56pt total height.
- **Home indicator** — system handles this on real iOS; the design draws its own for the canvas. Don't reimplement.

## Component kit

Build these as small, parameterized SwiftUI views in `Core/Components/`. Each should accept a `mode: ColorScheme` and an `accent: AccentColor` parameter where the design varies by context. Hard-code nothing.

### `Pip(accent:size:radius:)`
Filled rounded square (default 8×8, r:3). Used as project / feature accent indicators.

### `StatusGlyph(status:size:)`
The little ringed-circle status indicator. Maps `TicketStatus` and `FeatureStatus` to:
- `done / shipped` → solid green disc with white ✓.
- `review` → iris ring with iris-tinted fill (40% alpha).
- `doing / in-progress` → orange ring with conic-gradient fill (60% sweep).
- `planned` → dashed muted ring.
- `todo` → solid muted ring, empty.

### `RoundedCard(radius:padding:)`
Background: `Theme.card`. Light mode: no border, optional 1pt 4% shadow. Dark mode: 0.5pt hairline at `Theme.sep`. Default radius 14.

### `MetaPill(icon:iconColor:label:)`
Inline label with optional small leading dot. Used in `ProjectRow` for "Active · 4 live · 3/5 features".

### `PillButton(role:accent:wide:)`
Roles: `primary`, `secondary`, `ghost`. Primary is filled with the accent (white text). Secondary has a 14% accent fill (accent-tinted text). Ghost is text-only. `wide:true` lets it grow inside an HStack.

### `ScrollChips([Chip])` and `Chip(label:active:count:dot:)`
Horizontal scrolling filter chip row. Active chip uses the accent. Counts are mono.

### `SegmentedControl(items:active:)`
Match Apple's UISegmentedControl styling — `chip`-tinted track, white pill for the active item, 7pt radius, 6pt vertical padding. Used on Project Detail (Features / Tickets / Docs / Sessions) and Feature Detail (Tickets / PRD / Decisions / Sessions).

### `BackChevron(label:accent:)`
Accent-colored ‹ + label. Used as the leading slot of `QuietHeader` everywhere except top-level tabs.

### `NavIconButton(name:accent:)`
22pt icon button — supports plus, search, filter, calendar, dots, share, compose. Two variants: tinted-accent (for plus/compose primary actions) and neutral (for filter/search/dots).

### `Chevron(mode:)`
Trailing 7×12 ›. Used as the disclosure indicator on every drill-down row.

### `EmptyState(icon:title:body:)`
Centered 72pt circle outline (`fg3` border) with a glyph, then 22pt fg title and 14pt fg2 body. Used for "All clear" inbox, "No features yet" milestones, etc.

### `ProgressBar(value:accent:height:)`
2pt or 4pt rule with a percentage fill. Used on FeatureRow and FeatureDetail progress card.

### `KindIcon(kind:size:)`
Inbox kind glyph in a colored 32pt rounded square (r:8):
- `question` → orange square, "?" (white).
- `review` → iris square, "◐".
- `commit` → green square, "↑".
- `decision` → mint square, "◆".
- `test` → muted square, "✓".
- `doc` → amber square, "✎".

### `KindDot(kind:)`
The same `kind` mapped to a 8pt rounded-2pt dot for the activity feed. Different visual; same color mapping.

### `RunestoneTextSurface`
Already exists as a stub (`Core/Components/RunestoneTextSurface.swift`). Once `infra-runestone-package` lands, finish the wrapper — accept `attributedText: AttributedString`, `isEditable: Bool`, `onCommit: ((String) -> Void)?`.

## Dark mode

The terminal is the only screen that's *always* dark. Other screens follow user preference (the `appearance` toggle on the You screen). The design supplies tokens for both. Build every component to take a `ColorScheme` (or read the environment) — do not hard-code light-mode hex.

The Zen design uses `T = { light: {...}, dark: {...} }` — keep that shape on the iOS side too, in `Theme/Surface.swift`.

## What this gives downstream tickets

- `Theme/Colors.swift` exports `Theme.bg(_:)`, `Theme.card(_:)`, `Theme.fg(_:)`, accent helpers.
- `Theme/Typography.swift` exports `Theme.title()`, `Theme.body()`, `Theme.mono(_:)` view modifiers.
- `Theme/Spacing.swift`, `Theme/Radius.swift` export named constants.
- `Core/Components/*` provides the ~12 named primitives above.
- Every screen ticket can compose primitives without re-deriving design values.
- A future "white-label / theme override" never has to chase hex codes through views.
