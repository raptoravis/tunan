# Config Issue Storage

tunan stores project configuration in a **GitHub issue**, not a local file.
This keeps every durable artifact — requirements, plans, solutions, and now
config — in GitHub, so nothing depends on a machine-local config directory.

## The config issue

- **One open issue per repo**, labeled `tunan:config`, titled `[config] tunan settings`.
- Its body's first line is the marker `<!-- tunan:config -->`.
- The settings live in a fenced ```yaml block in the body. Keys match the
  documented config schema (see `references/config-template.yaml` for the full
  annotated key list).
- Found by label, not by path. There is no local config file and no
  `.gitignore` entry to manage.

Body shape:

````markdown
<!-- tunan:config -->
# tunan settings

Project configuration for the tunan plugin. Edit the YAML block below (or via
`/tunan:setup`). All keys are optional; unset keys fall through to defaults.

```yaml
# work_delegate: codex
# verify:
#   test: ...
# pulse_product_name: "..."
```
````

## Read recipe

Resolve the config issue number, then read its body and parse the yaml block.
Cheap enough to run in a skill preflight.

```bash
gh issue list --label "tunan:config" --state open --json number --jq '.[0].number // empty'
```

If that returns a number `<N>`, read the body and extract the fenced yaml:

```bash
gh issue view <N> --json body --jq .body
```

Parse the ```yaml block from the body with the native tooling already in use
(read the block, treat it as YAML). If no `tunan:config` issue exists, treat it
as "not configured" — fall through to defaults, never error.

## Write / merge recipe

Read the current body, merge the new keys into the yaml block preserving
existing keys, then update the issue body in place from a temp file.

- **Issue exists** → edit in place:

  ```bash
  gh issue edit <N> --body-file <tmpfile>
  ```

- **Issue absent** (first write) → create it:

  ```bash
  gh issue create --title "[config] tunan settings" --label "tunan:config" --body-file <tmpfile>
  ```

Ensure the label exists first (`gh label list --search "tunan:config"`, create
with `gh label create "tunan:config" --color 6f42c1 --description "tunan project config"` if absent).

## Team-shared vs per-machine semantics

A `tunan:config` issue is **shared across the team** — everyone working in the
repo reads the same settings. That is the intended model: project config lives
with the project.

**Safety caveat for consent / sandbox keys.** `work_delegate_consent` and
`work_delegate_sandbox` authorize Codex to run with a yolo / full-auto sandbox.
Stored in a shared issue they are a **team default, not a per-machine
authorization**. Reading `work_delegate_consent: true` from the issue does
**not** mean the current machine has consented. Before delegating to Codex on a
given machine, the running session must still confirm consent for that machine:
interactively, re-prompt once per session when not already acknowledged; in
headless / unattended runs, the per-machine authorization signal is the
`TUNAN_CODEX_CONSENT` env var (set to `1`, `yolo`, or `full-auto`) — a shared
`true` alone never authorizes a headless yolo run. This keeps config fully
issue-stored without auto-applying one developer's yolo consent to a teammate's
machine.

## No local fallback

If `gh` is missing or unauthenticated, config cannot be read — fall through to
defaults and surface the gh setup hint. The same fall-through applies to
**transient** failures (network error, rate limit, timeout): config reads are
best-effort and must never block a skill — degrade to defaults rather than
erroring. Callers that treat config as load-bearing (e.g. `verify` choosing a
test command, `work-beta` reading delegation consent) should be aware that a
transient `gh` failure silently reverts to defaults. Never write or read a local
config file; the issue is the only store.
