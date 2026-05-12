# service-0039: Push notification tap routing

Ticket: `.tickets/done/service-push-deep-link.md`

## Summary

Implements push-notification deep-linking. A pure `PushRouter` struct maps
APNs `userInfo` dicts to `PushDestination` (tab + optional `AppRoute`).
`PushDelegateBridge` adapts `UNUserNotificationCenterDelegate` callbacks
into router calls + navigation. `AppDelegate` stashes the cold-launch
payload; the App's `.task` consumes it once after the view hierarchy is
ready.

## Changes

- **Added** `Core/Services/PushRouter.swift`:
  - `PushDestination` struct (tab + optional route) with an `.inbox` fallback.
  - `PushRouter` struct (synchronous, no UIKit) mapping payload → destination.
  - Accepts `Int`, `Int64`, `NSNumber`, or numeric `String` for
    `agent_session_id` (JSON deserialisation produces varying types).
- **Added** `Core/Services/PushDelegateBridge.swift`:
  - `@MainActor` `UNUserNotificationCenterDelegate` adapter.
  - `willPresent` → returns `[.banner, .sound]` and calls
    `onForegroundArrival` so the Inbox unread state refreshes immediately.
  - `didReceive` → invokes router, calls `onNavigate`.
- **Modified** `App/AppDelegate.swift`:
  - `application(_:didFinishLaunchingWithOptions:)` stashes
    `launchOptions[.remoteNotification]` in `pendingLaunchPayload`.
  - `consumePendingLaunchPayload()` one-shot consumer.
  - `notificationDelegate` strong reference keeps the bridge alive.
- **Modified** `App/RootCoordinator.swift`:
  - `navigate(to:)` — switches tab + pushes route in one call. Used by
    deep-link surfaces.
- **Modified** `remote_codingApp.swift`:
  - `.task` now also calls `bindNotificationCenter()` and
    `consumeLaunchPayloadIfNeeded()`.
  - `bindNotificationCenter` wires the bridge → coordinator and bridge →
    activity-poller tick.
- **Modified** `remote-coding/openapi.yaml`:
  - Adds `PushPayload` documentary schema (kind, ids, optional
    `ticket_public_id`) so backend + iOS agree on the wire format.
- **Modified** `docs/feature_plans/60-push-notifications.md`:
  - Push payload example includes `ticket_public_id`.
  - Routing pseudocode updated to the synchronous `PushDestination` form.
- **Added** `remote-codingTests/PushRouterTests.swift`: 12 tests covering
  question routing (Int / Int64 / NSNumber / String coercions), review
  routing, empty / unknown / malformed payloads.
- **Modified** `remote-codingTests/RootCoordinatorTests.swift`: 2 tests
  for `navigate(to:)` — switches tab + pushes route; nil-route preserves
  other tabs' paths.

## Decisions

- **`ticket_public_id` over numeric-id lookup.** The original ticket text
  suggested resolving a numeric `ticket_id` via `getTicket(id:)` — but the
  contract has no GET-by-numeric-id endpoint. Adding `ticket_public_id`
  to the push payload keeps the router pure and synchronous and avoids
  adding a backend endpoint just for routing. `ticket_id` is still in the
  documentary `PushPayload` schema for activity-event cross-referencing.
- **Inbox tab for both kinds.** Push-tap navigation mirrors the existing
  in-app `InboxView.handleRowTap` which pushes onto the Inbox stack.
  Keeps the user's mental model consistent regardless of where the route
  was triggered.
- **`navigate(to:)` on `RootCoordinator` rather than coordinator-aware
  surfaces.** A single deep-link entry point on the coordinator is easier
  to reason about than scattering "switch tab + push" pairs.
- **`@MainActor` closures in `PushDelegateBridge`.** The bridge runs
  on the main actor; the closures it stores call into `@MainActor` types
  (`RootCoordinator`, `AppModel`). Explicit `@MainActor` on the closure
  types avoids Sendable warnings under strict concurrency.

## Notes

- PR #__, stacked on `phase6/03-push-permission`.
- No xcodebuild on this host — CI will validate the full build.
- The bridge itself isn't unit-tested directly because constructing
  `UNNotification` outside the system framework is impractical; the
  router (where the actual logic lives) is fully covered.
