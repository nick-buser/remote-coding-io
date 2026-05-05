---
prefix: infra
title: Wire Swift OpenAPI Generator and replace hand-rolled types
status: active
branch: infra-0001
---

## Description

The iOS app's `Core/Network/Generated/OpenAPIModels.swift` is hand-written and predates the current backend contract. The contract in `../api/openapi.yaml` now exposes Tickets, Acceptance Criteria, Docs, Decisions, Activity events, Agent Sessions, Ticket Diffs, and richer Project / Feature schemas. The hand-rolled types are missing all of that and have a stale `FeatureStatus` enum.

Wire the [`apple/swift-openapi-generator`](https://github.com/apple/swift-openapi-generator) plugin and `swift-openapi-urlsession` transport via Swift Package Manager. Generate `Types.swift` and `Client.swift` from the contract. Migrate every repository method to the generated client. Delete the hand-rolled file once it has no remaining references.

This unblocks Phase 2 (every repository expansion ticket needs the new types) and Phase 3 (every screen reads new fields like `feature.vision`, `feature.milestone`, `feature.progress_cached`, `ticket.criteria_total`).

See `docs/feature_plans/20-navigation-and-data.md` for the migration strategy.

## Acceptance criteria

- [ ] `swift-openapi-generator` plugin and `swift-openapi-urlsession` transport are listed as Swift Package dependencies in the Xcode project.
- [ ] `Core/Network/Generated/Types.swift` and `Generated/Client.swift` are produced by the generator (or regenerated during build) and are not hand-edited.
- [ ] The contract source vendored to the iOS package is byte-identical to `../api/openapi.yaml` at the time the package builds (or referenced via a build-script symlink).
- [ ] `LiveTmuxAgentRepository` is rewritten to call the generated client. Every existing call site (`listProjects`, `getProject`, `updateProject`, `listFeatures`, `getFeature`, `updateFeatureStatus`, `openProjectSession`, `listSessions`, `listSessions(projectID:)`, `listSessions(featureID:)`, `listPanes`, `getPaneOutput`, `sendPaneInput`) compiles against the new types.
- [ ] `MockTmuxAgentRepository` is updated to return generated types instead of `OpenAPI.*` types. Existing JSON fixtures decode into the generated types without loss.
- [ ] `TmuxAgentRepository` protocol uses generated `Components.Schemas.*` types in its signature (not the hand-rolled `OpenAPI.*` namespace).
- [ ] `OpenAPIModels.swift` is deleted. Searching the project for `OpenAPI.Project`, `OpenAPI.Feature`, etc. returns zero hits.
- [ ] `RepositoryError` replaces `APIClientError` and carries `Components.Schemas.ProblemDetails` on the `.problem` case.
- [ ] All existing screens (`ProjectListView`, `ProjectDetailView`, `FeatureDetailView`, `TerminalView`, `SettingsView`, `DocumentEditorView`) compile and render the same content as before the migration. No visual regressions.
- [ ] Repository tests cover at least: project list / get / update, feature list / get, session list, pane output, send pane input.
- [ ] Project builds in Xcode and `xcodebuild build-for-testing` succeeds.

## Notes

- The hand-rolled `FeatureStatus` enum has `inProgress / merged / abandoned`. The generated enum will have the contract's full set: `in_progress / review / planned / shipped / merged / abandoned`. View code that switches on these will need to handle the new cases — most should fall through to a "in flight" visual.
- `WorkspaceDocument` (the local doc concept in `Core/Domain/`) does **not** disappear in this ticket. It stays as-is until `service-repo-docs.md` lands. Keep the existing repository methods on `TmuxAgentRepository` for now so callers keep working.
- The generator's `Operations.<name>.Output` enum has cases like `.ok(.init(body: ...))`, `.notFound`, etc. Repository methods translate these into either a value or a thrown `RepositoryError`. Consolidate that mapping into a single helper to avoid scattering switch statements.
- Surface a clear build error on contract drift: when `openapi.yaml` changes shape, callers should fail to compile in obvious places. Avoid a permissive `[String: Any]` shim layer.
- Keep `APIConfiguration` and `APIConfigurationStore` intact — they live below the generator.
