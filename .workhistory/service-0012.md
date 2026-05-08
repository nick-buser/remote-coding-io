# service-0012: Ticket review actions — diff + approve / request / send-back

Ticket: `.tickets/done/service-repo-review.md`

## Summary

Closes Phase 2 of the v2 plan. The Review screen and the
Inbox row's Approve inline action both need a backend-shaped
data layer; the contract exposes
`getTicketDiff / approveTicket / requestTicketChanges /
sendTicketBack` for that. This branch lands all four
end-to-end (live OpenAPI client + mock + tests) so Phase 3
screen tickets can compose against them without further
contract work.

## Changes

- `TmuxAgentRepository` gains four methods:
  - `getTicketDiff(publicID:)`
  - `approveTicket(publicID:)`
  - `requestTicketChanges(publicID:comment:)`
  - `sendTicketBack(publicID:comment:)`
- `LiveTmuxAgentRepository` wraps the matching generated
  operations. The optional reviewer comment serializes as
  `Components.Schemas.ReviewActionRequest { comment }` even
  when nil (the contract accepts an empty body, but pinning
  the body to `.json(...)` keeps the live and mock paths in
  the same shape).
- `MockTmuxAgentRepository` seeds a fixture `TicketDiff` for
  TMX-0050 with two `FileDiff`s — one `.modified`
  (`DiffViewer.swift`, small refactor that adds a
  `NavigationSplitView`) and one `.added`
  (`DiffPaneView.swift`). Both files carry text content
  five-plus lines apart so a unified-diff render exercises
  +/-/context lines plus a hunk header.
- Mock `approveTicket` flips ticket status to `.done` and
  emits `ActivityEvent(kind: .approve)`. Mock
  `requestTicketChanges` keeps status `.review` and emits
  `ActivityEvent(kind: .review, detail: comment)`. Mock
  `sendTicketBack` flips to `.doing` and emits
  `ActivityEvent(kind: .check, detail: comment)`. All three
  reuse the activity event surface landed in
  `service-repo-activity` so the Inbox / poller picks them
  up through the same path the design uses.
- Four new `remote_codingTests` cover the diff fixture
  shape (modified + added FileDiffs, populated content) and
  each action's status transition + ActivityEvent
  side-effect with the comment carried through to
  `detail`.

## Decisions

- **Send-back uses `kind == .check`, not a dedicated kind.**
  The `ActivityKind` enum has no `.sendBack` case; `.check`
  is the closest fit ("operational, not a review verdict").
  If product feedback wants a dedicated kind later that's a
  contract change.
- **`requestTicketChanges` and `sendTicketBack` both take
  `comment: String?`.** The contract's `ReviewActionRequest`
  has `comment` as optional. Surfacing it through a single
  parameter rather than a wrapper struct keeps the call
  sites at the screen layer terse — a `Button("Approve")
  { Task { try await repo.approveTicket(publicID: id) } }`
  ergonomic versus a builder.
- **`approveTicket` does not take a comment.** The contract
  endpoint does not accept a body. Keeping the parameter
  list off avoids a misleading API surface where a passed
  comment would silently be dropped.
- **Diff fixture lives only on TMX-0050.** Phase 3's
  Review screen ticket has TMX-0050 as its example; seeding
  one ticket keeps the fixture set focused. Other tickets
  return `MockRepositoryError.notFound` on
  `getTicketDiff`, which mirrors the contract's 404 for a
  ticket without a diff.
- **Mock review actions also bump `Ticket.updatedAt`.** Each
  status transition is also a mutation; views that sort
  tickets by recently-updated would otherwise miss the
  approval. Mirrors the same convention `updateTicket` and
  the criterion-mutation paths use.
- **Activity emission is best-effort, not transactional.**
  Live calls don't roll back if the server fails to emit
  the activity event — the contract documents the activity
  emission as a server-side side-effect. The mock emits
  unconditionally because there is no failure mode to
  consider.

## Notes

- `TicketDiff.base` and `TicketDiff.branch` are git refs
  (e.g. `main`, `feat/tmx-0050-diff-viewer`). The Review
  screen header will paint them. Renamed files would
  surface `old_path` (rendered as `old_path → path`); the
  fixture has none, so that path is exercised by the
  screen ticket's tests rather than this one's.
- `FileDiff.binary == true` rows would render as
  `[binary file]` in the diff view. The fixture has no
  binary entries — that path is reserved for a follow-up
  fixture once `service-review-screen` lands.
- Computing a unified diff from `oldContent` and
  `newContent` is the screen's job (or a small helper
  under `Core/Components/Diff/`). The repository returns
  the raw text — do not pre-format it. Doing it
  client-side keeps the wire payload small for large
  diffs.
- This branch closes **Phase 2** of the v2 plan. Phase 3
  is the long parallel rollout of screen tickets: Inbox,
  Projects list / detail, Feature detail tabs (Tickets /
  PRD / Decisions / Sessions), Roadmap, Sessions, Review,
  You. Every screen ticket can run in parallel because
  each only touches its own `Features/` directory plus
  the existing repository methods.
- This work-history note ships in `chore-0001` rather
  than the next ticket's branch because the chain that
  closed Phase 2 (service-0008..0012) merged in a stack
  before a Phase-3 follow-up was branched. From service-0008
  onward each ticket's bookkeeping lands on the next
  ticket's first commit; this is the one-time tail
  cleanup.
- `xcodebuild build test` was not run on the originating
  branch (Linux dev environment, no Swift toolchain).
  Build + test verification was deferred to local Xcode
  ahead of merge.
