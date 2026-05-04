---
prefix: service
title: Add CreateFeatureSheet (also handles edit)
status: todo
branch:
---

## Description

Add the create-feature sheet, reachable from `Project Detail` (Features tab "+ New feature" button — needs a small UI add to the project detail Features tab footer) and from `Feature Detail` dots menu's `Edit feature`. Posts `CreateFeatureRequest` or PATCH (when editing).

Depends on `service-project-detail.md`, `service-feature-detail.md`, `infra-openapi-regen.md`. See `docs/feature_plans/30-screens.md` (section 4).

## Acceptance criteria

- [ ] `Features/FeatureDetail/CreateFeatureSheet.swift` with form fields:
  - **Title** (required, min 1).
  - **Branch name** (optional — auto-derived from slug; user-editable).
  - **Slug** (optional — auto-derived from title; user-editable).
  - **Vision** (multi-line).
  - **Accent** (`AccentSwatchPicker`).
  - **Milestone** (text field; future ticket may convert to a picker once milestone endpoints exist).
  - **Target date** (text field, freeform; e.g., "May 12" — contract is a string, not a date).
  - **Status** (segmented: `planned`, `in_progress`, `review`, `shipped`, `merged`, `abandoned` — defaults to `planned`).
  - **Health** (text field — `on-track`, `at-risk`, `planned`, `shipped` are commonly used).
  - **Tags** (chip input).
  - **Pinned doc** (text field).
- [ ] Submit calls `repository.createFeature(projectIDOrSlug: parentSlug, body:)` or, if editing, `repository.updateFeatureStatus(id:body:)` for the status field. Other field edits are not yet supported by the contract — surface this with a helper note above the form when in edit mode.
- [ ] Success: dismiss sheet, push `AppRoute.featureDetail(featureID:)` (create only — edit just refreshes).
- [ ] Field-level error mapping for `ProblemDetails.errors`.
- [ ] Tests: required-field validation; slug auto-derivation; create-then-list shows the new feature in mock; edit returns the modified feature.
- [ ] `#Preview` renders both the create and edit modes.

## Notes

- The contract currently exposes `updateFeatureStatus` only — full feature edit is not in the API. Document this by hiding non-status fields in edit mode (or render them disabled with a tooltip "Edit via project; this field is read-only on iOS").
- Update the Project Detail's Features tab to include a "+ New feature" footer button (similar to the Tickets tab). It opens this sheet with `parentSlug` pre-filled.
- The Health value is free-form on the wire; for the picker, suggest `on-track / at-risk / planned / shipped / behind` as quick options, but allow custom strings.
