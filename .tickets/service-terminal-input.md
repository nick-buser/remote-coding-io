---
prefix: service
title: Terminal input bar — text field with send and empty-Enter
status: todo
branch:
---

## Description

Add the bottom input bar for the terminal. Mono `TextField` placeholder reflecting the most recent agent prompt when present, accent-colored 34pt circular send button. Long-press send to choose between `Send` (text only), `Send + Enter` (default), and `Enter only` (empty enter).

Depends on `service-terminal-shell.md`. See `docs/feature_plans/40-terminal.md`.

## Acceptance criteria

- [ ] Input bar at the bottom of the terminal screen, above the home indicator.
- [ ] Layout: HStack { rounded `TextField` (mono 14, fg2 placeholder, terminalInput bg, padding 8/14, radius 18), 34pt accent circle send button with white paper-plane glyph }.
- [ ] Container background `terminalChrome`, top 0.5pt hairline at 8% white.
- [ ] Placeholder dynamically reflects the last agent prompt (parse simple `agent ›` line endings — fall back to "send a command…" when none).
- [ ] Send button taps:
  - With text → `repository.sendPaneInput(... SendInputRequest(text: text, keys: nil, enter: true))`.
  - Without text → `... SendInputRequest(keys: ["Enter"])` (Empty Enter).
- [ ] Long-press send opens a small menu: `Send`, `Send + Enter` (default), `Enter only`. Choice is sticky for the session.
- [ ] Multi-line draft: long-press the text field opens a sheet with a multi-line `TextEditor` (Runestone-backed once `service-terminal-runestone.md` lands; plain `TextEditor` until then). Sheet's primary action is the same send.
- [ ] Successful send clears the text field. The buffer should reflect the input on the next snapshot/stream message — do not echo locally to avoid double-rendering.
- [ ] Tests:
  - Send with text fires the right request body.
  - Empty-Enter (no text + tap) fires `keys: ["Enter"]`.
  - Long-press menu changes the default send mode.
- [ ] `#Preview` renders the bar with placeholder text.

## Notes

- Empty Enter is a load-bearing UX requirement (agent prompts often need a blank Enter to confirm a default). Both the quick-keys `⏎` and the empty-text send must produce it.
- Don't echo input to the buffer on the client side — the WebSocket stream replaces the buffer when the next message arrives, and the REST snapshot will pick it up immediately. Local echo creates double-rendering.
- The accent send button should also disable + show a `ProgressView` while the request is in flight.
