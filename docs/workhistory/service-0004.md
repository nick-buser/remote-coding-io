# service-0004

## Summary

This branch introduced the first real API integration path for the iOS app. The prior app was intentionally mock-backed so navigation and terminal context could be shaped quickly. That was useful, but it meant manual builds could not exercise the real backend.

## Changes

- Added API base URL configuration with a local default of `http://127.0.0.1:8080`.
- Added a URLSession-backed `APIClient`.
- Added `LiveTmuxAgentRepository` implementing the existing repository protocol against the OpenAPI paths.
- Switched app startup to use the live repository by default.
- Added a Settings tab for changing the backend URL, especially for physical-device testing against a LAN host.
- Added a checked-in `Info.plist` with local-network usage text and an ATS local-network exception so HTTP LAN backend testing can work on device.
- Added focused tests for API base URL validation and path escaping.
- Kept the mock repository for previews and tests.

## Decisions

- The repository protocol remains the app boundary. SwiftUI views still do not know whether data comes from mocks or the real backend.
- Document APIs return empty arrays in the live repository for now because the backend does not expose docs, prompt buildouts, criteria, or decisions yet.
- Project and feature session scoping is still inferred from `Project.tmuxSessionName`, because the backend still exposes sessions globally and does not return explicit ownership fields.
- The handwritten OpenAPI-shaped models remain in place for this step. Replacing them with Swift OpenAPI Generator output remains the next contract-hardening step.

## Notes

The biggest functional risk is local networking on a physical device. The Settings tab makes the base URL configurable, but the backend must be reachable from the device network.

The app target now builds against the real repository by default, but the backend still has no document endpoints and no explicit session ownership model beyond the project `tmux_session_name` field.
