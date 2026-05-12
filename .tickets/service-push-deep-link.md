---
prefix: service
title: Push notification tap routing
status: todo
branch:
---

## Description

Handle incoming push taps and route the user to the correct surface. Works for
cold launch, background, and foreground arrival.

Depends on `service-push-permission.md`. See `docs/feature_plans/60-push-notifications.md`.

## Acceptance criteria

- [ ] `PushRouter` struct (pure, no UIKit imports) maps a `[String: Any]` payload to `AppRoute?`:
  - `kind == "question"` + `agent_session_id` → `.agentSession(sessionID:)`
  - `kind == "review"` + `ticket_id` → `.review(ticketPublicID:)` (resolved via `getTicket` by numeric id; falls back to `.inbox` on failure)
  - default → `.inbox`
- [ ] `UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:)` calls `PushRouter` and pushes the resulting route into the appropriate tab stack via `RootCoordinator`.
- [ ] Cold launch: `AppDelegate.application(_:didFinishLaunchingWithOptions:)` stashes the notification payload; `RootCoordinator` consumes it after the view hierarchy is ready (one-shot, cleared after use).
- [ ] Foreground arrival: `willPresent` returns `.banner` + `.sound`; the Inbox unread indicator updates without waiting for the next polling tick.
- [ ] `PushRouter` is covered by unit tests for all three routing branches.

## Notes

- `review` routing resolves the public ID via a repository call on a background
  task. Use `Task { await resolve() }` inside the delegate; show Inbox
  immediately and replace it with the review screen once resolved.
- Do not hard-code tab indices — route through `RootCoordinator` like any other
  deep-link.
