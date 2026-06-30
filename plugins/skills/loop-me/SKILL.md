---
name: loop-me
description: "Design workflow specs through a grilling session — for recurring life patterns worth delegating to an agent. Use when the user says 'design a workflow', 'loop me', 'automate my X', 'workflow for Y', wants to spec out a recurring process they handle manually, or is exploring what parts of their work an agent could take over. Each workflow spec is a GitHub issue labeled `tunan:workflow` — ready for an implementer agent to build without asking a single question."
argument-hint: "[a workflow to design, or nothing to go find one]"
---

# Design a Workflow Spec

Design workflow specs through a stateful grilling session. A **workflow** is the spec of one recurring loop in the user's life, made real and ready for an implementer agent to build.

## The Loop Lens

A **loop** is a recurring pattern in the user's life: their career, their week, their morning, a single repeated activity. Picturing a life as loops within loops reveals how predictable its activities really are — which is what makes them worth **delegating**.

Use this lens to find loops worth specifying, and propose ones the user hasn't noticed. Every recurring manual process is a candidate: processing a channel (email, Slack, GitHub notifications), running a morning review, triaging a queue, preparing a weekly report, responding to a recurring request type.

A **workflow** is the spec of one loop, made real. You run a workflow on a loop — the loop is its running instantiation. Workflow specs live in GitHub issues labeled `tunan:workflow` and are the source of truth.

## Workspace Setup

Before grilling, ensure the workspace is ready:

### NOTES.md

`NOTES.md` is a local file at the repo root (or project root) that holds raw notes on the user's world: the tools they use, the channels they process, their own terminology for both. When it is empty or absent, interview the user about their world before specifying anything:

- What tools do you use day-to-day? (email client, Slack, GitHub, calendar, task manager, CRM, etc.)
- What channels do you process regularly? (inbox, mentions, assigned issues, calendar events, etc.)
- What terminology do you use for these things? (do you call it "triage" or "inbox zero" or "processing the queue"?)

Create or update `NOTES.md` with the findings. Sharpen fuzzy terms into canonical names as they surface during grilling, and record them here.

### GitHub Preflight

Workflow specs are GitHub issues. Run the standard checks before writing:

```bash
gh --version
gh auth status
gh repo view --json nameWithOwner
```

If any check fails, abort with guidance — never fall back to a local file for workflow specs.

Ensure the `tunan:workflow` label exists:

```bash
gh label list --search "tunan:workflow"
```

If absent:

```bash
gh label create "tunan:workflow" --color 1f883d --description "tunan workflow spec"
```

## Interaction Method

Same discipline as `grill-me` — load that skill for the full grilling protocol. The short form:

- **One question at a time** through the platform's blocking question tool (`AskUserQuestion` in Claude Code — call `ToolSearch` with `select:AskUserQuestion` first; `request_user_input` in Codex; `ask_user` in Gemini/Pi). Fall back to numbered options in chat only when no blocking tool exists or the call errors.
- **Alignment protocol.** Every question carries at least 3 ranked options with the single best one pre-selected as default (append `(Recommended)`. Load the `align` skill for the full protocol.
- **No stacking.** Pick the single most useful question and fire it. Wait for the answer.

## Vocabulary

Reach for these concepts only when a workflow calls for them — never as a checklist. **Mandate nothing structural**: a workflow needs no AI, no checkpoint, and no schedule unless the grilling shows it does.

- **Trigger** — what fires each run: an **event** (a new email, a new issue, a webhook) or a **schedule** (every morning, every Monday). Event-triggering is usually more efficient — the workflow runs only when there's something to do.
- **Checkpoint** — a human-in-the-loop point where the user is asked to verify or decide. Some workflows have none and run autonomously; some use no AI at all.
- **Push right** — defer the checkpoint as far as it will go. Do maximal work before involving the human, so they are asked once, late, with everything prepared. The ideal checkpoint presents a decision, not a draft.
- **Brief** — what a checkpoint presents: a tight, decision-ready summary — what was produced, why, and a link down to the asset itself — never the raw output. The user reads a brief, not a draft. Speed of review is imperative.

## Grilling Flow

### Phase 1: Find the Loop

If the user didn't name a specific workflow, use the loop lens to find one:

1. Read `NOTES.md` (or interview to build it)
2. Scan for recurring manual processes: things the user does daily, weekly, or on-trigger
3. Propose 2-3 candidate loops, ranked by delegation value (frequency × manual effort × spec-ability)
4. Let the user pick which to spec first

If the user named a specific workflow, skip to Phase 2.

### Phase 2: Spec the Workflow

Grill one dimension at a time, in this order (skip any that don't apply):

1. **Trigger** — what fires this? Is it event-driven or scheduled? If event-driven, what's the exact event?
2. **Input** — what data/context does the workflow receive at trigger time?
3. **Processing** — step by step, what happens between trigger and output? What decisions are made?
4. **Checkpoints** — where does a human need to verify or decide? Push each one right as far as it will go.
5. **Brief** — at each checkpoint, what does the human see? Design the brief for speed of review.
6. **Output** — what does the workflow produce? Where does it land?
7. **Failure modes** — what breaks? What's the fallback?
8. **Edge cases** — empty input, duplicate events, concurrent runs, partial failures

### Phase 3: Verify Completeness

Before writing the spec, cross-check:

- Could an implementer agent build this from the spec alone, without asking a single follow-up question?
- Is every term defined (in `NOTES.md` or the spec itself)?
- Are all failure modes addressed?
- Are checkpoint briefs concrete enough that the user knows exactly what they'll see?

If any answer is no, grill the unresolved dimension until it's yes.

### Phase 4: Publish the Workflow Spec

Write the spec as a GitHub issue:

**Title:** `[workflow] <descriptive name>`

**Body template:**

```markdown
## Trigger

<what fires this run — event or schedule, with exact conditions>

## Input

<what data/context the workflow receives>

## Processing

<step-by-step: what happens between trigger and output>

## Checkpoints

<each human-in-the-loop point: when it fires, what brief the user sees, what decision they make>

## Output

<what the workflow produces and where it lands>

## Failure Modes

<what can go wrong and how it's handled>

## Edge Cases

<empty input, duplicates, concurrency, partial failures>

## Notes

<any additional context, constraints, or open questions>
```

Create the issue:

```bash
gh issue create --title "[workflow] <name>" --label "tunan:workflow" --body-file <body-file>
```

Report the issue URL.

## After the Spec

Offer next steps:

1. **Spec another workflow** — find the next loop worth delegating
2. **Build this workflow** — hand the spec to an implementer agent (`/tunan:plan` or direct to `/tunan:work`)
3. **Refine this spec** — continue grilling the current workflow
4. **Done for now** — the spec is saved and ready when needed

Route through the platform's blocking question tool.
