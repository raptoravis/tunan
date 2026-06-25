# Absorbed GSD capabilities — the audit baseline

`tunan` is **not** a fork of `open-gsd/gsd-core`. GSD is a separately-built
project (TypeScript multi-runtime installer; capabilities under `gsd-core/`,
`capabilities/`, `agents/`, `commands/`) that tunan selectively borrows
*capabilities* from — porting the idea into tunan's own skill shapes, never
copying files. So sync-gsd is a **capability audit**, not a file port: it
surfaces what GSD gained since the last look and lets the maintainer decide what
to absorb. There is no path mapping and no branding transform.

This file records capabilities already absorbed, so the audit does not
re-surface them as "new". Update it (in the same commit) whenever a GSD
capability is absorbed.

## Already absorbed

From the initial GSD-core absorption (tunan commit `32d2b5a`, 2026-06-11):

1. **Execution Waves** — `plan` aggregates the U-ID dependency graph into parallel
   waves; `work` dispatches wave-by-wave. (tunan: `plan/`, `work/` SKILL.md)
2. **Progress anchor** — `work` maintains a `<!-- tunan:progress -->` issue
   comment; `resume`'s `phase.{sh,ps1}` read it and report `units_done/units_total`.
   (tunan: `work/`, `work-beta/` `references/progress-marker.md`, `resume/scripts/`)
3. **Convergence loop** — `plan` gains max-cycles + stall detection + a
   severity convergence gate + align escalation on non-convergence.
   (tunan: `plan/references/convergence-loop.md`)
4. **Capture skill** — `note`/`backlog`/`seed`/`list` four-state zero-friction
   capture, fully in issue state. (tunan: `capture/`)
5. **Sessions profile** — `sessions` gains a `profile` sub-action mining session
   history into memory, consent-gated with a headless fallback. (tunan: `sessions/`)

From the `map-codebase` absorption (2026-06-11):

6. **Codebase Map** — parallel mapper agents produce a seven-section current-state
   snapshot (stack, integrations, architecture, structure, conventions, testing,
   concerns) of an existing repo. Re-expressed issue-only: one living
   `tunan:codebase-map` issue updated in place (not GSD's `.planning/codebase/*.md`
   files), discovery parallel but the issue write serial, CodeGraph as the
   structural index and the `query` backend. (GSD: `commands/gsd/map-codebase.md`;
   tunan: `map-codebase/`)
7. **New Project / New Milestone** — greenfield bootstrap (`new-project`) and
   brownfield next-cycle (`new-milestone`) orchestrators. Re-expressed issue-only:
   project intent + milestone roadmap live in one living `tunan:project` issue
   (not GSD's `.planning/PROJECT.md` + `ROADMAP.md` + `STATE.md` local files);
   requirements reuse `brainstorm` → `tunan:req`, config reuses `tunan:config`,
   code current-state reuses `map-codebase`. The `tunan:project` issue **replaces
   the former `STRATEGY.md` local file** (the `strategy` skill still exists — it
   now sharpens the same issue's intent sections) — all former STRATEGY.md
   consumers (ideate/brainstorm/plan/product-pulse/retro/dogfood-beta) now read the
   issue. (GSD: `commands/gsd/new-project.md`, `new-milestone.md`; tunan:
   `new-project/`, `new-milestone/`)

## How to read the GSD source

GSD's capability surface, by directory:

- `.changeset/*.md` — **the best entry point.** Each changeset is a short,
  human-readable description of one shipped change. The titles alone read as a
  capability changelog; skim these first to spot candidates.
- `gsd-core/workflows/` — the discuss/execute/help phase logic (GSD's analog of
  tunan's plan/work/lfg flow).
- `gsd-core/contexts/`, `gsd-core/references/`, `gsd-core/templates/` — shared
  prompt material and few-shot examples.
- `capabilities/` (audit, graphify, intel, ui) — discrete add-on capabilities.
- `agents/`, `commands/gsd/` — agent definitions and slash commands.

GSD is TypeScript-and-installer heavy. Most of its tree (`src/`, `tests/`,
`bin/`, `scripts/`, `hooks/`, the multi-runtime emission machinery) is build and
release plumbing with no tunan analog — ignore it. A GSD capability is worth
absorbing only when it maps to a behavior tunan's issue-state, skill-based model
can express.
