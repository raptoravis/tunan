---
name: merge-pr-verify-close
description: Merge a PR, verify the merged base branch, and close the feature issue only when verification passes. Use when the user says "merge and verify", "merge then close the issue", "merge-pr-verify-close", or wants a PR landed with a post-merge safety check before the feature issue is closed. Runs after review is done and CI is green; never force-merges or bypasses branch protection.
argument-hint: "[<PR>] [--issue=<N>] [--base=<branch>] [--keep-branch] [--no-verify]"
---

# merge-pr-verify-close — merge → verify → close

> 运行环境入口约定：本仓库的 `.claude/skills` 以 Claude Code 为源，示例默认写 `/tunan:*`。若同一 skill 在 Codex 中运行，所有面向 sponsor 的可复制入口在输出前改写为 `$tunan:*`；Claude Code 中保持 `/tunan:*`。

> **何时触发**：用户说 "merge and verify" / "合并并验收" / "merge then close issue" / "/tunan:merge-pr-verify-close"。

This skill closes the tail end of a feature: it merges an already-reviewed, CI-green PR, then **re-verifies on the merged base branch** before closing the feature issue. The feature issue is closed **only when post-merge verification passes** — a red verification leaves the issue open and the failure recorded, never silently closed.

`lfg` deliberately stops at an open PR for human review and does **not** call this skill. Invoke this skill explicitly once a human has approved the PR.

## 调用语法

```
/tunan:merge-pr-verify-close [<PR>] [开关]
```

- `<PR>` — PR number or URL. Omit to use the current branch's open PR.
- `--issue=<N>` — feature issue to close. Omit to derive it from the PR body's `Closes #<N>` / `Fixes #<N>` line.
- `--base=<branch>` — base branch to verify on. Omit to use the PR's base branch.
- `--keep-branch` — do not delete the head branch after merge (default deletes it).
- `--no-verify` — skip the post-merge verification step and close the issue on a clean merge alone (use only when there is nothing meaningful to verify).

## 红线

- **不 force-merge、不绕过分支保护。** If `gh pr merge` is blocked by required reviews / required status checks / merge conflict, stop and report — never force it.
- **不在 CI 未绿时 merge。** Re-confirm checks immediately before merging; treat pending/failing as red.
- **verify 不过不关 issue。** A failed post-merge verification must leave the feature issue open with the failure recorded.
- **不弱化 / mock / skip 验证** to make it pass.

## GH PREFLIGHT（必跑，先于流程第 1 步）

Run these in order; if any fails, abort and tell the user to fix the gh setup (install `gh`, `gh auth login`, or set the repo). Do NOT fall back to local files.

```bash
gh --version
```
```bash
gh auth status
```
```bash
gh repo view --json nameWithOwner
```

## 流程

1. **Resolve the PR.** If `<PR>` was passed, use it; otherwise detect the current branch's open PR:

   ```bash
   gh pr view --json number,url,state,baseRefName,headRefName,body
   ```

   If no open PR exists, stop and report — there is nothing to merge.

2. **Resolve the feature issue `#<N>`.** Use `--issue=<N>` if passed. Otherwise parse the PR body for a `Closes #<N>` / `Fixes #<N>` / `Resolves #<N>` line. If none is found and no `--issue` was given, **ask the user** which issue to close via the platform's blocking question tool — Claude Code `AskUserQuestion` (load its schema first via `ToolSearch` `select:AskUserQuestion` if needed), Codex `request_user_input`, Gemini/Pi `ask_user`; fall back to a numbered chat list only if no blocking tool is available or it errors. Offer: derive-none (merge but do not close any issue) as one option. Record the chosen `#<N>` (or "none").

3. **Re-confirm CI is green** immediately before merging:

   ```bash
   gh pr checks <PR>
   ```

   If any check is failing or pending, STOP — do NOT merge. Report the red/pending checks and exit. (Run the review/CI-fix loop first, e.g. via `lfg` or `resolve-pr-feedback`, then re-invoke this skill.)

4. **Merge the PR** (squash; delete the head branch unless `--keep-branch`). Capture the base branch `BASE` from step 1 (or `--base`):

   ```bash
   gh pr merge <PR> --squash --delete-branch
   ```

   (Drop `--delete-branch` when `--keep-branch` is set.)

   If `gh pr merge` fails — branch protection requiring a human review or status checks, required approvals, or a merge conflict — STOP. Do NOT force it, do NOT close the issue. Report the block reason (one line) and exit.

5. **Switch to the merged base branch and pull the merge commit:**

   ```bash
   git checkout <BASE>
   ```
   ```bash
   git pull --ff-only origin <BASE>
   ```

   If `--ff-only` pull fails (local `<BASE>` diverged), report and stop before verifying — do not close the issue on an unclear base state.

6. **Verify on the merged base** (skip entirely when `--no-verify`).

   Run the project's verification against the now-merged code. Choose by what the change touches:
   - Web/UI surface → load the `test-browser` skill with `mode:pipeline`, or the generic `verify` skill.
   - Otherwise → run the project's own test/build commands (the same ones `lfg`/CI use). Prefer the native task runner; one simple command at a time, no chaining or error suppression.

   Treat any failing test/build as a **failed verification**. Do NOT weaken, skip, or mock to make it pass.

7. **Close the feature issue — only on green.**
   - **Verification passed (or `--no-verify` on a clean merge):** close the feature issue as completed (skip if step 2 resolved to "none"):

     ```bash
     gh issue view <N> --json state,stateReason
     ```

     If `state` is not already `CLOSED`:

     ```bash
     gh issue close <N> --reason completed
     ```

   - **Verification failed:** do NOT close the issue. Record the failure as a comment on the feature issue (so the open issue carries the regression context), writing the body to an OS temp file first (`${TMPDIR:-/tmp}` on bash, `$env:TEMP` on Windows):

     ```bash
     gh issue comment <N> --body-file BODY_FILE
     ```

     The comment states: PR `<PR>` merged to `<BASE>`, post-merge verification FAILED, and the failing tests/summary. Leave the issue **open** for a human to address. Report the failure and exit.

## 输出

> ✅ PR `#<PR>` squash-merged to `<BASE>` · post-merge verify **passed** · feature issue `#<N>` closed as completed.

On a blocked merge:

> ⛔ PR `#<PR>` not merged — `<one-line block reason>`. Issue `#<N>` left open.

On a failed post-merge verify:

> ⚠️ PR `#<PR>` merged to `<BASE>`, but post-merge verify **failed** (`<summary>`). Issue `#<N>` left open with the failure recorded.
