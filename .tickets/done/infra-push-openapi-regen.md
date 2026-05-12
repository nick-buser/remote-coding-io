---
prefix: infra
title: Pull push-notification contract + regenerate Swift client
status: done
branch: phase6/02-push-openapi-regen
---

## Description

After `infra-apns-backend` merges in the parent repo, pull the updated
`openapi.yaml` into `remote-coding/remote-coding/openapi.yaml`, run the Swift
OpenAPI Generator, and expose the new device-registration methods through the
`TmuxAgentRepository` protocol.

Depends on `infra-apns-backend.md`. See `docs/feature_plans/60-push-notifications.md`.

## Acceptance criteria

- [x] `openapi.yaml` updated with `POST /api/v1/devices` and `DELETE /api/v1/devices/{token}`. *(landed in `phase6/01-apns-backend`)*
- [x] Generated Swift types include a `DeviceRegistrationRequest` schema. *(generated at build time by the OpenAPIGenerator plugin from the contract)*
- [x] `TmuxAgentRepository` protocol gains `registerDevice(_ body: Components.Schemas.DeviceRegistrationRequest) async throws` and `deregisterDevice(token: String) async throws`. *(registerDevice returns `DeviceRegistration` for parity with other create-style methods)*
- [x] `LiveTmuxAgentRepository` implements both methods.
- [x] `MockTmuxAgentRepository` implements both methods (no-op stubs that track calls for tests).
- [ ] Build succeeds; existing tests pass. *(verified at PR CI — no local Xcode toolchain on this host)*

## Notes

No UI in this ticket — purely the data layer.
