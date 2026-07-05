---
name: doc-review
description: "Review requirements or plan documents using parallel persona agents that surface role-specific issues. Use when a tunan artifact (a tunan:req feature issue, its plan/solution marker comment, or a tunan:idea / tunan:pulse issue) or a local markdown document exists and the user wants to improve it."
argument-hint: "[mode:headless] [#<N> | <issue-url> | path/to/document.md]"
---

# Document Review

Review requirements or plan documents through multi-persona analysis. Dispatches specialized reviewer agents in parallel, auto-applies `safe_auto` fixes, and routes remaining findings through a four-option interaction (per-finding walk-through, auto-resolve with best judgment, Append-to-Open-Questions, Report-only) for user decision.

The primary input is a **tunan artifact** — durable requirements live in the body of a `tunan:req` feature issue, while that feature's plan and solution live as marker comments (`<!-- tunan:plan -->` / `<!-- tunan:solution -->`) on the same issue, with the issue accruing the matching `tunan:plan` / `tunan:solution` label; `tunan:idea` and `tunan:pulse` artifacts are their own issues. None are local files. Reviewing an arbitrary local markdown file (a doc that is not a tunan artifact) is also supported. In both cases the review reads markdown, runs the persona analysis, and applies agreed findings back to the **source** — the issue body or marker comment for an artifact, the file on disk for a local doc.

## Source resolution

A single concept threads through the whole skill: the **working file** — a local markdown path that all edit-tool mechanics (safe_auto apply, the Apply-set batch edit, Open-Questions appends) operate on. How the working file maps to the source depends on the argument:

- **Issue ref (body source)** — an argument of the form `#<N>`, a bare integer `<N>`, or a GitHub issue URL whose artifact lives in the **issue body** (`tunan:req` / `tunan:idea` / `tunan:pulse`, or any non-plan/solution issue). Run GH PREFLIGHT (below), read the issue body via `gh issue view`, and write the body markdown to a transient working file in the OS temp dir. This is the **primary path** for body-source tunan artifacts. After review edits land on the working file, push it BACK to the issue body via `gh issue edit <N> --body-file <working-file>` (the SYNC-BACK step in Phase 4/walkthrough).
- **Issue ref (comment source — plan / solution)** — when the target is a **plan** or **solution**, the artifact is a marker comment on the feature issue (`<!-- tunan:plan -->` / `<!-- tunan:solution -->`), not the issue body (the body is the requirement). The caller (e.g., `plan`'s doc-review step) names which stage. Resolve that comment, write its body to the working file, and SYNC-BACK by PATCHing the **same comment** — not the issue body. See "Comment-source read/sync-back" below.
- **Local path** — an argument that is a filesystem path to a markdown file that is not a tunan artifact. The working file IS that path; edits write in place, with no SYNC-BACK step.

### GH PREFLIGHT (issue source only)

Before any issue read or write, verify the GitHub CLI is usable. Run each check as a single simple command (no chaining, no error suppression) and abort with guidance if any fails — never fall back to writing a local file:

```bash
gh --version
gh auth status
gh repo view --json nameWithOwner
```

If `gh` is not installed, `gh auth status` is non-zero, or the repo does not resolve, stop and tell the user how to fix it (install `gh`, run `gh auth login`, or run from inside a GitHub-backed repo). Do not silently degrade to a local file — the artifact lives in the issue, and a local copy would diverge.

### Read the issue into a working file

```bash
gh issue view <N> --json title,body,url,labels
```

Capture `title` (the Proof/review display title and a hint for classification), `body` (the markdown), `url` (echo it in the final report), and `labels` (the `tunan:*` label is a classification hint — see Phase 1). Write `body` to a transient working file under the OS temp dir (`${TMPDIR:-/tmp}` on macOS/Linux, `$env:TEMP` on Windows) — for example `${TMPDIR:-/tmp}/tunan-doc-review-<N>.md`. All subsequent phases treat that path as `{document_path}` / the working file.

### Write results back to the issue (SYNC-BACK)

After the Phase 4 safe_auto pass and the end-of-walk-through Apply batch have edited the working file, overwrite the issue body from it:

```bash
gh issue edit <N> --body-file <working-file>
```

Optionally, post review notes (FYI observations, residual concerns, the verdict) that are not document edits as a comment instead of folding them into the body:

```bash
gh issue comment <N> --body-file <notes-file>
```

The Open-Questions deferral mechanic also operates on the working file; the same `gh issue edit` push-back carries those appended entries to the issue body. See `references/synthesis-and-presentation.md` and `references/walkthrough.md` for exactly when SYNC-BACK fires.

### Comment-source read/sync-back (plan / solution)

When reviewing a **plan** or **solution**, the artifact is a marker comment on the feature issue, so read and write that comment — never the issue body. Substitute the right marker (`<!-- tunan:plan -->` or `<!-- tunan:solution -->`).

Read the marker comment into the working file (REST `issues/{N}/comments` returns plain numeric ids; capture the id for SYNC-BACK):

```bash
gh api repos/{owner}/{repo}/issues/<N>/comments --jq '.[] | select(.body | startswith("<!-- tunan:plan -->")) | .id'
```
```bash
gh api repos/{owner}/{repo}/issues/<N>/comments --jq '.[] | select(.body | startswith("<!-- tunan:plan -->")) | .body'
```

SYNC-BACK overwrites that same comment by id (not the issue body):

```bash
gh api repos/{owner}/{repo}/issues/comments/<comment-id> -X PATCH -F body=@<working-file>
```

Keep the marker line as the first line of the working file so the comment stays discoverable after edits. FYI/residual notes still post as a fresh `gh issue comment <N>` on the feature issue.

## Interactive mode rules

- **Pre-load the platform question tool before any question fires.** In Claude Code, `AskUserQuestion` is a deferred tool — its schema is not available at session start. At the start of Interactive-mode work (before the routing question, per-finding walk-through questions, bulk-preview Proceed/Cancel, and Phase 5 terminal question), call `ToolSearch` with query `select:AskUserQuestion` to load the schema. Load it once, eagerly, at the top of the Interactive flow — do not wait for the first question site. On Codex, Gemini, and Pi this preload is not required.
- **The numbered-list fallback applies only when the harness genuinely lacks a blocking question tool** — `ToolSearch` returns no match, the tool call explicitly fails, or the runtime mode does not expose it (e.g., Codex edit modes where `request_user_input` is unavailable). A pending schema load is not a fallback trigger; call `ToolSearch` first per the pre-load rule. In genuine-fallback cases, present options as a numbered list and wait for the user's reply — never silently skip the question. Rendering a question as narrative text because the tool feels inconvenient, because the model is in report-formatting mode, or because the instruction was buried in a long skill is a bug. A question that calls for a user decision must either fire the tool or fall back loudly.

**Alignment protocol.** When asking the sponsor to choose between options, follow the align protocol: offer at least 3 ranked options with the single best one pre-selected as the default — place it first and append `(Recommended)` to its label — so the sponsor lands on the optimal choice by accepting the default. Load the `align` skill for the full protocol. Never hand an open-ended choice back to the sponsor.

## Phase 0: Detect Mode

Check the skill arguments for `mode:headless`. Arguments may contain a source (issue ref or document path), `mode:headless`, or both. Tokens starting with `mode:` are flags, not sources — strip them from the arguments and use the remaining token (if any) as the source for Phase 1.

Classify the remaining source token:

- Matches `#<N>`, a bare integer, or a GitHub issue URL → **issue source**. Run GH PREFLIGHT and read the issue into a working file per "Source resolution" above, then proceed to Phase 1 with the working file as `{document_path}`.
- Is a filesystem path to a markdown file → **local source**. The working file is that path; no SYNC-BACK at the end.

If `mode:headless` is present, set **headless mode** for the rest of the workflow.

**Headless mode** changes the interaction model, not the classification boundaries. doc-review still applies the same judgment about which tier each finding belongs in. The only difference is how non-safe_auto findings are delivered:

- `safe_auto` fixes are applied silently (same as interactive)
- `gated_auto`, `manual`, and FYI findings are returned as structured text for the caller to handle — no blocking-question prompts, no interactive routing
- Phase 5 returns immediately with "Review complete" (no routing question, no terminal question)

The caller receives findings with their original classifications intact and decides what to do with them.

Callers invoke headless mode by including `mode:headless` in the skill arguments, e.g.:

```
Skill("doc-review", "mode:headless #142")
Skill("doc-review", "mode:headless /abs/path/to/local-doc.md")
```

In headless mode the safe_auto pass still edits the working file. When the source is an issue, the headless run still pushes the edited working file back after the safe_auto pass — body sources via `gh issue edit <N> --body-file <working-file>`, comment sources (plan/solution) via the comment PATCH in "Comment-source read/sync-back" — silent fixes are durable regardless of interaction model. Non-safe_auto findings are returned as structured text for the caller (no SYNC-BACK is needed for findings the caller hasn't decided on yet).

If `mode:headless` is not present, the skill runs in its default interactive mode with the routing question, walk-through, and bulk-preview behaviors documented in `references/walkthrough.md` and `references/bulk-preview.md`.

## Phase 1: Get and Analyze Document

**If an issue source was resolved in Phase 0:** the working file already holds the issue body markdown — read it, then proceed.

**If a local document path is provided:** Read it, then proceed.

**If no source is specified (interactive mode):** Ask which tunan artifact issue (by `#<N>` or URL) or local markdown file to review. To suggest recent artifacts, list candidate issues by label:

```bash
gh issue list --label tunan:req --state open --limit 10
gh issue list --label tunan:plan --state open --limit 10
```

(Use one `gh issue list` per label; `tunan:solution`, `tunan:idea`, and `tunan:pulse` are also valid artifact labels. A `tunan:plan` / `tunan:solution` label marks a feature issue whose plan/solution lives in a marker comment, not the body.)

**If no source is specified (headless mode):** Output "Review failed: headless mode requires an issue ref or document path. Re-invoke with: Skill(\"doc-review\", \"mode:headless #<N>\") or Skill(\"doc-review\", \"mode:headless <path>\")" without dispatching agents.

### Classify Document Type

Classify the document by reading its **content shape**, not its source location. The issue label (for an issue source) or file path (for a local source) is a tie-breaker hint, not the primary signal — a `tunan:plan`-labeled issue whose body is brainstorm-shaped should still classify as `requirements`, and a plan-shaped doc should classify as `plan` regardless of where it came from. The reviewers below operate differently depending on this classification, so misclassifying a plan-shaped doc as a requirements doc (or vice versa) produces noisy or under-scrutinized findings.

Use these signals to decide:

**`requirements` signals (what-to-build documents):**
- Frontmatter fields like `actors:`, `flows:`, `acceptance_examples:`, or `status:` carrying brainstorm-shaped values
- Section headings such as `Acceptance Examples`, `Actors`, `Key Flows`, `User Flows`, `Outstanding Questions`, `Resolve Before Planning`
- Numbered identifiers in the form `R1`, `R2`, `A1`, `F1`, `AE1` — requirement, actor, flow, and acceptance-example IDs
- Prose framing focused on user/business problem, behavior, scope boundaries, success criteria
- No implementation units, no per-unit file lists, no test scenarios attached to units

**`plan` signals (how-to-build documents):**
- Frontmatter fields like `type: feat|fix|refactor`, or an `origin:` pointing at an upstream requirements artifact (an issue ref `#<N>` for a `tunan:req` artifact)
- Section headings such as `Implementation Units`, `Output Structure`, `Key Technical Decisions`, `Risks & Dependencies`, `System-Wide Impact`
- Numbered identifiers in the form `U1`, `U2` — implementation unit IDs
- Per-unit fields named `Goal`, `Files`, `Approach`, `Test scenarios`, `Verification`
- Repo-relative file paths to create/modify/test
- Prose framing focused on technical decisions, sequencing, and implementer-facing detail

**Tie-breaker rule.** When the content signals are mixed or sparse, fall back to the source hint: a `tunan:req` label (or a local path under a brainstorm/requirements location) → `requirements`; a `tunan:plan` label (or a local plan location) → `plan`. `tunan:solution`, `tunan:idea`, and `tunan:pulse` artifacts have no clean default — classify them by content shape. When no hint applies, treat the dominant content shape as authoritative; if shape is genuinely ambiguous, default to `requirements` (the more conservative classification — it activates fewer plan-specific feasibility checks).

Pass the classification result to each persona via the `{document_type}` slot in the subagent template. Personas read this and adapt their analysis accordingly.

### Select Conditional Personas

Analyze the document content to determine which conditional personas to activate. Check for these signals:

**product-lens** -- activate when the document makes challengeable claims about what to build and why, or when the proposed work carries strategic weight beyond the immediate problem. The system's users may be end users, developers, operators, maintainers, or any other audience -- the criteria are domain-agnostic. Check for either leg:

*Leg 1 — Premise claims:* The document stakes a position on what to build or why that a knowledgeable stakeholder could reasonably challenge -- not merely describing a task or restating known requirements:
- Problem framing where the stated need is non-obvious or debatable, not self-evident from existing context
- Solution selection where alternatives plausibly exist (implicit or explicit)
- Prioritization decisions that explicitly rank what gets built vs deferred
- Goal statements that predict specific user outcomes, not just restate constraints or describe deliverables

*Leg 2 — Strategic weight:* The proposed work could affect system trajectory, user perception, or competitive positioning, even if the premise is sound:
- Changes that shape how the system is perceived or what it becomes known for
- Complexity or simplicity bets that affect adoption, onboarding, or cognitive load
- Work that opens or closes future directions (path dependencies, architectural commitments)
- Opportunity cost implications -- building this means not building something else

**design-lens** -- activate when the document contains:
- UI/UX references, frontend components, or visual design language
- User flows, wireframes, screen/page/view mentions
- Interaction descriptions (forms, buttons, navigation, modals)
- References to responsive behavior or accessibility

**security-lens** -- activate when the document contains:
- Auth/authorization mentions, login flows, session management
- API endpoints exposed to external clients
- Data handling, PII, payments, tokens, credentials, encryption
- Third-party integrations with trust boundary implications

**scope-guardian** -- activate when the document contains:
- Multiple priority tiers (P0/P1/P2, must-have/should-have/nice-to-have)
- Large requirement count (>8 distinct requirements or implementation units)
- Stretch goals, nice-to-haves, or "future work" sections
- Scope boundary language that seems misaligned with stated goals
- Goals that don't clearly connect to requirements

**adversarial** -- activate when the document contains a high-value challenge surface, not merely structural complexity. Routine plans with stated rationale are not by themselves an adversarial signal — premise/assumption work re-litigates settled questions when the only signal is "this plan is well-structured." Activate when ANY of the following holds:

- The document is a **requirements document** with 2+ challengeable claims (problem framing, solution selection, prioritization, predicted outcomes) -- premise scrutiny is core to the brainstorm phase
- The document touches a **high-stakes domain** -- auth, payments, billing, data migrations, privacy/compliance, external integrations, cryptography -- regardless of doc type or size
- The document **proposes a new abstraction, framework, or significant architectural pattern** -- regardless of doc type
- The document is a **plan with no `origin:` requirements doc** (greenfield bootstrap) -- premise wasn't validated upstream
- The document is a **plan that explicitly extends scope** beyond its origin requirements doc (new actors, new flows, deferred-then-restored features)
- The document contains an **explicit alternatives section** or unresolved tradeoffs -- adversarial helps stress-test the chosen direction

Do NOT activate adversarial on a routine plan document that derives from a validated origin requirements doc, stays within scope, and does not introduce high-stakes domains or new abstractions. The plan's structural decisions (more units, more rationale) are not by themselves adversarial signal -- those are the plan doing its job.

## Phase 2: Announce and Dispatch Personas

### Announce the Review Team

Tell the user which personas will review and why. For conditional personas, include the justification:

```
Reviewing with:
- tunan:coherence-reviewer (always-on)
- tunan:feasibility-reviewer (always-on)
- tunan:scope-guardian-reviewer -- plan has 12 requirements across 3 priority levels
- tunan:security-lens-reviewer -- plan adds API endpoints with auth flow
```

### Build Agent List

Always include:
- `tunan:coherence-reviewer`
- `tunan:feasibility-reviewer`

Add activated conditional personas:
- `tunan:product-lens-reviewer`
- `tunan:design-lens-reviewer`
- `tunan:security-lens-reviewer`
- `tunan:scope-guardian-reviewer`
- `tunan:adversarial-document-reviewer`

### Dispatch

Dispatch agents using **bounded parallelism** with the platform's subagent primitive (e.g., `Agent` in Claude Code, `spawn_agent` in Codex, `subagent` in Pi via the `pi-subagents` extension). Omit the `mode` parameter so the user's configured permission settings apply. Respect the current harness's active-subagent limit: queue selected reviewers, dispatch only as many as the harness accepts, and fill freed slots as reviewers complete. Treat active-agent/thread/concurrency-limit spawn errors as backpressure, not reviewer failure: leave the reviewer queued and retry after a slot frees. Record a reviewer as failed only after a successful dispatch times out/fails, or when dispatch fails for a non-capacity reason.

Each agent receives the prompt built from the subagent template included below with these variables filled:

| Variable | Value |
|----------|-------|
| `{persona_file}` | Full content of the agent's markdown file |
| `{schema}` | Content of the findings schema included below |
| `{document_type}` | "requirements" or "plan" from Phase 1 classification |
| `{document_path}` | Path to the document |
| `{origin_path}` | Value of the document's `origin:` frontmatter field if present, or the literal string `none` if absent. Personas that adapt on origin (product-lens, adversarial, scope-guardian) read this slot to gate technique suppression — they do NOT re-parse frontmatter themselves. Extract this once during Phase 1 reading. |
| `{document_content}` | Full text of the document |
| `{decision_primer}` | Cumulative prior-round decisions in the current session, or an empty `<prior-decisions>` block on round 1. See "Decision primer" below. |

Pass each agent the **full document** — do not split into sections.

### Decision primer

On round 1 (no prior decisions), set `{decision_primer}` to:

```
<prior-decisions>
Round 1 — no prior decisions.
</prior-decisions>
```

On round 2+ (after one or more prior rounds in the current interactive session), accumulate prior-round decisions and render them as:

```
<prior-decisions>
Round 1 — applied (N entries):
- {section}: "{title}" ({reviewer}, {confidence})
  Evidence: "{evidence_snippet}"

Round 1 — rejected (M entries):
- {section}: "{title}" — Skipped because {reason}
  Evidence: "{evidence_snippet}"
- {section}: "{title}" — Deferred to Open Questions because {reason or "no reason provided"}
  Evidence: "{evidence_snippet}"
- {section}: "{title}" — Acknowledged without applying because {reason or "no suggested_fix — user acknowledged"}
  Evidence: "{evidence_snippet}"

Round 2 — applied (N entries):
...
</prior-decisions>
```

Each entry carries an `Evidence:` line because synthesis R29 (rejected-finding suppression) and R30 (fix-landed verification) both use an evidence-substring overlap check as part of their matching predicate — without the evidence snippet in the primer, the orchestrator cannot compute the `>50%` overlap test and has to fall back to fingerprint-only matching, which either re-surfaces rejected findings or suppresses too aggressively. The `{evidence_snippet}` is the first evidence quote from the finding, truncated to the first ~120 characters (preserving whole words at the boundary) and with internal quotes escaped. If a finding has multiple evidence entries, use the first one; the rest live in the run artifact and are not needed for the overlap check.

Accumulate across all rounds in the current session. Skip, Defer, and Acknowledge actions all count as "rejected" for suppression purposes — each signals the user decided the finding wasn't worth actioning this round (Acknowledge is the no-fix-guard variant: the user saw a finding with no `suggested_fix`, chose not to defer or skip explicitly, and recorded acknowledgement instead; for round-to-round suppression that is semantically equivalent to Skip). Applied findings stay on the applied list so round-N+1 personas can verify fixes landed (see R30 in `references/synthesis-and-presentation.md`).

Cross-session persistence is out of scope. A new invocation of doc-review on the same document starts with a fresh round 1 and no carried primer, even if prior sessions deferred findings into the document's Open Questions section.

**Error handling:** If an agent fails or times out, proceed with findings from agents that completed. Note the failed agent in the Coverage section. Do not block the entire review on a single agent failure.

**Dispatch limit:** Even at maximum (7 agents), use bounded parallel dispatch. If the harness cap is lower than the selected team size, queue the remainder and launch them as active reviewers complete.

## Phases 3-5: Synthesis, Presentation, and Next Action

After all dispatched agents return, read `references/synthesis-and-presentation.md` for the synthesis pipeline (validate, anchor-based gate, dedup, cross-persona agreement promotion, resolve contradictions, auto-promotion, route by three tiers with FYI subsection), `safe_auto` fix application, the SYNC-BACK step that pushes the edited working file to the issue body when the source is an issue, headless-envelope output, and the handoff to the routing question.

For the four-option routing question and per-finding walk-through (interactive mode), read `references/walkthrough.md`. For the bulk-action preview used by best-judgment routing, Append-to-Open-Questions, and walk-through `Auto-resolve with best judgment on the rest`, read `references/bulk-preview.md`. Do not load these files before agent dispatch completes.

---

## Included References

### Subagent Template

@./references/subagent-template.md

### Findings Schema

@./references/findings-schema.json
