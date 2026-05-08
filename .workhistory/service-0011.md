# service-0011: AgentSession repository methods

Ticket: `.tickets/done/service-repo-agent-sessions.md`

## Summary

Phase 2 continues. AgentSession is the persistent PM-hub
record (state, uptime, cpu, transcript_key, cost) bound to a
ticket — distinct from the raw tmux `Session` / `Pane` that
stays for the WebSocket transport. This branch lands the
three AgentSession methods end-to-end (live OpenAPI client +
mock + tests) plus the `AgentSession.uptime` adapter
extension that views read directly.

## Changes

- `TmuxAgentRepository` gains three methods:
  - `listProjectAgentSessions(projectIDOrSlug:)`
  - `listTicketAgentSessions(ticketPublicID:)`
  - `createAgentSession(_:)`
- `LiveTmuxAgentRepository` wraps the matching generated
  operations and sorts list responses by `last_active_at`
  desc inside the repository.
- `MockTmuxAgentRepository` seeds the four sessions from
  `data.jsx` (session-04 idle, session-05 awaiting-input,
  session-07 active, session-08 active) bound to existing
  ticket ids. Project filtering walks ticket → feature →
  project; ticket filtering goes by `ticket_id` directly.
- `createAgentSession` derives `tmux_session` as
  `<project_slug>__<feature_slug>__<branch_slug>` when
  omitted, honours an explicit override verbatim, and
  pushes an `ActivityEvent(kind: .check)` so the Inbox /
  Activity poller picks up the spawn (now that
  service-repo-activity is in place).
- New `Core/Domain/AgentSessionExtensions.swift` adds
  `AgentSession.uptime` — a human-readable string
  (`"47m"`, `"2h 14m"`, `"3d"`) derived from `start_time`
  so the Sessions list views can read it directly.
- 5 new `remote_codingTests` cases cover: project-scoped
  listing via the ticket walk, ticket-scoped listing
  (including the empty case for an unspawned ticket),
  `tmux_session` derivation on omit, explicit override +
  `ActivityEvent` emission on spawn, and `uptime`
  formatting across minute / hour / day boundaries.

## Decisions

- **Project filter walks ticket → feature → project.** The
  contract only links AgentSession to a ticket; the project
  membership has to come from the ticket's feature.
  Pre-computing a `Set<Int64>` of project-feature ids in the
  filter keeps the per-session predicate cheap (O(1) set
  lookup) without caching any state on the mock.
- **Mock honours explicit `tmux_session` overrides
  verbatim.** The contract description spells this out; the
  mock matches the live behaviour so test fixtures that need
  a specific session name (e.g. for routing tests) get one.
- **Spawn-time ActivityEvent has `kind == .check`, not
  `.commit` or `.test`.** The design uses `.check` for the
  generic "agent did something operational" kind. A spawn is
  not a commit or a test run, but it is operational signal —
  `.check` is the closest fit. If product feedback wants a
  dedicated `.spawn` kind later that's a contract change.
- **`AgentSession.uptime` is an extension, not a stored
  computed property on the model.** The contract type is
  generated; we cannot add stored properties without
  shadowing. The extension lives in `Core/Domain/` so views
  can treat it as part of the domain surface without
  importing `Components.Schemas.*` types directly.
- **Sluggify replaces `/` and `-` with `_`.** Matches the
  contract description's example
  `<project_slug>__<feature_slug>__<branch_slug>`. The
  `feat/tmx-0042-pane-registry` branch becomes
  `feat_tmx_0042_pane_registry` so the composed name is
  shell-safe.
- **`pane` stays a string (e.g. `agent:2.0`) in the
  repository surface.** Parsing into `(window, paneIndex)`
  is the terminal screen's job; the repository returns the
  raw string verbatim.

## Notes

- `transcript_key`, `token_usage`, and `cost_estimate` are
  reserved for the future Garage S3 integration; the seed
  leaves them `nil`. View code that paints these strings
  must treat them as optional and skip when empty.
- `xcodebuild build test` was not run on this branch
  (Linux dev environment, no Swift toolchain). Build + test
  verification is left to the local Xcode pass before merge.
- Branched off `service-0010` to chain past the activity
  surface this ticket spawns events on. Once the upstream
  branches merge, the diff collapses to the
  `service-0011`-specific commit.
