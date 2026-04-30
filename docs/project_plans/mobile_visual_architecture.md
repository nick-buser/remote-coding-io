# Mobile Visual Architecture

Date: 2026-04-30

## Purpose

The iOS app should not reproduce the web app in a smaller viewport. The mobile experience needs the same core affordances, but arranged around native navigation, fast context switching, deliberate text entry, and review surfaces that make sense in one hand.

This document defines the aims, challenges, invariants, and exploration space for the app's styling, UI/UX, terminal rendering, document rendering, and coding-agent conversation surfaces.

## Product Aims

- Make it safe to steer coding work remotely from a phone.
- Keep project, feature, session, and pane context visible enough to avoid accidental input.
- Favor quick review, triage, and nudging over dense desktop-style project management.
- Make terminal interaction viable without pretending a phone is a full desktop terminal.
- Make project/feature documents feel editable and reviewable, because those docs are likely to become Markdown-backed source material.
- Preserve backend contract alignment while letting the mobile UX be more focused than the web UI.

## Core Challenges

### Context Density

The app needs to expose projects, features, docs, tickets, criteria, sessions, panes, and live output. A phone cannot keep all of that visible at once. The design should prioritize progressive disclosure and contextual headers over dashboard density.

### Input Safety

Terminal input is high consequence. Sending a newline, `C-c`, or a pasted command to the wrong pane is easy if the UI hides context. The app needs friction where mistakes are costly and speed where actions are routine.

### Long Text

Coding agent sessions generate long transcripts, Markdown notes, code blocks, diffs, lists, command output, and partial plans. The visual system must support scanning and editing long text without resorting to raw plain text everywhere.

### Backend Lag

The UI already wants docs, prompt buildouts, acceptance criteria, tickets, decisions, and transcript browsing. The backend contract does not expose most of those yet. Mobile should model those surfaces cleanly but keep persistence behind repository boundaries.

### Mobile Terminal Reality

A phone terminal should support key commands, prompt replies, and monitoring. It should not require precise desktop terminal gestures to be useful. The design should optimize for common coding-agent interactions, not a full replacement terminal emulator first.

## Invariants

- The terminal surface is always tied to an explicit project, feature when known, session, and pane.
- Empty Enter must remain a first-class action for prompts and option selection.
- Control keys must be explicit controls, not hidden keyboard tricks.
- Session and pane lists must never leak across project boundaries.
- Feature-level sessions should be preferred when available; project-level sessions are acceptable fallback context.
- Every editable text surface should be built behind a reusable editor/renderer boundary.
- OpenAPI remains the network contract source of truth.
- Mobile design should be native and task-focused, not a scaled-down web layout.
- Long text should have affordances for scan, edit, copy, and share.
- Review surfaces should show status and risk before decoration.

## Navigation Model

Use a small root tab structure:

- **Projects:** folder-style hierarchy and management.
- **Terminal:** current contextual session/pane.
- **Review:** optional future tab for queued reviews, criteria, sessions needing attention, and recently changed docs.
- **Settings:** server configuration, defaults, appearance, and developer diagnostics.

Early app versions can use only Projects and Terminal, but the visual architecture should leave room for Review without turning Projects into a crowded dashboard.

Within Projects:

```text
Projects
-> Project detail
   -> Features
      -> Feature detail
         -> Docs / Criteria / Sessions / Review
   -> Project docs
   -> Project sessions
```

The back stack should feel like browsing folders. The terminal tab is different: it is a persistent work surface with a context picker/header, not just another detail screen.

## Visual System Direction

### Overall Tone

The app should feel quiet, technical, and precise. It should avoid marketing-style cards, oversized hero sections, or decorative gradients. The important objects are files, sessions, feature plans, diffs, terminal output, and review state.

Good visual references:

- Native Files app hierarchy for project browsing.
- Linear-style issue density for feature/ticket rows.
- Xcode/terminal-inspired monospace surfaces for code and logs.
- iOS Mail/Notes-style reading and editing rhythm for Markdown docs.

Avoid:

- Dark dashboard clutter with too many tiny panels.
- Decorative status cards inside cards.
- Color palettes dominated by one hue.
- Making every row look equally urgent.
- Hiding session/pane context behind tiny captions.

### Color

Use a restrained neutral base with semantic accents:

- Background: system grouped backgrounds.
- Primary text: system label.
- Secondary text: system secondary label.
- Project accent: small icon swatch, not full-screen tint.
- Status colors: active, paused, maintenance, merged, abandoned, error, warning.
- Terminal: darker surface is acceptable, but only the terminal needs to feel terminal-dark.

Color should identify state and scope. It should not be the main layout mechanism.

### Typography

- Use San Francisco for navigation, lists, metadata, and controls.
- Use monospaced text for terminal, code blocks, commands, paths, branch names, and IDs.
- Avoid viewport-scaled type.
- Keep list rows compact but tappable.
- Use title-scale text only for project/feature headings, not for every section.

### Layout

- Favor full-width list sections and native grouped lists.
- Use cards only for repeated items or modals, not as nested page containers.
- Keep toolbars stable in height.
- Keep terminal controls reachable above the keyboard.
- Use segmented controls for feature detail sections where tabs are useful.
- Use bottom sheets for focused actions: create project, create feature, command palette, session picker.

## Key Screens

### Project List

Primary job: choose a workspace quickly.

Ideas:

- Pinned projects at top.
- Recent projects sorted by last touched.
- Small status glyph for active/paused/maintenance.
- Project icon/accent swatch.
- Secondary line for local path or tagline.
- Search/filter later.
- Swipe actions for pin/edit/archive once persistence exists.

Do not show sessions, features, and docs all in the project list. That belongs in project detail.

### Project Detail

Primary job: understand the project and choose the next feature/session/doc.

Suggested sections:

- Summary header: name, status, path, linked session status.
- Quick actions: open session, create feature, edit project.
- Segmented sections: Features, Docs, Sessions, Activity.
- Feature rows: title, branch, status, changed time, session indicator.
- Docs rows: project brief, notes, decisions when available.
- Sessions rows: project-level sessions only.

The session section should make scope obvious: "Project sessions" rather than just "tmux".

### Feature Detail

Primary job: review and steer one unit of work.

Suggested sections:

- Header: feature title, branch, status, project chip.
- Tabs/segments: Overview, Docs, Criteria, Sessions, Review.
- Overview: brief description, current state, next action.
- Docs: feature description, prompt buildout, decisions.
- Criteria: checklist when structured data exists; Markdown checklist until then.
- Sessions: feature sessions first, project fallback clearly labeled.
- Review: changed files, open criteria, recent transcript highlights once backend supports it.

Feature detail should be the main review surface. It should not be buried under terminal output.

### Terminal

Primary job: observe output and send deliberate input.

Required visual structure:

- Persistent context header:
  - project
  - feature if known
  - session
  - pane
  - live/reconnecting/stale status
- Output surface.
- Input draft surface.
- Key toolbar.
- Send actions.

Terminal header should be compact but unmistakable. If a user switches panes, the header should visibly change.

Ideas:

- Use a context picker sheet from the header.
- Show "feature session" vs "project session" label.
- Add stale snapshot banner when WebSocket is disconnected.
- Add "last updated" timestamp.
- Provide a clear "Enter only" action separate from send.
- Provide command snippets/history in a sheet rather than crowding the main toolbar.

## Review Surfaces

Mobile is especially useful for lightweight review. Explore a dedicated Review tab or project/feature review sections that aggregate:

- Features with failing or incomplete acceptance criteria.
- Sessions that are still running.
- Recent agent output that asks for confirmation.
- Docs or prompt buildouts changed since last view.
- Features ready for review.
- Decisions requiring acknowledgement.
- PR/build status if backend later exposes it.

Review rows should be action-oriented:

- "Open terminal"
- "Review criteria"
- "Read latest output"
- "Continue prompt"
- "Mark decision"

The review surface should not require opening a terminal unless action is needed.

## Runestone And Text Surface Plan

Runestone should be the common foundation for serious text surfaces:

- Terminal output surface.
- Command draft input when TextField is too limited.
- Feature descriptions.
- Prompt buildouts.
- Acceptance criteria.
- Decisions.
- Markdown documents.

The app should keep `RunestoneTextSurface` as an adapter boundary. Views should not depend directly on Runestone details.

### Terminal Output

Terminal output has different needs from document editing:

- Efficient updates from snapshots and WebSocket messages.
- Monospaced layout.
- ANSI color/style parsing when present.
- Stable scroll behavior.
- Copy selected output.
- Search later.
- Block segmentation later.

Explore a renderer pipeline:

```text
PaneStreamMessage
-> TerminalBufferSnapshot
-> ANSI parser / style spans
-> Runestone document model
-> visible output surface
```

Start with full-buffer replacement because the backend currently streams captured pane content. Later, support diff/appended updates if the backend emits incremental events.

### Coding Agent Conversation Rendering

Coding-agent output is not just terminal text. It usually contains:

- User prompts.
- Assistant plans.
- Tool calls.
- Command output.
- Diffs.
- Test results.
- Review findings.
- Markdown lists.
- Code blocks.
- "Continue? y/N" prompts.

Explore rendering this as structured blocks over time:

- Prompt block.
- Agent response block.
- Command block.
- Output block.
- Diff block.
- Error block.
- Decision block.
- Criteria block.

The raw tmux stream remains the source initially, but the UI can progressively identify blocks with heuristics. If backend transcript storage later has structure, mobile should consume that instead of guessing.

### Command Options

The terminal input surface should support:

- Send.
- Send + Enter.
- Empty Enter.
- Escape.
- Tab.
- Backspace.
- Arrows.
- `C-c`, `C-d`, `C-z`, `C-l`, `C-a`, `C-e`.
- PageUp/PageDown/Home/End when useful.
- Paste command.
- Command history per pane.
- Snippets per project or feature.

Do not overload the native return key. Keep explicit buttons for high-value actions because prompts and coding agents often need empty responses.

Possible command UI:

- Horizontal quick-key toolbar for the common keys.
- "More keys" sheet for less common keys.
- Command history sheet.
- Snippet sheet.
- Long-press Send to choose send mode.

### Formatting And AST Support

Runestone can be the text editing base, but richer rendering likely needs a separate parsing layer:

- Markdown parser for docs and prompt buildouts.
- Syntax highlighting for fenced code blocks.
- Task-list parsing for acceptance criteria.
- Diff parser for patch review.
- ANSI parser for terminal output.
- Lightweight transcript block parser for agent conversations.

Preferred architecture:

```text
Stored Markdown / terminal output / transcript
-> parser
-> typed render blocks
-> Runestone-backed editor or native read-only block list
```

Do not put parsing rules directly in SwiftUI views. Keep them testable and reusable.

## Markdown Document Rendering

Docs will likely be stored as Markdown first. Mobile should support a better-than-plain-text Markdown experience without blocking early editing.

Phased approach:

1. **Plain Markdown editing**
   - Runestone-backed editor.
   - Monospace or mixed typography exploration.
   - Save/cancel.

2. **Preview mode**
   - Render headings, paragraphs, lists, links, code blocks, quotes, and checkboxes.
   - Toggle Edit/Preview.

3. **Split affordance without split view**
   - Mobile cannot sustain desktop split panes.
   - Use a segmented control or swipe between Edit and Preview.

4. **Structured affordances**
   - Tap checklist item to toggle when backend schema supports it.
   - Copy code block.
   - Jump between headings.
   - Insert prompt template.

5. **AST-backed editing**
   - Keep Markdown source as storage.
   - Use parser AST for navigation, outline, and block controls.
   - Avoid lossy rich-text transformations until there is a strong reason.

## Acceptance Criteria UX

Until criteria become structured backend objects, use Markdown checklists. Once structured criteria exist:

- Show criteria as native checklist rows.
- Preserve Markdown export/import.
- Keep criteria close to feature sessions and review state.
- Make unmet criteria visually obvious without dominating the feature screen.
- Support notes per criterion later.

## Prompt Buildout UX

Prompt buildouts are likely long Markdown documents with context, constraints, and task framing.

Explore:

- Outline from headings.
- Insertable snippets.
- "Send to session" action that copies or injects text into the terminal draft.
- Highlight linked project/feature/session context.
- Warning if sending to a pane outside the prompt's feature scope.

## Visual Architecture Ideas To Explore

- **Context ribbon:** a compact top ribbon showing project/feature/session/pane across terminal and review screens.
- **Session scope labels:** chips for "project session" and "feature session".
- **Review inbox:** native list of actionable review items.
- **Terminal command drawer:** bottom sheet for history, snippets, and special keys.
- **Document outline drawer:** headings extracted from Markdown AST.
- **Transcript highlights:** collapsed blocks for commands, failures, prompts, and decisions.
- **Criteria strip:** compact progress indicator on feature rows.
- **Stale/live badge:** consistent status treatment for stream health.
- **Copy-friendly output blocks:** long-press actions on command output and code blocks.
- **Safe send confirmation:** optional confirmation for destructive-looking commands or wrong-scope terminal sends.

## Risks

- Building too much mock document UI before backend contracts exist may create throwaway surfaces.
- Treating terminal output as Markdown too early may corrupt command output fidelity.
- A full terminal emulator may be overkill before the coding-agent interaction loop is understood.
- Too many controls near the keyboard can make the app feel cramped.
- Excessive status decoration can make review surfaces harder to scan.

## Near-Term Design Targets

The next UI pass should aim for:

- Clear project and feature hierarchy using native lists.
- Project and feature session sections with visible scope.
- A more deliberate terminal header.
- Expanded terminal key toolbar parity with web.
- Runestone wired for document editing before investing in rich preview.
- A lightweight Markdown preview experiment for feature docs and prompt buildouts.
- A review-oriented feature detail layout that surfaces criteria and sessions without requiring desktop density.

