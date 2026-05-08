---
prefix: service
title: Feature detail Sessions sub-tab — agent sessions list and spawn flow
status: done
branch: service-0024
---

## Description

Build the Sessions sub-tab on Feature Detail. Lists `AgentSession`s scoped to the feature (fetched per-ticket) and provides the `Spawn session` flow that creates a new agent session bound to a chosen ticket.

Depends on `service-feature-detail.md`, `service-repo-agent-sessions.md`, `service-repo-tickets.md`, `infra-component-kit.md`. See `docs/feature_plans/30-screens.md` (section 7 + 9).

## Acceptance criteria

- [ ] `Features/FeatureDetail/Tabs/FeatureSessionsTab.swift` renders a `RoundedCard` list of `SessionRow`s scoped to the feature. Group by state if the feature has ≥4 sessions; flat otherwise.
- [ ] `SessionRow` (shared with the global Sessions list — extract to `Core/Components/`):
  - State dot (state-colored, pulse for `active` and `awaiting-input`).
  - Mono `session.id` (13pt weight 600), mono `session.pane` (`agent:1.0`), mono `uptime` trailing.
  - 14pt parent ticket title (resolves from `session.ticket_id` via `repository.getTicket(publicID:)`).
  - 6pt accent pip (feature accent) + mono `FEAT-019 · TMX-0048` + mono CPU% (green when >10).
  - Chevron.
- [ ] Tap pushes `AppRoute.agentSession(sessionID:)`.
- [ ] Footer `Spawn session` button opens `SpawnSessionSheet`:
  - Ticket picker (lists all tickets in this feature, defaults to the most recently updated one).
  - Optional override `tmux_session` (string, hidden behind a "Show advanced" disclosure).
  - Optional starting `state` (segmented; default `idle`).
  - Submit calls `repository.createAgentSession(_: CreateAgentSessionRequest(...))`.
  - On success, dismiss and push `AppRoute.agentSession(sessionID:)`.
- [ ] Empty state: when no sessions exist, render `EmptyState(title: "No sessions yet", body: "Spawn a session to start working on a ticket.")` plus the same `Spawn session` button.
- [ ] Tests: feature-scoped session list filters by ticket→feature membership; spawn returns a new session and pushes the terminal route.
- [ ] `#Preview` for FEAT-018 shows session-04 / session-07 in mock.

## Notes

- Resolving session→ticket→title in a list is N+1 by default. Pre-fetch tickets once per feature, then resolve from a `Dictionary<String, Ticket>` keyed by `public_id`.
- The dense design's `SessionRow` shows the parent feature pip + IDs. On a feature-scoped list, the `FEAT-` part is redundant — keep it visible for consistency with the global Sessions list.
- `SpawnSessionSheet` should also be reachable from the Feature Detail footer (when the Tickets tab is active). The "Spawn session" button there opens the same sheet.
- Don't crash if the picker runs in a feature with zero tickets — disable the spawn button with a hint "Create a ticket first" pointing to the Tickets tab.
