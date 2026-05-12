# iOS App v2 — Implementation Overview

Date: 2026-05-04

## Purpose

The Claude Design bundle in `ios_apps/claude_design_references/remote-coding-platform/` defines an "Apple-zen" v2 of the native iOS client. This document is the entry point to the work — it explains what the design contains, how the work is sliced into phases, and which tickets implement each piece.

Read this first, then drill into the topical plans and individual tickets.

The earlier `docs/project_plans/mobile_gap_analysis.md` and `mobile_visual_architecture.md` were written before the v2 design and before the backend caught up to the PM hub hierarchy. They remain as historical context but are superseded by the documents in this folder.

## What changed since the previous plan

Two big shifts:

1. **The backend is now richer than the iOS app realizes.** `../api/openapi.yaml` already exposes Tickets, Acceptance Criteria, Docs, Decisions, Activity events, and Agent Sessions. The hand-rolled `OpenAPIModels.swift` only knows about the older Project / Feature / Session / Pane surface. Closing this gap is the load-bearing first phase.
2. **The product shape is now Project ▸ Feature ▸ Ticket ▸ Agent Session.** Tickets are first-class. Agent sessions are persistent records (with state, uptime, CPU, transcript key) distinct from raw tmux Sessions. The mobile app needs to model both.

## Design source map

- **Primary file**: `claude_design_references/remote-coding-platform/project/iOS App v2.html` — bundled canvas with two artboards, "Inbox · home screen" (5 top-level tabs) and "Drill-down · Light" (drill-down flow).
- **Source-of-truth components**: `project/ios-screens-zen.jsx` — every v2 screen as a JSX component (Inbox, InboxEmpty, Projects, ProjectDetail, FeatureDetail, Roadmap, Sessions, Terminal, You).
- **Older richer variant**: `project/ios-screens.jsx` — the pre-zen, denser version. Useful as a reference for structures we may bring back later (segmented controls, stats strip on project detail, ScrollChips, ReviewScreen, DocsScreen). The v2 zen design is the target; the dense version is the fallback when zen hides necessary information.
- **Device chrome**: `project/ios-frame.jsx` — `IOSDevice`, `IOSStatusBar`, `IOSNavBar`, `IOSGlassPill`, `IOSList`, `IOSListRow`, `IOSKeyboard`. The "liquid glass" pill recipe is `backdropFilter: blur(12px) saturate(180%)` with inset shines.
- **Tokens**: `project/styles.css` (web hub variants — Linear/Notion) and inline tokens in the JSX files. Accents: iris / amber / mint / rose / slate, each with light + dark variants in oklch space.
- **Mock data shapes**: `project/data.jsx` — Projects, Features, Tickets, Activity, Sessions (agent), Milestones. Use these to seed the mock repository.

## Tab structure (v2)

The bottom tab bar has **five** tabs, in this order:

| # | Tab | What it shows |
|---|-----|---------------|
| 1 | **Inbox** | Activity feed scoped to "needs you" — questions, reviews, decisions, mentions. |
| 2 | **Projects** | Pinned + all projects, drill-down to project / feature / ticket. |
| 3 | **Roadmap** | Milestone timeline with features grouped by milestone. |
| 4 | **Sessions** | Agent sessions, grouped by state (awaiting / active / idle). |
| 5 | **You** | Profile, workspace, accent, agent settings. |

The previous `Projects / Terminal / Settings` shell is replaced. The terminal is **not** a top-level tab in v2 — it is a full-screen drill-down reached from a Sessions row, an Inbox "Open pane" action, or a feature's Sessions sub-tab. When the terminal is visible the tab bar is hidden (the design has its own dark chrome and home-bar handling).

This is a deliberate departure from the previous `AGENTS.md` direction that called the terminal a first-class tab. The replacement keeps the spirit ("the terminal is always reachable, the context is always visible") while letting Sessions + the activity feed do the routing work. `AGENTS.md` and `claude.md` need a small update to reflect this — captured under `docs-update-agents-shell.md`.

## Information hierarchy

```
Project
└── Feature
    ├── Tickets
    │   └── Agent Session(s) (terminal pane)
    ├── Docs (PRD, design, notes, log, custom)
    └── Decisions (append-only)
```

Activity events cross-cut the hierarchy. A single `ActivityEvent` carries optional `project_id`, `feature_id`, and `ticket_id`, plus a `kind` (commit, review, doc, decision, question, test, approve, check) and a free-form `verb` and `detail`.

## Phase plan

The work is sliced into seven phases. Each phase is a coherent slice that leaves the app in a working, demonstrable state.

### Phase 0 — Foundation
Bring the iOS data layer and design system in line with the contract before touching screens.

- **`infra-openapi-regen`**: Wire Swift OpenAPI Generator and replace the hand-rolled `OpenAPIModels.swift`.
- **`infra-design-tokens`**: Theme module — colors, accent system (iris / amber / mint / rose / slate, light + dark), typography (SF Pro / SF Pro Display / JetBrains Mono), spacing, radius.
- **`infra-component-kit`**: Shared UI primitives — `StatusGlyph`, `Pip`, `RoundedCard`, `MetaPill`, `PillButton`, `SegmentedControl`, `ScrollChips`, `Chevron`, `BackButton`, `NavIconButton`, `EmptyState`.
- **`docs-update-agents-shell`**: Update `AGENTS.md` and `claude.md` to reflect the 5-tab structure and terminal-as-drill-down.

### Phase 1 — Navigation shell
Stand up the new shell so subsequent screens have a place to land.

- **`service-tab-shell`**: Replace `AppTab` and `ContentView` with the 5-tab shell. Inbox and Sessions get the unread/needsYou indicators per the design (single accent dot, no badge counts in v2).
- **`service-app-route-coordinator`**: Typed `AppRoute`, `RootCoordinator`, per-tab `NavigationStack`, deep-link from Inbox/Sessions to the terminal.

### Phase 2 — Repository expansion
Teach the repository layer about the contract surface the design relies on. Each ticket adds one resource family end-to-end (Live + Mock + tests).

- **`service-repo-tickets`**: `Ticket`, `AcceptanceCriterion`, full CRUD + criteria endpoints.
- **`service-repo-docs`**: `Doc` (TipTap `body_blocks` JSON), CRUD; replaces / adapts the local `WorkspaceDocument` concept where it overlaps.
- **`service-repo-decisions`**: `Decision`, list + append + delete.
- **`service-repo-activity`**: `ActivityEvent`, list with `project / feature / since / limit` cursor; 5s polling helper.
- **`service-repo-agent-sessions`**: `AgentSession`, list per project / per ticket, create. Distinct from raw tmux `Session`.
- **`service-repo-review`**: `TicketDiff`, approve / request-changes / send-back actions.

### Phase 3 — Screens
Build the v2 screens on top of the new shell + repositories. Most tickets are one screen each; the more complex screens get a follow-up "edit / create" ticket.

- **`service-inbox-screen`**: Inbox feed grouped Needs you / Earlier today, with kind icons and inline actions.
- **`service-projects-list`**: Pinned + all projects rounded-card sections with `ProjectRow`.
- **`service-project-detail`**: Hero (name + tagline), active features list grouped by status, secondary nav links (All tickets, Docs, Roadmap, Shipped).
- **`service-feature-detail`**: Hero (status pill + title + vision), progress bar line, three deep links (Tickets, PRD, Sessions).
- **`service-feature-tickets-tab`**: Tickets list with status glyph, criteria dots, estimate; create-ticket sheet.
- **`service-feature-prd-tab`**: Feature docs list + read-only TipTap renderer.
- **`service-feature-decisions-tab`**: Decisions list, append.
- **`service-feature-sessions-tab`**: Agent sessions for the feature, with "Spawn session" action.
- **`service-roadmap-screen`**: Milestone-focused view with page-dot navigation between milestones.
- **`service-sessions-list`**: Awaiting-you hero card and "Show all sessions" toggle.
- **`service-review-screen`**: Diff + checklist + approve/request actions.
- **`service-you-screen`**: Profile card + Workspace / Appearance / Agent settings groups.

Project and feature **create** flows ride along their respective screens but ship as separate tickets to keep PRs small:

- **`service-projects-create`**: Create-project sheet.
- **`service-projects-edit`**: Edit-project / pin / status / delete.
- **`service-feature-create`**: Create-feature sheet, scoped to a project.

### Phase 4 — Terminal experience
Replace the prototype terminal with the v2 dark chrome and wire real WebSocket transport. Land in stages so the terminal stays usable throughout.

- **`service-terminal-shell`**: Dark presentation, slim context bar (back chevron, session id + pane + tmux session, dots menu), home bar; hide tab bar while presented.
- **`service-terminal-pane-switcher`**: Pane chip switcher row above the buffer.
- **`service-terminal-renderer-boundary`**: `PaneTextRenderer` boundary; initial implementation is plain monospace, no ANSI.
- **`service-terminal-quick-keys`**: Quick-key row (esc, tab, ⌃C, ⌃D, ↑, ↓, ←, →, ⏎) wired to `SendInputRequest.keys`.
- **`service-terminal-input`**: Input field + accent send button, empty-Enter as a first-class action.
- **`service-terminal-websocket`**: Real WebSocket stream, snapshot seed, reconnect with backoff, foreground recovery.
- **`infra-runestone-package`**: Add the Runestone SwiftPM dependency.
- **`service-terminal-runestone`**: Swap the renderer to Runestone behind the existing boundary.

### Phase 5 — Polish (defer until Phases 0–4 settle)
- **`service-ansi-parser`**: ANSI color/style parsing inside `PaneTextRenderer`.
- **`service-empty-states`**: All-clear inbox, empty sessions, empty milestone copy, etc.
- **`service-mock-rich-seed`**: Rebuild the mock fixtures from `data.jsx` so previews match the design narrative.

### Phase 6 — Push notifications
Surface agent activity as APNs push notifications so the user is paged when an agent needs input or opens a review. Requires new backend endpoints (device registration + push dispatch). See `60-push-notifications.md`.

- **`infra-apns-backend`** *(parent-repo ticket)*: Add `POST /api/v1/devices` (register) and `DELETE /api/v1/devices/{token}` (deregister) to `openapi.yaml`; implement APNs dispatch on `ActivityEvent` creation for `question` and `review` kinds.
- **`infra-push-openapi-regen`**: Pull the updated contract and regenerate the Swift client.
- **`service-push-permission`**: `UNUserNotificationCenter` permission request on first meaningful interaction, APNs token → `POST /api/v1/devices`, token rotation on `didRegisterForRemoteNotificationsWithDeviceToken`.
- **`service-push-deep-link`**: `UNUserNotificationCenterDelegate.didReceive(_:)` — map push payload to `AppRoute` and navigate: `question` → terminal session, `review` → review screen, default → Inbox. Handle cold-launch case (app not running when tap arrives).
- **`service-push-settings`**: Push notifications group in You screen — master toggle, per-project mute list, quiet-hours window. Persisted in `AppSettings`.

### Phase 7 — Ticket detail + multi-scope session spawning
Complete the ticket lifecycle surface and replace the placeholder "Spawn session" button with a real multi-step spawn sheet. Sessions can be scoped to a ticket, a feature, or a project — not every session needs a specific ticket. Requires extending the backend spawn contract. See `70-spawn-ux.md`.

- **`infra-spawn-scope`** *(parent-repo ticket)*: Make `ticket_public_id` optional in `CreateAgentSessionRequest`; add optional `feature_id` and `project_id`. At least one must be present. Backend derives session name from the deepest scope provided and creates the tmux session accordingly.
- **`infra-spawn-openapi-regen`**: Pull the updated contract and regenerate the Swift client.
- **`service-ticket-detail`**: Full ticket detail view — title, description, status (editable inline), acceptance criteria (list + toggleable), branch name chip, linked agent sessions. Reached from `FeatureDetail` tickets tab and from push deep-links via `AppRoute.ticketDetail(publicID:)`.
- **`service-spawn-mock`**: Update `MockTmuxAgentRepository.createAgentSession` to accept project- and feature-scoped requests (nil `ticketId`). Derive session name from scope; return a valid `AgentSession`.
- **`service-spawn-sheet`**: Multi-step spawn sheet with cascading pickers (project → feature → ticket). Scope is determined by the entry-point context — pre-populated levels are shown as labels, unpopulated levels as pickers. Ticket level includes an inline "New ticket" path. Spawn button calls `createAgentSession` then navigates to the new terminal session.
- **`service-spawn-wiring`**: Wire spawn entry points across the app — Sessions tab `+` button (full scope picker), `FeatureDetail` Sessions sub-tab (feature pre-filled), `ProjectDetail` sessions section (project pre-filled). Replace all existing "Spawn session" stubs.

## Sequencing and dependencies

```
[infra-openapi-regen] ── [infra-design-tokens] ── [infra-component-kit]
                │
                ├── Phase-2 repo tickets (parallel)
                            │
                            ▼
                [service-tab-shell] ── [service-app-route-coordinator]
                            │
                            ▼
              Phase-3 screen tickets (parallel)
                            │
                            ▼
                Phase-4 terminal tickets (in order)
                            │
                            ▼
                       Phase-5 polish
                       /           \
           [infra-apns-backend]  [infra-spawn-scope]
                   │                     │
              Phase-6 push          Phase-7 spawn
          (push-permission,        (ticket-detail,
           push-deep-link,          spawn-mock →
           push-settings)           spawn-sheet →
                                    spawn-wiring)
```

Phases 6 and 7 are independent of each other and can run in parallel once their respective backend contracts land. `service-spawn-mock` and `service-ticket-detail` can start immediately (no backend needed); `service-spawn-sheet` and `service-spawn-wiring` need `service-spawn-mock` first and can switch to live when `infra-spawn-scope` is merged.

## Backend dependency

Phases 0–5 required no backend changes — the contract was already complete. **Phases 6 and 7 each need new backend endpoints** before their live paths can be exercised on device. The `infra-*-backend` tickets must land in the parent repo first; the `infra-*-openapi-regen` tickets then pull those changes into the iOS generated client. iOS-side work can proceed against the mock in the interim.

## Out of scope for this plan

- Search across projects/features/tickets: design shows a search icon but no flow defined; defer.
- Onboarding / first-run server URL prompt: existing `SettingsView` covers it; revisit later.
- Watch / multi-window / iPad split view: not in the v2 design.

## Where to look next

- Tokens, colors, fonts, and shared components: `10-design-system.md`.
- Tab shell, routes, and the repository protocol expansion: `20-navigation-and-data.md`.
- Per-screen detail and component composition: `30-screens.md`.
- Terminal transport, rendering, and ergonomics: `40-terminal.md`.
- Push notification architecture and flow: `60-push-notifications.md`.
- Ticket detail and multi-scope spawn UX: `70-spawn-ux.md`.
- Tickets: `.tickets/` (todo) and `.tickets/done/` (completed).
