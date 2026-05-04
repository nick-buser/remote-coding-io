---
prefix: service
title: Switch terminal buffer renderer to Runestone
status: todo
branch:
---

## Description

Swap the terminal's buffer view from a plain `Text(attributedString)` to `RunestoneTextSurface` configured for the terminal use case. The renderer boundary (`PaneTextRenderer`) keeps the existing pluggable shape — Runestone is just the destination view.

Depends on `infra-runestone-package.md`, `service-terminal-renderer-boundary.md`, `service-terminal-websocket.md`. See `docs/feature_plans/40-terminal.md`.

## Acceptance criteria

- [ ] Terminal buffer uses `RunestoneTextSurface(attributedText:..., isEditable: false, theme: .terminalDark)`.
- [ ] Buffer preserves scroll position when new content arrives unless the user is at the bottom (sticky-bottom behavior).
- [ ] Selection is enabled. Long-press to select / copy works.
- [ ] Performance: 10k-line buffer renders without dropped frames on a recent iPhone (verify with the soak preview added in `infra-runestone-package.md`).
- [ ] The previous fallback `Text(attributedString)` path is removed.
- [ ] Tests: rendering a buffer + appending lines preserves user-selected range across update.
- [ ] `#Preview` renders the dark terminal with mock content via Runestone.

## Notes

- "Sticky-bottom": maintain a `userIsAtBottom` flag. When true, scroll to bottom on every update; when false (user scrolled up), keep position. Reset to true when the user scrolls back to the bottom.
- Avoid re-applying themes on every update — the theme is constant once mounted.
- Disable Runestone's syntax highlighting — terminal output isn't a known language. The `PaneTextRenderer` (with future ANSI parsing) handles all coloring.
