---
name: sync-superpowers
description: "Periodically sync skills from obra/superpowers into tunan — fetch upstream, diff against stored baseline, classify coverage, identify complementary patterns worth absorbing, and create or enhance tunan skills. Use when the user says 'sync superpowers', 'pull from superpowers', 'check superpowers for new skills', 'merge superpowers skill', or wants to run the periodic upstream sync. Default mode: --diff (check what changed) then interactively sync selected skills."
argument-hint: "[skill-name | --audit | --diff]"
---

# Sync Skills from obra/superpowers

Periodic upstream sync: check https://github.com/obra/superpowers for new or changed skills, classify each against tunan's existing coverage, identify complementary patterns worth absorbing, and either create new tunan skills or enhance existing ones with the absorbed techniques. Run this on a recurring cadence — superpowers evolves rapidly (v6.1.1 at time of authoring) and its TDD-first, systematic-debugging, and subagent-driven-development patterns are designed to complement tunan's engineering pipeline.

## What superpowers brings

superpowers is a "complete software development methodology for coding agents" built by Jesse Vincent / Prime Radiant. Its skills enforce a strict workflow: brainstorming → worktree isolation → plan writing → subagent-driven execution with two-stage review → verification → branch completion. Key design traits that differ from tunan:

- **Mandatory gate enforcement.** Every skill has `<HARD-GATE>` blocks that forbid skipping phases. The `using-superpowers` bootstrap skill enforces skill invocation before ANY agent response — even clarifying questions.
- **TDD as law, not guidance.** "Code written before tests → delete it. Start over." No exceptions. The RED-GREEN-REFACTOR cycle is presented as an iron law, not a preference.
- **Anti-rationalization tables.** Skills include explicit "Red Flags — STOP" tables listing the exact rationalizations agents use to bypass process, with rebuttals. This is a meta-cognitive defense pattern tunan doesn't use.
- **Two-stage subagent review.** `subagent-driven-development` runs a spec-compliance reviewer THEN a code-quality reviewer after every task — two independent gates, not one combined review.
- **Zero-context plan writing.** Plans are written "assuming the engineer has zero context for our codebase and questionable taste" — every task includes exact file paths, complete code, and verification steps.
- **Session-start hook injection.** A `SessionStart` hook injects the `using-superpowers` bootstrap into every session, ensuring skills are mandatory from message one.

## Core Loop

```
--diff  →  review changed skills  →  classify  →  decide absorb/enhance/skip  →  execute  →  advance baseline
```

1. **`--diff`**: Compare superpowers `main` HEAD against the stored baseline SHA. List every skill that is new, modified, or deleted since the baseline.
2. **Classify**: For each changed skill, classify against tunan's existing coverage. Unlike mattpocock (which ports skills directly), superpowers skills often overlap with tunan — the value is in absorbing specific patterns, techniques, and behavioral rules INTO existing tunan skills, not creating standalone ports.
3. **Decide**: Present classification; the user picks what to absorb. Options: "Create new tunan skill", "Enhance existing tunan skill with pattern X", "Skip".
4. **Execute**: For "create" → write a new `SKILL.md` following tunan conventions. For "enhance" → read the target tunan skill and merge the complementary patterns into it.
5. **Advance baseline**: Record the new superpowers HEAD SHA so the next `--diff` starts from here.

## Baseline Storage

The sync baseline lives in the `tunan:config` GitHub issue under a `superpowers_sync` key:

```yaml
superpowers_sync:
  last_sha: "abc1234def5678..."
  synced_at: "2026-07-08T12:00:00Z"
  synced_skills:
    - test-driven-development
    - systematic-debugging
```

Resolve the config issue before any read or write:

```bash
gh issue list --label "tunan:config" --state all --json number --jq '.[0].number // empty'
```

If the config issue does not exist, create it. If `gh` is not available or `gh auth status` is non-zero, stop and tell the user — there is no local-file fallback.

## Interaction Method

Use the platform's blocking question tool: `AskUserQuestion` in Claude Code (call `ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded), `request_user_input` in Codex, `ask_user` in Gemini/Pi. Fall back to numbered options in chat only when no blocking tool exists or the call errors.

**Alignment protocol.** Every decision carries at least 3 ranked options with the single best one pre-selected as default (append `(Recommended)`). Load the `align` skill for the full protocol. Ask one question at a time.

## Source of Truth

The authoritative upstream is the `main` branch of `https://github.com/obra/superpowers`. Fetch via GitHub API or raw URLs — never clone the full repo.

Superpowers skills live in a flat `skills/` directory (no subcategories):
- `skills/brainstorming/`
- `skills/dispatching-parallel-agents/`
- `skills/executing-plans/`
- `skills/finishing-a-development-branch/`
- `skills/receiving-code-review/`
- `skills/requesting-code-review/`
- `skills/subagent-driven-development/`
- `skills/systematic-debugging/`
- `skills/test-driven-development/`
- `skills/using-git-worktrees/`
- `skills/using-superpowers/`
- `skills/verification-before-completion/`
- `skills/writing-plans/`
- `skills/writing-skills/`

Additional components (not skills but relevant for absorption):
- `hooks/` — SessionStart hook with bootstrap injection
- `.agents/plugins/` — Agent plugin definitions
- `AGENTS.md` / `CLAUDE.md` — Bootstrap delegation

## Workflow

### Phase 1: Resolve the Target

#### 1a. Get superpowers HEAD SHA

Every mode starts by fetching the current `main` HEAD:

```bash
curl -sL "https://api.github.com/repos/obra/superpowers/git/refs/heads/main" | grep -o '"sha":"[^"]*"' | head -1 | cut -d'"' -f4
```

Store this as `UPSTREAM_SHA`.

#### 1b. Resolve Mode

**`--diff` (default when no arguments):**

Fetch the stored baseline from the config issue. Compare `UPSTREAM_SHA` against `superpowers_sync.last_sha`:

- If `last_sha` is empty: "No baseline recorded yet. Running full audit to establish one."
- If `UPSTREAM_SHA` equals `last_sha`: "Up to date — superpowers hasn't changed since the last sync."
- If different: compute the delta.

**Delta computation:**

```bash
curl -sL "https://api.github.com/repos/obra/superpowers/compare/<last_sha>...<UPSTREAM_SHA>" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for f in (data.get('files') or []):
    if f['filename'].startswith('skills/') and f['filename'].endswith('/SKILL.md'):
        print(f['status'], f['filename'])
"
```

Also check `hooks/`, `.agents/`, and top-level instruction files for changes — these are non-skill components that may contain absorbable patterns.

Parse the output into three lists: **New**, **Modified**, **Deleted**. Present as a compact table then route to Phase 2 classification.

**`--audit`:**

Full inventory — enumerate all skills and classify each:

```bash
curl -sL "https://api.github.com/repos/obra/superpowers/git/trees/main?recursive=1" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for item in data.get('tree', []):
    if item['path'].startswith('skills/') and item['path'].endswith('/SKILL.md'):
        print(item['path'])
"
```

For each, fetch the frontmatter (`name`, `description`). Cross-reference against tunan's existing skill inventory. `--audit` does **not** advance the baseline.

**Single skill (`#$ARGUMENTS` is a name like `test-driven-development`):**

Fetch the SKILL.md directly:

```bash
curl -sL "https://raw.githubusercontent.com/obra/superpowers/main/skills/<skill-name>/SKILL.md"
```

Proceed to Phase 2 classification, then Phase 3 absorption decision, then Phase 4 execution, then Phase 5 baseline advancement.

### Phase 2: Classify Coverage

For each superpowers skill, classify against tunan's existing inventory. Unlike mattpocock sync (which primarily ports standalone skills), superpowers skills often overlap with tunan — the classification focuses on **what patterns to absorb** rather than **whether to port wholesale**.

| Verdict | Criteria | Action |
|---------|----------|--------|
| **Already covered** | A tunan skill fully subsumes it; no novel patterns | Skip; note the covering tunan skill |
| **Already synced** | A tunan skill with the same name exists AND was previously synced from this upstream | Skip, unless `--force` |
| **Pure additive** | No tunan skill covers this territory | Create new tunan SKILL.md |
| **Partial overlap — enhance** | A tunan skill covers some but superpowers has novel techniques, behavioral rules, or workflow patterns worth absorbing | Enhance the existing tunan skill with the complementary patterns |
| **Pattern-only absorption** | The skill's domain is covered but its meta-patterns (anti-rationalization tables, hard gates, red-flag lists) are novel | Absorb the meta-pattern into the relevant tunan skill or AGENTS.md |
| **Out of scope** | superpowers-specific bootstrap, or not applicable to tunan's model | Skip; note reason |

**Established classifications (apply these, don't re-litigate):**

- **test-driven-development** → **Partial overlap — enhance.** tunan covers test-first discipline through `plan` (Execution note signals test-first posture per implementation unit) + `work` (honors Execution notes, writes failing test before implementation for test-first units) + `debug` (test-first fixes). But tunan deliberately avoids RED/GREEN/REFACTOR micro-step expansion (`plan/SKILL.md:580`: "Do not expand units into literal `RED/GREEN/REFACTOR` substeps"). superpowers' TDD skill is a **strict standalone mandatory** cycle with iron laws and anti-rationalization tables — a different shape. The value from superpowers is the behavioral patterns: the Iron Law, the RED-GREEN-REFACTOR cycle diagram, the anti-rationalization table, and the testing anti-patterns reference. **These patterns could either enhance `work`'s test-first execution section** (adding the cycle diagram and anti-rationalization table as references) **or justify a companion standalone TDD skill** for users who want the strict mandatory approach. Decision left to the user at sync time.

- **systematic-debugging** → **Partial overlap — enhance.** tunan's `debug` covers debugging territory but superpowers' 4-phase root cause process (Phase 1: Root Cause Investigation with diagnostic instrumentation, defense-in-depth, condition-based-waiting) is more structured. The "Iron Law: NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST" is a valuable gate. Enhance `plugins/skills/debug/SKILL.md`: add the 4-phase structure, the diagnostic instrumentation pattern for multi-component systems, and the anti-rationalization table. The condition-based-waiting and root-cause-tracing techniques from superpowers' references are worth extracting into tunan `debug/references/`.

- **dispatching-parallel-agents** → **Pure additive.** No tunan equivalent. The decision tree (independent domains → parallel dispatch → review integration) is a useful standalone reference pattern. Create `plugins/skills/dispatching-parallel-agents/SKILL.md`. Keep: the decision flow, the "one agent per problem domain" principle, the integration pattern. Adapt: use tunan's Agent tool conventions, cross-platform subagent dispatch.

- **writing-skills** → **Partial overlap — enhance.** tunan's AGENTS.md "Skill Design Principles" covers skill authoring but superpowers' TDD-for-skills methodology (pressure scenarios with subagents, RED-GREEN-REFACTOR for documentation, baseline-then-skill-then-verify) is novel. Enhance AGENTS.md: add a section on "Testing Skills with Subagent Pressure Scenarios." The TDD mapping table (test case → pressure scenario, production code → SKILL.md) is worth absorbing as a new `references/skill-testing-methodology.md` in a relevant skill or as a standalone reference.

- **verification-before-completion** → **Partial overlap — enhance.** tunan's `verify` handles mechanical verification (run tests/lint/build, emit structured contract). superpowers adds a **behavioral discipline layer**: the "Iron Law: NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE," the anti-rationalization table ("I'm confident" → "Confidence ≠ evidence"), and the gate function (IDENTIFY → RUN → READ → VERIFY → CLAIM). Enhance `plugins/skills/verify/SKILL.md`: add the behavioral framing, the anti-rationalization table, and the gate function as a pre-claim checklist. This complements (not replaces) verify's existing structured output contract.

- **subagent-driven-development** → **Partial overlap — enhance.** tunan's `work` dispatches subagents for task execution but doesn't have superpowers' **two-stage review per task** (spec compliance reviewer THEN code quality reviewer — two independent gates). The "continuous execution without pausing" principle and the progress ledger pattern are also worth absorbing. Enhance `plugins/skills/work/SKILL.md` or `references/`: add the two-stage review pattern as an option for high-ceremony work, and the continuous-execution-with-ledger pattern.

- **writing-plans** → **Partial overlap — enhance.** tunan's `plan` has implementation planning but superpowers' **bite-sized task granularity** (2-5 minutes per step: "Write the failing test" → "Run it to make sure it fails" → "Implement minimal code" → "Run tests" → "Commit"), **file structure mapping** (map out all files before defining tasks), and **"assume zero context"** framing (plan is written for an engineer who knows nothing about the codebase) are stronger. Enhance `plugins/skills/plan/SKILL.md`: absorb the file-structure-mapping step, the 2-5 minute task granularity guidance, and the "zero context" assumption.

- **receiving-code-review** → **Partial overlap — enhance.** tunan's `resolve-pr-feedback` handles PR feedback resolution. superpowers adds **behavioral rules**: "No performative agreement" (never say "You're absolutely right!" / "Great point!"), "Verify before implementing," and the source-specific handling (human partner vs external reviewer). Enhance `plugins/skills/resolve-pr-feedback/SKILL.md`: add the no-performative-agreement rule and the verify-before-implementing gate.

- **brainstorming** → **Already covered** (tunan:brainstorm). superpowers has some patterns worth absorbing: the "This Is Too Simple To Need A Design" anti-pattern rebuttal, the spec self-review checklist (placeholders, contradictions, ambiguity, scope), and the multi-project decomposition flag. These are enhancements to `plugins/skills/brainstorm/SKILL.md`, not a separate skill.

- **executing-plans** → **Already covered** (tunan:work). No novel patterns beyond what subagent-driven-development already contributes.

- **finishing-a-development-branch** → **Already covered** (tunan:merge-pr-verify-close, tunan:commit-push-pr). No novel patterns.

- **requesting-code-review** → **Already covered** (tunan:code-review). The subagent dispatch template is similar to tunan's existing code-review dispatch.

- **using-git-worktrees** → **Already covered** (tunan:worktree). No novel patterns beyond what tunan already handles.

- **using-superpowers** → **Out of scope.** This is the superpowers bootstrap skill — it injects itself at session start and enforces mandatory skill invocation. tunan has no equivalent mechanism (and doesn't need one — tunan skills are opt-in via slash commands or model invocation). The **concept** of a bootstrap skill that enforces process from session start is worth noting as a reference pattern, but not worth porting.

### Phase 3: Absorption Decision

For each non-skip skill, present the absorption strategy. This is the key decision point — the user chooses the approach:

**For Pure Additive skills (create new tunan skill):**

Three options:
1. **Create standalone skill** (Recommended for dispatching-parallel-agents) — full SKILL.md following tunan conventions
2. **Create as beta skill** — use `-beta` suffix and `disable-model-invocation: true` for experimental absorption
3. **Skip for now** — note in the baseline, revisit next sync

**For Partial Overlap skills (enhance existing):**

Four options:
1. **Enhance existing skill inline** (Recommended) — merge the complementary patterns directly into the target tunan skill's SKILL.md
2. **Add as references/** — extract the novel techniques into `references/` files under the target skill
3. **Create companion skill** — when the superpowers approach is different enough to warrant a separate skill (e.g., a parallel "tdd" skill alongside existing workflow skills)
4. **Skip** — the existing tunan coverage is sufficient

### Phase 4: Execute Absorption

#### Creating a new tunan skill (Pure Additive)

Follow the same translation conventions as sync-mattpocock Phase 3, plus superpowers-specific adaptations:

**Frontmatter:**
- `name:` — use the superpowers name as-is (kebab-case), no `tunan-` prefix
- `description:` — tunan-style: what it does AND when to use it. Quote if colons. Max 1024 chars. No bare angle brackets.
- Remove `disable-model-invocation: true` unless deliberately creating a beta skill

**Content translation:**
- **Remove superpowers-specific skill references.** Replace `superpowers:brainstorming` → `` `brainstorm` ``, `superpowers:writing-plans` → `` `plan` ``, etc. Map the full set:
  - `superpowers:brainstorming` → `` `brainstorm` ``
  - `superpowers:writing-plans` → `` `plan` ``
  - `superpowers:subagent-driven-development` → `` `work` ``
  - `superpowers:executing-plans` → `` `work` ``
  - `superpowers:test-driven-development` → `` `test-driven-development` ``
  - `superpowers:systematic-debugging` → `` `debug` ``
  - `superpowers:using-git-worktrees` → `` `worktree` ``
  - `superpowers:finishing-a-development-branch` → `` `merge-pr-verify-close` ``
  - `superpowers:requesting-code-review` → `` `code-review` ``
  - `superpowers:receiving-code-review` → `` `resolve-pr-feedback` ``
  - `superpowers:verification-before-completion` → `` `verify` ``
  - `superpowers:dispatching-parallel-agents` → `` `dispatching-parallel-agents` ``
  - `superpowers:writing-skills` → AGENTS.md Skill Design Principles

- **Preserve superpowers' behavioral patterns that make them effective:**
  - **`<HARD-GATE>` blocks** — keep these; they're load-bearing for enforcement. Adapt the gate content to reference tunan skills.
  - **Anti-rationalization tables** — keep the "Red Flags — STOP" and "Rationalization Prevention" tables. These are the meta-cognitive defense that makes superpowers skills resistant to agent bypass. Add a tunan-specific row if relevant.
  - **Iron Laws** — keep the "NO X WITHOUT Y" formulations. They're memorable and effective.
  - **Process diagrams (dot/graphviz)** — keep these as they help agents visualize the workflow. superpowers uses them extensively.

- **Add cross-platform interaction method.** Standard tunan block: AskUserQuestion + ToolSearch, request_user_input, ask_user. One question at a time.

- **Use GitHub issues for durable artifacts.** superpowers writes design docs to `docs/superpowers/specs/` and plans to `docs/superpowers/plans/`. Adapt to tunan's artifact model: plan marker comments on the feature issue, not local files. For user-owned artifacts (design docs the user wants to keep), local files are acceptable.

- **Match tunan heading depth.** `#` title, `##` major sections, `###` subsections.

- **Script references.** If the superpowers skill references scripts or templates, use backtick paths relative to the skill directory.

#### Enhancing an existing tunan skill (Partial Overlap)

1. **Read the target tunan skill** completely before editing
2. **Identify the insertion point** — where does the superpowers pattern best fit?
   - New `##` section for substantial additions (e.g., a "## Root Cause Investigation" section in debug)
   - New bullet points / sub-sections for smaller enhancements
   - New `references/` file for techniques that are conditional or late-sequence
3. **Merge without breaking existing tunan patterns.** tunan skills follow AGENTS.md conventions — preserve them. The superpowers content should feel like a natural extension, not a transplant.
4. **Update cross-references.** If the enhanced skill references other skills, ensure the references are consistent.
5. **Run compliance checks** (same as Phase 4 in sync-mattpocock)

#### Pattern-only absorption

When the value is a meta-pattern (anti-rationalization tables, hard-gate enforcement, red-flag lists) rather than domain content:

1. Identify which tunan skill(s) would benefit from the pattern
2. Add the pattern to the most appropriate location:
   - Behavioral rules → inline in SKILL.md (they need to be load-bearing)
   - Reference tables → `references/` if they're conditional
   - Cross-cutting patterns → AGENTS.md "Skill Design Principles" if they apply to all skills
3. Document the absorption in the baseline so future syncs don't re-propose it

### Phase 5: Advance Baseline

Same mechanism as sync-mattpocock Phase 5, using the `superpowers_sync` key:

1. Re-read the config issue body
2. Merge the new state:
   ```yaml
   superpowers_sync:
     last_sha: "<UPSTREAM_SHA>"
     synced_at: "<ISO-8601 timestamp>"
     synced_skills:
       - test-driven-development
       - <newly-synced-or-enhanced-skill>
   ```
3. Write back via `gh issue edit`
4. Confirm: "Baseline advanced to `<UPSTREAM_SHA>`. Next `--diff` will compare from this point."

## Non-Skill Components to Monitor

superpowers has components beyond skills that are worth periodically checking for absorbable patterns:

### Hooks (`hooks/`)

The `SessionStart` hook injects the `using-superpowers` bootstrap into every session. tunan doesn't use hooks for skill loading (skills are opt-in via slash commands). **Monitor for:** hook patterns that could improve tunan's setup or session initialization. **Current assessment:** Not applicable — tunan deliberately avoids mandatory skill injection.

### Agent definitions (`.agents/plugins/`)

superpowers ships agent definitions under `.agents/plugins/marketplace.json`. **Monitor for:** new agent types or dispatch patterns that tunan could adopt. **Current assessment:** tunan has a richer agent library (43 agents); no immediate gaps.

### Instruction files (`AGENTS.md` / `CLAUDE.md`)

superpowers' `AGENTS.md` delegates to `CLAUDE.md`, which bootstraps the `using-superpowers` skill. **Monitor for:** instruction patterns that improve tunan's own AGENTS.md or CLAUDE.md. **Current assessment:** The delegation chain (`AGENTS.md` → `CLAUDE.md` → skill invocation) is a pattern tunan already uses.

## Examples

### Default (no args) — periodic check

```
User: /tunan:sync-superpowers
Agent:
  > Upstream: def5678; Baseline: abc1234 (2026-07-01)
  >
  > | Status   | Skill                        | Verdict                | tunan Action          |
  > |----------|------------------------------|------------------------|----------------------|
  > | New      | test-driven-development      | Partial overlap        | Enhance work or create companion |
  > | Modified | systematic-debugging         | Partial overlap        | Enhance tunan:debug   |
  > | Modified | subagent-driven-development  | Partial overlap        | Enhance tunan:work    |
  >
  > 3 skills changed. Which should I sync?
  >
  > AskUserQuestion → [Sync all (Recommended), Pick and choose, Skip for now, Full audit instead]
```

### Single skill — absorb TDD patterns

```
User: /tunan:sync-superpowers test-driven-development
Agent:
  > Fetching obra/superpowers/skills/test-driven-development/SKILL.md...
  > Classification: Partial overlap — tunan's `plan` + `work` + `debug` cover test-first
  > discipline through Execution notes, but tunan deliberately avoids RED/GREEN/REFACTOR
  > micro-step expansion. superpowers' standalone TDD skill has a different shape:
  > strict mandatory cycle with iron laws and anti-rationalization tables.
  >
  > Key patterns worth absorbing:
  >   1. RED-GREEN-REFACTOR cycle diagram
  >   2. Iron Law: NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
  >   3. Anti-rationalization table (8 excuses with rebuttals)
  >   4. Testing anti-patterns reference
  >
  > AskUserQuestion → [Enhance work's test-first section (Recommended), Create companion standalone TDD skill, Skip]
  >
  > [User selects "Enhance work's test-first section"]
  >
  > Reading plugins/skills/work/SKILL.md...
  > Merging patterns into "## Test-first execution" section...
  >   - Added RED-GREEN-REFACTOR cycle diagram as reference
  >   - Added anti-rationalization table
  >   - Added testing anti-patterns cross-reference
  > Enhanced plugins/skills/work/SKILL.md (+35 lines)
  > Baseline advanced to def5678.
```

### Single skill — enhance existing

```
User: /tunan:sync-superpowers systematic-debugging
Agent:
  > Fetching obra/superpowers/skills/systematic-debugging/SKILL.md...
  > Classification: Partial overlap — tunan:debug covers debugging but superpowers'
  > 4-phase root cause process, defense-in-depth, and condition-based-waiting
  > are more structured.
  >
  > Key patterns worth absorbing:
  >   1. 4-phase structure (Root Cause → Reproduce → Fix → Verify)
  >   2. Diagnostic instrumentation for multi-component systems
  >   3. Anti-rationalization table (8 excuses with rebuttals)
  >   4. Iron Law: NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
  >
  > AskUserQuestion → [Enhance tunan:debug inline (Recommended), Add as references/debugging-patterns.md, Create companion skill, Skip]
  >
  > [User selects "Enhance inline"]
  >
  > Reading plugins/skills/debug/SKILL.md...
  > Merging patterns...
  >   - Added "## Phase 1: Root Cause Investigation" section
  >   - Added diagnostic instrumentation pattern
  >   - Added anti-rationalization table
  >   - Added Iron Law gate at top of investigation phase
  > Enhanced plugins/skills/debug/SKILL.md (+47 lines)
  > Baseline advanced to def5678.
```

### Audit (full inventory)

```
User: /tunan:sync-superpowers --audit
Agent:
  > Enumerating all superpowers skills...
  > 14 skills found.
  >
  > | Skill                        | Verdict                | tunan Coverage                    | Action                |
  > |------------------------------|------------------------|-----------------------------------|----------------------|
  > | brainstorming                | Already covered        | tunan:brainstorm                  | Skip (enhance notes) |
  > | dispatching-parallel-agents  | Pure additive          | None                              | Create new skill      |
  > | executing-plans              | Already covered        | tunan:work                        | Skip                  |
  > | finishing-a-dev-branch       | Already covered        | tunan:merge-pr-verify-close       | Skip                  |
  > | receiving-code-review        | Partial overlap        | tunan:resolve-pr-feedback         | Enhance               |
  > | requesting-code-review       | Already covered        | tunan:code-review                 | Skip                  |
  > | subagent-driven-development  | Partial overlap        | tunan:work                        | Enhance               |
  > | systematic-debugging         | Partial overlap        | tunan:debug                       | Enhance               |
  > | test-driven-development      | Partial overlap        | tunan:plan + tunan:work + tunan:debug | Enhance or companion  |
  > | using-git-worktrees          | Already covered        | tunan:worktree                    | Skip                  |
  > | using-superpowers            | Out of scope           | N/A (bootstrap)                   | Skip                  |
  > | verification-before-completion| Partial overlap       | tunan:verify                      | Enhance               |
  > | writing-plans                | Partial overlap        | tunan:plan                        | Enhance               |
  > | writing-skills               | Partial overlap        | AGENTS.md Skill Design Principles | Enhance AGENTS.md     |
  >
  > 1 pure additive, 7 partial overlap, 5 already covered, 1 out of scope.
  > Which should I process?
```

## Differences from sync-mattpocock

This skill follows the same structural pattern as `sync-mattpocock` but differs in these key ways:

| Aspect | sync-mattpocock | sync-superpowers |
|--------|----------------|-----------------|
| **Primary action** | Port skills wholesale | Absorb patterns into existing skills |
| **Overlap handling** | "Already covered" → skip | "Partial overlap" → enhance existing |
| **Content preservation** | Translate container, keep content | Keep behavioral patterns (hard gates, anti-rationalization tables, iron laws) |
| **Skill references** | Map 1:1 to tunan equivalents | Map N:1 (multiple superpowers skills may enhance one tunan skill) |
| **Non-skill components** | Not monitored | Hooks, agents, instruction files monitored for absorbable patterns |
| **New skill creation** | Primary path | Only for pure additive (no tunan equivalent) |
| **Baseline key** | `mattpocock_sync` | `superpowers_sync` |
