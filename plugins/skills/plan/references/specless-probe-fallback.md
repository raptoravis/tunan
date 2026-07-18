# Spec-less Probe Fallback

Loaded by `plan` when the requirements issue (`tunan:req`) does not supply explicit
edge-coverage or prohibition sections, but the plan phase would benefit from running
the same probe logic the full-spec path uses. The principle: **absence of a spec
section is not absence of the concern** — the probe still fires, sourcing its
predicates from the requirement text directly.

## When This Applies

This fires during plan Phase 2 (Explore Approaches) or Phase 3 (Implementation Plan)
when ALL of:

1. The `tunan:req` issue body does NOT contain an explicit edge-case / boundary-condition
   enumeration (no "## Edge Cases" or equivalent heading with populated content).
2. The `tunan:req` issue body does NOT contain explicit prohibitions / "what NOT to build"
   (no "## Out of Scope" with prohibitive entries, or no "## Constraints" section).
3. The plan tier is Standard or Deep (Lightweight plans skip — the overhead isn't
   justified for a one-unit change).

## Protocol

### A. Edge Probe (deterministic)

When edge cases are not enumerated in the req:

1. Extract every requirement statement from the req issue body — each user story,
   acceptance criterion, or "must support" line is one requirement.
2. For each requirement, ask: **"What boundary condition would break this?"**
   - Data boundaries: empty, single, many, maximum, missing fields
   - Timing boundaries: concurrent, slow, timeout, retry, out-of-order
   - Identity boundaries: duplicate, missing, wrong type, stale
   - State boundaries: initial, mid-flow, interrupted, completed, rolled-back
3. Author each surfaced edge into the plan's acceptance criteria. An edge that maps
   to a defensible test assertion becomes a concrete gate criterion. An edge that
   can only be described as a backstop (no specific test, but a design invariant) is
   recorded as an explicit assumption with `verification: backstop` — the verifier
   will abstain rather than silently pass it.

**Never auto-dismiss an edge.** A wrong dismissal is the exact silent failure this
fallback exists to prevent. If genuinely not applicable, record the reason.

### B. Prohibition Recall (LLM prose pass)

When prohibitions / constraints are not enumerated in the req:

1. **Recall (adversarial).** Per requirement: *"What could this feature silently
   become that the author would NOT want, but the requirements don't forbid?"*
   Over-produce ~10 raw must-NOT candidates.
2. **Precision.** Drop routine engineering concerns (owned by code review). Keep
   only values / safety / data-integrity prohibitions (~2–3 survive).
3. **Author.** Each kept prohibition goes into the plan as a constraint — not as
   an implementation detail, but as a design invariant the work must respect.

**Never auto-dismiss a prohibition.** Surface unresolved ones as flagged assumptions.

### C. No-Silent-Drop Rule

For each section: (# probe-surfaced items) must equal (# items authored into the
plan + # items surfaced as explicit assumptions). Silence is never a resolution.
