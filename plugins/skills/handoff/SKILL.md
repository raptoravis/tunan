---
name: handoff
description: "Transfer working context between AI coding sessions via a GitHub issue labeled tunan:handoff instead of a local HANDOFF.md file. The create mode captures the current task, progress, failed approaches, key decisions, and resume steps into an issue; the resume mode reads a saved handoff issue, checks for git drift, and continues the work. Use when the user says handoff, hand off, save state, transfer context, wrap up a session for another agent, or pick up a saved handoff. Distinct from the resume skill, which resumes a feature pipeline by its issue phase markers — this is free-form session-to-session transfer. Takes create or resume plus an optional issue number."
argument-hint: "create|resume [<issue #N>]"
---

# handoff — transfer session context through a GitHub issue, not a local file

> 运行环境入口约定：本仓库的 `.claude/skills` 以 Claude Code 为源，示例默认写 `/tunan:*`。若同一 skill 在 Codex 中运行，所有面向 sponsor 的可复制入口在输出前改写为 `$tunan:*`；Claude Code 中保持 `/tunan:*`。

This skill does what `/handoff:create` and `/handoff:resume` do — capture the
state of an in-progress task so any agent can continue it later — but the
handoff lives in a **GitHub issue labeled `tunan:handoff`, never in a local
`HANDOFF.md`**. This keeps handoffs in the same issue-state store as every
other tunan artifact (requirements, plans, solutions, retros), so they work
across machines and sessions and never touch the working tree.

`handoff` is its own artifact kind, distinguished by the `tunan:handoff` label —
like `tunan:idea` / `tunan:retro`. It is not a feature-pipeline stage; for
resuming an interrupted `lfg` feature at the right phase, use the `resume` skill
instead (it reads a feature issue's labels and marker comments). This skill is
the lighter, free-form session-to-session context transfer.

## Invocation

```
/tunan:handoff create [<issue #N>]   # capture current context into a tunan:handoff issue
/tunan:handoff resume [<issue #N>]   # read a tunan:handoff issue and continue the work
```

- **No mode given** → infer: if the user is wrapping up, switching agents, or
  asks to "save state", treat as `create`; if they say "resume" / "pick up" /
  "continue", or an open `tunan:handoff` issue exists and they want to start
  from it, treat as `resume`. When genuinely ambiguous, ask via the blocking
  question tool (see Interaction Method).
- `<issue #N>` — in `create`, update that existing handoff issue in place
  instead of opening a new one; in `resume`, read that specific issue instead of
  auto-resolving the latest.

## Interaction Method

Any moment this skill asks the user to choose (ambiguous mode, which handoff
issue to resume among several, drift confirmation, whether to close a consumed
handoff) is an answer-alignment moment: fire the platform's blocking question
tool — never an ad-hoc chat menu. `AskUserQuestion` in Claude Code (call
`ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded),
`request_user_input` in Codex, `ask_user` in Gemini, `ask_user` in Pi (via the
`pi-ask-user` extension). Cap at 4 options; put extra destinations in the
question stem for free-form selection. Fall back to a numbered list in chat only
when no blocking tool exists or the call errors — never silently skip.

## GH preflight (required, both modes)

Handoffs are GitHub issues, so a working, authenticated `gh` is mandatory. Run
these and **abort with a clear message** if any fails — never fall back to a
local `HANDOFF.md`:

```bash
gh --version
```
```bash
gh auth status
```
```bash
gh repo view --json nameWithOwner
```

If any fails, stop and tell the user to fix gh setup (install from
`https://cli.github.com`, run `gh auth login`; in Claude Code suggest typing
`! gh auth login`, or run `/tunan:setup`).

## Mode: create

### Step 1 — gather current state

Read the actual repo state and the conversation, exactly as `/handoff:create`
does:

```bash
git status
```
```bash
git diff --stat
```
```bash
git log --oneline -5
```

From the conversation history, extract: the original goal, what was completed,
**what was tried and didn't work** (critical — saves the next agent hours), key
decisions and their rationale, user preferences expressed this session, and
error messages encountered with how they were resolved.

### Step 2 — build the handoff body

Load `references/handoff-template.md` and follow its body shape and authoring
rules (it is the authoritative copy — do not restate its rules here). Write the
filled body to an OS-appropriate temp file and pass it via `--body-file`; never
paste a long body inline. Temp path: `mktemp` on macOS/Linux (or Git Bash);
`Join-Path $env:TEMP ([guid]::NewGuid())` on Windows PowerShell.

### Step 3 — ensure the label, then create or update

Ensure the `tunan:handoff` label exists (create on demand):

```bash
gh label list --search "tunan:handoff"
```
```bash
gh label create "tunan:handoff" --color 0052cc --description "tunan session handoff"
```

**Always reuse the single shared handoff issue** (mirrors HANDOFF.md's
overwrite-the-single-file semantics): there is **one** `tunan:handoff` issue for
the repo, updated in place every time — never one per branch and never a fresh
issue each session. If `<issue #N>` was passed, update that one; otherwise find
the existing `tunan:handoff` issue (open **or closed**) and overwrite its body,
reopening it if it was closed. Only ever create a new issue when none exists.

List handoff issues across **all** states, so a previously closed handoff is
reused rather than duplicated:

```bash
gh issue list --label "tunan:handoff" --state all --json number,title,url,state,updatedAt
```

- **One issue exists** (the normal case) → it is the shared handoff. Update it
  regardless of which branch produced the earlier handoff; if its `state` is
  `CLOSED`, reopen it first.
- **Several exist** (should not happen under the single-issue rule, e.g. left
  over from older per-branch handoffs) → use the most recently updated one
  (`updatedAt`), reopening it if closed; mention the older duplicates so the user
  can close them.
- **None exist at all** → create the single handoff issue.

- **Reopen** the resolved issue first if it is closed:

  ```bash
  gh issue reopen <N>
  ```

- **Update** the resolved issue (or the passed `<issue #N>`):

  ```bash
  gh issue edit <N> --body-file <body-file>
  ```

- **Otherwise create** the one handoff issue. Title: `[handoff] <brief task title>`.

  ```bash
  gh issue create --title "[handoff] <title>" --label "tunan:handoff" --body-file <body-file>
  ```

### Step 4 — confirm (one line)

```
✅ Handoff saved: #<N> — <title>   🔗 <url>
```

Mention the next agent can pick it up with `/tunan:handoff resume #<N>` (or just
`/tunan:handoff resume` for the latest). Then stop — do not derail into more work.

## Mode: resume

### Step 1 — find and read the handoff

- If `<issue #N>` was passed, read it: `gh issue view <N> --json title,body,url,state,labels`.
  If it is closed, carries no `tunan:handoff` label, or its body lacks the
  `kind: handoff` metadata block, warn and confirm (blocking tool) before
  resuming against it — a stale or mistyped `#N` should not be resumed silently.
- Otherwise list handoff issues across **all** states (so a previously closed
  handoff is found rather than missed — mirrors `create` and the
  `tunan:config` / `tunan:codebase-map` single-issue lookups):

  ```bash
  gh issue list --label "tunan:handoff" --state all --json number,title,url,state,updatedAt
  ```

  - **One** → use it. If its `state` is `CLOSED`, reopen it first — it is the
    single shared handoff reused in place, so reopening keeps its number
    stable for reuse (same as `create` does):

    ```bash
    gh issue reopen <N>
    ```
  - **Several** → ask the user which to resume via the blocking question tool
    (show number, title, and how recent each is); reopen the chosen one if
    closed.
  - **None** → tell the user there is no handoff issue and stop; offer to
    create one (`/tunan:handoff create`) if they meant to save state instead.

  Distinguish "the command succeeded and returned zero issues" from "the command
  failed" (network error, rate limit, non-zero exit) — on a `gh` failure, report
  it and stop; never treat a failed lookup as "None / no open handoff".

Read the entire issue body carefully.

### Step 2 — verify state hasn't drifted

```bash
git status
```
```bash
git log --oneline -5
```

Compare against the handoff's metadata block: same branch? Commits since it was
written? Uncommitted changes it doesn't mention? If state has drifted
significantly, warn the user and ask (blocking tool) whether to proceed with the
handoff context anyway or have them describe what changed.

### Step 3 — summarize, don't dump

Give a brief summary, not the whole issue:

```
Resuming handoff #<N>: <title>
Goal: <1 sentence>
Status: <X of Y tasks complete>
Next: <first item from Resume Instructions>
```

### Step 4 — heed the warnings, then continue

Pay special attention to **Failed Approaches** (don't repeat them),
**Warnings** (respect the prior agent's gotchas), and **Key Decisions** (follow
established patterns unless the user asks to change). Start with the first item
in Resume Instructions unless the user redirects; if the handoff is unclear on
something critical, ask rather than guess.

### Step 5 — leave the shared handoff open for reuse

The handoff lives in **one shared `tunan:handoff` issue** that is overwritten on
the next `create`, so a consumed handoff does not need closing and stale
handoffs cannot accumulate — leave the issue **open** by default so its number
stays stable for reuse. Only close it if the user explicitly asks to retire the
handoff entirely (blocking tool to confirm); never close it merely because it
was picked up, and never close it if the user only previewed.

## Claude Code Fast-Path (`claude --bg`)

When the user is on Claude Code and wants to hand off immediately without creating a GitHub issue, use the `claude --bg` mechanism for a lightweight, same-machine handoff:

```bash
claude --bg --name "<descriptive name>" "<handoff summary>"
```

This launches a background agent seeded with the summary as its prompt. It starts in the current working directory and returns immediately; the user manages it with `claude agents`.

Always pass `--name` with a descriptive name (e.g. `--name "Fix login bug"`) — it sets the display name shown in the job list, session picker, and terminal title.

**When to use each path:**

| Path | When |
|------|------|
| `tunan:handoff` issue | Cross-machine handoff, long gaps between sessions, team handoffs, non-Claude-Code environments |
| `claude --bg` | Same machine, immediate continuation, Claude Code available, lightweight context |

**Include a "suggested skills" section** in the summary regardless of which path — it tells the next agent which skills to invoke.

**Do not duplicate** content already captured in other artifacts (PRDs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

**Redact sensitive information** — API keys, passwords, PII — before writing the summary (it becomes the agent's prompt).

## Common mistakes

- **Writing a local `HANDOFF.md`** — the whole point of this skill is that the
  handoff is a `tunan:handoff` issue (or a `claude --bg` agent on Claude Code). Never fall back to a local file; abort if
  `gh` is unavailable and `claude --bg` isn't applicable.
- **Skipping Failed Approaches** — always include it when anything was tried and
  abandoned (say "None" only if truly nothing failed). It is the highest-value
  section.
- **Resuming the wrong artifact** — for picking up an interrupted `lfg` feature
  pipeline, use the `resume` skill (it reads feature-issue phase markers). This
  skill is for free-form session handoffs.
- **Spawning duplicate handoff issues** — there is one shared `tunan:handoff`
  issue for the repo; always reuse it (reopening it first if it was closed)
  instead of creating a new one (per branch or per session).
- **Closing the shared handoff on consume** — the single `tunan:handoff` issue
  is meant to be reused and overwritten, so leave it open after resuming; close
  it only when the user explicitly asks to retire it.
