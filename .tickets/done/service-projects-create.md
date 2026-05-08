---
prefix: service
title: Add CreateProjectSheet with form validation
status: done
branch: service-0025
---

## Description

Add the create-project sheet reachable from the Projects tab's `+` icon. Posts `CreateProjectRequest` to the backend and pushes the new project's detail on success. Surfaces server-side `ProblemDetails.errors` field-level validation messages on the corresponding form fields.

Depends on `service-projects-list.md`, `infra-openapi-regen.md`. See `docs/feature_plans/30-screens.md` (section 2).

## Acceptance criteria

- [ ] `Features/Projects/CreateProjectSheet.swift` is a SwiftUI sheet view backed by `CreateProjectViewModel`.
- [ ] Form fields:
  - **Name** (required, min length 1).
  - **Local repo path** (required, min length 1).
  - **Slug** (optional — auto-derived from name as kebab-case; user may override).
  - **Git repo URL** (optional).
  - **Tagline** (optional, single line).
  - **Description** (optional, multi-line).
  - **Accent** (`AccentSwatchPicker` — defaults to `.iris`).
  - **Icon** (single character text field — defaults to first character of name).
  - **Status** (segmented control — `.active`, `.maintenance`, `.paused` — defaults to `.active`).
  - **Pinned** (toggle — defaults to off).
- [ ] Submit button is disabled while required fields are empty. While submitting: button shows `ProgressView`, form fields are disabled.
- [ ] On success: dismiss the sheet, push `AppRoute.projectDetail(idOrSlug: project.slug)` onto the Projects tab's stack, refresh the projects list.
- [ ] On `ProblemDetails.errors`, render the field-level message under each affected field. Map `field` JSON path to local form field via a small `FieldErrorMapper`.
- [ ] On other errors (network, generic problem), show an inline error banner above the submit button with the `ProblemDetails.detail` or generic message.
- [ ] Slug auto-derivation: lowercase, trim, replace runs of non-alphanumeric with `-`, strip leading/trailing `-`. The user can edit it; once edited, stop auto-deriving.
- [ ] Tests:
  - View model rejects empty name and empty path before submit.
  - View model maps `FieldError(field: "slug", code: "conflict", ...)` to the slug field.
  - Successful submit calls `repository.createProject` with the right body.
- [ ] `#Preview` renders the sheet pre-filled with sample data.

## Notes

- The sheet should be presentable from anywhere — accept a callback `onCreated: (Project) -> Void` so the caller can decide whether to push the detail or just refresh.
- Bundle ID is **not** an input. Let the backend derive it from slug if it needs one. The contract doesn't surface bundle IDs.
- The accent picker in the form must match the `AccentSwatchPicker` used in the You screen — same component.
- For the icon, accept up to 4 characters but display only the first 2 in the project mark. Some users may paste an emoji.
- Auto-pinning new projects is a UX decision — leave as off; the user pins on the list screen.
