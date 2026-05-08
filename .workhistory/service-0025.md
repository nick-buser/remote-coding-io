# service-0025: Create-project sheet + repository createProject

Ticket: `.tickets/done/service-projects-create.md`

## Summary

Adds `CreateProjectSheet` — the form sheet behind the Projects tab's
`+` icon. The Projects-list placeholder sheet is replaced with the
real form, which on success prepends the new project to the list,
re-sorts, and pushes `.projectDetail(idOrSlug:)` on the Projects
tab's stack.

This ticket also extends the repository surface with
`createProject(_:body:)` (LiveTmuxAgentRepository wraps the
generated `client.createProject`; MockTmuxAgentRepository validates
required fields, derives a slug fallback, and rejects slug
conflicts with a typed `MockRepositoryError.problem`). The mock
parity matches the live response shape so the sheet's error
handling is exercised end-to-end against `RepositoryError.problem`
(live) and `MockRepositoryError.problem` (mock).

## Changes

- `Core/Repositories/TmuxAgentRepository.swift` — protocol gains
  `createProject(_:) async throws -> Project`.
- `Core/Repositories/LiveTmuxAgentRepository.swift` — wraps
  `client.createProject(.init(body: .json(body)))`. Maps the
  201 / 400 / 409 / 503 response cases onto `RepositoryError`.
- `Core/Repositories/MockTmuxAgentRepository.swift` — validates
  `name` and `local_repo_path`, derives a slug if absent (the
  static `deriveSlug(from:)` mirrors the form's helper), enforces
  uniqueness, and inserts the new project with a generated id.
  `MockRepositoryError` gains a new `.problem(field:code:message:)`
  case + `LocalizedError` conformance so the sheet can surface
  the message under the offending field.
- `Features/Projects/CreateProjectViewModel.swift` — `@Observable
  @MainActor`. Tracks form fields, gates submit on required
  fields, drives slug auto-derivation, and routes server / mock
  errors through `apply(problem:)` and a typed `Field` enum. The
  `fieldErrorMapper` accepts contract snake-case + Swift camelCase
  + nested paths (`slug.format`) so errors land on the right field
  regardless of which side emits them.
- `Features/Projects/CreateProjectSheet.swift` — SwiftUI form view.
  Sections: Identity (name / slug / path), Details (git URL /
  tagline / description), Appearance (`AccentSwatchPicker` +
  icon), Status (segmented + pinned toggle). Per-field inline
  errors render below the offending field; a banner section at
  the top of the form surfaces non-field errors.
- `Features/Projects/ProjectListView.swift` — replaces the
  placeholder `EmptyState` sheet with `CreateProjectSheet` and
  prepends the result to the local list, re-sorts via the
  existing static helper, and pushes `.projectDetail` so the
  user lands directly on the new screen.
- `Features/Inbox/InboxView.swift` — the preview-only
  `EmptyInboxRepository` forwards `createProject` to its
  underlying mock so the protocol stays satisfied.
- `remote-codingTests/CreateProjectViewModelTests.swift` — Swift
  `Testing` cases covering submit gating, slug auto-derivation /
  manual-edit lockout, the field-error mapper (contract +
  camelCase + nested), and two mock-backed integration paths
  (success roundtrip + slug-conflict mapping to `.slug`).

## Decisions

- **Mock parity for validation errors.** Throwing a typed
  `MockRepositoryError.problem(field:code:message:)` from the
  mock keeps the form's error-mapping code path identical to the
  live `RepositoryError.problem(ProblemDetails)` path. The view
  model has two `catch` arms but the visible behavior matches.
- **`fieldErrorMapper` accepts both snake_case and camelCase.**
  The contract emits `local_repo_path` but the generated Swift
  type is `localRepoPath`; mapping both shields the form from
  whichever convention the server emits today.
- **Slug auto-derivation runs while
  `slugWasManuallyEdited == false`.** Once the user types into
  the slug field directly, `nameChanged` stops overwriting it.
  The detection compares the new slug value against
  `deriveSlug(name)`; values that differ are treated as
  user-edited.
- **`onCreated` callback over a hard-coded post-create
  navigation.** The sheet hands the new project back; the parent
  decides whether to push detail / refresh / both. Lets the
  same sheet ship from the You-screen empty state in a future
  ticket without a refactor.
- **Banner-vs-field error split.** Field-level
  `ProblemDetails.errors` populate `fieldErrors`; everything
  else (network, undocumented status) lands on `bannerError`.
- **Pinned defaults to off.** Per the ticket note, the user pins
  on the list screen rather than pre-selecting on create.

## Notes

- Branched from updated `main` (post-rollup of the sub-tab
  batch). The next two modal tickets (`service-projects-edit`,
  `service-feature-create`) will stack off this branch since
  they touch the same `ProjectListView` / `ProjectDetailView` /
  `MockRepositoryError` surfaces.
- `ProblemDetails`-direct construction tests were intentionally
  omitted — the generator's reserved-keyword label (`type` vs
  `_type`) is uncertain without a build, and the mock-backed
  paths cover the same logic.
- iOS gates were not exercised in this session (Linux runner
  without Xcode); the suite needs to run on a Mac via the
  `ios-gates` skill before merge.
