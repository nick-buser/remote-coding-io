---
prefix: service
title: Add Ticket review actions — diff, approve, request-changes, send-back
status: done
branch: service-0012
---

## Description

Add the per-ticket review endpoints to the repository layer:
- `GET /api/v1/tickets/{publicId}/diff` → `TicketDiff`
- `POST /api/v1/tickets/{publicId}/approve`
- `POST /api/v1/tickets/{publicId}/request-changes` (with optional comment)
- `POST /api/v1/tickets/{publicId}/send-back` (with optional comment)

These power the Review screen (`service-review-screen.md`) and the Inbox row's `Approve` inline action.

Depends on `infra-openapi-regen.md` and `service-repo-tickets.md`. See `docs/feature_plans/30-screens.md`.

## Acceptance criteria

- [x] `TmuxAgentRepository` adds:
  - `func getTicketDiff(publicID: String) async throws -> Components.Schemas.TicketDiff`
  - `func approveTicket(publicID: String) async throws -> Components.Schemas.Ticket`
  - `func requestTicketChanges(publicID: String, comment: String?) async throws -> Components.Schemas.Ticket`
  - `func sendTicketBack(publicID: String, comment: String?) async throws -> Components.Schemas.Ticket`
- [x] `LiveTmuxAgentRepository` wires to `getTicketDiff`, `approveTicket`, `requestTicketChanges`, `sendTicketBack` generated operations. The optional comment serializes as `ReviewActionRequest { comment }`.
- [x] `MockTmuxAgentRepository` returns a fixture `TicketDiff` for at least TMX-0050 (the design's example) with at least 2 `FileDiff`s, one with `change == .modified` and one with `change == .added`. `old_content` and `new_content` differ in 5+ lines so a unified-diff render is meaningful.
- [x] Mock `approveTicket` flips the ticket's `status` to `done` and emits an `ActivityEvent(kind: .approve)`.
- [x] Mock `requestTicketChanges` keeps `status == review`, emits `ActivityEvent(kind: .review, detail: comment)`.
- [x] Mock `sendTicketBack` flips `status` to `doing`, emits `ActivityEvent(kind: .check, detail: comment)`.
- [x] Tests:
  - `getTicketDiff` returns a `TicketDiff` with non-empty `files`. `binary == true` files have empty `old_content`/`new_content`.
  - Each review action returns the updated `Ticket` with the new status.
  - Each review action surfaces a corresponding ActivityEvent in the mock activity store.
- [x] Project builds.

## Notes

- `TicketDiff.base` and `TicketDiff.branch` are git ref strings (e.g., `main`, `feat/tmx-0050-diff-viewer`). Render them in the Review screen header.
- `FileDiff.change == .renamed` carries `old_path` — the screen displays it as `old_path → path`.
- `FileDiff.binary == true` rows render as `[binary file]` in the diff view; the screen does not attempt to show byte content.
- The mock fixture should produce a diff whose unified rendering exercises +/-/context lines plus a hunk header; this lets the Review screen UI be verified end-to-end on previews.
- Computing a unified diff from `old_content` and `new_content` is the screen's job (or a small helper in `Core/Components/Diff/`). The repository returns the raw text — do not pre-format it.
