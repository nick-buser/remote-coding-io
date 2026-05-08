---
prefix: service
title: Build Ticket review screen — diff, criteria, approve/request actions
status: done
branch: service-0019
---

## Description

Build the Review screen reachable from Inbox `Open diff` actions and from a ticket's row in `review` status. Header shows the ticket meta (`TMX-0050 · In review · branch · +M/−N · n files`); body has a segmented control (Diff / Checklist / Files) and a sticky footer with `Request changes` / `Approve & merge`.

Depends on `service-app-route-coordinator.md`, `service-repo-tickets.md`, `service-repo-review.md`, `infra-component-kit.md`. See `docs/feature_plans/30-screens.md` (section 10).

## Acceptance criteria

- [ ] `Features/Review/TicketReviewView.swift` mounts on `AppRoute.ticketDetail(publicID:)` when ticket status is `review` (otherwise route falls back to a `TicketDetailView` placeholder).
- [ ] `Features/Review/TicketReviewViewModel.swift` loads ticket, criteria, and diff in parallel.
- [ ] Header:
  - `BackChevron("Inbox")` (or whichever route brought us — fall back to "Back").
  - Trailing dots menu with `Send back to doing`, `Mark in review`, `Edit ticket`.
  - Hero: HStack { mono `TMX-0050`, status pill `In review` (iris-tinted) }, 22pt display `ticket.title`, mono `actor · branch_name · +<adds>/<dels> · <n> files`.
- [ ] `SegmentedControl(["Diff", "Checklist <done>/<total>", "Files"])`.
- [ ] **Diff** body: per-file `DiffViewer`:
  - File header: mono path (12pt fg2), `+M / −N` summary, change badge (added / modified / deleted / renamed). Renamed shows `old_path → path`.
  - Body: monospace pre-formatted unified diff between `old_content` and `new_content`. Green-tinted `+` lines, red-tinted `-` lines, gray context lines.
  - Binary files render `[binary file]` placeholder.
- [ ] **Checklist** body: list of `AcceptanceCriterion` rows. Each row: 18pt rounded checkbox (filled green ✓ when `done`), text (strikethrough when done), trailing edit affordance disabled (read-only on this screen).
- [ ] **Files** body: a flat list of file paths grouped by change type (Added / Modified / Deleted / Renamed). Tap a path scrolls the Diff view to that file.
- [ ] Sticky footer (kept in safe area above keyboard):
  - `PillButton("Request changes", secondary, wide)` → opens a sheet with a comment textarea + Submit. Calls `repository.requestTicketChanges(publicID:comment:)`.
  - `PillButton("Approve & merge", primary, wide)` with the user's accent → calls `repository.approveTicket(publicID:)`.
- [ ] On any successful action: refresh activity feed, dismiss the screen via `coordinator.popToRoot(in: .inbox)` (or pop one level if pushed from a different tab).
- [ ] Loading skeleton: render header skeleton + `ProgressView` for the body. Error: `EmptyState(title: "Couldn't load review", body: ..., retry: ...)`.
- [ ] Tests:
  - Unified diff helper produces correct context / +/- spans against fixture content.
  - `Approve & merge` calls the right repo method and pops the screen.
  - `Request changes` carries the comment in the request body.
- [ ] `#Preview` for TMX-0050 with mock diff and criteria.

## Notes

- Implement unified diff via a small `Core/Components/Diff/UnifiedDiff.swift` helper. Use Myers diff or just the simpler longest-common-subsequence approach; performance matters past a few hundred lines but not for typical PR-sized diffs.
- Don't try to wrap long lines in the diff view. Horizontal scroll inside each file body is acceptable and matches the design.
- Mark removed lines with `\u{2212}` minus or `-` ASCII; either is fine. The design shows ASCII.
- Sticky footer with safe-area bottom inset: use `.safeAreaInset(edge: .bottom)`.
- Keep the comment sheet simple — text editor + submit button. No template snippets in v1.
