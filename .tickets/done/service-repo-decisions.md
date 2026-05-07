---
prefix: service
title: Add Decision repository methods
status: done
branch: service-0009
---

## Description

Add the per-feature Decision endpoints (`/api/v1/features/{id}/decisions`, `/api/v1/decisions/{id}`) to the repository layer. Decisions are append-only short notes (title + body + actor) the FeatureDetail Decisions sub-tab shows.

Depends on `infra-openapi-regen.md`. See `docs/feature_plans/20-navigation-and-data.md` and `docs/feature_plans/30-screens.md`.

## Acceptance criteria

- [x] `TmuxAgentRepository` adds:
  - `func listFeatureDecisions(featureID: Int64) async throws -> [Components.Schemas.Decision]`
  - `func createFeatureDecision(featureID: Int64, body: Components.Schemas.CreateDecisionRequest) async throws -> Components.Schemas.Decision`
  - `func deleteDecision(id: Int64) async throws`
- [x] `LiveTmuxAgentRepository` wires to the generated operations.
- [x] `MockTmuxAgentRepository` seeds 2–3 decisions per active feature, with varied actors (`human` and `agent`) and `actor_name` populated. Decisions are returned newest-first.
- [x] Tests:
  - `listFeatureDecisions` returns decisions in `created_at DESC` order.
  - `createFeatureDecision` returns a record with the supplied `actor` and a server-assigned `created_at`. Mock generates a new ID.
  - `deleteDecision` removes the decision; subsequent list omits it.
- [x] Project builds.

## Notes

- The contract's `actor` enum is `{ human, agent }`. Default UX in the create flow: `human` when triggered from a UI button. Agent decisions are written by the backend (e.g., when a session logs a decision via the activity feed) — the mobile app never sets `actor: agent` from the app.
- `Decision.body` is plain text (per the schema — no `body_blocks` JSON). The Decisions sub-tab UI renders it as monospaced or prose depending on the view; the repository returns the string verbatim.
- Activity events with `kind == decision` are separate from Decision records — when a Decision is created via `POST /decisions`, the backend emits an activity event automatically. The mobile app's activity poller will surface it; the create call does not need to chain.
- Deletion is supported by the contract for typo recovery but should be visually rare. Surface it as a destructive action under the row's swipe / context menu; never expose it on tap.
