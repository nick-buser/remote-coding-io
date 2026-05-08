# service-0034: Switch terminal buffer renderer to Runestone

Ticket: `.tickets/done/service-terminal-runestone.md`

## Summary

Swaps the terminal buffer from a plain `Text(attributedString)` to a
`RunestoneTerminalBuffer` (`UIViewRepresentable` wrapping `RunestoneScrollContainer`
with Runestone's `TextView`) with sticky-bottom auto-scroll.

## Changes

- `Features/Terminal/TerminalView.swift` — replaces `Text(renderedBuffer)` with
  `RunestoneTerminalBuffer`. `RunestoneTerminalBuffer: UIViewRepresentable` wraps
  `RunestoneScrollContainer`. `RunestoneScrollContainer: UIView` holds a
  `Runestone.TextView`, implements `isAtBottom` (content offset within 20pt of
  end), and `scrollToBottom(animated:)`. `updateUIView` checks `isAtBottom`
  before applying new state, then auto-scrolls only if user was at the bottom.
  `setState(TextViewState(text:))` called only when content differs.
- `remote-codingTests/RunestoneIntegrationTests.swift` — buffer loads, rendered
  content matches `output`, append preserves consistency.

## Decisions

- **Sticky-bottom via 20pt threshold** — `isAtBottom` returns true when
  `contentOffset.y + frameHeight >= contentHeight - 20`, which handles sub-pixel
  rounding without false positives.
- **`TextViewState(text:)` with no language** — disables syntax highlighting.
  The `PaneTextRenderer` handles all colouring; Runestone is the rendering
  surface only.
- **`RunestoneScrollContainer` owns the scroll logic** — keeps the
  `UIViewRepresentable` coordinator free of complex state.

## Notes

- PR #42, targeting `phase4/07-runestone-pkg`. Final PR in the Phase 4 stack.
- ANSI colour overlays will layer on top when `ANSIPaneTextRenderer` lands in
  Phase 5 (`service-ansi-parser.md`).
