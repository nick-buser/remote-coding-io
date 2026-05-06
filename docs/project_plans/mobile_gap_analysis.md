# Mobile Gap Analysis

Date: 2026-04-30

> **Superseded by `docs/feature_plans/` for the v2 design.** This document
> predates the Claude Design v2 bundle and the richer OpenAPI surface
> (Tickets, Acceptance Criteria, Docs, Decisions, Activity, Agent Sessions,
> Review) that the iOS app is now being built against. Kept for historical
> context. Read `docs/feature_plans/00-overview.md` first for the current
> plan.

## Purpose

This document tracks the functional gap between the current backend, the web client, and the iOS client. The goal is to make the next mobile work easy to sequence without forgetting what already works elsewhere.

The iOS app should not simply clone the web UI. It should preserve the same backend contract and operational capabilities while presenting them in a native mobile hierarchy: project -> feature -> session -> pane.

## Current Source Of Truth

- Backend contract: `../api/openapi.yaml`
- Web API client: `../frontend/src/api/client.ts`
- Web terminal input: `../frontend/src/components/input/PaneInputPanel.tsx`
- Web terminal output: `../frontend/src/components/panes/PaneMonitor.tsx`
- Mobile repository boundary: `remote-coding/remote-coding/Core/Repositories/TmuxAgentRepository.swift`
- Mobile OpenAPI-shaped prototype models: `remote-coding/remote-coding/Core/Network/Generated/OpenAPIModels.swift`

## Current Backend Surface

The backend contract currently exposes:

- Health: `GET /healthz`
- Projects: list, create, get, update, delete
- Project session open/link: `POST /api/v1/projects/{idOrSlug}/session`
- Features: list under project, create under project, get by ID, update status
- Sessions: list, create, kill
- Panes: list panes, get output snapshot, send input
- WebSocket: stream pane output and accept resize messages

Important constraints:

- Sessions are still globally listed by `GET /api/v1/sessions`.
- Session ownership is only inferable through project `tmux_session_name`; the API does not expose project or feature ownership on session records.
- Tickets, acceptance criteria, feature docs, prompt buildouts, decisions, and transcript/doc storage are not exposed through OpenAPI yet.
- Pane input supports empty Enter behavior through `enter`/`keys`, but the app must intentionally preserve that behavior in the UI.

## Current Web Surface

The web client already has real API-backed flows for:

- Project list and create.
- Project detail with path, git URL, linked tmux session status, and project-session open/link button.
- Feature list and create under a project.
- Session list and create.
- Session detail with pane list, active-pane selection, live pane output, and pane input.
- WebSocket output streaming with reconnect/backoff.
- Terminal resize messages from the xterm fit addon.
- Input editor behavior using CodeMirror:
  - Send without Enter.
  - Send + Enter, including empty Enter for prompts.
  - Shift-Enter newline.
  - Per-pane command history.
  - Special tmux keys: Escape, Tab, arrows, `C-c`, `C-d`, `C-z`, `C-l`, `C-a`, `C-e`.

The web code also contains a richer mocked PM hub:

- Project hub layout.
- Feature detail tabs for overview, tickets, docs, sessions, review, and decisions.
- Ticket rows with status and acceptance-count display.
- Placeholder docs/decisions panels.

Those PM hub pieces are not backed by the current OpenAPI contract.

## Current Mobile Surface

The iOS client currently has:

- OpenAPI-shaped Swift model stubs.
- Mock repository fixtures using backend-style JSON keys.
- Project list and project detail navigation.
- Feature list and feature detail navigation.
- Mock project and feature documents.
- Editable document surfaces for descriptions, prompt buildouts, and acceptance criteria.
- Terminal tab with explicit project/feature/session/pane context.
- Mock terminal output snapshots.
- Text input, empty Enter, and basic tmux key buttons.
- Project-scoped and feature-scoped mock session lookup.

The iOS client does not yet have:

- Real generated Swift OpenAPI client wiring.
- Real backend networking.
- Real WebSocket streaming.
- Real Runestone integration; the current `RunestoneTextSurface` is an adapter boundary with a SwiftUI fallback.
- Real project/feature create or edit forms.
- Real session create/kill/open flows beyond mocked repository behavior.
- Real docs, tickets, prompt, criteria, or decisions endpoints.

## Backend To Mobile Gaps

| Area | Backend Status | Mobile Status | Gap |
| --- | --- | --- | --- |
| OpenAPI typegen | Contract exists | Handwritten OpenAPI-shaped stubs | Replace stubs with generated Swift client/types. |
| Base URL/config | Backend listens at configured URL | No real configuration screen/store | Add environment/server configuration and reachability. |
| Error handling | RFC 7807 problem responses | Mock-only errors | Add typed API error mapping and user-visible recovery states. |
| Project list/get | Available | Mocked | Wire real repository calls. |
| Project create/update/delete | Available | Not built in UI | Add mobile create/edit/delete flows. |
| Project open session | Available | Mocked | Wire call and update session context after response. |
| Feature list/get | Available | Mocked | Wire real repository calls. |
| Feature create/status update | Available | Not built in UI | Add create and status controls. |
| Session list/create/kill | Available globally | Mocked and locally scoped | Wire real list/create/kill; solve ownership scoping. |
| Pane list/output/input | Available | Mocked | Wire pane list, snapshot recovery, and input send. |
| WebSocket stream | Available | Not built | Add URL construction, lifecycle, reconnect, background recovery, and message decoding. |
| Resize | WebSocket accepts resize | Not built | Send size updates once terminal text surface exposes dimensions. |
| Docs/prompts/criteria | Not exposed | Mock editable docs | Keep mock UI, but backend needs endpoints before persistence can be real. |
| Tickets | Not exposed | Not modeled beyond docs/criteria text | Backend must expose tickets before mobile can use them structurally. |
| Session ownership | Not explicit | Mock ownership exists | Backend contract needs ownership fields or scoped session endpoints. |

## Web To Mobile Gaps

| Capability | Web Status | Mobile Status | Notes |
| --- | --- | --- | --- |
| API client | Real TypeScript client over generated types | Mock repository | Mobile needs generated Swift client and repository implementation. |
| Project create | Built | Missing | Should use native form/sheet. |
| Project detail session status | Built | Mock sessions only | Mobile should show linked session health once real sessions are wired. |
| Feature create | Built | Missing | Add after real feature repository exists. |
| Session list | Built | No standalone list | Mobile may keep terminal as primary tab but needs a discoverable session browser. |
| Session create/kill | Built | Missing | Mobile needs guardrails for destructive kill. |
| Pane selection | Built | Mock project/feature session rows | Mobile should support active pane default and pane switching. |
| Output rendering | xterm.js | TextEditor fallback behind Runestone adapter | Replace fallback with Runestone and ANSI rendering plan. |
| Output streaming | WebSocket with reconnect | Missing | Needs foreground/background lifecycle handling. |
| Output snapshot recovery | Available through API, web stream replaces full buffer | Mock snapshot only | Mobile should seed from snapshot before stream opens and after reconnect failures. |
| Input editor | CodeMirror | TextField | Mobile needs command history, multiline draft, key toolbar parity, and better focus behavior. |
| Empty Enter | Built and documented in code | Built in prototype | Preserve as a first-class button and test case. |
| Special keys | Broad toolbar | Smaller toolbar | Add missing `C-z`, `C-l`, `C-a`, `C-e`, Page/Home/End as needed. |
| Terminal resize | Built from xterm fit addon | Missing | Depends on real terminal surface dimensions. |
| PM hub tabs | Mocked in web | Partial mobile feature tabs | Mobile should selectively adopt feature docs/sessions/review/decisions when backend exists. |
| Tickets/criteria | Mocked in web hub | Criteria is editable mock text | Need backend ticket/criteria schema before building structured mobile UI. |

## Product Gaps Specific To Mobile

These are not simply web parity items:

- Recent context: persist the last selected project, feature, session, and pane so the Terminal tab opens predictably.
- Wrong-pane prevention: terminal header should always show project, feature, session, and pane, with enough contrast to prevent accidental input.
- Mobile keyboard ergonomics: key toolbar, Enter-only action, and command history need to be reachable while the keyboard is open.
- Offline/resume behavior: app foregrounding should refresh the pane snapshot before or while reconnecting the WebSocket.
- Small-screen document editing: Runestone-backed docs should handle long prompt buildouts and acceptance criteria without layout shift.
- Scoped sessions: mobile should prefer feature sessions but allow project-level sessions when a feature has no specific session.

## Suggested Implementation Order

1. **Generated API client**
   - Add Swift OpenAPI Generator.
   - Replace handwritten generated stubs.
   - Keep mock repository available for previews/tests.

2. **Real project and feature repositories**
   - Wire list/get first.
   - Add project create/update/delete.
   - Add feature create/status update.

3. **Real session and pane repositories**
   - Wire global backend endpoints.
   - Add local scoping logic using current `Project.tmuxSessionName`.
   - Document backend ownership gap in code comments or a follow-up backend ticket.

4. **Terminal transport**
   - Snapshot load.
   - WebSocket stream.
   - Reconnect/backoff.
   - Foreground refresh.
   - Resize messages.

5. **Runestone terminal/document surfaces**
   - Replace TextEditor fallback in `RunestoneTextSurface`.
   - Add ANSI/style rendering behind a renderer boundary.
   - Apply the same editor boundary to docs, prompts, criteria, and terminal drafts where appropriate.

6. **Input parity**
   - Port web behavior deliberately:
     - Send without Enter.
     - Send + Enter.
     - Empty Enter.
     - Multiline draft.
     - Command history per pane.
     - Full special-key toolbar.

7. **Docs/tickets backend planning**
   - Define OpenAPI schemas for feature docs, prompt buildouts, acceptance criteria, tickets, decisions, and transcripts.
   - Replace mobile mock document repository only after those endpoints exist.

## Backend Contract Changes Mobile Will Need

The mobile app can move forward with existing endpoints for basic project/session/terminal work, but these backend additions will remove guesswork:

- Scoped session listing:
  - `GET /api/v1/projects/{idOrSlug}/sessions`
  - `GET /api/v1/features/{id}/sessions`
- Session ownership fields:
  - `project_id`
  - `feature_id`
  - later `ticket_id`
- Feature document endpoints:
  - description
  - prompt buildout
  - acceptance criteria
  - decisions
- Ticket endpoints once the Project -> Feature -> Ticket -> Session hierarchy lands.
- Transcript/document metadata endpoints if the app is expected to browse prior session output.

## Definition Of Useful Mobile Parity

Mobile reaches useful parity when a user can:

- Pick a project.
- See and manage its features.
- Open or resume the correct session for that project or feature.
- Select a pane.
- Watch live output.
- Send text, empty Enter, and control keys reliably.
- Edit feature-facing docs or criteria where the backend supports persistence.
- Return later and land back in the same contextual terminal without ambiguity.

