---
prefix: service
title: Build Inbox screen with activity feed and inline actions
status: todo
branch:
---

## Description

Build the Inbox tab — the v2 home screen — using the activity poller from `service-repo-activity.md`. The dense "Needs you" + "Earlier today" two-section layout is the default; tapping an inbox row pushes a focused detail (review screen, terminal, doc viewer, decision detail) depending on `kind`.

Depends on `service-tab-shell.md`, `service-app-route-coordinator.md`, `service-repo-activity.md`, `infra-component-kit.md`. See `docs/feature_plans/30-screens.md` (section 1).

## Acceptance criteria

- [ ] `Features/Inbox/InboxView.swift` mounts inside the Inbox tab's `NavigationStack`.
- [ ] `Features/Inbox/InboxViewModel.swift` is `@Observable @MainActor`. State: `events: [ActivityEvent]`, `selectedFilter: InboxFilter`, `isLoading: Bool`, `error: String?`.
- [ ] The view renders, in order:
  - `LargeTitleHeader(title: "Inbox", subtitle: "<n> need you · <m> sessions live")` with trailing icons `filter` and `compose`.
  - `ScrollChips(["All", "Questions", "Reviews", "Decisions", "Mentions"])` bound to `selectedFilter`. Each chip shows a count when ≥1 matching event.
  - Section "Needs you" with a `RoundedCard` of `InboxRow`s — events with `kind ∈ {question, review}` plus `kind == decision` events newer than 1 hour.
  - Section "Earlier today" with a `RoundedCard` of `InboxRow`s — remaining events from the current local day.
- [ ] `InboxRow` renders per the design:
  - 32pt `KindIcon` square (color from `kind`).
  - Mono target ID (TMX-0050 / FEAT-018 / etc.) tinted with the related project / feature accent (resolved by looking up `event.project_id` / `event.feature_id`).
  - `· session-07` actor name in fg2 (uses `event.actor_name`).
  - Mono `2h` timestamp pinned right (`event.created_at` formatted relative).
  - 14pt `event.detail` (or `event.verb` if detail is empty) body.
  - For `kind == question`: inline `Reply` (primary) + `Open pane` (secondary) buttons.
  - For `kind == review`: inline `Approve` (primary) + `Open diff` (secondary) buttons.
- [ ] Tap targets:
  - Question row body / `Open pane` → push `AppRoute.agentSession(...)` resolved from `event.ticket_id`.
  - Review row body / `Open diff` → push `AppRoute.ticketDetail(...)` (the review screen).
  - Other kinds (commit, test, check, doc, decision, approve) → push the most appropriate detail or open a brief detail sheet.
  - `Reply` action → open a sheet with a text input that calls `repository.sendPaneInput(...)` to the resolved agent session's pane. (Initial impl: hand-off to terminal — replace with a proper reply sheet in a follow-up if needed.)
  - `Approve` action → call `repository.approveTicket(publicID:)` and remove the row.
- [ ] When `selectedFilter != .all`, sections collapse to filtered events. Empty matching state shows `EmptyState`.
- [ ] When the workspace activity feed is empty of "needs you" events: render `InboxEmptyZen` style — 72pt circle + envelope glyph, "All clear" title, "Agents are working. They'll find you here when they need something." body. The Earlier today section still renders below if it has events.
- [ ] Pull-to-refresh kicks the poller manually.
- [ ] `viewModel.markSeen()` is called when the view appears (clears `needsYou` on the tab bar).
- [ ] Tests:
  - View model groups events into "Needs you" / "Earlier today" correctly.
  - Filter chips count match the event predicate.
  - Tapping `Approve` calls `repository.approveTicket` and refreshes the list.
- [ ] `#Preview` renders Inbox in light + dark with the mock fixtures.

## Notes

- The events come from `ActivityPoller.events`, not a one-shot fetch. Subscribe via the `@Observable` macro.
- `event.detail` may contain newlines — clamp to two lines in the row, full text in the row's expanded detail view (push on tap when no inline button is present).
- The `compose` icon in the trailing slot opens a free-form text post that emits an `ActivityEvent(kind: .doc | .decision)` depending on what the user picks. Defer the actual sheet to a follow-up; for this ticket the icon is a button that prints to the console (or calls a stub).
- Resolving the row's accent: build a small in-memory `accentResolver(projectID:Int64?)` in the view model that caches `Project.accent` lookups via a single `repository.listProjects()` snapshot.
- Don't fetch heavy data per row. `event` already carries everything the row needs except the project accent and a label for the target ID.
