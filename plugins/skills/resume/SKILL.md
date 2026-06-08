---
name: resume
description: 'Resume an interrupted yunxing feature pipeline at the right stage instead of re-running it from the start. Reads the feature issue''s labels, marker comments, and any open PR to infer the current phase (plan / work / review-ci / done) and dispatches to the correct next skill. Use when the user says "resume", "continue the feature", "pick up where we left off", "继续这个 req", or passes a feature issue ref to continue. Resolves the target by explicit issue number, current branch''s PR body, or branch name.'
argument-hint: "[<feature issue #N>]"
---

# resume — pick up an interrupted feature pipeline at the right phase

> 运行环境入口约定：本仓库的 `.claude/skills` 以 Claude Code 为源，示例默认写 `/yunxing:*`。若同一 skill 在 Codex 中运行，所有面向 sponsor 的可复制入口在输出前改写为 `$yunxing:*`；Claude Code 中保持 `/yunxing:*`。

> **何时触发**：用户说 "resume" / "继续这个 feature" / "接着上次的做" / "/yunxing:resume #N"，或一个 `lfg` 跑到一半被打断、想从断点继续而不是从 step 1 重跑整条流水线。

The feature issue **is** the state machine. yunxing keeps every durable artifact on a single GitHub issue (requirement body + `<!-- yunxing:plan -->` / `<!-- yunxing:solution -->` marker comments + accumulating labels), and a feature's open PR marks the review/CI tail. `resume` reads that state with a deterministic script and routes to the next skill — it never re-derives progress from the agent's memory of a prior session.

This mirrors comet's `/comet` auto-detect-and-dispatch, but the state source stays GitHub, not a local `.yaml` — so resume works across machines and sessions, and never conflicts with yunxing's "artifacts are issues, never local files" invariant.

## 调用语法

```
/yunxing:resume [<feature issue #N>]
```

- `<feature issue #N>` — the feature issue to resume. If omitted, resolve it (in order): the current branch's open PR body (`gh pr view --json body` → first `#N`), then the branch name (`feat/…-N` or a trailing number), then the most recent open `yunxing:req` issue (`gh issue list --label yunxing:req --state open --limit 5`). If still ambiguous, ask the sponsor which issue to resume.

## GH preflight (required)

Resume reads GitHub state; if `gh` is missing or unauthenticated there is no state to read. Run before anything else; if any fails, stop and tell the sponsor to fix gh setup — do not guess the phase from local files.

```bash
gh --version
```
```bash
gh auth status
```
```bash
gh repo view --json nameWithOwner
```

## Step 1 — detect the phase

Run the co-located phase detector (it owns the inference rules; do not re-implement them inline). Pick the variant for the current OS. macOS/Linux:

```bash
bash scripts/phase.sh detect <N>
```

Windows:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/phase.ps1 detect <N>
```

It prints one machine line on stdout, e.g.:

```
phase=work next=work pr=- issue=42
```

Parse `phase`, `next`, and `pr`. The exit code is advisory: `0` = a phase was determined (including `done`), `1` = issue not found, `2` = gh/infra problem. On `1`/`2`, surface the stderr hint and stop — do not fabricate a phase.

## Step 2 — confirm, then dispatch

Tell the sponsor the resolved feature issue, the detected `phase`, and the planned next action in one line, then dispatch. Phase → action:

| `phase` | what already exists | resume by |
|---|---|---|
| `plan` | feature issue, no plan comment | invoke `plan` with the issue ref (creates the `<!-- yunxing:plan -->` comment), then continue the pipeline |
| `work` | plan comment, no open PR | invoke `work` with the issue ref (it reads the plan comment) |
| `review-ci` | an open PR references the issue | resume at `code-review` (`mode:agent plan:#N`), then commit-push-pr / CI watch / `compound` — lfg steps 3–9 |
| `done` | `<!-- yunxing:solution -->` comment present | nothing to resume; report the feature as complete and stop |
| `unknown` | issue not found / gh down | report the stderr hint; ask the sponsor for an explicit issue ref |

When the sponsor wants the **whole remaining pipeline** run hands-off from the detected phase, hand off to `lfg` with the feature issue ref and a note of the resume phase, so it skips the already-completed stages rather than re-running step 1. When they want only the **single next stage**, invoke just that skill and stop.

Always resolve a referenced skill name against the host's available-skills list and call the exact listed entry (some platforms namespace as `yunxing:<name>`); never invoke a short-form guess that is not in the list.
