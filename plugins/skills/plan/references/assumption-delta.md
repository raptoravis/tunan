# Assumption-Delta Architecture Checkpoint

> Advisory, non-blocking. Fires **only** when the plan scope shows a singular→plural / required→optional / derived→chosen transition. When it fires, it surfaces ONE identity-model question before the plan is finalized. Most phases will not fire it — that is the point.

Load this during deepening (5.3.x) when the deepening pass covers Key Technical Decisions or Implementation Units. Skip it entirely for lightweight plans unless the deepening gate flagged a high-risk domain.

## Why this exists

Most quietly-imported architectural debt does not come from a missing upfront design phase. It comes at the *seam*: a later phase introduces a second case (a second platform, auth method, tenant, region, source of truth) and nobody re-asks whether the original abstraction still names the right thing. The phase that adds the second case is exactly the 20-minute conversation that prevents an afternoon of later cleanup.

## Run the detector

The detector is a deterministic scan over the plan's scope text. Strip fenced code blocks first, so a trigger word that appears only inside a code snippet does not fire. Scan for three signal families:

| Family | Trigger pattern | Example |
|---|---|---|
| `pluralization` | "second", "multiple", "additional", "another", "different <incumbent noun>", "per-<dimension>", "multi-<thing>" appearing near a previously-singular entity | "add a second auth provider", "support multiple regions" |
| `optional` | "optional", "not required", "may be empty", "nullable" applied to a previously-required field or value | "the config key is now optional" |
| `chosen` | "configurable", "user-specified", "selectable", "pluggable", "strategy pattern", "polymorphic" replacing a previously-derived or hardcoded value | "the retry policy is now configurable" |

The scan is conservative: it errs toward firing on ambiguous phrases rather than missing a real drift. A false fire costs one cheap question; a missed fire accumulates silent debt.

## Decision branch

**If no signals detected:** this phase does not change a core assumption. Skip the checkpoint entirely and continue deepening. Do not raise it with the user.

**If signals detected:** a core assumption may have lost its monopoly. Before the deepening pass writes its recommendations, answer this for the user:

> **Promote vs. add-alongside.** The usual correct move when a generalization occurs is to **promote** the new general representation to the primary and **demote** the old specific one to a detail of one variant — *not* to add the new one alongside the still-required old one. Adding alongside silently contradicts the generalized intent (a later variant that does not fit the old primary can be stored but never confirmed as a default).

Surface exactly **one question** — not an inventory of every signal. Pick the highest-impact signal (the one that would force the most downstream code to change if decided wrong) and ask:

> **Assumption delta:** the plan introduces `<signal>`. Does `<current primary identity>` still name the right thing, or should `<generalized identity>` become primary?

Record the answer in the deepened plan comment as an `<!-- assumption-delta -->` block:

- The **noun** that is now primary (the generalized identity).
- The **decision**: `promote` | `add-alongside` | `no-change`, with a one-line rationale.
- If `add-alongside`: call it out as accepted debt and note what would force a later promote.

## Optional companion: an invariant test

When a signal fires, suggest (do not require) a contract/invariant test that encodes the now-generalized intent — e.g. *"every confirmed default round-trips through the primary use-path, for every supported variant."* That test goes red the instant a future phase reintroduces the singular assumption, so the regression cannot land silently. If the user accepts, add the test as a task in the plan.

## Config

Toggleable via the `tunan:config` issue under `plan.assumption_delta` (default: `true`). When `false`, skip the checkpoint entirely for all plans.

## This checkpoint is advisory

It informs and records; it never blocks plan finalization. Its value is asking the question at the right moment — the moment the second case appears.
