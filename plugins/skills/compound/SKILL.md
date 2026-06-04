---
name: compound
description: "Document a recently solved problem as a yunxing:solution GitHub issue to compound your team's knowledge, or update CONCEPTS.md, the project's shared domain vocabulary."
argument-hint: "[optional: brief context] [mode:headless] "
---

# /yunxing:compound

Coordinate multiple subagents working in parallel to document a recently solved problem.

## Purpose

Captures problem solutions while context is fresh, creating a structured GitHub issue labeled `yunxing:solution` (titled `[solution] <slug>`) with a fenced ```yaml block at the top of the body for searchability and future reference. Uses parallel subagents for maximum efficiency.

**Why "compound"?** Each documented solution compounds your team's knowledge. The first time you solve a problem takes research. Document it, and the next occurrence takes minutes. Knowledge compounds.

## Usage

```bash
/yunxing:compound                            # Document the most recent fix
/yunxing:compound [brief context]            # Provide additional context hint
/yunxing:compound mode:headless              # Non-interactive run for automations
/yunxing:compound mode:headless [context]    # Non-interactive run with context hint
```

## CONCEPTS.md bootstrap requests

If invoked specifically to create or bootstrap `CONCEPTS.md` from scratch rather than to document a solved problem, do not run the normal phases — `compound` populates `CONCEPTS.md` only as a side effect of documenting a real learning (it seeds the *learning's area*, not the whole repo; see Phase 2.4). Repo-wide concept-map creation is `compound-refresh`'s job. Redirect a standalone bootstrap request to `compound-refresh` (which asks whether to build the concept map or run a refresh cycle), then exit.

## Mode Detection

Check `$ARGUMENTS` for a `mode:headless` token. Tokens starting with `mode:` are flags, not context — strip `mode:headless` from arguments before treating the remainder as the brief context hint.

| Mode | When | Behavior |
|------|------|----------|
| **Interactive** (default) | No mode token present | Ask Full vs Lightweight, ask about session history (Full only), prompt for Discoverability Check consent, end with "What's next?" |
| **Headless** | `mode:headless` in arguments | No blocking questions. Run **Full mode without session history**. Apply the Discoverability Check edit silently if a gap exists. Skip Phase 3 specialized reviews. End with a structured terminal report — no "What's next?" menu. |

Headless mode is intended for automations and skill-to-skill invocation where no human is present to answer questions. The doc itself is identical to what an interactive Full run would produce — classification work (track, category, overlap) follows the same rules and writes nothing extra into the artifact. Once detected, headless mode applies for the entire run.

## Pre-resolved context

**Git branch (pre-resolved):** !`git rev-parse --abbrev-ref HEAD 2>/dev/null || true`

If the line above resolved to a plain branch name (like `feat/my-branch`), include it in the `sessions` invocation payload in Phase 1 so the orchestrator does not waste a turn deriving it. If it still contains a backtick command string or is empty, omit it and let `sessions` derive it at runtime.

## Storage: yunxing:solution GitHub issues

Learnings are stored as GitHub issues, never local files. A learning is one issue labeled `yunxing:solution`, titled `[solution] <slug>`, whose body is a fenced ```yaml block (the frontmatter from `references/schema.yaml`) followed by the resolution-template markdown sections. Never write a learning to a local file.

**GH preflight — run before any issue read or write.** If any check fails, abort and surface the guidance; never fall back to a local file.

1. `gh` is installed. If not, install from https://cli.github.com or run `/yunxing:setup`.
2. `gh auth status` exits 0. If not, run `gh auth login` (in Claude Code, suggest typing `! gh auth login`).
3. `gh repo view --json nameWithOwner` resolves. If not, a GitHub repo is required.

**Ensure the label exists** before creating or relabeling:

```bash
gh label list --search "yunxing:solution"
```

If absent:

```bash
gh label create "yunxing:solution" --color 1f883d --description "yunxing solution"
```

**Create a learning issue** (markdown body only — no HTML files). Write the body to a temp file, then:

```bash
gh issue create --title "[solution] <slug>" --label "yunxing:solution" --body-file <tmpfile>
```

The body is the ```yaml block (from the resolution template's frontmatter) followed by the template's markdown sections. Reference the originating req/plan issue by `#<N>` in the body when known.

**Find / resume / update a learning issue:**

```bash
gh issue list --label "yunxing:solution" --search "<terms>" --json number,title,url
gh issue view <N> --json title,body,url,labels
gh issue edit <N> --body-file <tmpfile>
```

Accept an issue ref `#<N>` or full issue URL as input. Before creating, check for an existing matching open `yunxing:solution` issue and update it instead of duplicating.

## Support Files

These files are the durable contract for the workflow. Read them on-demand at the step that needs them — do not bulk-load at skill start.

- `references/schema.yaml` — canonical frontmatter fields and enum values for the issue body's ```yaml block (read when validating YAML)
- `references/yaml-schema.md` — category classification from problem_type (read when classifying)
- `references/concepts-vocabulary.md` — CONCEPTS.md format and inclusion rules (read in Phase 2.4 when domain terms surface)
- `assets/resolution-template.md` — issue body structure for new learnings (read when assembling)

When spawning subagents, pass the relevant file contents into the task prompt so they have the contract without needing cross-skill paths.

## Execution Strategy

**In headless mode**, skip both questions below and go directly to **Full Mode** with session history disabled. Phase 1's session-history step (step 4) is omitted. Proceed straight to research.

**In interactive mode**, present the user with two options before proceeding, using the platform's blocking question tool: `AskUserQuestion` in Claude Code (call `ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded), `request_user_input` in Codex, `ask_user` in Gemini, `ask_user` in Pi (requires the `pi-ask-user` extension). Fall back to presenting options in chat only when no blocking tool exists in the harness or the call errors (e.g., Codex edit modes) — not because a schema load is required. Never silently skip the question.

**Alignment protocol.** When asking the sponsor to choose between options, follow the align protocol: offer at least 3 ranked options with the single best one pre-selected as the default — place it first and append `(Recommended)` to its label — so the sponsor lands on the optimal choice by accepting the default. Load the `align` skill for the full protocol. Never hand an open-ended choice back to the sponsor.

```
1. Full (recommended) — the complete compound workflow. Researches,
   cross-references, and reviews your solution to produce documentation
   that compounds your team's knowledge.

2. Lightweight — same documentation, single pass. Faster and uses
   fewer tokens, but won't detect duplicates or cross-reference
   existing docs. Best for simple fixes or long sessions nearing
   context limits.
```

In interactive mode, do NOT pre-select a mode, do NOT skip this prompt, and wait for the user's choice before proceeding. (Headless mode bypasses this prompt per the "**In headless mode**" rule above and runs Full directly — these "do not skip" directives do not apply to headless.)

**If the user chooses Full** (interactive mode only), ask one follow-up question before proceeding. Detect which harness is running (Claude Code, Codex, or Cursor) and ask:

```
Would you also like to search your [harness name] session history
for relevant knowledge to help the Compound process? This adds
time and token usage.
```

If the user says yes, invoke `sessions` in Phase 1 (see step 4). If no, skip it. Do not ask this in lightweight mode or headless mode.

---

### Full Mode

<critical_requirement>
**The primary deliverable is ONE artifact — the final `yunxing:solution` issue.**

Phase 1 subagents return TEXT DATA to the orchestrator. They must NOT use Write, Edit, create files, or create/edit issues. Only the orchestrator creates or edits the issue. Beyond the Phase 2 solution issue, its other writes are local maintenance side effects — not additional deliverables, and creating one when absent is expected, not a violation of this rule:
- **`CONCEPTS.md`** — create or update in Phase 2.4 (Vocabulary Capture) when a qualifying domain term surfaces.
- **A project instruction file** (AGENTS.md or CLAUDE.md) — a small edit when the Discoverability Check finds a gap.

Both ensure future agents can discover and ground in the knowledge store; neither makes the documentation any less the single deliverable.
</critical_requirement>

### Phase 0.5: Auto Memory Scan

Before launching Phase 1 subagents, check the auto-memory block injected into your system prompt for notes relevant to the problem being documented.

1. Look for a block labeled "user's auto-memory" (Claude Code only) already present in your system prompt context — MEMORY.md's entries are inlined there
2. If the block is absent, empty, or this is a non-Claude-Code platform, skip this step and proceed to Phase 1 unchanged
3. Scan the entries for anything related to the problem being documented -- use semantic judgment, not keyword matching
4. If relevant entries are found, prepare a labeled excerpt block:

```
## Supplementary notes from auto memory
Treat as additional context, not primary evidence. Conversation history
and codebase findings take priority over these notes.

[relevant entries here]
```

5. Pass this block as additional context to the Context Analyzer and Solution Extractor task prompts in Phase 1. If any memory notes end up in the final documentation (e.g., as part of the investigation steps or root cause analysis), tag them with "(auto memory [claude])" so their origin is clear to future readers.

If no relevant entries are found, proceed to Phase 1 without passing memory context.

### Phase 1: Research

Launch research subagents. Each returns text data to the orchestrator.

**Dispatch order:**
- Launch `Context Analyzer`, `Solution Extractor`, and `Related Docs Finder` in parallel (background)
- **Then** invoke the `sessions` skill via the platform's skill-invocation primitive (see step 4 below) — only if the user opted in to session history. The skill call is synchronous from this orchestrator's main-context turn, but the already-dispatched background subagents continue running in parallel underneath, so the wall-clock benefit is preserved (`max(sessions, slowest background subagent)`, not their sum). Issuing the skill call before the parallel block would serialize sessions in front of the research subagents and regress wall-clock time.

<parallel_tasks>

#### 1. **Context Analyzer**
   - Extracts conversation history
   - Reads `references/schema.yaml` for enum validation and **track classification**
   - Determines the track (bug or knowledge) from the problem_type
   - Identifies problem type, component, and track-appropriate fields:
     - **Bug track**: symptoms, root_cause, resolution_type
     - **Knowledge track**: applies_when (symptoms/root_cause/resolution_type optional)
   - Incorporates auto memory excerpts (if provided by the orchestrator) as supplementary evidence
   - Reads `references/yaml-schema.md` for category classification from problem_type
   - Suggests an issue title slug using the pattern `[solution] <sanitized-problem-slug>` — no date suffix; the `date:` frontmatter field is the canonical creation date
   - Returns: YAML frontmatter skeleton (must include `category:` field mapped from problem_type), category slug, suggested title slug, and which track applies
   - Does not invent enum values, categories, or frontmatter fields from memory; reads the schema and mapping files above
   - Does not force bug-track fields onto knowledge-track learnings or vice versa

#### 2. **Solution Extractor**
   - Reads `references/schema.yaml` for track classification (bug vs knowledge)
   - Adapts output structure based on the problem_type track
   - Incorporates auto memory excerpts (if provided by the orchestrator) as supplementary evidence -- conversation history and the verified fix take priority; if memory notes contradict the conversation, note the contradiction as cautionary context

   **Bug track output sections:**

   - **Problem**: 1-2 sentence description of the issue
   - **Symptoms**: Observable symptoms (error messages, behavior)
   - **What Didn't Work**: Failed investigation attempts and why they failed
   - **Solution**: The actual fix with code examples (before/after when applicable)
   - **Why This Works**: Root cause explanation and why the solution addresses it
   - **Prevention**: Strategies to avoid recurrence, best practices, and test cases. Include concrete code examples where applicable (e.g., gem configurations, test assertions, linting rules)

   **Knowledge track output sections:**

   - **Context**: What situation, gap, or friction prompted this guidance
   - **Guidance**: The practice, pattern, or recommendation with code examples when useful
   - **Why This Matters**: Rationale and impact of following or not following this guidance
   - **When to Apply**: Conditions or situations where this applies
   - **Examples**: Concrete before/after or usage examples showing the practice in action

#### 3. **Related Docs Finder**
   - Searches existing `yunxing:solution` issues for related learnings (`gh issue list --label "yunxing:solution" --search "<terms>"`)
   - Identifies cross-references and links (by `#<N>` issue references)
   - Finds related GitHub issues
   - Flags any related learning issue that may now be stale, contradicted, or overly broad
   - **Assesses overlap** with the new learning being created across five dimensions: problem statement, root cause, solution approach, referenced files, and prevention rules. Score as:
     - **High**: 4-5 dimensions match — essentially the same problem solved again
     - **Moderate**: 2-3 dimensions match — same area but different angle or solution
     - **Low**: 0-1 dimensions match — related but distinct
   - Returns: Links (`#<N>` refs and URLs), relationships, refresh candidates, and overlap assessment (score + which dimensions matched)

   **Search strategy (issue-list filtering for efficiency):**

   1. Extract keywords from the problem context: module names, technical terms, error messages, component types
   2. List candidate learning issues with `gh issue list --label "yunxing:solution" --search "<keywords>" --state all --json number,title,url --limit 25`. Run a few keyword variants if needed
   3. If the list returns >25 candidates, re-run with more specific keywords. If <3, broaden the keywords
   4. Read only the frontmatter ```yaml block of candidate issues (`gh issue view <N> --json body` then inspect the top fence) to score relevance
   5. Fully read only strong/moderate matches
   6. Return distilled links (`#<N>` refs / URLs) and relationships, not raw issue bodies

   **Related non-learning issues:**

   Also search for other related GitHub issues with `gh issue list --search "<keywords>" --state all --limit 5`. If `gh` is not installed, the GH preflight already aborts the run — there is no local-file fallback.

</parallel_tasks>

#### 4. **Session History via `sessions`** (synchronous skill call, after launching the parallel block — only if the user opted in)
   - **Skip entirely** if the user declined session history in the follow-up question, if running in lightweight mode, or if running in headless mode.
   - Invoke the `sessions` skill via the platform's skill-invocation primitive (`Skill` in Claude Code, `Skill` in Codex, the equivalent on Gemini/Pi). Pass the dispatch payload below as the skill argument string. `sessions` runs in main context — it owns discovery, branch/keyword filtering, scan-window selection, the deep-dive cap, per-session extraction to a `mktemp` scratch dir, and dispatch of the synthesis-only `yunxing:session-historian` subagent. The compound orchestrator only needs to pass the topic and time window and read back the findings text.

   **Dispatch payload — keep tight.** A long, keyword-rich payload licenses sessions to keep widening. Use this shape:

   - **Pre-resolved context** (only if values resolved cleanly above; otherwise omit): repo name, current git branch.
   - **Time window**: explicit `7 days` unless the documented problem clearly spans a longer arc.
   - **Problem topic**: one sentence naming the concrete issue — error message, module name, what broke and how it was fixed. Not a paragraph; not a bullet list of related topics.
   - **Filter rule (one line)**: "Only surface findings directly relevant to this specific problem. Ignore unrelated work from the same sessions or branches."
   - **Output schema**:

     ```
     Structure your response with these sections (omit any with no findings):
     - What was tried before
     - What didn't work
     - Key decisions
     - Related context
     ```

   Do not append additional context blocks, exclusion lists, or topic-keyword bullets — verbose payloads give sessions license to keep widening the search and rapidly compound wall time. If keyword search is needed, sessions owns that decision internally based on the topic.
   - Returns: structured digest of findings from prior sessions, or "no relevant prior sessions" if none found.
   - **sessions is the final Phase 1 input, not a workflow stop.** When it returns, proceed directly to Phase 2 with its output as the last input — do not emit a summary and do not pause for the user. A "no relevant prior sessions" return is still a valid input; the documentation gets written without session context.

### Phase 2: Assembly & Write

<sequential_tasks>

**WAIT for all Phase 1 inputs to complete before proceeding** — the three parallel subagents and, when the user opted in, the synchronous `sessions` skill call. sessions is a Phase 1 input even though it is a skill rather than a subagent.

The orchestrating agent (main conversation) performs these steps:

1. Collect all text results from Phase 1 subagents
2. **Check the overlap assessment** from the Related Docs Finder before deciding what to write:

   | Overlap | Action |
   |---------|--------|
   | **High** — existing learning issue covers the same problem, root cause, and solution | **Update the existing issue** with fresher context (new code examples, updated references, additional prevention tips) via `gh issue edit <N> --body-file <tmpfile>` rather than creating a duplicate. The existing issue's number and structure stay the same. |
   | **Moderate** — same problem area but different angle, root cause, or solution | **Create the new issue** normally. Flag the overlap for Phase 2.5 to recommend consolidation review. |
   | **Low or none** | **Create the new issue** normally. |

   The reason to update rather than create: two learnings describing the same problem and solution will inevitably drift apart. The newer context is fresher and more trustworthy, so fold it into the existing issue rather than creating a second one that immediately needs consolidation.

   When updating an existing issue, preserve its number and frontmatter structure. Update the solution, code examples, prevention tips, and any stale references. Add a `last_updated: YYYY-MM-DD` field to the ```yaml block. Do not change the title unless the problem framing has materially shifted.

3. **Incorporate session history findings** (if available). When `sessions` returned relevant prior-session context:
   - Fold investigation dead ends and failed approaches into the **What Didn't Work** section (bug track) or **Context** section (knowledge track)
   - Use cross-session patterns to enrich the **Prevention** or **Why This Matters** sections
   - Tag session-sourced content with "(session history)" so its origin is clear to future readers
   - If findings are thin or "no relevant prior sessions," proceed without session context
4. Assemble the complete issue body from the collected pieces: a fenced ```yaml block (the frontmatter) at the top, then the markdown sections — reading `assets/resolution-template.md` for the structure of new learnings. Write the body to a temp file.
5. Validate the YAML block against `references/schema.yaml`, including the YAML-safety quoting rule for array items (see `references/yaml-schema.md` > YAML Safety Rules)
6. Run the GH preflight (see "Storage: yunxing:solution GitHub issues") and ensure the `yunxing:solution` label exists
7. Create or update the issue: for a new learning, `gh issue create --title "[solution] <slug>" --label "yunxing:solution" --body-file <tmpfile>`; for a high-overlap update, `gh issue edit <N> --body-file <tmpfile>` on the existing issue
8. **Run the parser-safety validator on the body file** — `python3 scripts/validate-frontmatter.py <body-file>` (macOS/Linux) or `python scripts/validate-frontmatter.py <body-file>` (Windows). It extracts the top ```yaml block and catches silent-corruption parser-safety issues the prose rules miss: unquoted ` #` in scalar values (silent comment truncation) and unquoted `: ` in scalar values (silent mapping confusion). Exit 0 means parser-safe; exit 1 means stderr names the offending field(s) — quote the value(s), rebuild the body, and re-run until exit 0 **before** creating/editing the issue. Do not declare success while validation fails. The script does not enforce schema rules and does not flag YAML reserved-indicator characters (those produce loud parser errors downstream rather than silent corruption — out of scope). Uses Python 3 stdlib only (no PyYAML or other deps).

When creating a new learning, preserve the section order from `assets/resolution-template.md` unless the user explicitly asks for a different structure.

</sequential_tasks>

### Phase 2.4: Vocabulary Capture

**First, read `references/concepts-vocabulary.md`.** This is unconditional. Do not pre-judge from memory that nothing qualifies — the reference's criteria are non-obvious and qualifying terms often live in the surrounding conversation rather than the new doc itself. Reading the reference is what makes the rest of the phase possible.

Then, applying those criteria, scan the new doc **and** the surrounding conversation for qualifying domain terms. If `CONCEPTS.md` exists at repo root, add missing qualifying terms and refine existing entries when new precision surfaced. If it does not exist and at least one qualifying term surfaced, create it.

**Seed the learning's area at creation — don't write a lone term.** When `CONCEPTS.md` does not yet exist, alongside the surfaced term also seed the core domain nouns of the area this learning touched, following the **Seed goal** and **Scope of a seed** rules in `references/concepts-vocabulary.md`. The seed is scoped to the learning's area (the modules and domain the fix touched) and defines only terms investigated here — it does not reach for repo-wide nouns. This anchors the surfaced term so it does not dangle against undefined siblings. A repo-wide concept map is `compound-refresh`'s bootstrap path, not this one.

**At creation, hold the qualifying bar conservatively for borderline terms.** A borderline term, or a class/table/file name dressed up as an entity, defers to a later run — clear core nouns are seeded, borderline ones wait. The conservatism is about quality, not count; updates to an existing file follow the normal criteria.

**When bootstrapping the file, start with this preamble under the `# Concepts` heading**, then add the qualifying entries below it:

> Shared domain vocabulary for this project — entities, named processes, and status concepts with project-specific meaning. Seeded with core domain vocabulary, then accretes as compound and compound-refresh process learnings; direct edits are fine. Glossary only, not a spec or catch-all.

**Refresh the coherence neighborhood of any entry you touch.** When adding or editing an entry, also inspect its *coherence neighborhood* — its cluster siblings and the terms it cross-references or that reference it. Within that neighborhood, do two things: fix glossary violations (implementation specifics — file paths, class names, function signatures, current-config values), and refresh entries the learning's own evidence shows have drifted. Bounds: neighborhood only, never a full-file audit; refresh only on evidence already in hand; if judging a neighbor would require investigation this learning did not do, flag it for `compound-refresh` rather than editing on a guess. The test: after the edit, would a reader find the touched entry's siblings or referenced terms inconsistent with it? Broader audit is `compound-refresh`'s job.

If no terms qualified after applying the reference's criteria, record that outcome explicitly in the success output (e.g., "Vocabulary capture: scanned, no qualifying terms"). Do not silently skip — the visible scan-and-no-result record is the audit signal that the reference was consulted.

**Apply edits silently in every mode — no user prompt in interactive, lightweight, or headless.** Vocabulary capture is a side effect of compounding, not a decision the user makes per run. Lightweight mode reaches this through its own single-pass step (see Lightweight Mode), and runs an **update-only** version — it refines an existing `CONCEPTS.md` but defers creation/seeding to a Full run.

### Phase 2.5: Selective Refresh Check

After writing the new learning, decide whether this new solution is evidence that older learning issues should be refreshed.

`compound-refresh` is **not** a default follow-up. Use it selectively when the new learning suggests an older learning issue may now be inaccurate.

It makes sense to invoke `compound-refresh` when one or more of these are true:

1. A related learning issue recommends an approach that the new fix now contradicts
2. The new fix clearly supersedes an older documented solution
3. The current work involved a refactor, migration, rename, or dependency upgrade that likely invalidated references in older learnings
4. A related learning now looks overly broad, outdated, or no longer supported by the refreshed reality
5. The Related Docs Finder surfaced high-confidence refresh candidates in the same problem space
6. The Related Docs Finder reported **moderate overlap** with an existing learning issue — there may be consolidation opportunities that benefit from a focused review

It does **not** make sense to invoke `compound-refresh` when:

1. No related learnings were found
2. Related learnings still appear consistent with the new learning
3. The overlap is superficial and does not change prior guidance
4. Refresh would require a broad historical review with weak evidence

Use these rules:

- If there is **one obvious stale candidate**, invoke `compound-refresh` with a narrow scope hint after the new learning is written
- If there are **multiple candidates in the same area**, ask the user whether to run a targeted refresh for that module, category, or pattern set
- If context is already tight or you are in lightweight mode, do not expand into a broad refresh automatically; instead recommend `compound-refresh` as the next step with a scope hint
- **In headless mode**, never invoke `compound-refresh` and never ask the user. Surface the recommended scope hint in the terminal report's "Refresh recommendation" line and let the caller decide

When invoking or recommending `compound-refresh`, be explicit about the argument to pass. Prefer the narrowest useful scope:

- **Specific learning issue** (`#<N>` or its slug) when one learning is the likely stale artifact
- **Module or component name** when several related learnings may need review
- **Category slug** when the drift is concentrated in one solutions area

Examples:

- `/yunxing:compound-refresh plugin-versioning-requirements`
- `/yunxing:compound-refresh payments`
- `/yunxing:compound-refresh performance-issues`
- `/yunxing:compound-refresh critical-patterns`

A single scope hint may still expand to multiple related docs when the change is cross-cutting within one domain, category, or pattern area.

Do not invoke `compound-refresh` without an argument unless the user explicitly wants a broad sweep.

Always capture the new learning first. Refresh is a targeted maintenance follow-up, not a prerequisite for documentation.

### Discoverability Check

After the learning is written and the refresh decision is made, check whether the project's instruction files would lead an agent to discover and search the project's `yunxing:solution` GitHub issues before starting work in a documented area. This runs every time — the knowledge store only compounds value when agents can find it.

1. Identify which root-level instruction files exist (AGENTS.md, CLAUDE.md, or both). Read the file(s) and determine which holds the substantive content — one file may just be a shim that `@`-includes the other (e.g., `CLAUDE.md` containing only `@AGENTS.md`, or vice versa). The substantive file is the assessment and edit target; ignore shims. If neither file exists, skip this check entirely.
2. Assess whether an agent reading the instruction files would learn three things:
   - That a searchable knowledge store of documented solutions exists as GitHub issues labeled `yunxing:solution`
   - Enough about its structure to search effectively (the label, and the YAML fields like `category`, `module`, `tags`, `problem_type` in each issue body)
   - When to search it (before implementing features, debugging issues, or making decisions in documented areas — learnings may cover bugs, best practices, workflow patterns, or other institutional knowledge)

   This is a semantic assessment, not a string match. The information could be a line in an architecture section, a bullet in a gotchas section, spread across multiple places, or expressed without ever using the exact label `yunxing:solution`. Use judgment — if an agent would reasonably discover and use the knowledge store after reading the file, the check passes.

3. If the spirit is already met, no action needed — move on.
4. If not:
   a. Based on the file's existing structure, tone, and density, identify where a mention fits naturally. Before creating a new section, check whether the information could be a single line in the closest related section — an architecture overview, a conventions block, or a documentation section. A line added to an existing section is almost always better than a new headed section. Only add a new section as a last resort when the file has clear sectioned structure and nothing is even remotely related.
   b. Draft the smallest addition that communicates the three things. Match the file's existing style and density. The addition should describe the knowledge store itself, not the plugin — an agent without the plugin should still find value in it.

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
   c. In full interactive mode, explain to the user why this matters — agents working in this repo (including fresh sessions, other tools, or collaborators without the plugin) won't know to check the `yunxing:solution` issues unless the instruction file surfaces them. Show the proposed change and where it would go, then use the platform's blocking question tool to get consent before making the edit: `AskUserQuestion` in Claude Code (call `ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded), `request_user_input` in Codex, `ask_user` in Gemini, `ask_user` in Pi (requires the `pi-ask-user` extension). Fall back to presenting the proposal in chat only when no blocking tool exists in the harness or the call errors (e.g., Codex edit modes) — not because a schema load is required. Never silently skip the question. In lightweight mode, output a one-liner note and move on. In headless mode, apply the edit directly without prompting and surface it in the terminal report under "Instruction-file edit"

5. **If `CONCEPTS.md` exists at repo root, run a parallel discoverability check for it.** Assess whether the instruction file would lead an agent to discover the project's shared domain vocabulary. Use the same workflow as the `yunxing:solution` check above: same target file, same edit-placement judgment, same consent-then-edit interaction shape per mode. A line in an existing section is almost always better than a new headed section. Example calibration when nothing else fits:

   ```
   CONCEPTS.md  # shared domain vocabulary (entities, named processes, status concepts) — relevant when orienting to the codebase or discussing domain concepts
   ```

   **Skip this step entirely if `CONCEPTS.md` does not exist** — never nag for an artifact the project has not adopted. When skipped, this step produces no output and no edit.

### Phase 3: Optional Enhancement

**WAIT for Phase 2 to complete before proceeding.**

**Skip Phase 3 entirely in headless mode** to bound token usage — the caller does not have a human-in-the-loop to act on reviewer findings, and downstream automations can run specialized reviewers themselves if they want that pass.

<parallel_tasks>

Based on problem type, optionally invoke specialized agents to review the documentation:

- **performance_issue** → `yunxing:performance-oracle`
- **security_issue** → `yunxing:security-sentinel`
- **database_issue** → `yunxing:data-integrity-guardian`
- Any code-heavy issue → always run `yunxing:code-simplicity-reviewer` for minimal, clear examples. Structural concerns in the diff are already covered when the same work goes through `/yunxing:code-review` (maintainability persona).

</parallel_tasks>

---

### Lightweight Mode

<critical_requirement>
**Single-pass alternative — same documentation, fewer tokens.**

This mode skips parallel subagents entirely. The orchestrator performs all work in a single pass, producing the same solution document without cross-referencing or duplicate detection.

Headless mode forces Full and does not enter Lightweight — automations get the cross-reference and overlap detection benefits without the interactive overhead.
</critical_requirement>

The orchestrator (main conversation) performs ALL of the following in one sequential pass:

1. **Extract from conversation**: Identify the problem and solution from conversation history. Also scan the "user's auto-memory" block injected into your system prompt, if present (Claude Code only) -- use any relevant notes as supplementary context alongside conversation history. Tag any memory-sourced content incorporated into the final learning with "(auto memory [claude])"
2. **Classify**: Read `references/schema.yaml` and `references/yaml-schema.md`, then determine track (bug vs knowledge), category, and title slug
3. **Create the learning issue**: Run the GH preflight (see "Storage: yunxing:solution GitHub issues"), ensure the `yunxing:solution` label exists, build the issue body using the appropriate track template from `assets/resolution-template.md`, then `gh issue create --title "[solution] <slug>" --label "yunxing:solution" --body-file <tmpfile>`. The body has:
   - A fenced ```yaml block with track-appropriate fields, applying the YAML-safety quoting rule for array items (see `references/yaml-schema.md` > YAML Safety Rules)
   - Bug track: Problem, root cause, solution with key code snippets, one prevention tip
   - Knowledge track: Context, guidance with key examples, one applicability note
4. **Vocabulary capture (update-only)**: if `CONCEPTS.md` exists at repo root, read `references/concepts-vocabulary.md`, then scan the new learning and the conversation for qualifying terms and add/refine entries silently (same criteria as Phase 2.4). Do **not** bootstrap or seed in lightweight mode — if `CONCEPTS.md` does not exist, defer creation to a Full run, which owns seeding. Record the outcome in the output (e.g., "Vocabulary: 1 entry refined" or "scanned, no qualifying terms"). If you refined `CONCEPTS.md` and a quick read of `AGENTS.md`/`CLAUDE.md` shows it isn't surfaced there, add the discoverability tip to the output below — lightweight **tips**, it does not edit instruction files (a Full run owns that edit).
5. **Skip specialized agent reviews** (Phase 3) to conserve context

**Lightweight output:**
```
✓ Documentation complete (lightweight mode)

Issue created:
- #<N> [solution] <slug>  (<url>)

[If discoverability check found instruction files don't surface the knowledge store:]
Tip: Your AGENTS.md/CLAUDE.md doesn't surface the yunxing:solution issues to
agents — a brief mention helps all agents discover these learnings.

[If CONCEPTS.md was refined this run and isn't surfaced in the instruction files:]
Tip: Your AGENTS.md/CLAUDE.md doesn't surface CONCEPTS.md —
a one-line mention helps agents find the shared vocabulary.

Note: This was created in lightweight mode. For richer documentation
(cross-references, detailed prevention strategies, specialized reviews),
re-run /yunxing:compound in a fresh session.
```

**No subagents are launched. No parallel tasks. The solution issue is the one deliverable** (Phase 2.4's update-only vocabulary capture may also refine an existing `CONCEPTS.md`).

In lightweight mode, the overlap check is skipped (no Related Docs Finder subagent). This means lightweight mode may create an issue that overlaps with an existing one. That is acceptable — `compound-refresh` will catch it later. Only suggest `compound-refresh` if there is an obvious narrow refresh target. Do not broaden into a large refresh sweep from a lightweight session.

---

## What It Captures

- **Problem symptom**: Exact error messages, observable behavior
- **Investigation steps tried**: What didn't work and why
- **Root cause analysis**: Technical explanation
- **Working solution**: Step-by-step fix with code examples
- **Prevention strategies**: How to avoid in future
- **Cross-references**: Links to related issues and docs

## Preconditions

<preconditions enforcement="advisory">
  <check condition="problem_solved">
    Problem has been solved (not in-progress)
  </check>
  <check condition="solution_verified">
    Solution has been verified working
  </check>
  <check condition="non_trivial">
    Non-trivial problem (not simple typo or obvious error)
  </check>
</preconditions>

## What It Creates

**One GitHub issue labeled `yunxing:solution`**, titled `[solution] <slug>`, whose body is a fenced ```yaml block followed by the resolution-template markdown sections. Never a local file.

**Category (a `category` slug in the YAML block, auto-detected from problem):**

Bug track:
- build-errors
- test-failures
- runtime-errors
- performance-issues
- database-issues
- security-issues
- ui-bugs
- integration-issues
- logic-errors

Knowledge track:
- architecture-patterns — architectural or structural patterns (agent/skill/pipeline/workflow shape decisions)
- design-patterns — reusable non-architectural design approaches (content generation, interaction patterns, prompt shapes)
- tooling-decisions — language, library, or tool choices with durable rationale
- conventions — team-agreed way of doing something, captured so it survives turnover
- workflow-issues
- developer-experience
- documentation-gaps
- best-practices — fallback only, use when no narrower knowledge-track value applies

## Common Mistakes to Avoid

| ❌ Wrong | ✅ Correct |
|----------|-----------|
| Subagents write files or create/edit issues | Subagents return text data; orchestrator creates/edits the one issue |
| Writing a learning to a local file | One GitHub issue labeled `yunxing:solution` |
| Research and assembly run in parallel | Research completes → then assembly runs |
| Multiple artifacts created during workflow | One solution issue created or updated (plus optional local maintenance writes: a `CONCEPTS.md` create/update from Phase 2.4 and a small instruction-file edit for discoverability) |
| Creating a new issue when an existing issue covers the same problem | Check overlap assessment; update the existing issue when overlap is high |

## Success Output

### Headless mode

Emit a structured terminal report and end the turn. No "What's next?" question, no blocking prompt. End with `Documentation complete` as the terminal signal so callers can detect completion.

```
✓ Documentation complete (headless mode)

Issue: #<N> [solution] <slug>  (<url>)  (created | updated)
Track: <bug | knowledge>
Category: <category>
Overlap: <none | low | moderate — see #<N> | high — existing issue updated>
Instruction-file edit: <none needed | applied to <path> | gap noted, not applied>
CONCEPTS.md: <scanned, no qualifying terms | created with N entries (M seeded from the learning's area) | updated — N added, N refined>
Refresh recommendation: <none | scope hint for /yunxing:compound-refresh>

Documentation complete
```

When no issue was written (e.g., headless invoked on a session where the problem is not yet solved), emit a structured failure instead and end with `Documentation skipped` so callers can distinguish success from no-op:

```
✗ Documentation skipped (headless mode)

Reason: <one-sentence explanation — e.g., "no solved problem detected in
conversation history" or "solution not yet verified">

Documentation skipped
```

### Interactive mode

```
✓ Documentation complete

Auto memory: 2 relevant entries used as supplementary evidence

Subagent Results:
  ✓ Context Analyzer: Identified performance_issue in brief_system, category: performance-issues
  ✓ Solution Extractor: 3 code fixes, prevention strategies
  ✓ Related Docs Finder: 2 related issues
  ✓ Session History: 3 prior sessions on same branch, 2 failed approaches surfaced

Specialized Agent Reviews (Auto-Triggered):
  ✓ yunxing:performance-oracle: Validated query optimization approach
  ✓ yunxing:code-simplicity-reviewer: Solution is appropriately minimal

Written:
- Issue #42 [solution] n-plus-one-brief-generation (created) — https://github.com/<owner>/<repo>/issues/42
- CONCEPTS.md (created with 3 entries: BriefSystem, EmailQueue, Brief Status)

This learning will be searchable for future reference when similar
issues occur in the Email Processing or Brief System modules.

What's next?
1. Continue workflow (recommended)
2. Link related learnings
3. Update other references
4. View the issue
5. Other
```

**After displaying the interactive success output above, present the "What's next?" options using the platform's blocking question tool:** `AskUserQuestion` in Claude Code (call `ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded), `request_user_input` in Codex, `ask_user` in Gemini, `ask_user` in Pi (requires the `pi-ask-user` extension). Fall back to numbered options in chat only when no blocking tool exists in the harness or the call errors (e.g., Codex edit modes) — not because a schema load is required. Never silently skip the question. Do not continue the workflow or end the turn without the user's selection. (Interactive mode only — headless skips this per the headless block above.)

**Alternate interactive output (when updating an existing issue due to high overlap):** in headless mode, this case is communicated via the `Overlap: high — existing issue updated` line of the headless terminal report above, not as a separate output block.

```
✓ Documentation updated (existing issue refreshed with current context)

Overlap detected: #37 [solution] n-plus-one-queries
  Matched dimensions: problem statement, root cause, solution, referenced files
  Action: Updated existing issue with fresher code examples and prevention tips

Issue updated:
- #37 [solution] n-plus-one-queries (added last_updated: 2026-03-24)
```

## The Compounding Philosophy

This creates a compounding knowledge system:

1. First time you solve "N+1 query in brief generation" → Research (30 min)
2. Document the solution → a `yunxing:solution` issue (5 min)
3. Next time similar issue occurs → Quick lookup (2 min)
4. Knowledge compounds → Team gets smarter

The feedback loop:

```
Build → Test → Find Issue → Research → Improve → Document → Validate → Deploy
    ↑                                                                      ↓
    └──────────────────────────────────────────────────────────────────────┘
```

**Each unit of engineering work should make subsequent units of work easier—not harder.**

## Auto-Invoke

<auto_invoke> <trigger_phrases> - "that worked" - "it's fixed" - "working now" - "problem solved" </trigger_phrases>

<manual_override> Use /yunxing:compound [context] to document immediately without waiting for auto-detection. </manual_override> </auto_invoke>

## Output

Creates (or updates) the final learning as a GitHub issue labeled `yunxing:solution`.

## Applicable Specialized Agents

Based on problem type, these agents can enhance documentation:

### Code Quality & Review
- **yunxing:code-simplicity-reviewer**: Ensures solution code is minimal and clear
- **yunxing:pattern-recognition-specialist**: Identifies anti-patterns or repeating issues

### Specific Domain Experts
- **yunxing:performance-oracle**: Analyzes performance_issue category solutions
- **yunxing:security-sentinel**: Reviews security_issue solutions for vulnerabilities
- **yunxing:data-integrity-guardian**: Reviews database_issue migrations and queries

### Enhancement & Research
- **yunxing:best-practices-researcher**: Enriches solution with industry best practices
- **yunxing:framework-docs-researcher**: Links to framework/library documentation references

### When to Invoke
- **Auto-triggered** (optional): Agents can run post-documentation for enhancement
- **Manual trigger**: User can invoke agents after /yunxing:compound completes for deeper review

## Related Commands

- `/research [topic]` - Deep investigation (searches `yunxing:solution` issues for patterns)
- `/yunxing:plan` - Planning workflow (references documented solutions)
