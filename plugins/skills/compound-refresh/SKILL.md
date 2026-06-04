---
name: compound-refresh
description: "Refresh stale learning issues labeled yunxing:solution by reviewing them against the current codebase, then updating, consolidating, or closing drifted ones. Use when the user asks to refresh my learnings, audit yunxing:solution issues, clean up stale learnings, or consolidate overlapping learnings, or when compound flags an older learning as superseded. Do not trigger for general refactor, debugging, or code-review work unless the user has explicitly pointed at the yunxing:solution issues."
argument-hint: "[optional: scope hint — directory, filename, module, or keyword] [mode:headless] "
---

# Compound Refresh

Maintain the quality of the project's `yunxing:solution` learning issues over time. This workflow reviews existing learning issues against the current codebase, then refreshes any related learnings that depend on them.

## Storage: yunxing:solution GitHub issues

Learnings are GitHub issues, never local files. Each learning is one issue labeled `yunxing:solution`, titled `[solution] <slug>`, whose body is a fenced ```yaml block (the frontmatter from `references/schema.yaml`) followed by markdown sections. This skill reads, edits, and closes those issues — it never reads or writes any local learning file.

**GH preflight — run before any issue read or write.** If any check fails, abort and surface the guidance; never fall back to a local file.

1. `gh` is installed. If not, install from https://cli.github.com or run `/yunxing:setup`.
2. `gh auth status` exits 0. If not, run `gh auth login` (in Claude Code, suggest typing `! gh auth login`).
3. `gh repo view --json nameWithOwner` resolves. If not, a GitHub repo is required.

**Core gh operations:**

```bash
gh issue list --label "yunxing:solution" --state open --json number,title,url,labels
gh issue view <N> --json title,body,url,labels
gh issue edit <N> --body-file <tmpfile>
gh issue close <N> --comment "<reason>"
```

**Action → gh mapping:**

- **Keep** — no write (optionally `gh issue edit` only if already editing for another reason).
- **Update** — `gh issue edit <N> --body-file <tmpfile>` with the corrected body.
- **Consolidate** — merge unique content into the canonical issue (`gh issue edit`), then close the subsumed issue (`gh issue close <N> --comment "consolidated into #<canonical>"`).
- **Replace** — write the successor body and overwrite the issue body via `gh issue edit <N> --body-file <tmpfile>` (same issue number, fresh content). When evidence is insufficient, mark stale instead (set `status: stale`, `stale_reason`, `stale_date` in the YAML block via `gh issue edit`).
- **Delete** — there is no hard delete; "delete/archive" = `gh issue close <N> --comment "<reason>"`. Git/issue history preserves the body. A reopen (`gh issue reopen <N>`) recovers it if needed.

## Mode Detection

Check if `$ARGUMENTS` contains `mode:headless`. If present, strip it from arguments (use the remainder as a scope hint) and run in **headless mode**.

| Mode | When | Behavior |
|------|------|----------|
| **Interactive** (default) | User is present and can answer questions | Ask for decisions on ambiguous cases, confirm actions |
| **Headless** | `mode:headless` in arguments | No user interaction. Apply all unambiguous actions (Keep, Update, Consolidate, auto-Close, Replace with sufficient evidence). Mark ambiguous cases as stale. Generate a summary report at the end. |

### Headless mode rules

- **Skip all user questions.** Never pause for input.
- **Process all learning issues in scope.** No scope narrowing questions — if no scope hint was provided, process everything.
- **Attempt all safe actions:** Keep (no-op), Update (fix references via `gh issue edit`), Consolidate (merge then close the subsumed issue), auto-Close (unambiguous Delete criteria met → `gh issue close`), Replace (when evidence is sufficient → `gh issue edit` the body). If a write succeeds, record it as **applied**. If a write fails (e.g., gh not authed, permission denied), record the action as **recommended** in the report and continue — do not stop or ask for permissions.
- **Mark as stale when uncertain.** If classification is genuinely ambiguous (Update vs Replace vs Consolidate vs Delete) or Replace evidence is insufficient, mark as stale by setting `status: stale`, `stale_reason`, and `stale_date` in the issue body's YAML block via `gh issue edit`. If even the stale-marking write fails, include it as a recommendation.
- **Use conservative confidence.** In interactive mode, borderline cases get a user question. In headless mode, borderline cases get marked stale. Err toward stale-marking over incorrect action.
- **Always generate a report.** The report is the primary deliverable. It has two sections: **Applied** (actions that were successfully written) and **Recommended** (actions that could not be written, with full rationale so a human can apply them or run the skill interactively). The report structure is the same regardless of what permissions were granted — the only difference is which section each action lands in.

## CONCEPTS.md bootstrap requests

If invoked specifically to create or bootstrap `CONCEPTS.md` (e.g., "create a CONCEPTS.md", "build the concept map", "set up shared vocabulary"), the intent is ambiguous between two jobs — building the vocabulary file and running a refresh of the `yunxing:solution` issues — so disambiguate before proceeding. Use the platform's blocking question tool: `AskUserQuestion` in Claude Code (call `ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded), `request_user_input` in Codex, `ask_user` in Gemini, `ask_user` in Pi (requires the `pi-ask-user` extension). Fall back to numbered options in chat only when no blocking tool exists in the harness or the call errors (e.g., Codex edit modes) — not because a schema load is required. Never silently skip the question. Two options:

1. **Create CONCEPTS.md (build the concept map)** — seed the repo-wide concept map and commit it; skip only the learning-issue classification phases (Phases 0–4). Read `references/concepts-vocabulary.md` and follow its **Seed goal** and **Scope of a seed** (repo-wide) rules: seed the project's core domain nouns from the declared domain model (schema, core types, primary models, top-level domain docs), each meeting the qualifying bar, the codebase setting the count. Write the preamble (see Phase 4.5), cluster per the organization rules, and run the Discoverability Check so `AGENTS.md`/`CLAUDE.md` surface the new file. Then **enter Phase 5 (Commit Changes)** to commit/PR the new `CONCEPTS.md` and any instruction-file edit through the same durable-write flow the refresh uses — do not leave the bootstrap uncommitted. (`CONCEPTS.md` remains a local file; only the learnings moved to issues.)
2. **Run a refresh cycle** — proceed with the normal refresh flow below; `CONCEPTS.md` is seeded (if absent) and reconciled as part of Phase 4.5.

**Alignment protocol.** When asking the sponsor to choose between options, follow the align protocol: offer at least 3 ranked options with the single best one pre-selected as the default — place it first and append `(Recommended)` to its label — so the sponsor lands on the optimal choice by accepting the default. Load the `align` skill for the full protocol. Never hand an open-ended choice back to the sponsor.

In headless mode there is no user to ask: default to the refresh cycle (vocabulary is seeded and reconciled within Phase 4.5 regardless) and note in the report that a standalone repo-wide bootstrap was not run.

## Interaction Principles

**These principles apply to interactive mode only. In headless mode, skip all user questions and apply the headless mode rules above.**

Follow the same interaction style as `brainstorm`:

- Ask questions **one at a time** — use the platform's blocking question tool: `AskUserQuestion` in Claude Code (call `ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded), `request_user_input` in Codex, `ask_user` in Gemini, `ask_user` in Pi (requires the `pi-ask-user` extension). Fall back to numbered options in plain text only when no blocking tool exists in the harness or the call errors (e.g., Codex edit modes) — not because a schema load is required. Never silently skip the question
- Prefer **multiple choice** when natural options exist
- Start with **scope and intent**, then narrow only when needed
- Do **not** ask the user to make decisions before you have evidence
- Lead with a recommendation and explain it briefly

The goal is not to force the user through a checklist. The goal is to help them make a good maintenance decision with the smallest amount of friction.

## Refresh Order

Refresh in this order:

1. Review the relevant individual learning docs first
2. Note which learnings stayed valid, were updated, were consolidated, were replaced, or were deleted
3. Then review any pattern docs that depend on those learnings

Why this order:

- learning docs are the primary evidence
- pattern docs are derived from one or more learnings
- stale learnings can make a pattern look more valid than it really is

If the user starts by naming a pattern doc, you may begin there to understand the concern, but inspect the supporting learning docs before changing the pattern.

## Maintenance Model

For each candidate artifact, classify it into one of five outcomes:

| Outcome | Meaning | Default action |
|---------|---------|----------------|
| **Keep** | Still accurate and still useful | No edit by default; report that it was reviewed and remains trustworthy |
| **Update** | Core solution is still correct, but references drifted | Apply evidence-backed edits to the issue body (`gh issue edit`) |
| **Consolidate** | Two or more issues overlap heavily but are both correct | Merge unique content into the canonical issue, close the subsumed issue |
| **Replace** | The old learning is now misleading, but there is a known better replacement | Overwrite the issue body with a trustworthy successor (`gh issue edit`) |
| **Delete** | No longer useful, applicable, or distinct | Close the issue (`gh issue close`) — issue history preserves it; reopen recovers it |

## Core Rules

1. **Evidence informs judgment.** The signals below are inputs, not a mechanical scorecard. Use engineering judgment to decide whether the artifact is still trustworthy.
2. **Prefer no-write Keep.** Do not update a doc just to leave a review breadcrumb.
3. **Match docs to reality, not the reverse.** When current code differs from a learning, update the learning to reflect the current code. The skill's job is doc accuracy, not code review — do not ask the user whether code changes were "intentional" or "a regression." If the code changed, the doc should match. If the user thinks the code is wrong, that is a separate concern outside this workflow.
4. **Be decisive, minimize questions.** When evidence is clear (file renamed, class moved, reference broken), apply the update. In interactive mode, only ask the user when the right action is genuinely ambiguous. In headless mode, mark ambiguous cases as stale instead of asking. The goal is automated maintenance with human oversight on judgment calls, not a question for every finding.
5. **Avoid low-value churn.** Do not edit a doc just to fix a typo, polish wording, or make cosmetic changes that do not materially improve accuracy or usability.
6. **Use Update only for meaningful, evidence-backed drift.** Paths, module names, related links, category metadata, code snippets, and clearly stale wording are fair game when fixing them materially improves accuracy.
7. **Use Replace only when there is a real replacement.** That means either:
   - the current conversation contains a recently solved, verified replacement fix, or
   - the user has provided enough concrete replacement context to document the successor honestly, or
   - the codebase investigation found the current approach and can document it as the successor, or
   - newer learning issues, PRs, or other issues provide strong successor evidence.
8. **Delete (close) when the code is gone, and only after checking for inbound links.** If the referenced code, controller, or workflow no longer exists in the codebase and no successor can be found, close the issue — don't default to Keep just because the general advice is still "sound." When in doubt between Keep and Delete, ask the user (in interactive mode) or mark as stale (in headless mode). Inbound links inform classification, not cleanup: cleanup is always mechanical, but **decorative** citations (principle stated inline) allow Delete, while **substantive** citations (citing learning relies on the cited learning) signal Replace. The auto-close case is missing code, no matching successor, and citations absent or decorative.
9. **Evaluate document-set design, not just accuracy.** In addition to checking whether each learning is accurate, evaluate whether it is still the right unit of knowledge. If two or more learnings overlap heavily, determine whether they should remain separate, be cross-scoped more clearly, or be consolidated into one canonical learning. Redundant learnings are dangerous because they drift silently — two issues saying the same thing will eventually say different things.
10. **Close, don't archive.** When a learning is no longer useful, close its issue with a comment naming the reason. The closed issue is the archive — reopen recovers it. Do not invent an "archived" label or a local archive directory; closed-issue history already preserves everything. Find recently closed learnings with `gh issue list --label "yunxing:solution" --state closed`.

## Scope Selection

Start by discovering open learning issues after running the GH preflight:

```bash
gh issue list --label "yunxing:solution" --state open --json number,title,url,labels --limit 200
```

**Legacy local learning files:** if pre-migration local learning files exist in the repo, note them in the report as legacy content that should be migrated into `yunxing:solution` issues (or deleted once migrated). Do not treat them as candidates for this workflow; this skill operates only on issues.

If `$ARGUMENTS` is provided, use it to narrow scope before proceeding. Try these matching strategies in order, stopping at the first that produces results:

1. **Issue ref** — if the argument is `#<N>` or a full issue URL, target that issue directly
2. **Category match** — check if the argument matches a `category` slug (e.g., `performance-issues`, `database-issues`) in the YAML blocks; also try it as a label search term: `gh issue list --label "yunxing:solution" --search "<arg>"`
3. **Frontmatter / body match** — search `module`, `component`, or `tags` in issue bodies, or the title slug, for the argument: `gh issue list --label "yunxing:solution" --search "<arg>"`
4. **Content search** — broaden the `--search` keyword (useful for feature names or feature areas)

If no matches are found, report that and ask the user to clarify. In headless mode, when a scope hint was provided but matched nothing, report the miss in the summary and exit without widening to all issues — do not silently fall back to processing everything. (The "process everything" rule from Headless mode rules applies only when **no** scope hint was provided.)

If no candidate learning issues are found, report:

```text
No candidate yunxing:solution issues found.
Run `compound` after solving problems to start building your knowledge base.
```

## Phase 0: Assess and Route

Before asking the user to classify anything:

1. Discover candidate artifacts
2. Estimate scope
3. Choose the lightest interaction path that fits

### Route by Scope

| Scope | When to use it | Interaction style |
|-------|----------------|-------------------|
| **Focused** | 1-2 likely issues or user named a specific learning | Investigate directly, then present a recommendation |
| **Batch** | Up to ~8 mostly independent learning issues | Investigate first, then present grouped recommendations |
| **Broad** | 9+ issues, ambiguous, or repo-wide stale-learning sweep | Triage first, then investigate in batches |

### Broad Scope Triage

When scope is broad (9+ candidate issues), do a lightweight triage before deep investigation:

1. **Inventory** — read the YAML block of all candidate issues (`gh issue view <N> --json body`), group by module/component/category
2. **Impact clustering** — identify areas with the densest clusters of learnings. A cluster of 7 learnings covering the same module is higher-impact than 7 isolated single-issue areas, because staleness in one is likely to affect the others.
3. **Spot-check drift** — for each cluster, check whether the primary referenced files still exist. Missing references in a high-impact cluster = strongest signal for where to start.
4. **Recommend a starting area** — present the highest-impact cluster with a brief rationale and ask the user to confirm or redirect. In headless mode, skip the question and process all clusters in impact order.

Example:

```text
Found 24 learnings across 5 areas.

The auth module has 7 learnings that cross-reference each other (by #N) —
and 3 of those reference files that no longer exist. I'd start there.

1. Start with auth (recommended)
2. Pick a different area
3. Review everything
```

Do not ask action-selection questions yet. First gather evidence.

## Phase 1: Investigate Candidate Learnings

For each learning issue in scope, read its body (`gh issue view <N> --json title,body,url,labels`), cross-reference its claims against the current codebase, and form a recommendation.

A learning has several dimensions that can independently go stale. Surface-level checks catch the obvious drift, but staleness often hides deeper:

- **References** — do the file paths, class names, and modules it mentions still exist or have they moved?
- **Recommended solution** — does the fix still match how the code actually works today? A renamed file with a completely different implementation pattern is not just a path update.
- **Code examples** — if the learning includes code snippets, do they still reflect the current implementation?
- **Related learnings** — are cross-referenced learning issues (`#N`) still open and consistent?
- **Auto memory** (Claude Code only) — does the injected auto-memory block in your system prompt contain entries in the same problem domain? Scan that block directly. If the block is absent, skip this dimension. A memory note describing a different approach than what the learning recommends is a supplementary drift signal.
- **Overlap** — while investigating, note when another issue in scope covers the same problem domain, references the same files, or recommends a similar solution. For each overlap, record: the two issue numbers, which dimensions overlap (problem, solution, root cause, files, prevention), and which issue appears broader or more current. These signals feed Phase 1.75 (Document-Set Analysis).
- **Vocabulary** — note domain terms the learning cites (entities, named processes, status concepts with project-specific meaning). For each term: does it appear in `CONCEPTS.md`? If yes, does the definition still match how the code uses the term? If no, flag the term for Phase 4.5 to add or bootstrap. Do not edit `CONCEPTS.md` during investigation — just collect the signal centrally.

Match investigation depth to the learning's specificity — a learning referencing exact file paths and code snippets needs more verification than one describing a general principle.

### Drift Classification: Update vs Replace

The critical distinction is whether the drift is **cosmetic** (references moved but the solution is the same) or **substantive** (the solution itself changed):

- **Update territory** — file paths moved, classes renamed, links broke, metadata drifted, but the core recommended approach is still how the code works. `compound-refresh` fixes these directly.
- **Replace territory** — the recommended solution conflicts with current code, the architectural approach changed, or the pattern is no longer the preferred way. This means a new learning body needs to be written. A replacement subagent writes the successor following `compound`'s issue-body format (the ```yaml block, problem, root cause, solution, prevention), using the investigation evidence already gathered. The orchestrator then overwrites the same issue's body via `gh issue edit`. The orchestrator does not rewrite learnings inline — it delegates body authoring to a subagent for context isolation.

**The boundary:** if you find yourself rewriting the solution section or changing what the learning recommends, stop — that is Replace, not Update.

**Memory-sourced drift signals** are supplementary, not primary. A memory note describing a different approach does not alone justify Replace or Delete. Use memory signals to:
- Corroborate codebase-sourced drift (strengthens the case for Replace)
- Prompt deeper investigation when codebase evidence is borderline
- Add context to the evidence report ("(auto memory [claude]) notes suggest approach X may have changed since this learning was written")

In headless mode, memory-only drift (no codebase corroboration) should result in stale-marking, not action.

### Judgment Guidelines

Three guidelines that are easy to get wrong:

1. **Contradiction = strong Replace signal.** If the learning's recommendation conflicts with current code patterns or a recently verified fix, that is not a minor drift — the learning is actively misleading. Classify as Replace.
2. **Age alone is not a stale signal.** A 2-year-old learning that still matches current code is fine. Only use age as a prompt to inspect more carefully.
3. **Check for successors before deleting.** Before recommending Replace or Delete, look for newer learning issues, PRs, or other issues covering the same problem space. If successor evidence exists, prefer Replace over Delete so readers are directed to the newer guidance.

## Phase 1.5: Investigate Pattern-Style Learnings

After reviewing the incident-level learning issues, investigate any pattern-style learnings in scope — those whose `category` is `architecture-patterns` or `design-patterns` (or that otherwise generalize a rule across several incidents).

Pattern-style learnings are high-leverage — a stale pattern is more dangerous than a stale individual learning because future work may treat it as broadly applicable guidance. Evaluate whether the generalized rule still holds given the refreshed state of the learnings it depends on.

A pattern-style learning with no clear supporting incident learnings is a stale signal — investigate carefully before keeping it unchanged.

## Phase 1.75: Document-Set Analysis

After investigating individual docs, step back and evaluate the document set as a whole. The goal is to catch problems that only become visible when comparing docs to each other — not just to reality.

### Overlap Detection

For docs that share the same module, component, tags, or problem domain, compare them across these dimensions:

- **Problem statement** — do they describe the same underlying problem?
- **Solution shape** — do they recommend the same approach, even if worded differently?
- **Referenced files** — do they point to the same code paths?
- **Prevention rules** — do they repeat the same prevention bullets?
- **Root cause** — do they identify the same root cause?

High overlap across 3+ dimensions is a strong Consolidate signal. The question to ask: "Would a future maintainer need to read both docs to get the current truth, or is one mostly repeating the other?"

### Supersession Signals

Detect "older narrow precursor, newer canonical doc" patterns:

- A newer doc covers the same files, same workflow, and broader runtime behavior than an older doc
- An older doc describes a specific incident that a newer doc generalizes into a pattern
- Two docs recommend the same fix but the newer one has better context, examples, or scope

When a newer learning clearly subsumes an older one, the older issue is a consolidation candidate — its unique content (if any) should be merged into the newer issue's body, and the older issue should be closed.

### Canonical Doc Identification

For each topic cluster (docs sharing a problem domain), identify which doc is the **canonical source of truth**:

- Usually the most recent, broadest, most accurate doc in the cluster
- The one a maintainer should find first when searching for this topic
- The one that other docs should point to, not duplicate

All other learnings in the cluster are either:
- **Distinct** — they cover a meaningfully different sub-problem and have independent retrieval value. Keep them separate.
- **Subsumed** — their unique content fits as a section in the canonical issue. Consolidate.
- **Redundant** — they add nothing the canonical issue doesn't already say. Delete (close).

### Retrieval-Value Test

Before recommending that two docs stay separate, apply this test: "If a maintainer searched for this topic six months from now, would having these as separate docs improve discoverability, or just create drift risk?"

Separate docs earn their keep only when:
- They cover genuinely different sub-problems that someone might search for independently
- They target different audiences or contexts (e.g., one is about debugging, another about prevention)
- Merging them would create an unwieldy doc that is harder to navigate than two focused ones

If none of these apply, prefer consolidation. Two docs covering the same ground will eventually drift apart and contradict each other — that is worse than a slightly longer single doc.

### Cross-Doc Conflict Check

Look for outright contradictions between docs in scope:
- Doc A says "always use approach X" while Doc B says "avoid approach X"
- Doc A references a file path that Doc B says was deprecated
- Doc A and Doc B describe different root causes for what appears to be the same problem

Contradictions between docs are more urgent than individual staleness — they actively confuse readers. Flag these for immediate resolution, either through Consolidate (if one is right and the other is a stale version of the same truth) or through targeted Update/Replace.

## Subagent Strategy

Use subagents for context isolation when investigating multiple artifacts — not just because the task sounds complex. Choose the lightest approach that fits:

| Approach | When to use |
|----------|-------------|
| **Main thread only** | Small scope, short docs |
| **Sequential subagents** | 1-2 artifacts with many supporting files to read |
| **Parallel subagents** | 3+ truly independent artifacts with low overlap |
| **Batched subagents** | Broad sweeps — narrow scope first, then investigate in batches |

**When spawning any subagent**, omit the `mode` parameter so the user's configured permission settings apply. Include this instruction in its task prompt:

> Use dedicated file search and read tools (Glob, Grep, Read) for all investigation. Do NOT use shell commands (ls, find, cat, grep, test, bash) for file operations. This avoids permission prompts and is more reliable.
>
> Also scan the "user's auto-memory" block injected into your system prompt (Claude Code only). Check for notes related to the learning's problem domain. Report any memory-sourced drift signals separately from codebase-sourced evidence, tagged with "(auto memory [claude])" in the evidence section. If the block is not present in your context, skip this check.

There are two subagent roles:

1. **Investigation subagents** — read-only. They must not edit files, edit issues, create successors, or close anything. Each returns: issue number, evidence, recommended action, confidence, and open questions. The orchestrator passes each subagent the issue body it already fetched (subagents do not call `gh`). These can run in parallel when artifacts are independent.
2. **Replacement subagents** — write a single new learning body to replace a stale one. These run **one at a time, sequentially** (each replacement subagent may need to read significant code, and running multiple in parallel risks context exhaustion). They return body text only; the orchestrator applies it via `gh issue edit` and handles all closes/metadata updates after each replacement completes.

The orchestrator merges investigation results, detects contradictions, coordinates replacement subagents, and performs all `gh` issue edits/closes centrally (subagents never call `gh`). In interactive mode, it asks the user questions on ambiguous cases. In headless mode, it marks ambiguous cases as stale instead. If two artifacts overlap or discuss the same root issue, investigate them together rather than parallelizing.

## Phase 2: Classify the Right Maintenance Action

After gathering evidence, assign one recommended action.

### Keep

The learning is still accurate and useful. Do not edit the issue — report that it was reviewed and remains trustworthy. Only add `last_refreshed` to the YAML block if you are already making a meaningful update for another reason.

### Update

The core solution is still valid but references have drifted (paths, class names, links, code snippets, metadata). Apply the fixes directly via `gh issue edit`.

### Consolidate

Choose **Consolidate** when Phase 1.75 identified learning issues that overlap heavily but are both materially correct. This is different from Update (which fixes drift in a single issue) and Replace (which rewrites misleading guidance). Consolidate handles the "both right, one subsumes the other" case.

**When to consolidate:**

- Two issues describe the same problem and recommend the same (or compatible) solution
- One issue is a narrow precursor and a newer issue covers the same ground more broadly
- The unique content from the subsumed issue can fit as a section or addendum in the canonical issue
- Keeping both creates drift risk without meaningful retrieval benefit

**When NOT to consolidate** (apply the Retrieval-Value Test from Phase 1.75):

- The issues cover genuinely different sub-problems that someone would search for independently
- Merging would create an unwieldy issue that harms navigation more than drift risk harms accuracy

**Consolidate vs Delete:** If the subsumed issue has unique content worth preserving (edge cases, alternative approaches, extra prevention rules), use Consolidate to merge that content first. If the subsumed issue adds nothing the canonical issue doesn't already say, skip straight to Delete.

The Consolidate action is: merge unique content from the subsumed issue into the canonical issue's body (`gh issue edit`), then close the subsumed issue (`gh issue close <N> --comment "consolidated into #<canonical>"`). Not archive — close. Issue history preserves it.

### Replace

Choose **Replace** when the learning's core guidance is now misleading — the recommended fix changed materially, the root cause or architecture shifted, or the preferred pattern is different.

The user may have invoked the refresh months after the original learning was written. Do not ask them for replacement context they are unlikely to have — use agent intelligence to investigate the codebase and synthesize the replacement.

**Evidence assessment:**

By the time you identify a Replace candidate, Phase 1 investigation has already gathered significant evidence: the old learning's claims, what the current code actually does, and where the drift occurred. Assess whether this evidence is sufficient to write a trustworthy replacement:

- **Sufficient evidence** — you understand both what the old learning recommended AND what the current approach is. The investigation found the current code patterns, the new file locations, the changed architecture. → Proceed to write the replacement (see Phase 4 Replace Flow).
- **Insufficient evidence** — the drift is so fundamental that you cannot confidently document the current approach. The entire subsystem was replaced, or the new architecture is too complex to understand from a file scan alone. → Mark as stale in place:
   - Set `status: stale`, `stale_reason: [what you found]`, `stale_date: YYYY-MM-DD` in the issue body's YAML block via `gh issue edit`
   - Report what evidence you found and what is missing
   - Recommend the user run `compound` after their next encounter with that area, when they have fresh problem-solving context

### Delete

Choose **Delete** when:

- The code or workflow no longer exists and the problem domain is gone
- The learning is obsolete and has no modern replacement worth documenting
- The learning is fully redundant with another issue (use Consolidate if there is unique content to merge first)
- There is no meaningful successor evidence suggesting it should be replaced instead

Action: close the issue (`gh issue close <N> --comment "<reason>"`). No archival label, no archive directory — just close it. Issue history preserves the body, and `gh issue reopen <N>` recovers it if needed.

### Before deleting: check if the problem domain is still active

When a learning's referenced files are gone, that is strong evidence — but only that the **implementation** is gone. Before deleting, reason about whether the **problem the learning solves** is still a concern in the codebase:

- A learning about session token storage where `auth_token.rb` is gone — does the application still handle session tokens? If so, the concept persists under a new implementation. That is Replace, not Delete.
- A learning about a deprecated API endpoint where the entire feature was removed — the problem domain is gone. That is Delete.

Do not search mechanically for keywords from the old learning. Instead, understand what problem the learning addresses, then investigate whether that problem domain still exists in the codebase. The agent understands concepts — use that understanding to look for where the problem lives now, not where the old code used to be.

### Before deleting: check for inbound links

A learning that other artifacts cite is load-bearing in a way the learning itself does not announce. Before classifying as Delete, search for citations of the issue:

- Other learning issues referencing it by `#<N>`: `gh issue list --label "yunxing:solution" --search "#<N>"` (also try the title slug as a search term).
- The repo's markdown content (plans, instruction files, READMEs) referencing the issue number or title slug — use the platform's native content-search tool (e.g., Grep in Claude Code). Read context lines around each match (e.g., Grep's `-B`/`-A`), not whole files.

Skip source code, where citations are rare and only appear in comments.

**Inbound links inform the classification, not the cleanup.** Removing a citation is always mechanical (drop the parenthetical, the bare entry, or the deferring clause). The judgment is upstream: given these citations, is Delete still right, or is Replace closer to right?

Classify each citation by what it does in its citing context:

- **Decorative** — principle stated inline, citation is a "see also" pointer or bare attribution. Delete (close) is fine; clean up citations in the same pass.
- **Substantive** — citing artifact relies on the cited learning to provide content not stated inline (e.g., "see #N for details on Y" with no inline Y). Signal Replace — overwrite the same issue's body with a successor, or **Keep with narrowed scope** if the learning's actual content is broader than its title implies.
- **Mixed or unclear** — stale-mark.

In headless mode, Delete (close) + decorative cleanup is fine. Any substantive citation, or any genuine ambiguity, downgrades to stale-marking — writing a Replace successor is judgment-heavy and should not happen unattended.

**Auto-close only when all three hold:**

- The implementation is gone (or fully superseded by a clearly better successor, or the learning is plainly redundant).
- The problem domain is gone — the app no longer deals with what the learning addresses.
- Inbound links are absent or unambiguously decorative.

If any condition fails, classify as Replace, Update, Consolidate, or stale-mark per the rules above. Do not close a learning whose problem domain is still active or whose principles are cited substantively — fill the gap with a replacement instead.

## Pattern Guidance

Apply the same five outcomes (Keep, Update, Consolidate, Replace, Delete) to pattern-style learnings, but evaluate them as **derived guidance** rather than incident-level learnings. Key differences:

- **Keep**: the underlying learnings still support the generalized rule and examples remain representative
- **Update**: the rule holds but examples, links, scope, or supporting references drifted
- **Consolidate**: two pattern-style learnings generalize the same set of incidents or cover the same design concern — merge into one canonical pattern issue
- **Replace**: the generalized rule is now misleading, or the underlying learnings support a different synthesis. Base the replacement on the refreshed learning set — do not invent new rules from guesswork
- **Delete**: the pattern is no longer valid, no longer recurring, or fully subsumed by a stronger pattern-style learning with no unique content remaining

## Phase 3: Ask for Decisions

### Headless mode

**Skip this entire phase. Do not ask any questions. Do not present options. Do not wait for input.** Proceed directly to Phase 4 and execute all actions based on the classifications from Phase 2:

- Unambiguous Keep, Update, Consolidate, auto-Delete, and Replace (with sufficient evidence) → execute directly
- Ambiguous cases → mark as stale
- Then generate the report (see Output Format)

### Interactive mode

Most Updates and Consolidations should be applied directly without asking. Only ask the user when:

- The right action is genuinely ambiguous (Update vs Replace vs Consolidate vs Delete)
- You are about to Delete (close) a learning **and** the evidence is not unambiguous (see auto-close criteria in Phase 2). When auto-close criteria are met, proceed without asking.
- You are about to Consolidate and the choice of canonical issue is not clear-cut
- You are about to create a successor via Replace

Do **not** ask questions about whether code changes were intentional, whether the user wants to fix bugs in the code, or other concerns outside learning maintenance. Stay in your lane — learning accuracy.

#### Question Style

Always present choices using the platform's blocking question tool: `AskUserQuestion` in Claude Code (call `ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded), `request_user_input` in Codex, `ask_user` in Gemini, `ask_user` in Pi (requires the `pi-ask-user` extension). Fall back to numbered options in plain text only when no blocking tool exists in the harness or the call errors (e.g., Codex edit modes) — not because a schema load is required. Never silently skip the question.

Question rules:

- Ask **one question at a time**
- Prefer **multiple choice**
- Lead with the **recommended option**
- Explain the rationale for the recommendation in one concise sentence
- Avoid asking the user to choose from actions that are not actually plausible

#### Focused Scope

For a single artifact, present:

- issue ref (`#<N>` + title)
- 2-4 bullets of evidence
- recommended action

Then ask:

```text
This [learning/pattern] looks like a [Keep/Update/Consolidate/Replace/Delete].

Why: [one-sentence rationale based on the evidence]

What would you like to do?

1. [Recommended action]
2. [Second plausible action]
3. Skip for now
```

Do not list all five actions unless all five are genuinely plausible.

#### Batch Scope

For several learnings:

1. Group obvious **Keep** cases together
2. Group obvious **Update** cases together when the fixes are straightforward
3. Present **Consolidate** cases together when the canonical issue is clear
4. Present **Replace** cases individually or in very small groups
5. Present **Delete** cases individually unless they are strong auto-close candidates

Ask for confirmation in stages:

1. Confirm grouped Keep/Update recommendations
2. Then handle Consolidate groups (present the canonical issue and what gets merged)
3. Then handle Replace one at a time
4. Then handle Delete one at a time unless the close is unambiguous and safe to auto-apply

#### Broad Scope

If the user asked for a sweeping refresh, keep the interaction incremental:

1. Narrow scope first
2. Investigate a manageable batch
3. Present recommendations
4. Ask whether to continue to the next batch

Do not front-load the user with a full maintenance queue.

## Phase 4: Execute the Chosen Action

For each candidate, execute the flow that matches its classification from Phase 2 (confirmed in Phase 3). Read `references/per-action-flows.md` and follow the matching section:

- **Keep** — no issue edit by default; summarize why the learning remains trustworthy.
- **Update** — edit the issue body (`gh issue edit`) when the solution is still substantively correct (path renames, link refreshes, module renames).
- **Consolidate** — merge overlapping issues into a canonical issue, close subsumed issues, update cross-references. The orchestrator handles consolidation directly.
- **Replace** — author a successor body via subagent (passing the documentation contract files), validate the YAML block, then overwrite the same issue's body via `gh issue edit`. When evidence is insufficient, mark stale instead.
- **Delete** — final inbound-link check, then close the issue. Reclassify if late-discovered substantive citations surface.

Only one flow runs per candidate; the reference contains the per-action criteria, examples, and step-by-step instructions.

## Phase 4.5: Vocabulary Capture

After the per-learning actions execute, aggregate the domain terms flagged across Phase 1's Vocabulary dimension and reconcile them with `CONCEPTS.md`.

**First, read `references/concepts-vocabulary.md`.** This is unconditional. Do not pre-judge from memory which Phase 1 signals qualify — the reference's criteria are non-obvious and a "nothing qualifies" judgment without reading is a shortcut, not a result.

**Procedure:**

1. **Aggregate.** Collect qualifying terms surfaced across the learnings in scope, applying the reference's criteria. If the same term surfaced in multiple learnings with different shades of precision, **union the shades into one entry** — not three entries, not most-recent-wins.
2. **If `CONCEPTS.md` exists**, add missing terms and refine existing entries when the corpus surfaced new precision. Do not duplicate entries already present. **Then reconcile the in-scope core nouns:** re-derive the core domain nouns of the area in scope from its declared model (per the **Seed goal** in the reference) and backfill any that are central but missing. This is the every-run safety net for stable-central terms that friction never surfaces — bounded to the area in scope, defining only terms investigated this run, never a repo-wide sweep.
3. **If `CONCEPTS.md` does not exist** and at least one qualifying term was surfaced, **bootstrap it — and seed, don't write a single term.** Alongside the surfaced term(s), seed the core domain nouns of the area in scope per the reference's **Seed goal**, so the file is anchored from creation rather than a lone peripheral entry (and so captured terms don't dangle against undefined siblings). The seed stays scoped to the area in scope — a repo-wide concept map comes only from the explicit bootstrap path above, not from a scoped refresh. **At creation, hold the qualifying bar conservatively for borderline terms** — a borderline term or a class/table/file name dressed up as an entity defers to a later run; clear core nouns are seeded, borderline ones wait. The conservatism is about quality, not count; updates to an existing file follow normal criteria.
4. **Scope discipline and citation hygiene.** Bootstrap, seed, and reconcile reflect only the area in scope — do not expand to other categories, and do not retroactively inject `(see CONCEPTS.md)` pointers into existing learnings. (The repo-wide bootstrap path above is the deliberate exception — it intentionally covers the whole declared model.) The report should note that additional entries are likely from refresh runs on other scopes.
5. **Initial structure.** When bootstrapping, start the file with this preamble under the `# Concepts` heading:

   > Shared domain vocabulary for this project — entities, named processes, and status concepts with project-specific meaning. Seeded with core domain vocabulary, then accretes as compound and compound-refresh process learnings; direct edits are fine. Glossary only, not a spec or catch-all.

   Then add entries. Let term count drive shape: 1-4 terms → flat headings, more → cluster by domain relationship per the rules in `references/concepts-vocabulary.md`.
6. **Scrub violations.** Scan existing entries for content that violates `references/concepts-vocabulary.md` criteria — implementation specifics (file paths, class names, function signatures, code references), current-config values (thresholds, counts, enum values that will drift), status/owner/date metadata, duplicates of terms covered under a different name, or entries that lean on an undefined project-specific sibling (add the sibling or rephrase). Rewrite or consolidate. The full sweep is appropriate here because refresh is an audit; compound's same-named phase scopes corrections to the coherence neighborhood of entries being touched.

If no Phase 1 signals qualified after applying the reference's criteria, record that outcome explicitly in the report's `CONCEPTS.md` line (e.g., "scanned, no qualifying terms"). Do not silently skip — the visible scan-and-no-result record is the audit signal that the reference was consulted.

Note: if this run **creates** `CONCEPTS.md` from scratch, the Discoverability Check below also surfaces it so future agents can discover it — by editing `AGENTS.md`/`CLAUDE.md` in interactive mode (with consent), or, in headless mode, by emitting a "Discoverability recommendation" line in the report rather than editing instruction files (per the headless boundary in step 4c — headless does doc maintenance, not project config). Either way the created file is surfaced or flagged for surfacing; subsequent runs skip this because the instruction file is already current or the recommendation was already reported.

**Apply edits silently — no user prompt in any mode.** Vocabulary capture is a side effect of refreshing, not a decision the user makes per run.

## Output Format

**The full report MUST be printed as markdown output.** Do not summarize findings internally and then output a one-liner. The report is the deliverable — print every section in full, formatted as readable markdown with headers, tables, and bullet points.

After processing the selected scope, output the following report:

```text
Compound Refresh Summary
========================
Scanned: N learnings

Kept: X
Updated: Y
Consolidated: C
Replaced: Z
Deleted: W
Skipped: V
Marked stale: S

CONCEPTS.md: <scanned, no qualifying terms | created with N entries (M seeded) | updated — N added, N refined, N reconciled, N scrubbed | repo-wide map created with N entries>
```

Then for EVERY learning issue processed, list:
- The issue ref (`#<N>` + title)
- The classification (Keep/Update/Consolidate/Replace/Delete/Stale)
- What evidence was found -- tag any memory-sourced findings with "(auto memory [claude])" to distinguish them from codebase-sourced evidence
- What action was taken (or recommended)
- For Consolidate: which issue was canonical, what unique content was merged, which issue was closed

For **Keep** outcomes, list them under a reviewed-without-edits section so the result is visible without creating churn.

### Headless mode report

In headless mode, the report is the sole deliverable — there is no user present to ask follow-up questions, so the report must be self-contained and complete. **Print the full report. Do not abbreviate, summarize, or skip sections.**

Split actions into two sections:

**Applied** (writes that succeeded):
- For each **Updated** issue: the issue ref, what references were fixed, and why
- For each **Consolidated** cluster: the canonical issue, what unique content was merged from each subsumed issue, and the subsumed issues that were closed
- For each **Replaced** issue: what the old learning recommended vs what the current code does, and the issue ref whose body was overwritten
- For each **Deleted** issue: the issue ref and why it was closed (problem domain gone, fully redundant, etc.)
- For each **Marked stale** issue: the issue ref, what evidence was found, and why it was ambiguous

**Recommended** (actions that could not be written — e.g., gh not authed, permission denied):
- Same detail as above, but framed as recommendations for a human to apply
- Include enough context that the user can apply the change manually or re-run the skill interactively

If all writes succeed, the Recommended section is empty. If no writes succeed (e.g., gh unavailable), all actions appear under Recommended — the report becomes a maintenance plan.

**Legacy cleanup** (if pre-migration local learning files exist in the repo):
- Note them as pre-migration content and recommend migrating each into a `yunxing:solution` issue (or deleting once migrated). This skill does not process local files.

## Phase 5: Commit Changes

The learning maintenance itself (Update/Consolidate/Replace/Delete) happens on GitHub issues via `gh` and needs no git commit. This phase commits only the **local files** this run may have modified: `CONCEPTS.md` and any instruction-file (`AGENTS.md`/`CLAUDE.md`) discoverability edit. Skip this phase if no local files were modified (e.g., only issue edits occurred, all Keep, or all writes failed).

### Detect git context

Before offering options, check:
1. Which branch is currently checked out (main/master vs feature branch)
2. Whether the working tree has other uncommitted changes beyond what compound-refresh modified
3. Recent commit messages to match the repo's commit style

### Headless mode

Use sensible defaults — no user to ask:

| Context | Default action |
|---------|---------------|
| On main/master | Create a branch named for what was refreshed (e.g., `refresh/auth-and-ci-learnings`), commit, attempt to open a PR. If PR creation fails, report the branch name. |
| On a feature branch | Commit as a separate commit on the current branch |
| Git operations fail | Include the recommended git commands in the report and continue |

Stage only the files that compound-refresh modified — not other dirty files in the working tree.

### Interactive mode

First, run `git branch --show-current` to determine the current branch. Then present the correct options based on the result. Stage only compound-refresh files regardless of which option the user picks.

**If the current branch is main, master, or the repo's default branch:**

1. Create a branch, commit, and open a PR (recommended) — the branch name should be specific to what was refreshed, not generic (e.g., `refresh/auth-learnings` not `refresh/compound-refresh`)
2. Commit directly to `{current branch name}`
3. Don't commit — I'll handle it

**If the current branch is a feature branch, clean working tree:**

1. Commit to `{current branch name}` as a separate commit (recommended)
2. Create a separate branch and commit
3. Don't commit

**If the current branch is a feature branch, dirty working tree (other uncommitted changes):**

1. Commit only the compound-refresh changes to `{current branch name}` (selective staging — other dirty files stay untouched)
2. Don't commit

### Commit message

Write a descriptive commit message that:
- Summarizes the local changes committed (e.g., "add 2 CONCEPTS.md entries; surface yunxing:solution issues in AGENTS.md") and references the issue maintenance done this run (e.g., "refreshed 6 yunxing:solution issues")
- Follows the repo's existing commit conventions (check recent git log for style)
- Is succinct — the issue-side details live in the report and the issues themselves

## Relationship to compound

- `compound` captures a newly solved, verified problem as a `yunxing:solution` issue
- `compound-refresh` maintains older learning issues as the codebase evolves — both their individual accuracy and their collective design as a knowledge set

Use **Replace** only when the refresh process has enough real evidence to write a trustworthy successor. When evidence is insufficient, mark as stale and recommend `compound` for when the user next encounters that problem area.

Use **Consolidate** proactively when the learning set has grown organically and redundancy has crept in. Every `compound` invocation adds a new issue — over time, multiple issues may cover the same problem from slightly different angles. Periodic consolidation keeps the learning set lean and authoritative.

## Discoverability Check

After the refresh report is generated, check whether the project's instruction files would lead an agent to discover and search the project's `yunxing:solution` GitHub issues before starting work in a documented area. This runs every time — the knowledge store only compounds value when agents can find it. If this check produces edits, they are committed as part of (or immediately after) the Phase 5 commit flow — see step 6 below.

1. Identify which root-level instruction files exist (AGENTS.md, CLAUDE.md, or both). Read the file(s) and determine which holds the substantive content — one file may just be a shim that `@`-includes the other (e.g., `CLAUDE.md` containing only `@AGENTS.md`, or vice versa). The substantive file is the assessment and edit target; ignore shims. If neither file exists, skip this check entirely.
2. Assess whether an agent reading the instruction files would learn three things:
   - That a searchable knowledge store of documented solutions exists as GitHub issues labeled `yunxing:solution`
   - Enough about its structure to search effectively (the label, and the YAML fields like `category`, `module`, `tags`, `problem_type` in each issue body)
   - When to search it (before implementing features, debugging issues, or making decisions in documented areas — learnings may cover bugs, best practices, workflow patterns, or other institutional knowledge)

   This is a semantic assessment, not a string match. The information could be a line in an architecture section, a bullet in a gotchas section, spread across multiple places, or expressed without ever using the exact label `yunxing:solution`. Use judgment — if an agent would reasonably discover and use the knowledge store after reading the file, the check passes.

3. If the spirit is already met, no action needed.
4. If not:
   a. Based on the file's existing structure, tone, and density, identify where a mention fits naturally. Before creating a new section, check whether the information could be a single line in the closest related section — an architecture overview, a conventions block, or a documentation section. A line added to an existing section is almost always better than a new headed section. Only add a new section as a last resort when the file has clear sectioned structure and nothing is even remotely related.
   b. Draft the smallest addition that communicates the three things. Match the file's existing style and density. The addition should describe the knowledge store itself, not the plugin.

      Keep the tone informational, not imperative. Express timing as description, not instruction — "relevant when implementing or debugging in documented areas" rather than "check before implementing or debugging." Imperative directives like "always search before implementing" cause redundant reads when a workflow already includes a dedicated search step. The goal is awareness: agents learn the issue store exists and what's in it, then use their own judgment about when to consult it.

      Examples of calibration (not templates — adapt to the file):

      When there's an existing conventions or architecture section — add a line:
      ```
      Solved-problem learnings live as GitHub issues labeled `yunxing:solution` (bugs, best practices, workflow patterns), each with a YAML block carrying category, module, tags, problem_type — search with `gh issue list --label "yunxing:solution" --search "<terms>"`.
      ```

      When nothing in the file is a natural fit — a small headed section is appropriate:
      ```
      ## Documented Solutions

      Solved-problem learnings live as GitHub issues labeled `yunxing:solution` (bugs, best practices, workflow patterns), each with a YAML block carrying `category`, `module`, `tags`, `problem_type`. Search with `gh issue list --label "yunxing:solution" --search "<terms>"`. Relevant when implementing or debugging in documented areas.
      ```
   c. In interactive mode, explain to the user why this matters — agents working in this repo (including fresh sessions, other tools, or collaborators without the plugin) won't know to check the `yunxing:solution` issues unless the instruction file surfaces them. Show the proposed change and where it would go, then use the platform's blocking question tool to get consent before making the edit: `AskUserQuestion` in Claude Code (call `ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded), `request_user_input` in Codex, `ask_user` in Gemini, `ask_user` in Pi (requires the `pi-ask-user` extension). Fall back to presenting the proposal in chat only when no blocking tool exists in the harness or the call errors (e.g., Codex edit modes) — not because a schema load is required. Never silently skip the question. In headless mode, include it as a "Discoverability recommendation" line in the report — do not attempt to edit instruction files (headless scope is learning maintenance, not project config).

5. **If `CONCEPTS.md` exists at repo root, run a parallel discoverability check for it.** Use the same workflow as the `yunxing:solution` check above: same target file, same edit-placement judgment, same consent-then-edit interaction shape per mode. Example calibration when a conventions block is present:

   ```
   CONCEPTS.md  # shared domain vocabulary — read when orienting to the codebase or before discussing domain concepts
   ```

   **Skip this step entirely if `CONCEPTS.md` does not exist** — never nag for an artifact the project has not adopted. When skipped, this step produces no output and no edit.

6. **Amend or create a follow-up commit when the check produces edits.** If step 4 or step 5 resulted in an edit to an instruction file and Phase 5 already committed the local changes, stage the newly edited file and either amend the existing commit (if still on the same branch and no push has occurred) or create a small follow-up commit (e.g., `docs: surface yunxing:solution issues in AGENTS.md`, or `docs: add CONCEPTS.md discoverability to AGENTS.md`, or a combined message when both edits landed). If Phase 5 already pushed the branch to a remote (e.g., the branch+PR path), push the follow-up commit as well so the open PR includes the discoverability change. This keeps the working tree clean and the remote in sync at the end of the run. If the user chose "Don't commit" in Phase 5, leave the instruction-file edits unstaged alongside the other uncommitted local changes — no separate commit logic needed.
