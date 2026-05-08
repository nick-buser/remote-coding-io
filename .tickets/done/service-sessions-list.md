---
prefix: service
title: Build Sessions tab — awaiting-you hero plus status-grouped list
status: done
branch: service-0018
---

## Description

Build the Sessions tab using the hybrid layout: a "Awaiting you" hero block at the top (the zen feel) followed by status-grouped session sections (Active / Awaiting / Idle) with detailed rows. Tap any row to open the terminal.

Depends on `service-tab-shell.md`, `service-app-route-coordinator.md`, `service-repo-agent-sessions.md`, `service-repo-tickets.md`, `infra-component-kit.md`. See `docs/feature_plans/30-screens.md` (section 9).

## Acceptance criteria

- [ ] `Features/Sessions/SessionsListView.swift` mounts inside the Sessions tab.
- [ ] `Features/Sessions/SessionsListViewModel.swift` aggregates agent sessions across the user's projects via `repository.listProjectAgentSessions(projectIDOrSlug:)` per project.
- [ ] Layout:
  - `LargeTitleHeader(title: "Sessions", trailing: plus)`.
  - **Awaiting hero** block: 11pt mono uppercase "Awaiting you", 24pt display "<n> session<s>" counter; for each `awaiting-input` session, a `RoundedCard(radius: 18)`:
    - HStack { state dot, mono session.id, mono uptime trailing }.
    - 17pt ticket title.
    - `PillButton("Open pane", primary)` → `AppRoute.agentSession(sessionID:)`.
  - `ScrollChips(["All", "Active", "Awaiting", "Idle"])` filter row.
  - **Active** section: `SessionRow` list (omit when filter doesn't match).
  - **Awaiting** section: omit if equal to the hero list (otherwise render).
  - **Idle** section: same shape.
- [ ] `SessionRow` (lifted from `service-feature-sessions-tab.md`):
  - StatusDot (green for active, orange for awaiting with pulse, muted for idle).
  - Mono session.id, mono session.pane, mono uptime.
  - 14pt ticket.title.
  - Feature accent pip + mono `FEAT-XXX · TMX-XXXX` + mono CPU% (green when >10).
  - Chevron.
- [ ] Tap row → `AppRoute.agentSession(sessionID:)`.
- [ ] Plus button opens `SpawnSessionSheet` (no feature pre-fill — show a project picker → feature picker → ticket picker).
- [ ] Empty state for filter `Awaiting` when no awaiting sessions: keep the hero counter at 0 with copy "All clear" replacing the cards (use `EmptyState`).
- [ ] Empty state for the entire screen (no sessions across all projects): show a single hero card "No live sessions" with a `Spawn session` button.
- [ ] Pull-to-refresh.
- [ ] Tests: state grouping correctness; hero count matches awaiting filter; spawn opens picker chain.
- [ ] `#Preview` shows the design's 4-session mock.

## Notes

- Cross-project session aggregation is N requests over project list. Cache per-launch and refresh on activity events with `kind ∈ {commit, test, review, question, approve}` (subscribe to the workspace `ActivityPoller`).
- Avoid showing the awaiting hero AND the awaiting section simultaneously when they contain the same items. Render one or the other (hero wins when count ≤ 3; section wins beyond that).
- The dense `SessionRow` includes uptime; compute it from `start_time` rather than reading a server-side `uptime` field. Re-render once per minute via a `TimelineView` (or simpler `Text(start, style: .relative)`).
- The status dot's pulse animation: SwiftUI `.symbolEffect(.pulse)` on iOS 17+, otherwise a manual `withAnimation` opacity oscillation.
