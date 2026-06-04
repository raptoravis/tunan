# Per-Action Flows

Read this reference when executing Phase 4. Find the section matching the action classified in Phase 2 and confirmed in Phase 3 (Keep, Update, Consolidate, Replace, or Delete) and follow that flow.

A learning is a GitHub issue labeled `yunxing:solution`; its body is a fenced ```yaml block followed by markdown sections. All edits operate on the issue body via `gh issue edit <N> --body-file <tmpfile>`; "delete/archive" is `gh issue close <N>`. Run the GH preflight (see SKILL.md "Storage: yunxing:solution GitHub issues") before any `gh` call.

## Keep Flow

No issue edit by default. Summarize why the learning remains trustworthy.

## Update Flow

Apply edits to the issue body (`gh issue edit`) only when the solution is still substantively correct.

Examples of valid updates:

- Rename `app/models/auth_token.rb` reference to `app/models/session_token.rb`
- Update `module: AuthToken` to `module: SessionToken` in the YAML block
- Fix outdated links to related learnings (`#<N>` refs)
- Refresh implementation notes after a directory move

Examples that should **not** be Update edits:

- Fixing a typo with no effect on understanding
- Rewording prose for style alone
- Small cleanup that does not materially improve accuracy or usability
- The old fix is now an anti-pattern
- The system architecture changed enough that the old guidance is misleading
- The troubleshooting path is materially different

Those cases require **Replace**, not Update.

## Consolidate Flow

The orchestrator handles consolidation directly (no subagent needed — the issue bodies are already read and the merge is a focused edit). Process Consolidate candidates by topic cluster. For each cluster identified in Phase 1.75:

1. **Confirm the canonical issue** — the broader, more current, more accurate learning in the cluster.
2. **Extract unique content** from the subsumed issue(s) — anything the canonical issue does not already cover. This might be specific edge cases, additional prevention rules, or alternative debugging approaches.
3. **Merge unique content** into the canonical issue's body in a natural location, then write it back with `gh issue edit <canonical> --body-file <tmpfile>`. Do not just append — integrate it where it logically belongs. If the unique content is small (a bullet point, a sentence), inline it. If it is a substantial sub-topic, add it as a clearly labeled section.
4. **Update cross-references** — if any other learnings or markdown reference the subsumed issue, update those references to point to the canonical issue (`#<canonical>`).
5. **Close the subsumed issue:** `gh issue close <subsumed> --comment "consolidated into #<canonical>"`. Do not invent an archive label — closing is the archive. Issue history preserves it.

If a cluster has 3+ overlapping issues, process pairwise: consolidate the two most overlapping issues first, then evaluate whether the merged result should be consolidated with the next.

**Structural edits beyond merge:** Consolidate also covers the reverse case. If one learning has grown unwieldy and covers multiple distinct problems that would benefit from separate retrieval, it is valid to recommend splitting it into multiple `yunxing:solution` issues. Only do this when the sub-topics are genuinely independent and a maintainer might search for one without needing the other.

## Replace Flow

Process Replace candidates **one at a time, sequentially**. Each replacement body is authored by a subagent to protect the main context window; the orchestrator applies it via `gh issue edit`.

When a replacement is needed, read the documentation contract files and pass their contents into the replacement subagent's task prompt:

- `references/schema.yaml` — frontmatter fields and enum values for the YAML block
- `references/yaml-schema.md` — category classification
- `assets/resolution-template.md` — issue-body section structure

Do not let replacement subagents invent frontmatter fields, enum values, or section order from memory. Subagents return body text only — they do not call `gh`.

**When evidence is sufficient:**

1. Spawn a single subagent to author the replacement learning body. Pass it:
   - The old learning's full body (the orchestrator's `gh issue view <N>` output)
   - A summary of the investigation evidence (what changed, what the current code does, why the old guidance is misleading)
   - The target category (same category as the old learning unless the category itself changed)
   - The relevant contents of the three support files listed above
2. The subagent writes the new body using the support files as the source of truth: `references/schema.yaml` for frontmatter fields and enum values, `references/yaml-schema.md` for category classification and YAML-safety rules for array items, and `assets/resolution-template.md` for section order (a fenced ```yaml block at the top, then the markdown sections). It should use dedicated file search and read tools if it needs additional context beyond what was passed.
3. The orchestrator writes the returned body to a temp file and **runs `python3 scripts/validate-frontmatter.py <body-file>`** (or `python` on Windows) to catch silent-corruption parser-safety issues the prose rules miss: unquoted ` #` in scalar values (silent comment truncation) and unquoted `: ` in scalar values (silent mapping confusion). Exit 0 means parser-safe; exit 1 means stderr names the offending field(s) — quote the value(s), rebuild the body, and re-run until exit 0 **before** editing the issue. Do not declare success while validation fails. The script does not enforce schema rules and does not flag YAML reserved-indicator characters (those produce loud parser errors downstream rather than silent corruption — out of scope). Uses Python 3 stdlib only (no PyYAML or other deps).
4. Overwrite the **same issue's** body: `gh issue edit <N> --body-file <body-file>`. The new YAML block may include `supersedes: <old slug>` for traceability, but this is optional — the issue history provides the same information. (Replace keeps the same issue number; only the body changes.)

**When evidence is insufficient:**

1. Mark the learning as stale in place via `gh issue edit <N>`:
   - Set in the YAML block: `status: stale`, `stale_reason: [what you found]`, `stale_date: YYYY-MM-DD`
2. Report what evidence was found and what is missing
3. Recommend the user run `compound` after their next encounter with that area

## Delete Flow

Delete (close) only when a learning is clearly obsolete, redundant (with no unique content to merge), or its problem domain is gone. Do not close a learning just because it is old — age alone is not a signal.

Before closing the issue, run a final inbound-link check to catch any references missed during Phase 1: other learning issues referencing it by `#<N>` (`gh issue list --label "yunxing:solution" --search "#<N>"`) and the repo's markdown content (prefer the platform's native content-search tool, e.g., Grep in Claude Code; use ranged or context-line reads around matches rather than loading whole files).

Each match is a citation that will dangle after close. Cleanup is mechanical — Phase 2 already classified the citations and confirmed Delete was right. Don't re-litigate.

If any citation surfaces here that wasn't seen in Phase 1 and is anything other than unambiguously decorative (substantive or mixed/unclear), stop and reclassify: autofix mode stale-marks; interactive mode asks the user whether Replace fits. Only proceed with cleanup when all late-discovered citations are unambiguously decorative.

Close the issue: `gh issue close <N> --comment "<reason — e.g., problem domain removed in #PR>"`.
