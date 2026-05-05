# iOS App — Architecture State

Date: 2026-05-05

A snapshot of the architecture decisions actually in force, the gaps between
the prescribed plan and the code, and the things tickets currently depend on
without owning. Pair this with `CLAUDE.md` (prescriptive) and
`docs/feature_plans/00-overview.md` (forward plan) — this file is the
*as-built* view, dated today.

Re-read this whenever a ticket assumes a layer or type that doesn't exist
yet, or when CLAUDE.md and the feature plans appear to disagree.

## Prescribed architecture

`CLAUDE.md` locks in MVVM with a service layer above repositories:

```
View → ViewModel (@Observable @MainActor) → Service → Repository → Network/Generated → Persistence
```

Dependencies flow downward only. Repositories are the protocol boundary;
views are not supposed to import generated OpenAPI types directly.

## What is actually built today

| Layer | Status | Notes |
|---|---|---|
| Views | Present | Projects, FeatureDetail, Terminal, Settings, Documents |
| ViewModels | Present | `@Observable @MainActor`, one per screen, talk straight to the repository |
| **Services** | **Missing** | No `Core/Services/` directory, no `*Service` types |
| Repository | Present | `TmuxAgentRepository` protocol + `LiveTmuxAgentRepository` + `MockTmuxAgentRepository` + `RepositoryError` (PR #6) |
| Network | Present | Apple OpenAPI Generator output, `APIConfiguration`, `APIConfigurationStore` (PR #6) |
| Domain | Stub | `Core/Domain/` exists but only holds `WorkspaceDocument`, a leftover local type |
| Persistence | UserDefaults only | `APIConfigurationStore` |
| Coordinator / Routes | Missing | `AppModel` doubles as DI container + selected-tab holder + live-vs-mock toggle. `NavigationStack` is inline in views with `navigationDestination(for: Components.Schemas.Project.self)` |
| Tests | Boilerplate only | Xcode test targets exist; no real unit tests landed yet. The `infra-0001` workhistory describes new repository tests — verify they are wired into the test target before claiming gates pass |

## Decisions that are made and locked

1. **MVVM with `@Observable`** — not `ObservableObject` / Combine.
2. **Repository abstraction with Live + Mock implementations** — generated types as the wire format.
3. **OpenAPI Generator owns the network layer.** `Components.Schemas.*` is the canonical type surface (PR #6).
4. **`RepositoryError.problem(ProblemDetails)`** is the typed error path. No `[String: Any]` shims.
5. **Generated types stay below the repository layer** — declared in `CLAUDE.md`. **Currently violated everywhere**: views and view models freely reference `Components.Schemas.{Project,Feature,Pane,Session}`. The `infra-0001` workhistory acknowledges this; no ticket owns the cleanup.
6. **Per-tab `NavigationStack` with typed `AppRoute`** — declared. The route enum in `CLAUDE.md` (`projectList` / `paneText`) is *already stale* against the v2 plan (`agentSession` / `ticketDetail` / `docDetail`); `docs-update-agents-shell` is the ticket to reconcile that.
7. **Five-tab shell, terminal as drill-down** — replaces the current 3-tab `Projects / Terminal / Settings`. `CLAUDE.md` still describes the 3-tab world; `docs-update-agents-shell` reconciles.
8. **Theme system with explicit `ColorScheme` parameters** — no implicit defaults; the terminal stays dark in light mode (`infra-design-tokens` notes).

## Decisions deferred (no ticket)

- **Service layer.** `CLAUDE.md` prescribes one, but no ticket creates `Core/Services/` or any `*Service` type. Phase 2 repo tickets and Phase 3 screen tickets all wire view models straight to repositories. Either the layer is being quietly skipped or it will appear ad-hoc when a use case spans repositories.
- **Domain adapters.** `docs/feature_plans/20-navigation-and-data.md:150–158` calls for per-resource extensions (`Feature.progressPercent`, sorted criteria, pre-mapped `KindStyle`) and `CLAUDE.md` says "convert generated DTOs into small domain models at the repository boundary when it improves UI clarity." No ticket owns this — it will happen inside whichever repo or screen ticket needs it.
- **DI / `AppContainer`.** `CLAUDE.md` lists `AppContainer.swift` in the target tree. Today `AppModel` carries that role plus selected-tab plus live-vs-mock — three concerns in one observable. No ticket splits them; `service-app-route-coordinator` adds `RootCoordinator` but explicitly keeps `AppModel`.
- **Persistence beyond UserDefaults.** SwiftData / cache mentioned only as "lightweight local preferences/cache when needed." No data model, no ticket.
- **Test strategy.** No ticket sets up a test plan, naming conventions, or what the test target should cover.
- **Module / package split.** Everything is one app target. No ticket breaks `Core` into an SPM package.

## Implicitly assumed by tickets but not yet built

- **`@Environment(\.accent)`** — `service-tab-shell` and many Phase 3 tickets rely on it. The key lands in `infra-design-tokens`.
- **`EmptyState`, `StatusGlyph`, `Pip`, `RoundedCard`, `MetaPill`, `PillButton`, `SegmentedControl`, `ScrollChips`** — referenced casually across screen tickets. All come from `infra-component-kit`, which depends on tokens.
- **`RootCoordinator` + `AppRoute`** — screen tickets push routes (`coordinator.push(.featureDetail(...))`) without specifying who owns the binding. `service-app-route-coordinator` is where it actually lands.
- **`ActivityPoller` actor in `Core/Services/`.** `20-navigation-and-data.md:217–225` describes it; `service-inbox-screen` and the `needsYou` indicator both depend on it. No standalone ticket — it will be folded into `service-repo-activity` or `service-inbox-screen`.
- **WebSocket client.** Listed as a Network-layer responsibility; used today by `TerminalViewModel`. The real client lands in `service-terminal-websocket` (Phase 4).
- **TipTap renderer for `body_blocks`.** `service-feature-prd-tab` reads docs as JSON blocks — no ticket creates the renderer; it will appear inside that screen ticket.

## Live tensions worth resolving before Phase 3

1. **The "views do not import generated types" rule is already broken.** Every Phase 3 screen ticket will widen the violation. We need to either:
   - codify domain-model adapters as part of each Phase 2 repo ticket so view code only sees domain types, **or**
   - relax the rule and update `CLAUDE.md` to match what we actually do.
   Pick one before Phase 3 lands; a later cleanup will be a multi-screen rewrite.

2. **`AppModel` is doing too much.** `service-app-route-coordinator` will pile a `RootCoordinator` reference onto it. If DI / coordinator / settings are not split before Phase 3, view models will accumulate environment lookups that hide their actual dependencies. Lowest-cost fix: split `AppContainer` (repo + apiConfig + isUsingMock) from `RootCoordinator` (selectedTab + paths) inside `service-app-route-coordinator`, since that ticket already touches both.

3. **`CLAUDE.md` still describes the 3-tab terminal-as-tab world.** Will be fixed by `docs-update-agents-shell`. Until then, treat the feature plans as the source of truth and `CLAUDE.md` Architecture / Navigation sections as stale.

## Where to look next

- Forward plan, ticket sequencing: `docs/feature_plans/00-overview.md`.
- Tokens, colors, fonts, components: `docs/feature_plans/10-design-system.md`.
- Tab shell, routes, repo expansion: `docs/feature_plans/20-navigation-and-data.md`.
- Per-screen detail: `docs/feature_plans/30-screens.md`.
- Terminal transport: `docs/feature_plans/40-terminal.md`.
