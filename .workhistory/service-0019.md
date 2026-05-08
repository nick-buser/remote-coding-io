# service-0019: Ticket review — diff, criteria, approve/request actions

Ticket: `.tickets/done/service-review-screen.md`

## Summary

Replaces the `.ticketDetail` `RoutePlaceholder` with the v2 review
screen: `QuietHeader` + ticket meta hero (`TMX-#### · StatusPill ·
title · branch · +adds/−dels · n files`), `SegmentedControl(["Diff",
"Checklist done/total", "Files"])`, and a sticky safe-area footer
carrying `Request changes` / `Approve & merge`. Approve and Request
both call the Phase 2 review endpoints and dismiss back to the
caller.

Introduces a small `UnifiedDiff` helper (LCS-via-DP) that powers the
Diff body and the file-header `+M / −N` summary. The dots menu wires
`Send back to doing` through `sendTicketBack`.

## Changes

- `Core/Components/Diff/UnifiedDiff.swift` — pure helper: `compute`
  returns `[Line]` (each tagged `.added / .removed / .context`);
  `summary` returns `(adds, dels)` for the header pill. Splits on
  `\n` with the trailing-empty-string suppression baked in.
- `Features/Review/TicketReviewViewModel.swift` — `@Observable
  @MainActor`. Loads `ticket / criteria / diff` in parallel via
  `async let`, derives `DiffStats` and `filesByChange()`, exposes
  approve / requestChanges / sendBack actions that flip
  `didFinishAction` on success.
- `Features/Review/TicketReviewView.swift` — full screen body:
  top bar with back + dots menu, hero, segmented control, diff /
  checklist / files bodies, sticky `safeAreaInset` footer. The
  Diff body horizontal-scrolls per file (no line-wrap, matching
  the design); the Checklist body renders a read-only list with
  strikethrough on done items; the Files body groups paths by
  change type.
- `ContentView.swift:113` — `.ticketDetail` route now mounts
  `TicketReviewView(publicID:)` instead of `RoutePlaceholder`.
- `remote-codingTests/UnifiedDiffTests.swift` — pure-helper cases
  covering empty inputs, identical content, insertion, deletion,
  replacement, summary counts, and trailing-newline handling.
- `remote-codingTests/TicketReviewViewModelTests.swift` — Swift
  `Testing` cases covering load, diff-stats aggregation, files
  grouping, approve / requestChanges / sendBack action wiring,
  and the dynamic-label `ReviewSection.from(label:)` mapping.

## Decisions

- **LCS-via-DP for the diff.** O(n×m) memory is fine at PR-sized
  diffs (hundreds of lines). The helper's surface is a flat
  `[Line]`; if a Myers-diff upgrade is needed later the call
  site only depends on the line shape, not the algorithm.
- **No syntax highlighting.** The contract delivers raw text;
  syntax highlighting is a separate ticket and the design doesn't
  call for it on review.
- **Dynamic checklist label inside the segmented control.** The
  segmented control renders `"Checklist <done>/<total>"` literally
  (it just shows the string the view passes). `ReviewSection.from(
  label:)` matches by prefix so the binding stays consistent
  across re-renders that change the count.
- **Request-changes sheet ships flat.** Just a `TextEditor` plus
  Submit / Cancel. Per the ticket note, no template snippets in v1.
- **`didFinishAction` triggers `dismiss()`.** The view watches the
  flag in `onChange` and pops the screen on success — simpler
  than threading the coordinator through every action call site.
  Activity feed refresh happens implicitly via the workspace
  poller's next tick (the mock emits an `.approve` /
  `.review` / `.check` activity event in the same call).
- **Edit ticket / Mark in review menu items disabled.** Edit
  lives in a future ticket; "Mark in review" would no-op since
  the screen is gated on review status.

## Notes

- Branched from `service-0018` (still open). The PR's base is
  `service-0018`; once #20–#24 land the base will retarget to
  `main`. ContentView modification for the `.ticketDetail`
  route is the only edit there — the placeholder copy referencing
  `service-review-screen` simply goes away.
- The footer uses `.background(.ultraThinMaterial)` so the
  segmented-control area above it can scroll under the buttons
  without losing legibility, matching the design's "sticky
  glass" footer.
- iOS gates were not exercised in this session (Linux runner
  without Xcode); the suite needs to run on a Mac via the
  `ios-gates` skill before merge.
