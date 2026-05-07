# service-0010: ActivityEvent listing + polling helper

Ticket: `.tickets/done/service-repo-activity.md`

## Summary

Phase 2 continues. ActivityEvents cross-cut the
Project / Feature / Ticket hierarchy and feed both the Inbox
screen and the tab-bar needs-you indicator. The contract polls
`/api/v1/activity` at a 5-second cadence using the latest
`createdAt` it has seen as the cursor; this branch lands the
repository surface plus an `@Observable` `ActivityPoller`
service that views can observe directly.

## Changes

- `TmuxAgentRepository` gains
  `listActivity(project:feature:since:limit:)`. Live wraps the
  matching generated operation. Mock filters seeded events on
  every parameter combination — `project` resolves numeric id
  or slug, `feature` filters by `feature_id`, `since`
  enforces strict greater-than (so the cursor event itself is
  excluded on the next tick), `limit` clamps to `[1, 500]`
  with a default of 100.
- `MockTmuxAgentRepository` seeds the 10 fixture events from
  the design's `data.jsx`, mapped onto the existing mock
  projects / features / tickets. A test-only
  `appendActivityEvent(_:)` helper exposes the seeded array to
  tests without forcing a separate stub repository surface.
- New `Core/Services/ActivityPoller.swift`:
  - `@Observable @MainActor final class`. `events`
    (latest-first, capped at 500) and `needsYou` (derived: any
    unseen `kind ∈ {question, review}`) are observable; the
    cursor and seen cursor are `@ObservationIgnored`.
  - `start(scope:)` drives a 5s tick loop via `Task.sleep`.
    `tick()` is exposed for tests so the timer doesn't have
    to be exercised. `stop()` cancels the task; `markSeen()`
    advances the seen cursor and re-derives `needsYou`.
- `AppModel` becomes `@MainActor` and owns a workspace-scoped
  `ActivityPoller`. The placeholder `needsYou: Bool = true` is
  replaced by a derived computed property that reads the
  poller, so `ContentView`'s Inbox `.badge(...)` stays the
  same call site but now reflects real activity. `ContentView`
  starts the poller from a `.task` block.
- 4 new `remote_codingTests` cover full-list newest-first,
  filtering on every parameter, poller cursor advancement
  across two ticks, and `needsYou` flip + `markSeen()` reset.

## Decisions

- **`@MainActor` on the poller, not an `actor`.** SwiftUI's
  `@Observable` macro emits property-tracking that runs on the
  same isolation as the type. An `actor`-based poller would
  have required every `events` / `needsYou` read to be
  `await`-ed, including from view bodies (which are
  `@MainActor`). `@MainActor @Observable` keeps the views
  unchanged; the polling work happens in a `Task` whose body
  is implicitly main-isolated by the actor-isolation rules.
- **Strict greater-than `since` filter.** The contract
  documentation hedges between `>=` and `>`; the mock and the
  `tick()` cursor use strict `>`, which is the only choice
  that keeps the next tick from re-fetching the same event.
  If the live backend ever returns the cursor event itself,
  the poller dedupes by id at the merge step (the `events`
  prepend can be tightened later if duplicate ids show up).
- **Single workspace poller on `AppModel`, additional pollers
  per screen.** Per-screen scoped pollers don't need a shared
  state actor — each `ActivityPoller` instance has its own
  buffer and cursor. The workspace one drives the global
  needs-you dot; the project / feature ones drive their own
  Inbox-style strips on detail screens. Keeping them
  independent is simpler than threading a shared store
  through.
- **`tick()` is `@discardableResult` and exposed for tests.**
  The polling loop calls `tick()` and sleeps; tests skip the
  sleep by calling `tick()` directly. Hiding `tick()` would
  have required a test-only DI seam that's not worth the
  extra surface.
- **Test stub piggy-backs on `MockTmuxAgentRepository` instead
  of a separate fake.** The repository protocol has 30
  methods; a brand-new fake would have to stub them all to
  satisfy the type. Adding a small `appendActivityEvent`
  helper to the existing mock keeps the tests self-contained.
- **`AppModel.needsYou` stays as a derived property.** The
  call site in `ContentView` reads `appModel.needsYou`;
  redirecting to a computed property that returns
  `activityPoller.needsYou` keeps the view diff to zero. The
  underlying `@Observable` macro tracks the read of
  `activityPoller.needsYou` inside the getter, so view
  invalidation propagates correctly.

## Notes

- The poller does NOT subscribe to `ScenePhase` itself.
  `service-terminal-shell` is the right place to wire the
  pause / resume — when the terminal screen takes over the
  surface, the WebSocket transport is the live signal. Keeping
  ScenePhase out of the poller means previews and tests don't
  have to provide one.
- `ActivityEvent.detail` is treated as untrusted free-form
  text; this PR does not paint it directly so no escaping
  concern lands here. The Inbox row will treat `detail` as
  display content when `service-inbox-screen` ships.
- The mock's filter resolves slug → id by scanning
  `projects`. For the small fixture set this is fine; if the
  fixture grows we can switch to a `[slug: id]` cache in
  `init`.
- `ActivityPoller.eventsCap = 500` is per-instance, not
  global. The Inbox UI shows at most a few dozen at once and
  v2 doesn't expose historical browsing — 500 is generous.
- `xcodebuild build test` was not run on this branch (Linux
  dev environment, no Swift toolchain). Build + test
  verification is left to the local Xcode pass before merge.
