# service-0031: Terminal quick-keys row

Ticket: `.tickets/done/service-terminal-quick-keys.md`

## Summary

Adds the horizontal quick-keys row between the buffer and input bar. Each button
dispatches a `SendInputRequest` with the correct wire key. The row scrolls
horizontally; all primary and extra keys are in one continuous strip.

## Changes

- `Features/Terminal/QuickKeysRow.swift` (new) — `QuickKeysRow` SwiftUI view.
  Primary keys: esc→Escape, tab→Tab, ⌃C→C-c, ⌃D→C-d, ↑→Up, ↓→Down, ←→Left,
  →→Right, ⏎→Enter. Extra keys: ⌃Z, ⌃L, ⌃A, ⌃E, PgUp→PPage, PgDn→NPage, Home,
  End, ⌫→BSpace, ⇤→BTab. 32×32pt buttons with `rgba(255,255,255,0.08)` bg;
  0.1s scale+opacity tap feedback. Row uses `terminalChrome` bg with 0.5pt top
  hairline.
- `Features/Terminal/TerminalView.swift` — replaces quick-keys placeholder with
  `QuickKeysRow`.
- `remote-codingTests/QuickKeysRowTests.swift` — wire-key mapping verification,
  empty-Enter fires without input text, extra keys present.

## Decisions

- **Single scrolling row** (not a "More" chevron) for v1 — the row already
  scrolls, so extra keys simply extend it. Simpler than an action sheet toggle.
- **No gate on input bar focus** — keys fire regardless of whether the text
  field is active, matching the spec.

## Notes

- PR #37, targeting `phase4/03-renderer-boundary`.
