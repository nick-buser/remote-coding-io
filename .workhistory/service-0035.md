# service-0035: ANSI color/style parser plugged into PaneTextRenderer

Ticket: `.tickets/done/service-ansi-parser.md`

## Summary

Added `ANSIPaneTextRenderer` — a full SGR escape sequence parser that produces
styled `AttributedString` output and replaces `PlainPaneTextRenderer` as the
default for the terminal surface.

## Changes

- **New** `Core/Components/Terminal/ANSIPaneTextRenderer.swift`: single-pass
  scalar walker that collects styled runs and assembles `AttributedString` in
  one concatenation pass. Supports reset, bold/dim/italic/underline/reverse,
  8-color (30–37/40–47), bright (90–97/100–107), 256-color (38;5;N/48;5;N),
  and 24-bit true-color (38;2;R;G;B/48;2;R;G;B) SGR codes. OSC sequences and
  unknown escapes are stripped silently.
- **Updated** `Features/Terminal/TerminalViewModel.swift`: default renderer
  changed from `PlainPaneTextRenderer()` to `ANSIPaneTextRenderer()`.
- **Updated** `remote-codingTests/PaneTextRendererTests.swift`: added 18 ANSI
  test cases covering plain passthrough, color stripping, multi-attribute codes,
  OSC stripping, 256/truecolor foreground, bright colors, background, underline,
  dim, git-log style buffer, consecutive sequences, append, and palette sizes.

## Decisions

- **SGR state resets per `render(_:)` call**: the contract sends full pane
  content each tick, so there is no cross-call incremental state to maintain.
  Reset at the start of each call is implicit (fresh `SGRState()`).
- **16-color palette**: macOS Terminal "Pro"-style muted hues — avoids pure
  `(0,255,0)` green and `(255,0,0)` red; uses 0.647/0.6 levels instead.
- **Dim as opacity**: `Color.opacity(0.6)` on the foreground rather than a
  separate dim color avoids palette duplication and works correctly over both
  default and explicit foreground colors.
- **256-color built lazily**: `static let ansi256` is a closure that references
  `ansi16` for index 0–15, then computes the 6×6×6 cube and grayscale ramp.
  The lazy init order in Swift statics is well-defined so this is safe.

## Notes

- `ANSIPaneTextRenderer` is a `struct`, not a class, which is fine since
  `PaneTextRenderer` is a protocol with value semantics. The renderer carries
  no mutable state — all parsing state lives as local `var` inside `render`.
- `PlainPaneTextRenderer` remains available for test injection.
