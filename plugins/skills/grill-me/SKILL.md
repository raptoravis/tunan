---
name: grill-me
description: "A relentless one-question-at-a-time interview to stress-test and sharpen a plan, design, or document. Use when the user wants to pressure-test thinking before building, says 'grill me', 'stress-test this', 'poke holes in this', 'challenge my plan', 'devil's advocate', or references any plan/design/doc they want sharpened through adversarial Q&A. Complementary to `doc-review` (parallel persona review) — grill-me is sequential, interactive, and the user answers each question before the next one fires."
argument-hint: "[#<N> | <issue-url> | path/to/document.md | nothing — grills the active plan or conversation context]"
---

# Grill a Plan or Design

Grill the user relentlessly about a plan, design, or document — one question at a time, with a recommended answer attached to each. Walk down every branch of the design tree, resolving dependencies between decisions one-by-one, until the plan can withstand real-world contact.

This is **sequential adversarial Q&A**, not parallel batch review. The user answers each question before the next one fires. The agent's job is to find the unexamined corners, surface unstated assumptions, and force the user to defend (or revise) every load-bearing decision.

Complementary to `doc-review`: doc-review dispatches parallel persona agents and surfaces batch findings; grill-me walks the design tree interactively with the user present. Use grill-me when the user wants to be in the room for the stress test; use doc-review when they want a written report.

## Interaction Method

**Hard rule — every question goes through the platform's blocking question tool.** Use `AskUserQuestion` in Claude Code (call `ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded), `request_user_input` in Codex, `ask_user` in Gemini, `ask_user` in Pi (via `pi-ask-user`). Fall back to numbered options in chat only when no blocking tool exists in the harness or the call errors — never as a convenience.

**One question at a time.** Stacking questions produces diluted answers. Pick the single most useful question and fire it. Wait for the user's answer before choosing the next question.

**Alignment protocol.** Every question carries at least 3 ranked options with the single best one pre-selected as the default — place it first and append `(Recommended)` to its label. Load the `align` skill for the full protocol. The user accepts the optimal choice by confirming the default; they are not handed an open-ended choice.

**Open-ended escape.** A question may be genuinely open-ended (cannot write 3-4 distinct, plausible options without padding or strawmen). In that case, fire it as a single open-ended question with a free-text prompt — but still route it through the blocking question tool with `multiSelect: false` and a single option labeled "I'll type my answer" so the tool gate stays in place. Genuinely-open questions are rare in grilling — most questions are enumerable. Default to enumerated options.

## Source Resolution

Read the thing being grilled before asking any questions:

- **No argument, conversation context:** If the user has been discussing a plan or design in the current conversation, grill that context directly. Announce what you're grilling: "I'll grill the plan we've been discussing."
- **Issue ref** (`#<N>` or a GitHub issue URL): If the issue carries a `tunan:plan` label and a `<!-- tunan:plan -->` comment, the target is that plan comment — read it via `gh api repos/{owner}/{repo}/issues/<N>/comments --jq '.[] | select(.body | startswith("<!-- tunan:plan -->")) | .body'`. Otherwise, read the issue body via `gh issue view <N> --json body --jq .body`.
- **Local path** (`path/to/document.md`): read the file from disk.

If the source is unclear, ask what to grill.

## Grilling Discipline

### Before You Start

1. Read the document thoroughly. Form an internal map: what are the key claims, decisions, and assumptions?
2. Identify the load-bearing decisions — the ones where being wrong would cascade.
3. Classify the grilling depth:
   - **Light** — small document, low stakes, quick sanity check (3-5 questions)
   - **Standard** — normal plan or design (5-10 questions)
   - **Deep** — high-stakes, cross-cutting, or strategically important (10+ questions, full tree walk)

Announce the depth and give the user a chance to redirect before the first question.

### Question Crafting

Walk the design tree in dependency order — resolve foundational decisions before their dependents. Each question should:

1. **Target a specific, named decision or assumption** in the document — not a vague "have you thought about X?"
2. **Name the consequence of getting it wrong** — why this question matters
3. **Attach a recommended answer** — the option you believe is strongest, with a one-clause rationale
4. **Surface an unexamined alternative when one exists** — the non-obvious third path

Anti-patterns:
- "Have you considered security?" (vague, no stake)
- "What about edge cases?" (lazy, no specific edge case named)
- "Are you sure?" (no recommended answer, forces the user to re-defend without new information)

Good questions:
- "The plan assumes the payment gateway responds within 2s. Under peak load we've seen 8s+ timeouts. Which path: (A) add a circuit breaker at the gateway call (Recommended — one-and-done, no schema change), (B) make the whole flow async with a job queue, or (C) add a client-side timeout and retry UI?"
- "The design puts the mute toggle on the rule entity. If rule-delete silently drops pause state with no warning, operators won't notice until alerts go missing. Where should the checkpoint live: (A) warn on rule-delete when a mute is active (Recommended — lowest carrying cost), (B) move mute to a separate entity that survives rule-delete, or (C) accept the risk and document it?"

### Facts vs Decisions

Distinguish sharply between facts and decisions:

- **Facts** live in the codebase, docs, or runtime behavior. When a question hinges on a fact, look it up — explore the codebase, read the spec, check the logs. Present the finding as the recommended answer rather than asking the user.
- **Decisions** are the user's to make. Put each one to the user and wait for their answer. Never answer your own grilling questions.

The test: "can the codebase settle this?" — if yes, it's a fact; if no, it's a decision that needs the user's judgment.

### Don't Enact Until Confirmed

Do not enact the plan or apply any revisions until the user confirms the grilling has reached a shared understanding. Grilling sharpens the plan; it does not execute it. The user says when the grilling is done and what to do next.

### Exit Conditions

Continue until one of:
- The user says "done," "good," "ship it," or equivalent
- The user has accepted the recommended answer for 3+ consecutive questions without revision — offer to stop: "Three straight confirmations — the plan may be solid. Continue grilling or call it done?"
- You've walked every branch of the design tree and have no further specific, consequential questions

When done, offer to capture any revisions back to the source document (issue body, plan comment, or local file). Do NOT auto-write — the user decides.

## Output

No durable artifact is created by default — grill-me is a conversation, not a document generator. The user may optionally ask to:
- Apply agreed revisions to the source document
- Capture unresolved tensions as a comment or follow-up issue
- Feed the sharpened plan into the next stage (`/tunan:work`, `/tunan:plan`, etc.)
