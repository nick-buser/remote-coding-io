# service-0046: Doc editor — inline title editing, Runestone body editor, round-trip Markdown helpers

Ticket: `phase8/02-doc-editor`

## Summary

Adds a full inline editing experience to `DocViewerView` backed by a Runestone
Markdown surface. Three new block types (`table`, `horizontalRule`, `image`) are
added to the `DocBlock` model. Round-trip serialisation/deserialisation helpers
(`DocMarkdownSerializer`, `DocMarkdownParser`, `DocTipTapEncoder`) let the editor
convert TipTap JSON → Markdown for editing and Markdown → TipTap JSON on save.
27 new tests cover the serializer, parser, encoder, and round-trip paths.

## Changes

- **Modified** `Core/Components/Doc/DocBlock.swift`:
  - Added three cases to `DocBlock` enum:
    `table(headers:[String], rows:[[String]])`, `horizontalRule`, `image(src:String, alt:String?)`.
  - Extended `DocBlockDecoder.decodeBlock` to handle `"table"`, `"horizontalRule"`, `"image"`.
  - Added private `decodeTable(rows:)` helper that walks TipTap's `tableRow` /
    `tableHeader` / `tableCell` structure and extracts plain-text cell content.

- **Modified** `Core/Components/Doc/DocBlockRenderer.swift`:
  - Added `table(headers:rows:)` — renders as a card with header background, dividers,
    and a rounded-rect stroke border.
  - Added `tableRow(cells:isHeader:)` helper.
  - Added `horizontalRule()` — a plain `Divider` with vertical padding.
  - Added `imageBlock(src:alt:)` — `AsyncImage` for valid URLs, falls back to a
    `photo` icon + alt-text placeholder.
  - Added `imagePlaceholder(alt:)` helper.
  - Wired the three new cases into `renderBlock(_:)`.

- **New** `Core/Components/Doc/DocMarkdownSerializer.swift`:
  - `enum DocMarkdownSerializer` with `serialize([DocBlock]) -> String`.
  - Block serialisers for all `DocBlock` cases; unsupported falls through to `""`.
  - `serializeRuns([TextRun]) -> String` — applies marks in innermost-first order
    (`code` → `strike` → `underline` → `italic` → `bold`) so nested delimiters
    are unambiguous.

- **New** `Core/Components/Doc/DocMarkdownParser.swift`:
  - `enum DocMarkdownParser` with `parse(String) -> [DocBlock]`.
  - Line-by-line scanner handles all block types the serialiser produces:
    fenced code blocks, ATX headings (H1–H3 capped), horizontal rules (`---`),
    pipe tables, blockquotes, task lists (`- [x] / - [ ]`), bullet lists,
    ordered lists, images (`![alt](src)`), and paragraphs.
  - `parseInline(String) -> [TextRun]` greedy left-to-right scanner handles
    `**bold**`, `~~strike~~`, `<u>underline</u>`, `*italic*`, `` `code` ``.
    Swift `Substring` index sharing means closing-delimiter positions are
    always correct without manual offset arithmetic.

- **New** `Core/Components/Doc/DocTipTapEncoder.swift`:
  - `enum DocTipTapEncoder` with `encode([DocBlock]) -> String` — inverse of
    `DocBlockDecoder`; produces valid TipTap JSON accepted by `updateDoc`.
  - Handles all `DocBlock` cases including `table` (→ `tableHeader`/`tableCell`
    with paragraph wrappers), `horizontalRule`, `image`, `unsupported` (passthrough).

- **Modified** `Features/FeatureDetail/DocViewerView.swift`:
  - Added `isEditing`, `draftTitle`, `draftMarkdown`, `isSaving`, `@FocusState titleFocused`.
  - `body` switches between `viewerLayout` (existing scroll view) and `editorLayout`.
  - `editorLayout`: custom `editorTopBar` (Cancel / title / Done buttons) + `TextField`
    for title + `RunestoneTextSurface(theme: .docLight)` for body, inside a `ScrollView`.
  - `enterEditMode()` populates `draftTitle` / `draftMarkdown` from current state.
  - `commitEdits()` parses Markdown → DocBlock → TipTap JSON, calls `updateDoc`,
    then reloads `blocks` from the returned doc's `bodyBlocks`.
  - Dots menu gains an "Edit" entry; `emptyBody` message updated to point to ···.
  - Preview restored with two colour-scheme variants.

- **New** `remote-codingTests/DocEditorTests.swift` — 27 tests:
  - Serializer: headings, paragraph marks, code block, horizontal rule, table,
    image, task list.
  - Parser: heading, code block, horizontal rule, table, image, task list, bullet
    list, ordered list; inline bold, code, strike.
  - Encoder: paragraph, heading, horizontal rule, table.
  - Round-trip (serialize → parse → encode → decode): heading+paragraph, code
    block, horizontal rule, table, bullet list.

## Decisions

- **Markdown as the edit surface, not TipTap JSON** — Markdown is far more
  human-readable and editable in a plain-text surface. TipTap JSON is only on
  the wire; Markdown lives only in the editor session.
- **`DocTipTapEncoder` as a separate enum** — keeps encoding concerns out of
  `DocBlock` (which is already responsible for decoding via `DocBlockDecoder`)
  and makes the encode/decode symmetry explicit.
- **`minHeight: 420` for the Runestone editor** — the editor has its own internal
  scroll for long documents; the outer `ScrollView` handles page-level navigation.
  A fixed minimum prevents the surface from collapsing when the doc is empty.
- **`AccentColor.value(for:scheme)` for the Done button** — consistent with the
  rest of the app's dynamic accent resolution.

## Notes

- No xcodebuild on this host — CI validates the build.
- The project uses `PBXFileSystemSynchronizedRootGroup` (Xcode 16), so the four
  new `.swift` files are automatically discovered without touching `project.pbxproj`.
