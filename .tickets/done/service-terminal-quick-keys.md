---
prefix: service
title: Terminal quick-keys row — esc, tab, ⌃C, ⌃D, arrows, ⏎
status: todo
branch:
---

## Description

Add the quick-keys row between the buffer and the input bar. Each key sends a `SendInputRequest` with `keys: [<name>]` to the current pane. Empty Enter is a first-class key.

Depends on `service-terminal-shell.md`. See `docs/feature_plans/40-terminal.md`.

## Acceptance criteria

- [ ] Quick keys row displays, in order: `esc`, `tab`, `⌃C`, `⌃D`, `↑`, `↓`, `←`, `→`, `⏎`.
- [ ] Each key is a 32×32pt button with rounded background `rgba(255,255,255,0.08)` and 13pt mono white label.
- [ ] Row scrolls horizontally when content overflows.
- [ ] Tap dispatches `repository.sendPaneInput(sessionName:paneID:body: SendInputRequest(keys: [<wireKey>]))`.
- [ ] Wire keys mapping:
  - `esc` → `"Escape"`.
  - `tab` → `"Tab"`.
  - `⌃C` → `"C-c"`.
  - `⌃D` → `"C-d"`.
  - `↑` → `"Up"`.
  - `↓` → `"Down"`.
  - `←` → `"Left"`.
  - `→` → `"Right"`.
  - `⏎` → `"Enter"`.
- [ ] Tap feedback: a brief 0.1s scale + opacity transition on tap.
- [ ] Behind a "More keys" overflow chevron at the end of the row, expose less-common keys (`⌃Z`, `⌃L`, `⌃A`, `⌃E`, `Page Up`, `Page Down`, `Home`, `End`, `BSpace`, `BTab`).
- [ ] Tests:
  - Tapping each key calls `sendPaneInput` with the correct `keys` array.
  - Empty Enter goes through (the `⏎` button works without text in the input bar).
- [ ] `#Preview` renders the row in the dark terminal context.

## Notes

- Match the design's row background `rgba(28,28,30,0.6)` with a 0.5pt top hairline at 8% white.
- The contract accepts both `keys: ["Enter"]` and the legacy `enter: true`. Use the `keys` form everywhere — `enter` is kept around for backward compat only.
- Don't gate quick keys on input bar focus. Keys fire whether the user has typed something or not.
- The "More keys" expansion can be a horizontal scroll (the existing row already scrolls — just add more content past the chevron) or an action sheet. Pick scroll for v1.
