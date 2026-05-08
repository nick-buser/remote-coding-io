# service-0027: Create-feature sheet (also handles edit)

Ticket: `.tickets/done/service-feature-create.md`

## Summary

Adds `CreateFeatureSheet` reachable from two places:

- **Project detail Features tab** — new `+ New feature` footer
  button next to the existing feature list. On submit, the new
  feature prepends to the local list and the screen pushes
  `.featureDetail(featureID:)`.
- **Feature detail dots menu** — the previously-disabled "Edit
  feature" item now opens the same sheet pre-filled. Because the
  contract only exposes `updateFeatureStatus` for features today,
  edit mode disables every non-status field and submits via the
  status-only PATCH.

The repository surface gains `createFeature(projectIDOrSlug:body:)`
(Live wraps `client.createFeature`; Mock validates required
title, derives a slug, enforces per-project slug uniqueness, and
inserts with sensible field defaults).

## Changes

- `Core/Repositories/TmuxAgentRepository.swift` — protocol gains
  `createFeature(projectIDOrSlug:body:)`.
- `Core/Repositories/LiveTmuxAgentRepository.swift` — wraps
  `client.createFeature`. Maps 201 / 400 / 404 / 409 / 503 onto
  `RepositoryError`.
- `Core/Repositories/MockTmuxAgentRepository.swift` — validates
  `title`, derives a slug fallback (reusing the static
  `deriveSlug` from the create-project landing), enforces
  per-project slug uniqueness, and inserts a fully-populated
  `Feature` with `progressCached = 0` and `health` defaulting to
  `"on-track"` when the request omits it.
- `Features/Inbox/InboxView.swift` — preview-only
  `EmptyInboxRepository` forwards `createFeature` so the
  protocol stays satisfied.
- `Features/FeatureDetail/CreateFeatureViewModel.swift` —
  `@Observable @MainActor`. Single view-model powers create and
  edit modes via an `existing: Feature?` init parameter:
  - Title auto-derives both slug AND branch (`feat/<slug>`),
    each with its own manual-edit lock so the user can type
    into either field independently.
  - `parsedTags()` splits the comma-separated input, trims, and
    drops empties.
  - `submit(...)` routes through `createFeature` in create mode
    and `updateFeatureStatus` in edit mode (per the ticket's
    contract-limitation note).
  - `nonStatusFieldsAreEditable` is `false` in edit mode so the
    sheet can disable everything except the status picker.
  - `fieldErrorMapper` covers contract snake-case + Swift
    camelCase + nested paths.
- `Features/FeatureDetail/CreateFeatureSheet.swift` — SwiftUI
  form view. Sections: Identity (title / slug / branch), Details
  (vision / milestone / target date / tags), Appearance (accent),
  Status & health. Edit mode renders a banner explaining the
  status-only constraint and disables every non-status control.
- `Features/Projects/ProjectDetailView.swift`:
  - New `@State showCreateFeatureSheet`.
  - Features sub-tab body renders a `+ New feature` footer
    `PillButton` after the section list (or directly under the
    "No features yet" empty state).
  - `.sheet` modifier presents `CreateFeatureSheet`; on success
    prepends and pushes detail.
- `Features/FeatureDetail/FeatureDetailView.swift`:
  - New `@State showEditFeatureSheet`.
  - Dots menu's `Edit feature` no longer `.disabled(true)` — it
    flips the binding.
  - `.sheet` presents `CreateFeatureSheet(parentSlug:existing:)`;
    success replaces the local feature so the hero / progress
    update without a reload.
- `remote-codingTests/CreateFeatureViewModelTests.swift` — Swift
  `Testing` cases covering required-field gating, slug + branch
  auto-derivation with manual-edit lockout, tag parsing, the
  field-error mapper, edit-mode pre-fill + status routing, and
  two mock-backed integration paths (create success + slug
  conflict mapping).

## Decisions

- **Single view-model for create + edit.** Mirrors the
  service-0026 pattern for projects. Submit branches on
  `existing == nil`; non-status fields disable in edit mode
  because the contract doesn't expose a richer feature update.
- **Branch name auto-derives via `feat/<slug>`** to match the
  project's existing convention. Independent manual-edit lock
  from slug — typing into one doesn't lock the other.
- **`pinned_doc` field omitted from the form.** The Feature
  schema carries both `description_doc_key` and `pinned_doc` but
  CreateFeatureRequest only exposes `description_doc_key`. The
  ticket mentions "Pinned doc" but the value would have nowhere
  to land on create; deferred until the contract surfaces a
  unified field.
- **Edit-mode banner copy** explicitly calls out the status-only
  constraint so the user understands why every other field is
  greyed out. When the contract surfaces a richer
  `updateFeature`, the disabled state lifts and the banner can
  go.
- **Footer button on Features sub-tab specifically.** The Tickets
  / PRD / Decisions / Sessions sub-tabs already have their own
  footer affordances; `+ New feature` doesn't belong on those.
  Embedding inside `featuresBody` (vs. a global footer) keeps
  it scoped.

## Notes

- Branched from `service-0026` (still open) so the modal
  context-menu wiring there can land first. Base will retarget
  to `main` once #33 lands.
- This is the **last create / edit modal ticket** in the
  `.tickets/` queue. Remaining queued work: Phase 4 terminal
  tickets and Phase 5 polish.
- iOS gates were not exercised in this session (Linux runner
  without Xcode); the suite needs to run on a Mac via the
  `ios-gates` skill before merge.
