---
prefix: docs
title: Update AGENTS.md and claude.md to reflect the 5-tab v2 shell
status: todo
branch:
---

## Description

The current `AGENTS.md` and `ios_apps/claude.md` describe a navigation shell where the terminal is a top-level tab and `RootCoordinator` owns five typed routes (`projectList`, `projectDetail(...)`, `featureDetail(...)`, `sessionDetail(...)`, `paneText(...)`).

The v2 design replaces this with a 5-tab bottom bar (Inbox / Projects / Roadmap / Sessions / You) and treats the terminal as a full-screen drill-down reached from Sessions or from Inbox `Open pane` actions — not as a top-level tab. Update the documentation to match before screen tickets begin so contributors don't build to the wrong shape.

## Acceptance criteria

- [ ] `AGENTS.md` ▸ `Navigation` section lists the 5 tabs (Inbox, Projects, Roadmap, Sessions, You) and notes that the terminal is a full-screen drill-down, not a tab.
- [ ] `AGENTS.md` ▸ `Navigation` updates the `AppRoute` examples to include `agentSession(sessionID:)`, `ticketDetail(publicID:)`, `docDetail(docID:)`. Removes `paneText(...)` (which was tab-specific).
- [ ] `AGENTS.md` ▸ `Directory Structure` adjusts the Features tree to reflect the new screens (`Inbox/`, `Projects/`, `Roadmap/`, `Sessions/`, `You/`, `Terminal/`, `Review/`).
- [ ] `AGENTS.md` ▸ `Backend Contract` ▸ API Surface table is rebuilt from `../api/openapi.yaml` to include Tickets, Acceptance Criteria, Docs, Decisions, Activity, Agent Sessions, and Review endpoints. The old "Sessions and panes" subsection stays for tmux raw sessions.
- [ ] `AGENTS.md` ▸ `Type Generation` lists the additional generated types: `Ticket`, `AcceptanceCriterion`, `Doc`, `Decision`, `ActivityEvent`, `AgentSession`, `TicketDiff`, `FileDiff`.
- [ ] `AGENTS.md` ▸ `Terminal Tab Requirements` is renamed to `Terminal Surface Requirements` and removed from the "tab" framing. Behavior bullets stay.
- [ ] `ios_apps/claude.md` mirrors the same changes (it's a near-duplicate of `AGENTS.md` — keep them in sync; do not let them drift).
- [ ] A short `## v2 design reference` section in both files links to `claude_design_references/remote-coding-platform/README.md` and `docs/feature_plans/00-overview.md`.
- [ ] `docs/project_plans/mobile_visual_architecture.md` and `mobile_gap_analysis.md` get a one-paragraph header note: "Superseded by `docs/feature_plans/` for the v2 design. Kept for historical context."
- [ ] No breaking changes to the parent `CLAUDE.md` (root repo) — this ticket only edits files under `ios_apps/`.

## Notes

- Avoid rewriting prose that's still accurate. The Layer Responsibilities table, MVVM with Observation guidance, OpenAPI-as-source-of-truth rules, and Testing notes all stay.
- Be mindful that some workhistory files reference the old terminal-as-tab phrasing. Don't rewrite those — they are historical artifacts of completed branches.
- Keep this ticket purely documentation. Code changes that flow from the new shell live in `service-tab-shell.md` and `service-app-route-coordinator.md`.
