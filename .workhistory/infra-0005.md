# infra-0005: APNs device registration endpoints in openapi.yaml

Ticket: `.tickets/done/infra-apns-backend.md`

## Summary

Adds `POST /api/v1/devices` and `DELETE /api/v1/devices/{deviceToken}` to the
OpenAPI contract along with the `DeviceRegistrationRequest`, `DeviceRegistration`,
and `DeviceEnvironment` schemas. This is the contract-side slice of the phase 6
backend ticket — the actual APNs dispatch (push send to APNs gateway) is a
backend-server concern not implemented in this repository.

## Changes

- **Modified** `remote-coding/remote-coding/openapi.yaml`:
  - New paths: `POST /api/v1/devices` (idempotent registration), `DELETE
    /api/v1/devices/{deviceToken}` (deregister, 204).
  - New parameter `DeviceToken` (hex-encoded, `^[0-9a-f]{64}$`).
  - New schemas:
    - `DeviceEnvironment` enum (`sandbox` / `production`).
    - `DeviceRegistrationRequest` — required `device_token`, `environment`;
      optional `muted_project_ids`, `quiet_hours_start`, `quiet_hours_end`.
    - `DeviceRegistration` — server-side echo with `created_at` / `updated_at`.
  - New tag `Notifications`.

## Decisions

- **Quiet hours stored as UTC integers (0–23).** Display conversion happens
  client-side. The ticket spec calls this out explicitly; the iOS settings UI
  later picks a local-time hour, converts to UTC for the request body, and
  converts back for display.
- **`muted_project_ids` is server-side filtering.** The backend suppresses
  pushes before dispatch; the client does not need to filter incoming pushes
  by project. Cheaper than dispatching and dropping client-side, and works
  even when the device is offline.
- **`DeviceRegistration` response schema mirrors the request.** Lets the
  iOS settings screen read back its own state after a re-registration without
  a separate GET endpoint.
- **APNs dispatch (push send) is out-of-scope for this PR.** The contract
  documents the expected push payload shape (`kind`, `activity_event_id`,
  `project_id`, `feature_id`, `ticket_id`, `agent_session_id`) inline in
  `docs/feature_plans/60-push-notifications.md`. Marked the corresponding
  acceptance-criteria boxes as deferred to the backend server work.

## Notes

- PR #__, targeting `main`. First slice of phase 6 stacked branches.
- Validated: `yaml.safe_load` parses; 30 paths, 47 schemas; new paths and
  schemas all present.
