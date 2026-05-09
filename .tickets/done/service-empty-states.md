---
prefix: service
title: Polish empty states across screens
status: done
branch: service-0036
---

## Description

Audit every list screen and replace ad-hoc empty placeholders with `EmptyState` from the component kit using copy aligned with the v2 design's tone (quiet, encouraging, action-oriented).

Depends on all Phase 3 screen tickets. See `docs/feature_plans/30-screens.md`.

## Acceptance criteria

- [ ] **Inbox**: when `Needs you` has no items, render the "All clear" state per the design (72pt outline circle + envelope, "All clear", "Agents are working. They'll find you here when they need something.").
- [ ] **Projects**: when there are zero projects, render `EmptyState` "No projects yet" + body "Tap + to add your first project." with a primary `Add project` button that opens `CreateProjectSheet`.
- [ ] **Project Detail Features tab**: when a project has zero features, render `EmptyState` "No features yet" + `Add feature` primary button.
- [ ] **Project Detail Tickets tab**: zero tickets → "No tickets across this project's features yet."
- [ ] **Project Detail Docs tab**: zero docs → "No docs yet. Pin a PRD or vision to start."
- [ ] **Feature Detail Tickets tab**: zero tickets → "No tickets yet" + `Add ticket` button.
- [ ] **Feature Detail PRD tab**: zero docs → "No docs yet" + `Add doc` button.
- [ ] **Feature Detail Decisions tab**: zero decisions → "No decisions logged yet" + `Log decision` button.
- [ ] **Feature Detail Sessions tab**: zero sessions → "No agent sessions yet" + `Spawn session` button.
- [ ] **Roadmap**: a milestone with zero matching features (after filter) → "No features for <project>" + suggestion "Try All to see features across projects."
- [ ] **Sessions tab**: zero awaiting sessions → "All clear — agents are working." Zero sessions across all projects → "No live sessions" + `Spawn session` button.
- [ ] All copy uses sentence case and avoids exclamation marks. Body text under 80 characters.
- [ ] Tests: empty-state appearance is verified via snapshot tests for each screen.

## Notes

- Lifting copy from the design's `InboxEmptyZen` is the gold standard — match its tone elsewhere.
- The empty state should never be a dead-end. Always include a primary action when one is meaningful.
- Don't hide the navigation chrome (large title, segmented control) just because the body is empty — keep the chrome so the user can switch tabs without going back.
