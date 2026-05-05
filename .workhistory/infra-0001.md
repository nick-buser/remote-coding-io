# infra-0001: Wire Swift OpenAPI Generator and replace hand-rolled types

Ticket: `.tickets/done/infra-openapi-regen.md`

## Summary

Replaced the hand-rolled `Core/Network/Generated/OpenAPIModels.swift` with output from `apple/swift-openapi-generator` so the iOS network layer is regenerated from `api/openapi.yaml` on every build. The hand-rolled types had drifted: they were missing Tickets, AcceptanceCriteria, Decisions, ActivityEvents, AgentSessions, and TicketDiff entirely, and had a stale `FeatureStatus` enum (`inProgress / merged / abandoned`) instead of the contract's full set (`in_progress / review / planned / shipped / merged / abandoned`). Without the generator, every Phase 2 repository expansion would have re-introduced the same drift.

## Changes

- Added SPM dependencies: `swift-openapi-generator` (build-tool plugin), `swift-openapi-runtime`, `swift-openapi-urlsession`.
- Vendored `openapi.yaml` next to the iOS sources so the plugin has a stable input on a per-build basis. The vendored copy is byte-identical to `../api/openapi.yaml` at branch time.
- Added `openapi-generator-config.yaml` selecting the `Types` and `Client` modes.
- Replaced `APIClientError` with `RepositoryError`; the `.problem` case carries `Components.Schemas.ProblemDetails` so RFC 7807 responses round-trip without a `[String: Any]` shim.
- Re-typed the `TmuxAgentRepository` protocol against `Components.Schemas.*`. Every call site (12 methods across projects, features, sessions, panes) compiles against the generated client.
- `LiveTmuxAgentRepository` now drives the generated `Client` directly. `Operations.<name>.Output` cases are translated through a small helper that either returns a value or throws a typed `RepositoryError`.
- `MockTmuxAgentRepository` returns generated types; the existing JSON fixtures decode unchanged because the field names line up after the generator's idiomatic naming pass (`git_repo_url` → `gitRepoUrl`, etc.).
- Deleted `OpenAPIModels.swift` and the old `APIClient.swift`. Zero `OpenAPI.*` or `APIClientError` references remain.
- Updated `/ios-gates` to target `iPhone 17` and pass `-skipPackagePluginValidation` so the generator runs headlessly in CI.
- Added a small `GeneratedIdentifiable` extension and a shared `JSONCoding` namespace for the few places domain code still touches generated types directly.
- Repository test coverage expanded to cover project list/sort, get-by-ID-and-slug, update mutation, feature scoping + full-schema get, pane snapshot snake_case decoding, and send-input recording.

## Decisions

- **Vendor the contract, don't symlink.** Symlinking `../api/openapi.yaml` into the package would couple the iOS build to the repo layout and break if this app is ever split out. A vendored copy plus a one-line `diff -q` check at PR time is simpler and surfaces drift as a reviewable diff rather than a silent regeneration.
- **Generated types stay below the repository layer.** Views and ViewModels still consume the same domain models they did before. The generator changed the *shape* of what repositories produce, not the public surface — so feature code didn't have to be touched in this ticket.
- **`RepositoryError.problem` carries `ProblemDetails` directly,** not a string. Future error UIs can render the structured `title` / `detail` / `errors` fields without re-decoding.
- **No permissive `[String: Any]` shim.** Callers compile-fail when the contract shape changes, which is the point — silent shims hid the drift that motivated this ticket in the first place.
- **`WorkspaceDocument` and the local document repository methods stayed put.** Replacing them belongs to `service-repo-docs.md`, not here. Keeping them prevents callers from breaking before that ticket lands.

## Notes

- The generator's idiomatic naming maps `git_repo_url` to `gitRepoUrl`, not `gitRepoURL`. A test pins this so a future config flip is obvious.
- The new `FeatureStatus` cases (`review`, `planned`, `shipped`) are not yet handled visually in `FeatureDetailView`. Most should fall through to an "in flight" badge until the design tokens for them land — flagged for whichever Phase 3 ticket touches feature status visuals next.
- `xcodebuild` can stall on simulator boot when invoked headless against a shut-down `iPhone 17`. `/ios-gates` boots the simulator first to keep the build deterministic; if a future Xcode version changes default simulator behavior, that step may need revisiting.
- Future-you, when you regenerate after a contract bump: the build-tool plugin re-runs automatically, so a stale local checkout will look broken until `xcodebuild` runs once. Don't chase it as a code bug.
