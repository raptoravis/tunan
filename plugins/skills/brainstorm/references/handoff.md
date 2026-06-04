# Handoff

This content is loaded when Phase 4 begins — after the `yunxing:req` issue is written (or skipped).

The durable requirement is a **`yunxing:req` GitHub issue**, not a local file. Everything downstream is keyed off the issue ref — pass the issue NUMBER/URL, never a file path. `REQ_ISSUE` below is the bound issue (number + URL) captured at Phase 3 (created or updated). When no issue was warranted, `REQ_ISSUE` is empty and the doc-dependent options are hidden.

---

#### 4.1 Present Next-Step Options

The Phase 4 menu's visible option count varies by state: no `REQ_ISSUE` hides the review and Proof options; unresolved `Resolve Before Planning` hides `Plan implementation` and `Build it now`; a failing direct-to-work gate hides `Build it now`. Count the visible options for the current state and choose the rendering mode accordingly:

- **4 or fewer visible:** use the platform's blocking question tool (`AskUserQuestion` in Claude Code — call `ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded; `request_user_input` in Codex; `ask_user` in Gemini, `ask_user` in Pi (requires the `pi-ask-user` extension)). This is the default.
- **5 or more visible:** render as a numbered list in chat. This is the narrow option-overflow fallback; trimming would hide legitimate choices (plan, review, Proof, build, refine, pause are all distinct destinations). Include a hint that free-form input is accepted ("Pick a number or describe what you want.") so the numbered list retains the blocking tool's open-endedness.

Never silently skip the question.

If `Resolve Before Planning` contains any items:

- Ask the blocking questions now, one at a time, by default
- If the user explicitly wants to proceed anyway, first convert each remaining item into an explicit decision, assumption, or `Deferred to Planning` question (written back to the issue body)
- If the user chooses to pause instead, present the handoff as paused or blocked rather than complete
- Do not offer the `Plan implementation` or `Build it now` options while `Resolve Before Planning` remains non-empty

In both preambles below, the "Pick a number or describe what you want." hint applies only in numbered-list mode. When using the blocking tool, omit that line and pass the remaining stem as the question.

**Reference format:** Cite the requirement by issue ref — `#<N>` and its URL — so it is clickable. Never print a local file path.

**Preamble when no blocking questions remain:**

```
Brainstorm complete.

Requirement: #<N> — <issue URL>  # omit line if no issue was created

What would you like to do next? (Pick a number or describe what you want.)
```

**Preamble when blocking questions remain and user wants to pause:**

```
Brainstorm paused. Planning is blocked until the remaining questions are resolved.

Requirement: #<N> — <issue URL>  # omit line if no issue was created

What would you like to do next? (Pick a number or describe what you want.)
```

Present only the options that apply. Renumber so visible options stay contiguous starting at 1.

1. **Plan implementation with `plan` (Recommended)** - Move to `plan` for structured implementation planning. Shown only when `Resolve Before Planning` is empty.
2. **Agent review of the requirement with `doc-review`** - Dispatch reviewer agents to check the requirement for coherence, feasibility, scope, and other persona-specific issues; apply safe fixes back to the issue body; route remaining findings interactively. Shown only when `REQ_ISSUE` exists.
3. **Open in Proof — review and comment to iterate with the agent** - Export the issue body to a temp markdown file, iterate with the agent via comments in Every's Proof editor, then sync the reviewed markdown back to the issue. Shown only when `REQ_ISSUE` exists.
4. **Build it now with `work` (skip planning)** - Skip planning and move to `work`; suited to lightweight, well-defined changes. Shown only when `Resolve Before Planning` is empty **and** scope is lightweight, success criteria are clear, scope boundaries are clear, and no meaningful technical or research questions remain (the "direct-to-work gate").
5. **More clarifying questions to sharpen the requirement** - Keep refining scope, edge cases, constraints, and preferences through further dialogue. Always shown.
6. **Done for now** - Pause; the requirement issue is saved and can be resumed later by passing its ref to `brainstorm`. Always shown.

**Post-review nudge (subsequent rounds only):** If the user has already run `doc-review` this session and residual P0/P1 findings remain unaddressed, add a one-line prose nudge adjacent to the menu (e.g., "Document review flagged 2 P1 findings you may want to address — pick \"Agent review of the requirement\" to run another pass."). Reference the option by label, not number: the menu renumbers when `Resolve Before Planning` hides `Plan implementation` and `Build it now`, so a hardcoded option number can point users at the wrong action. Do not add a separate menu option; reuse the existing agent-review option.

#### 4.2 Handle the Selected Option

Selections may be the literal option label (when the user types the label or a close paraphrase) or the option number. Match numbers against the currently-rendered (post-trim) list. Free-form input that doesn't match an option or describe an alternative action should be treated as clarification — ask a follow-up rather than guessing.

**If user selects "Plan implementation with `plan` (Recommended)":**

Immediately load the `plan` skill in the current session. Pass the requirement issue ref (`#<N>` or URL) when one exists; otherwise pass a concise summary of the finalized brainstorm decisions. The req issue **is** the feature issue: `plan` reads its body for the requirement and writes the plan as a **comment** on this same issue (first line `<!-- yunxing:plan -->`), adding the `yunxing:plan` label — it does **not** create a separate plan issue. The feature issue `#<N>` is what flows downstream. Do not print the closing summary first.

**If user selects "Agent review of the requirement with `doc-review`":**

Load the `doc-review` skill, passing the requirement issue ref as the argument. The reviewer reads the issue body, and findings are applied back to the issue body (via `gh issue edit <N> --body-file <tmpfile>`). When doc-review returns "Review complete", return to the Phase 4 options and re-render the menu (the issue may have changed, so re-evaluate `Resolve Before Planning`, direct-to-work gate, and residual findings). If residual P0/P1 findings remain unaddressed, include the post-review nudge above the menu. Do not show the closing summary yet.

**If user selects "Build it now with `work` (skip planning)":**

Immediately load the `work` skill in the current session using the finalized brainstorm output as context. If a `REQ_ISSUE` exists, pass its ref (`#<N>` or URL); `work` reads the requirement from the issue and references it back by `#<N>`. Do not print the closing summary first.

**If user selects "More clarifying questions to sharpen the requirement":** Return to Phase 1.3 (Collaborative Dialogue) and continue asking the user clarifying questions one at a time to further refine scope, edge cases, constraints, and preferences. Continue until the user is satisfied, then return to Phase 4. When the dialogue changes the requirement, sync the updated body back to the issue (`gh issue edit <N> --body-file <tmpfile>`). Do not show the closing summary yet.

**If user selects "Open in Proof — review and comment to iterate with the agent":**

Export the issue body to a transient markdown file in the OS temp dir (bash `${TMPDIR:-/tmp}`, PowerShell `$env:TEMP`):

```bash
gh issue view <N> --json body --jq .body > "${TMPDIR:-/tmp}/req-<N>.md"
```

Then load the `proof` skill in HITL-review mode with:

- **source file:** the temp markdown file just exported
- **doc title:** `Requirements: <topic title>`
- **identity:** `ai:yunxing` / `Compound Engineering`
- **recommended next step:** `plan` (shown in the proof skill's final terminal output)

Follow `references/hitl-review.md` in the proof skill. It uploads the markdown, prompts the user for review in Proof's web UI, ingests filtered comment threads, applies agreed edits through the current Proof edit APIs, replies/resolves in-thread, and syncs the final markdown back to the temp file atomically on proceed.

When the proof skill returns control, **sync the reviewed markdown back to the issue body** and then re-render the Phase 4 menu:

- `status: proceeded` with `localSynced: true` → the temp markdown reflects the review. Write it back to the issue: `gh issue edit <N> --body-file "${TMPDIR:-/tmp}/req-<N>.md"`. Return to the Phase 4 options and re-render the menu (the requirement may have changed substantially during review, so option eligibility can shift — re-evaluate `Resolve Before Planning`, direct-to-work gate, and residual doc-review findings against the updated issue).
- `status: proceeded` with `localSynced: false` → the reviewed version lives in Proof at `docUrl` but the temp copy is stale. Offer to pull the Proof doc to the temp file using the proof skill's Pull workflow, then write it back to the issue with `gh issue edit`. Re-render the Phase 4 menu after the pull + sync completes (or is declined). If declined, include a one-line note above the menu that issue #<N> does not yet reflect the Proof review.
- `status: done_for_now` → the temp copy may be stale if the user edited in Proof before leaving. Offer to pull the Proof doc to the temp file and sync it back to the issue, then return to the Phase 4 options. If declined, include the stale note above the menu. `done_for_now` means the user stopped the HITL loop without syncing — it does not mean they ended the whole brainstorm.
- `status: aborted` → fall back to the Phase 4 options without changes (the issue body is unchanged).

If the initial upload fails (network error, Proof API down), retry once after a short wait. If it still fails, tell the user the upload didn't succeed and briefly explain why, then return to the Phase 4 options — don't leave them wondering why the option did nothing. The issue body remains the source of truth in that case.

**If user selects "Done for now":** Display the closing summary (see 4.3) and end the turn.

#### 4.3 Closing Summary

Use the closing summary only when this run of the workflow is ending or handing off, not when returning to the Phase 4 options.

In both templates below, substitute `#<N> — <issue URL>` with the actual requirement issue created or updated this run.

When complete and ready for planning, display:

```text
Brainstorm complete!

Requirement: #<N> — <issue URL>  # omit line if no issue was created

Key decisions:
- [Decision 1]
- [Decision 2]

Recommended next step: `plan #<N>`
```

If the user pauses with `Resolve Before Planning` still populated, display:

```text
Brainstorm paused.

Requirement: #<N> — <issue URL>  # omit line if no issue was created

Planning is blocked by:
- [Blocking question 1]
- [Blocking question 2]

Resume with `brainstorm #<N>` when ready to resolve these before planning.
```
