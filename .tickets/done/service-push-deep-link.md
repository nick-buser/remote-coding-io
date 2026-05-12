---
prefix: service
title: Push notification tap routing
status: done
branch: phase6/04-push-deep-link
---

## Description

Handle incoming push taps and route the user to the correct surface. Works for
cold launch, background, and foreground arrival.

Depends on `service-push-permission.md`. See `docs/feature_plans/60-push-notifications.md`.

## Acceptance criteria

- [x] `PushRouter` struct (pure, no UIKit imports) maps a payload to a `PushDestination` (tab + optional `AppRoute`):
  - `kind == "question"` + `agent_session_id` → `.agentSession(sessionID:)`
  - `kind == "review"` + `ticket_public_id` → `.ticketDetail(publicID:)`
  - default → `.inbox` fallback
- [x] `UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:)` calls `PushRouter` and routes via `RootCoordinator.navigate(to:)`.
- [x] Cold launch: `AppDelegate.application(_:didFinishLaunchingWithOptions:)` stashes the notification payload; the App's `.task` consumes it once after the view hierarchy is ready (one-shot, cleared after use).
- [x] Foreground arrival: `willPresent` returns `.banner` + `.sound`; the Inbox unread indicator updates via `activityPoller.tick()` without waiting for the next polling tick.
- [x] `PushRouter` is covered by unit tests for all three routing branches (plus malformed-payload cases).

## Notes

- Backend includes `ticket_public_id` in the push payload (added to the
  `PushPayload` documentary schema in `openapi.yaml`) so the router doesn't
  need a numeric → public-id repository lookup — the contract has no
  GET-ticket-by-numeric-id endpoint.
- Plan doc updated to reflect the synchronous router and the
  `PushDestination` (tab + route) shape.
- Tab placement: question + review pushes land on the Inbox stack to match
  the in-app row-tap routing in `InboxView`.
