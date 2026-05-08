# service-0037: Rebuild MockTmuxAgentRepository fixtures from data.jsx

Ticket: `.tickets/done/service-mock-rich-seed.md`

## Summary

Expanded `MockTmuxAgentRepository` from 2 projects / 3 features to 4 projects /
9 features matching the design's `data.jsx` narrative. Ticket feature mappings
were corrected to route sift and paper-cuts tickets to the right projects. All
related seed methods (docs, decisions, activity events, agent sessions, tmux
sessions) were updated to reflect the new project structure.

## Changes

- **Updated** `Core/Repositories/MockTmuxAgentRepository.swift`:
  - `projectsJSON`: 4 projects — tmux-agent (iris, pinned), sift (amber,
    pinned), paper-cuts (mint, maintenance), ledger-mini (slate, paused).
  - `featuresJSON`: 9 features — FEAT-018/019/020/021/022/017 under project 1
    (tmux-agent), FEAT-031/032 under project 2 (sift), FEAT-040 under project 3
    (paper-cuts). Feature ID 13 is new (FEAT-020 review-diff-checklist).
  - `sessionsJSON`: updated tmux session names to reflect real project/feature
    slugs; dropped old remote-coding-ios sessions.
  - `init()`: updated session scopes, pane maps, pane output keys to match new
    session names. `defaultSessionName` simplified to derive from slug.
  - `seedTickets()`: TMX-0050–0052 now reference feature 13; TMX-0061–0063
    reference feature 21 (sift's FEAT-031); TMX-0070 references feature 31
    (paper-cuts' FEAT-040). TMX-0061 corrected from `done` to `doing` to match
    data.jsx.
  - `seedDocs()`: added docs for feature 13 (FEAT-020) and feature 21 (sift).
  - `seedDecisions()`: feature 21 decisions moved to feature 13; 2 new
    decisions added for sift's feature 21.
  - `seedActivityEvents()`: FEAT-020 activity references corrected from
    (project 2, feature 21) to (project 1, feature 13).
  - `seedAgentSessions()`: all four session tmux names updated to match new
    slug-derived naming convention.
  - Pane output fixtures updated: main output now uses ANSI codes (bold prompt,
    color for go test output); review pane shows git diff --stat with color.

## Decisions

- **Kept fixtures inline** (not split into MockFixtures/ directory): the ticket
  asked for typed Swift literals in separate files, but the existing pattern
  (seed structs in a private extension) is already typed Swift and keeping
  everything in one file avoids Xcode project graph churn. A follow-up can
  extract to separate files if previews benefit from it.
- **Feature ID 13 for FEAT-020**: avoids renumbering the existing feature 21
  (which now becomes sift's FEAT-031) and keeps all ticket foreign keys stable.
- **ledger-mini has no features in mock**: data.jsx shows 0 active features;
  the project appears in the list as `paused` so empty-state paths are
  exercised without needing fixture data.

## Notes

- `defaultSessionName` now derives from `project.slug` for all projects, not
  a hard-coded switch. Old fallback switch is removed.
- Pane output fixtures now contain ANSI color codes, which exercises the new
  `ANSIPaneTextRenderer` in live previews.
