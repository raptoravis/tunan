# Output Contract (`mode:agent` JSON)

Authoritative definition of the machine-readable contract emitted by `code-review`
and `tunan:verify` when run with `mode:agent`. Both skills emit the **same
top-level envelope** so a single consumer (e.g. `lfg`) can read either one the
same way.

> **Authoritative source:** `skills/code-review/references/output-contract.md`;
> `skills/verify/references/output-contract.md` is a byte-identical copy. (This
> note reads correctly from either file.) Both are registered in the
> `plugins/AGENTS.md` "reference file duplicated across skills" list and MUST be
> edited in the same commit. There is no automated check — byte-compare before
> committing:
> `diff plugins/skills/code-review/references/output-contract.md plugins/skills/verify/references/output-contract.md`

## Stability scope (read first)

The producer of this contract is an LLM following markdown instructions, so it is
**non-deterministic**: two runs over the identical input may yield different
`findings`, different counts, or a different `verdict`. `schema_version` versions
the **structure** of the envelope only.

Consumers MAY rely on:

- key presence and types
- the membership of `status` / `verdict_code` enums
- `verdict_code` being derivable from `summary` via the rule below

Consumers MUST NOT rely on:

- exact counts being reproducible run-to-run
- the same diff always producing the same `verdict_code`

`schema_version: 2` is the current version. Version `1` was the original envelope
(findings + checks dimensions only); version `2` adds the **gates dimension**
(`gates[]`, the `gates_*` summary counts, and the `invalid` per-gate verdict) and
folds `gates_failed` into the `verdict_code` derivation rule — a meaning change to
an already-published field, hence the bump (see Versioning rule). A consumer that
only reads findings/checks keys behaves the same against a version-2 payload; the
bump exists because `verdict_code` can now be driven by a third dimension.

## Versioning rule

- **Bump `schema_version` (+1)** when any already-published field changes meaning
  or is removed, or an enum drops/redefines a value.
- **Do NOT bump** when adding a new optional field — additive, backward-compatible
  changes keep the same version.

Examples:

- Renaming `summary.actionable` → `summary.actionable_count`, or changing
  `verdict_code` enum values → **bump**.
- Adding an optional `summary.suppressed` count → **no bump**.
- **v1 → v2 (this change):** `gates[]` and the `gates_*` counts are additive, but
  `verdict_code` now also reads `gates_failed` and a new `invalid` gate verdict can
  drive `status: degraded` — the derivation rule (an already-published behavior)
  changed meaning, so the version was bumped to `2`.

## Top-level envelope

| Field | Type | Producer | Notes |
|-------|------|----------|-------|
| `schema_version` | integer | both | Structural version. Currently `2`. |
| `status` | enum | both | `complete` \| `failed` \| `degraded` \| `skipped`. |
| `verdict_code` | enum | both | `ready` \| `ready_with_fixes` \| `not_ready`. Derived from `summary` (see below). |
| `verdict` | string | code-review | Human-readable verdict for the default markdown view. Retained, not machine-stable. |
| `summary` | object | both | Counts (see below). |
| `checks[]` | array | verify | Per-check results (see below). |
| `gates[]` | array | verify | Per-criterion verdicts against the frozen acceptance gate (see below). Omitted when no gate was found. |
| `findings[]` / `actionable_findings[]` | array | code-review | Review findings (defined in code-review SKILL.md). |
| `reason` | string | both | One sentence; present on `failed` / `degraded` / `skipped`. |

`status` semantics:

- `complete` — the run finished; `verdict_code` reflects the result (red verdicts
  are still `complete`).
- `failed` — could not complete before producing a verdict.
- `degraded` — completed partially (e.g. some reviewers/checks failed, command
  detection was ambiguous, **or one or more acceptance gates could not be measured
  — `invalid` — so the green is not authoritative**); do not treat a `degraded` run
  as authoritative green.
- `skipped` — nothing to do (e.g. no detectable checks, or a skip rule fired).

## `summary` object

```json
{
  "total": 0,
  "actionable": 0,
  "by_severity": { "P0": 0, "P1": 0, "P2": 0, "P3": 0 },
  "checks_total": 0,
  "checks_passed": 0,
  "checks_failed": 0,
  "gates_total": 0,
  "gates_passed": 0,
  "gates_failed": 0,
  "gates_invalid": 0
}
```

- `code-review` populates the findings subset: `total`, `actionable`,
  `by_severity`.
- `verify` populates the checks subset (`checks_total`, `checks_passed`,
  `checks_failed`) and, when a frozen acceptance gate was found, the gates subset
  (`gates_total`, `gates_passed`, `gates_failed`, `gates_invalid`). `verify` has no
  `by_severity`.
- Each producer omits the keys that do not apply to it. A `verify` run with no gate
  omits the `gates_*` keys (and the `gates[]` array). Key names are fixed and carry
  no skill prefix.

## `verdict_code` derivation (deterministic)

`verdict_code` is a function of `summary`, computed identically by the producer
(when it fills the field) and any consumer that wishes to re-check it:

1. If `by_severity.P0 > 0`, any P1 actionable finding exists, `checks_failed > 0`,
   **or `gates_failed > 0`** → `not_ready`
2. else if `actionable > 0` → `ready_with_fixes`
3. else → `ready`

Binding the enum to counts removes the "enum is still free agent judgment" noise:
given a `summary`, exactly one `verdict_code` is valid.

This makes `not_ready` reachable for **both** producers: code-review reaches it
via finding severity, and `verify` reaches it via `checks_failed > 0` **or
`gates_failed > 0`** (a failed check or a failed acceptance gate is a blocking red
for a green gate). `ready_with_fixes` is reached only by code-review
(`actionable > 0`); `verify` never emits it, because a failed check or gate is
`not_ready`, not a fixable advisory.

**`gates_invalid` does not change `verdict_code`** — it is not a red. An
unmeasurable gate (`invalid`) instead forces `status: degraded` (above), which
already signals "not authoritative green" to consumers without claiming the work
failed. A run with all gates `pass`/`invalid` and no `fail` therefore yields
`verdict_code: ready` but `status: degraded` when any gate was `invalid` — the
consumer must check `status`, not `verdict_code` alone, before trusting the green
(the `lfg` gate already maps `degraded` → SOFT).

`verdict` ↔ `verdict_code` mapping (human string ⇄ machine enum):

| `verdict` (human) | `verdict_code` (machine) |
|-------------------|--------------------------|
| Ready to merge | `ready` |
| Ready with fixes | `ready_with_fixes` |
| Not ready | `not_ready` |

## `checks[]` element (verify)

```json
{ "name": "tests", "status": "pass", "messages": [] }
```

- `name` — short check id, e.g. `structure` \| `tests` \| `lint` \| `build` \| `observe`.
- `status` — `pass` \| `fail` \| `skip`.
- `messages[]` — zero or more short strings (failure detail, skip reason).

`duration_ms` is intentionally omitted — an agent-run skill has no precise timing.

## `gates[]` element (verify)

One entry per criterion in the frozen acceptance gate (the `<!-- tunan:gate -->`
comment on the feature issue). The gate is the contract the work was measured
against; `verify` judges each criterion **verbatim** against the actual result and
records an outcome-based verdict.

```json
{ "id": "G1", "status": "pass", "criterion": "`npm test` exits 0", "source": "R1 / U1", "messages": [] }
```

- `id` — the stable gate id from the frozen contract (`G1`, `G2`, …).
- `status` — `pass` \| `fail` \| `invalid`.
  - `pass` — the criterion is met, judged against the verbatim frozen text.
  - `fail` — the criterion is measured and not met (a blocking red; drives
    `gates_failed`, hence `not_ready`).
  - `invalid` — the criterion could not be measured by the checks available this
    run (per the gate's own basis — e.g. an `observe` criterion with no dynamic
    observation run). `invalid` is **not** a failure; it means "unmeasured", drives
    `gates_invalid`, and forces `status: degraded` (non-authoritative green). This
    mirrors the architect-loop INVALID verdict ("unmeasured per gate specification").
- `criterion` — the verbatim criterion text quoted from the frozen gate (not
  restated from memory).
- `source` — the gate's traceability tag back to the plan (e.g. `R1 / U1`).
- `messages[]` — zero or more short strings (evidence for the verdict, or the
  reason a criterion is `invalid`).

## Output rules (both skills, `mode:agent`)

- Emit **one raw JSON object** as the primary response — a bare JSON value with
  **no markdown code fence** (a leading ```` ```json ```` breaks naive
  `JSON.parse` consumers).
- The default (non-`mode:agent`) view stays human-readable markdown; never emit
  this JSON in default mode.
