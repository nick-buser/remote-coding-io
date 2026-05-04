# Terminal Experience

Date: 2026-05-04

This plan covers the terminal — the screen reached by tapping a session row, an Inbox `Open pane` button, or a feature's spawn-session flow. It is the only screen in the app with hard real-time requirements (WebSocket stream + low-latency input echo).

## Source

`TerminalZen` in `ios-screens-zen.jsx` is nearly identical to `TerminalScreen` in `ios-screens.jsx`. Both render dark; both put the buffer in `JetBrains Mono` 12.5–13pt; both use the slim context bar + quick-keys row + input bar layout. The zen variant drops the pane chip switcher row that the dense version shows.

**Decision**: Use the dense layout (with the pane chip switcher). On a phone, switching panes is a frequent operation when juggling agent sessions, and tucking it into a sheet adds friction we don't want.

## Layout

```
ZStack(alignment: .top) {
    Color.black.ignoresSafeArea()

    VStack(spacing: 0) {
        // System status bar handled by iOS

        ContextBar
            BackChevron("Sessions") accent-tinted
            VStack {
                17pt session.id (white, weight 600)
                10.5pt mono tmux_session · pane · uptime (fg2 dark)
            }
            Trailing: dots menu

        PaneChipSwitcher
            HorizontalScrollView {
                ForEach(siblingSessions) { Chip }
                Chip(plus)
            }

        TerminalBuffer
            RunestoneTextSurface (or fallback)
                .background(Color.black)
                .padding(14)
                Reads pane content from PaneStreamMessage

        QuickKeysRow
            HorizontalScrollView {
                ForEach(quickKeys) { Key($0) }   // esc tab ⌃C ⌃D ↑ ↓ ← → ⏎
            }
            .background(rgba(28,28,30,0.6))

        InputBar
            HStack {
                TextField (mono, 14pt, rounded, terminalInput bg)
                SendButton (34pt accent circle, paper-plane glyph)
            }
            .background(terminalChrome)

        // Home indicator handled by iOS
    }
}
```

The tab bar is **hidden** while the terminal is presented. Use `.toolbar(.hidden, for: .tabBar)` on the route or present full-screen via `.fullScreenCover`.

## Phasing

The terminal is best built in stages so the screen stays usable through the work. Each ticket below leaves the terminal in a working state.

### Stage 1 — Shell + context bar (`service-terminal-shell`)
Replace the existing `TerminalView` with the new dark layout. Drop the iOS chrome (no large title, no system back), replace with the slim context bar. Hide the tab bar while presented. The buffer can render plain text from the existing `getPaneOutput` snapshot — no streaming yet.

### Stage 2 — Pane chip switcher (`service-terminal-pane-switcher`)
Above the buffer, render a horizontal scroll of agent sessions in the same project + feature. Each chip: status dot (state-colored), mono session id, accent ring if active. A trailing `+` chip opens `SpawnSessionSheet`. Tap switches `currentSessionID`, which re-fetches the buffer and (after Stage 6) reconnects the WebSocket.

### Stage 3 — Renderer boundary (`service-terminal-renderer-boundary`)
Introduce `PaneTextRenderer` in `Core/Components/Terminal/`:

```swift
protocol PaneTextRenderer {
    func render(_ raw: String) -> AttributedString
    func append(_ chunk: String, to existing: AttributedString) -> AttributedString
}
```

Initial implementation `PlainPaneTextRenderer` returns the input as `AttributedString` with mono font and primary color. This boundary lets later stages (ANSI parser, prompt block segmenter) plug in without touching the view.

### Stage 4 — Quick keys (`service-terminal-quick-keys`)
Quick keys row below the buffer. Each key tap calls `repository.sendPaneInput(... body: SendInputRequest(keys: [k]))`. Empty Enter is a first-class key (`⏎`) — it sends `enter: true` (or `keys: ["Enter"]` per the contract; pick one and stick with it). The input bar already supports text + send; this ticket only adds the row above it.

Required keys: `esc`, `tab`, `⌃C` (`C-c`), `⌃D` (`C-d`), `↑`, `↓`, `←`, `→`, `⏎`.
Recommended secondary (collapsible / scrollable): `⌃Z`, `⌃L`, `⌃A`, `⌃E`, `Page Up/Down`, `Home`, `End`, `BSpace`, `BTab`.

### Stage 5 — Input bar (`service-terminal-input`)
Replace any existing input UI with the design's: mono `TextField` placeholder hint reflecting the most recent agent prompt when present, send button = 34pt circle with white paper-plane glyph on the user accent. Long-press send to choose `Send` vs `Send + Enter`. Empty input + send = `enter only` (uses the same wire as the Enter quick key).

### Stage 6 — WebSocket transport (`service-terminal-websocket`)
Replace the snapshot-only model with a real WebSocket client.

`Core/Network/WebSocketClient.swift`:
- Connects to `/api/v1/ws/sessions/{name}/panes/{paneId}`.
- Decodes server messages into `PaneStreamMessage` (`{ content, timestamp }`).
- Emits resize messages on layout change: `{ "resize": { "cols": N, "rows": M } }`.
- Reconnect with exponential backoff (1s, 2s, 4s, 8s, capped at 30s).
- Status: `connecting`, `connected`, `disconnected(error)`. Surface a small "reconnecting…" pill in the context bar when not connected.

Lifecycle:
- `onAppear`: load a snapshot from REST first (so the buffer is populated immediately), then open the socket.
- `onDisappear`: close the socket.
- `scenePhase == .active` after `.background`: refresh snapshot, reopen socket if needed.
- App backgrounded: close the socket, save the last cursor / content.

### Stage 7 — Runestone (`infra-runestone-package` + `service-terminal-runestone`)
Add the [Runestone](https://github.com/simonbs/Runestone) SwiftPM dependency. Replace the `RunestoneTextSurface` stub's fallback with the real Runestone backend. Configure: monospaced font, dark theme, line numbers off, soft-wrap on, read-only with selection.

The buffer is *appended-only* from the WebSocket — Runestone needs to handle large appends without re-laying out the whole document. Use the language `.plainText` initially.

### Stage 8 — ANSI parsing (`service-ansi-parser`)
Parse SGR escape sequences (`\x1b[...m`) inside `PaneTextRenderer`:
- 8 base colors + 8 bright (`30–37`, `90–97` foreground; `40–47`, `100–107` background).
- Bold (`1`), dim (`2`), italic (`3`), underline (`4`), reverse (`7`).
- 256-color (`38;5;N`) and 24-bit (`38;2;R;G;B`) — render directly to the closest 24-bit value.

Fold styles into the `AttributedString` produced by `render(_:)`. Keep the parser independent of SwiftUI; unit-test against fixtures.

### Stage 9 — Prompt block segmentation (`service-prompt-block-segmentation`) — defer
Detect `agent ›` / `>` / shell prompt patterns and split the buffer into collapsible blocks. The design hints at this with the `agent ›` orange glyph (question state) and accent glyph (working state). Defer until Phase 4 stabilizes.

## Reconnection and recovery

The contract gives us two recovery paths:
1. `GET /api/v1/sessions/{name}/panes/{paneId}/output` — full snapshot.
2. WebSocket stream — live deltas (server sends full content, not deltas, per `PaneStreamMessage`).

Order on `onAppear`:
1. Show the cached buffer if present (instant).
2. Issue snapshot GET in parallel with WebSocket open.
3. When WebSocket connects, the first message replaces the buffer with the canonical content.

Order on reconnect:
1. Close the dead socket.
2. Issue snapshot GET to seed (so a long disconnect doesn't show stale text).
3. Open a new socket; first message replaces buffer.

## Input safety

The previous architecture spec calls for "wrong-pane prevention." Carry this forward:

- The context bar shows `tmux_session · pane · uptime` in mono, large enough to read.
- A 0.5pt accent bar appears under the context bar when the connection is `connected`. The bar fades out when disconnected, then returns when reconnected.
- If the user switches panes while typing, prompt to confirm before discarding the draft.
- Empty Enter is explicit (Enter quick key) — never auto-trigger from the keyboard's return.

## Multi-line input

Initial scope: single-line `TextField`. Long-press the send button or tap a "draft" affordance to expand into a multi-line draft sheet (Runestone-backed). This is a follow-up ticket (`service-terminal-multiline-draft`) — capture the requirement here so the interim single-line input gets a clear upgrade path.

## Quick key persistence

Quick keys are global. Future: per-feature snippet sets (e.g., a feature's PRD doc lists three useful commands; they show as quick keys). This is `service-terminal-snippets` — defer until docs editing exists.

## Security note

The terminal sends raw input to a tmux pane. Treat the connection like SSH:
- Never log message contents in OS-level logs (verify with Console.app).
- The WebSocket URL must use the same scheme as the configured base URL (downgrade to ws:// if base is http://, ws:// otherwise wss://). Don't auto-upgrade.
- If the configured base is HTTP, surface a one-time warning in the You screen before first session — `tmux input is unencrypted at rest on this network`.

## What downstream tickets depend on this plan

- `service-terminal-shell` lands the screen + context bar.
- `service-terminal-pane-switcher` adds the chip row.
- `service-terminal-renderer-boundary` introduces `PaneTextRenderer`.
- `service-terminal-quick-keys` lands the quick keys row.
- `service-terminal-input` lands the input bar with send.
- `service-terminal-websocket` adds real transport with reconnect.
- `infra-runestone-package` adds the dependency.
- `service-terminal-runestone` swaps the renderer.
- `service-ansi-parser` extends the renderer with ANSI parsing.

Polish/extras live in Phase 5: `service-prompt-block-segmentation`, `service-terminal-multiline-draft`, `service-terminal-snippets`.
