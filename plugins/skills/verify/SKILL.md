---
name: verify
description: "Run a project's test/lint/build checks (and optionally delegate dynamic app observation) and emit a structured, schema-versioned validation contract. Use after code changes to get a machine-readable green/fail signal before pushing, or as a local green gate inside autonomous pipelines like lfg. Always invoke fully-qualified as tunan:verify to avoid colliding with a host built-in verify."
---

# verify — run checks, emit a machine contract

Run the project's verification checks (test / lint / build, plus an optional
dynamic observation) and report the result as a stable, versioned JSON contract —
the **same envelope** `code-review` emits in `mode:agent`, so `lfg` and other
callers read either skill the same way. This skill is the dynamic (does-it-run)
counterpart to `code-review`'s static (is-it-sound) review.

**Always invoke this skill fully-qualified as `tunan:verify`** — a host may ship
an unnamespaced `verify`; never call it bare.

## Invocation

```
/tunan:verify [mode:agent] [gate:#N]
```

| Mode | Behavior |
|------|----------|
| default | Human-readable markdown summary of each check + overall verdict. |
| `mode:agent` | One **raw JSON object** (the contract below), no markdown fence — for programmatic callers. Report-only; the caller decides what to do. |

**`gate:#N`** (optional) — a feature issue ref (`#N` or URL) carrying a frozen
acceptance gate (a `<!-- tunan:gate -->` comment written by `plan`). When passed,
verify judges each gate criterion verbatim and emits the `gates[]` dimension (Step
2b). When omitted, verify tries to discover the gate from the current branch's open
PR / feature issue, but never blocks if none is found — it simply omits `gates[]`
and reports checks only.

## What it does NOT do

- It does not fix failures, commit, push, or open PRs — it reports.
- It does not reinvent browser/app driving. Dynamic observation is **delegated**
  to the existing `test-browser` skill (see the `observe` check).

## Step 1: Detect the checks to run

Resolve which commands to run, in this precedence:

1. **Config** — the `verify:` block in the repo's `tunan:config` GitHub issue.
   Resolve it with `gh issue list --label "tunan:config" --state open --json number --jq '.[0].number // empty'`,
   then read its body (`gh issue view <N> --json body`) and parse the fenced
   `yaml` block. It may name `test`, `lint`, `build` commands explicitly. If no
   `tunan:config` issue exists, or `gh` is unavailable, skip this source and
   fall through to repo convention below — never read a local config file.
2. **Repo convention** — obvious entrypoints already present (e.g. a test script
   in `package.json`, a `Makefile` target, `bin/rails test`, `pytest`,
   `go test ./...`).
3. **Language-stack inference** — only when neither of the above resolves.

Ambiguity policy:

- **Multiple plausible commands for one check and no config to disambiguate** →
  do not guess. Record that check as `skip` with a reason and set the run
  `status: degraded` (a degraded run is not authoritative green).
- **No detectable checks at all** → emit `status: skipped` with a reason; do not
  error.

## Step 2: Run each check

Run each resolved command through the Bash tool, **one command at a time** — no
`&&`/`;` chaining, no error suppression. Capture pass/fail and any short failure
detail. Record one `checks[]` entry per command:

```json
{ "name": "tests", "status": "pass", "messages": [] }
```

`name` is a short id (`structure` | `tests` | `lint` | `build` | `observe`);
`status` is `pass` | `fail` | `skip`; `messages[]` holds failure detail or skip
reason.

**Optional `observe` check** — only when the plan or `verify:` config explicitly
asks for dynamic observation. Do not build browser/app driving here; **delegate to
the `test-browser` skill** and fold its outcome into a single `observe` check
entry. Omit the `observe` check entirely when not requested.

## Step 2b: Judge the frozen acceptance gate (when one exists)

The plan stage may freeze an **acceptance gate** — a `<!-- tunan:gate -->` comment
on the feature issue listing the verbatim, checkable criteria the work is measured
against (each with a stable `G-ID` and a traceability `source` back to the plan's
R-IDs / U-IDs). When a gate exists, judge it; this is the static counterpart to
running checks — checks ask "does it run?", the gate asks "does it meet the frozen
acceptance criteria?".

**Resolve the gate** (skip the whole step, omitting `gates[]`, if none resolves):

1. If `gate:#N` was passed, use that feature issue.
2. Else discover it from the current branch's open PR body or branch name (best
   effort): `gh pr view --json body,number` then scan the body for a `#N` feature
   ref. Never block — if discovery is ambiguous or finds nothing, omit `gates[]`.
3. Read the frozen gate comment (the GitHub Storage Preflight in Step 1's config
   read applies; require `gh`):

   ```bash
   gh api repos/{owner}/{repo}/issues/<N>/comments --jq '.[] | select(.body | startswith("<!-- tunan:gate -->")) | .body'
   ```

   Empty → no gate; omit `gates[]`.

**Judge each criterion — verbatim, outcome-based.** For each `G-ID` row in the
frozen gate, record one `gates[]` entry (see the contract's `gates[]` element).
Quote the criterion **verbatim** from the frozen text — never restate it from
memory (restating is how goalposts drift). Assign a verdict from the criterion's
own basis and the actual result:

- `pass` — the criterion is met (e.g. its `command` exited 0, its named test
  passes, the asserted behavior holds).
- `fail` — the criterion is measured and not met. A failed gate is a blocking red
  (`gates_failed` → `verdict_code: not_ready`).
- `invalid` — the criterion **could not be measured** by the checks available this
  run (e.g. an `observe`-basis criterion when no dynamic observation ran). `invalid`
  means "unmeasured", not "failed": it does not make the verdict red, but it does
  force `status: degraded` so the green is not treated as authoritative. Record the
  reason in `messages[]`.

**Honest-verifier abstention.** When a gate criterion carries a `verification: backstop`
marker (set at plan time to flag a non-inferable check), the verifier must **abstain**
rather than confidently false-pass. The backstop tag means the correct answer cannot be
derived from the spec alone — the verifier does not know that it does not know, and a
bare "are you sure?" prompt does not fix it. Read `references/honest-verifier.md` for
the full disposition table. In brief: a `backstop` criterion with explicit evidence
(wired test / observed behavior) → `pass`; without → `invalid` with
`reason: insufficient_spec`. An inferable criterion (no `backstop` tag) is never
abstained — over-abstention is as wrong as false-passing.

**Do not edit the gate comment.** The gate is the frozen contract; verify reads and
quotes it, never rewrites it.

> **Tamper note.** In tunan's issue-comment memory model the gate is a GitHub
> comment, not a worktree file, so architect-loop's "git diff the gate file →
> auto-FAIL on edit" check does not apply here. The freeze is procedural: `work`
> never edits issue comments, and verify quotes the frozen text verbatim rather
> than restating it.

## Step 3: Summarize and emit

Compute `summary` (checks dimension, plus the gates dimension when Step 2b ran) and
`verdict_code` per the contract, then emit.

- **default mode** — a short markdown summary: one line per check
  (name → pass/fail/skip); when a gate was judged, one line per gate criterion
  (`G-ID` → pass/fail/invalid, with the verbatim criterion); then the overall
  verdict. Keep it ASCII-safe.
- **`mode:agent`** — one raw JSON object, no fence. Minimum shape:

```json
{
  "schema_version": 2,
  "status": "complete",
  "verdict_code": "ready | ready_with_fixes | not_ready",
  "summary": {
    "checks_total": 0,
    "checks_passed": 0,
    "checks_failed": 0,
    "gates_total": 0,
    "gates_passed": 0,
    "gates_failed": 0,
    "gates_invalid": 0
  },
  "checks": [],
  "gates": []
}
```

Include the `gates_*` counts and the `gates[]` array **only when Step 2b judged a
gate**; omit all four `gates_*` keys and `gates[]` when no gate resolved (a
gate-less run is unchanged from before).

`verdict_code` is derived deterministically from `summary` per
`references/output-contract.md`. For verify: `checks_failed > 0` **or
`gates_failed > 0`** → `not_ready` (a failed check or a failed acceptance gate is a
blocking red for a green gate); otherwise → `ready`. verify never emits
`ready_with_fixes` — that value is code-review's only. A failed check or gate keeps
`status: complete` (the run finished; the result is just red).
Use `status: degraded` for ambiguous detection, partial runs, **or when any gate is
`invalid`** (unmeasured → green is non-authoritative); use `status: skipped` when
nothing was runnable. `gates_invalid` alone never makes `verdict_code` red — it only
drives `degraded`. Every status object carries `"schema_version": 2` and, on
`degraded`/`skipped`/`failed`, a `reason`.

The contract envelope, the full `verdict_code` derivation rule, the versioning
policy, and the stability scope are defined authoritatively in
`references/output-contract.md` (a byte-identical copy of
`code-review/references/output-contract.md`).

## Interaction

This skill runs without blocking questions in the common case. If it must choose
among genuinely ambiguous detected commands and no config resolves it, prefer
`degraded` over prompting in pipeline/`mode:agent` contexts; in interactive use it
may ask via the platform's blocking question tool (`AskUserQuestion` in Claude
Code — load it via `ToolSearch` `select:AskUserQuestion` first; `request_user_input`
in Codex; `ask_user` in Gemini/Pi), falling back to a numbered chat list only when
no such tool exists.
