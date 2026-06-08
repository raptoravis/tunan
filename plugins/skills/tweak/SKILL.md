---
name: tweak
description: 'Fast-path autonomous pipeline for a small change — runs the full lfg engineering pipeline (work, verify, code review, commit, push, PR, CI watch, compound) with a minimal plan and the lightest code review (always-on correctness only, heavy conditional personas skipped). Use when the user says "tweak", "small change", "minor update", "/tunan:tweak", or wants a low-risk small edit shipped hands-off without full planning or full review ceremony. For a bug fix use hotfix; for a full feature use lfg.'
argument-hint: "[change description | #N to resume]"
---

# tweak — 快速路径流水线（小改动）

> 运行环境入口约定：本仓库的 `.claude/skills` 以 Claude Code 为源，示例默认写 `/tunan:*`。若同一 skill 在 Codex 中运行，所有面向 sponsor 的可复制入口在输出前改写为 `$tunan:*`；Claude Code 中保持 `/tunan:*`。

> **何时触发**：用户说 "tweak" / "/tunan:tweak" / "小改一下" / "做个小调整"，且希望 hands-off 跑完而不要完整规划与完整评审仪式。

## 与 lfg 的关系

`tweak` 是 `lfg` 的**命名快速路径入口**，行为等价于 `lfg --tweak`。对标 comet 的 `/comet-tweak` 预设。

执行时：**加载并遵循 `lfg` skill 的完整流程**（GH preflight、各步骤、脚本化门禁、CI watch 自修复循环、residual handoff、compound、输出契约），只在两处降低仪式：

- **跳过 brainstorm 与 plan 的 deepening pass**——告诉 `plan` 产出一个 minimal plan 即可。plan 评论仍必须落地（`<!-- tunan:plan -->`），因为 `work` 要读它；一个 feature 仍是一个 issue，链条不断。
- **code-review 跑最轻档**——lfg step 3 调用 `code-review` 时略过重型条件 persona，只保留 always-on correctness pass。
- 其余步骤一律继承 lfg，**不在此重复**。

**证据门禁绝不豁免**：本地 green gate（lfg step 2a 的 `verify-green`）、work-done 门禁、CI watch（step 8）、compound（step 9）全部照常执行。快速路径只省规划与评审仪式，不省守卫——这是与 comet 一致的硬约束。

## 调用语法

```
/tunan:tweak [改动描述 | #N]
```

- `改动描述` — 小改动的描述，作为 `$ARGUMENTS` 传给 lfg 的 step 1（带 `--tweak` 语义）。
- `#N` — 已存在的 feature issue ref。此时遵循 lfg 的 RESUME 前导：加载 `resume` skill 检测阶段并从断点继续，同样维持 tweak 的低仪式规划与轻档评审。

**示例**：

```
/tunan:tweak 把首页按钮文案从"登录"改成"立即登录"      # 直接改并发布
/tunan:tweak #503                                    # 从已存在的 feature issue 断点续跑
```

## 与 hotfix 的区别

- `tweak`：小改动语义。minimal plan **且** code-review 最轻档。适合低风险的文案、样式、配置类微调。
- `hotfix`：bug 修复语义。minimal plan，但保留 lfg 的完整 code-review always-on 纠错。

不确定时：是无 bug 的小调整用 `tweak`，是修 bug 用 `hotfix`，是完整 feature 用 `lfg`。
