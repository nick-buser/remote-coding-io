---
prefix: service
title: Project edit, pin, status, and delete actions
status: done
branch: service-0026
---

## Description

Wire the destructive and metadata actions on a project: edit (reuses `CreateProjectSheet` in edit mode), pin/unpin (toggle on the list and detail), status change, and delete with confirmation.

Depends on `service-projects-list.md`, `service-projects-create.md`, `service-project-detail.md`. See `docs/feature_plans/30-screens.md` (section 2 + 3).

## Acceptance criteria

- [ ] `CreateProjectSheet` accepts an optional `existingProject: Project?` parameter. When non-nil, the sheet pre-fills fields and the submit button reads "Save changes" (calls `updateProject(idOrSlug:body:)`).
- [ ] On the Projects list, the row's long-press context menu wires:
  - `Pin` / `Unpin` → calls `updateProject` with the toggled `pinned` value. List re-sorts.
  - `Edit` → presents `CreateProjectSheet(existingProject: project)`.
  - `Delete` → presents a `confirmationDialog` with `Delete <name>?` and a destructive `Delete` button. On confirm, calls `repository.deleteProject(idOrSlug:)` and removes the row.
- [ ] On Project Detail, the dots menu wires the same `Edit` / `Pin` / `Delete` actions plus `Open in tmux` (calls `repository.openProjectSession(idOrSlug:)` and updates the project's `tmux_session_name`).
- [ ] Status change is exposed as a long-press menu on the project's status pill in the detail header — opens an action sheet to pick `.active / .maintenance / .paused`. Calls `updateProject`.
- [ ] Optimistic updates: the UI updates immediately on action, with a rollback if the request fails. Show a toast / banner on rollback.
- [ ] Tests:
  - Pin toggle round-trips through the mock and re-orders the list.
  - Delete removes the project and prevents stale navigation back into its detail.
  - `Open in tmux` populates `tmux_session_name` if previously nil.
- [ ] `#Preview` renders the edit sheet with a pre-filled project.

## Notes

- Deleting a project that owns active features should still succeed (the contract handles cascade — verify in mock). Surface a 409 conflict gracefully if the backend rejects.
- The status change UI is small; don't make it a full sheet. An action sheet (`confirmationDialog` with `.destructive` styling for `paused`) is enough.
- Don't introduce a separate edit form — reuse the create sheet to keep one source of truth.
