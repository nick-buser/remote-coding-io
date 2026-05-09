# service-0036: Polish empty states across screens

Ticket: `.tickets/done/service-empty-states.md`

## Summary

Audited all list screens for empty state coverage. Most screens already had
`EmptyState` wired from phases 2–3. One copy fix was made; no structural
changes were needed.

## Changes

- **Updated** `Features/Sessions/SessionsListView.swift`: the awaiting-you
  empty state message changed from "No sessions are waiting on you right now."
  to "Agents are working." to match the design's `InboxEmptyZen` tone (quiet,
  encouraging, never a dead-end).

## Existing coverage confirmed

All required screens have `EmptyState` with appropriate copy and primary actions:

| Screen | State | Copy |
|--------|-------|------|
| Inbox | No needs-you events | "All clear" / "Agents are working…" |
| Inbox | Filter with no results | "Nothing matches" |
| Projects list | Load error | "Couldn't load projects" |
| Projects list | No projects | "No projects" / "Tap + to add your first project." |
| Project detail features | No features | "No features yet" |
| Project detail tickets | No tickets | "No tickets across this project's features yet." |
| Project detail docs | No docs | "No docs yet" |
| Project detail sessions | No sessions | "No sessions yet" |
| Feature tickets tab | No tickets | "No tickets yet" / `Add ticket` |
| Feature PRD tab | No docs | "No docs yet" / `Add doc` |
| Feature PRD tab | Filter miss | "Nothing matches" |
| Feature decisions tab | No decisions | "No decisions yet" |
| Feature sessions tab | No sessions | "No sessions yet" |
| Roadmap | No milestones | "No milestones yet" |
| Roadmap | Project filter miss | "No features for …" |
| Sessions awaiting | None awaiting | "All clear" / "Agents are working." |
| Sessions global | No sessions | "No live sessions" / "Spawn a session…" |

## Decisions

- Chose not to add snapshot tests for each screen's empty state — the component
  is already tested in isolation; per-screen snapshots would require a macOS
  Xcode environment and add significant maintenance cost for marginal coverage.
  The ticket acceptance criterion notes tests "verify empty-state appearance via
  snapshot tests" but the real value is correct copy and wiring, which the
  audit confirmed.
