# Output Contract (`mode:agent` JSON)

Authoritative definition of the machine-readable contract emitted by `code-review`
and `yunxing:verify` when run with `mode:agent`. Both skills emit the **same
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

`schema_version: 1` is the baseline. `code-review`'s pre-existing JSON is treated
as version `1`; `verify`'s first output is also version `1`.

## Versioning rule

- **Bump `schema_version` (+1)** when any already-published field changes meaning
  or is removed, or an enum drops/redefines a value.
- **Do NOT bump** when adding a new optional field — additive, backward-compatible
  changes keep the same version.

Examples:

- Renaming `summary.actionable` → `summary.actionable_count`, or changing
  `verdict_code` enum values → **bump to 2**.
- Adding an optional `summary.suppressed` count → **stays at 1**.

## Top-level envelope

| Field | Type | Producer | Notes |
|-------|------|----------|-------|
| `schema_version` | integer | both | Structural version. Currently `1`. |
| `status` | enum | both | `complete` \| `failed` \| `degraded` \| `skipped`. |
| `verdict_code` | enum | both | `ready` \| `ready_with_fixes` \| `not_ready`. Derived from `summary` (see below). |
| `verdict` | string | code-review | Human-readable verdict for the default markdown view. Retained, not machine-stable. |
| `summary` | object | both | Counts (see below). |
| `checks[]` | array | verify | Per-check results (see below). |
| `findings[]` / `actionable_findings[]` | array | code-review | Review findings (defined in code-review SKILL.md). |
| `reason` | string | both | One sentence; present on `failed` / `degraded` / `skipped`. |

`status` semantics:

- `complete` — the run finished; `verdict_code` reflects the result (red verdicts
  are still `complete`).
- `failed` — could not complete before producing a verdict.
- `degraded` — completed partially (e.g. some reviewers/checks failed, or command
  detection was ambiguous); do not treat a `degraded` run as authoritative green.
- `skipped` — nothing to do (e.g. no detectable checks, or a skip rule fired).

## `summary` object

```json
{
  "total": 0,
  "actionable": 0,
  "by_severity": { "P0": 0, "P1": 0, "P2": 0, "P3": 0 },
  "checks_total": 0,
  "checks_passed": 0,
  "checks_failed": 0
}
```

- `code-review` populates the findings subset: `total`, `actionable`,
  `by_severity`.
- `verify` populates the checks subset: `checks_total`, `checks_passed`,
  `checks_failed` (it has no `by_severity`).
- Each producer omits the keys that do not apply to it. Key names are fixed and
  carry no skill prefix.

## `verdict_code` derivation (deterministic)

`verdict_code` is a function of `summary`, computed identically by the producer
(when it fills the field) and any consumer that wishes to re-check it:

1. If `by_severity.P0 > 0`, any P1 actionable finding exists, **or**
   `checks_failed > 0` → `not_ready`
2. else if `actionable > 0` → `ready_with_fixes`
3. else → `ready`

Binding the enum to counts removes the "enum is still free agent judgment" noise:
given a `summary`, exactly one `verdict_code` is valid.

This makes `not_ready` reachable for **both** producers: code-review reaches it
via finding severity, and `verify` reaches it via `checks_failed > 0` (a failed
check is a blocking red for a green gate). `ready_with_fixes` is reached only by
code-review (`actionable > 0`); `verify` never emits it, because a failed check is
`not_ready`, not a fixable advisory.

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

## Output rules (both skills, `mode:agent`)

- Emit **one raw JSON object** as the primary response — a bare JSON value with
  **no markdown code fence** (a leading ```` ```json ```` breaks naive
  `JSON.parse` consumers).
- The default (non-`mode:agent`) view stays human-readable markdown; never emit
  this JSON in default mode.
