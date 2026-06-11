# Progress Marker (resume hint)

An optional `<!-- tunan:progress -->` comment on the feature issue that records
which Implementation Units have landed so far. It exists so `resume` (via
`scripts/phase.*`) can report unit-level progress instead of only the coarse
plan / work / review-ci phase.

**Git stays authoritative for what actually shipped.** This marker is a
convenience pointer refreshed at work batch boundaries, not a source of truth.
If it ever disagrees with git, git wins. Do not gate any decision on it; never
treat a unit as done because the marker says so — treat it as done because its
commit is on the branch.

## When to maintain it

Maintain the marker only when the plan defines U-IDs and `work` is executing
unit-by-unit (serial or parallel subagent strategies, or a multi-unit inline
run). Skip it entirely for trivial / bare-prompt work with no U-IDs — there is
no unit progress to report and the coarse phase is enough.

## Format

Two lines after the marker: a machine line the phase detector parses, then a
human line.

```text
<!-- tunan:progress -->
<!-- progress: done=U1,U2,U3 total=5 -->
**Work progress** — 3 of 5 units landed (U1, U2, U3). Git is authoritative for shipped code; this pointer lets `resume` report unit-level progress and refreshes at each work batch boundary.
```

- `done=` — comma-separated U-IDs landed so far, no spaces (e.g. `U1,U2,U3`).
  Use `done=` with nothing after it when none have landed yet.
- `total=` — count of Implementation Units in the plan.

The phase detector reads only the machine line; keep its shape exact
(`progress: done=<csv> total=<N>`).

## Update recipe

Find the existing progress comment id, then PATCH it in place if present, else
create it. Mirrors the plan-comment chain pattern.

```bash
gh api repos/{owner}/{repo}/issues/<N>/comments --jq '.[] | select(.body | startswith("<!-- tunan:progress -->")) | .id'
```

- **None found** → create it:

  ```bash
  gh issue comment <N> --body-file <tmpfile>
  ```

- **Exists** → update in place by id:

  ```bash
  gh api repos/{owner}/{repo}/issues/comments/<comment-id> -X PATCH -F body=@<tmpfile>
  ```

No label is added for the progress marker — it is found by marker prefix, not
by label, and carries no stage semantics of its own.
