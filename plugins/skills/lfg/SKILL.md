---
name: lfg
description: Run the full autonomous engineering pipeline end-to-end (plan, work, code review, test, commit, push, open PR, watch CI, fix CI failures until green). Use only when the user explicitly requests hands-off execution of a software task and provides a feature description; do not auto-route casual conversation here.
argument-hint: "[feature description]"
---

CRITICAL: You MUST execute every step below IN ORDER. Do NOT skip any required step. Do NOT jump ahead to coding or implementation. The plan phase (step 1) MUST be completed and verified BEFORE any work begins. Violating this order produces bad output.

When invoking any skill referenced below, resolve its name against the available-skills list the host platform provides and use that exact entry. Some platforms list skills under a plugin namespace (e.g., `yunxing:plan`); others list the bare name. Invoking a short-form guess that isn't in the list will fail — always match a listed entry verbatim before calling the Skill/Task tool.

**Artifact model: one feature, one issue — the pipeline chains via comments on that issue, not separate issues or local files.** A feature is a **single GitHub issue** for its whole lifetime. Its NUMBER `#N` — the **feature issue** — is the one handle threaded through every stage. The requirement is the issue **body**; each later stage lands as a **marker comment** on the same issue and adds a label. There are **no** separate `yunxing:plan` or `yunxing:solution` issues:

- `brainstorm` produces the feature issue (body = requirement, label `yunxing:req`)
- `plan` consumes the feature issue and writes the plan as a **comment** on it (first line `<!-- yunxing:plan -->`, label `yunxing:plan` added)
- `work` consumes the same feature issue, reading its plan comment
- `compound` writes the solution as a **comment** on the same feature issue (first line `<!-- yunxing:solution -->`, label `yunxing:solution` added)

Every stage receives the **same feature issue `#N`** — never a freshly-minted plan or solution number. A stage's "done" is verified by checking the feature issue for its marker comment and label, not by listing a separate issue. There is no local-file fallback for these artifacts — never read or write a plan/req/solution as a local file.

**GH PREFLIGHT (required — run before step 1; the pipeline depends on `gh`).** Run these in order; if any fails, abort the pipeline and tell the user to fix the gh setup (install `gh`, run `gh auth login`, or set the repo). Do NOT fall back to local files:

```bash
gh --version
```
```bash
gh auth status
```
```bash
gh repo view --json nameWithOwner
```

1. Invoke the `plan` skill with `$ARGUMENTS`. If a prior `brainstorm` ran in this pipeline and produced a feature issue, pass that issue ref so the plan consumes it and writes its plan comment onto the same `#<N>`. When no upstream feature issue exists, `plan` creates the feature issue itself (requirement stub body) before writing the plan comment.

   GATE: STOP. If plan reported the task is non-software and cannot be processed in pipeline mode, stop the pipeline and inform the user that LFG requires software tasks. Otherwise, **record the feature issue ref (`#<N>`/URL)** that `plan` reports, then verify the plan landed as a comment on it — confirm both the marker comment and the label are present:

   ```bash
   gh api repos/{owner}/{repo}/issues/<N>/comments --jq '.[] | select(.body | startswith("<!-- yunxing:plan -->")) | .id'
   ```

   A non-empty id confirms the plan comment landed. To double-check the label accumulated, read the feature issue's labels:

   ```bash
   gh issue view <N> --json labels
   ```

   If the feature issue carries no `<!-- yunxing:plan -->` comment (the first command returns empty), invoke `plan` again with `$ARGUMENTS`. Do NOT proceed to step 2 until the plan comment exists on the feature issue. The feature issue ref `#<N>` is the single handle passed to work in step 2, to code-review in step 3, and to compound in step 9 — there is no separate plan number.

2. Invoke the `work` skill with the **feature issue ref `#<N>`** from step 1 as its work source. `work` reads the plan comment (`<!-- yunxing:plan -->`) on that issue.

   GATE: STOP. Verify that implementation work was performed - files were created or modified beyond the plan. Do NOT proceed to step 3 if no code changes were made.

3. Invoke the `code-review` skill with `mode:agent plan:<feature-issue-ref-from-step-1>`.

   Pass the feature issue ref `#<N>` from step 1 so code-review reads its plan comment and can verify requirements completeness. Read the **Actionable Findings** summary the skill emits.

4. **Apply and persist review fixes** (REQUIRED after step 3, before residual handoff)

   Load `references/review-followup.md` and execute step 4 there (mechanical apply + commit/push when changes exist). Do not proceed to step 5, run browser tests, or output DONE while eligible review fixes remain only in the working tree uncommitted.

5. **Autonomous residual handoff** (only when step 3 reported one or more actionable `downstream-resolver` findings not applied in step 4; skip when it reported `Actionable findings: none.`)

   Do not prompt the user. This step embraces the autopilot contract: residuals must become durable before DONE, but the agent never stops to ask.
   1. Load `references/tracker-defer.md` in **non-interactive mode**. Pass the residual actionable findings from step 3/4 (or the run artifact when the summary was truncated).
   2. Collect the structured return: `{ filed: [...], failed: [...], no_sink: [...] }`.
   3. Compose a `## Residual Review Findings` markdown section from the structured return:
      - For each item in `filed`: a bullet with severity, file:line, title, and a link to the tracker ticket URL.
      - For each item in `failed`: a bullet with severity, file:line, title, and the failure reason (e.g., `Defer failed: gh returned 401 — tracker unavailable`).
      - For each item in `no_sink`: a bullet with severity, file:line, and title inlined verbatim so the PR body or fallback file is the durable record.
   4. Detect the current branch's open PR without prompting:

      ```bash
      gh pr view --json number,url,body,state
      ```

   5. If an open PR exists, update it directly with `gh`; do not load any confirmation-driven PR update skill. Append or replace the `## Residual Review Findings` section in the current PR body, write the new body to an OS temp file, then run:

      ```bash
      gh pr edit PR_NUMBER --body-file BODY_FILE
      ```

   6. If no open PR exists, record the residuals as a `yunxing:review` GitHub issue — never a local file. Run the GH preflight first (`gh` installed; `gh auth status` exits 0; `gh repo view --json nameWithOwner` resolves); if any check fails, stop and report the gh setup problem. Ensure the label exists:

      ```bash
      gh label list --search "yunxing:review"
      ```

      If absent, create it:

      ```bash
      gh label create "yunxing:review" --color 1f883d --description "yunxing review"
      ```

      Write the composed `## Residual Review Findings` section plus the source PR-review run context to an OS temp file (`${TMPDIR:-/tmp}` / `$env:TEMP`), then create the issue titled `[review] <branch-or-head-sha>`:

      ```bash
      gh issue create --title "[review] <branch-or-head-sha>" --label "yunxing:review" --body-file BODY_FILE
      ```

      When the feature issue ref `#<N>` from step 1 is known, reference it with `#<N>` in the `yunxing:review` issue body and also post the findings as a comment on that feature issue:

      ```bash
      gh issue comment FEATURE_NUMBER --body-file BODY_FILE
      ```

      This is the durable no-PR sink. Do not output DONE until either the existing PR body has been updated or this `yunxing:review` issue has been created. If both paths fail, stop and report the failed commands; do not silently proceed.

   Never block DONE on tracker filing failures once residuals have been durably recorded. A `no_sink` outcome is success only when the findings are present in the PR body or in the created `yunxing:review` issue.

6. Invoke the `test-browser` skill with `mode:pipeline`.

7. Invoke the `commit-push-pr` skill.

   This commits any remaining changes, pushes the branch, and opens a pull request. If step 5 already opened a PR (check with `gh pr view --json number,url,state 2>/dev/null`), skip PR creation but still commit and push any uncommitted changes.

8. **CI watch and autofix loop** (only when an open PR exists for the current branch)

   Detect the PR; if none exists or `gh` is unavailable, skip this step entirely and proceed to step 9.

   ```bash
   gh pr view --json number,url,state
   ```

   For up to **3 fix iterations**, repeat:
   1. Wait for CI to complete:

      ```bash
      gh pr checks --watch
      ```

      If the command exits 0, all checks passed. Break out of the loop and proceed to step 9.

      If it exits non-zero, one or more checks failed. Continue to (2).

   2. Identify failing checks and pull their failure logs. Use `gh pr checks --json name,state,conclusion,workflow,link` to enumerate failures, then for each failing check read the run logs:

      ```bash
      gh run view <run-id> --log-failed
      ```

      where `<run-id>` is parsed from the check's details URL or workflow run.

   3. Read the failure logs, identify the root cause, and apply a fix in the working tree. Do NOT weaken, skip, or mock the failing assertion to make it pass — repair the actual issue. If the failure is a flaky test that has no fix path, document that as the residual outcome below rather than retrying without a code change.

   4. Stage only the files you changed, commit, and push:

      ```bash
      git add <changed-files>
      git commit -m "fix(ci): <one-line summary of the failure repaired>"
      git push
      ```

   5. Return to iteration (1) with the next attempt counter.

   GATE: STOP iterating after 3 failed attempts. If CI is still red after 3 fix cycles:
   - Compose a `## CI Failures Unresolved` markdown section listing each remaining failing check, the failure summary, and the run/check URL.
   - Append or replace this section in the PR body, write the new body to an OS temp file, then run:

     ```bash
     gh pr edit PR_NUMBER --body-file BODY_FILE
     ```

   - Do NOT continue looping. The autopilot contract is "make residuals durable, then exit." Proceed to step 9.

9. Invoke the `compound` skill to capture the solved problem.

   Pass it the **feature issue ref `#<N>`** from step 1, the PR URL, and a short summary of what was built. `compound` runs its own GH preflight and writes the solution as a **comment** on that same feature issue (first line `<!-- yunxing:solution -->`, label `yunxing:solution` added) — not a separate issue or a local file. If `compound` is unavailable on the harness, note that compounding was skipped — do not write a local solution file.

10. Output `<promise>DONE</promise>` when complete. Include the chain in the summary: the **feature issue `#<N>`** (carrying its req body plus `yunxing:plan` and `yunxing:solution` comments) and the PR URL — a single issue handle, not three separate issue numbers.

Start with step 1 now. Remember: GH preflight and plan FIRST, then work. Never skip the plan.
