---
name: lfg
description: Run the full autonomous engineering pipeline end-to-end (plan, work, code review, test, commit, push, open PR, watch CI, fix CI failures until green). Use only when the user explicitly requests hands-off execution of a software task and provides a feature description; do not auto-route casual conversation here.
argument-hint: "[feature description | #N to resume] [--hotfix | --tweak]"
---

CRITICAL: You MUST execute every step below IN ORDER. Do NOT skip any required step. Do NOT jump ahead to coding or implementation. The plan phase (step 1) MUST be completed and verified BEFORE any work begins. Violating this order produces bad output.

When invoking any skill referenced below, resolve its name against the available-skills list the host platform provides and use that exact entry. Some platforms list skills under a plugin namespace (e.g., `tunan:plan`); others list the bare name. Invoking a short-form guess that isn't in the list will fail — always match a listed entry verbatim before calling the Skill/Task tool.

**Artifact model: one feature, one issue — the pipeline chains via comments on that issue, not separate issues or local files.** A feature is a **single GitHub issue** for its whole lifetime. Its NUMBER `#N` — the **feature issue** — is the one handle threaded through every stage. The requirement is the issue **body**; each later stage lands as a **marker comment** on the same issue and adds a label. There are **no** separate `tunan:plan` or `tunan:solution` issues:

- `brainstorm` produces the feature issue (body = requirement, label `tunan:req`)
- `plan` consumes the feature issue and writes the plan as a **comment** on it (first line `<!-- tunan:plan -->`, label `tunan:plan` added)
- `work` consumes the same feature issue, reading its plan comment
- `compound` writes the solution as a **comment** on the same feature issue (first line `<!-- tunan:solution -->`, label `tunan:solution` added)

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

**Setup reminder (non-blocking).** If the repo root has no `.tunan/config.local.yaml`, this repo hasn't been through tunan setup — tell the user once, "This repo isn't set up for tunan yet; run `/tunan:setup` to configure it," then continue. A missing config is non-blocking and never aborts the pipeline.

**RESUME (run before step 1 when `$ARGUMENTS` references an existing feature issue — a bare `#N` / issue URL / "resume #N" — rather than a fresh feature description).** Do not re-run the whole pipeline from step 1 on an interrupted feature. Load the `resume` skill with that issue ref: it reads the issue's labels, marker comments, and any open PR to detect the phase (`plan` / `work` / `review-ci` / `done`) and reports which step to resume at. Then continue this pipeline from that step — skip any stage whose evidence already exists (a `<!-- tunan:plan -->` comment means step 1 is done; an open PR referencing the issue means steps 1–2 are done, resume at step 3; a `<!-- tunan:solution -->` comment means the feature is already complete — report and stop). When `$ARGUMENTS` is a new description, ignore this block and start at step 1.

**FAST PATHS (`--hotfix` / `--tweak` in `$ARGUMENTS`, also reachable as the named entry skills `/tunan:hotfix` and `/tunan:tweak` which delegate here).** Both keep the one-feature-one-issue chain intact — the plan comment must still land so `work` has a plan to read — but cut ceremony, mirroring comet's hotfix/tweak presets. `--hotfix` (bug fix): tell `plan` to produce a minimal plan (no brainstorm, no deepening pass), then run steps 2–10 normally. `--tweak` (small change): minimal plan as above, and in step 3 run `code-review` at its lightest (skip the heavy conditional personas; keep the always-on correctness pass). Neither flag skips the local green gate (step 2a), CI watch (step 8), or `compound` (step 9) — evidence gates are never waived for speed. With no flag, run the full pipeline.

1. Invoke the `plan` skill with `$ARGUMENTS`. If a prior `brainstorm` ran in this pipeline and produced a feature issue, pass that issue ref so the plan consumes it and writes its plan comment onto the same `#<N>`. When no upstream feature issue exists, `plan` creates the feature issue itself (requirement stub body) before writing the plan comment.

   GATE: STOP. If plan reported the task is non-software and cannot be processed in pipeline mode, stop the pipeline and inform the user that LFG requires software tasks. Otherwise, **record the feature issue ref (`#<N>`/URL)** that `plan` reports, then run the script gate to verify the plan comment actually landed — the gate, not the agent's recollection, decides whether step 1 is complete (pick the variant for the current OS):

   ```bash
   bash scripts/gate.sh plan-exists <N>
   ```

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/gate.ps1 plan-exists <N>
   ```

   Branch on the exit code, not the prose: `0` = plan comment present, proceed to step 2; `1` = no `<!-- tunan:plan -->` comment, invoke `plan` again with `$ARGUMENTS` and re-gate; `2` = gh/infra problem, stop and report it (do not loop). Do NOT proceed to step 2 while the gate returns `1`. The feature issue ref `#<N>` is the single handle passed to work in step 2, to code-review in step 3, and to compound in step 9 — there is no separate plan number.

2. **Run `work` in an isolated subagent** so its file reads and diffs stay out of the orchestrator context — only a summary returns. Dispatch the platform's subagent primitive (`Agent`/`Task` in Claude Code, `spawn_agent` in Codex, `subagent` in Pi via `pi-subagents`) with the catch-all/general-purpose agent type, omitting any `mode` override, and instruct it to load the `work` skill with the **feature issue ref `#<N>`** from step 1 as its work source (`work` reads the plan comment `<!-- tunan:plan -->` on that issue) and to return only a concise summary of what changed (files touched, key decisions). The subagent edits the working tree on disk, so the gate below still sees the changes. If the harness cannot dispatch subagents or a subagent cannot load skills, fall back to invoking `work` inline.

   GATE: STOP. Verify that implementation work was actually performed via the script gate — it confirms the working tree is dirty or HEAD diverged from the base branch, so a "done" claim with no code change is caught (pick the variant for the current OS):

   ```bash
   bash scripts/gate.sh work-done
   ```

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/gate.ps1 work-done
   ```

   Exit `0` = code changes present, proceed to step 2a; exit `1` = no changes detected, `work` did not run — re-invoke it before continuing. Do NOT proceed to step 2a while the gate returns `1`.

2a. **Local green gate** — run `tunan:verify` (`mode:agent`, always the fully-qualified name, never a bare `verify`) in an isolated subagent so its test/lint/build command output stays out of the orchestrator context. Dispatch the platform's subagent primitive (`Agent`/`Task` in Claude Code, `spawn_agent` in Codex, `subagent` in Pi via `pi-subagents`) with the catch-all/general-purpose agent type, omitting any `mode` override, and instruct it to load `tunan:verify` with `mode:agent` and return only the JSON output contract as its final message. If the harness cannot dispatch subagents or a subagent cannot load skills, invoke `tunan:verify` inline instead. Write the returned contract to an OS temp file and pass it through the script gate rather than eyeballing the fields (pick the variant for the current OS):

   ```bash
   bash scripts/gate.sh verify-green "$CONTRACT_FILE"
   ```

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/gate.ps1 verify-green $CONTRACT_FILE
   ```

   Map the exit code: `0` (`verdict_code: ready`) → proceed to step 3; `1` (`not_ready`/`failed`) → run the autopilot fix loop below, then re-verify and re-gate; `3` (`status: degraded`/`skipped`) → proceed to step 3 but do not treat as authoritative green — note in the PR body that local verification was degraded/skipped and CI remains the gate; `2` (no parseable contract / jq missing) → treat as a degraded local signal, note it, and proceed. The detailed per-status handling below still applies; the gate is the mechanical front door, the prose is the recovery detail. Read the contract's `status` and `verdict_code`:

   - `not_ready` or `status: failed` → local checks are red; route into the same autopilot fix loop the pipeline uses for failures (do not prompt the user) — dispatch the diagnose-and-fix work to an isolated subagent as in step 8 so the failing-check output never enters the orchestrator context — then re-run `tunan:verify` (again in a subagent) and re-gate. **Bound the loop:** after a small number of consecutive `not_ready` results with no progress, stop the autopilot, surface the failing checks in the PR body, and proceed — CI (the remote authoritative gate) is the backstop. Never spin indefinitely on a persistently red local environment.
   - `ready` → proceed to step 3.
   - `status: degraded` (ambiguous command detection / partial run) or `status: skipped` (no detectable checks) → do not loop and do not treat as authoritative green; proceed to step 3, noting in the PR body that local verification was degraded/skipped and CI remains the authoritative gate.

   **Division of labor (do not duplicate):** `tunan:verify` is the pre-push **local static green** signal (test/lint/build). Its optional `observe` check delegates to the same `test-browser` skill used later in this pipeline — do not run app/browser observation twice. The CI watch later in this pipeline remains the **remote authoritative** gate. **Anti-false-green:** verify's detected commands should align with the project's CI command set; a `degraded` or partial verify must not be treated as `ready`, so the autopilot loop is never taught to trust a local signal that does not predict the real CI gate.

3. Invoke the `code-review` skill with `mode:agent plan:<feature-issue-ref-from-step-1>`.

   Pass the feature issue ref `#<N>` from step 1 so code-review reads its plan comment and can verify requirements completeness. Read the **Actionable Findings** summary the skill emits, and its machine-readable `verdict_code` / `summary` fields (the shared `mode:agent` output contract that `code-review` and `verify` both emit) rather than string-matching the human `verdict` prose.

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

   6. If no open PR exists, record the residuals as a `tunan:review` GitHub issue — never a local file. Run the GH preflight first (`gh` installed; `gh auth status` exits 0; `gh repo view --json nameWithOwner` resolves); if any check fails, stop and report the gh setup problem. Ensure the label exists:

      ```bash
      gh label list --search "tunan:review"
      ```

      If absent, create it:

      ```bash
      gh label create "tunan:review" --color 1f883d --description "tunan review"
      ```

      Write the composed `## Residual Review Findings` section plus the source PR-review run context to an OS temp file (`${TMPDIR:-/tmp}` / `$env:TEMP`), then create the issue titled `[review] <branch-or-head-sha>`:

      ```bash
      gh issue create --title "[review] <branch-or-head-sha>" --label "tunan:review" --body-file BODY_FILE
      ```

      When the feature issue ref `#<N>` from step 1 is known, reference it with `#<N>` in the `tunan:review` issue body and also post the findings as a comment on that feature issue:

      ```bash
      gh issue comment FEATURE_NUMBER --body-file BODY_FILE
      ```

      This is the durable no-PR sink. Do not output DONE until either the existing PR body has been updated or this `tunan:review` issue has been created. If both paths fail, stop and report the failed commands; do not silently proceed.

   Never block DONE on tracker filing failures once residuals have been durably recorded. A `no_sink` outcome is success only when the findings are present in the PR body or in the created `tunan:review` issue.

6. **Run `test-browser` (`mode:pipeline`) in an isolated subagent** so its screenshots, page snapshots, and browser logs stay out of the orchestrator context — only a pass/fail summary returns. Dispatch the platform's subagent primitive (`Agent`/`Task` in Claude Code, `spawn_agent` in Codex, `subagent` in Pi via `pi-subagents`) with the catch-all/general-purpose agent type, omitting any `mode` override, and instruct it to load `test-browser` with `mode:pipeline` and return only a concise result summary (what was exercised, pass/fail, any defects found). If the harness cannot dispatch subagents or a subagent cannot load skills, invoke `test-browser` inline instead.

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

   2. **Dispatch an isolated subagent to diagnose and fix**, so the failure logs never enter the orchestrator context — only a short summary returns. Use the platform's subagent primitive (`Agent`/`Task` in Claude Code, `spawn_agent` in Codex, `subagent` in Pi via `pi-subagents`) with the catch-all/general-purpose agent type, omitting any `mode` override. Instruct it to:
      - enumerate failing checks with `gh pr checks --json name,state,conclusion,workflow,link`, parse each failing `<run-id>` from the check's details URL, and read each failure log with `gh run view <run-id> --log-failed`;
      - identify the root cause and apply a real fix in the working tree — never weaken, skip, or mock the failing assertion; if the failure is a flaky test with no fix path, make no code change and report that;
      - stage only the files it changed, then commit and push:

        ```bash
        git add <changed-files>
        git commit -m "fix(ci): <one-line summary of the failure repaired>"
        git push
        ```

      - return ONLY a concise structured summary — `{ fixed: <bool>, summary: <what was repaired>, remaining: <flaky/unfixable notes> }` — keeping the raw logs inside the subagent.

      If the harness cannot dispatch subagents, fall back to performing this diagnose-and-fix inline.

   3. Read the subagent's summary (not raw logs) and return to iteration (1) with the next attempt counter. If it reported a flaky/unfixable failure with no code change, treat that as the residual outcome below rather than retrying.

   GATE: STOP iterating after 3 failed attempts. If CI is still red after 3 fix cycles:
   - Compose a `## CI Failures Unresolved` markdown section listing each remaining failing check, the failure summary, and the run/check URL.
   - Append or replace this section in the PR body, write the new body to an OS temp file, then run:

     ```bash
     gh pr edit PR_NUMBER --body-file BODY_FILE
     ```

   - Do NOT continue looping. The autopilot contract is "make residuals durable, then exit." Proceed to step 9.

9. Invoke the `compound` skill to capture the solved problem.

   Pass it the **feature issue ref `#<N>`** from step 1, the PR URL, and a short summary of what was built. `compound` runs its own GH preflight and writes the solution as a **comment** on that same feature issue (first line `<!-- tunan:solution -->`, label `tunan:solution` added) — not a separate issue or a local file. If `compound` is unavailable on the harness, note that compounding was skipped — do not write a local solution file.

   When `compound` ran (was available), confirm the solution comment actually landed with the script gate before declaring DONE (pick the variant for the current OS):

   ```bash
   bash scripts/gate.sh solution-exists <N>
   ```

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/gate.ps1 solution-exists <N>
   ```

   Exit `0` confirms the `<!-- tunan:solution -->` comment is present — proceed to step 10. Exit `1` means compound silently failed to post — re-invoke `compound` once, then re-gate. If `compound` was unavailable on the harness, skip this gate and note the skip in the summary; an infra exit (`2`) is non-blocking here.

10. Output `<promise>DONE</promise>` when complete. Include the chain in the summary: the **feature issue `#<N>`** (carrying its req body plus `tunan:plan` and `tunan:solution` comments) and the PR URL — a single issue handle, not three separate issue numbers.

Start with step 1 now. Remember: GH preflight and plan FIRST, then work. Never skip the plan.
