# tmux-agent iOS Client

## Project Overview

Native iOS client for the `tmux-agent` backend. The app exists because the mobile web experience for remote coding through tmux is too constrained to maintain well. The iOS app should provide a clean project-management surface plus an always-available text session surface for reading tmux output and sending input.

- **App target:** `remote-coding`
- **Bundle ID:** `com.nickb.remote-coding`
- **Current scaffold:** SwiftUI app in `ios_apps/remote-coding`
- **Current deployment target:** iOS `26.4` as generated in the Xcode project
- **Dependency management:** Swift Package Manager
- **Backend contract:** `../api/openapi.yaml`
- **Active plan:** `docs/feature_plans/00-overview.md` — read this first. It defines the v2 design scope, the five-phase ticket sequencing, and which ticket to pick up next.

### Product Shape

The v2 design (see `docs/feature_plans/00-overview.md`) reframes the app
around a 5-tab bottom shell — Inbox, Projects, Roadmap, Sessions, You — and
treats the terminal as a full-screen drill-down rather than a top-level tab.
The information hierarchy is:

```
Project
└── Feature
    ├── Tickets
    │   └── Agent Session(s) (terminal pane)
    ├── Docs (PRD, design, notes, log, custom)
    └── Decisions (append-only)
```

`ActivityEvent` records cross-cut the hierarchy and feed the Inbox. `AgentSession`
is a persistent record (state, uptime, transcript key) bound to a ticket; the
raw tmux `Session` / `Pane` surface remains for transport.

Drill-down should feel like a mobile file browser: Projects → Project →
Feature → Tickets / Docs / Decisions / Sessions. The terminal is reachable
from a Sessions row, an Inbox `Open pane` action, or a feature's Sessions
sub-tab — when it is presented the tab bar is hidden. The selected
terminal surface is always scoped to an explicit project, feature, session,
and pane; never a global anonymous terminal.

### Current Focus

The app is being rebuilt against the v2 design across five phases (see
`docs/feature_plans/00-overview.md`). The current scope is:

- Phase 0 — foundation: OpenAPI generator, theme tokens, shared component kit.
- Phase 1 — navigation: 5-tab shell, typed `AppRoute`, root coordinator.
- Phase 2 — repositories: Tickets, Acceptance Criteria, Docs, Decisions,
  Activity, Agent Sessions, Review (each end-to-end with Live + Mock + tests).
- Phase 3 — screens: Inbox, Projects list / detail, Feature detail tabs
  (Tickets, PRD, Decisions, Sessions), Roadmap, Sessions, Review, You.
- Phase 4 — terminal: dark chrome, pane switcher, renderer boundary, quick
  keys, input row, real WebSocket transport, then Runestone.
- Phase 5 — polish: ANSI parsing, empty states, mock fixture rebuild.

The OpenAPI contract already exposes Tickets, Acceptance Criteria, Docs,
Decisions, Activity, Agent Sessions, and Review (diff / approve / request /
send-back). All app work flows through generated types — do not handwrite
DTOs that duplicate `../api/openapi.yaml`.

---

## v2 design reference

The v2 design and ticket plan live alongside the code:

- `claude_design_references/remote-coding-platform/README.md` — Claude Design
  bundle: `iOS App v2.html` artboards, `ios-screens-zen.jsx` (source-of-truth
  per-screen JSX), `ios-frame.jsx` (device chrome / liquid-glass pill),
  `styles.css` and inline tokens, `data.jsx` mock fixtures.
- `docs/feature_plans/00-overview.md` — phase plan, ticket sequencing,
  information hierarchy, dependency graph. Read first.
- `docs/feature_plans/10-design-system.md` — tokens, accents, typography,
  component inventory.
- `docs/feature_plans/20-navigation-and-data.md` — tab shell, typed routes,
  repository protocol expansion.
- `docs/feature_plans/30-screens.md` — per-screen detail and component
  composition.
- `docs/feature_plans/40-terminal.md` — terminal transport, rendering,
  ergonomics.

The earlier `docs/project_plans/mobile_gap_analysis.md` and
`mobile_visual_architecture.md` predate the v2 design. They are kept for
historical context but are superseded by the documents in
`docs/feature_plans/`.

---

## Workflow

Follow the root repository workflow unless the iOS app is intentionally split into its own repository.

### First action

Always run this before inspecting or editing:

```sh
git fetch origin
```

### Git rules

- Never push directly to `main`.
- Branch naming: `<prefix>-<####>`, zero-padded 4-digit number. Numbering is **per-prefix** — each of `service-`, `fix-`, `docs-`, `chore-`, `infra-` has its own counter. The next `service-NNNN` is computed by scanning only existing `service-NNNN` branches (local + remote) and ticket / work-history files. Use `~/.claude/bin/branch-new <prefix> [title]` (or the `/branch-new` slash command) — it does the per-prefix scan correctly.
- Do **not** delete merged branches from `origin`. The branch-name ledger is the source of truth for the per-prefix counter; deleting a remote branch leaves only `.workhistory/` to keep the number reserved.
- Before every push, verify the branch still has an open PR:

```sh
gh pr list --head <branch-name> --json state,number
```

- If the PR is merged or closed, stop and create a new branch from updated `main`.
- Stage every file created or modified for the task.
- Do not read `.env` files. `.env.example` is safe.

### Ticket system

Tickets live in `.tickets/`. They capture scope and acceptance criteria **before** work begins. Creating a ticket is recommended but not required — small chores or obvious fixes can go straight to a branch.

**Naming:** `<prefix>-<short-description>.md` — prefix only, no branch number (numbers are assigned when the branch is created).

```
.tickets/service-project-list-view.md
.tickets/fix-websocket-reconnect.md
```

**Status flow:** `todo → active → done`. When a ticket is done, move it to `.tickets/done/` rather than deleting it.

**Template:**

```markdown
---
prefix: service
title: Add project list view
status: todo   # todo | active | done
branch:        # filled in once branch is created, e.g. service-0005
---

## Description

## Acceptance criteria

- [ ] ...

## Notes
```

### Work history

At the end of every ticket, add a reflective work-history note in:

```sh
.workhistory/<prefix-####>.md
```

This is not a changelog. Write it for future maintainers: what changed, why the direction was chosen, what tradeoffs or follow-up constraints matter, and what would be easy to forget later. The filename must match the branch name exactly (e.g., `fix-0002.md`). If a ticket exists for the work, reference it in the header.

**Template:**

```markdown
# <prefix-####>: <title>

Ticket: `.tickets/<prefix>-<short-description>.md`

## Summary

## Changes

## Decisions

## Notes
```

### iOS folder note

`ios_apps/` is currently ignored by the root `.gitignore` and also contains its own `.git` directory with its own GitHub remote (`git@github.com:nick-buser/remote-coding-io.git`). Use the `gh` CLI for PRs here — `tea` / Gitea are root-repo only. When working on the app, check the iOS repo state directly:

```sh
git -C ios_apps status --short --branch
```

If the iOS app is later folded into the root repo, remove the nested git repository and update `.gitignore` deliberately in the same PR.

### Verifying iOS work

Before opening a PR, run the iOS build + tests. The `/ios-gates` slash command is the canonical wrapper, but the underlying invocation is:

```sh
xcodebuild \
  -project remote-coding/remote-coding.xcodeproj \
  -scheme remote-coding \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  build test
```

`-skipPackagePluginValidation` is required so the `OpenAPIGenerator` build-tool plugin runs headlessly. If the project structure changes (new scheme, renamed target, different bundled simulator generation), update both this snippet and `.claude/commands/ios-gates.md` together.

---

## Architecture

Use SwiftUI with MVVM and Observation. Keep networking and generated types below the feature layer so views stay focused on presentation and intent.

### Layer Responsibilities

Dependencies flow downward only. A layer must not import or reference a layer above it.

| Layer | Contains | May Depend On |
| --- | --- | --- |
| **Views** | SwiftUI views, reusable UI components, Runestone wrappers | ViewModels |
| **ViewModels** | `@Observable @MainActor` state and user intent handlers | Services |
| **Services** | Use cases and orchestration for projects, features, sessions, panes | Repositories |
| **Repositories** | API-backed data access abstractions | API client, generated OpenAPI types, WebSocket client |
| **Network** | HTTP client, generated OpenAPI client/types, WebSocket stream client | Foundation, generated code |
| **Persistence** | Lightweight local preferences/cache when needed | Foundation/SwiftData |

Views should not import generated OpenAPI types directly. Convert generated DTOs into small domain models at the repository boundary when it improves UI clarity.

### Navigation

The bottom tab bar has **five** tabs in this order:

| # | Tab | What it shows |
|---|-----|---------------|
| 1 | **Inbox** | Activity feed scoped to "needs you" — questions, reviews, decisions, mentions. |
| 2 | **Projects** | Pinned + all projects, drill-down to project / feature / ticket. |
| 3 | **Roadmap** | Milestone timeline with features grouped by milestone. |
| 4 | **Sessions** | Agent sessions, grouped by state (awaiting / active / idle). |
| 5 | **You** | Profile, workspace, accent, agent settings. |

The terminal is **not** a top-level tab. It is a full-screen drill-down
reached from a Sessions row, an Inbox `Open pane` action, or a feature's
Sessions sub-tab. When the terminal is visible the tab bar is hidden — it
brings its own dark chrome and home-bar handling.

Use a root coordinator with typed routes. The set the v2 plan calls for
(see `docs/feature_plans/20-navigation-and-data.md`):

- `inbox`, `projects`, `roadmap`, `sessions`, `you` — top-level tab roots
- `projectDetail(projectIDOrSlug)`
- `featureDetail(featureID)`
- `ticketDetail(publicID:)`
- `docDetail(docID:)`
- `agentSession(sessionID:)` — full-screen terminal for one agent session
- `review(ticketPublicID:)` — diff + checklist surface
- `sessionDetail(sessionName, projectID, featureID?)` — raw tmux session
  (kept for parity with the existing repository surface; the v2 routes
  prefer `agentSession`)

Project, feature, and ticket navigation should behave like a folder
hierarchy. The terminal route should restore the last-selected project /
feature / ticket / agent session, but it must make that context visible
and changeable in the slim context bar at the top of the surface.

---

## Directory Structure

Use this target structure as the app grows:

```
remote-coding/
  App/
    RemoteCodingApp.swift          # App entry point
    AppContainer.swift             # Dependency container
    RootCoordinator.swift          # Tab/navigation ownership
    AppRoute.swift                 # Typed navigation routes

  Features/
    Inbox/
      Views/                       # Activity feed grouped by Needs you / Earlier
      ViewModels/
    Projects/
      Views/                       # Projects list + ProjectDetail
      ViewModels/
    FeatureDetail/
      Views/                       # Tickets / PRD / Decisions / Sessions sub-tabs
      ViewModels/
    Roadmap/
      Views/                       # Milestone timeline with page-dot navigation
      ViewModels/
    Sessions/
      Views/                       # Agent sessions list, awaiting-you hero card
      ViewModels/
    Review/
      Views/                       # Ticket diff + approve / request changes / send back
      ViewModels/
    You/
      Views/                       # Profile + Workspace / Appearance / Agent settings
      ViewModels/
    Terminal/
      Views/                       # Full-screen drill-down: Runestone surface, quick keys, input
      ViewModels/

  Core/
    Domain/
      ProjectModel.swift
      FeatureModel.swift
      SessionModel.swift
      PaneModel.swift
    Services/
      ProjectService.swift
      FeatureService.swift
      SessionService.swift
      PaneStreamService.swift
    Repositories/
      ProjectRepository.swift
      FeatureRepository.swift
      SessionRepository.swift
    Network/
      APIConfiguration.swift
      APIClient.swift
      WebSocketClient.swift
      Generated/                   # OpenAPI-generated files only
    Persistence/
      AppSettings.swift
      RecentContextStore.swift
    Components/
      StatusBadge.swift
      EmptyStateView.swift
      ErrorBanner.swift
    Theme/
      Colors.swift
      Spacing.swift
      Typography.swift

  Resources/
    Assets.xcassets
    Localizable.xcstrings
```

Keep generated OpenAPI output isolated under `Core/Network/Generated/`. Do not manually edit generated files.

---

## Backend Contract

The iOS app must use `../api/openapi.yaml` as the exclusive HTTP API contract.

- Do not handwrite request or response DTOs that duplicate OpenAPI schemas.
- Do not add endpoints in the app before they exist in `api/openapi.yaml`.
- If the backend changes, update `api/openapi.yaml` first, regenerate the Swift client/types, then adapt app code.
- WebSocket message shapes documented in OpenAPI should also be mirrored from generated or contract-owned types where possible.

### Type Generation

Use Swift OpenAPI Generator for HTTP client and schema types. The
generated surface (under `Components.Schemas.*`) covers:

- System: `HealthResponse`, `StatusResponse`, `ProblemDetails`,
  `FieldError`.
- Projects: `Project`, `ProjectStatus`, `CreateProjectRequest`,
  `UpdateProjectRequest`.
- Features: `Feature`, `FeatureStatus`, `CreateFeatureRequest`,
  `UpdateFeatureStatusRequest`.
- Tickets: `Ticket`, `TicketStatus`, `CreateTicketRequest`,
  `UpdateTicketRequest`.
- Acceptance Criteria: `AcceptanceCriterion`,
  `CreateAcceptanceCriterionRequest`,
  `UpdateAcceptanceCriterionRequest`.
- Docs: `Doc`, `DocKind`, `CreateDocRequest`, `UpdateDocRequest`.
- Decisions: `Decision`, `DecisionActor`, `CreateDecisionRequest`.
- Activity: `ActivityEvent`, `ActivityKind`, `ActivityActor`.
- Agent Sessions: `AgentSession`, `SessionState`,
  `CreateAgentSessionRequest`.
- Review: `TicketDiff`, `FileDiff`, `FileChange`, `ReviewActionRequest`.
- Raw tmux surface: `Session`, `Pane`, `PaneOutput`,
  `CreateSessionRequest`, `SessionCreatedResponse`, `SendInputRequest`,
  `PaneStreamMessage`, `PaneResizeRequest`.

The generator runs with `namingStrategy: idiomatic` so snake_case JSON
keys map to camelCase Swift identifiers via `CodingKeys`. Generated code
is produced in DerivedData under `BuildToolPluginIntermediates/` — it
is not committed and is regenerated on every clean build. Repositories
own translation from generated types to app domain models; views must
not import `Components.Schemas.*` directly.

### API Surface

Base URL is configured in `APIConfiguration.swift`; local development
defaults to `http://localhost:8080`. The full contract lives in
`../api/openapi.yaml` — these tables are a navigation aid, not a
substitute. If a row here disagrees with the spec, the spec wins.

System:

| Action | Method | Path |
| --- | --- | --- |
| Health check | GET | `/healthz` |

Projects:

| Action | Method | Path |
| --- | --- | --- |
| List projects | GET | `/api/v1/projects` |
| Create project | POST | `/api/v1/projects` |
| Get project by ID or slug | GET | `/api/v1/projects/{idOrSlug}` |
| Update project | PUT | `/api/v1/projects/{idOrSlug}` |
| Delete project | DELETE | `/api/v1/projects/{idOrSlug}` |
| Open/link tmux session | POST | `/api/v1/projects/{idOrSlug}/session` |

Features:

| Action | Method | Path |
| --- | --- | --- |
| List project features | GET | `/api/v1/projects/{idOrSlug}/features` |
| Create project feature | POST | `/api/v1/projects/{idOrSlug}/features` |
| Get feature | GET | `/api/v1/features/{id}` |
| Update feature status | PUT | `/api/v1/features/{id}` |

Tickets:

| Action | Method | Path |
| --- | --- | --- |
| List feature tickets | GET | `/api/v1/features/{id}/tickets` |
| Create feature ticket | POST | `/api/v1/features/{id}/tickets` |
| Get ticket by public ID | GET | `/api/v1/tickets/{publicId}` |
| Update ticket | PATCH | `/api/v1/tickets/{publicId}` |

Acceptance criteria:

| Action | Method | Path |
| --- | --- | --- |
| List ticket criteria | GET | `/api/v1/tickets/{publicId}/criteria` |
| Append ticket criterion | POST | `/api/v1/tickets/{publicId}/criteria` |
| Update criterion | PATCH | `/api/v1/criteria/{id}` |
| Delete criterion | DELETE | `/api/v1/criteria/{id}` |

Docs:

| Action | Method | Path |
| --- | --- | --- |
| List feature docs | GET | `/api/v1/features/{id}/docs` |
| Create feature doc | POST | `/api/v1/features/{id}/docs` |
| Get doc | GET | `/api/v1/docs/{id}` |
| Update doc | PATCH | `/api/v1/docs/{id}` |
| Delete doc | DELETE | `/api/v1/docs/{id}` |

Decisions:

| Action | Method | Path |
| --- | --- | --- |
| List feature decisions | GET | `/api/v1/features/{id}/decisions` |
| Append feature decision | POST | `/api/v1/features/{id}/decisions` |
| Delete decision | DELETE | `/api/v1/decisions/{id}` |

Review (ticket diff + actions):

| Action | Method | Path |
| --- | --- | --- |
| Get ticket diff | GET | `/api/v1/tickets/{publicId}/diff` |
| Approve ticket | POST | `/api/v1/tickets/{publicId}/approve` |
| Request changes | POST | `/api/v1/tickets/{publicId}/request-changes` |
| Send back to doing | POST | `/api/v1/tickets/{publicId}/send-back` |

Activity:

| Action | Method | Path |
| --- | --- | --- |
| List activity events | GET | `/api/v1/activity` |

Agent sessions (persistent ticket-bound records, distinct from raw tmux):

| Action | Method | Path |
| --- | --- | --- |
| List project agent sessions | GET | `/api/v1/projects/{idOrSlug}/sessions` |
| List ticket agent sessions | GET | `/api/v1/tickets/{publicId}/sessions` |
| Create agent session | POST | `/api/v1/agent-sessions` |

Sessions and panes (raw tmux transport — used by the terminal surface):

| Action | Method | Path |
| --- | --- | --- |
| List sessions | GET | `/api/v1/sessions` |
| Create session | POST | `/api/v1/sessions` |
| Kill session | DELETE | `/api/v1/sessions/{name}` |
| List panes | GET | `/api/v1/sessions/{name}/panes` |
| Get pane output snapshot | GET | `/api/v1/sessions/{name}/panes/{paneId}/output` |
| Send pane input | POST | `/api/v1/sessions/{name}/panes/{paneId}/input` |
| Stream pane output | WebSocket | `/api/v1/ws/sessions/{name}/panes/{paneId}` |

### Important Backend Details

- Project identifiers can be numeric IDs or slugs.
- `POST /api/v1/projects/{idOrSlug}/session` creates a tmux session using `project.local_repo_path` and persists `project.tmux_session_name` when needed.
- Pane IDs are integer pane indexes.
- `SendInputRequest` accepts `text`, `keys`, and `enter`. Use `keys` for tmux special keys such as `Enter`, `Escape`, `Tab`, `BSpace`, arrow keys, `C-c`, and `C-d`.
- WebSocket server messages contain the current pane `content` and a `timestamp`.
- WebSocket client resize messages use `{ "resize": { "cols": 120, "rows": 40 } }`.
- Errors use RFC 7807 `application/problem+json`.

---

## Terminal Text Experience

Use Runestone for the text render and input surface. Treat it as the foundation for a progressively richer mobile coding transcript, not as a raw `Text` dump.

### Terminal Surface Requirements

- The terminal is presented as a full-screen drill-down from Sessions,
  Inbox `Open pane` actions, or a feature's Sessions sub-tab — it is not
  a top-level tab. While presented, the bottom tab bar is hidden.
- The selected surface is always scoped to an explicit project, feature,
  agent session, and pane. No global anonymous terminal.
- The slim context bar at the top of the surface (back chevron, session
  id + pane + tmux session, dots menu) must expose enough context to
  prevent sending input to the wrong pane.
- Input controls support normal text, submit / enter, escape, interrupt
  (`C-c`), EOF (`C-d`), arrows, tab, and backspace, wired through the
  `keys` field of `SendInputRequest`.
- The view reconnects WebSocket streams when returning to foreground and
  uses the REST output snapshot endpoint to seed or recover when the
  WebSocket is unavailable.

### Rendering Plan

Start simple and preserve room for formatting:

1. Render pane content in Runestone as monospaced editable/read-only text.
2. Add ANSI color/style parsing behind a renderer boundary.
3. Add prompt/output block segmentation for readability.
4. Add copy/share affordances for selected output.
5. Add mobile-friendly command history and reusable snippets.

Do not couple backend stream parsing directly to SwiftUI views. Keep a small `PaneTextRenderer` or equivalent boundary so formatting can improve without rewriting session transport.

---

## Testing

Use focused tests around transformation and transport boundaries:

- Repository tests for generated-type to domain-model mapping.
- ViewModel tests for loading, empty, error, and retry states.
- WebSocket client tests for message decoding and reconnect behavior.
- Terminal renderer tests for ANSI/style parsing as that support is added.
- UI tests for project drill-down, feature sub-tabs, and presenting the terminal surface with the correct project / feature / session / pane context.

Before opening a feature PR, run the iOS test suite from Xcode or `xcodebuild` and verify the backend contract generation still succeeds.
