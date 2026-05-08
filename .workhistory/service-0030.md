# service-0030: PaneTextRenderer boundary with plain monospace impl

Ticket: `.tickets/done/service-terminal-renderer-boundary.md`

## Summary

Introduces the `PaneTextRenderer` protocol and `PlainPaneTextRenderer` default
implementation, decoupling the terminal buffer view from raw string handling.
This boundary lets later tickets plug ANSI parsing and Runestone backing without
touching the view.

## Changes

- `Core/Components/Terminal/PaneTextRenderer.swift` (new) — defines:
  ```swift
  protocol PaneTextRenderer {
      func render(_ raw: String) -> AttributedString
      func append(_ chunk: String, to existing: AttributedString) -> AttributedString
  }
  struct PlainPaneTextRenderer: PaneTextRenderer
  ```
  `render` applies mono 13pt font; `append` concatenates the chunk rendering.
- `Features/Terminal/TerminalViewModel.swift` — `init(renderer: any PaneTextRenderer
  = PlainPaneTextRenderer())` for DI. `setBuffer(_:)` sets both `output` and
  `renderedBuffer = renderer.render(raw)`.
- `remote-codingTests/PaneTextRendererTests.swift` — 2-line render, empty string,
  append, DI injection via `FakePaneTextRenderer`.

## Decisions

- **Full-replacement semantics for now.** `append` is provided for future
  delta-streaming; the current WebSocket contract emits full content on every
  `PaneStreamMessage`, so `render` is the primary path.
- **`AttributedString` is Foundation's** — not a SwiftUI extension. View code
  consumes it via `Text(attributedString)` until Runestone lands.

## Notes

- PR #36, targeting `phase4/02-pane-switcher`.
