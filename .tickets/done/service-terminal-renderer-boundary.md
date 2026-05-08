---
prefix: service
title: Introduce PaneTextRenderer boundary with plain monospace impl
status: todo
branch:
---

## Description

Create a small `PaneTextRenderer` protocol and a `PlainPaneTextRenderer` default implementation. The terminal buffer view consumes the renderer instead of `String`. This boundary lets later tickets plug ANSI parsing (`service-ansi-parser.md`), prompt block segmentation, and Runestone backing without touching the buffer view.

Depends on `service-terminal-shell.md`. See `docs/feature_plans/40-terminal.md`.

## Acceptance criteria

- [ ] `Core/Components/Terminal/PaneTextRenderer.swift` defines:
  ```swift
  protocol PaneTextRenderer {
      func render(_ raw: String) -> AttributedString
      func append(_ chunk: String, to existing: AttributedString) -> AttributedString
  }
  ```
- [ ] `PlainPaneTextRenderer` is the default implementation:
  - `render(_:)` returns `AttributedString(raw)` with mono font and `Theme.Text.fg(.dark)` color.
  - `append(_:to:)` concatenates the chunk's rendering onto the existing attributed string.
- [ ] Terminal buffer view consumes a `@State` `AttributedString` and calls `renderer.render(initialContent)` on load. WebSocket / snapshot updates call `renderer.render(newContent)` (full replacement) until incremental updates are needed.
- [ ] `TerminalViewModel` accepts a `PaneTextRenderer` in its initializer (defaults to `PlainPaneTextRenderer`). DI lets tests inject fakes.
- [ ] Renderer is unit-testable independent of SwiftUI. Tests:
  - `render("hello\nworld")` → 2-line `AttributedString`.
  - `append("more", to: render("hello"))` returns the concatenation.
- [ ] No visual change yet — the buffer keeps rendering monospace, no color.

## Notes

- The renderer interface is deliberately small. Resist adding hooks for cursor position, selection, viewport-width — those are concerns of the buffer view (or Runestone, when it lands).
- `AttributedString` here is Foundation's, not the SwiftUI extension. View code does `Text(attributedString)`.
- Prefer full-replacement semantics initially. Append is provided for the future when WebSocket emits deltas — but the contract today emits full content on every `PaneStreamMessage`, so we mostly call `render`.
- When ANSI parser lands, it'll come as `ANSIPaneTextRenderer` plugged in via DI; this ticket lays the wiring.
