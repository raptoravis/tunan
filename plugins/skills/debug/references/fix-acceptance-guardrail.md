# Fix-Acceptance Guardrail (Anti-Overfitting)

Loaded by `debug` during the fix-verification step. A multi-signal gate that prevents
accepting a fix that merely greens the regression test — the defense against Goodhart's
Law applied to "make the test pass."

## Why This Exists

"the failing test now passes" is a gameable success signal. Automated Program Repair
research (Smith et al., FSE 2015; Qi et al., ISSTA 2015) found that ~98% of "plausible"
auto-generated patches were functionality-deleting no-ops that vacuously satisfied a
weak oracle. An LLM optimizing "make the test green" is subject to the same failure mode —
suppress the symptom, delete the branch, weaken the assertion.

Per Goodhart's Law, the defense is not a better single metric — it is several
**partially-independent** signals that pull in different directions, plus separating
the test that *drives* the fix from the check that *judges* it.

## The Five Signals

A fix is accepted only when **all applicable signals** agree. Any one failing signal
(without a justified technical-debt escape) rejects the fix.

### 1. Target Test Greens

The regression test that reproduced the bug now passes. This is the existing bar —
the driving test. Necessary but not sufficient.

### 2. Mutation Check (when available)

If the project uses mutation testing (Stryker, mutmut, pitest, etc.), run it scoped
to the changed line(s). The regression test must **kill** a mutant seeded at the fix
site. A **surviving mutant** means the test asserts the symptom, not the root cause —
reject the fix.

When mutation testing is not configured in the project: **skip** with a logged note.
Never assume pass.

### 3. No-Op / Behavior-Deleting Detector

Inspect `git diff` of the fix. If the net change only **deletes** or short-circuits
behavior (removed branches, early returns that skip logic, weakened assertions,
comment-outs, blanket `return null` / `return true`), the fix is **rejected** unless
the root-cause analysis **explicitly justifies** a removal. This guards the "98% were
deletions" failure mode.

Red flags in the diff:
- A branch or condition removed with no replacement
- An assertion weakened (e.g., `assert_eq!(a, b)` → `assert!(a.is_some())`)
- An early return that skips the main logic body
- A hardcoded constant replacing a computed value with no explanation
- A `try/catch` that silently swallows without logging

### 4. Adjacent / Held-Out Tests Green

Run tests touching the changed file's import/dependency graph. Any newly-broken
neighbor **rejects** the fix. If the project has no test suite touching the import
graph, skip with a logged note — never assume pass.

### 5. Revert-and-Reconfirm (Agans Rule 9)

Revert the fix, confirm the bug returns; reapply, confirm it is gone. Proves *this
change* is what fixed it — not a side effect of the test rig, not a transient
condition that happened to clear.

- Uncommitted fixes: `git stash` → confirm bug → `git stash pop` → confirm fixed
- Committed fixes: `git revert -n` → confirm bug → `git reset --hard HEAD` → confirm fixed

Requires a recorded repro (an automated test OR explicit manual steps). If no repro
exists, this signal cannot pass — surface to the user as `CHECKPOINT: cannot verify
without a repro`.

## Graceful Degradation

Signals degrade onto whatever the environment provides. Every degradation is
**logged** — a skipped signal is never silently passed.

| Signal | When unavailable | Behavior |
|---|---|---|
| 2. Mutation check | No mutation testing configured | Skip with logged note — never assume pass |
| 4. Adjacent tests | No test suite touching the import graph | Skip with logged note |
| 1, 3, 5 | No test suite at all | Guardrail reduces to signals 3 + 5 (no-op detector + revert-and-reconfirm) |
| 1, 3, 5 | No test suite AND no repro | Cannot verify → surface `CHECKPOINT` to user; do not silently pass |

## Escape Hatch — Documented Technical Debt

If a signal cannot be made to pass and the user accepts the fix anyway, record the
acceptance as documented technical debt: name the unmet signal, state the justification,
and surface it in the resolution summary. This is the only way a fix lands without the
full gate passing, and it is never silent.

## Scope Boundary

This guardrail hardens fix acceptance for **one bug**. It is not a test framework, not
a CI policy, and not an incident-management system. Where a signal reuses existing
project structure (test suite, mutation testing), it reuses — it does not build a
parallel system.
