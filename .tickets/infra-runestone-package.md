---
prefix: infra
title: Add Runestone SwiftPM dependency and finish the wrapper
status: todo
branch:
---

## Description

Add the [Runestone](https://github.com/simonbs/Runestone) Swift Package dependency and finish the placeholder `RunestoneTextSurface` wrapper in `Core/Components/`. The wrapper exposes a small SwiftUI-friendly API used by both the terminal buffer and (later) the doc editor.

Depends on `infra-design-tokens.md`. See `docs/feature_plans/40-terminal.md`.

## Acceptance criteria

- [ ] Runestone added as a Swift Package dependency in the Xcode project.
- [ ] `Core/Components/RunestoneTextSurface.swift` finishes the wrapper:
  ```swift
  struct RunestoneTextSurface: UIViewRepresentable {
      var attributedText: AttributedString
      var isEditable: Bool = false
      var onCommit: ((String) -> Void)? = nil
      var theme: RunestoneTheme = .terminalDark   // or .docLight
  }
  ```
- [ ] Theme presets: `.terminalDark` (mono 13pt, no line numbers, no soft wrap, dark background) and `.docLight` (UI font 14pt, soft wrap on, line numbers off).
- [ ] `attributedText` updates apply via Runestone's content APIs without rebuilding the view (preserves scroll position and selection).
- [ ] `isEditable: false` disables editing but keeps text selectable.
- [ ] When `onCommit` is provided and `isEditable: true`, return key submits the buffer (terminal multi-line draft sheet uses this).
- [ ] Existing placeholder fallback in `RunestoneTextSurface.swift` is removed.
- [ ] Project builds and `#Preview` renders both themes with sample content.

## Notes

- Runestone is iOS-only. Target deployment matches the Xcode project's iOS 26.4. Confirm Runestone's minimum iOS version (15+ at the time of writing) is satisfied.
- The wrapper is `UIViewRepresentable` — bridge updates carefully to avoid infinite loops. Use a `Coordinator` to track in-flight changes.
- Performance: large terminal buffers (10k+ lines) should not lag. Validate with a soak preview that pumps lines at ~60Hz.
- Don't expose Runestone's API surface to view code — keep `RunestoneTextSurface` the only public touch point.
