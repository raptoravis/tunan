# Plan Handoff

This file contains post-plan-writing instructions: document review, final checks, and post-generation handoff. Load it after the plan comment has been created/updated and the confidence check (5.3.1-5.3.7) is complete.

The plan is a comment on the feature issue `#N` (the `yunxing:req` issue), whose body is markdown with the marker `<!-- yunxing:plan -->` as its first line. All review and handoff operates on that plan comment — there is no local `.md` or `.html` plan file. See `references/comment-chain-storage.md` for the read/PATCH gh recipes.

## 5.3.8 Document Review

Run the `doc-review` skill with `mode:headless` on the plan comment. Export the plan comment body to a temp file (find its id, then `gh api repos/{owner}/{repo}/issues/comments/<comment-id> --jq '.body' > <tmpfile>`); the reviewer reads that file and applies `safe_auto` fixes back to the plan comment via `gh api repos/{owner}/{repo}/issues/comments/<comment-id> -X PATCH -F body=@<tmpfile>`. Pass the feature issue ref plus `mode:headless` as the skill arguments. When this step is reached, it is mandatory — do not skip it because the confidence check already ran. The two tools catch different classes of issues.

Headless is the default at this phase because most users want to start work after planning, not adjudicate every reviewer concern up front. Headless applies `safe_auto` fixes silently and returns structured findings text — no walkthrough, no per-finding routing, no blocking prompts. The post-generation menu (see 5.4) offers `Run deeper doc review` as a first-class option so users can opt into the full interactive walkthrough when they want it.

The confidence check and doc-review are complementary:

- The confidence check strengthens rationale, sequencing, risk treatment, and grounding
- Document-review checks coherence, feasibility, scope alignment, and surfaces role-specific issues

Capture the headless envelope so it can drive the contextual summary above the post-generation menu:

- The number of fixes auto-applied
- The count of remaining findings, broken out by user-facing bucket (proposed fixes, decisions, FYI observations)
- The severity breakdown of decisions and proposed fixes (specifically the P0/P1 count, since those benefit from explicit user attention)

When doc-review returns "Review complete", proceed to Final Checks.

**Pipeline mode:** Pipeline runs (LFG or any `disable-model-invocation` context) invoke `doc-review` with `mode:headless` and the feature issue ref. No further routing is offered in pipeline mode; the caller decides what to do with the returned findings. Address any P0/P1 findings before returning control to the caller.

## 5.3.9 Final Checks and Cleanup

Before proceeding to post-generation options:

- Confirm the plan is stronger in specific ways, not merely longer
- Confirm the planning boundary is intact
- Confirm origin decisions were preserved when a requirement issue was bound (the `Requirement: #<reqN>` body link and the carried-forward requirements)

If artifact-backed mode was used (per-run OS-temp scratch directory for sub-agent research):

- Clean up the temporary scratch directory after the plan comment is safely updated
- If cleanup is not practical on the current platform, note where the artifacts were left

After all mutations in this run have settled (initial create/update, deepening synthesis, doc-review `safe_auto` fixes, HITL Proof resync if any), the plan comment reflects the final state.

## 5.4 Post-Generation Options

**Pipeline mode:** If invoked from an automated workflow such as LFG or any `disable-model-invocation` context, skip the interactive menu below and return control to the caller immediately, passing the feature issue ref. The plan comment has already been created/updated, the confidence check has already run, and doc-review has already run — the caller (e.g., lfg) determines the next step.

**Summary line above the menu (always):** Print a single concise line summarizing the headless review state — e.g., `Doc review applied 3 fixes. 2 decisions, 1 proposed fix, 4 FYI observations remain (1 at P1).` When no fixes were applied and no findings remain, print `Doc review clean — no fixes needed.` This line establishes what the autofix pass did (or didn't) so the user has the context to choose between the menu options below.

**Question:** "Plan comment ready on `#<N>`: `<feature issue URL>`. What would you like to do next?"

**Options:**

1. **Start `/yunxing:work`** (recommended) - Begin implementing this plan in the current session
2. **Run deeper doc review** - Walk through the remaining findings interactively (full doc-review walkthrough)
3. **Open in Proof (web app) — review and comment to iterate with the agent** - Export the plan body to Every's Proof editor, iterate with the agent via comments, then sync edits back to the plan comment.
4. **Done for now** - Pause; the plan comment is saved and can be resumed later by the feature issue ref

**Menu rendering:** The menu has 4 options, within the `AskUserQuestion` cap — route it through the platform's blocking question tool (`AskUserQuestion` in Claude Code — call `ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded; `request_user_input` in Codex; `ask_user` in Gemini; `ask_user` in Pi). When the platform's blocking tool is unavailable or errors (e.g., Codex edit modes where `request_user_input` is not exposed), fall back to a numbered list in chat with the hint "Pick a number or describe what you want." Never silently skip the question.

**Hide `Run deeper doc review` when no actionable findings remain.** Show option 2 only when the headless envelope reports `proposed_fixes_count + decisions_count > 0` — i.e., at least one `gated_auto` or `manual` finding at confidence anchor `75` or `100`. Drop the option in any other case, including FYI-only state. FYI observations (anchor `50`) do not enter `doc-review`'s interactive routing question or walkthrough — that flow is gated to actionable findings — so a `Run deeper doc review` option that only has FYIs to show is a dead-end. When option 2 is dropped, the menu becomes 3 options (1, 3, 4 above) and renumbers 1-3 in display so users see a clean sequence. The summary line above the menu still names the FYI count when present so the user sees what was found.

Based on selection (the bare per-option routing is also stated inline in the SKILL.md so it cannot be missed when this reference is not loaded; the elaborate sub-flows below are the reason this reference still exists):

- **Start `/yunxing:work`** -> Invoke the `work` skill via the platform's skill-invocation primitive (`Skill` in Claude Code, `Skill` in Codex, the equivalent on Gemini/Pi), passing the feature issue ref (`#<N>` or its URL) as the skill argument. Do not merely tell the user to type `/yunxing:work` — fire the invocation now so the plan executes in this session.
- **Run deeper doc review** -> Re-invoke the `doc-review` skill on the feature issue ref **without** `mode:headless` so the interactive routing question and walkthrough fire. The headless pass already applied `safe_auto` fixes to the plan comment and recorded its findings in the session, so the interactive pass picks up where headless stopped — its R29 suppression rule prevents prior-round Skipped/Deferred entries from re-raising. After it returns (with any edits synced back to the plan comment), re-render this menu with the refreshed counts so the user can pick what to do next.
- **Open in Proof (web app) — review and comment to iterate with the agent** -> Export the plan comment body to a transient markdown file in the OS temp dir (bash `${TMPDIR:-/tmp}/yunxing-plan-<N>.md`, PowerShell `$env:TEMP\yunxing-plan-<N>.md`) — find the plan comment id and `gh api repos/{owner}/{repo}/issues/comments/<comment-id> --jq '.body' > <tmpfile>`. Load the `proof` skill in HITL-review mode with:
  - source file: the exported temp markdown file
  - doc title: `Plan: <plan title from the comment frontmatter>`
  - identity: `ai:yunxing` / `Compound Engineering`
  - recommended next step: `/yunxing:work` (shown in the proof skill's final terminal output)

  Follow `references/hitl-review.md` in the proof skill. It uploads the plan markdown, prompts the user for review in Proof's web UI, ingests filtered comment threads, applies agreed edits through the current Proof edit APIs, replies/resolves in-thread, and syncs the final markdown back to the temp file on proceed.

  When the proof skill returns, sync the reviewed markdown back to the plan comment (PATCH it in place by id) and clean up the temp file:
  - `status: proceeded` with `localSynced: true` -> the temp markdown now reflects the review. Overwrite the plan comment with it via `gh api repos/{owner}/{repo}/issues/comments/<comment-id> -X PATCH -F body=@<tmpfile>`. Then re-run `doc-review` on the updated plan comment before re-rendering the menu — HITL can materially rewrite the plan body, so the prior doc-review pass no longer covers the current content and section 5.3.8 requires a review before any handoff option is offered. Then return to the post-generation options with the refreshed residual findings.
  - `status: proceeded` with `localSynced: false` -> the reviewed version lives in Proof at `docUrl` but the temp copy is stale. Offer to pull the Proof doc to the temp file using the proof skill's Pull workflow. If the pull happened, PATCH the plan comment with it via `gh api repos/{owner}/{repo}/issues/comments/<comment-id> -X PATCH -F body=@<tmpfile>` and re-run `doc-review` on the updated plan comment before re-rendering (same 5.3.8 rationale). If the pull was declined, include a one-line note above the menu that the plan comment is stale vs. Proof — otherwise `Start /yunxing:work` will silently use the pre-review body.
  - `status: done_for_now` -> the plan comment may be stale if the user edited in Proof before leaving. Offer to pull the Proof doc and PATCH the plan comment so it stays in sync. If the pull happened, PATCH the comment and re-run `doc-review` before re-rendering (same 5.3.8 rationale). If the pull was declined, include the stale note above the menu. `done_for_now` means the user stopped the HITL loop — it does not mean they ended the whole plan session; they may still want to start work.
  - `status: aborted` -> clean up the temp file and fall back to the options without changes to the plan comment.

  If the initial upload fails (network error, Proof API down), retry once after a short wait. If it still fails, tell the user the upload didn't succeed and briefly explain why, then return to the options — don't leave them wondering why the option did nothing.

- **Done for now** -> Display a brief confirmation that the plan is saved (show the feature issue URL) and end the turn. Do not start follow-up work without an explicit further user prompt.
- **Free-form prompts that target the findings** (e.g., the user types "review", "walk through", "deep review" instead of picking a numbered option) -> route as if they had picked `Run deeper doc review`. Do not loop back to the menu without firing the deeper review.
- **Other free-form input** -> Accept revisions to the plan (PATCH the plan comment in place via `gh api repos/{owner}/{repo}/issues/comments/<comment-id> -X PATCH -F body=@<tmpfile>`) and loop back to options.
