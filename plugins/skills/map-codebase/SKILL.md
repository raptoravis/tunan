---
name: map-codebase
description: "Map an existing codebase into a durable current-state snapshot — stack, integrations, architecture, structure, conventions, testing, and concerns — stored as a single GitHub issue labeled tunan:codebase-map. Use when onboarding to a repo, when the user says 'map the codebase', 'survey this repo', '摸清这个库', '生成代码现状', 'what's the current state of this code', or before brainstorming/planning so work starts from a written baseline. Modes: full (default, parallel mappers), fast (single mapper with --focus), status (staleness check), refresh (re-map in place), diff (show drift since last map). No local files — the map lives in issue state."
argument-hint: "[full | fast --focus <tech|arch|quality|concerns> | status | refresh | diff | query <term>]"
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - Agent
  - AskUserQuestion
---

# Map Codebase

> 运行环境入口约定：本仓库的 `.claude/skills` 以 Claude Code 为源，示例默认写 `/tunan:*`。若同一 skill 在 Codex 中运行，所有面向 sponsor 的可复制入口在输出前改写为 `$tunan:*`；Claude Code 中保持 `/tunan:*`。

`map-codebase` scans an existing repository and produces a **current-state snapshot** — the durable "现状" baseline that later work starts from. The snapshot is seven sections (stack, integrations, architecture, structure, conventions, testing, concerns) plus a provenance header recording the git SHA and date it was mapped at.

The snapshot is stored as **one GitHub issue** labeled `tunan:codebase-map`, never a local file. There is exactly one such issue per repository — it is a **living document updated in place** (like the `tunan:config` issue), not a per-run timeline (unlike `product-pulse`/`retro`). Re-mapping edits the same issue; significant re-maps add a short `<!-- tunan:map-revision -->` changelog comment so the history is visible without forking the doc.

The skill is **read-only against the code.** Its only writes are the single map issue (and its revision comments). It never mutates the repo, the database, or any external system.

## Interaction Method

Default to the platform's blocking question tool: `AskUserQuestion` in Claude Code (call `ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded), `request_user_input` in Codex, `ask_user` in Gemini, `ask_user` in Pi (requires the `pi-ask-user` extension). Fall back to numbered options in chat only when no blocking tool exists in the harness or the call errors — not because a schema load is required. Never silently skip the question. In practice the only blocking question is the refresh confirmation when a map already exists (Phase 0).

## Modes

<mode> #$ARGUMENTS </mode>

Interpret the argument as a mode. If empty, default to `full` (or `refresh` semantics when a map already exists — Phase 0 routes).

- **`full`** (default) — parallel mappers analyze the whole repo and produce all seven sections. Orchestrator assembles one body and writes the issue.
- **`fast --focus <area>`** — a single mapper covers one area (`tech` → STACK+INTEGRATIONS, `arch` → ARCHITECTURE+STRUCTURE, `quality` → CONVENTIONS+TESTING, `concerns` → CONCERNS; default focus `tech+arch`). Only the covered sections are rewritten; the rest of the issue body is preserved verbatim.
- **`status`** — read-only. Read the map issue's provenance header, compare `mapped_at_sha` against current `git rev-parse HEAD`, and report staleness (commits behind, files changed). No re-scan, no write.
- **`refresh`** — re-map and update the same issue in place, then add a revision comment summarizing what changed.
- **`diff`** — re-scan, compare the fresh findings against the stored body, and post a **changed-sections summary** as an issue comment for review. Does not overwrite the body; the user runs `refresh` after reviewing.
- **`query <term>`** — answer a structural question about the codebase. Do **not** build a separate search index: read the map issue for written context, then use native search tools (Glob, Grep, Read) over the repo for the answer.

## Core Principles

1. **Current state, not aspiration.** Describe what the code *is* today — patterns actually in use, debt actually present — not what it should become. CONCERNS records real risk; it does not prescribe a roadmap.
2. **One living issue.** A repo has exactly one `tunan:codebase-map` issue. Re-mapping updates it; it is never duplicated.
3. **Concurrent discovery, serial write.** Mappers run in parallel but **return their sections to the orchestrator**; the orchestrator writes the issue once. Never let multiple agents edit the issue concurrently — concurrent edits clobber each other.
4. **Native search for structure.** Structural questions (who-calls-what, impact, layering) go through native Glob/Grep/Read tools over the repo.
5. **Provenance is load-bearing.** Every write stamps `mapped_at_sha` and date. `status`/`diff` depend on it to compute drift.
6. **Honest gaps over padding.** If a section is thin (no tests, no external integrations), say so in one line. Do not invent structure to fill a heading.

## Execution Flow

### Phase 0: GitHub preflight + route

The map is stored as a GitHub issue, never a local file. Verify prerequisites first. Run these one at a time:

```bash
gh --version
gh auth status
gh repo view --json nameWithOwner
```

- If `gh` is not installed, abort and direct the user to install it from https://cli.github.com or run `/tunan:setup`. Never fall back to a local file.
- If `gh auth status` does not exit 0, abort and direct the user to authenticate (`gh auth login`; in Claude Code suggest typing `! gh auth login`).
- If `gh repo view` does not resolve, abort and explain that a GitHub repo is required to store the map.
- **Setup reminder (non-blocking).** If the repo has no `tunan:config` issue, tell the user once, "This repo isn't set up for tunan yet; run `/tunan:setup` to configure it," then continue. map-codebase needs no config, so this never aborts the run.

Ensure the `tunan:codebase-map` label exists (Phase 2 re-checks):

```bash
gh label list --search "tunan:codebase-map"
gh label create "tunan:codebase-map" --color 0e8a16 --description "tunan codebase current-state map"
```

Run the create command only if the list shows no `tunan:codebase-map` label.

**Resolve the existing map issue (search all states so a closed map is reused, not duplicated):**

```bash
gh issue list --label "tunan:codebase-map" --state all --json number --jq '.[0].number // empty'
```

Route on the result and the mode:

- **No issue + (`full`/`fast`/empty)** → first map. Go to Phase 1.
- **No issue + (`status`/`diff`/`query`)** → nothing to read. Tell the user no map exists yet and offer to run `full`. Stop unless they accept.
- **Issue exists + `status`** → read provenance, compute staleness (below), report, stop.
- **Issue exists + `diff`** → go to Phase 1 (scan), then Phase 2 diff path (comment only).
- **Issue exists + `query`** → read the issue body, answer via native search tools, stop.
- **Issue exists + (`full`/`refresh`/empty)** → confirm before overwriting. Use the blocking question tool: "A map already exists (mapped at `<sha>`, `<date>`). Re-map and update it in place?" Options: *Refresh in place* (recommended) / *Cancel*. On confirm, go to Phase 1.

**Staleness computation** (for `status` and the refresh confirmation): read the issue body's provenance YAML, take `mapped_at_sha`, then:

```bash
git rev-parse HEAD
git rev-list --count <mapped_at_sha>..HEAD
git diff --stat <mapped_at_sha>..HEAD
```

Report `N commits behind` and a one-line file-churn summary. If `<mapped_at_sha>` is not in history (force-push/rebase), say the baseline is unreachable and recommend a full re-map.

### Phase 1: Map (parallel mappers)

Read `references/mapper-dispatch.md` — it holds the per-mapper prompts and the area→section assignment. Dispatch mappers using the platform's subagent primitive (`Agent`/`Task` in Claude Code, `spawn_agent` in Codex, `subagent` in Pi). Prefer tunan/bundled agents or the `Explore` agent over platform-built-in bare names. Respect the platform's active-subagent limit; queue overflow; fall back to sequential dispatch where parallel is unsupported.

- **`full`** → four mappers in parallel (tech, arch, quality, concerns).
- **`fast --focus <area>`** → one mapper for that area only.

**Each mapper returns its section markdown as its final message** — it does not write the issue. The orchestrator collects all returned sections. (This is the issue-state adaptation of GSD's "agents write files directly": concurrent issue edits would clobber, so discovery is parallel but the write is serial in Phase 2.)

### Phase 2: Assemble & write

Read `references/section-contract.md` for the exact body shape (provenance header + seven `##` sections) and the section ordering.

1. **Stamp provenance.** Capture `git rev-parse HEAD` and today's date into the provenance YAML block at the top of the body, with `mode` and (for fast) `focus`.
2. **Assemble the body.** For `full`/`refresh`: build the complete body from the returned sections. For `fast --focus`: read the current issue body, replace only the covered `##` sections, preserve the rest verbatim, and update the provenance header.
3. **Write path by mode:**
   - **First map** → create the issue. Title `[codebase-map] <repo-name>`:
     ```bash
     gh issue create --title "[codebase-map] <repo>" --label "tunan:codebase-map" --body-file <tmpfile>
     ```
   - **refresh / full-over-existing / fast** → update in place:
     ```bash
     gh issue edit <N> --body-file <tmpfile>
     ```
     For a significant change (a section materially rewritten), add a revision comment:
     ```bash
     gh issue comment <N> --body-file <revfile>
     ```
     where `<revfile>` starts with `<!-- tunan:map-revision -->` then a one-to-three-line changelog (`re-mapped at <sha>; ARCHITECTURE: split worker layer; CONCERNS: added migration-drift risk`).
   - **diff** → do **not** edit the body. Compare fresh sections against the stored body, and post a changed-sections summary as a comment (lead the comment with `<!-- tunan:map-diff -->`). Tell the user to run `refresh` to apply.

Confirm the label exists before any create (Phase 0 normally created it):

```bash
gh label list --search "tunan:codebase-map"
gh label create "tunan:codebase-map" --color 0e8a16 --description "tunan codebase current-state map"
```

Surface in chat: a one-to-two-line summary per section plus the top CONCERNS item, and the issue URL returned by `gh`. `brainstorm` (technical brainstorms), `plan` (Phase 1 research), and `work` (work-area scan) automatically read this issue as their current-state baseline when present — and `lfg` inherits it through `plan`/`work` — so once this map exists, downstream work starts from it.

## What This Skill Does Not Do

- Does not write local files. The map lives only in the `tunan:codebase-map` issue; there is no `.planning/` or any on-disk artifact.
- Does not keep a per-run timeline. One living issue, updated in place — re-mapping does not open a new issue.
- Does not build a bespoke search/intel index. The issue body is the written context; structural queries use native search tools.
- Does not prescribe a roadmap. CONCERNS surfaces real risk and debt; turning that into work is `brainstorm`/`plan`.
- Does not let mappers write the issue. Discovery is parallel; the issue write is a single serial step in the orchestrator.
- Does not mutate the repo or any external system. Code access is read-only.

## Learn More

The single-issue, living-document model is deliberate. A current-state map is only useful if there is one authoritative copy that stays current — a timeline of stale snapshots invites reading the wrong one. Storing it in issue state (not `.planning/*.md`) keeps it in the same searchable store as requirements (`tunan:req`), plans, config, and learnings (`tunan:solution`), so the whole project context lives in one place and travels with the repo on GitHub rather than in a contributor's working tree. The written map answers "what is this codebase and why"; native search tools answer "what calls this and what breaks if I change it." Run `map-codebase` when joining a repo or before a planning pass; run `status` to see whether the map has drifted from HEAD.
