# Navigation Shell + Data Layer

Date: 2026-05-04

This plan covers the structural work that has to land before the v2 screens can be built: the new tab shell, typed routes, and the repository layer expansion that brings the iOS data model in line with the backend OpenAPI contract.

## Tab shell

### Current

`ContentView.swift` mounts a 3-tab `TabView` (`projects`, `terminal`, `settings`) backed by `AppTab`. The terminal tab pushes a `TerminalView` driven by an `AppModel.terminalContext`.

### Target (v2)

A 5-tab `TabView` that matches the design:

```swift
enum AppTab: Hashable {
    case inbox
    case projects
    case roadmap
    case sessions
    case you
}
```

The terminal is **not** a tab in v2. It is a full-screen presentation pushed onto the active tab's `NavigationStack` (or covered modally) when the user taps an Inbox `Open pane`, a Sessions row, or a feature's `Spawn session` action.

### needs-you indicator

The Inbox tab gets a single 7pt accent dot above its icon when the activity feed has at least one `kind` in `{ question, review, mention }` that the user has not dismissed. The design's `TabBar2` accepts a `needsYou` prop — model the same on the iOS side as a derived `@Observable` value off the activity repository.

Sessions does *not* get the dot in v2 (the design only shows it on Inbox). Keep the prop available for future use.

### Mode and accent

The active tab's icon + label use the user's chosen accent (default `iris`), pulled from the You screen's preferences. Inactive tabs use `fg2`. The mode (light / dark) is read from the system + user override.

## Routing

### `AppRoute`

```swift
enum AppRoute: Hashable {
    case projectDetail(idOrSlug: String)
    case featureDetail(featureID: Int64)
    case ticketDetail(publicID: String)               // for review or future ticket page
    case docDetail(docID: Int64)
    case sessionsForFeature(featureID: Int64)
    case agentSession(sessionID: Int64)               // pushes the terminal
}
```

Each tab owns its own `NavigationStack` with a `[AppRoute]` path. `RootCoordinator` is an `@Observable` object that holds five paths (one per tab) plus the active tab.

### Deep links

The Inbox row's "Open pane" action produces an `AppRoute.agentSession(sessionID:)` and pushes it onto whatever tab is most natural — usually the current Inbox stack. The Sessions tab does the same. The terminal screen is a single view that takes an `agentSessionID` and resolves project / feature / pane context from the `AgentSession` record.

### Last-context restoration

The previous design called for "the terminal tab restores the last selected project/feature/session/pane." With terminal-as-drill-down, this becomes: on cold start, if we have a saved `lastAgentSessionID`, the You screen offers a "Resume last session" link near the top. Don't auto-push — the user should land on Inbox by default.

Save the last-active tab and route paths in `UserDefaults` (key per tab), restored on launch.

## Repository protocol expansion

### Current

`TmuxAgentRepository` covers projects, features, raw tmux sessions, panes, pane I/O, and a local `WorkspaceDocument` concept that does not map to any backend resource.

### Target

Split the protocol or break it into composed repositories — either is fine. The simpler path is to keep one protocol but group methods by resource, with sub-protocols if the file grows past ~300 lines. Either way, every method must:

- Take and return generated OpenAPI types (see `Generated/`).
- Be `async throws`.
- Map error responses (`application/problem+json`) to a typed `RepositoryError` carrying the `ProblemDetails` payload.
- Be implemented in both `LiveTmuxAgentRepository` (real HTTP) and `MockTmuxAgentRepository` (in-memory fixtures matching `data.jsx`).

### Method surface (minimum)

```swift
// Health
func health() async throws -> Components.Schemas.HealthResponse

// Projects
func listProjects() async throws -> [Components.Schemas.Project]
func getProject(idOrSlug: String) async throws -> Components.Schemas.Project
func createProject(_ body: Components.Schemas.CreateProjectRequest) async throws -> Components.Schemas.Project
func updateProject(idOrSlug: String, body: Components.Schemas.UpdateProjectRequest) async throws -> Components.Schemas.Project
func deleteProject(idOrSlug: String) async throws
func openProjectSession(idOrSlug: String) async throws -> Components.Schemas.Project

// Features
func listFeatures(projectIDOrSlug: String, status: Components.Schemas.FeatureStatus?) async throws -> [Components.Schemas.Feature]
func getFeature(id: Int64) async throws -> Components.Schemas.Feature
func createFeature(projectIDOrSlug: String, body: Components.Schemas.CreateFeatureRequest) async throws -> Components.Schemas.Feature
func updateFeatureStatus(id: Int64, status: Components.Schemas.FeatureStatus) async throws -> Components.Schemas.Feature

// Tickets
func listTickets(featureID: Int64, status: Components.Schemas.TicketStatus?) async throws -> [Components.Schemas.Ticket]
func getTicket(publicID: String) async throws -> Components.Schemas.Ticket
func createTicket(featureID: Int64, body: Components.Schemas.CreateTicketRequest) async throws -> Components.Schemas.Ticket
func updateTicket(publicID: String, body: Components.Schemas.UpdateTicketRequest) async throws -> Components.Schemas.Ticket

// Acceptance criteria
func listCriteria(ticketPublicID: String) async throws -> [Components.Schemas.AcceptanceCriterion]
func createCriterion(ticketPublicID: String, body: Components.Schemas.CreateAcceptanceCriterionRequest) async throws -> Components.Schemas.AcceptanceCriterion
func updateCriterion(id: Int64, body: Components.Schemas.UpdateAcceptanceCriterionRequest) async throws -> Components.Schemas.AcceptanceCriterion
func deleteCriterion(id: Int64) async throws

// Docs
func listFeatureDocs(featureID: Int64) async throws -> [Components.Schemas.Doc]
func getDoc(id: Int64) async throws -> Components.Schemas.Doc
func createFeatureDoc(featureID: Int64, body: Components.Schemas.CreateDocRequest) async throws -> Components.Schemas.Doc
func updateDoc(id: Int64, body: Components.Schemas.UpdateDocRequest) async throws -> Components.Schemas.Doc
func deleteDoc(id: Int64) async throws

// Decisions
func listFeatureDecisions(featureID: Int64) async throws -> [Components.Schemas.Decision]
func createFeatureDecision(featureID: Int64, body: Components.Schemas.CreateDecisionRequest) async throws -> Components.Schemas.Decision
func deleteDecision(id: Int64) async throws

// Activity
func listActivity(project: String?, feature: Int64?, since: Date?, limit: Int?) async throws -> [Components.Schemas.ActivityEvent]

// Agent sessions
func listProjectAgentSessions(projectIDOrSlug: String) async throws -> [Components.Schemas.AgentSession]
func listTicketAgentSessions(ticketPublicID: String) async throws -> [Components.Schemas.AgentSession]
func createAgentSession(_ body: Components.Schemas.CreateAgentSessionRequest) async throws -> Components.Schemas.AgentSession

// Review
func getTicketDiff(publicID: String) async throws -> Components.Schemas.TicketDiff
func approveTicket(publicID: String) async throws -> Components.Schemas.Ticket
func requestTicketChanges(publicID: String, comment: String?) async throws -> Components.Schemas.Ticket
func sendTicketBack(publicID: String, comment: String?) async throws -> Components.Schemas.Ticket

// tmux Sessions / Panes (preserved from current)
func listTmuxSessions() async throws -> [Components.Schemas.Session]
func createTmuxSession(_ body: Components.Schemas.CreateSessionRequest) async throws -> Components.Schemas.SessionCreatedResponse
func killTmuxSession(name: String) async throws
func listPanes(sessionName: String) async throws -> [Components.Schemas.Pane]
func getPaneOutput(sessionName: String, paneID: Int) async throws -> Components.Schemas.PaneOutput
func sendPaneInput(sessionName: String, paneID: Int, body: Components.Schemas.SendInputRequest) async throws -> Components.Schemas.StatusResponse
```

The exact namespacing depends on the OpenAPI generator output (likely `Components.Schemas.*`). Adapter typealiases in `Core/Domain/` keep view code from importing the Generated module directly.

### Local domain types

Most generated types are usable as-is. Build small adapters for:

- `Project.tags` — currently absent from the contract; add as a derived UI extension when the design needs them.
- `Feature.progressCached` is a fraction (0–1). The UI displays a percentage; expose `progressPercent: Int` on a `Feature` extension.
- `AcceptanceCriterion.sortOrder` is opaque; expose the array already sorted at the repository boundary.
- `ActivityEvent.kind`, `ActivityEvent.actor` — pre-map to `Color` and `Image` in a `KindStyle.swift` helper so views don't switch on raw enums.
- `WorkspaceDocument` (existing local type) — replace with `Components.Schemas.Doc` in views; keep a small typealias if the deletion is too invasive in one PR.

### Mock fixtures

Replace the JSON-string fixtures in `MockTmuxAgentRepository.swift` with structured fixtures derived from `claude_design_references/.../data.jsx`. Specifically, port:

- 4 projects (PRJ-01 tmux-agent, PRJ-02 sift, PRJ-03 paper-cuts, PRJ-04 ledger-mini) with their tagline, description, accent, icon, status, pinned, lastTouchedAt.
- ~10 features across those projects with vision, status, milestone, target_date, accent, health, tags, progress_cached, ticketsDone/total, sessions, lastTouched, pinnedDoc.
- ~14 tickets with status, branch_name (nullable), criteria_total, criteria_done, estimate, updated.
- 4 milestones (v0.3, v0.4, v0.5, v0.6).
- 10 activity events spanning kinds (commit, check, review, doc, decision, question, test, approve).
- 4 agent sessions with state, uptime, pane, cpu, ticket_id.

The fixtures should render every screen end-to-end without backend access, and previews should exercise empty / loading / error states explicitly.

## OpenAPI generator

### Current

`Core/Network/Generated/OpenAPIModels.swift` is **hand-written** despite living in a `Generated/` folder. It only knows the older Project / Feature / Session / Pane shape and predates Tickets / Docs / Decisions / ActivityEvent / AgentSession.

### Target

Use [`apple/swift-openapi-generator`](https://github.com/apple/swift-openapi-generator) with the `swift-openapi-urlsession` transport. Vendor `../api/openapi.yaml` into the iOS package or reference it via build script.

Outputs in `Core/Network/Generated/`:
- `Types.swift` — all schemas under `Components.Schemas.*`.
- `Client.swift` — strongly-typed operations (e.g., `Operations.listProjects.Input`, `.Output`).

`LiveTmuxAgentRepository` then wraps the generated client per-method, mapping `Output` cases (`.ok`, `.notFound`, etc.) into `Components.Schemas.*` returns or throws.

### Migration strategy

This is a big swap. Stage it:

1. Wire the generator package and produce `Generated/Types.swift` alongside the existing hand-written file. Compile both.
2. Migrate each repository method to the generated type one at a time. Update every call site. The `OpenAPI` enum from the hand-written file disappears module-by-module.
3. Once the hand-written file has no remaining references, delete it.

The plan is captured in `.tickets/infra-openapi-regen.md`. Expect the migration ticket to touch every existing screen — that's intentional and load-bearing for the rest of Phase 0–2.

## Configuration & errors

- Keep `APIConfiguration` and `APIConfigurationStore` as-is. They live below the generator.
- Replace `APIClientError` with `RepositoryError` that carries the generated `Components.Schemas.ProblemDetails` so views can surface field-level validation errors. Exact structure:

```swift
enum RepositoryError: Error {
    case network(URLError)
    case http(Int)
    case problem(Components.Schemas.ProblemDetails)
    case decoding(Error)
    case unsupported(String)
}
```

- `ProblemDetails.errors` (an array of `FieldError`) drives form-level validation surfacing — surface the right messages on the right form fields in create / edit sheets.

## Background polling

Activity polling is the only continuous request the app makes when not on the terminal. Implement it as:

- A `@MainActor` `ActivityPoller` actor inside `Core/Services/`.
- Owned by the Inbox view model + the global `RootCoordinator` (so the tab-bar dot can update without Inbox being mounted).
- 5 second cadence, paused when the app is backgrounded, reset on foreground.
- Cursor: the most recent `created_at` it has seen.

Stop the poller when the user is on the terminal screen — the WebSocket stream is the live signal there, and the activity feed will catch up when the user leaves.

## What downstream tickets depend on this plan

- `infra-openapi-regen` lands the generator and the new types.
- `service-tab-shell` lands the 5-tab `AppTab` and updated `ContentView`.
- `service-app-route-coordinator` lands the typed routes and per-tab `NavigationStack`.
- `service-repo-*` tickets land each resource family end-to-end.
- Every screen ticket assumes its corresponding repository method exists and the route to push it is wired.
