---
name: sync-ups
description: |
  Merge the latest upstream everyinc/compound-engineering-plugin changes into
  the local tunan skills fork. Use when the user says "sync-ups", "拉上游更新",
  "merge upstream", "sync compound-engineering", "合并上游", "pull upstream into
  tunan", or asks to bring this fork up to date with the upstream
  compound-engineering-plugin. Maintainer-facing: run from the tunan fork repo
  root. Computes the delta since the last synced upstream commit, ports skill
  changes with the tunan branding transform applied, flags dead files (added
  reference/script files no SKILL.md wires in), records the new sync point, and
  stops at unstaged changes for the maintainer to review.
disable-model-invocation: true
allowed-tools: Bash(bash *fetch-upstream-delta.sh), Bash(powershell.exe *fetch-upstream-delta.ps1)
---

# Sync Upstream — merge compound-engineering-plugin into tunan

The local `tunan` plugin is a rebranded fork of
`everyinc/compound-engineering-plugin`. This skill brings the latest upstream
skill changes into the local fork, one merge at a time, preserving every
deliberate local customization and the tunan branding.

Skill changes only. Upstream release chores — version bumps, `CHANGELOG.md`,
`package.json`, the `.release-please-manifest.json`, manifest `version` fields,
and the upstream-specific top-level `README.md` — are never ported; the local
fork manages its own version and README.

## Phase 0: Preconditions

Confirm the working context before touching anything:

1. **This is the tunan fork repo.** `plugins/.claude-plugin/plugin.json` must
   have `"name": "tunan"`. If not, stop and tell the user sync-ups only runs from
   the tunan fork checkout.
2. **Clean-ish tree.** If the working tree has unrelated uncommitted changes,
   warn the user — the merge will add more unstaged changes on top, and they
   should be able to tell them apart. Do not auto-stash.
3. **Determine the sync baseline.** Use a `last_synced_sha` supplied by the
   maintainer (as an argument, or the `UPSTREAM_HEAD` reported by the prior run
   in Phase 6). There is no persisted baseline file — tunan keeps no local
   state. If no baseline SHA is provided, treat the merge as a full audit
   (no baseline diff) and say so.

## Phase 1: Fetch upstream + compute the delta

Run the helper via the Bash tool, picking the variant for the current OS —
PowerShell (`.ps1`) on Windows, bash (`.sh`) on macOS/Linux. Pass the
`last_synced_sha` from Phase 0:

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/fetch-upstream-delta.sh" <last_synced_sha>
```

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_SKILL_DIR}/scripts/fetch-upstream-delta.ps1" <last_synced_sha>
```

The script clones upstream to a scratch dir (never into this repo) and prints:

- `UPSTREAM_HEAD=<sha>` — the upstream `main` HEAD this run targets.
- `UPSTREAM_ROOT=<path>` — read upstream files from here.
- the commit list and skill-scoped `git diff --stat` for `<last_synced_sha>..HEAD`.

Sentinels: `__SYNCUPS_CLONE_FAILED__` (network/clone failed — stop and report),
`__SYNCUPS_LAST_SHA_MISSING__` (baseline SHA absent from upstream history; fall
back to comparing the local skill tree against `UPSTREAM_ROOT` file-by-file).

If `UPSTREAM_HEAD` already equals `last_synced_sha`, the fork is current — report
that and stop.

## Phase 2: Triage the delta

Classify every changed upstream path:

- **Port** — a `SKILL.md`, `references/*`, or `scripts/*` under a
  `ce-<name>/` whose `<name>` maps to an existing local skill (see
  `references/branding-transform.md` for the mapping).
- **Skip (chore)** — version bumps, `CHANGELOG.md`, `package.json`,
  manifests, `.release-please-manifest.json`, top-level upstream `README.md`.
  Note them in the report as skipped; do not apply.
- **New upstream skill** — a `ce-<name>/` with no local counterpart. Do not
  silently port a whole new skill. Surface it to the user as a decision (port
  as a new tunan skill / skip) via the blocking question tool — see
  Interaction below.

Present the triage to the user before editing (short list: port N files, skip M
chores, X new skills) so they see the scope.

## Phase 3: Port each change with the branding transform

For each Port item, read the upstream file at `UPSTREAM_ROOT` and the
corresponding local file, then **semantically merge** — apply the upstream
change while preserving local customizations. Never blind-overwrite a local file
with the upstream version; the local fork has intentional divergences (GitHub
issue-comment storage, the `align` protocol, `cp`/`cpm`/`hotfix`/`tweak`
additions, markdown-only output, Windows/PowerShell parity).

After applying each change, re-apply the tunan branding transform. Load
`references/branding-transform.md` for the full path mapping, token
substitutions, and the residual-token sweep. Run that sweep over every file you
touched — it must come back empty before the port is considered done.

When a ported file has a `-beta` counterpart (or vice versa), apply the
stable/beta sync decision explicitly, per the repo's stable/beta rule.

## Phase 4: Dead-file check (required)

A reference or script file that no `SKILL.md` (directly or transitively through
another loaded reference) names is a **dead file** — it ships but never loads,
so it has no effect. Every newly-added reference/script from this merge must be
checked:

For each added `references/*` or `scripts/*` file, search its basename across
its owning skill directory. If nothing names it, it is dead. A dead file has
three dispositions — choose by whether wiring it in fits the local fork's
design:

1. **Wire it in** — add a backtick-path reference at the point in `SKILL.md`
   where it applies (mirror how upstream wires the same file). Preferred when
   the feature belongs in the fork.
2. **Remove it** — when the file's feature was deliberately removed from the
   fork and wiring it in would re-introduce that feature (e.g. an HTML-output
   reference in a fork that stores artifacts only as markdown GitHub comments).
3. **Keep but don't wire** — only when the maintainer explicitly wants the file
   retained despite being unloaded.

When the right disposition is not obvious — especially when wiring-in would
conflict with a deliberate local design decision — raise it as a blocking
question (see Interaction). Never silently leave a newly-added dead file
unresolved or unreported.

## Phase 5: Validate

- Residual-token sweep (Phase 3) is empty across all changed files.
- No broken markdown link references introduced:
  `grep -E '\[.*\]\(\./references/|\[.*\]\(references/' plugins/skills/*/SKILL.md`
  returns nothing for files you touched.
- Any ported `SKILL.md` still has valid `name`/`description` frontmatter and the
  `name` matches its directory.

## Phase 6: Record, version, report — then STOP

1. **Report the new baseline.** State the synced `UPSTREAM_HEAD` SHA and today's
   date in the summary so the maintainer can record it (and pass it as the
   baseline on the next run). Do not write a local baseline file — there is no
   persisted baseline.
2. **Version + README, only if a skill was added or its surface changed.** A new
   tunan skill: bump the version in BOTH `plugins/.claude-plugin/plugin.json`
   and `plugins/.codex-plugin/plugin.json` (same value, same commit), add the
   skill to the README skill table, and update the skill count. A pure
   reference/SKILL.md content port that adds no new skill still warrants a patch
   bump so installs pick it up.
3. **Report.** Summarize: which files ported, which chores skipped, dead-file
   dispositions, new-skill decisions, and the new sync SHA.
4. **STOP at unstaged changes.** Do not `git add`, commit, or push. The
   maintainer reviews the diff and commits explicitly. (Repo rule: changes wait
   in unstaged/staged state until the user says "commit"/"提交"/"push".)

## Interaction

Every decision point routes through the platform's blocking question tool
(`AskUserQuestion` in Claude Code — load it via `ToolSearch`
`select:AskUserQuestion` first if its schema isn't loaded; `request_user_input`
in Codex; `ask_user` in Gemini/Pi). Use it for: porting a new upstream skill,
and any non-obvious dead-file disposition. Keep to ≤4 options, each label
self-contained, recommended option first. If no blocking tool is available,
present a numbered list in chat and wait — never silently pick.
