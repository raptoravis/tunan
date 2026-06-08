---
name: hotfix
description: 'Fast-path autonomous pipeline for a bug fix — runs the full lfg engineering pipeline (work, verify, code review, commit, push, PR, CI watch, compound) but skips brainstorm and the plan deepening pass, producing only a minimal plan. Use when the user says "hotfix", "quick fix this bug", "ship a fix for X", "/yunxing:hotfix", or wants a bug repaired and shipped hands-off without the full planning ceremony. For a small non-bug change use tweak; for a full feature use lfg.'
argument-hint: "[bug description | #N to resume]"
---

# hotfix — 快速路径流水线（bug 修复）

> 运行环境入口约定：本仓库的 `.claude/skills` 以 Claude Code 为源，示例默认写 `/yunxing:*`。若同一 skill 在 Codex 中运行，所有面向 sponsor 的可复制入口在输出前改写为 `$yunxing:*`；Claude Code 中保持 `/yunxing:*`。

> **何时触发**：用户说 "hotfix" / "/yunxing:hotfix" / "快速修一下这个 bug" / "修复并发布 X"，且希望 hands-off 跑完而不要完整规划仪式。

## 与 lfg 的关系

`hotfix` 是 `lfg` 的**命名快速路径入口**，行为等价于 `lfg --hotfix`。对标 comet 的 `/comet-hotfix` 预设。

执行时：**加载并遵循 `lfg` skill 的完整流程**（GH preflight、各步骤、脚本化门禁、CI watch 自修复循环、residual handoff、compound、输出契约），只在规划阶段降低仪式：

- **跳过 brainstorm 与 plan 的 deepening pass**——告诉 `plan` 产出一个 minimal plan 即可。plan 评论仍必须落地（`<!-- yunxing:plan -->`），因为 `work` 要读它；一个 feature 仍是一个 issue，链条不断。
- 其余步骤一律继承 lfg，**不在此重复**。

**证据门禁绝不豁免**：本地 green gate（lfg step 2a 的 `verify-green`）、work-done 门禁、CI watch（step 8）、compound（step 9）全部照常执行。快速路径只省规划仪式，不省守卫——这是与 comet 一致的硬约束。

## 调用语法

```
/yunxing:hotfix [bug 描述 | #N]
```

- `bug 描述` — 新 bug 的描述，作为 `$ARGUMENTS` 传给 lfg 的 step 1（带 `--hotfix` 语义）。
- `#N` — 已存在的 feature issue ref。此时遵循 lfg 的 RESUME 前导：加载 `resume` skill 检测阶段并从断点继续，同样维持 hotfix 的低仪式规划。

**示例**：

```
/yunxing:hotfix 登录 token 过期后没有刷新，导致 401     # 直接修复并发布
/yunxing:hotfix #482                                  # 从已存在的 feature issue 断点续跑
```

## 与 tweak 的区别

- `hotfix`：bug 修复语义。minimal plan，其余 lfg 全流程（含完整 code-review 的 always-on 纠错）照常。
- `tweak`：小改动语义。minimal plan **且** code-review 跑最轻档（略过重型条件 persona，只保留 always-on correctness）。

不确定时：是修 bug 用 `hotfix`，是无 bug 的小调整用 `tweak`，是完整 feature 用 `lfg`。
