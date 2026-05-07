---
prefix: service
title: Add typed AppRoute and per-tab navigation coordinator
status: done
branch: service-0006
---

## Description

Add `AppRoute` typed routes and a `RootCoordinator` that owns per-tab `NavigationStack` paths and the active tab. Wire the existing project drill-down (`ProjectListView` → `ProjectDetailView` → `FeatureDetailView`) onto the new routing primitive without changing the screens visually. Provide the route hooks the Inbox / Sessions / Terminal tickets will use later.

Depends on `service-tab-shell.md`. See `docs/feature_plans/20-navigation-and-data.md`.

## Acceptance criteria

- [ ] `App/AppRoute.swift` defines:
  ```swift
  enum AppRoute: Hashable {
      case projectDetail(idOrSlug: String)
      case featureDetail(featureID: Int64)
      case ticketDetail(publicID: String)
      case docDetail(docID: Int64)
      case sessionsForFeature(featureID: Int64)
      case agentSession(sessionID: Int64)
  }
  ```
- [ ] `App/RootCoordinator.swift` is an `@Observable` class that owns:
  - `var selectedTab: AppTab`.
  - `var paths: [AppTab: [AppRoute]]` (or five separately-named `NavigationPath`s, whichever reads cleaner).
  - `func push(_ route: AppRoute, in tab: AppTab? = nil)` that defaults to the active tab.
  - `func popToRoot(in tab: AppTab)`.
  - `func switchTab(_ tab: AppTab)`.
- [ ] `ContentView.swift` injects the coordinator into the environment and the `TabView` reads `selectedTab` via `Binding(get: ..., set: ...)`.
- [ ] Each tab's body wraps content in a `NavigationStack(path: ...)` bound to the coordinator's path for that tab.
- [ ] A single `.navigationDestination(for: AppRoute.self)` switch in each tab's stack maps routes to their views. Initially:
  - `.projectDetail` → existing `ProjectDetailView(idOrSlug:)`.
  - `.featureDetail` → existing `FeatureDetailView(featureID:)`.
  - The other cases (`.ticketDetail`, `.docDetail`, `.sessionsForFeature`, `.agentSession`) push placeholder views with the route value displayed; later tickets replace them.
- [ ] `RootCoordinator` persists the active tab and per-tab path to `UserDefaults` and restores on launch. Use a stable encoding (Codable on `AppTab` + `[AppRoute]`).
- [ ] Existing tap-handlers in `ProjectListView` and `ProjectDetailView` are migrated from `NavigationLink` to `coordinator.push(...)` calls. The visual behavior is unchanged.
- [ ] `AppModel` exposes a `coordinator: RootCoordinator` (or `RootCoordinator` is injected separately via `@Environment`). Pick one and apply consistently.
- [ ] A unit test verifies that `coordinator.push(.featureDetail(...))` followed by `coordinator.popToRoot(in: .projects)` clears the path.
- [ ] Snapshot or basic UI test: opening the app on a fresh install lands on `.inbox`. Pushing a route in `.projects` then switching tabs and back preserves the project drill-down.

## Notes

- `NavigationPath` codability: `NavigationPath` itself supports `CodableRepresentation`, but `AppRoute` cases that carry `Int64` need explicit Codable conformance. Keep the encoding readable — emit `["projectDetail", "tmux-agent"]` style, not opaque numerics.
- Restoring routes that point to no-longer-existing resources (e.g., a stale `featureID`) should fall back to the route's parent (project list / feature list) rather than crash. Implement once, in `RootCoordinator.restore()`, after each route is decoded.
- Resist adding a global `coordinator` singleton. Inject through `@Environment` so previews and tests can swap it.
- This ticket does **not** add the Inbox / Sessions / Terminal route handling — those land with their respective screen tickets. Just stub the destinations for now.
- The existing `TerminalView` is reachable only via `agentSession` route after this ticket. Until the terminal shell ticket replaces it, the destination renders the existing prototype with the legacy fixture so anything currently linking to terminal still works for previews.
