---
name: forensics
description: "Post-mortem a stuck or failed tunan pipeline run (lfg / work / plan / hotfix). Read-only investigation that gathers evidence from git history, worktrees, and the feature issue's tunan markers (the tunan:progress comment, plan marker, labels, open PR + CI state), detects anomalies — stuck loops, missing markers, abandoned uncommitted work, orphaned worktrees, CI thrash — and emits a structured diagnostic report with a likely root cause and corrective next step. Use when the user says 'what went wrong', 'the pipeline got stuck', 'lfg failed silently', 'why did this run die', 'forensics', '复盘一下哪里卡住了', or after an autonomous run ends in an unclear state. Never modifies project files; optionally captures the report as an issue."
argument-hint: "[problem description] [--issue <feature issue #>]"
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - AskUserQuestion
---

# forensics — 流水线事后复盘

> 运行环境入口约定：本仓库的 `.claude/skills` 以 Claude Code 为源，示例默认写 `/tunan:*`。若同一 skill 在 Codex 中运行，所有面向 sponsor 的可复制入口在输出前改写为 `$tunan:*`；Claude Code 中保持 `/tunan:*`。

`forensics` 对一次**卡住或失败**的 tunan 流水线运行（`lfg` / `work` / `plan` / `hotfix`）做事后复盘：从 git 历史、worktree、以及功能 issue 上的 tunan 标记（`<!-- tunan:progress -->` 进度评论、plan marker、标签、open PR + CI 状态）收集证据，比对异常模式，给出最可能的根因和纠正动作。

**核心原则：全程只读。** 不改任何项目文件、不动 git、不碰 issue/PR 状态——只调查、只输出报告（可选把报告存成一个 issue）。这与 `debug`（查代码 bug）和 `sessions`（挖会话历史）不同：forensics 诊断的是**流水线运行本身**为什么卡住，证据来源是 git + tunan issue 标记，而非源码或会话日志。

## Interaction Method

决策点走平台阻塞问询工具：`AskUserQuestion`（Claude Code；未加载 schema 先 `ToolSearch` `select:AskUserQuestion`）、`request_user_input`（Codex）、`ask_user`（Gemini；Pi 经 `pi-ask-user`）。无工具或出错退化为 chat 编号列表并等待，绝不静默跳过。用于：问题描述缺失时的补问、收尾"是否把报告存成 issue"。

## Argument

<problem> #$ARGUMENTS </problem>

- 自由文本：对出了什么问题的描述（如"lfg 在 plan 后没进 work 就停了"/"costs 异常高"/"execute 阶段静默失败"）。为空时 Phase 1 先问。
- `--issue <N>`：指定要复盘的功能 issue 号。不传则尝试从当前分支的 PR body 或分支名推断功能 issue。

## 执行流程

### Phase 1：确定调查对象

1. 拿到问题描述。`$ARGUMENTS` 为空时用阻塞问询工具问"出了什么问题"，给几个常见症状选项（卡在某阶段 / 静默失败 / 反复改同一处 / 状态不明）外加自由输入。
2. 解析功能 issue：`--issue <N>` 优先；否则按 `resume`/`status` 同款顺序推断——当前分支 open PR 的 body（找 issue 引用）→ 分支名里的 issue 号 → 最近活跃的 `tunan:req`/`tunan:plan` issue。推断不到就只做 git 侧复盘，并在报告里说明缺 issue 侧证据。

### Phase 2：收集证据（只读，缺失的源跳过即可）

用 git 命令（只读）和原生工具收集。一次一条简单命令，不链式、不抑制错误：

**git 侧：**
```bash
git log --format="%h %ai %s" -30
git log --name-only --format="---COMMIT---" -20
git status --short
git diff --stat
git worktree list
```
记录：提交时间线与频率、被反复改动的文件、未提交的改动、孤立 worktree。

**issue 侧**（有功能 issue 时，用 `gh`）：
- `gh issue view <N> --json number,title,labels,state` —— 阶段标签（`tunan:req`/`tunan:plan`）反映流水线走到哪。
- 取 `<!-- tunan:progress -->` 进度评论：`units_done/units_total` 反映 work 推进到几成。读取办法见 `references/anomaly-taxonomy.md`。
- 找 plan marker 评论是否存在、是否成型。
- `gh pr list --head <branch> --json number,state,statusCheckRollup` —— open PR 与 CI 状态（CI 反复红 = thrash 信号）。

### Phase 3：比对异常模式

对照 `references/anomaly-taxonomy.md` 的异常清单逐项判定，每项给 **置信度 HIGH/MEDIUM/LOW** 和证据。至少检查 5 类：卡死循环、标记缺失/阶段不一致、废弃的未提交工作、崩溃/中断（孤立 worktree、进度半截）、CI thrash。

### Phase 4：诊断报告

按 `references/anomaly-taxonomy.md` 的报告格式输出（纯文本，不用 markdown 表格），inline 呈现：
- 命中的异常（按置信度排序）+ 各自证据。
- 最可能的**单一根因**。
- 一条具体**纠正动作**（如"`resume #<N>` 从 work 阶段继续"/"清理孤立 worktree 后重跑"/"未提交改动先 commit 或 stash 再诊断")。

### Phase 5：可选存档

用阻塞问询工具问是否把报告存成 issue 供团队追溯：*存成 issue（标签 `tunan:forensics`）* / *只看 inline，不存（推荐）*。选存时创建（首次需建标签），否则结束。**forensics 自身只读**——纠正动作只是**建议**，由用户显式去执行对应 skill，本 skill 不代为修改任何东西。

## 不要做

- 不改项目文件、不动 git（不 commit/stash/reset/checkout）、不改 issue/PR 状态。
- 不直接"修复"——只诊断 + 建议；修复路径交给用户显式触发（`resume`/`debug`/`commit` 等）。
- 不用 shell `find`/`ls`/`cat`/`grep` 做文件勘探——用原生 Glob/Grep/Read。git/gh 是只读查询，可直接用。
