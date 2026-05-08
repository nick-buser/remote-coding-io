# service-0008: Doc + LocalProjectNote repository methods

Ticket: `.tickets/done/service-repo-docs.md`

## Summary

Phase 2 continues. The legacy `WorkspaceDocument` type
conflated two unrelated surfaces — project-level brief / notes
the contract still does not expose, and feature-level docs the
contract has shipped under `/api/v1/features/{id}/docs`. This
branch lands the five `Doc` repository methods end-to-end and
splits the local concept in two: the contract-backed
`Components.Schemas.Doc` for feature-level surfaces, and a
renamed `LocalProjectNote` for the project-level stopgap.

## Changes

- `TmuxAgentRepository` gains five Doc methods:
  - `listFeatureDocs(featureID:)`
  - `getDoc(id:)`
  - `createFeatureDoc(featureID:body:)`
  - `updateDoc(id:body:)`
  - `deleteDoc(id:)`
- `LiveTmuxAgentRepository` wraps the matching generated
  operations. `listFeatureDocs` sorts pinned-first then
  `updatedAt` desc inside the repository so views never see an
  unsorted list.
- `MockTmuxAgentRepository` seeds 8 fixture docs across
  features 11 / 12 / 21 with TipTap-shaped `body_blocks` for
  every `DocKind` (`vision`, `prd`, `design`, `notes`, `log`,
  `custom`). Mutations recompute `wordCount` from the
  `body_blocks` string on every create / update so the field
  matches the contract's server-side behaviour.
- `Core/Domain/WorkspaceDocument.swift` is renamed to
  `LocalProjectNote.swift`. Kind drops to two cases —
  `projectBrief`, `projectNotes` — and ownership simplifies to
  a flat `projectID` (the `.feature(id)` variant is gone, since
  feature docs are `Doc` records now).
- New `Core/Persistence/LocalProjectNoteStore.swift` is the
  UserDefaults-backed store the live repo uses for project
  notes. Reads / writes go through one `LocalProjectNotes.v1`
  payload bucketed by `String(projectID)`.
- View / ViewModel callers migrate:
  - `ProjectDetailView` + `ProjectDetailViewModel` →
    `LocalProjectNote` (notes still tap into
    `DocumentEditorView` for editing).
  - `FeatureDetailView` + `FeatureDetailViewModel` →
    `Components.Schemas.Doc`. The criteria sub-tab is dropped
    (those records moved to `AcceptanceCriterion` on Tickets in
    service-0007). Doc rows push `.docDetail` through the
    coordinator, which still resolves to `RoutePlaceholder`
    until `service-feature-prd-tab` lands the renderer.
  - `DocumentEditorView` + `DocumentEditorViewModel` keep the
    project-notes editor; feature-doc editing returns in
    Phase 3 with the proper TipTap renderer.
- Five new `remote_codingTests` cover: pinned-first ordering,
  `body_blocks` default-to-`"[]"`, `wordCount` recompute on
  update, `deleteDoc` removal, project-note seed scoping, and
  the `LocalProjectNoteStore` round-trip across two store
  instances on the same defaults.

## Decisions

- **Split the concept rather than retrofit `WorkspaceDocument`.**
  `Components.Schemas.Doc` is structurally different — it
  carries opaque TipTap `body_blocks` JSON, a `pinned` flag,
  `wordCount`, `kind` enum that does not overlap with the old
  one (no `acceptanceCriteria`). Keeping a single shared type
  would have required adapter shims on every read and write.
  The split lets each surface use its native shape and lets
  the project-notes stopgap retire cleanly when the contract
  catches up.
- **Persist project notes in UserDefaults, not on disk.** The
  contract is going to grow project-level doc endpoints; the
  stopgap should be cheap to delete. UserDefaults is one
  property-list payload per device — no migrations to do when
  the real endpoint lands. Bucketing by projectID inside one
  `LocalProjectNotes.v1` payload keeps reads to a single
  decode.
- **Drop `acceptanceCriteria` from the Docs sub-tab outright,
  not stub it out.** Acceptance criteria are
  `AcceptanceCriterion` records on a Ticket now (landed in
  service-0007). Leaving an empty criteria sub-tab in
  `FeatureDetailView` would have been more confusing than just
  removing it — Phase 3 rebuilds the feature detail anyway.
- **Sort pinned-first inside the repository, not at the view
  layer.** The contract documents the order
  ("pinned first then most-recently-updated"), so encoding it
  once in the repository keeps every screen unaware of the
  ordering rule. `listFeatureDocs` mock + live both apply it.
- **Recompute `wordCount` on create as well as update.** The
  contract only documents the recompute on PATCH, but a
  fresh-from-create record with `wordCount: 0` for a non-empty
  `body_blocks` would be visibly wrong. Mock recomputes on
  both paths so previews paint the real number.
- **Keep `LocalProjectNote.id` a free-form `String`, not the
  contract's `Int64`.** Project-level notes are local-only and
  may need to round-trip across UserDefaults installs without
  collisions. The seeded mock IDs are stable strings
  (`project-1-brief`, `project-1-notes`); user-created notes
  can use UUIDs without conflicting with future server IDs.

## Notes

- `Core/Persistence/` is a new directory. The Xcode project
  uses `fileSystemSynchronizedGroups`, so adding files to a
  new sub-directory does not require a `.pbxproj` edit.
- `xcodebuild build test` was not run on this branch because
  the dev environment lacks a Swift toolchain. Build + test
  verification is left to the local Xcode pass before merge —
  this is called out explicitly in the PR test plan.
- `LocalProjectNote` is intentionally a stopgap. When the
  backend ships project-level doc endpoints, a follow-up
  ticket will replace `LocalProjectNote` and
  `LocalProjectNoteStore` with the contract type and retire
  `Core/Persistence/`. The store keys on the `v1` suffix so a
  later migration can recognise the legacy payload.
- `Components.Schemas.DocKind.systemImage` is colocated with
  `FeatureDetailView` for now. When the Phase 3 PRD renderer
  lands the icon mapping likely moves into a shared adapter
  alongside the renderer.
