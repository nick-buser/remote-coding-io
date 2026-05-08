---
prefix: service
title: Build Roadmap screen — milestone-focused page-swipe view
status: done
branch: service-0017
---

## Description

Build the Roadmap tab using the zen one-milestone-at-a-time layout with `TabView(.page)` for swipe navigation. Each milestone page shows the eyebrow ("Now · ends May 26"), the large milestone label, the milestone ID, and the features in that milestone.

Depends on `service-tab-shell.md`, `service-app-route-coordinator.md`, `infra-component-kit.md`. See `docs/feature_plans/30-screens.md` (section 8).

## Acceptance criteria

- [ ] `Features/Roadmap/RoadmapView.swift` mounts inside the Roadmap tab.
- [ ] `Features/Roadmap/RoadmapViewModel.swift` is `@Observable @MainActor`. Loads features from all projects via `repository.listFeatures(projectIDOrSlug:status:)` parallelized; groups by `feature.milestone`.
- [ ] Milestone derivation: distinct non-empty `feature.milestone` strings, sorted by the earliest `target_date` of any feature in the milestone (lexicographic if dates aren't parseable).
- [ ] State map per milestone (derived):
  - All features `shipped` → `.shipped` (green dot).
  - Any feature `in_progress` or `review` → `.active` (accent dot).
  - Otherwise → `.planned` (muted dot).
- [ ] Top-level layout:
  - `LargeTitleHeader(title: "Roadmap", subtitle: "All projects · <n> milestones", trailing: calendar + filter)`.
  - `ScrollChips` filter row across projects (active accent for the selected project; "All" default).
  - `TabView(selection: $milestoneIndex)` with `.tabViewStyle(.page(indexDisplayMode: .always))` and a custom page indicator below if needed.
- [ ] Each milestone page renders:
  - 11pt mono uppercase eyebrow `Now · ends <m.end>` for active, `Planned · starts <m.start>` for planned, `Shipped <m.end>` for shipped.
  - 28pt display milestone label (strip leading `vN.M — `).
  - 12pt mono milestone ID (`v0.4`).
  - 24pt spacer.
  - List of features in the milestone (after applying the project filter): 8pt status dot + 16pt title + 11.5pt mono target date.
  - Bottom-of-page hint "Swipe for next milestone" at 12pt fg2.
- [ ] Tap a feature row → `AppRoute.featureDetail(featureID:)`.
- [ ] Page dots reflect milestone count and selected index.
- [ ] When a project filter excludes all features in a milestone, render `EmptyState(title: "No features for <project>", body: "Try All to see features across projects.")` instead of the empty list.
- [ ] Tests:
  - Milestone derivation correctly groups mock features.
  - Project filter narrows the per-page list.
  - Swiping changes the selected milestone (verified via `.tabViewStyle` selection binding).
- [ ] `#Preview` shows the v0.4 — Multi-agent milestone with feature rows.

## Notes

- The design's "Now" eyebrow assumes the milestone is currently active. Compute eligibility against `Date.now`: parse `m.end` if possible (try ISO-8601 first, then `MMM d` with the current year). If parsing fails, fall back to `Active` for the milestone whose features include any in-progress entry.
- The trailing `calendar` icon opens a date-range picker that scopes the milestone derivation. Defer the actual scope filter to a follow-up; the icon is a button stub.
- When the user has a default project set (You ▸ Workspace ▸ Default project), pre-select that project's chip on first load.
- The previous gap analysis suggested a vertical timeline with multi-feature cards (`RoadmapFeatureCard`). The zen page-swipe is the v2 direction — don't fall back to the dense version unless the page swipe proves unusable on data with many milestones.
