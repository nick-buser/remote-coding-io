# Phase 6 — Push notifications

Date: 2026-05-12

## Goal

Surface the most time-sensitive agent events — questions waiting on the user
and reviews ready for approval — as APNs push notifications. The user should
be able to tap a notification cold (app not running) and land directly on the
right surface (terminal for a question, review screen for a diff, Inbox for
everything else).

## What triggers a push

Only two `ActivityEvent` kinds warrant a push:

| `kind` | When | Destination |
|--------|------|-------------|
| `question` | Agent emits a prompt waiting on input | Terminal screen (the session) |
| `review` | Agent opens a review on a ticket | Review screen for that ticket |

All other activity kinds (commit, check, doc, decision, test, approve) update
the Inbox feed via polling but do **not** send a push. The user opted into
being paged for things that need them; they did not opt into a firehose.

## Backend contract additions

Two new endpoints must land in `../api/openapi.yaml` before the iOS
registration path can go live. A parent-repo ticket (`infra-apns-backend`)
covers the backend implementation; `infra-push-openapi-regen` pulls the result
into the iOS generated client.

### `POST /api/v1/devices`

Register (or re-register) an APNs device token.

```yaml
requestBody:
  required: true
  content:
    application/json:
      schema:
        type: object
        required: [device_token, environment]
        properties:
          device_token:
            type: string
            description: Hex-encoded APNs token from didRegisterForRemoteNotificationsWithDeviceToken.
          environment:
            type: string
            enum: [sandbox, production]
```

Response: `200 OK` (idempotent — re-registering an existing token is a no-op).

### `DELETE /api/v1/devices/{device_token}`

Deregister a token on sign-out or when the user disables notifications in
settings. Response: `204 No Content`.

### Push payload shape

The backend sends a silent + alert push. The `userInfo` dict the iOS app
receives must carry enough context to route without a network call:

```json
{
  "aps": {
    "alert": { "title": "session-07 needs input", "body": "Use unified diff or split?" },
    "sound": "default"
  },
  "kind": "question",
  "activity_event_id": 912,
  "project_id": 1,
  "feature_id": 13,
  "ticket_id": 208,
  "ticket_public_id": "TMX-0050",
  "agent_session_id": 802
}
```

`agent_session_id` is present for `question` so the app can navigate directly
to the terminal without resolving through the ticket. `ticket_public_id` is
required for `review` — the iOS route uses the public id, so including it in
the payload avoids a numeric-to-public lookup on tap (the contract has no
GET-by-numeric-ticket-id endpoint). Either may be null if not applicable.

## iOS tickets

### `infra-push-openapi-regen`

Pull the updated backend contract (device registration endpoints) and run the
Swift OpenAPI Generator. Add the new request/response types to
`TmuxAgentRepository` protocol and implement in both `LiveTmuxAgentRepository`
and `MockTmuxAgentRepository`.

No UI work in this ticket — just the repository layer.

### `service-push-permission`

**When to ask:** Request permission on the first action that implies the user
cares about being paged — tapping "Open pane" on an Inbox question row, or
navigating to the Sessions tab for the first time. Never ask on cold launch.

**Implementation:**

```swift
// In AppModel or a dedicated PushRegistrationService
func requestPushPermissionIfNeeded() async {
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    guard settings.authorizationStatus == .notDetermined else { return }
    let granted = try? await UNUserNotificationCenter.current()
        .requestAuthorization(options: [.alert, .sound, .badge])
    if granted == true {
        await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
    }
}
```

**Token registration:** `AppDelegate.didRegisterForRemoteNotificationsWithDeviceToken`
encodes the token as a hex string and calls `POST /api/v1/devices` with the
current environment (`sandbox` for debug builds, `production` for release).
Token rotation is handled naturally — iOS calls this method on every launch
when push is active; the server endpoint is idempotent.

**Token deregistration:** Called from the push settings toggle (see below) and
on any sign-out path.

**Storage:** The current token is stored in `AppSettings` so the settings
screen can show whether push is active without a network call.

### `service-push-deep-link`

Implement `UNUserNotificationCenterDelegate` to handle notification taps.

**Foreground arrival** (`willPresent`): show the notification as a banner (do
not suppress it — the user may be in a different part of the app). Also update
the Inbox unread dot immediately by injecting a synthetic `ActivityEvent` into
`ActivityPoller`'s cache.

**Tap routing** (`didReceive`):

```
kind == "question" && agent_session_id != nil
    → PushDestination(tab: .inbox, route: .agentSession(sessionID:))

kind == "review" && ticket_public_id != nil
    → PushDestination(tab: .inbox, route: .ticketDetail(publicID:))

default
    → PushDestination.inbox (select Inbox tab, no push)
```

Routing is synchronous in the `PushRouter` struct — the backend includes
`ticket_public_id` in the payload so there's no async lookup on tap.

**Cold launch:** `AppDelegate.application(_:didFinishLaunchingWithOptions:)`
checks `launchOptions[.remoteNotification]` and stashes the payload; the root
coordinator consumes it once the view hierarchy is ready.

If `ticket_public_id` is missing or malformed, fall back to Inbox. The
router never makes a repository call — it's pure and synchronous.

**Testing:** `service-push-deep-link` must be testable with mock payloads. The
routing logic should live in a pure `PushRouter` struct that takes a
`[String: Any]` payload and returns an `AppRoute?`, separate from the delegate.

### `service-push-settings`

Add a "Notifications" group to the You screen, between Workspace and Agent
settings.

**Controls:**

| Control | Behaviour |
|---------|-----------|
| Push notifications master toggle | Calls `DELETE /api/v1/devices/{token}` on off → `registerForRemoteNotifications` + `POST /api/v1/devices` on on. If not yet authorized, triggers `requestPushPermissionIfNeeded`. |
| Muted projects | Multi-select list of all projects. Muted projects suppress pushes server-side (the backend filters by project_id before dispatching). Requires a `muted_project_ids` field in the device registration body (add to backend ticket scope). |
| Quiet hours | Start / end time pickers. Stored locally in `AppSettings` and sent as `quiet_hours_start` / `quiet_hours_end` (UTC hours) in the device registration body. |

The settings group only renders when the app is registered for push (token
in `AppSettings`). If the system-level permission is denied, show a
"Enable in Settings →" link opening `UIApplication.openSettingsURLString`.

## Acceptance criteria checklist

- [ ] `POST /api/v1/devices` and `DELETE /api/v1/devices/{token}` exist in the OpenAPI contract and generated Swift client.
- [ ] APNs permission is requested at the right moment (not on cold launch).
- [ ] Device token is registered on permission grant and on every subsequent launch (idempotent).
- [ ] Token is deregistered when the user disables push in settings.
- [ ] Cold-launch tap on a `question` push opens the correct terminal session.
- [ ] Cold-launch tap on a `review` push opens the correct review screen.
- [ ] Foreground push arrival shows a banner and updates the Inbox unread dot.
- [ ] `PushRouter` has unit tests covering question, review, and default routing.
- [ ] Push settings group renders correctly and master toggle deregisters/re-registers the token.
- [ ] Muted projects and quiet hours are included in the device registration body.

## Notes

- Sandbox vs production environment detection: `#if DEBUG` is sufficient for
  now; a proper entitlement check can come later.
- The backend should **not** send a push for events the current device itself
  triggered (e.g., the user approving a ticket from the app). The device token
  can be sent as an `X-Device-Token` header on mutation requests so the server
  can exclude it from dispatch. Add this to the backend ticket scope.
- Badge count: do not use badge numbers. The v2 design uses a single accent
  dot on the Inbox tab, not a numeric badge. Set `aps.badge` to 0 in all
  payloads so the badge clears on arrival.
