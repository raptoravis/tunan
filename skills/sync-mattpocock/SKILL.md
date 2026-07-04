---
name: sync-mattpocock
description: "Periodically sync skills from mattpocock/skills into tunan — fetch upstream, diff against stored baseline, classify coverage, translate format conventions, write adapted SKILL.md files, and advance the baseline. Use when the user says 'sync mattpocock', 'pull updates from mattpocock/skills', 'check for new mattpocock skills', 'merge mattpocock skill', or wants to run the periodic upstream sync. Default mode: --diff (check what changed) then interactively sync selected skills."
argument-hint: "[skill-name | --audit | --diff]"
---

# Sync Skills from mattpocock/skills

Periodic upstream sync: check https://github.com/mattpocock/skills for new or changed skills, classify each against tunan's existing coverage, translate format conventions, write adapted `SKILL.md` files, and advance the stored baseline. Run this on a recurring cadence — it is designed to be the single entry point for keeping tunan in sync with mattpocock's skill catalog.

## Core Loop

The primary workflow is the periodic delta sync:

```
--diff  →  review changed skills  →  sync selected  →  advance baseline
```

1. **`--diff`**: Compare mattpocock `main` HEAD against the stored baseline SHA. List every skill that is new, modified, or deleted since the baseline.
2. **Review**: Present the delta. The user picks which skills to sync.
3. **Sync**: For each selected skill, classify → translate → write → README update.
4. **Advance baseline**: Record the new mattpocock HEAD SHA so the next `--diff` starts from here.

A single-skill sync (`#$ARGUMENTS` is a name) also advances the baseline for that skill's category — it records which commit was current when the skill was synced. Bulk `--audit` does not advance the baseline (it's a discovery tool, not a sync action).

## Baseline Storage

The sync baseline lives in the `tunan:config` GitHub issue under a `mattpocock_sync` key. It is the **authoritative record** of the last synced state — stored in the issue store alongside other project config. Never store it in a local file.

```yaml
mattpocock_sync:
  last_sha: "abc1234def5678..."
  synced_at: "2026-06-30T12:00:00Z"
  synced_skills:
    - grill-me
    - loop-me
```

Resolve the config issue before any read or write:

```bash
gh issue list --label "tunan:config" --state all --json number --jq '.[0].number // empty'
```

If the config issue does not exist, create it — the baseline is load-bearing for periodic sync and a missing config is a blocker, not a skip:

```bash
gh issue create --title "[config] tunan settings" --label "tunan:config" --body '```yaml
mattpocock_sync:
  last_sha: ""
  synced_at: ""
  synced_skills: []
```'
```

If `gh` is not available or `gh auth status` is non-zero, stop and tell the user to install/authenticate — the baseline requires GitHub storage and there is no local-file fallback.

## Interaction Method

Use the platform's blocking question tool for classification and selection decisions: `AskUserQuestion` in Claude Code (call `ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded), `request_user_input` in Codex, `ask_user` in Gemini/Pi. Fall back to numbered options in chat only when no blocking tool exists or the call errors.

**Alignment protocol.** Every decision carries at least 3 ranked options with the single best one pre-selected as default (append `(Recommended)`). Load the `align` skill for the full protocol. Ask one question at a time.

## Source of Truth

The authoritative upstream is the `main` branch of `https://github.com/mattpocock/skills`. Fetch via GitHub API or raw URLs — never clone the full repo.

Skill categories in mattpocock's tree:
- `skills/engineering/` — to-issues, to-prd, implement, tdd, domain-modeling, diagnosing-bugs, codebase-design, etc.
- `skills/productivity/` — grill-me, grilling, handoff, teach, writing-great-skills, etc.
- `skills/in-progress/` — loop-me, review, wizard, writing-beats, etc.
- `skills/misc/` — git-guardrails, setup-pre-commit, scaffold-exercises, etc.
- `skills/personal/` — edit-article, obsidian-vault (**always skip** — personal to Matt)
- `skills/deprecated/` — design-an-interface, qa, ubiquitous-language (**always skip**)

## Workflow

### Phase 1: Resolve the Target

#### 1a. Get mattpocock HEAD SHA

Every mode starts by fetching the current `main` HEAD:

```bash
curl -sL "https://api.github.com/repos/mattpocock/skills/git/refs/heads/main" | grep -o '"sha":"[^"]*"' | head -1 | cut -d'"' -f4
```

Store this as `UPSTREAM_SHA`. It is needed for: `--diff` comparison, single-skill baseline advancement, and verifying the fetched skill is from the recorded commit.

#### 1b. Resolve Mode

**`--diff` (default when no arguments):**

Fetch the stored baseline from the config issue. Compare `UPSTREAM_SHA` against `mattpocock_sync.last_sha`:

- If `last_sha` is empty: "No baseline recorded yet. Running full audit to establish one, then next `--diff` will show only changes."
- If `UPSTREAM_SHA` equals `last_sha`: "Up to date — mattpocock/skills hasn't changed since the last sync."
- If different: compute the delta.

**Delta computation — changed skills since baseline:**

```bash
curl -sL "https://api.github.com/repos/mattpocock/skills/compare/<last_sha>...<UPSTREAM_SHA>" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for f in (data.get('files') or []):
    if f['filename'].startswith('skills/') and f['filename'].endswith('/SKILL.md'):
        print(f['status'], f['filename'])
"
```

Parse the output into three lists:
- **New** (`status: added`) — skill didn't exist at baseline
- **Modified** (`status: modified` / `renamed`) — SKILL.md content changed
- **Deleted** (`status: removed`) — skill was removed upstream

Skip `skills/personal/` and `skills/deprecated/` automatically. Present the delta as a compact table:

```
Upstream: abc1234 (baseline) → def5678 (current)

| Status   | Skill              | Category     |
|----------|--------------------|--------------|
| New      | writing-beats      | in-progress  |
| Modified | grill-me           | productivity |
| Deleted  | qa                 | deprecated   |
```

Then route to Phase 2 classification for each non-deleted skill.

**`--audit`:**

Full inventory — enumerate all skills across all categories and classify each. Use the GitHub API tree endpoint for the `skills/` directory to get the full directory listing without cloning. Skip `skills/personal/` and `skills/deprecated/`.

```
/api/repos/mattpocock/skills/git/trees/main?recursive=1
```

Filter paths matching `skills/<category>/<skill-name>/SKILL.md`. For each, fetch the frontmatter (`name`, `description`). Cross-reference against tunan's existing skill inventory: list `plugins/skills/*/SKILL.md` and parse their `name:` frontmatter.

Present the full classification table (Phase 2), then route per-skill decisions. `--audit` does **not** advance the baseline — it's discovery, not sync.

**Single skill (`#$ARGUMENTS` is a name like `grill-me`):**

Map the name to its category by probing each category path:

```bash
for cat in engineering productivity in-progress misc; do
  code=$(curl -sI -o /dev/null -w "%{http_code}" "https://raw.githubusercontent.com/mattpocock/skills/main/skills/$cat/<skill-name>/SKILL.md")
  if [ "$code" = "200" ]; then echo "$cat"; break; fi
done
```

Fetch the SKILL.md:

```bash
curl -sL "https://raw.githubusercontent.com/mattpocock/skills/main/skills/<category>/<skill-name>/SKILL.md"
```

Proceed to Phase 2 classification, then Phase 3 translation, then Phase 4 write, then Phase 5 baseline advancement (record `UPSTREAM_SHA` as the new baseline for this skill).

### Phase 2: Classify Coverage

For each mattpocock skill, classify against tunan's existing inventory:

| Verdict | Criteria | Action |
|---------|----------|--------|
| **Already covered** | A tunan skill fully subsumes it | Skip; note the covering tunan skill |
| **Already synced** | A tunan skill with the same name exists AND was previously synced from this upstream | Skip, unless `--force`; note the tunan skill |
| **Pure additive** | No tunan skill covers this territory | Translate → create SKILL.md |
| **Partial overlap** | A tunan skill covers some but not all, OR a novel interaction pattern is worth absorbing | Surface for user decision |
| **Out of scope** | Personal to Matt, deprecated, or not applicable | Skip; note reason |

Agent judgment for classification — not keyword matching. Consider:
- What problem does the mattpocock skill solve?
- Which tunan skill (if any) solves the same problem?
- Is the mattpocock approach novel enough to warrant a separate skill despite overlap?

**Established classifications (from prior syncs — apply these, don't re-litigate):**
- `grill-me` / `grilling` → **Already synced** (tunan:grill-me, tunan:grill-me absorbed grilling)
- `loop-me` → **Already synced** (tunan:loop-me)
- `to-prd` → **Partial overlap** (tunan:brainstorm covers requirements synthesis; to-prd's non-interactive mode + Testing Decisions section are the delta — enhance brainstorm references, don't create a standalone)
- `to-issues` → **Already covered** (tunan:plan Implementation Units + vertical-slice philosophy)
- `handoff` → **Already covered** (tunan:handoff — different implementation, same purpose)
- `teach` → **Pure additive** (no tunan equivalent)
- `implement` / `prototype` → **Already covered** (tunan:work)
- `diagnosing-bugs` → **Already covered** (tunan:debug)
- `domain-modeling` → **Pure additive** (no tunan equivalent)
- `codebase-design` → **Pure additive** (no tunan equivalent)
- `tdd` → **Already covered** (tunan's plan supports test-first posture via Execution note)
- `triage` → **Partial overlap** (tunan:brainstorm + tunan:capture cover parts)
- `ask-matt` → **Out of scope** (personal to Matt)
- `edit-article`, `obsidian-vault` → **Out of scope** (personal)
- `setup-matt-pocock-skills` → **Out of scope** (mattpocock setup — not applicable to tunan)
- `writing-great-skills` → **Partial overlap** (tunan AGENTS.md "Skill Design Principles" covers similar ground)
- `writing-beats`, `writing-fragments`, `writing-shape` → **Pure additive** (writing workflow helpers, no tunan equivalent)
- `wizard` → **Pure additive** (guided setup wizard, no tunan equivalent)
- `review` → **Partial overlap** (tunan:code-review covers engineering review; mattpocock's review skill may have a different shape)
- `decision-mapping` → **Pure additive** (no tunan equivalent)
- `improve-codebase-architecture` → **Already covered** (tunan:plan + tunan:code-review with architecture reviewer)
- `resolving-merge-conflicts` → **Already covered** (tunan handles merge conflicts through git integration implicitly)
- `scaffold-exercises` → **Out of scope** (Matt's course-specific tooling)
- `git-guardrails-claude-code` → **Partial overlap** (tunan's CLAUDE.md git-commit-push discipline covers similar territory)
- `setup-pre-commit` → **Out of scope** (generic setup, not a tunan concern)
- `migrate-to-shoehorn` → **Out of scope** (Matt-specific migration tool)

### Phase 3: Translate Format

When creating or adapting a skill:

#### Frontmatter

- `name:` — use the mattpocock name as-is (kebab-case), no `tunan-` prefix
- `description:` — write a tunan-style description: **what it does AND when to use it**, include trigger phrases. Quote if it contains colons. Max 1024 chars. No bare angle brackets (`<tag>`).
- `argument-hint:` — adapt from mattpocock's `argument-hint:` if present; drop references to mattpocock-specific setup
- Remove `disable-model-invocation: true` — tunan skills can be model-invoked (exception: beta skills use it deliberately)

#### Content

- **Remove mattpocock-specific setup references.** Replace `run \`/setup-matt-pocock-skills\` if not` or drop the line.
- **Add cross-platform interaction method.** Standard tunan block: AskUserQuestion + ToolSearch, request_user_input, ask_user. One question at a time. Alignment protocol.
- **Use GitHub issues for durable artifacts.** If the original writes local files (`workflows/*.md`, `NOTES.md`), adapt to GitHub issues with a `tunan:*` label. Local files are fine only as transient scratch or user-owned raw notes.
- **Use semantic skill references.** Backtick names (`` `grill-me` ``), not slash syntax (`/grill-me`).
- **Keep the original's core concepts and vocabulary.** These are the value — translate the container, not the content.
- **Preserve anti-patterns and examples.** Good/bad question examples teach the agent better than abstract principles.
- **Match tunan heading depth.** `#` title, `##` major sections, `###` subsections.

#### README

After creating a skill:
1. Add it to the appropriate category table in `plugins/README.md`
2. Update the skill count
3. Match existing row format (backtick-wrapped name, pipe-aligned description)

### Phase 4: Write and Verify

1. Create `plugins/skills/<name>/SKILL.md` with the translated content
2. Run compliance checks:
   ```bash
   grep -E '\[.*\]\(\./references/|\[.*\]\(references/' plugins/skills/<name>/SKILL.md   # must return nothing
   ```
   ```bash
   # Verify the description field (frontmatter only) has no bare angle brackets:
   grep -E '^description:' plugins/skills/<name>/SKILL.md | grep -o '<[^>]*>'   # must return nothing
   ```
3. Verify `name:` in frontmatter matches directory name
4. Update `plugins/README.md`

### Phase 5: Advance Baseline

**This phase runs after every successful sync** — single-skill, multi-skill from `--diff`, or bulk sync from `--audit` selections. The baseline is the anchor that makes the next `--diff` work. Skipping it silently breaks the periodic sync loop.

1. Re-read the config issue body:
   ```bash
   gh issue view <config-N> --json body --jq .body
   ```
2. Merge the new state into the `mattpocock_sync` key:
   ```yaml
   mattpocock_sync:
     last_sha: "<UPSTREAM_SHA>"          # the mattpocock HEAD at sync time
     synced_at: "<ISO-8601 timestamp>"    # now
     synced_skills:                       # union of previous list + newly synced names
       - grill-me
       - loop-me
       - <newly-synced-skill>
   ```
3. Write back:
   ```bash
   gh issue edit <config-N> --body-file <tmpfile>
   ```
4. Confirm: "Baseline advanced to `<UPSTREAM_SHA>` (short: `<first-7-chars>`). Next `--diff` will compare from this point."

If `gh` fails during baseline write, report the error and the intended new SHA — the user can record it manually. Never silently skip baseline advancement.

## Examples

### Default (no args) — periodic check

```
User: /tunan:sync-mattpocock
Agent:
  > Upstream: def5678; Baseline: abc1234 (2026-06-30)
  >
  > | Status   | Skill              | Category     |
  > |----------|--------------------|--------------|
  > | New      | writing-beats      | in-progress  |
  > | Modified | grill-me           | productivity |
  >
  > 2 skills changed. Which should I sync?
  >
  > AskUserQuestion → [Sync all (Recommended), Sync selected, Skip for now, Full audit instead]
```

### Single skill

```
User: /tunan:sync-mattpocock teach
Agent:
  > Fetching mattpocock/skills/productivity/teach/SKILL.md...
  > Classification: Pure additive — no tunan equivalent.
  > Translating... Created plugins/skills/teach/SKILL.md
  > Updated README (count 44 → 45)
  > Baseline advanced to def5678.
```

### Audit (full inventory)

```
User: /tunan:sync-mattpocock --audit
Agent:
  > Enumerating all mattpocock skills across engineering, productivity, in-progress, misc...
  > 23 skills found (6 personal/deprecated skipped).
  >
  > | Skill                  | Category     | Verdict         | tunan Coverage              |
  > |------------------------|-------------|-----------------|----------------------------|
  > | codebase-design        | engineering | Pure additive   | None                        |
  > | domain-modeling        | engineering | Pure additive   | None                        |
  > | grill-me               | productivity| Already synced  | tunan:grill-me              |
  > | teach                  | productivity| Pure additive   | None                        |
  > | to-prd                 | engineering | Partial overlap | tunan:brainstorm            |
  > | writing-beats          | in-progress | Pure additive   | None                        |
  > | ...                    | ...         | ...             | ...                         |
  >
  > 5 pure additive, 3 partial overlap. Which should I sync?
```
