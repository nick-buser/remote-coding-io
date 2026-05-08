# service-0033: Terminal WebSocket transport

Ticket: `.tickets/done/service-terminal-websocket.md`

## Summary

Replaces the snapshot-only terminal buffer with a live `WebSocketClient` connected
to `/api/v1/ws/sessions/{name}/panes/{id}`. Adds reconnect with exponential
backoff, foreground recovery, resize messages, and a "reconnecting…" status pill.

## Changes

- `Core/Network/WebSocketClient.swift` (new) — `@Observable @MainActor final class
  WebSocketClient`. `enum WebSocketStatus: connecting / connected /
  disconnected(Error?)`. `messages: AsyncStream<Components.Schemas.PaneStreamMessage>`.
  URL construction maps `http` → `ws`, `https` → `wss`. Backoff doubles each
  reconnect (1→2→4→8→30s cap), resets on success. `sendResize(cols:rows:)` encodes
  `{"resize":{"cols":N,"rows":M}}`. Test helpers: `webSocketURLForTesting()`,
  `encodeResizeForTesting(cols:rows:)`.
- `Features/Terminal/TerminalViewModel.swift` — `openSocket(session:configuration:)`,
  `closeSocket()`, `sendResize(cols:rows:)`. `socketStatus` drives the reconnecting
  pill visibility. Buffer lifecycle: REST snapshot on appear, then socket open;
  first message replaces buffer; close on disappear.
- `Features/Terminal/TerminalView.swift` — reconnecting pill shown when
  `socketStatus == .disconnected`; `sendResize(for:)` computes cols/rows from
  view size (~7.8pt wide, 18pt tall per char). `.onDisappear` calls `closeSocket()`.
- `remote-codingTests/WebSocketClientTests.swift` — http→ws, https→wss, path
  contains session+pane, resize encoding, initial status.

## Decisions

- **Full-replacement content.** `PaneStreamMessage.content` is the full current
  pane content, not a delta. Each message calls `renderer.render(content)` — no
  delta merging.
- **`URLSessionWebSocketTask`** as the transport. Reconnect loop lives in the
  actor — `URLSessionWebSocketTask` doesn't handle reconnect beyond superficially.
- **No auto-upgrade http → https** — match what the user configured.

## Notes

- PR #40, targeting `phase4/05-input`.
