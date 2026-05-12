---
branch: fix-0003-xcode-26-4-build
title: Xcode 26.4 build recovery
status: in-progress
---

## Description

The `remote-coding` app would not compile under Xcode 26.4 / iOS 26.4. The
break was not a single regression — it was a swarm of paper-cuts that the
forced toolchain bump (Xcode 26.4 → Runestone 0.5.2) revealed all at once,
on top of accumulated OpenAPI codegen drift and stale preview-only stubs.

This ticket lands the smallest set of changes that gets the build green and
captures the lessons in a retrospective so the next forced bump costs less.
Test execution remains blocked by an unrelated simulator-launch issue
(documented in the retrospective under "Open questions") and is out of
scope here.

## Acceptance criteria

- [x] `xcodebuild build` succeeds with the iPhone 17 simulator destination.
- [x] Runestone API migration applied across `RunestoneTextSurface`,
      `DocBlockRenderer`, and `DocumentEditorView` (delegate → editorDelegate,
      font/textColor → theme, lineWrappingEnabled → isLineWrappingEnabled,
      contentInset → textContainerInset, removed obsolete `text:` binding).
- [x] OpenAPI codegen drift addressed at all call sites (e.g.
      `Ticket.estimate` non-optional, missing `getAgentSession(id:)` on
      preview stubs).
- [x] SwiftUI `body` shadowing fixed in `FeatureDecisionsTab` and
      `ReplySheet`.
- [x] Curly-quote contamination in `MockTmuxAgentRepository.swift` removed.
- [x] Test target compiles against current `TerminalViewModel` API and adds
      the `import SwiftUI` / `@MainActor` annotations the new surface needs.
- [x] Retrospective filed in `docs/retrospectives/` with themed root-cause
      analysis and prioritised action items.

## Notes

The work was originally done on `main` without a branch, which violates the
iOS workflow in `claude.md`. This ticket re-homes that work onto `fix-0003`
after the fact so the diff lands through a PR and acceptance criteria are
visible in the ticket ledger.

Recovery details, root-cause themes, and follow-up action items live in
`docs/retrospectives/2026-05-09-xcode-26.4-recovery.md`. The work-history
note at `.workhistory/fix-0003.md` summarises the decision to bundle this
as a single ticket rather than splitting it (Runestone migration / OpenAPI
caller audit / cleanup as separate PRs).
