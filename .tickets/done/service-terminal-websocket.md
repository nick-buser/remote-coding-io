---
prefix: service
title: Terminal WebSocket transport — stream, reconnect, foreground recovery
status: todo
branch:
---

## Description

Replace the snapshot-only terminal buffer with a real WebSocket client connected to `/api/v1/ws/sessions/{name}/panes/{paneId}`. Decode `PaneStreamMessage` (`{ content, timestamp }`). Add reconnect with exponential backoff, foreground recovery, and resize messages.

Depends on `service-terminal-shell.md`, `service-terminal-renderer-boundary.md`. See `docs/feature_plans/40-terminal.md`.

## Acceptance criteria

- [ ] `Core/Network/WebSocketClient.swift` is a `@MainActor` `@Observable` actor with:
  - `init(configuration: APIConfiguration, sessionName: String, paneID: Int)`.
  - `func connect() async throws`.
  - `func disconnect()`.
  - `var status: WebSocketStatus` — `.connecting`, `.connected`, `.disconnected(error)`.
  - `var messages: AsyncStream<Components.Schemas.PaneStreamMessage>`.
  - `func sendResize(cols: Int, rows: Int) async throws`.
- [ ] WebSocket URL construction: scheme follows `APIConfiguration.baseURL.scheme` — `http` → `ws`, `https` → `wss`.
- [ ] Reconnect with exponential backoff: 1s, 2s, 4s, 8s, capped at 30s. Backoff resets on successful connect.
- [ ] Backgrounded app closes the socket. Foreground reopens it after a fresh REST snapshot fetch.
- [ ] Buffer lifecycle:
  - `onAppear`: render cached buffer if any, then issue REST snapshot in parallel with WebSocket open. WebSocket's first message replaces the buffer with canonical content.
  - `onDisappear`: close socket.
  - On reconnect: REST snapshot first, then reopen socket; first message replaces buffer.
- [ ] Status indicator: a small "reconnecting…" pill appears below the context bar when status is `.disconnected`. The hairline below the context bar fades from accent (connected) to muted (disconnected).
- [ ] `Resize` message sent on:
  - Buffer view's `onAppear` once layout is known.
  - Layout change events (`GeometryReader` size delta debounced 250ms).
  - Compute cols/rows from view width × `monoCharWidth` and view height × `lineHeight`.
- [ ] Tests:
  - Mock `WebSocketClient` (subprotocol with controllable status) verifies the buffer's snapshot+stream lifecycle.
  - Reconnect backoff sequence verified via injectable clock.
  - Resize message body matches `{ "resize": { "cols": N, "rows": M } }`.
- [ ] `#Preview` shows the buffer rendering live mock messages from a `MockWebSocketClient`.

## Notes

- The contract treats `PaneStreamMessage.content` as the *full* current pane content, not a delta. The renderer treats each message as a full replacement. Don't try to delta-merge.
- `URLSessionWebSocketTask` is the simplest transport; it handles reconnect itself only superficially — implement the loop in the actor.
- HTTPS upgrade: do NOT auto-upgrade `http://` → `https://`. Match what the user configured.
- Console-log the URL once on first connect for debugging; never log message bodies.
- Surface a one-time warning in the You screen the first time the user uses an `http://` server: "tmux input is unencrypted at rest on this network." Track via `UserDefaults`.
