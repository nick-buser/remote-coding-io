---
prefix: service
title: Feature detail Decisions sub-tab — append-only list, log decision sheet
status: todo
branch:
---

## Description

Build the Decisions sub-tab on Feature Detail. Renders the append-only decision list newest-first plus a `+ Log decision` footer button. Each row shows the actor (human/agent), title, body, and timestamp.

Depends on `service-feature-detail.md`, `service-repo-decisions.md`, `infra-component-kit.md`. See `docs/feature_plans/30-screens.md` (section 6).

## Acceptance criteria

- [ ] `Features/FeatureDetail/Tabs/FeatureDecisionsTab.swift` renders a vertical list of `DecisionRow`s (no rounded card wrapper — decisions are quiet prose, not list rows).
- [ ] `DecisionRow`:
  - 11pt mono timestamp (relative — `1h`, `3d`, `2w`).
  - 14pt fg `decision.title` (weight 600).
  - 12.5pt fg2 `decision.body` (multi-line).
  - Trailing actor chip: `agent` rendered iris-tinted, `human` neutral. `decision.actor_name` shown in mono.
- [ ] Footer `+ Log decision` button opens a sheet:
  - **Title** (required).
  - **Body** (multi-line, optional).
  - **Actor** (segmented: Human / Agent — defaults to Human).
  - **Actor name** (optional — defaults to user's display name when Human).
- [ ] Submit calls `repository.createFeatureDecision(featureID:body:)`. New decision prepends to the list.
- [ ] Long-press / swipe-from-trailing reveals `Remove (typo)` destructive action. Confirms in a `confirmationDialog` before calling `repository.deleteDecision(id:)`.
- [ ] Tests: list ordering is newest-first; create prepends; delete removes.
- [ ] `#Preview` shows FEAT-018 decisions with both human and agent actors.

## Notes

- The design's dense version uses an `iris`-tinted glyph color for agent actors. Match this with `AccentColor.iris` value.
- Decision body is plain text — render it in the UI font, not mono. Don't markdown-parse.
- Avoid making `Remove` discoverable on tap. Decisions are intentionally append-only; deletion is for typo recovery.
- A future ticket could surface decisions in the Inbox (kind=decision events). This ticket only handles the per-feature view.
