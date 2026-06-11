---
name: sync-gsd
description: |
  Audit the upstream open-gsd/gsd-core project for new capabilities worth
  absorbing into the local tunan skills, and absorb the ones the maintainer
  picks. Use when the user says "sync-gsd", "拉 GSD 更新", "absorb GSD", "同步
  gsd", "审计 gsd-core", or asks to bring the latest GSD-core capabilities into
  tunan. Maintainer-facing: run from the tunan repo root. tunan is NOT a fork of
  GSD — this is a capability audit, not a file port: it computes the delta since
  the last-absorbed GSD commit, classifies changes into capabilities, surfaces
  each for a keep/skip decision, ports accepted ones into tunan's own skill
  shapes, records the new audit baseline, and stops at unstaged changes.
disable-model-invocation: true
allowed-tools: Bash(bash *fetch-gsd-delta.sh), Bash(powershell.exe *fetch-gsd-delta.ps1)
---

# Sync GSD — audit open-gsd/gsd-core for capabilities to absorb

`tunan` borrows *capabilities* from `open-gsd/gsd-core` but is not a fork of it.
GSD is a separately-built TypeScript multi-runtime project; tunan re-expresses
the borrowed idea in its own issue-state, skill-based shapes. So this skill is a
**capability audit**, not a mechanical port:

- There is **no path mapping** and **no branding transform** (unlike `sync-ups`).
  A GSD file is never copied into tunan as-is.
- The unit of work is a *capability*, not a file. The question for each delta is
  "is there an idea here worth re-expressing in a tunan skill?" — answered by the
  maintainer, not auto-applied.

Load `references/absorbed-capabilities.md` at the start of every run — it records
what tunan has already absorbed (so the audit does not re-surface it) and maps
GSD's source tree to where capabilities live.

## Phase 0: Preconditions

1. **This is the tunan repo.** `plugins/.claude-plugin/plugin.json` must have
   `"name": "tunan"`. If not, stop and tell the user sync-gsd only runs from the
   tunan repo checkout.
2. **Clean-ish tree.** If the working tree has unrelated uncommitted changes,
   warn the user — the audit may add more unstaged changes on top. Do not
   auto-stash.
3. **Determine the audit baseline.** Use a `last_synced_sha` supplied by the
   maintainer (as an argument, or the `GSD_HEAD` reported by a prior run). There
   is no persisted baseline file — tunan keeps no local state. If no
   baseline SHA is provided, treat the audit as a full survey (no baseline diff)
   and say so.

## Phase 1: Fetch GSD + compute the delta

Run the helper via the Bash tool, picking the variant for the current OS —
PowerShell (`.ps1`) on Windows, bash (`.sh`) on macOS/Linux. Pass the
`last_synced_sha` from Phase 0:

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/fetch-gsd-delta.sh" <last_synced_sha>
```

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_SKILL_DIR}/scripts/fetch-gsd-delta.ps1" <last_synced_sha>
```

The script clones GSD's default branch (`next`) to a scratch dir (never into
this repo) and prints:

- `GSD_HEAD=<sha>` — the upstream HEAD this run targets.
- `GSD_ROOT=<path>` — read upstream files from here.
- the commit list for `<last_synced_sha>..HEAD`.
- the changed `.changeset/*.md` paths — **the primary capability index**; each
  changeset is a human-readable description of one shipped change.
- the capability-scoped `git diff --stat` (`gsd-core capabilities agents commands`).

Sentinels: `__SYNCGSD_CLONE_FAILED__` (network/clone failed — stop and report),
`__SYNCGSD_LAST_SHA_MISSING__` (baseline SHA absent from GSD history; fall back
to surveying changesets and capability dirs against `GSD_ROOT` without a diff).

If `GSD_HEAD` already equals `last_synced_sha`, tunan is current on GSD — report
that and stop.

## Phase 2: Triage into capabilities

Read the changed changesets at `GSD_ROOT/.changeset/` first — they name the
capabilities. Group the delta into discrete capabilities (one idea each, not one
file each), and classify every capability:

- **Candidate** — a behavior tunan's issue-state, skill-based model could
  express, not already in `references/absorbed-capabilities.md`.
- **Already absorbed** — listed in `references/absorbed-capabilities.md`; note
  and skip.
- **N/A to tunan** — GSD build/installer/runtime-emission plumbing (`src/`,
  `tests/`, `bin/`, multi-runtime machinery, changeset/release chores) with no
  tunan analog; note as skipped, do not absorb.

Present the triage to the user before absorbing anything: a short list of
candidate capabilities (with the GSD changeset/commit each came from), plus the
counts of already-absorbed and N/A items, so they see the scope.

## Phase 3: Decide per capability (blocking)

For each Candidate, route a keep/skip decision through the blocking question tool
(see Interaction). Do not absorb a capability the maintainer did not pick. For an
accepted capability, name the concrete tunan target — which existing skill it
extends or whether it warrants a new skill — and confirm before writing.

## Phase 4: Absorb accepted capabilities

Re-express each accepted capability in tunan's own shape:

- Port the *idea*, not the GSD file. Match tunan conventions: issue-state config
  (no local config files), the `align` blocking-question protocol, bare skill
  names, Windows/PowerShell script parity, markdown-only artifacts.
- Reuse GSD's wording only where it is genuinely generic; never carry GSD
  branding, slash-command names, or path assumptions into tunan.
- When the capability touches a skill that has a `-beta` counterpart (or vice
  versa), apply the stable/beta sync decision explicitly, per the repo's
  stable/beta rule.

## Phase 5: Record, version, report — then STOP

1. **Update the absorbed list.** Add each absorbed capability to
   `references/absorbed-capabilities.md` (in this same change) so the next audit
   does not re-surface it.
2. **Report the new baseline.** State the audited `GSD_HEAD` SHA and today's date
   in the summary so the maintainer can record it and pass it as the baseline on
   the next run. Do not write a local baseline file.
3. **Version + README, only if a skill was added or its surface changed.** A new
   tunan skill: bump the version in BOTH `plugins/.claude-plugin/plugin.json` and
   `plugins/.codex-plugin/plugin.json` (same value, same commit), add the skill
   to the README skill table, and update the skill count. A capability folded
   into an existing skill still warrants a patch bump so installs pick it up.
4. **Report.** Summarize: which capabilities absorbed (and into which skills),
   which were already-absorbed or N/A, and the new audit SHA.
5. **STOP at unstaged changes.** Do not `git add`, commit, or push. The
   maintainer reviews the diff and commits explicitly. (Repo rule: changes wait
   in unstaged/staged state until the user says "commit"/"提交"/"push".)

## Interaction

Every decision point routes through the platform's blocking question tool
(`AskUserQuestion` in Claude Code — load it via `ToolSearch`
`select:AskUserQuestion` first if its schema isn't loaded; `request_user_input`
in Codex; `ask_user` in Gemini/Pi). Use it for: each candidate capability's
keep/skip decision, and the absorb-target decision (which skill / new skill).
Keep to ≤4 options, each label self-contained, recommended option first. If no
blocking tool is available, present a numbered list in chat and wait — never
silently pick.
