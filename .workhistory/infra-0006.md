# infra-0006: Surface APNs device-registration methods through TmuxAgentRepository

Ticket: `.tickets/done/infra-push-openapi-regen.md`

## Summary

Adds `registerDevice` and `deregisterDevice` to the `TmuxAgentRepository`
protocol and implements both in `LiveTmuxAgentRepository` (calling the
OpenAPI client) and `MockTmuxAgentRepository` (in-memory store with
call-tracking for tests). The generated Swift types for the new endpoints
(`DeviceRegistrationRequest`, `DeviceRegistration`, `DeviceEnvironment`)
come from the contract landed in `phase6/01-apns-backend`; the
OpenAPIGenerator build-tool plugin produces them at build time.

## Changes

- **Modified** `Core/Repositories/TmuxAgentRepository.swift`:
  - `func registerDevice(_ body: Components.Schemas.DeviceRegistrationRequest) async throws -> Components.Schemas.DeviceRegistration`
  - `func deregisterDevice(token: String) async throws`
- **Modified** `Core/Repositories/LiveTmuxAgentRepository.swift`:
  - `registerDevice` switches on `.ok` / `.badRequest` / `.serviceUnavailable`.
  - `deregisterDevice` switches on `.noContent` / `.notFound` / `.serviceUnavailable`.
- **Modified** `Core/Repositories/MockTmuxAgentRepository.swift`:
  - `private(set) var registeredDevices: [Components.Schemas.DeviceRegistration]`
  - `private(set) var deregisteredDeviceTokens: [String]`
  - `registerDevice` upserts by `device_token`, preserves `createdAt`, advances `updatedAt`.
  - `deregisterDevice` records the call and removes the matching registration.
- **Added** `remote-codingTests/DeviceRegistrationRepositoryTests.swift`:
  - Six tests covering register persistence, idempotent re-register, quiet
    hours + mute list, deregister removes + records, deregister-unknown still
    records.

## Decisions

- **`registerDevice` returns `DeviceRegistration`.** The ticket prescribed
  `async throws` (no return), but the OpenAPI 200 response carries a body
  with server-side timestamps. Returning the registration matches
  `createProject` / `createFeature` and keeps the door open for the You
  settings screen to read back server-acknowledged state without a GET.
- **No HTTP call for the mock.** Mock tracks calls and stores registrations
  in-memory; this matches the existing pattern (`sentInputs`) and lets unit
  tests assert behaviour without faking a transport.

## Notes

- PR #__, targeting `phase6/01-apns-backend` (stacked branch).
- No local Xcode toolchain on the agent host — relies on PR CI to verify
  the generated types and full build.
