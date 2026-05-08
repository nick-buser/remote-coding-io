---
prefix: service
title: Feature detail PRD sub-tab — doc list and read-only TipTap renderer
status: done
branch: service-0022
---

## Description

Build the PRD sub-tab on Feature Detail and the doc viewer it pushes to. The sub-tab lists docs (sourced from `repository.listFeatureDocs(featureID:)`) with a kind filter; tapping a doc pushes a read-only renderer that interprets the TipTap `body_blocks` JSON into native blocks.

Depends on `service-feature-detail.md`, `service-repo-docs.md`, `infra-component-kit.md`. See `docs/feature_plans/30-screens.md` (section 5).

## Acceptance criteria

- [ ] `Features/FeatureDetail/Tabs/FeaturePRDTab.swift` renders:
  - A small kind filter row above the list (only kinds with ≥1 doc plus an "All" option).
  - A `RoundedCard` with rows of `DocRow`. Pinned docs first.
- [ ] `DocRow`:
  - 16pt SF Symbol icon mapped from `doc.kind` (`vision` → "lightbulb", `prd` → "doc.text", `design` → "ruler", `notes` → "note.text", `log` → "list.bullet.rectangle", `custom` → "doc").
  - 14pt `doc.title`.
  - Mono `<word_count> words · updated <relative>`.
  - 10pt yellow pinned star when `doc.pinned`.
- [ ] Tap pushes `AppRoute.docDetail(docID:)`.
- [ ] `Features/FeatureDetail/DocViewerView.swift` is a read-only renderer. Loads via `repository.getDoc(id:)`. Shows:
  - 11pt mono eyebrow `<feature.publicID> · <doc.kind>`.
  - 26pt display weight 700 `doc.title`.
  - Renders `doc.body_blocks` JSON into native blocks (paragraph, heading 1/2/3, bullet list, ordered list, code block, callout, task list).
- [ ] `Core/Components/Doc/TipTapBlockRenderer.swift` provides the block decoder + `View` builder.
  - Decodes a small subset of TipTap node shapes: `paragraph`, `heading {level}`, `bulletList { content: [listItem [...] ] }`, `orderedList`, `codeBlock {language?}`, `blockquote`, `taskList`, `taskItem { checked: Bool }`.
  - Unknown nodes render as a muted "Unsupported block: <type>" placeholder so the renderer never crashes on unfamiliar content.
- [ ] No editing in this ticket. Edit affordance is a follow-up that requires Runestone.
- [ ] Trailing dots menu on `DocViewerView`: `Pin / Unpin`, `Delete` (calls `repository.deleteDoc(id:)`).
- [ ] Footer "+ New doc" button on the PRD tab opens a small sheet with `Title`, `Kind` (segmented), `Pinned` (toggle). Submits `CreateDocRequest` with default `body_blocks: "[]"`.
- [ ] Tests: TipTap decoder handles the design's mock fixture; unknown node types fall through to the placeholder.
- [ ] `#Preview` shows DocViewer rendering a sample TipTap document.

## Notes

- TipTap shape reference: `{"type":"<name>", "attrs":{}, "content":[{"type":"text","text":"..."}]}`. The decoder treats `content[].type == "text"` leaves and joins them into a string; marks (`content[].marks`) drive bold/italic/code styling on the text run.
- Code blocks use `Theme.mono(13)` and a tinted background. Don't try to syntax-highlight in this ticket.
- The renderer is deliberately a *renderer*, not an editor. Keep `Edit` out of scope.
- Sort: pinned first by `updated_at DESC`, then unpinned by `updated_at DESC` (matches contract description).
- The kind filter is dynamic (only show kinds that have docs) — no need to hard-code.
