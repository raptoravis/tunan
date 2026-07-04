# Honest Verifier — Abstention on Non-Inferable Checks

Shared reference for the verification judgment phase. When a check is tagged `verification: backstop` (meaning the correct answer cannot be derived from the spec alone), the verifier must **abstain** rather than confidently false-pass.

## The problem it solves

A verifier is trustworthy on **inferable** checks — defects determined by the stated spec. On a **non-inferable** check the correct answer is *not derivable from the spec alone* (e.g. "does `[1,2]` touching `[2,3]` merge?", "is a 'character' a grapheme or a code unit?"). On these the verifier *does not know that it does not know*: measured behavior is a **confident PASS on the blind-spot check ~100% of the time**, because a model cannot self-detect a gap it does not perceive.

The honest verifier converts a silent false-pass (the worst failure: you don't know to look) into an explicit, actionable "write a held-out test."

## The two properties

1. **Exogenous, not endogenous.** The trigger is the *external tag* (`backstop`), never the verifier's self-judgment. Asking the verifier to "abstain if unsure" barely moves the number — on a true blind spot it stays confidently wrong. A confidence gate cannot reach a blind spot the model does not feel — so there is **no "are you sure?" prompt**; routing is on the pre-existing tag only.
2. **Routing, not diagnosis.** The verifier need not name the omitted rule (if it could, it wouldn't be a blind spot). The honest verdict requires only "I was told this is under-specified and I cannot rule it out." The omitted rule is carried by a human-authored held-out test, not by the verifier.

## The disposition

For each check item that carries a `verification` tier:

| Item | Confirmable with explicit evidence? | Disposition |
|---|---|---|
| Inferable (`verification: explicit` or plain) | n/a — graded normally | `passed` / `failed` as usual; **never abstained** |
| Non-inferable (`verification: backstop`) | **yes** (a wired held-out test that passes, or directly-observed behavior) | `passed` |
| Non-inferable (`verification: backstop`) | **no** | **abstain** → `insufficient_spec`, flagged `human_needed` — **never `passed`** |

- **Explicit evidence** = a wired held-out/property-based test that passes, or a behavior the verifier directly observed. Symbol presence + wiring is **not** explicit evidence for a non-inferable truth.
- **Never silent, never a hard halt.** The abstained item routes to human confirmation. Autonomous (pipeline) runs produce a prominent `unverified — held-out test recommended` flag.
- **Distinguishable reason.** The abstain disposition carries `reason: insufficient_spec` so the `human_needed` outcome is never conflated with an ordinary manual-UAT `human_needed`.

## Integration with tunan verify

When the gate comment (`<!-- tunan:gate -->`) carries `verification: backstop` markers on individual checks, the verifier applies the disposition table above. A check without a `verification` tag is treated as inferable.

In the JSON output contract, an abstained check adds `"reason": "insufficient_spec"` to the finding and sets `"verdict": "human_needed"`.

## Model-tier note

Abstention is model-tier dependent. Budget tiers are less flag-responsive and may degrade toward confident false-pass. Run honest-verifier judgment on the session's model; on a budget-tier run, treat the abstention as best-effort and flag the tier limitation in the output.
