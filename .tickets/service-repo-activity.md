---
prefix: service
title: Add ActivityEvent listing and 5-second polling helper
status: todo
branch:
---

## Description

Add the `/api/v1/activity` listing to the repository layer plus a small `ActivityPoller` service that drives the Inbox feed and the tab-bar `needsYou` indicator. Activity events cross-cut the Project / Feature / Ticket hierarchy and carry a `kind` that drives the Inbox row icons and inline action buttons.

Depends on `infra-openapi-regen.md`. See `docs/feature_plans/20-navigation-and-data.md` and `docs/feature_plans/30-screens.md`.

## Acceptance criteria

- [ ] `TmuxAgentRepository` adds:
  - `func listActivity(project: String?, feature: Int64?, since: Date?, limit: Int?) async throws -> [Components.Schemas.ActivityEvent]`
- [ ] `LiveTmuxAgentRepository` wires this to the generated `listActivity` operation. Query parameters serialize as `project=<idOrSlug>`, `feature=<id>`, `since=<RFC3339>`, `limit=<int>`.
- [ ] `MockTmuxAgentRepository` returns the 10 fixture events from `data.jsx` newest-first. Filtering: when `project` is set, only events whose `project_id` resolves to that idOrSlug are returned. When `feature` is set, only events whose `feature_id` matches. When `since` is set, only events with `created_at > since` are returned. `limit` clamps the result.
- [ ] `Core/Services/ActivityPoller.swift` is a `@MainActor` `@Observable` actor with:
  - `var events: [Components.Schemas.ActivityEvent]` (latest first, capped at 500).
  - `var needsYou: Bool` (derived: any event with `kind ∈ {question, review}` newer than the user's last seen cursor).
  - `func start(scope: ActivityPollerScope)` (scope is `.workspace`, `.project(idOrSlug)`, or `.feature(id)`).
  - `func stop()`.
  - `func markSeen()` updates the cursor so `needsYou` resets.
- [ ] The poller runs at 5-second cadence using `Task.sleep`. It pauses when the app is backgrounded (subscribe to `ScenePhase`) and resumes on foreground.
- [ ] On each tick, the poller fetches `listActivity(... since: lastCursor, limit: 100)` and prepends new events to `events`, advancing the cursor to the newest `created_at`.
- [ ] `RootCoordinator` (or `AppModel`) instantiates one workspace-scoped poller at app launch. Inbox view models can spawn additional scoped pollers without conflict.
- [ ] Tests:
  - `listActivity` mock filters correctly on each combination of `project`, `feature`, `since`, `limit`.
  - `ActivityPoller` advances its cursor across two ticks (verified by injecting a controllable repository fixture).
  - `needsYou` flips when a `kind == question` event is added and resets after `markSeen()`.
- [ ] Project builds.

## Notes

- Avoid backoff for transient errors in the initial ticket — log and continue. Backoff is a follow-up if 5s polling proves expensive.
- Stop the poller while the terminal screen is presented (the WebSocket stream is the live signal there). Resume on dismiss. Implement this hook in the terminal shell ticket; this ticket only exposes `start/stop`.
- The `RootCoordinator` should expose a derived `needsYou: Bool` so the tab bar can read it without subscribing to the poller directly.
- Avoid storing `events` past 500 entries — the Inbox UI shows at most a few dozen and historical browsing isn't a v2 feature.
- `ActivityEvent.detail` is free-form text; treat it as untrusted display content.
