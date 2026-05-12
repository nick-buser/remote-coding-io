---
prefix: infra
title: Backend APNs device registration + push dispatch
status: todo
branch:
---

## Description

Add two endpoints to `../api/openapi.yaml` and implement APNs push dispatch
in the backend server. This is a **parent-repo ticket** — the backend work
lands there; the iOS side follows in `infra-push-openapi-regen`.

See `docs/feature_plans/60-push-notifications.md` for the full spec.

## Acceptance criteria

- [ ] `POST /api/v1/devices` accepts `{device_token, environment, muted_project_ids?, quiet_hours_start?, quiet_hours_end?}` and stores the registration. Idempotent (re-register is a no-op or update).
- [ ] `DELETE /api/v1/devices/{device_token}` removes the registration. `204 No Content`.
- [ ] Backend sends an APNs push when an `ActivityEvent` with `kind=question` or `kind=review` is created, for all registered devices whose `project_id` is not in `muted_project_ids` and whose current time is outside `quiet_hours`.
- [ ] Push is **not** sent to the device identified by `X-Device-Token` request header on the mutation that triggered the event.
- [ ] Push payload includes `kind`, `activity_event_id`, `project_id`, `feature_id`, `ticket_id`, `agent_session_id` (where applicable).
- [ ] `aps.badge` is always 0.
- [ ] Both endpoints are documented in `openapi.yaml`.

## Notes

- `environment` field distinguishes sandbox vs production APNs gateway.
- `quiet_hours_start` / `quiet_hours_end` are UTC hour integers (0–23).
- Coordinate with iOS `infra-push-openapi-regen` on exact field names.
