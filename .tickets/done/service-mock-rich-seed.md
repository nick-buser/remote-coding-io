---
prefix: service
title: Rebuild MockTmuxAgentRepository fixtures from data.jsx
status: done
branch: service-0037
---

## Description

Replace the current `MockTmuxAgentRepository` JSON fixtures with structured Swift fixtures derived from `claude_design_references/remote-coding-platform/project/data.jsx`. The mocks should render every screen end-to-end exactly as the design intends, so previews and offline runs are demoable without backend access.

Depends on `infra-openapi-regen.md` and the Phase 2 repository tickets. See `docs/feature_plans/20-navigation-and-data.md`.

## Acceptance criteria

- [ ] Fixtures live in `Core/Repositories/MockFixtures/` as typed Swift literals (one file per resource):
  - `MockProjects.swift`: PRJ-01 tmux-agent (iris, pinned), PRJ-02 sift (amber, pinned), PRJ-03 paper-cuts (mint), PRJ-04 ledger-mini (slate, paused).
  - `MockFeatures.swift`: 10 features matching `data.jsx` (FEAT-018..FEAT-022 under tmux-agent, FEAT-031 / 032 under sift, FEAT-040 under paper-cuts, plus FEAT-017 shipped).
  - `MockTickets.swift`: 14 tickets (TMX-0042..TMX-0070 with the right feature mapping).
  - `MockCriteria.swift`: per-ticket criteria with `done` matching the data.
  - `MockDocs.swift`: at least 3 docs per active feature (PRD, vision, notes), each with non-trivial TipTap `body_blocks`.
  - `MockDecisions.swift`: 2–3 decisions per active feature with mixed actor types.
  - `MockActivity.swift`: the 10 events from `data.jsx` (kinds: commit, check, review, doc, decision, question, test, approve).
  - `MockAgentSessions.swift`: session-04 idle, session-05 awaiting-input, session-07 active, session-08 active.
  - `MockMilestones.swift`: v0.3 shipped, v0.4 active, v0.5 planned, v0.6 planned.
- [ ] `MockTmuxAgentRepository` reads from these fixtures. Mutations (create/update/delete) modify the in-memory copies for the lifetime of the app.
- [ ] Fixtures use realistic timestamps (relative to `Date.now`) so "12m ago" / "2h ago" labels read sensibly.
- [ ] Pane output fixtures include 1–2 examples of agent output that contains a `?` prompt (to seed the Inbox question example).
- [ ] Tests verify that the mock returns a complete dataset for every screen — at least one project, one feature, one ticket, one decision, one doc, one agent session, plus activity events of every kind.
- [ ] Removed: the old `projectsJSON / featuresJSON / sessionsJSON` raw JSON strings in `MockTmuxAgentRepository.swift`.

## Notes

- Aim for fixtures that are readable Swift literals (not embedded JSON). Use date helpers like `Date.now.addingTimeInterval(-12 * 60)` for relative timestamps.
- TipTap `body_blocks` for fixture docs can be a small constant `String` per file. Match the design's PRD content where possible (the dense `DocsScreen` shows real PRD copy for FEAT-018).
- Mock activity events should reference real fixture IDs (TMX-0050, FEAT-019, etc.) so the Inbox "Open diff" / "Open pane" routes resolve to real fixtures.
- Coordinate this with `service-repo-*` tickets — those land their own minimal fixtures; this ticket consolidates everything.
