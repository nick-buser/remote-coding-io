# service-0022: Feature detail PRD sub-tab — doc list + read-only TipTap renderer

Ticket: `.tickets/done/service-feature-prd-tab.md`

## Summary

Replaces the PRD-sub-tab `EmptyState` stub (landed in service-0016)
with `FeaturePRDTab`: a kind filter chip row (only kinds present),
a `RoundedCard` of `FeatureDocRow`s sorted pinned-first then
updated-desc, and a `+ New doc` footer that opens `CreateDocSheet`.
Tap a row → push `.docDetail(docID:)`, which now mounts
`DocViewerView` (replaces the previous `RoutePlaceholder`).

`DocViewerView` paints the doc through a new `DocBlockRenderer` that
parses TipTap `body_blocks` JSON into native SwiftUI blocks
(headings, paragraphs, bullet/ordered lists, code blocks,
blockquotes, task lists). Inline marks (`bold / italic / code /
underline / strike`) ride through `AttributedString`. Unknown node
types and malformed JSON fall through to a "Unsupported block"
placeholder so the renderer never crashes on novel content.

## Changes

- `Core/Components/Doc/DocBlock.swift` — pure data model
  (`DocBlock`, `TextRun`, `TextMark`, `TaskItem`) plus
  `DocBlockDecoder.decode(_:)` which parses the JSON via
  `JSONSerialization`. Recursion is shallow and explicit; unknown
  marks / nodes fall through gracefully.
- `Core/Components/Doc/DocBlockRenderer.swift` — SwiftUI view
  that renders `[DocBlock]`. Handles every supported block plus
  the `unsupported` placeholder; inline marks become
  `AttributedString` attributes. Code blocks horizontal-scroll;
  task lists render `done` items with strikethrough.
- `Features/FeatureDetail/Tabs/FeaturePRDTab.swift` — kind
  filter row + doc list + footer + `CreateDocSheet`. The filter
  is dynamic (only kinds with ≥1 doc render). `FeatureDocRow`
  surfaces the kind icon, title, pinned star, word count, and
  relative updated time.
- `Features/FeatureDetail/DocViewerView.swift` — full read-only
  doc surface. Loads via `getDoc(id:)`, displays an eyebrow
  (`FEAT-### · KIND`) plus the title and meta line, then renders
  the parsed blocks. Dots menu wires `Pin/Unpin` (through
  `updateDoc`) and `Delete` (through `deleteDoc`). `didDelete`
  triggers `dismiss()` on the parent stack.
- `Features/FeatureDetail/FeatureDetailView.swift` — replaces
  `prdSummary` stub with `prdBody: FeaturePRDTab(...)`.
- `ContentView.swift:101` — `.docDetail` now mounts
  `DocViewerView(docID:)` instead of `RoutePlaceholder`.
- `remote-codingTests/DocBlockRendererTests.swift` — Swift
  `Testing` cases covering paragraph / heading / heading-clamp /
  bullet list / code block / task list decoding, mark
  propagation and unknown-mark drop, the unsupported-node
  fallback, and malformed-input safety.

## Decisions

- **`JSONSerialization` over Codable.** TipTap's tree is
  open-ended (each node can carry arbitrary attrs and content);
  Codable would either require deeply nested generic types or a
  custom `init(from:)` that mirrors what we already wrote with
  `JSONSerialization`. The dynamic-typing approach is shorter
  and the only loss (compile-time field validation) is recovered
  by the test fixture suite.
- **Renderer ships read-only.** Per the ticket scope, editing
  lands with the Runestone integration in Phase 4 / 5. The
  renderer's API is independent of any future editor — they
  share `[DocBlock]` as the canonical model.
- **`FeatureDocRow` lives next to the tab, not in
  `Core/Components/`.** It's denser than the project-scoped
  `DocRow` (drops the parent-feature label, adds an
  updated-relative timestamp). Promoting it would force the
  shared row to grow a config knob.
- **`DocViewerView` resolves the parent feature for the
  eyebrow.** A second fetch (`getFeature`) just for the
  `FEAT-###` label feels heavy, but the alternative — passing
  the feature down through every doc-link callsite — is more
  invasive. The fetch is cheap on the mock and live backend.
- **Heading levels clamp to 1…3.** TipTap allows up to 6, but
  the design only uses 3 sizes. Clamp in the decoder so the
  renderer doesn't have to switch on level beyond `.headingSize(for:)`.

## Notes

- Branched from `service-0021` (still open) to avoid
  `FeatureDetailView.swift` and `ContentView.swift` conflicts
  between parallel sub-tab PRs. Base will retarget to `main`
  once the previous PR lands.
- `body_blocks` defaults to `"[]"` (empty array). The decoder
  surfaces this as zero blocks; the viewer renders an
  `EmptyState` "No content yet" carrying a forward-pointer to
  the Runestone editor.
- iOS gates were not exercised in this session (Linux runner
  without Xcode); the suite needs to run on a Mac via the
  `ios-gates` skill before merge.
