# Plan Convergence Loop

Wraps the single-pass deepening (5.3.3–5.3.8) in a bounded revise→review
loop with explicit stop conditions. Load this only when the convergence
fast path at Phase 5.3 fires (the user said "converge the plan", "iterate
the plan to convergence", or passed `--converge` / `--max-cycles N`).

The default deepening path stays single-pass. Convergence is opt-in because
it spends more sub-agent budget — multiple deepening + review cycles — to
drive a high-stakes plan to a stable state rather than strengthening it once.

## What the loop is for

A single deepening pass strengthens the plan against a checklist once, then
a single `doc-review` gate checks the result. That is enough for most plans.
It is not enough when a plan is contested or high-risk: the first review
surfaces issues, the fixes introduce new gaps, and nothing re-checks the
fixes. Convergence closes that gap — it keeps revising and re-reviewing until
the plan stops generating actionable findings or a stop condition fires.

## Inputs

- `max_cycles` — cap on revise→review cycles. Default **3**. Override with
  `--max-cycles N` (clamp to 1–5; a value above 5 is almost always a sign the
  plan should go back to `brainstorm`, not loop harder).
- The feature issue ref and its `<!-- tunan:plan -->` comment (the artifact
  under revision; every cycle PATCHes it in place by id — never forks a new
  comment).

## The loop

Run cycles `1..max_cycles`. Each cycle has three steps.

### Step A — Revise

- **Cycle 1:** run the standard deepening execution (5.3.3–5.3.7 from
  `references/deepening-workflow.md`) to produce the first strengthened plan.
- **Cycles 2+:** revise only the sections the previous cycle's review flagged.
  Do not re-run the full section-scoring pass — the review findings already
  name the targets. Apply the same synthesis discipline as 5.3.7 (strengthen
  named sections, never renumber U-IDs, no implementation code, no inventing
  product scope).

PATCH the plan comment in place after each revision so the review in Step B
reads the current body.

### Step B — Review

Dispatch a review pass over the revised plan and collect findings with a
severity each. Use the platform's subagent primitive (`Agent`/`Task` in
Claude Code, `spawn_agent` in Codex, `subagent` in Pi).

- **Always:** invoke `doc-review` in `mode:agent` on the feature issue ref.
  It returns structured findings (see `doc-review`'s findings schema) with a
  severity/priority on each — that severity drives the convergence gate below.
- **Multi-model augmentation (when available):** if a second model's CLI is
  installed and authed, add one independent review from it so convergence is
  not judged by a single model's blind spots. Prefer a `codex` review pass
  (load the `codex:rescue` skill with a plan-review prompt) when the `codex`
  CLI is present; skip silently when it is not. Treat its issues as additional
  findings, normalized to the same severity buckets (HIGH / MEDIUM / LOW).

Pass each reviewer the revised plan comment body and the origin requirement
issue ref so findings are judged against product intent, not in a vacuum.

### Step C — Evaluate stop conditions

Check these in order. The first that matches ends the loop.

1. **Converged.** No unresolved HIGH findings remain, AND no actionable
   MEDIUM/LOW findings fall outside the plan's own boundaries. A MEDIUM/LOW
   that only proposes content already correctly scoped out (a deferred
   follow-up, an explicit non-goal) does not block convergence — record it
   under Open Questions or Deferred to Follow-Up Work and converge.
   → Report convergence and exit to 5.3.8.

2. **Stall.** This cycle's findings substantially repeat the previous cycle's
   — the same sections raising the same class of issue, or a finding the prior
   cycle already tried to fix resurfacing unchanged. Two cycles of churn
   without net progress is a stall. Looping again will not help.
   → Stop and escalate (below). Do not silently exit as if converged.

3. **Cycle budget exhausted.** `max_cycles` reached with HIGH or
   out-of-bounds actionable findings still open.
   → Stop and escalate (below).

If none match, continue to the next cycle (back to Step A with the new
findings as the revision targets).

## Escalation on non-convergence

When the loop stops on **stall** or **cycle budget** with findings still
open, do not present the plan as finished and do not silently pick a
resolution. Surface the residual disagreement to the sponsor as a decision.

Load the `align` skill and follow its protocol: present the unresolved
findings as a numbered, ranked set of options with a recommended default
pre-selected, routed through the platform's blocking question tool. Typical
options:

1. **Accept the plan as-is** (recommended when remaining findings are
   MEDIUM/LOW judgment calls) — record the open findings under Open Questions
   and proceed.
2. **Resolve a specific finding now** — the sponsor names which one; revise
   that section and re-check, then re-present.
3. **Send back to `brainstorm`** — when the residual findings are product-level
   (the plan keeps fracturing because WHAT to build is still unsettled).

Never auto-resolve a HIGH finding by fiat. The sponsor decides. This honors
the alignment invariant: a recommendation is offered, but silence is not
consent — wait for an explicit choice before continuing.

## After the loop

However the loop ended (converged, or escalated and the sponsor chose to
proceed), continue with 5.3.8 (document review) → 5.3.9 → 5.4 per
`references/plan-handoff.md`. The convergence loop replaces the single
deepening pass; it does not replace the final document-review gate, which
still runs. Add or update the `deepened: YYYY-MM-DD` frontmatter field if any
cycle substantively strengthened the plan.

## Headless / pipeline mode

In `disable-model-invocation` or pipeline contexts (e.g., LFG) there is no
synchronous sponsor to escalate to. Convergence does not auto-trigger in
these contexts — pipelines run the standard single-pass deepening. If a
pipeline explicitly requests convergence, run the loop but on non-convergence
record the residual findings under a `## Open Questions` section in the plan
(instead of firing `align`) and return control to the caller, so the open
items remain visible rather than silently dropped.
