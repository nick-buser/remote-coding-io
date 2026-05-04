---
prefix: service
title: ANSI color/style parser plugged into PaneTextRenderer
status: todo
branch:
---

## Description

Add `ANSIPaneTextRenderer` that parses SGR escape sequences inside pane content and produces a styled `AttributedString`. Plug it in as the default renderer for the terminal. Output keeps unknown escapes silent (drop them rather than render them as text).

Depends on `service-terminal-renderer-boundary.md`. See `docs/feature_plans/40-terminal.md`.

## Acceptance criteria

- [ ] `Core/Components/Terminal/ANSIPaneTextRenderer.swift` implements `PaneTextRenderer`.
- [ ] Supported sequences:
  - `\x1b[0m` reset.
  - `\x1b[1m` / `\x1b[22m` bold on/off.
  - `\x1b[2m` / `\x1b[22m` dim on/off.
  - `\x1b[3m` / `\x1b[23m` italic on/off.
  - `\x1b[4m` / `\x1b[24m` underline on/off.
  - `\x1b[7m` / `\x1b[27m` reverse on/off.
  - 8-color foreground `30..37` and bright `90..97`.
  - 8-color background `40..47` and bright `100..107`.
  - 256-color `38;5;N` and `48;5;N` (palette resolved to 24-bit).
  - 24-bit color `38;2;R;G;B` and `48;2;R;G;B`.
  - Multi-attribute sequences `\x1b[1;31m` etc.
- [ ] Unknown / malformed escapes are dropped silently (never rendered as text).
- [ ] Color palette: standard 16 colors mapped to a perceptually balanced palette (avoid pure red/green — use the same palette as macOS Terminal "Pro" or similar).
- [ ] `ANSIPaneTextRenderer` is the default for the terminal screen. The DI parameter still allows swapping in `PlainPaneTextRenderer` for tests.
- [ ] Unit tests: fixture inputs (bold, color, mixed) produce expected `AttributedString` runs.
- [ ] Snapshot test: render a `git log --color=always` style buffer and verify the styled output.

## Notes

- ANSI parsing happens at `render(_:)` time — no incremental state needed across calls because the contract sends full pane content each message. Reset SGR state at the start of every `render` call.
- Reverse video: swap fg/bg attributes for the affected run.
- 256-color palette: 0–15 are the 16 base colors; 16–231 are a 6×6×6 RGB cube; 232–255 are a 24-step grayscale ramp. Implement as a lookup table.
- Don't try to render OSC sequences (e.g., `\x1b]0;title\a`); strip them.
- Performance: avoid `Range<String.Index>` per character — walk the string once, build an array of `(range, attributes)` pairs, then build the `AttributedString` in one pass.
