---
prefix: infra
title: Pull push-notification contract + regenerate Swift client
status: todo
branch:
---

## Description

After `infra-apns-backend` merges in the parent repo, pull the updated
`openapi.yaml` into `remote-coding/remote-coding/openapi.yaml`, run the Swift
OpenAPI Generator, and expose the new device-registration methods through the
`TmuxAgentRepository` protocol.

Depends on `infra-apns-backend.md`. See `docs/feature_plans/60-push-notifications.md`.

## Acceptance criteria

- [ ] `openapi.yaml` updated with `POST /api/v1/devices` and `DELETE /api/v1/devices/{token}`.
- [ ] Generated Swift types include a `DeviceRegistrationRequest` schema.
- [ ] `TmuxAgentRepository` protocol gains `registerDevice(_ body: Components.Schemas.DeviceRegistrationRequest) async throws` and `deregisterDevice(token: String) async throws`.
- [ ] `LiveTmuxAgentRepository` implements both methods.
- [ ] `MockTmuxAgentRepository` implements both methods (no-op stubs that track calls for tests).
- [ ] Build succeeds; existing tests pass.

## Notes

No UI in this ticket — purely the data layer.
