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

The primary workflow is hierarchical and project-centered:

```
Project
└── Feature
    └── Session
        └── Pane text stream + input
```

The project and feature areas should feel like a mobile file browser: drill into projects, then features, then the active coding sessions for that work. Feature detail screens should have dedicated tabs for descriptions, planning notes, status, and related sessions as those backend resources become available.

The text view is a first-class tab, not a hidden detail view. It must always be reachable from the app shell, but the selected text surface is scoped to an explicit project, feature, session, and pane. Avoid global anonymous terminal screens.

### Current Focus

Build the minimum useful native app:

- List, create, view, edit, and delete projects.
- List and create features under a project.
- Open or link a project tmux session through the backend.
- List sessions and panes.
- Stream pane output over WebSocket.
- Send text and special-key input to a pane.
- Render the pane text cleanly on mobile with Runestone.

Tickets are part of the planned backend hierarchy, but the current OpenAPI contract does not expose ticket endpoints yet. Do not invent local ticket DTOs or API calls before the contract exists.

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

Use a root coordinator with typed routes:

- `projectList`
- `projectDetail(projectIDOrSlug)`
- `featureDetail(featureID)`
- `sessionDetail(sessionName, projectID, featureID?)`
- `paneText(projectID, featureID?, sessionName, paneID)`

Project and feature navigation should behave like a folder hierarchy. The text tab should restore the last selected project/feature/session/pane, but it must make that context visible and changeable.

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
    Projects/
      Views/
      ViewModels/
    FeatureDetail/
      Views/                       # Description, status, sessions tabs
      ViewModels/
    Sessions/
      Views/                       # Session and pane lists
      ViewModels/
    Terminal/
      Views/                       # Runestone text surface and input controls
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

Use Swift OpenAPI Generator for HTTP client and schema types. The expected generated surface should cover:

- `HealthResponse`
- `Session`
- `Pane`
- `PaneOutput`
- `CreateSessionRequest`
- `SendInputRequest`
- `Project`
- `CreateProjectRequest`
- `UpdateProjectRequest`
- `Feature`
- `CreateFeatureRequest`
- `UpdateFeatureStatusRequest`
- `ProblemDetails`

Generated code belongs in `Core/Network/Generated/`. Repositories own translation from generated types to app domain models.

### API Surface

Base URL is configured in `APIConfiguration.swift`; local development defaults to `http://localhost:8080`.

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

Sessions and panes:

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

### Terminal Tab Requirements

- The terminal/text tab is always present in the root tab bar.
- The selected surface is always scoped to project, feature, session, and pane context.
- The header must expose enough context to prevent sending input to the wrong pane.
- Input controls should support normal text, submit/enter, escape, interrupt (`C-c`), EOF (`C-d`), arrows, tab, and backspace.
- The view should reconnect WebSocket streams when returning to foreground.
- Use the REST output snapshot endpoint to seed or recover the view when WebSocket state is unavailable.

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
- UI tests for project drill-down, feature tabs, and opening the terminal tab with selected context.

Before opening a feature PR, run the iOS test suite from Xcode or `xcodebuild` and verify the backend contract generation still succeeds.
