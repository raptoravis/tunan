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

From the 2026-06-25 audit (GSD `a0e45cd`, full survey):

8. **Docs-update** — generate/refresh project docs (README, architecture, contributing,
   API/usage) with reader/writer subagents that explore the code directly, a verifier
   pass that fact-checks every path/signature/command/endpoint against the live
   codebase, and a bounded fix loop. Re-expressed without GSD's `.planning/` work
   manifest or fixed 9-doc list: adapts to the repo's existing doc layout, keeps the
   work list in the chat task list, and writes markdown doc files (the one tunan write-
   to-disk skill, since docs are code-tree files not issue-state). CodeGraph is the
   structural/verification index. (GSD: `commands/gsd/docs-update.md`, `gsd-doc-writer`
   / `gsd-doc-verifier` agents; tunan: `docs-update/`)
9. **Forensics** — read-only post-mortem of a stuck/failed pipeline run; gathers git +
   issue-marker evidence, matches an anomaly taxonomy (stuck loop, missing markers,
   abandoned work, crash/interruption, CI thrash), emits a diagnostic report + single
   root cause + one corrective action. Re-expressed over git history + tunan issue
   markers (the `tunan:progress` comment, plan marker, labels, open PR/CI) instead of
   GSD's `.planning/` artifacts; optional report capture as a `tunan:forensics` issue.
   (GSD: `commands/gsd/forensics.md`; tunan: `forensics/`)
10. **Doc conflict-engine + ingest** — bootstrap the planning model from existing
    ADRs/PRDs/SPECs with severity-bucketed conflict detection (BLOCKER/WARNING/INFO),
    a plain-text report, a BLOCKER safety gate, and `ADR > SPEC > PRD > DOC` precedence.
    Re-expressed as an **ingest mode folded into `new-project`** (`--ingest`, Phase 1b):
    synthesizes intent + requirements from the docs, checks conflicts against the
    locked decisions in an existing `tunan:project` issue, then feeds the normal
    roadmap/requirements flow — no `.planning/INGEST-CONFLICTS.md` file. (GSD:
    `commands/gsd/ingest-docs.md`, `import.md`, `references/doc-conflict-engine.md`;
    tunan: `new-project/` + `new-project/references/doc-conflict-engine.md`)
11. **Inbox triage** — review open issues/PRs against contribution templates, report
    completeness, optionally label/close non-compliant items. Re-expressed as an
    **opt-in `--triage` mode folded into `status`** — read-only reporting by default
    (preserving status's read-only contract); `--label` / `--close-incomplete` act only
    behind explicit per-step blocking confirmation. (GSD: `commands/gsd/inbox.md`;
    tunan: `status/`)

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
