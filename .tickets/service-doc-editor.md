---
prefix: service
title: Doc viewer improvements — inline title edit, body editing, tables, images
status: todo
branch:
---

## Description

Enhance `DocViewerView` from a read-only renderer to a light edit surface.
The v2 design deferred editing with "arrives with Runestone" — Runestone is now
integrated (phase 4). This ticket adds inline title editing (matching the
`TicketDetailView` pattern), a basic body editor backed by Runestone for plain
text / markdown, table rendering, image placeholders, and syntax highlighting
in code blocks.

Depends on: Runestone package (`infra-runestone-package`, done), `service-terminal-runestone` (done).

## Acceptance criteria

### Inline title editing
- [ ] `DocViewerView.hero` makes the title a tappable `TextField` (same `@FocusState`
  + blur-commits pattern as `TicketDetailViewModel.commitTitle()`). Committing calls
  `repository.updateDoc(id: doc.id, body: UpdateDocRequest(title: trimmed, ...))`.
- [ ] Empty title reverts to original (no save).

### Body editor
- [ ] A floating "Edit" / "Done" toggle button in the top bar (trailing, next to the
  dots menu) switches between read mode and edit mode.
- [ ] **Read mode**: existing `DocBlockRenderer` (unchanged).
- [ ] **Edit mode**: renders `doc.bodyBlocks` as a Runestone `TextView` in a monospaced
  font, pre-populated with a lossless serialisation of the TipTap JSON to Markdown
  (`DocBlockDecoder` → Markdown string via `DocMarkdownSerializer`).
  - On "Done": calls `repository.updateDoc(id:body:)` with the Markdown re-encoded
    back into TipTap JSON via `DocMarkdownParser`. Reverts to read mode.
  - Unsaved changes indicator: dot in the title bar when the body has been modified.
  - Cancel: confirm sheet ("Discard changes?") if there are unsaved changes.
- [ ] `DocMarkdownSerializer.swift` in `Core/Components/Doc/`:
  - Converts `[DocBlock]` → a Markdown string.
  - Round-trips cleanly for: heading (# / ## / ###), paragraph, bullet list, ordered
    list, code block (fenced with language), blockquote, task list (`- [ ]` / `- [x]`).
- [ ] `DocMarkdownParser.swift` in `Core/Components/Doc/`:
  - Parses the above Markdown back into `[DocBlock]` using a simple line-by-line
    state machine (no third-party Markdown library needed for this limited subset).

### Renderer improvements
- [ ] **Tables**: `DocBlock.table(headers: [String], rows: [[String]])` case.
  - Decoder handles `{"type":"table", ...}` TipTap node.
  - Renderer shows a scrollable `Grid` / `LazyVGrid` with header row in semibold,
    border separators, and alternating row backgrounds.
- [ ] **Horizontal rule**: `DocBlock.horizontalRule` — renders a `Divider()`.
- [ ] **Inline images**: `DocBlock.image(src: String, alt: String?)` — renders an
  `AsyncImage` with a placeholder. Does not support upload in this ticket.
- [ ] **Syntax highlighting in code blocks**: use Runestone's highlight API to apply
  tree-sitter grammar for `swift`, `python`, `bash`, `json`, `typescript` when
  the `language` attribute matches. Fallback to plain monospaced for unknown languages.

### Tests
- [ ] `DocMarkdownSerializer` round-trips all supported block types.
- [ ] `DocMarkdownParser` produces equivalent blocks for the same input.
- [ ] Table decoder produces the correct headers + rows from a fixture TipTap JSON.

## Notes

- Keep the `DocBlockDecoder` / `DocBlockRenderer` pair intact — they're the read-mode
  path and have existing tests. Layer the editor on top, don't refactor the decoder.
- The Markdown ↔ TipTap round-trip is intentionally lossy for exotic block types
  (e.g., mention nodes, embeds). Those should survive as `unsupported` blocks in
  read mode but be stripped on the Markdown save path; document this clearly with
  a warning banner: "Some unsupported blocks were removed on save."
- Don't attempt WYSIWYG inline formatting in the Runestone edit field in v1 — plain
  text Markdown is sufficient and keeps the implementation tractable.
- Image upload is explicitly out of scope. Displaying existing images from `src` URLs
  already in the document is in scope.
