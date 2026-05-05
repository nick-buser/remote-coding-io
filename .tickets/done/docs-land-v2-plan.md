---
prefix: docs
title: Land the v2 design plan, ticket backlog, and supporting tooling
status: done
branch: docs-0004
---

## Description

Commit the in-flight planning materials so subsequent ticket PRs aren't polluted with 50+ unrelated files. This PR is housekeeping only — no behavior changes to the app.

What lands here:

- **Design references** (`claude_design_references/remote-coding-platform/`) — the Claude Design v2 bundle (HTML canvas, JSX components, mock data, tokens).
- **Feature plans** (`docs/feature_plans/00-overview.md`, `10-design-system.md`, `20-navigation-and-data.md`, `30-screens.md`, `40-terminal.md`) — the five-phase plan that sequences the rest of the work.
- **Ticket backlog** (`.tickets/<various>.md`) — every Phase 0–5 ticket described in the overview.
- **Workflow infrastructure** — `.tickets/.gitkeep`, `.tickets/done/.gitkeep`, `.workhistory/.gitkeep`, the rename `docs/workhistory/*` → `.workhistory/*`, a project `README.md`, and the previously-staged `claude.md` / `AGENTS.md` ticket-system + work-history templates.
- **Tooling additions** — `.claude/settings.json` (team-wide permission allowlist for routine iOS commands), `.claude/commands/ios-gates.md` (the `/ios-gates` slash command that wraps `xcodebuild build test`), and `.gitignore` updates to keep `.claude/settings.local.json` per-user.
- **Doc additions** in `claude.md` / `AGENTS.md`: pointer to `docs/feature_plans/00-overview.md`, the per-prefix branch-numbering rule, the `gh`-vs-`tea` clarification, and the iOS gates snippet. The deeper v2 rewrite (5-tab shell, terminal-as-drill-down, expanded API surface) is reserved for `docs-update-agents-shell` per the overview's Phase 0 list.

## Acceptance criteria

- [ ] All planning files (design refs, feature plans, ticket backlog) are committed and visible on `origin/docs-0004`.
- [ ] `claude.md` and `AGENTS.md` carry the new `Active plan` pointer, the per-prefix numbering bullet, and the `Verifying iOS work` section — and stay in sync with each other.
- [ ] `.claude/settings.local.json` is gitignored; `.claude/settings.json` is committed.
- [ ] PR opens cleanly via `gh pr create` against `nick-buser/remote-coding-io`.
- [ ] No app source files are modified — `remote-coding/` is untouched in this PR.

## Notes

- The next ticket per the phase plan is `infra-openapi-regen` (Phase 0). Pick it up after this PR merges.
- The full v2 rewrite of `claude.md` / `AGENTS.md` happens later under `docs-update-agents-shell`; this PR intentionally only adds workflow scaffolding so future sessions can navigate the plan.
