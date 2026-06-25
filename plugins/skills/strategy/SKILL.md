---
name: strategy
description: "Create or sharpen the product strategy — the intent sections (target problem, approach, persona, key metrics, tracks) of the tunan:project GitHub issue — through a rigorous interview. Use when starting a product, changing direction, or when ideate, brainstorm, or plan need sharper upstream product grounding."
argument-hint: "[optional: section to revisit, e.g. 'metrics' or 'approach']"
---

# Product Strategy

**Note: The current year is 2026.** Use this when dating the strategy.

`strategy` produces and sharpens the **product strategy** — what the product is, who it serves, how it succeeds, and where the team is investing. That strategy is the **intent half of the `tunan:project` GitHub issue** (the five locked intent sections, plus the optional Not-working-on / Marketing sections) — the same issue `new-project` bootstraps and `new-milestone` extends. tunan keeps this in the issue, never a local file. The roadmap / milestone ledger in that issue is owned by `new-project` / `new-milestone`; `strategy` never touches it.

Where `new-project` does a quick bootstrap of intent **plus** an initial roadmap, `strategy` is the **deep interview** — it pushes back on weak answers to make the intent sections sharp. Downstream skills (`ideate`, `brainstorm`, `plan`, `product-pulse`) read the same `tunan:project` issue as grounding.

## Interaction Method

Default to the platform's blocking question tool: `AskUserQuestion` in Claude Code (call `ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded), `request_user_input` in Codex, `ask_question` in Antigravity CLI (`agy`), `ask_user` in Pi (requires the `pi-ask-user` extension). Fall back to numbered options in chat only when no blocking tool exists in the harness or the call errors (e.g., Codex edit modes) — not because a schema load is required. Never silently skip the question.

Ask one question at a time. Prefer free-form responses for the substantive sections (problem, approach, persona); reserve single-select for routing decisions (which section to revisit). Each option label must be self-contained.

## Focus Hint

<focus_hint> #$ARGUMENTS </focus_hint>

Interpret any argument as an optional focus: an intent section to revisit (`metrics`, `approach`, `tracks`) or a scope hint. With no argument, proceed open-ended and let the issue state decide the path.

## Core Principles

1. **Anchor, not plan.** Strategy is what the product is and why. Features belong in `brainstorm`; schedules and milestones belong in the roadmap (owned by `new-project` / `new-milestone`). Do not let either creep into the intent sections.
2. **Rigor in the questions, not the headings.** The section headers are plain English. The interview questions enforce strategy discipline.
3. **Short is a feature.** The intent sections are constrained (≤4 sentences each, Tracks excepted; 3–5 metrics; 2–4 tracks). Push back on expansion.
4. **Durable across runs.** This skill is rerunnable. On a second run it updates the intent sections in place, preserves what is working, and only challenges sections that look stale or weak.
5. **Never touch the roadmap.** `strategy` reads and writes only the intent sections (and optional Not-working-on / Marketing). The `## Roadmap` section, the frontmatter `current_milestone`, and any `<!-- tunan:project-revision -->` comments are owned by `new-project` / `new-milestone` — carry them forward verbatim.

## Execution Flow

### Phase 0: Route by Issue State

**GH preflight — run before any issue read/write. Abort with the guidance shown if any check fails; NEVER fall back to a local file.**

```bash
gh --version
```
```bash
gh auth status
```
```bash
gh repo view --json nameWithOwner
```

If `gh` is missing, tell the user to install it from `https://cli.github.com` or run `/tunan:setup`; if unauthenticated, tell them to run `gh auth login`; if the repo does not resolve, a GitHub repository is required — abort and explain.

**Resolve the `tunan:project` issue** (one open issue per repo):

```bash
gh issue list --label "tunan:project" --state open --json number,title --jq '.[0].number // empty'
```

- **No issue** -> First run. Ensure the `tunan:project` label exists (`gh label list --search "tunan:project"`, else `gh label create "tunan:project" --color 1f883d --description "tunan project intent + roadmap"`). Go to Phase 1; Phase 1 creates the issue with the intent sections plus a placeholder `## Roadmap` (`_No milestones yet — run \`/tunan:new-milestone\` to plan the first._`).
- **Issue exists and argument names a specific section** -> Targeted update. Go to Phase 2.
- **Issue exists, no argument** -> Ask which intent section(s) to revisit, then Phase 2.

Announce the path in one line: "No project issue found - let's write the strategy." or "Found project issue #<N> - let's sharpen its strategy."

### Phase 1: First-Run Interview

Read `references/interview.md`. This load is non-optional - the pushback rules, anti-pattern examples, and quality bar for each section live there. Improvising from memory produces a passive transcription instead of a strategy.

Run the interview in the section order of the intent block:

1. Target problem
2. Our approach
3. Who it's for
4. Key metrics
5. Tracks
6. Not working on (optional)
7. Marketing (optional)

For each section, ask the opening question, apply the pushback rules, and capture the final answer in the user's own language. Do not skip the pushback step - it is the core of the skill. Two rounds of pushback per section maximum; capture what the user has given after that and note the section is worth revisiting on the next run.

When the required sections (1-5) are captured, read `references/strategy-template.md`, fill in the intent block, and present the full draft in chat before writing. Offer one round of edits. Then build the `tunan:project` body in an OS temp file (bash `${TMPDIR:-/tmp}`, PowerShell `$env:TEMP`) — the YAML frontmatter (`name`, `last_updated`, omit `current_milestone` until a milestone exists), the filled intent sections, and a placeholder `## Roadmap` — and create the issue:

```bash
gh issue create --title "[project] <project name>" --label "tunan:project" --body-file <body-file>
```

Report the issue URL (a `🔗` line) so it is clickable.

### Phase 2: Update Run

Read the existing `tunan:project` issue body fully (`gh issue view <N> --json body --jq .body`). Summarize the current intent in 3-5 lines so the user sees what is on file.

If the argument named a specific section, jump to that section in `references/interview.md`. Apply pushback as if this were a first run - do not rubber-stamp existing weak content. If no specific target, ask the user which intent section to revisit using the blocking question tool. Options:

- "Target problem"
- "Our approach"
- "Who it's for"
- "Metrics, tracks, or other"

For each revisited section, re-interview with full pushback. For sections the user confirms are still accurate, leave them untouched.

**Merge, do not clobber.** Build the new body by replacing only the intent sections you revised; **carry forward verbatim** the frontmatter (update `last_updated` to today's ISO date; keep `current_milestone`, `codebase_map`, and any other keys), the entire `## Roadmap` section, the optional sections you did not revise, and any `<!-- tunan:project-revision -->` comments. Then write it back in place:

```bash
gh issue edit <N> --body-file <body-file>
```

After the edit, re-read the body and confirm the `## Roadmap` section and `current_milestone` survived intact. If the roadmap was dropped or altered, the merge clobbered milestone state owned by `new-project` / `new-milestone` — restore it from the pre-edit body and re-write before reporting done.

### Phase 3: Downstream Handoff

After writing, note in one line that the strategy lives in the `tunan:project` issue #<N> and that `ideate`, `brainstorm`, `plan`, and `product-pulse` will pick it up as grounding on their next run.

If the issue has no roadmap yet, suggest `/tunan:new-milestone` to plan the first milestone.

## What This Skill Does Not Do

- Does not touch the roadmap, milestones, or `current_milestone` — those are `new-project` / `new-milestone`.
- Does not prioritize the backlog. Prioritization is a separate workflow.
- Does not write product requirements or implementation plans - those are `brainstorm` and `plan`.
- Does not compute metric values. It records which metrics matter and where they live, not what they read today.

## Learn More

The "Target problem / Our approach / Tracks" structure is informed by Richard Rumelt's *Good Strategy Bad Strategy* - specifically his kernel of diagnosis, guiding policy, and coherent action. The interview questions in `references/interview.md` are designed to push past the patterns he calls "bad strategy": fluff, goals dressed up as strategy, and feature lists in place of a guiding choice.
