---
name: new-project
description: "Bootstrap a new project end to end: establish the project's intent (problem, approach, users, key metrics, tracks), lay out an initial roadmap of milestones, and optionally scope the first milestone's requirements — all stored in one GitHub issue labeled tunan:project. Use when starting a new product or initiative, when the user says 'new project', 'start a project', 'set up the project', '新项目', '立项', or 'bootstrap this'. Greenfield orchestrator over setup, research, brainstorm, and map-codebase. Can also bootstrap from existing planning docs (ADRs/PRDs/SPECs) via --ingest, synthesizing intent + requirements with conflict detection against locked decisions. For the next cycle of an existing project use new-milestone."
argument-hint: "[optional: project idea / one-line pitch, or @path to an idea doc] [--auto] [--ingest <path|globs>]"
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - Agent
  - AskUserQuestion
---

# New Project

> 运行环境入口约定：本仓库的 `.claude/skills` 以 Claude Code 为源，示例默认写 `/tunan:*`。若同一 skill 在 Codex 中运行，所有面向 sponsor 的可复制入口在输出前改写为 `$tunan:*`；Claude Code 中保持 `/tunan:*`。

`new-project` is the greenfield bootstrap orchestrator. It establishes a project's durable intent and an initial roadmap, then optionally seeds the first milestone's work — sequencing tunan's existing skills (`setup`, research, `brainstorm`, `map-codebase`) into one guided flow so a project starts from a written baseline instead of an empty repo.

**The durable artifact is one GitHub issue labeled `tunan:project`** — the project's living document, one per repo, updated in place (like `tunan:config` / `tunan:codebase-map`), never a local file. It holds the project intent (problem, approach, users, key metrics, tracks) **and** the roadmap (an ordered list of milestones, each linking its `tunan:req` feature issues). This issue is the upstream grounding that `ideate`, `brainstorm`, `plan`, `product-pulse`, and `dogfood-beta` read — it replaces the former `STRATEGY.md` local file.

Read `references/project-issue-contract.md` for the exact body shape and the gh read/write recipes. Read `references/project-interview.md` for the intent interview (problem/approach/persona/metrics/tracks) — its pushback rules are load-bearing; improvising from memory produces a passive transcription instead of a project doc.

## Interaction Method

Default to the platform's blocking question tool: `AskUserQuestion` in Claude Code (call `ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded), `request_user_input` in Codex, `ask_user` in Gemini, `ask_user` in Pi (requires the `pi-ask-user` extension). Fall back to numbered options in chat only when no blocking tool exists in the harness or the call errors — not because a schema load is required. Never silently skip the question.

Ask one question at a time. Prefer free-form responses for the substantive intent sections (problem, approach, persona); reserve single-select for routing decisions.

**Alignment protocol.** When asking the sponsor to choose between options, follow the align protocol: offer at least 3 ranked options with the single best one pre-selected as the default — place it first and append `(Recommended)` to its label. Load the `align` skill for the full protocol. Never hand an open-ended choice back to the sponsor.

## Argument

<project_idea> #$ARGUMENTS </project_idea>

The argument is an optional project pitch or an `@path` to an idea document. `--auto` runs the flow with minimal interaction after the intent interview (research → roadmap → requirements run sequentially using sensible defaults); it requires a non-empty idea (argument text or `@`-referenced doc) to work from. If the argument is empty, Phase 1 opens by asking what the project is.

`--ingest <path|globs>` switches on **ingest mode** (Phase 1b): instead of (or before) the interactive intent interview, the project intent and an initial set of requirements are synthesized from existing planning documents in the repo — ADRs, PRDs, SPECs, RFCs — with conflict detection against any locked decisions. Without an explicit path, Phase 0 offers ingest when it detects conventional planning-doc locations. See Phase 1b and `references/doc-conflict-engine.md`.

## Core Principles

1. **Intent before tasks.** Establish problem/approach/users/metrics first. A roadmap without intent is a todo list.
2. **One living issue.** A repo has exactly one `tunan:project` issue. It is updated in place, never duplicated. If one already exists, route to `new-milestone`.
3. **Reuse, don't reinvent.** Requirements are `brainstorm` → `tunan:req` issues; code current-state is `map-codebase`; config is `tunan:config` via `setup`. `new-project` sequences them; it does not re-implement them.
4. **Right-size the roadmap.** Two-to-four milestones ahead is plenty. Milestone 1 is scoped concretely; later milestones are one-line intentions, refined by `new-milestone` when their turn comes.
5. **Honest, not aspirational.** The intent interview pushes back on vanity metrics, fluffy approaches, and everyone-personas (see the interview reference).

## Execution Flow

### Phase 0: Preflight + route

The project doc is a GitHub issue, never a local file. Verify prerequisites, one at a time:

```bash
gh --version
gh auth status
gh repo view --json nameWithOwner
```

- If `gh` is not installed, abort and direct the user to install it from https://cli.github.com or run `/tunan:setup`. Never fall back to a local file.
- If `gh auth status` does not exit 0, abort and direct the user to authenticate (`gh auth login`; in Claude Code suggest typing `! gh auth login`).
- If `gh repo view` does not resolve, abort and explain that a GitHub repo is required.

Ensure the `tunan:project` label exists (Phase 5 re-checks):

```bash
gh label list --search "tunan:project"
gh label create "tunan:project" --color 5319e7 --description "tunan project intent + roadmap"
```

Run the create command only if the list shows no `tunan:project` label.

**Resolve any existing project issue:**

```bash
gh issue list --label "tunan:project" --state open --json number --jq '.[0].number // empty'
```

- **A `tunan:project` issue already exists** → this is not a new project. Tell the user, and use the blocking question tool to offer: *Define the next milestone* (recommended → hand off to `new-milestone`) / *Revise the existing project intent* (re-run the relevant Phase 1 sections and update in place) / *Cancel*. Do not create a second project issue.
- **No issue** → continue to Phase 1. If `--ingest` was passed, or a quick native-Glob scan finds conventional planning-doc locations (`docs/adr/`, `docs/prd/`, `docs/specs/`, `docs/rfc/`, root `{ADR,PRD,SPEC,RFC}-*.md`), offer ingest mode via the blocking question tool (*Bootstrap intent from existing docs (recommended)* / *Run the interactive interview instead*) and route to Phase 1b if accepted.

**Setup gate (blocking).** Check whether the repo has a `tunan:config` issue:

```bash
gh issue list --label "tunan:config" --state open --json number --jq '.[0].number // empty'
```

If that returns empty, this repo hasn't been through tunan setup — load and run the `setup` skill to completion first, then continue to Phase 1. If `setup` cannot complete (user declines, or it errors), abort rather than bootstrapping a project into an unconfigured repo. If it returns a number, setup is already done — continue.

### Phase 1: Project intent interview

Read `references/project-interview.md` and run it. Capture, in order: target problem, approach, who it's for, key metrics, tracks (sections 1–5 required), plus the optional sections only if the user engages them. Apply the pushback rules — push back once, maybe twice, quote the user back, keep answers tight.

If `--auto` and an idea doc was provided, draft each section from the doc and skip the interactive pushback, but still produce all five required sections.

### Phase 1b: Ingest existing planning docs (brownfield bootstrap)

Run this phase when `--ingest <path|globs>` is given, or when Phase 0 detected conventional planning-doc locations (`docs/adr/`, `docs/prd/`, `docs/specs/`, `docs/rfc/`, root-level `{ADR,PRD,SPEC,RFC}-*.md`) and the user opted in via the blocking question tool. It replaces or augments the Phase 1 interview by synthesizing intent **from the docs**.

**Read `references/doc-conflict-engine.md` first** — its severity semantics (BLOCKER/WARNING/INFO), plain-text report format, and the BLOCKER safety gate are load-bearing.

1. **Discover docs.** Resolve the explicit `--ingest` path/globs, or scan the conventional locations with native Glob (not shell `find`). Cap at 50 docs per run; if more match, report the cap and ask which subset. Classify each by type (ADR/SPEC/PRD/DOC) from its path/heading.
2. **Synthesize.** Read the docs (pass paths to a subagent for large sets) and extract: the project's target problem, approach, users, metrics, tracks, plus candidate requirements (one per discrete deliverable). Apply the precedence rule **ADR > SPEC > PRD > DOC** when two docs disagree on the same decision.
3. **Detect conflicts.** Run the conflict checks defined by `references/doc-conflict-engine.md` against any **already-locked decisions** — primarily an existing `tunan:project` issue's intent sections (if one exists, this is not a fresh bootstrap; route per Phase 0). Bucket findings into BLOCKER/WARNING/INFO. A doc that contradicts a locked decision is a BLOCKER; competing variants among the ingested docs are WARNINGs; superseded-by-precedence notes are INFO.
4. **Gate.** Render the plain-text conflict report. **If any BLOCKER exists, exit without writing the project issue or any `tunan:req`** — the gate holds regardless of WARNING/INFO counts. If only WARNINGs/INFO, get explicit approval via the blocking question tool before proceeding. Empty report → continue silently.
5. **Hand to the normal flow.** The synthesized intent feeds Phase 2 (roadmap) and Phase 3 (requirements) exactly as the interview output would — the synthesized requirements become milestone-1 `tunan:req` candidates (created via `brainstorm`/`new-raw` in Phase 3). The `tunan:project` issue is still written only in Phase 5.

**Optional research seed.** If the project is in a domain where prior art matters and the user wants it, dispatch lightweight research (the `deep-research` skill or a web-research subagent) before or during the interview, and fold findings into approach/metrics. Skip by default; do not force research on a clearly-scoped internal tool.

### Phase 2: Initial roadmap

Lay out the milestone sequence (the roadmap). Define **milestone 1 concretely** — a name, a one-line outcome, and the scope boundary of what it delivers. Sketch the next 1–3 milestones as one-line intentions only (they are refined by `new-milestone` later). Keep to 2–4 milestones total; more is a planning smell.

Use the blocking question tool to confirm the milestone-1 scope boundary when there is a real fork (e.g., "MVP = read-only viewer, or include editing?").

### Phase 3: Seed milestone-1 requirements (optional)

Offer to scope milestone 1 into concrete requirements now, or defer. Use the blocking question tool: *Brainstorm milestone-1 requirements now* (recommended) / *Defer — I'll run brainstorm per feature later* / *Skip*.

If accepted: for each milestone-1 deliverable, hand off to `brainstorm` to produce a `tunan:req` feature issue (or create lightweight `tunan:raw` stubs via `new-raw` for the user to expand later). Dispatch `brainstorm` via the platform's subagent primitive (`Agent`/`Task` in Claude Code, `spawn_agent` in Codex, `subagent` in Pi), or load it inline. **The `tunan:project` issue is not written until Phase 5**, so pass the captured project intent (problem, approach, persona, milestone-1 scope) explicitly to `brainstorm` rather than expecting it to read the not-yet-created issue. Collect the resulting issue refs (`#<N>`) — they link under milestone 1 in the roadmap.

### Phase 4: Brownfield code map (optional)

If the repo already contains code (not an empty greenfield checkout), offer to run `map-codebase` so the project starts from a current-state snapshot. Use the blocking question tool: *Map the existing code now* (recommended for non-empty repos) / *Skip*. If accepted, run `map-codebase` (it writes the `tunan:codebase-map` issue); record its issue ref in the project doc's `codebase_map` frontmatter key (see `references/project-issue-contract.md`).

### Phase 5: Write the project issue

Assemble the body per `references/project-issue-contract.md`: the provenance/frontmatter block, the five intent sections, then the `## Roadmap` with milestone 1 (and its linked `tunan:req` refs) marked current and later milestones marked planned. Stamp `last_updated` with today's date and set `current_milestone`.

Present the full draft in chat and offer one edit round. Then confirm the label exists (Phase 0 normally created it) and create the issue:

```bash
gh label list --search "tunan:project"
gh label create "tunan:project" --color 5319e7 --description "tunan project intent + roadmap"
```

Run the create command only if the list shows no `tunan:project` label. Write the assembled body to a temp file, then:

```bash
gh issue create --title "[project] <project name>" --label "tunan:project" --body-file <tmpfile>
```

Surface in chat: the project name, the milestone-1 scope, any linked `tunan:req` refs, and the issue URL. State the handoff: `plan`/`work`/`lfg` execute the milestone-1 requirements; they read this `tunan:project` issue as upstream grounding. To start the next cycle later, run `new-milestone`.

## What This Skill Does Not Do

- Does not write local files. The project doc lives only in the `tunan:project` issue — there is no `STRATEGY.md`, `PROJECT.md`, `ROADMAP.md`, or any on-disk artifact.
- Does not duplicate the project issue. If one exists, it routes to `new-milestone` or updates in place.
- Does not re-implement requirements, code-mapping, or config. It orchestrates `brainstorm`, `map-codebase`, and `setup`.
- Does not implement code or write plans. Milestone requirements flow to `plan`/`work`/`lfg`.
- Does not pad the roadmap. Two-to-four milestones; only milestone 1 is scoped concretely up front.

## Learn More

`new-project` retired the former `STRATEGY.md` local file: project intent now lives in the `tunan:project` issue alongside the roadmap, so the whole project context is in one searchable place that travels with the repo on GitHub rather than in a contributor's working tree. The intent interview is shared with the `strategy` skill — `new-project` bootstraps intent **plus** an initial roadmap in one pass, while `strategy` is the deeper standalone interview that sharpens the same issue's intent sections (and never touches the roadmap). The rigor is in the questions, not the headings. Pairing intent with an explicit milestone roadmap is what lets later work start "on the current state": `new-milestone` extends the roadmap as the project moves, and the per-feature `brainstorm` → `plan` → `work` loop fills each milestone in. Run `new-project` once to stand a project up; run `new-milestone` for every cycle after.
