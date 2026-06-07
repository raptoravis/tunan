---
name: closeissue
description: 'Close a specified GitHub issue, or the feature issue for the req/plan currently being worked on. Use when the user says "close the issue", "关闭 issue", "close this req", "closeissue", or wants the current feature issue (the yunxing:req issue behind the active branch/PR/plan) closed. Resolves the target by explicit number, current branch''s PR body, branch name, or a req/plan search, and confirms before closing — it never reopens, deletes, or force-closes.'
argument-hint: "[<issue>] [--reason=completed|not_planned] [--comment=<text>] [--yes]"
---

# closeissue — close the target / current feature issue

> 运行环境入口约定：本仓库的 `.claude/skills` 以 Claude Code 为源，示例默认写 `/yunxing:*`。若同一 skill 在 Codex 中运行，所有面向 sponsor 的可复制入口在输出前改写为 `$yunxing:*`；Claude Code 中保持 `/yunxing:*`。

> **何时触发**：用户说 "close the issue" / "关闭这个 issue" / "关掉当前 req" / "close this req" / "/yunxing:closeissue"。

This skill closes a single GitHub issue. With an explicit number it closes that issue; without one it resolves the **feature issue** behind the work currently in progress — the single `yunxing:req` issue that holds the requirement, plan, and solution for the active branch / PR / plan (one feature = one issue for its whole lifetime) — and closes that. Closing is a shared-state action, so the skill always confirms the resolved target before closing unless `--yes` is passed.

## 调用语法

```
/yunxing:closeissue [<issue>] [开关]
```

- `<issue>` — issue number (`42` / `#42`) or URL. Omit to resolve the current feature issue.
- `--reason=completed|not_planned` — close reason (default `completed`; use `not_planned` when the requirement is being dropped rather than shipped).
- `--comment=<text>` — post this text as a comment before closing (e.g. a closing note or the PR/commit that resolved it).
- `--yes` — skip the confirmation prompt (use only when the target is unambiguous and the user has already authorized closing).

## 红线

- **只关一个 issue。** Never batch-close multiple issues from one invocation; resolve exactly one target.
- **不 reopen、不 delete、不改 issue body/title。** This skill only transitions an open issue to closed (plus an optional comment).
- **确认后再关。** Without `--yes`, never close before the user confirms the resolved target — closing the wrong issue is disruptive and the resolution is a best-effort guess.
- **目标已关则不重复操作。** If the resolved issue is already `CLOSED`, report that and exit; do not reopen-then-reclose.

## GH PREFLIGHT（必跑，先于流程第 1 步）

Run these in order; if any fails, abort and tell the user to fix the gh setup (install `gh`, `gh auth login`, or set the repo). Do NOT fall back to local files — the feature issue lives only in GitHub.

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

1. **Resolve the target issue `#N`.** Take the first source that yields a number:

   1. **Explicit arg.** If `<issue>` was passed (number or URL), use it. Skip the rest of resolution.
   2. **Current branch's open PR.** Detect a PR for the current branch and parse its body for a `Closes #<N>` / `Fixes #<N>` / `Resolves #<N>` line:

      ```bash
      gh pr view --json number,url,state,body
      ```

   3. **Branch name.** If the current branch name embeds an issue number (e.g. `feature/42-foo`, `42-foo`, `issue-42`), treat that as a candidate `#N`.

      ```bash
      git branch --show-current
      ```

   4. **req/plan search.** Otherwise search for the feature issue whose topic matches the work in progress (branch name, recent commit subjects, or the user's phrasing). Prefer issues that carry `yunxing:plan` (planned, most likely the active feature) and fall back to `yunxing:req`:

      ```bash
      gh issue list --label "yunxing:req" --search "<terms>" --state open --json number,title,url,labels
      ```

2. **Confirm the resolved target** (skip only when `--yes` was passed). Read the issue so the confirmation shows real context, not just a number:

   ```bash
   gh issue view <N> --json number,title,state,labels,url
   ```

   - If the issue is already `CLOSED`, report it and exit — nothing to do.
   - If resolution produced **no candidate** or **multiple plausible candidates**, ask the user which issue to close via the platform's blocking question tool — Claude Code `AskUserQuestion` (load its schema first via `ToolSearch` `select:AskUserQuestion` if it is not already available), Codex `request_user_input`, Gemini/Pi `ask_user`; fall back to a numbered list in chat only when no blocking tool exists or the call errors. Offer the top candidates plus a "none — don't close anything" option, each label naming the issue (`#<N> <title>`) so it is self-contained.
   - If resolution produced a **single** candidate, confirm it with the blocking question tool before closing: present the resolved `#<N> <title>` and ask whether to close it (options: close as the resolved reason / cancel). Pre-select close as the default.

3. **Post the closing comment** (only when `--comment=<text>` was passed). Write the body to an OS temp file first (`${TMPDIR:-/tmp}` on bash, `$env:TEMP` on Windows), then:

   ```bash
   gh issue comment <N> --body-file BODY_FILE
   ```

4. **Close the issue** with the resolved reason:

   ```bash
   gh issue close <N> --reason completed
   ```

   (Use `--reason not_planned` when `--reason=not_planned` was passed.)

## 输出

> ✅ Issue `#<N>` <title> closed as `<reason>`.

When resolution was ambiguous and the user picked / cancelled:

> ↩️ No issue closed — <reason> (e.g. user chose "none", or target already closed).
