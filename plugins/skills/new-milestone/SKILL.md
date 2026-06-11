---
name: new-milestone
description: "Start the next cycle of an existing project: decide what the next milestone delivers, optionally research and scope its requirements, then extend the roadmap in the tunan:project issue — closing the current milestone and opening the next. Use when a project's current milestone is done and the user says 'new milestone', 'what's next', 'next cycle', 'plan the next milestone', '下一个里程碑', or 'next phase'. Brownfield complement of new-project; requires an existing tunan:project issue."
argument-hint: "[optional: what the next milestone should deliver, or @path to a notes doc]"
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - Agent
  - AskUserQuestion
---

# New Milestone

> 运行环境入口约定：本仓库的 `.claude/skills` 以 Claude Code 为源，示例默认写 `/tunan:*`。若同一 skill 在 Codex 中运行，所有面向 sponsor 的可复制入口在输出前改写为 `$tunan:*`；Claude Code 中保持 `/tunan:*`。

`new-milestone` is the brownfield next-cycle orchestrator — the complement of `new-project`. Where `new-project` stands a project up, `new-milestone` moves it forward: it reads the existing `tunan:project` issue, closes the current milestone, defines the next one, and optionally scopes its requirements — sequencing research and `brainstorm` into one guided flow so the next cycle starts from the project's current state.

It updates the **same `tunan:project` issue** in place (one per repo, issue-only, never a local file): marking the current milestone done, appending the next milestone to the `## Roadmap`, and updating `current_milestone`. Requirements are new `tunan:req` feature issues linked under the new milestone.

Read `references/project-issue-contract.md` for the body shape and the gh read/write recipes.

## Interaction Method

Default to the platform's blocking question tool: `AskUserQuestion` in Claude Code (call `ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded), `request_user_input` in Codex, `ask_user` in Gemini, `ask_user` in Pi (requires the `pi-ask-user` extension). Fall back to numbered options in chat only when no blocking tool exists in the harness or the call errors. Never silently skip the question.

Ask one question at a time. Prefer free-form for the "what's next" framing; single-select for routing and scope-boundary forks.

**Alignment protocol.** When asking the sponsor to choose between options, follow the align protocol: at least 3 ranked options, best pre-selected first with `(Recommended)`. Load the `align` skill for the full protocol.

## Argument

<milestone_intent> #$ARGUMENTS </milestone_intent>

Optional: a one-line statement of what the next milestone delivers, or an `@path` to notes. If empty, Phase 1 opens by asking what's next.

## Core Principles

1. **Continuity over restart.** The next milestone builds on the project intent and prior milestones already in the `tunan:project` issue. Do not re-run the full intent interview — only revise intent sections if the user signals direction changed.
2. **One current milestone.** Closing the prior milestone and opening the next is a single atomic update to the roadmap; `current_milestone` always names exactly one.
3. **Scope this milestone concretely.** The new milestone gets a name, a one-line outcome, a scope boundary, and (optionally) linked `tunan:req` issues. Milestones beyond it stay one-line intentions.
4. **Reuse, don't reinvent.** Requirements are `brainstorm` → `tunan:req`. Code drift is `map-codebase` `refresh`. This skill sequences them.

## Execution Flow

### Phase 0: Preflight + load the project

Verify GitHub prerequisites, one at a time:

```bash
gh --version
gh auth status
gh repo view --json nameWithOwner
```

Same abort guidance as `new-project` (install gh / authenticate / repo required). Never fall back to a local file.

**Require an existing project issue.** Resolve it:

```bash
gh issue list --label "tunan:project" --state open --json number --jq '.[0].number // empty'
```

- **No `tunan:project` issue** → there is no project to extend. Tell the user and offer to run `new-project` to bootstrap one. Stop unless they accept.
- **Issue exists** → read its body (`gh issue view <N> --json body --jq .body`), parse the intent sections, the `## Roadmap`, and `current_milestone`. Summarize the current state in 3–5 lines: the project, the current milestone, and its linked `tunan:req` status (done vs open).

### Phase 1: What's next

Decide what the next milestone delivers. Open free-form ("With <current milestone> landing, what should the next milestone deliver?") and converge on a one-line outcome plus a scope boundary. Use the blocking question tool when there's a real fork in direction (e.g., "deepen the current track, or open a new one?").

**Check for drift.** If the current milestone's intent or the project's approach has shifted, offer to revise the relevant intent section(s) in place (reuse the questions in `new-project`'s interview reference). Default is to leave intent untouched — only the roadmap changes.

**Optional research.** For genuinely new feature areas, offer lightweight research (the `deep-research` skill or a web-research subagent) before scoping. Skip by default.

### Phase 2: Scope the milestone's requirements (optional)

Offer to scope the new milestone into concrete requirements now, or defer. Use the blocking question tool: *Brainstorm the requirements now* (recommended) / *Defer — run brainstorm per feature later* / *Skip*.

If accepted: for each deliverable, hand off to `brainstorm` to produce a `tunan:req` feature issue (or create `tunan:req` stubs via `new-req`). Collect the issue refs (`#<N>`) to link under the new milestone.

### Phase 3: Update the project issue

Update the `tunan:project` issue body in place (per `references/project-issue-contract.md`):

1. Mark the prior `🚧 current` milestone `✅ done (shipped <date>)`; tick its delivered `tunan:req` refs.
2. Append the new milestone as `🚧 current` with its name, one-line outcome, scope, and any linked `#<req>` refs.
3. Set `current_milestone` to the new milestone id and stamp `last_updated` with today's date.
4. Present the diff (the closed milestone + the new one) in chat and offer one edit round.

```bash
gh issue edit <N> --body-file <tmpfile>
```

Then add a revision comment:

```bash
gh issue comment <N> --body-file <revfile>
```

where `<revfile>` starts with `<!-- tunan:project-revision -->` then a one-line changelog (`closed M2 (shipped 2026-06-11); opened M3 — <scope>`).

Surface in chat: the closed milestone, the new milestone's scope, any linked `tunan:req` refs, and the issue URL. State the handoff: `plan`/`work`/`lfg` execute the new milestone's requirements and read the `tunan:project` issue as upstream grounding.

## What This Skill Does Not Do

- Does not write local files. The roadmap lives only in the `tunan:project` issue.
- Does not create a second project issue, and does not run without one (routes to `new-project` if absent).
- Does not re-run the full intent interview — intent is revised only on explicit drift.
- Does not implement code or write plans. Requirements flow to `plan`/`work`/`lfg`.
- Does not leave two milestones current. Closing one and opening the next is a single roadmap update.

## Learn More

`new-project` and `new-milestone` are the bootstrap and continuation halves of the same loop, both writing the one `tunan:project` issue. Keeping the roadmap in issue state means each cycle starts from the project's actual current state — the prior milestones, their shipped `tunan:req` issues, and the intent — rather than from a contributor's memory or a stale local doc. The per-feature `brainstorm` → `plan` → `work` loop fills each milestone in; `new-milestone` is what advances the project between cycles.
