# Concepts

Shared domain vocabulary for this project — entities, named processes, and status concepts with project-specific meaning. Seeded with core domain vocabulary, then accretes as compound and compound-refresh process learnings; direct edits are fine. Glossary only, not a spec or catch-all.

## Skill contracts & autonomous pipeline

### mode:agent
A skill run mode in which the skill emits a single machine-readable JSON object instead of human-facing markdown, so another skill or an automated pipeline can consume the result programmatically. The default (non-`mode:agent`) run produces prose/markdown for a human.

### Output contract
The versioned JSON envelope a `mode:agent` skill emits. Multiple skills emit the *same* envelope shape so one consumer can read any of them the same way. Its version field tracks the **structure** of the envelope only — because the producer is a non-deterministic agent, values are not guaranteed reproducible run-to-run. When the contract is shared across skills, the authoritative definition lives in one skill's `references/` and others hold a byte-identical copy.

### verdict_code
The machine-readable verdict in an output contract — a stable enum derived **deterministically from the summary counts** (not free agent judgment), so a consumer can route on it and independently recompute it. Distinct from the human-readable `verdict` string, which is for the markdown view and is not machine-stable.

### Green gate
A pipeline step that gates progress on a machine-read pass/fail signal from a `mode:agent` verification skill. A red signal routes back into the fix loop rather than letting the pipeline proceed; an ambiguous or skipped signal is never treated as authoritative green.

### lfg pipeline
The end-to-end autonomous engineering run (plan → work → review → verify → ship → watch CI), driven by reading machine contracts between stages and self-correcting without prompting the user. *Avoid:* "the autopilot" when precision matters.
