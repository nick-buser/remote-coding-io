---
prefix: service
title: Add Doc repository methods and replace the local WorkspaceDocument concept
status: done
branch: service-0008
---

## Description

Add the feature `Doc` endpoints (`/api/v1/features/{id}/docs`, `/api/v1/docs/{id}`) to the repository layer. The contract returns `Doc` records with `body_blocks` storing TipTap block JSON as a string — keep the JSON opaque on the client and let the renderer view interpret it.

Replace the local `WorkspaceDocument` concept (`Core/Domain/WorkspaceDocument.swift` + `MockTmuxAgentRepository` document handling + `Features/Documents/`) with the generated `Doc` type. The local concept conflated project-level docs (which the contract does not yet surface) and feature-level docs (which the contract does surface).

For the project-level cases that have no contract analogue (`projectBrief`, `projectNotes`), keep them client-side for now under a renamed `LocalProjectNote` type so the existing `ProjectDetailView` editor still works.

Depends on `infra-openapi-regen.md`. See `docs/feature_plans/20-navigation-and-data.md` and `docs/feature_plans/30-screens.md`.

## Acceptance criteria

- [x] `TmuxAgentRepository` adds:
  - `func listFeatureDocs(featureID: Int64) async throws -> [Components.Schemas.Doc]`
  - `func getDoc(id: Int64) async throws -> Components.Schemas.Doc`
  - `func createFeatureDoc(featureID: Int64, body: Components.Schemas.CreateDocRequest) async throws -> Components.Schemas.Doc`
  - `func updateDoc(id: Int64, body: Components.Schemas.UpdateDocRequest) async throws -> Components.Schemas.Doc`
  - `func deleteDoc(id: Int64) async throws`
- [x] `LiveTmuxAgentRepository` wires these to the generated operations.
- [x] `MockTmuxAgentRepository` returns fixture `Doc` records for at least one feature in each project. Each fixture has `kind`, `title`, `body_blocks` (a TipTap JSON string with at least 3 blocks), `pinned`, `word_count`.
- [x] `Core/Domain/WorkspaceDocument.swift` is renamed to `LocalProjectNote.swift`. The type is restricted to `kind ∈ {projectBrief, projectNotes}` and the `featureDescription / promptBuildout / acceptanceCriteria` cases are removed.
- [x] All callers of the removed `WorkspaceDocument` cases compile against either the new `Doc` type (for feature-level docs) or `LocalProjectNote` (for project-level notes). `ProjectDetailView` uses `LocalProjectNote`; `FeatureDetailView` and `DocumentEditorView` use `Doc`.
- [x] `repository.listProjectDocuments(projectID:)` and `saveDocument(_:)` keep their signatures but accept `LocalProjectNote`. Live impl persists to `UserDefaults` keyed by project ID (no server roundtrip — explicitly in-memory until the contract exposes project-level docs).
- [x] `repository.listFeatureDocuments(featureID:)` and the corresponding `saveDocument(_:)` for features are deprecated and removed in this ticket. All call sites switch to the new `listFeatureDocs(featureID:)` / `updateDoc(id:body:)`.
- [x] Tests:
  - `listFeatureDocs(featureID:)` returns pinned docs first, then most-recently-updated.
  - `createFeatureDoc(featureID:body:)` defaults `body_blocks` to `"[]"` when omitted (per contract).
  - `updateDoc` recomputes `word_count` server-side; mock mimics this by counting words in the `body_blocks` JSON.
- [x] Project builds; existing screens render the same content as before (the project notes editor still works against `LocalProjectNote`; feature docs render the new fixture content).

## Notes

- TipTap `body_blocks` JSON is opaque on the wire; do not parse it in the repository. Parsing happens in the renderer view (which lands in `service-feature-prd-tab.md`). For mocks, hand-write a minimal block array like:
  ```json
  [{"type":"heading","attrs":{"level":2},"content":[{"type":"text","text":"Problem"}]},
   {"type":"paragraph","content":[{"type":"text","text":"…"}]}]
  ```
- The previous `WorkspaceDocumentKind.featureDescription / promptBuildout / acceptanceCriteria` cases mapped to specific feature concepts — now those are:
  - `featureDescription` ↔ `Doc(kind: .prd | .vision)` depending on intent.
  - `promptBuildout` ↔ `Doc(kind: .custom, title: "Prompt buildout")`.
  - `acceptanceCriteria` ↔ never a Doc — those are `AcceptanceCriterion` rows on a Ticket.
  Migration: when the user-facing change ships, drop the prompt-buildout / acceptance-criteria editing from `FeatureDetailView` (it'll come back via the proper screens in Phase 3).
- The renamed `LocalProjectNote` is a stopgap. When the backend adds project-level doc endpoints, this ticket's deprecation note should link to a follow-up that replaces `LocalProjectNote` with the contract type.
- Keep the existing `Features/Documents/DocumentEditorView` operational for `LocalProjectNote` editing only — feature docs get a new editor in Phase 3.
