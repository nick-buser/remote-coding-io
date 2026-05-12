# Phase 7 — Ticket detail + multi-scope session spawning

Date: 2026-05-12

## Goal

Two things that belong together: a real ticket detail view that makes the
ticket lifecycle visible and actionable, and a proper "Spawn session" flow
that works at three scopes — ticket, feature, and project.

Not every session needs to be precisely ticket-bound. An agent working on a
feature across several tickets benefits from a feature-scoped session that
isn't glued to one branch. A project-level session is useful for exploration,
CI watching, or repo-wide commands. The spawn sheet handles all three.

## Scope model

```
Project ──► Feature ──► Ticket
  │             │          │
  └ project-    └ feature-  └ ticket-scoped session
    scoped        scoped      (existing, always had a branch)
    session       session
```

A **ticket-scoped** session binds to one branch and one acceptance checklist.
A **feature-scoped** session can range across a feature's tickets; the agent's
context window is the feature's PRD, decisions, and open ticket list.
A **project-scoped** session has no feature context pre-loaded; useful for
cross-cutting work (CI, dependency updates, docs).

The spawn sheet is the same component at all three entry points; the entry
point context pre-fills higher levels and determines whether lower levels are
required.

## Backend contract change

### `infra-spawn-scope` (parent-repo ticket)

`CreateAgentSessionRequest.ticket_public_id` becomes optional. Two new
optional fields are added:

```yaml
CreateAgentSessionRequest:
  type: object
  properties:
    ticket_public_id:
      type: string
      pattern: "^TMX-[0-9]{4}$"
      description: Present for ticket-scoped sessions.
    feature_id:
      type: integer
      format: int64
      description: Present for feature-scoped sessions. Ignored if ticket_public_id is set.
    project_id:
      type: integer
      format: int64
      description: Present for project-scoped sessions. Ignored if feature_id or ticket_public_id is set.
    tmux_session:
      type: string
      description: Optional override; derived from scope when omitted.
    state:
      $ref: "#/components/schemas/SessionState"
    pane:
      type: string
    cpu:
      type: number
```

Validation: at least one of `ticket_public_id`, `feature_id`, `project_id`
must be present. If multiple are given they must be consistent (ticket must
belong to the feature, feature must belong to the project).

**Derived session names:**

| Scope | Template |
|-------|----------|
| Ticket | `<project_slug>__<feature_slug>__<branch_slug>` (existing) |
| Feature | `<project_slug>__<feature_slug>__session_<epoch_sec>` |
| Project | `<project_slug>__session_<epoch_sec>` |

The epoch suffix prevents collisions when spawning multiple sessions in the
same feature or project scope.

**Agent context injection:** The backend injects different context bundles
into the tmux pane depending on scope:
- Ticket: PRD + decisions + acceptance checklist (existing behaviour)
- Feature: PRD + decisions + open ticket list (no single checklist)
- Project: project brief only

## iOS tickets

### `infra-spawn-openapi-regen`

Pull the updated `CreateAgentSessionRequest` schema and regenerate the Swift
client. Update `TmuxAgentRepository.createAgentSession` signature if needed —
the generated type change is sufficient; no protocol change required because
the method already accepts the full request body.

### `service-ticket-detail`

**What it shows:**

```
TicketDetailView
├── Header: public_id chip · status pill (tappable → status picker)
├── Title (editable inline on tap)
├── Description (editable inline on tap, multiline)
├── Branch chip (copy on tap)
├── Estimate badge
├── Acceptance criteria
│   ├── Each criterion: toggle (done/not done) + text
│   └── + Add criterion row
└── Agent sessions section
    ├── Each session: state badge · session id · uptime · Open pane →
    └── Spawn session button (opens SpawnSheet pre-filled to this ticket)
```

**Navigation:** `AppRoute.ticketDetail(publicID:)` is already defined in
`RootCoordinator`. Wire it from `FeatureTicketsTab` row taps. Push deep-links
for `review` kind should also pass through `ticketDetail` before going on to
the review screen so the user has a back-navigation stack.

**Editing:** Status and criteria toggles are optimistic — update local state
immediately and call the repository in the background. Roll back on failure
with an `ErrorBanner`. Title and description use an inline tap-to-edit pattern
consistent with `ProjectDetailView`.

**Acceptance criteria:** Use `listCriteria`, `createCriterion`,
`updateCriterion`, `deleteCriterion` from the existing repository surface.
Criteria rows are swipe-deletable.

### `service-spawn-mock`

Update `MockTmuxAgentRepository.createAgentSession` before building the real
sheet so previews and tests work without a backend:

- If `body.ticketPublicId` is nil AND `body.featureId != nil`: look up the
  feature, derive a session name as `<feature_slug>__session_<id>`, create an
  `AgentSession` with `ticketId = nil`.
- If both are nil AND `body.projectId != nil`: derive `<project_slug>__session_<id>`.
- Validation mirrors the backend: at least one scope field required.

Add two fixture sessions in `seedAgentSessions`:

- One feature-scoped session on FEAT-019 (feature-context-bundle) showing
  state `active`, to exercise the feature-scoped list view.
- One project-scoped session on tmux-agent showing state `idle`, to show
  in the Sessions tab and ProjectDetail.

### `service-spawn-sheet`

A modal sheet that collects scope and fires `createAgentSession`.

**Entry-point context:**

```swift
enum SpawnEntry {
    case sessionsTab                          // no pre-fill; show scope picker
    case project(Components.Schemas.Project) // project pre-filled; show feature picker
    case feature(Components.Schemas.Feature,
                 Components.Schemas.Project) // project+feature pre-filled; show ticket picker
}
```

**Sheet structure:**

```
SpawnSheet
├── Scope selector (segmented or chip): Ticket · Feature · Project
│   (hidden / locked when entry already implies scope)
├── Project row
│   ├── If pre-filled: label (not interactive)
│   └── If not: picker list of all projects
├── Feature row (visible when scope ≠ Project)
│   ├── If pre-filled: label
│   ├── If scope = Feature: picker of project's features (required)
│   └── If scope = Ticket: picker of project's features (required)
├── Ticket row (visible when scope = Ticket)
│   ├── Picker of feature's open tickets
│   └── "New ticket" option → inline mini-form (title + estimate only)
│       that calls createTicket first, then pre-selects the result
└── Footer
    ├── Session name preview (derived, greyed out, monospace)
    └── Spawn button (accent, disabled until scope is satisfied)
```

**Post-spawn navigation:** On success, dismiss the sheet and push
`AppRoute.agentSession(sessionID: created.id)` into the appropriate tab stack.

**Error handling:** Show an `ErrorBanner` inside the sheet on failure; do not
dismiss. The user should be able to correct the input and retry.

### `service-spawn-wiring`

Replace all existing "Spawn session" stubs with `SpawnSheet` presentations.
Entry points and their pre-filled context:

| Location | Entry | Pre-fill |
|----------|-------|---------|
| Sessions tab `+` button | `SpawnEntry.sessionsTab` | None |
| `FeatureDetail` Sessions sub-tab "Spawn session" | `SpawnEntry.feature(feature, project)` | Project + feature |
| `ProjectDetail` sessions section "Spawn session" | `SpawnEntry.project(project)` | Project |
| `TicketDetail` sessions section "Spawn session" | Opens `SpawnSheet` pre-filled to ticket scope | Project + feature + ticket |

Remove the placeholder `EmptyState` in `SessionsListView.sheet(isPresented: $showSpawnSheet)`.

The `FeatureDetail` Sessions sub-tab currently has a stub button — replace it
with a real `SpawnSheet` presentation at feature scope. The button in
`TicketDetailView` (see above) uses the ticket entry.

## Navigation additions

`AppRoute` needs two new cases if not already present:

```swift
case ticketDetail(publicID: String)
// Already present per the v2 plan; wire it from FeatureTicketsTab.

// No new route needed for spawn — SpawnSheet is always a sheet, never a push.
```

`listTicketAgentSessions` is already in the repository protocol; use it to
populate the sessions section in `TicketDetailView`.

## Mock fixture additions (`service-spawn-mock`)

Two new sessions in `seedAgentSessions`:

```swift
// session-09 — feature-scoped, FEAT-019, active
AgentSession(id: 804, ticketId: nil,
             tmuxSession: "tmux_agent__feature_context_bundle__session_1714054800",
             state: .active, pane: "agent:3.0", cpu: 8, ...)

// session-10 — project-scoped, tmux-agent, idle
AgentSession(id: 805, ticketId: nil,
             tmuxSession: "tmux_agent__session_1714050000",
             state: .idle, pane: "agent:4.0", cpu: 1, ...)
```

`listProjectAgentSessions` already queries by project; update it to also
return sessions where `ticketId == nil` if they match the project's features
or the project directly. This requires adding `featureId` and `projectId`
fields to `AgentSession` (backend ticket scope for `infra-spawn-scope`).

> **Note:** If the backend adds `feature_id` and `project_id` to the
> `AgentSession` response schema, the iOS mock needs to match. Coordinate with
> the backend ticket.

## Acceptance criteria checklist

- [ ] `CreateAgentSessionRequest` in the OpenAPI contract accepts optional `feature_id` / `project_id`; generated Swift types updated.
- [ ] `MockTmuxAgentRepository.createAgentSession` handles all three scopes and returns a valid `AgentSession`.
- [ ] `TicketDetailView` renders status, title, description, branch, estimate, criteria (toggleable), and linked agent sessions.
- [ ] Inline ticket creation works within `SpawnSheet` (title + estimate → creates ticket → pre-selects it).
- [ ] `SpawnSheet` launched from Sessions tab shows scope picker and all three pickers unpopulated.
- [ ] `SpawnSheet` launched from `FeatureDetail` skips project and feature pickers (pre-filled as labels).
- [ ] `SpawnSheet` launched from `ProjectDetail` skips project picker, shows feature picker.
- [ ] Spawn at all three scopes succeeds against the mock; navigates to the new terminal session.
- [ ] Sessions tab, `FeatureDetail` Sessions sub-tab, and `ProjectDetail` sessions section all show feature- and project-scoped sessions alongside ticket-scoped ones.
- [ ] No "Spawn session" stubs remain in the codebase.

## Notes

- `TicketDetailView` reuses `AcceptanceCriterionRow` if it exists from
  `service-feature-tickets-tab`; extract it to `Core/Components/` if it is
  currently private to that view.
- The session name preview in the spawn sheet footer is informational — do
  not make it editable (the tmux override field exists in the contract but
  exposing it in the UI adds complexity for a power-user feature; defer).
- The "New ticket" inline form in the spawn sheet intentionally captures only
  title and estimate. Full ticket creation (description, branch, criteria)
  belongs in `FeatureTicketsTab`'s create sheet. Keep the spawn path fast.
- Feature- and project-scoped sessions should appear in the Sessions tab's
  active/idle/awaiting groupings alongside ticket-bound ones. The state badge
  logic is the same regardless of scope.
