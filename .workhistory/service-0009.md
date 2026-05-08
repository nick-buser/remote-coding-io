# service-0009: Decision repository methods

Ticket: `.tickets/done/service-repo-decisions.md`

## Summary

Phase 2 continues. Decisions are append-only short notes the
FeatureDetail Decisions sub-tab will surface; an ActivityEvent
of `kind == decision` is also emitted by the backend so the
Inbox feed catches them. This branch lands the three decision
methods end-to-end (live OpenAPI client + mock + tests). The
mock does not chain an ActivityEvent on create — the activity
surface ships in `service-repo-activity` and the create flow
intentionally stays single-purpose.

## Changes

- `TmuxAgentRepository` gains three methods:
  - `listFeatureDecisions(featureID:)`
  - `createFeatureDecision(featureID:body:)`
  - `deleteDecision(id:)`
- `LiveTmuxAgentRepository` wraps the matching generated
  operations and sorts list responses by `createdAt DESC`
  inside the repository.
- `MockTmuxAgentRepository` seeds 7 decisions across features
  11 / 12 / 21 with mixed `human` / `agent` actors and
  populated `actor_name`. Mutations roundtrip — create returns
  a record with a fresh `id` and a server-generated
  `createdAt`; delete removes the row.
- 3 new `remote_codingTests` cases cover `createdAt DESC`
  ordering + feature scoping, server-assigned id / createdAt
  on create with the requested actor preserved, and delete
  removal.

## Decisions

- **Sort `createdAt DESC` inside the repository.** Same
  rationale as `listFeatureDocs` in service-0008: encoding the
  contract's list ordering once in the repository keeps every
  consumer view unaware of it.
- **Don't chain an `ActivityEvent` on create.** The contract
  notes the backend emits the event automatically; coupling
  the iOS mock's createFeatureDecision to the activity feed
  would have created an artificial dependency on
  service-repo-activity that does not exist in the live
  surface. Keeping the create path single-purpose lets the
  next ticket land the activity surface without touching this
  one.
- **Both actors look the same in the seed.** The contract has
  `{ human, agent }` but says human is the default for
  app-triggered creates — agent decisions only ever come from
  backend writes (e.g., a session logging a decision via the
  activity feed). The mock seed reflects this with both
  variants present, but the mock's `createFeatureDecision`
  honours whatever `actor` the request specifies; it does not
  override to `.human`. The UI layer (which lands later) is
  what enforces the human-on-app default.
- **Surface delete in the API but reserve UX placement for the
  Decisions sub-tab ticket.** The contract supports delete,
  which makes the repo API symmetric. The Notes section on the
  ticket reminds the screen ticket to gate this behind a swipe
  / context menu so the affordance is visually rare — typo
  recovery, not a top-level action.

## Notes

- `xcodebuild build test` was not run on this branch (Linux
  dev environment, no Swift toolchain). Build + test
  verification is left to the local Xcode pass before merge —
  this is called out in the PR test plan.
- Branched off `service-0008` to sidestep `Core/Repositories/`
  merge conflicts. Once #13 merges and #14's base flips to
  `main`, the diff collapses to just the `service-0009`
  commit.
- The mock's `nextDecisionID` starts at 700 to leave room for
  fixtures from other resources (tickets at 200, docs at 500)
  without overlap. This is cosmetic — IDs are opaque on the
  client — but it keeps the seed grep-friendly.
