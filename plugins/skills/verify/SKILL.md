---
name: verify
description: "Run a project's test/lint/build checks (and optionally delegate dynamic app observation) and emit a structured, schema-versioned validation contract. Use after code changes to get a machine-readable green/fail signal before pushing, or as a local green gate inside autonomous pipelines like lfg. Always invoke fully-qualified as yunxing:verify to avoid colliding with a host built-in verify."
---

# verify — run checks, emit a machine contract

Run the project's verification checks (test / lint / build, plus an optional
dynamic observation) and report the result as a stable, versioned JSON contract —
the **same envelope** `code-review` emits in `mode:agent`, so `lfg` and other
callers read either skill the same way. This skill is the dynamic (does-it-run)
counterpart to `code-review`'s static (is-it-sound) review.

**Always invoke this skill fully-qualified as `yunxing:verify`** — a host may ship
an unnamespaced `verify`; never call it bare.

## Invocation

```
/yunxing:verify [mode:agent]
```

| Mode | Behavior |
|------|----------|
| default | Human-readable markdown summary of each check + overall verdict. |
| `mode:agent` | One **raw JSON object** (the contract below), no markdown fence — for programmatic callers. Report-only; the caller decides what to do. |

## What it does NOT do

- It does not fix failures, commit, push, or open PRs — it reports.
- It does not reinvent browser/app driving. Dynamic observation is **delegated**
  to the existing `test-browser` skill (see the `observe` check).

## Step 1: Detect the checks to run

Resolve which commands to run, in this precedence:

1. **Config** — the `verify:` block in `.yunxing/config.local.yaml` at the repo
   root (read it via the repo-root resolution pattern; see this repo's authoring
   guidance for the gitignored-config read). It may name `test`, `lint`, `build`
   commands explicitly.
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

## Step 3: Summarize and emit

Compute `summary` (checks dimension) and `verdict_code` per the contract, then
emit.

- **default mode** — a short markdown summary: one line per check
  (name → pass/fail/skip), then the overall verdict. Keep it ASCII-safe.
- **`mode:agent`** — one raw JSON object, no fence. Minimum shape:

```json
{
  "schema_version": 1,
  "status": "complete",
  "verdict_code": "ready | ready_with_fixes | not_ready",
  "summary": {
    "checks_total": 0,
    "checks_passed": 0,
    "checks_failed": 0
  },
  "checks": []
}
```

`verdict_code` is derived deterministically from `summary` per
`references/output-contract.md`. For verify (checks dimension): `checks_failed > 0`
→ `not_ready` (a failed check is a blocking red for a green gate); all pass →
`ready`. verify never emits `ready_with_fixes` — that value is code-review's only.
A failed check keeps `status: complete` (the run finished; the result is just red).
Use `status: degraded` for ambiguous detection or partial runs, `status: skipped`
when nothing was runnable; both carry `"schema_version": 1` and a `reason`.

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
