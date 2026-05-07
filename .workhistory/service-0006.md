# service-0006: Typed AppRoute + per-tab navigation coordinator

Ticket: `.tickets/done/service-app-route-coordinator.md`

## Summary

Phase 1 of the v2 plan closes here. service-0005 swapped the tab shell;
this branch adds the routing primitive every later screen will push on.
The five tabs are now real `NavigationStack(path:)`s bound to a single
`@Observable` `RootCoordinator`, every navigation goes through a typed
`AppRoute` enum, and the active tab + per-tab path persist to
`UserDefaults` so app relaunch lands where the user left off. Visually
nothing moved — `ProjectListView` and `ProjectDetailView` still drill
into the same screens — but every tap that used to be a `NavigationLink`
is now a `coordinator.push(...)` call, which is the surface every Phase 3
screen ticket will lean on.

## Changes

- `App/AppRoute.swift` — `Hashable` enum with the six v2 routes
  (`projectDetail`, `featureDetail`, `ticketDetail`, `docDetail`,
  `sessionsForFeature`, `agentSession`). `Codable` is hand-rolled as a
  flat `[discriminator, value]` pair so persisted paths read like
  `["projectDetail", "tmux-agent"]` rather than opaque associated-value
  numerics.
- `App/RootCoordinator.swift` — `@Observable` class owning
  `selectedTab` and a `[AppTab: [AppRoute]]` path dictionary. Exposes
  `push`, `popToRoot`, `switchTab`, and `binding(for:)` so each tab can
  drive a `NavigationStack(path:)`. Persists on every mutation; restores
  on init. Corrupt UserDefaults state falls back to defaults silently
  rather than crashing.
- `ContentView.swift` — each of the five tabs is now wrapped in a
  `NavigationStack(path: coordinator.binding(for: tab))` with one
  `.navigationDestination(for: AppRoute.self)` switch. Tab selection
  reads / writes via the coordinator. `.projectDetail` and
  `.featureDetail` resolve through small async loader wrappers
  (`ProjectDetailDestination`, `FeatureDetailDestination`) that hit the
  existing `getProject(idOrSlug:)` / `getFeature(id:)` repository
  methods, so the detail-view inits stay unchanged for this ticket.
  `.ticketDetail`, `.docDetail`, and `.sessionsForFeature` push a
  `RoutePlaceholder` showing the route value + the ticket that will
  replace each one. `.agentSession` keeps the legacy `TerminalView`
  prototype until `service-terminal-shell` ships.
- `ProjectListView` / `ProjectDetailView` — `NavigationLink` rows
  migrated to `Button` + `coordinator.push(...)`. The pane rows whose
  `service-app-route-coordinator` TODO no-op'd in 0005 now push the
  `.agentSession` route. The list's outer `NavigationStack` moved out
  to `ContentView` so the coordinator owns it.
- `AppModel.selectedTab` removed — the coordinator is the single source
  of truth. `AppModel.needsYou` and `AppModel.accent` stay (not
  navigation state).
- `RootCoordinatorTests` — round-trip codec for every `AppRoute` case,
  the headline push/popToRoot acceptance criterion, per-tab path
  isolation, persistence across coordinator rebuilds, and corrupt-state
  fallback.

## Decisions

- **Inject `RootCoordinator` separately via `@Environment`, not as an
  `AppModel.coordinator` property.** The ticket called this out
  explicitly. Lets previews and tests swap a fresh coordinator per case
  without spinning up a full `AppModel`. `AppModel` keeps user-visible
  preferences; routing is its own concern.
- **Hand-rolled flat `Codable` for `AppRoute`.** Synthesised `Codable`
  on an enum with associated values produces `{"_0": ...}` JSON — fine
  for round-trip but actively hostile to the developer reading what
  ended up in `UserDefaults`. The `[discriminator, value]` shape stays
  legible (`["featureDetail", 11]`) and the encoder/decoder is short
  enough to read in one screen.
- **Persist a `[AppTab: [AppRoute]]` dictionary instead of five
  `NavigationPath`s.** `NavigationPath` has `CodableRepresentation` but
  every concrete route type has to be registered, which scales poorly
  as routes grow. A plain `[AppRoute]` per tab is `Codable` for free
  through our `AppRoute.Codable` and reads exactly as intended. Tabs
  re-create their `NavigationPath` from `paths[tab]` on render.
- **Async loader wrappers for `.projectDetail` and `.featureDetail`.**
  `ProjectDetailView(idOrSlug:)` and `FeatureDetailView(featureID:)`
  already exist with their own loading paths. Re-doing that lookup at
  the route level would have duplicated state. The wrappers `await` the
  repository call once, then hand a fully-formed `Project` /
  `Feature` to the existing detail view. Slightly more code than a
  direct route → view binding but keeps the detail view untouched and
  preview-friendly.
- **Fall back to defaults on corrupt persisted state.** A user updating
  the app could find a `UserDefaults` payload they can't decode (route
  removed, route schema changed). Crashing on launch is the worst
  failure mode; silently resetting to `.inbox` with empty paths is the
  right behaviour. The `Codable` test exercises this by writing
  garbage and verifying the next coordinator init lands clean.
- **`.agentSession` route still renders the legacy `TerminalView`.**
  The new dark-chrome terminal lands in Phase 4 (`service-terminal-shell`).
  Until then the route exists, the tap path is wired, and pane rows
  push something visible. Phase 4 swaps the destination view; the
  callers don't need to move.

## Notes

- Restoring routes that point to no-longer-existing resources (a stale
  `featureID`, deleted project slug) should fall back to the parent
  list rather than crash. The `RootCoordinator.restore()` path decodes
  the full path optimistically; failures inside the destination's
  loader surface as the existing per-screen error UI. There's no
  explicit "verify-then-keep" pre-flight today — if it becomes a
  product issue we can validate against the repository on restore,
  but the cost is a load per restored route on every cold start.
- `RoutePlaceholder` is intentionally ugly. It exists to make it
  obvious in test builds that the route is firing but the screen
  hasn't shipped yet. Each Phase 3 screen ticket replaces one
  placeholder. Grep for `RoutePlaceholder` to find the open seats.
- The pre-existing `TerminalContext` struct stayed in
  `App/AppModel.swift`. It will likely move to `Core/Domain/` when the
  terminal shell lands and the agent-session repository surface
  arrives — no value shuffling it now.
- `coordinator.binding(for:)` returns a SwiftUI `Binding` over the
  per-tab path so `NavigationStack(path:)` can mutate it directly on
  swipe-back. The setter routes back through the coordinator so
  persistence stays consistent.
