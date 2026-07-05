---
name: retro
description: "Generate a time-windowed engineering retrospective on what actually shipped and how fast the team moved — merged PRs, shipped features, commit/PR cadence, shipping streaks, per-author breakdown, in-flight and stuck work, and learnings captured in the window. Use when the user says 'run a retro', 'weekly retro', 'what did we ship', 'how did this week go', 'sprint review', or passes a window like '7d'/'30d'. Zero-config: reads git history and GitHub issues/PRs only. Stores each report as a GitHub issue labeled tunan:retro (browse past retros via gh issue list)."
argument-hint: "[lookback window, e.g. '7d', '30d', '14d'; default 7d]"
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - AskUserQuestion
---

# Engineering Retro

> 运行环境入口约定：本仓库的 `.claude/skills` 以 Claude Code 为源，示例默认写 `/tunan:*`。若同一 skill 在 Codex 中运行，所有面向 sponsor 的可复制入口在输出前改写为 `$tunan:*`；Claude Code 中保持 `/tunan:*`。

`retro` reads git history and GitHub issues/PRs for a given time window and produces a compact, single-page engineering retrospective: what shipped, how fast the team moved, what is still in flight, and what was learned. Each report is stored as a GitHub issue labeled `tunan:retro`, and the headlines are surfaced in chat. The list of `tunan:retro` issues is the browseable timeline of past retros.

This is the engineering-cadence complement of `product-pulse`. **`product-pulse` reports user experience and system performance and deliberately does *not* report "what shipped." `retro` is exactly that missing half** — shipped work and the cadence behind it — read straight from `git` and `gh`. Run pulse to see how users fared; run retro to see how the team moved. They never overlap.

The skill is **read-only and zero-config.** It never mutates the repo, the database, or any external system — it only reads `git log`/`git shortlog` locally and queries GitHub through `gh` read commands, then writes one report issue. There is no interview and no `tunan:config` dependency; the only inputs are the repo's own history and the lookback window.

## Interaction Method

Default to the platform's blocking question tool: `AskUserQuestion` in Claude Code (call `ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded), `request_user_input` in Codex, `ask_user` in Gemini, `ask_user` in Pi (requires the `pi-ask-user` extension). Fall back to numbered options in chat only when no blocking tool exists in the harness or the call errors — not because a schema load is required. Never silently skip the question. In practice retro only asks if the window argument is unparseable; a normal run needs no questions.

## Lookback Window

<lookback> #$ARGUMENTS </lookback>

Interpret the argument as a time window. Common forms:

- `7d`, `14d`, `30d` — trailing days (retro is typically weekly)
- `48h`, `72h` — trailing hours (for short sprints or launch retros)

If the argument is empty, default to `7d`. If the argument is a schedule keyword (`weekly`, `daily`), treat the run as ad-hoc over the matching window (`weekly`→`7d`, `daily`→`24h`) and surface the scheduling hint in Phase 3. If the argument is unparseable, ask the user to clarify.

Resolve the window to concrete UTC date bounds **once**, up front, and reuse the same bounds for every query and for the report title. Use the same start date for `git --since`, `gh --search "merged:>=…"`, and `gh --search "closed:>=…"` so the report is internally consistent.

## Core Principles

1. **Read it like a tech lead.** No hardcoded "good/bad" thresholds. Present the counts, cadence, and cycle times; let the reader judge.
2. **Single page.** Target 30–45 lines of report. If a section is thin, leave it thin; do not pad.
3. **Shipped means landed.** Count a PR as shipped only when it is merged (not just opened) within the window. Count a feature as shipped when its `tunan:req` issue closed in the window or its PR merged in the window.
4. **Cadence over volume.** Raw commit/LOC counts are AI-inflated and misleading. Lead with merged-PR count, shipping streak, and PR cycle time (open→merge), and treat commit counts as secondary color only.
5. **Memory through saved reports.** Every run creates a `tunan:retro` GitHub issue so past retros are browseable as a timeline via `gh issue list --label tunan:retro`.
6. **No PII beyond git identity.** Per-author breakdown uses the author names/handles already public in git and GitHub. Do not add emails or any other personal data to the report body.
7. **Compounding loop.** Surface the `tunan:solution` learnings captured in the window so the retro reinforces the compound-knowledge loop, not just the shipping numbers.

## Execution Flow

### Phase 0: GitHub preflight

Each retro report is stored as a GitHub issue, never a local file, and most data comes from `gh`. Verify prerequisites first. Run these one at a time:

```bash
gh --version
gh auth status
gh repo view --json nameWithOwner
```

- If `gh` is not installed, abort and direct the user to install it from https://cli.github.com or run `/tunan:setup`. Never fall back to a local file.
- If `gh auth status` does not exit 0, abort and direct the user to authenticate (`gh auth login`; in Claude Code suggest typing `! gh auth login`).
- If `gh repo view` does not resolve, abort and explain that a GitHub repo is required to store retro reports.
- **Setup reminder (non-blocking).** If the repo has no `tunan:config` issue, tell the user once, "This repo isn't set up for tunan yet; run `/tunan:setup` to configure it," then continue. retro needs no config, so this never aborts the run.

Ensure the `tunan:retro` label exists before writing (Phase 2.4 re-checks):

```bash
gh label list --search "tunan:retro"
gh label create "tunan:retro" --color 8957e5 --description "tunan engineering retro"
```

Run the create command only if the list shows no `tunan:retro` label.

### Phase 1: Gather (read-only)

Resolve the window start date (e.g. `7d` → `START=2026-06-01`) and reuse it below. Run the git commands and the `gh` commands in parallel where the harness allows (they hit different systems); keep each query scoped to the window.

**Git cadence (local):**

```bash
git log --since="7 days ago" --pretty=format:"%h%x09%an%x09%ad%x09%s" --date=short
git shortlog -sn --since="7 days ago" --no-merges
git log --since="7 days ago" --date=short --pretty=format:"%ad" --no-merges
```

- First command: commit list (hash, author, date, subject) for the shipped/grouping read.
- Second: per-author commit counts.
- Third: dates only — derive the **shipping streak** (the longest run of consecutive calendar days with at least one commit, ending at or near the window's end) and commits-per-active-day.

**Merged PRs (shipped):**

```bash
gh pr list --state merged --search "merged:>=2026-06-01" --limit 100 \
  --json number,title,author,mergedAt,createdAt,additions,deletions,labels
```

Compute **PR cycle time** per PR as `mergedAt − createdAt`; report the median and the slowest one. Group merged PRs by author for the per-author breakdown.

**Features & learnings (tunan artifacts):**

```bash
gh issue list --label tunan:req --state closed --search "closed:>=2026-06-01" --limit 100 --json number,title,closedAt,labels
gh issue list --label tunan:solution --state all --limit 100 --json number,title,updatedAt,labels
```

- Closed `tunan:req` issues in the window = features that fully landed (req → plan → solution → closed).
- For `tunan:solution`, keep only those whose solution comment landed in the window. If precise timing is unavailable from the list, note the count of solution-labeled features touched and link them; do not fabricate timestamps.

**In-flight & stuck:**

```bash
gh pr list --state open --limit 100 --json number,title,author,createdAt,isDraft
gh issue list --label tunan:req --state open --limit 100 --json number,title,createdAt,labels
```

Flag as **stuck** any open PR or open `tunan:req` issue older than 14 days (report the age; do not editorialize beyond "stuck").

If any single query errors or returns nothing, render that section as `no data` and continue — a partial retro is still useful. Never block the whole report on one failed query.

### Phase 2: Assemble & write

#### 2.1 Assemble the report

Fill the template below from the Phase 1 results. Six sections, in order; keep the total to 30–45 lines.

```markdown
# [retro] <START>..<END>

## Headlines
- <N> PRs merged · <M> features shipped · <streak>-day shipping streak
- <one or two lines of the most notable cadence or shipping facts>

## Shipped
- #<pr> <title> — <author> (<cycle time>)
- ... (merged PRs in the window; group tightly, cap the list and note "+N more" if long)
- Features closed: #<req> <title>, ...

## Cadence
- Merged PRs: <N> · median cycle time: <X> · slowest: #<pr> (<Y>)
- Commits: <C> across <D> active days (<C/D>/active day) · streak: <streak> days
- By author: <name> <merged>PR/<commits>c · ...

## In flight
- Open PRs: <N> (<draft> draft) — oldest #<pr> (<age>)
- Open features: <N> req issue(s)
- ⚠ Stuck (>14d): #<n> <title> (<age>), ...   ← omit the line if none

## Learnings
- #<issue> <title> — <one-line takeaway from the tunan:solution comment>
- ... (tunan:solution learnings captured in the window; "none this window" if empty)

## Reflections
- <1–5 process observations: bottlenecks, cycle-time outliers, review gaps, momentum>
```

Discipline: numbers first, narration second. If `tunan:req`/`tunan:solution` labels are absent (a repo not using the tunan flow), drop the "Features closed" line and the Learnings section to the PR/commit data and note that tunan artifacts were not found — the cadence read still stands.

#### 2.2 Write the report

Confirm the label exists (Phase 0 normally created it):

```bash
gh label list --search "tunan:retro"
gh label create "tunan:retro" --color 8957e5 --description "tunan engineering retro"
```

Run the create command only if the list shows no `tunan:retro` label.

Write the filled template to a temp file, then create the issue. Title is `[retro] <START>..<END>` using the resolved window bounds:

```bash
gh issue create --title "[retro] 2026-06-01..2026-06-08" --label "tunan:retro" --body-file <tmpfile>
```

Surface the **Headlines** and the top **Reflection** in chat, plus the issue URL returned by `gh issue create`. To browse past retros as a timeline, run `gh issue list --label tunan:retro`.

### Phase 3: Routine hook

retro is most useful on a cadence. After an ad-hoc run:

- If the argument was a schedule keyword (`weekly`, `daily`), note that this run is ad-hoc and suggest scheduling via the harness's available primitive (the in-plugin `schedule` skill where present; otherwise a platform-native option such as cron or a GitHub Action) for recurring retros.
- If this is the third or later retro the user has run and none is scheduled, mention once that scheduling is available. Don't nag on every run.

Never schedule automatically. Any scheduling handoff requires explicit confirmation.

## What This Skill Does Not Do

- Does not report user experience or system performance — that's `product-pulse`. retro is strictly about what shipped and how fast.
- Does not rank or grade people. Per-author counts are descriptive, not a leaderboard or performance review.
- Does not lead with raw LOC or commit counts as a productivity metric — those are AI-inflated. Cadence (merged PRs, streak, cycle time) leads.
- Does not mutate the repo or any external system. All git and `gh` access is read-only except the single report issue it creates.
- Does not editorialize beyond the data. It surfaces stuck items and outliers; it does not assign blame.

## Learn More

The single-page constraint and "cadence over volume" posture are deliberate. A retro that lists every commit produces attention sprawl and rewards LOC churn; one page that leads with merged-PR cadence, shipping streak, and cycle time forces the reader to see flow, not noise. The `tunan:retro` issue list is the team's working memory of how it has been shipping over time — searchable and filterable via `gh issue list --label tunan:retro`, and a natural input to `new-milestone` and `product-pulse` reviews. Pairing the cadence read with the window's `tunan:solution` learnings keeps the retro tied to the compound-knowledge loop rather than becoming a pure metrics dashboard.
