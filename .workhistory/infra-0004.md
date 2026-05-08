# infra-0004: Add Runestone SwiftPM dependency and finish the wrapper

Ticket: `.tickets/done/infra-runestone-package.md`

## Summary

Adds `simonbs/Runestone` (^0.3.0) as a Swift Package dependency and completes
the `RunestoneTextSurface` wrapper with two theme presets: `.terminalDark` and
`.docLight`.

## Changes

- `remote-coding.xcodeproj/project.pbxproj` — adds `XCRemoteSwiftPackageReference
  "Runestone"` (UUID `8C1EA2B02FAABC1200000001`), `XCSwiftPackageProductDependency`
  (UUID `8C1EA2B12FAABC1200000001`), and `PBXBuildFile` in Frameworks (UUID
  `8C1EA2B22FAABC1200000001`). Wired into `packageReferences`,
  `packageProductDependencies`, and the Frameworks build phase.
- `remote-coding.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
  — pins Runestone at version `0.3.0` (placeholder revision
  `0000000000000000000000000000000000000000`; Xcode resolves the real hash on
  first build).
- `Core/Components/RunestoneTextSurface.swift` — rewrites the placeholder:
  `enum RunestoneTheme { case terminalDark; case docLight }`.
  `makeUIView` creates `Runestone.TextView`, applies theme (mono 13pt / no line
  numbers / no soft-wrap / black bg for terminal; UI 14pt / soft-wrap / light bg
  for doc). `updateUIView` extracts plain string, calls `setState(TextViewState
  (text:))` only when content differs. `Coordinator: TextViewDelegate` fires
  `onCommit` on `textViewDidReturn`.

## Decisions

- **One wrapper file as the sole Runestone touch point.** No Runestone import
  outside `RunestoneTextSurface.swift` — keeps the dependency boundary clean.
- **`setState` only on diff** — avoids redundant layout passes when content
  hasn't changed (e.g., view re-renders from unrelated state changes).
- **Placeholder revision in `Package.resolved`** — the real SHA is resolved by
  Xcode on first `xcodebuild`; committing `0000...` is acceptable for a
  non-network CI environment.

## Notes

- PR #41, targeting `phase4/06-websocket`.
