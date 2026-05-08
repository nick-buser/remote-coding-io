# service-0032: Terminal input bar

Ticket: `.tickets/done/service-terminal-input.md`

## Summary

Adds the bottom input bar: mono text field, accent send button, long-press mode
picker, multi-line draft sheet, and empty-Enter behavior.

## Changes

- `Features/Terminal/TerminalInputBar.swift` (new) — `TerminalInputBar` SwiftUI
  view. `enum SendMode: sendAndEnter / sendOnly / enterOnly` (sticky per session).
  Empty text fires `.enterOnly` regardless of mode. Long-press send → `.contextMenu`
  mode picker. Long-press text field → `MultilineDraftSheet` (plain `TextEditor`
  until PR 8 swaps Runestone). `extractPromptHint(from:)` parses last line ending
  in `› > $ %` for placeholder.
- `Features/Terminal/TerminalView.swift` — replaces input bar placeholder with
  `TerminalInputBar`.
- `remote-codingTests/TerminalInputBarTests.swift` — send modes, `isSending`
  baseline, prompt hint parsing.

## Decisions

- **Empty text always sends Enter** regardless of sticky mode — agents frequently
  need a blank Enter to confirm defaults; forcing the user to switch mode would
  be friction.
- **No local echo** — buffer reflects server content on next snapshot/stream
  message; local echo would cause double-rendering.
- **Plain `TextEditor` for multi-line draft** until `service-terminal-runestone`
  lands; the sheet's primary action uses the same `sendInput` path.

## Notes

- PR #39, targeting `phase4/04-quick-keys`.
