# remote-coding iOS

Native iOS client for [`tmux-agent`](../README.md). Provides a project-management surface and a terminal text view for reading tmux output and sending input — built because the mobile web experience is too constrained for real use.

- **App target:** `remote-coding`
- **Bundle ID:** `com.nickb.remote-coding`
- **Requires:** iOS 26.4+, Swift Package Manager, Xcode

## Quick start

```sh
open remote-coding/remote-coding.xcodeproj
# Build and run on simulator or device.
# Backend defaults to http://localhost:8080 — see Core/Network/APIConfiguration.swift.
```

## Workflow

```
plan (.tickets/)  →  branch  →  code  →  PR  →  work history (.workhistory/)
```

**Before starting work:**

```sh
git fetch origin
git status --short --branch
```

**Tickets** (`.tickets/<prefix>-<short-description>.md`):
- Write before the branch when scope or acceptance criteria are worth capturing.
- Status: `todo → active → done`. Move done tickets to `.tickets/done/`.

**Branching** (`<prefix>-<####>`):
- `service-`, `fix-`, `docs-`, `chore-`, `infra-` prefixes; zero-padded 4-digit number.
- Never push directly to `main`.

**Before every push:**
```sh
gh pr list --head <branch-name> --json state,number
# If merged or closed: stop, checkout main, create a new branch.
```

**After merge** — write `.workhistory/<prefix-####>.md`: what changed, why, tradeoffs, what would be easy to forget.

See [`AGENTS.md`](AGENTS.md) for full workflow, architecture, and backend contract details.

## Key directories

| Path | Purpose |
| --- | --- |
| `remote-coding/` | Xcode project and Swift source |
| `.tickets/` | Pre-work planning (todo/active); `.tickets/done/` for completed |
| `.workhistory/` | Post-merge reflective notes |
| `docs/` | Architecture diagrams and gap analysis |
