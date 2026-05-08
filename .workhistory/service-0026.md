# service-0026: Project edit / pin / status / delete

Ticket: `.tickets/done/service-projects-edit.md`

## Summary

Wires the previously-stubbed destructive and metadata actions on
projects:

- **Edit**: `CreateProjectSheet` now accepts `existing: Project?`.
  Pre-fills every field, switches the title to "Edit project", and
  routes the submit button (now reading "Save changes") through
  `updateProject(idOrSlug:body:)`.
- **Pin / Unpin**: optimistic toggle on both the Projects list (the
  long-press context menu wires `viewModel.togglePin` already from
  service-0014) and the Project detail (new dots-menu action with
  rollback on failure).
- **Status**: nested `Menu("Status")` on the Project detail's dots
  menu — picks `.active / .maintenance / .paused` and PUTs through
  `updateProject`.
- **Open in tmux**: dots-menu action calls
  `repository.openProjectSession(idOrSlug:)` and refreshes the
  detail screen.
- **Delete**: a `confirmationDialog` on both surfaces. List
  optimistically removes the row and rolls back on failure;
  detail screen pops itself via `dismiss()` after a successful
  delete.

The repository surface gains `deleteProject(idOrSlug:)` (Live wraps
`client.deleteProject`; Mock cascades the deletion across features
/ tickets / criteria / docs / decisions / activity / agent sessions
so a re-create with the same slug doesn't see leftovers).

## Changes

- `Core/Repositories/TmuxAgentRepository.swift` — protocol gains
  `deleteProject(idOrSlug:) async throws`.
- `Core/Repositories/LiveTmuxAgentRepository.swift` — wraps
  `client.deleteProject`. Maps 204 / 400 / 404 / 503 onto
  `RepositoryError`.
- `Core/Repositories/MockTmuxAgentRepository.swift` — implements
  `deleteProject` with full cascade to keep the mock self-
  consistent. Throws `MockRepositoryError.notFound` when the slug
  doesn't resolve.
- `Features/Inbox/InboxView.swift` — preview-only
  `EmptyInboxRepository` forwards `deleteProject` so the protocol
  stays satisfied.
- `Features/Projects/CreateProjectViewModel.swift` — now accepts
  `existing: Project?`. Pre-fills every form field, marks
  `slugWasManuallyEdited` so name edits don't overwrite the
  existing slug, and gains a `mode` (`.create` / `.edit`).
  `submit(...)` (renamed `onCreated` → `onSubmitted`) routes
  through either `createProject` or `updateProject`. New
  `makeUpdateRequest()` mirrors `makeCreateRequest()` and shares
  field sanitisation through `sanitisedCore()`.
- `Features/Projects/CreateProjectSheet.swift` — accepts
  `existing` via init, switches navigation title and submit
  button copy by mode, exposes a second preview for the edit path.
- `Features/Projects/ProjectListView.swift` — context menu drops
  the disabled placeholders. Edit presents
  `CreateProjectSheet(existing:)`; Delete shows a
  `confirmationDialog` and optimistically removes (with rollback
  on error). Pin/Unpin already worked.
- `Features/Projects/ProjectDetailView.swift` — replaces the
  stubbed dots `NavIconButton` with a real `Menu` carrying
  Edit / Pin / Open in tmux / Status / Delete. Optimistic
  Pin/Status updates rebuild a PUT-shaped
  `UpdateProjectRequest` from the local snapshot. Delete pops
  the screen on success via `didDelete`-driven `dismiss()`.
- `remote-codingTests/EditProjectViewModelTests.swift` — Swift
  `Testing` cases covering the new `Mode` switch, edit-mode
  pre-fill, submit routing through `updateProject`, mock
  `deleteProject` cascade + not-found, and the
  `makeUpdateRequest` round-trip.

## Decisions

- **Reuse `CreateProjectSheet` for edit.** Per the ticket note,
  "don't introduce a separate edit form — reuse the create sheet
  to keep one source of truth." The view model's `mode` switch
  drives every divergence (titles, button copy, submit routing).
- **Mock cascade on delete.** Re-creating a project with the same
  slug after a delete shouldn't surface stale features, tickets,
  agent sessions, or activity events; the mock removes everything
  the project owns recursively. Live backend handles this in the
  contract.
- **Optimistic updates with rollback.** Pin / Status / Delete
  flip the local model immediately and revert on failure with an
  inline `actionError` alert. The list flow uses a `previous`
  snapshot for the same pattern.
- **Status menu nested in the dots menu** rather than a long-press
  on the status pill. The pill isn't a button today (no obvious
  tap affordance on a small chip), and the dots menu surface
  already groups every project-level mutation.
- **Project detail's `pin` action keeps the existing tab.** Once
  you pin/unpin from inside the detail, the user expects the
  state to persist when they pop back to the list. The list's
  `viewModel.projects` array is on a separate view-model, so the
  detail's flip doesn't directly mutate it; the next list `task`
  re-fetch picks the change up. Cross-view-model live sync is
  deferred until a shared workspace store exists.

## Notes

- Branched from `service-0025` (post-merge of #32 into main).
  `service-0027` (feature-create) will branch off this branch
  to keep `ProjectListView`/`ProjectDetailView` from
  conflicting between parallel modal PRs.
- The `Project` extension already conforms to `Identifiable`
  (`Core/Network/GeneratedIdentifiable.swift`); the
  `.sheet(item: $editingProject)` and
  `.confirmationDialog(presenting:)` patterns rely on that.
- iOS gates were not exercised in this session (Linux runner
  without Xcode); the suite needs to run on a Mac via the
  `ios-gates` skill before merge.
