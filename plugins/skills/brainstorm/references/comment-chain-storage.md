# Comment-Chain Storage Convention (tunan v2)

> **Single source of truth.** This file is duplicated verbatim into every skill that
> reads or writes pipeline artifacts (`brainstorm`, `plan`, `work`, `work-beta`,
> `compound`, `compound-refresh`, `lfg`). When editing one copy, edit all copies in the
> same commit — see the sync list in `plugins/AGENTS.md`. Drift produces inconsistent
> storage behavior depending on which skill ran.

## The model: one feature, one issue

A feature is **one GitHub issue** for its entire lifetime. The issue NUMBER `#N` — the
**feature issue** — is the durable handle passed across the whole pipeline (`brainstorm` →
`plan` → `work` → `compound`). There are **no** separate `tunan:plan` or
`tunan:solution` issues; every stage after the requirement lands as a **comment** on the
feature issue.

| Stage | Where it lives | Marker (first line of the artifact) | Label added to the feature issue |
|---|---|---|---|
| Requirement | issue **body** | — (body, not a comment) | `tunan:req` |
| Plan | a **comment** | `<!-- tunan:plan -->` | `tunan:plan` |
| Solution | a **comment** | `<!-- tunan:solution -->` | `tunan:solution` |

- **Title:** `[req] <topic>`. The title is not re-prefixed per stage; stage progress is
  read from the labels and the marker comments.
- **Labels accumulate** (`tunan:req` → `+tunan:plan` → `+tunan:solution`). They are
  the cheap cross-feature index: `gh issue list --label tunan:solution` still finds every
  feature that has a solution, so institutional-learnings search keeps working without
  scanning comments across the repo.
- **One comment per stage.** A stage edits its existing marker comment in place rather than
  appending a second one. Re-running `plan` updates the plan comment; it never stacks.

## Referencing a stage

Downstream always receives the **feature issue `#N`**. To point at a specific stage, write
`#N` plus the stage name — e.g. `#42 (plan comment)` or the compound id form `#42/plan`,
`#42/solution`. Never invent a separate issue number for a plan or solution.

## Standalone entry (no upstream requirement)

`plan` (and `work` from a bare prompt) can run with no feature issue yet. In that case the
skill **creates the feature issue first** — body = a short requirement stub distilled from
the prompt, label `tunan:req`, title `[req] <topic>` — then writes its stage comment onto
it. This preserves "one feature = one issue": there is never a plan or solution comment
without a host issue.

## gh recipes

`gh api` substitutes `{owner}/{repo}` from the current repo automatically, and the REST
`issues/{N}/comments` endpoint returns plain numeric comment ids — use it (not the GraphQL
`gh issue view --json comments` node ids) so PATCH-by-id is unambiguous.

**Create a stage comment** (the body file's first line is the marker):

```bash
gh issue comment <N> --body-file <file>
```

**Add the stage label** (first time the stage lands on the feature issue):

```bash
gh issue edit <N> --add-label "tunan:plan"
```

**Find an existing stage comment's id** (returns empty if none yet):

```bash
gh api repos/{owner}/{repo}/issues/<N>/comments --jq '.[] | select(.body | startswith("<!-- tunan:plan -->")) | .id'
```

**Read an existing stage comment's body:**

```bash
gh api repos/{owner}/{repo}/issues/<N>/comments --jq '.[] | select(.body | startswith("<!-- tunan:plan -->")) | .body'
```

**Update a stage comment in place** (edit, do not append a second comment):

```bash
gh api repos/{owner}/{repo}/issues/comments/<comment-id> -X PATCH -F body=@<file>
```

**Write-or-update pattern** (the canonical "land my stage" sequence):

1. Resolve the feature issue `#N` (from input ref, an upstream search, or standalone-create).
2. Look up the existing stage comment id with the find recipe above.
3. If none → `gh issue comment <N> --body-file <file>` and `gh issue edit <N> --add-label "<stage-label>"`.
4. If one exists → PATCH it in place by id.

Swap `<!-- tunan:plan -->` / `tunan:plan` for the solution marker / label as needed.

## Notes

- The marker line stays as the literal first line of every stage comment so the find/read
  recipes match on `startswith`. Keep any per-stage `yaml` frontmatter (e.g. a solution's
  trimmed metadata) **after** the marker line.
- A solution comment carries a trimmed ```yaml frontmatter that records `source_issue: #N`
  (the feature issue it lives on) instead of the standalone-issue fields the old model used.
- Never fall back to a local file for any stage. The feature issue is the only durable store.
