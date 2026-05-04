# Screens

Date: 2026-05-04

Per-screen implementation plan derived from the v2 design. Each section describes the screen as it appears in `ios-screens-zen.jsx` (primary) or `ios-screens.jsx` (richer fallback when zen is missing detail), maps each piece to a SwiftUI structure, and identifies the data source from `../api/openapi.yaml`.

Layout values (padding, font sizes, radius) come from `10-design-system.md`. Don't redefine them here — reference `Theme.*` constants.

---

## 1. Inbox

**Source**: `InboxZen` (zen) plus the richer `InboxScreen` (dense) for context.

The zen Inbox is a single hero card showing the most-pressing item, with "1 of 3 needs you" eyebrow text and a "Swipe for next →" hint plus page dots at the bottom. The dense Inbox shows two grouped sections: `Needs you` and `Earlier today`, each as a rounded card of activity rows.

**Decision**: Build the dense version as the **default** mobile experience. The zen single-card view is a wonderful focused mode but it loses the user's mental model of "what's left." Provide the zen view as a presented detail when the user taps any inbox row — the full-screen "answer one thing at a time" mode — but the tab itself shows a scannable list.

### Structure

```
NavigationStack {
    ScrollView {
        Header
            Title "Inbox"
            Subtitle "3 need you · 4 sessions live"
            Trailing icons: filter, compose

        ScrollChips ["All", "Questions", "Reviews", "Decisions", "Mentions"]

        Section "Needs you"
            RoundedCard
                ForEach(needsAttention) { InboxRow($0) }

        Section "Earlier today"
            RoundedCard
                ForEach(recent) { InboxRow($0) }
    }
}
```

### `InboxRow`

- 32pt accent square with kind glyph (see `KindIcon` in `10-design-system.md`).
- Mono target ID (`TMX-0050`) tinted with the related project / feature accent.
- `· session-07` actor in fg2.
- `2h` mono timestamp pinned right.
- Body in 14pt fg, line-height 1.35.
- For `kind == question`: inline `Reply` (primary, accent) + `Open pane` (secondary).
- For `kind == review`: inline `Approve` (primary, accent) + `Open diff` (secondary, opens Review screen).
- Other kinds: no inline buttons; tapping the row pushes a detail (review screen for review kinds, terminal for commit/test/check kinds, decision detail for decision kinds, doc viewer for doc kinds).

### Data

- Source: `repository.listActivity(project: nil, feature: nil, since: nil, limit: 100)`.
- Polling: 5 second cadence via `ActivityPoller`.
- Filtering: `Needs you` = `kind ∈ {question, review}` plus `kind == decision` items in the last hour. `Earlier today` = everything else from today.
- Filter chips: `All` (no predicate), `Questions` (`kind == question`), `Reviews` (`kind == review`), `Decisions` (`kind == decision`), `Mentions` (no contract surface yet — disable until backend exposes mention metadata).

### Empty state

When the activity feed has no `Needs you` items, show `InboxEmptyZen`: 72pt circle outline with envelope glyph, "All clear" title, "Agents are working. They'll find you here when they need something." body. Keep `Earlier today` rendered below — empty inbox doesn't mean an empty day.

---

## 2. Projects

**Source**: `ProjectsZen` plus `ProjectsScreen` (dense) reference.

Zen shows a flat list of projects: 8pt liveness dot + 22pt project name (muted if paused) + mono "N live" trailing. Dense shows pinned + all sections in rounded cards with project accent square, name, pinned star, tagline, and meta pills.

**Decision**: Use the **dense** layout. The zen list is too sparse for finding a project quickly when there are >3 of them. Mock data has 4 projects but real users will have more.

### Structure

```
NavigationStack {
    ScrollView {
        Header
            Title "Projects"
            Subtitle "4 projects · 4 live sessions"
            Trailing icons: search, plus

        Section "Pinned"
            RoundedCard
                ForEach(pinnedProjects) { ProjectRow($0) }

        Section "All projects"
            RoundedCard
                ForEach(otherProjects) { ProjectRow($0) }
    }
    .refreshable { await viewModel.refresh() }
}
```

### `ProjectRow`

- 38pt accent rounded square (icon glyph in white, font 18, weight 600).
- Title (16pt, weight 600) + 10pt yellow pinned star if pinned.
- Tagline (13pt, fg2, single-line).
- Meta pills row: status dot (Active = green, Maintenance = orange, Paused = gray), `X live` if `liveSessions > 0`, `Y/Z features`.
- Trailing chevron.

Tap pushes `AppRoute.projectDetail(idOrSlug:)`. Long-press shows context menu (Pin/Unpin, Edit, Delete).

### Plus button

Opens `CreateProjectSheet` — see `service-projects-create.md`. Slug is auto-derived from name (kebab-case) but editable.

### Data

- `repository.listProjects()` ordered server-side, but re-sort client-side: pinned first, then `last_touched_at` desc.
- `liveSessions` for each project: count from `repository.listProjectAgentSessions(idOrSlug:)` filtered to `state ∈ {active, awaiting-input}`. Cache for the session — refresh when an agent-sessions event lands in the activity poller.
- `activeFeatures` / `totalFeatures`: derive from a `repository.listFeatures(projectIDOrSlug:status:)` call where status is unset (returns all) — count `status == in_progress` for the active number.

The "live + features" counts can be expensive over the wire if every list refresh re-fetches them. Initial implementation: lazy-load when the row appears, debounce, cache.

---

## 3. Project detail

**Source**: `ProjectDetailZen` and `ProjectDetailScreen` (dense).

Zen shows the project name in a 34pt hero, tagline, "Active features" eyebrow, and a list of active features (8pt accent dot + 17pt title + "N live" trailing). Below: a centered row of small accent links: `All tickets`, `Docs`, `Roadmap`, `Shipped`. Dense adds a 4-up stats strip and a 4-tab segmented control (Features / Tickets / Docs / Sessions) plus status-grouped feature cards.

**Decision**: Hybrid. Use the zen hero (just name + tagline, big and quiet). Below the hero, keep a 4-up stats strip (Active / Open / Live / Total) — it answers "what's the state of this project?" cheaply. Then a 4-tab segmented control for the body (default tab: Features). The status-grouped feature lists live inside the Features tab.

### Structure

```
NavigationStack {
    ScrollView {
        Header
            BackChevron("Projects")
            CenterLabel: project.name
            Trailing: dots menu (Edit / Pin / Open in tmux / Delete)

        Hero
            34pt project.name (display, weight 600)
            15pt project.tagline (fg2)

        StatsStrip [
            ("Active", project.activeFeatures),
            ("Open", project.openTickets),
            ("Live", project.liveSessions),
            ("Total", project.totalFeatures)
        ]

        SegmentedControl ["Features", "Tickets", "Docs", "Sessions"]

        Switch (active tab):
          .features → FeatureGroupedList
          .tickets  → TicketList (across all features)
          .docs     → DocList
          .sessions → AgentSessionList
    }
}
```

### `FeatureGroupedList`

Sections in order: `In progress`, `In review`, `Planned`, `Shipped`. Hide a section if it's empty. Each section header uses 13pt uppercase fg2.

`FeatureRow` (per the dense design):
- 16pt status glyph.
- Mono FEAT-018 + 6pt accent pip + mono milestone label (`v0.4 — Multi-agent`).
- 15pt title (single line ellipsis).
- Progress bar (60×4, accent fill) + `5/8` mono + green `● 3 live` if any sessions + mono target date pinned right.
- Chevron.

Tap pushes `AppRoute.featureDetail(featureID:)`.

---

## 4. Feature detail

**Source**: `FeatureDetailZen` plus `FeatureDetailScreen` (dense).

Zen: status dot + status / milestone, 28pt feature title, 16pt vision, single-line progress (mono "5 of 8 tickets" + target, accent fill bar), then **three deep links** as full-width rows: `Tickets`, `PRD`, `Live sessions / Spawn session`. Dense: hero + progress card + 4-tab segmented control (Tickets / PRD / Decisions / Sessions) + tickets list + footer actions (`+ New ticket`, `Spawn session`).

**Decision**: Use the **dense** layout. Three deep links are too few — Decisions deserves to be reachable in one tap, and the segmented control matches the Project Detail pattern. Keep the zen hero typography (large, quiet) and the single-line progress.

### Structure

```
NavigationStack {
    ScrollView {
        Header
            BackChevron(project.name)
            CenterLabel: feature.publicID (e.g., "FEAT-018")
            Trailing: share, dots menu

        Hero
            HStack { Pip(accent), mono "FEAT-018", InProgressPill }
            28pt feature.title
            16pt feature.vision (fg2)

        ProgressLine
            HStack {
                "5 of 8 tickets",  Spacer,  mono "May 12"
            }
            2pt rule with accent fill at progress_cached

        SegmentedControl ["Tickets", "PRD", "Decisions", "Sessions"]

        Switch (active tab):
          .tickets    → TicketList
          .prd        → DocList (kind ∈ {prd, vision, design, notes, log})
          .decisions  → DecisionList
          .sessions   → AgentSessionList(featureID:)

        Footer (tickets tab only)
            HStack { PillButton("+ New ticket", primary), PillButton("Spawn session") }
    }
}
```

### `TicketList` / `TicketRow`

- 14pt status glyph (todo / doing / review / done).
- Mono TMX-0042 + green `● live` if any active agent session + mono updated time.
- 14pt title (single line).
- Criteria dots: 8×4 dashes per criterion, green if done, gray if pending.
- Mono `2/4` count + estimate badge (`S/M/L`) bordered, right-aligned.

Tap pushes `AppRoute.ticketDetail(publicID:)` which opens the Review screen (see below).

### `+ New ticket`

`CreateTicketSheet` posts `CreateTicketRequest` to `repository.createTicket(featureID:body:)`. Status defaults to `todo`. Estimate is optional (S/M/L picker).

### `Spawn session`

`SpawnSessionSheet` opens with a ticket picker (or selected ticket pre-filled if invoked from a ticket row). Submits `CreateAgentSessionRequest` with the chosen `ticket_public_id`. On success, push `AppRoute.agentSession(sessionID:)` to land on the terminal.

---

## 5. PRD / Docs sub-tab

**Source**: `DocsScreen` (dense; v2 zen does not include a docs screen detail).

The dense docs screen shows a feature's PRD with a 4-tab sub-segment (PRD / Eng design / Decisions / Notes) and TipTap-style blocks: heading, paragraph, callout, checklist.

### Initial scope

Read-only renderer that:
- Lists feature docs (via `repository.listFeatureDocs(featureID:)`) in a docs index showing pinned first.
- Tapping a doc pushes `AppRoute.docDetail(docID:)`.
- Doc detail renders `body_blocks` (TipTap JSON) into native blocks: paragraph, heading 1/2/3, bullet list, ordered list, code block, callout, task list.
- Title shown as 26pt display weight 700, with `feature.publicID · doc.kind` as a 11pt mono eyebrow.

### Editing (next ticket)

A second ticket adds editing — replace the renderer with a Runestone-backed editor that emits TipTap JSON on save. Requires `infra-runestone-package`.

### Heuristic for the segmented control on Feature Detail

The dense Docs sub-segment hard-codes PRD / Eng design / Decisions / Notes. With the new contract, `DocKind` is `vision | prd | design | notes | log | custom`. Build the segmented control dynamically: show only kinds that have ≥1 doc in this feature, plus an "All" option.

---

## 6. Decisions sub-tab

**Source**: dense `lin-fd-decisions` and the dense `DecisionsList`.

Append-only list of `Decision` records, newest first. Each row:
- Mono timestamp (`1h`).
- Title (14pt fg).
- Optional body (12.5pt fg2, prose).
- Trailing actor chip (`agent` iris, `human` fg).

Footer button: `+ Log decision` opens a sheet with title + body fields + actor (defaults to human). Submits `CreateDecisionRequest`.

### Long-press / swipe

Right-edge swipe to delete. Confirm with an action sheet — decisions are append-only by design but the contract allows deletion for typo recovery; surface this as "Remove (typo)" with a destructive confirmation.

---

## 7. Sessions sub-tab (Feature)

Lists agent sessions whose `ticket_id` belongs to this feature. Same row visual as the top-level Sessions screen — see below.

---

## 8. Roadmap

**Source**: `RoadmapZen` plus `RoadmapScreen` (dense).

Zen: one milestone in focus (`Now · ends May 26`, large milestone name + ID), the active milestone's features as a list (8pt status dot + 16pt title + mono target), then page dots and "Swipe for next milestone" hint. Dense: vertical timeline with all milestones, each with a colored rail dot, label, range, and inset feature cards.

**Decision**: Implement the **zen** version. The roadmap is the only screen in the design where the zen layout is clearly superior — milestones are sparse enough that one-at-a-time focus actually helps.

### Structure

```
NavigationStack {
    TabView(selection: $milestoneIndex) {
        ForEach(milestones.indices) { index in
            VStack {
                Eyebrow:   mono "Now · ends \(m.end)" (or "Planned · starts \(m.start)" or "Shipped \(m.end)")
                Title:     28pt display "Multi-agent" (after stripping "v0.4 — ")
                ID:        12pt mono "v0.4"

                Spacer 24

                ForEach(features in milestone) { FeatureRowCompact }

                Spacer

                "Swipe for next milestone" hint (centered, 12pt fg2)
            }
            .tag(index)
        }
    }
    .tabViewStyle(.page(indexDisplayMode: .always))
}
```

### Project filter

The `ScrollChips` row from the dense version (`All`, `tmux-agent`, `sift`, `paper-cuts`) filters the features list inside each milestone. Keep this filter at the top of every milestone page, not above the swiper, so the milestone label stays anchored.

### Data

`repository.listFeatures(projectIDOrSlug:status:)` doesn't return milestone filtering directly. Strategy: call `listFeatures(projectIDOrSlug: nil, status: nil)` for each project the user has, then group client-side by `feature.milestone`. Milestones themselves aren't in the contract — derive them from the union of `feature.milestone` strings present in the data, sorted by `target_date`. Initial 4 milestones come from the mock seed; once features have real `target_date` values, the timeline lays itself out.

---

## 9. Sessions list

**Source**: `SessionsZen` plus `SessionsListScreen` (dense).

Zen: `Awaiting you` eyebrow + count + a hero card per awaiting session with `Open pane` accent button + "Show all 4 sessions" link. Dense: status-grouped sections (Awaiting input / Active / Idle) with detailed rows.

**Decision**: Hybrid. Show the zen hero block at the top — it's the right "what should I do" summary. Below, render the dense status-grouped list with all sessions. The "Show all" link from zen is implicit; the list is always visible.

### Structure

```
NavigationStack {
    ScrollView {
        Header
            CenterLabel "Sessions"
            Trailing: plus

        AwaitingHero
            "Awaiting you" eyebrow
            "1 session" big counter
            ForEach(awaiting) {
                RoundedCard {
                    StatusDot, mono session.id, mono uptime
                    17pt ticket.title
                    PillButton("Open pane", primary)
                }
            }

        ScrollChips ["All", "Active", "Awaiting", "Idle"]

        Section "Active"     → ForEach(active) { SessionRow }
        Section "Awaiting"   → ForEach(awaiting) { SessionRow }     // hide if equal to AwaitingHero list
        Section "Idle"       → ForEach(idle) { SessionRow }
    }
}
```

### `SessionRow`

- StatusDot (state-colored, pulse animation if active or awaiting).
- Mono session id (13pt weight 600), mono pane label (`agent:1.0`), mono uptime trailing.
- 14pt ticket.title (single line).
- 6pt accent pip + mono `FEAT-019 · TMX-0048` + mono CPU% (green when >10).
- Chevron.

Tap pushes `AppRoute.agentSession(sessionID:)`.

### Plus button

Opens `SpawnSessionSheet` — same flow as the Feature Detail's Spawn session.

### Data

- `repository.listProjectAgentSessions` for each project (or a global agent-sessions endpoint if/when the contract adds one).
- Polling: same 5s cadence as Inbox; reuse `ActivityPoller` to emit a "sessions changed" notification on activity events with `kind ∈ {commit, test, review, question, approve}`.

---

## 10. Review screen

**Source**: `ReviewScreen` (dense). Zen has no review variant.

Reached by tapping a `kind == review` Inbox row, or from the dots menu on a ticket in `review` status. Shows the diff, the acceptance checklist, and the approve / request-changes / send-back actions.

### Structure

```
NavigationStack {
    ScrollView {
        Header
            BackChevron("Inbox")
            Trailing: dots

        Hero
            HStack { mono "TMX-0050", InReviewPill }
            22pt display title
            mono "session-07 · feat/tmx-0050-diff-viewer · +412 / −37 · 9 files"

        SegmentedControl ["Diff", "Checklist 6/6", "Files"]

        Switch (active sub-tab):
          .diff      → DiffViewer (per-file FileDiff with green/red highlights)
          .checklist → CriteriaList (read-only here)
          .files     → FileTreeWithDiffSummary

        Footer (sticky)
            HStack {
                PillButton("Request changes", secondary, wide),
                PillButton("Approve & merge", primary accent, wide)
            }
    }
}
```

### `DiffViewer`

`TicketDiff.files: [FileDiff]`. For each file:
- Header: mono path (12pt fg2), `+M / −N` summary.
- Body: monospace pre-formatted text with green-tinted `+` lines (oklch 70% 0.15 145) and red-tinted `-` lines (oklch 70% 0.16 15) and gray context lines. Use `AttributedString` with paragraph backgrounds, not view-per-line.

Initial implementation: render the unified diff between `old_content` and `new_content` line-by-line. Defer split view, syntax highlighting, hunk navigation to follow-up tickets.

### Approve / Request changes / Send back

- `Approve & merge` → `repository.approveTicket(publicID:)`. On success, dismiss the screen and refresh Inbox.
- `Request changes` → opens a sheet with a comment textarea + `Submit`. Calls `repository.requestTicketChanges(publicID:comment:)`. The comment lands in the activity feed as the event detail.
- Dots menu includes `Send back to doing` → `repository.sendTicketBack(publicID:comment:)`.

---

## 11. You

**Source**: `YouZen` plus `YouScreen` (dense).

Zen: 64pt accent avatar with initial, name, "4 projects · 4 sessions live", three settings rows (Workspace / Appearance / Agent). Dense: workspace card + three settings sections (Workspace / Appearance / Agent) with multi-row content including an accent color swatch picker.

**Decision**: Use the **dense** version. The zen "three rows" is too sparse for a settings screen — users expect to see and adjust their accent and connection settings from this surface, not drill in.

### Structure

```
NavigationStack {
    ScrollView {
        Header
            CenterLabel "You"
            Trailing: dots

        ProfileCard
            64pt avatar
            22pt name
            12pt mono "4 projects · 4 sessions live"

        Section "Workspace"
            SettingRow(icon: blue, glyph: "◎", title: "Default project", detail: project.name)
            SettingRow(icon: orange, glyph: "!", title: "Notifications", detail: "Reviews & questions")
            SettingRow(icon: green, glyph: "◧", title: "tmux server",
                       detail: connection state derived from /healthz)

        Section "Appearance"
            VStack {
                "Accent color" label
                AccentSwatchPicker(accents: [iris, amber, mint, rose, slate])
            }
            SettingRow("Text size", detail: "Default")
            SettingRow("Appearance", detail: "Light" | "Dark" | "System")

        Section "Agent"
            SettingRow("Default model", detail: "Claude Sonnet")
            SettingRow("Pane budget", detail: "6 per window")
            SettingRow("Context bundle", detail: "PRD + Decisions")
    }
}
```

### Settings

- **Workspace ▸ tmux server** sub-screen: edits `APIConfiguration.baseURL` (currently in the existing `SettingsView`). Reuses the existing form with the new header style.
- **Workspace ▸ Default project**: persists a project ID in `UserDefaults` (`workspace.defaultProjectID`). Used by Inbox subtitle (when set, scopes the activity feed and the "needs you" count).
- **Appearance ▸ Accent color**: persists in `UserDefaults` (`appearance.accent`). All accent-using components read this through the environment.
- **Appearance ▸ Appearance**: Light / Dark / System override (`UserDefaults` `appearance.colorScheme`).
- **Agent ▸ Default model / Pane budget / Context bundle**: defer until the contract surfaces these (none of these have endpoints yet). For initial ship, render them as static rows that open a "Coming soon" detail.

---

## Cross-cutting screens

### Loading / error / empty

Every list view should render three states explicitly:
- **Loading**: `ProgressView` centered, no shimmer placeholders (the design has no shimmer).
- **Error**: `EmptyState` icon + "Couldn't load" title + the `ProblemDetails.detail` body + a Retry button.
- **Empty**: `EmptyState` icon + topic-appropriate copy.

Avoid spreading these states across many subviews — extract a single `LoadingStateView<Loaded>` wrapper in `Core/Components/`.

### Pull-to-refresh

Every list screen supports `.refreshable`. The activity poller continues running; pull-to-refresh just kicks it manually.

### Long-press menus

Project / feature / ticket rows expose a context menu with the most-used actions (`Pin`, `Edit`, `Open in tmux`, `Delete`, `Approve`, …). Long-press feels native and avoids cluttering the row trailing area with dots menus.
