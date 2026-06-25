---
name: docs-update
description: "Generate or refresh a project's documentation (README, architecture, contributing, API/usage docs) so every path, signature, command, and endpoint is verified against the live codebase — no hallucinated or stale docs. Detects existing doc structure, builds a work list, dispatches reader/writer subagents that explore the code directly, then a verifier pass fact-checks each claim and a bounded fix loop repairs inaccuracies. Use when the user says 'update the docs', 'write a README', 'document this project', 'refresh the architecture doc', '更新文档', '写文档', or after a feature lands and the docs drifted. Modes: default (generate + verify), --verify-only (check accuracy, no writes), --force (regenerate all, skip preservation prompts)."
argument-hint: "[doc target or path] [--verify-only] [--force]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
  - Agent
  - AskUserQuestion
---

# docs-update — 文档与代码对齐

> 运行环境入口约定：本仓库的 `.claude/skills` 以 Claude Code 为源，示例默认写 `/tunan:*`。若同一 skill 在 Codex 中运行，所有面向 sponsor 的可复制入口在输出前改写为 `$tunan:*`；Claude Code 中保持 `/tunan:*`。

`docs-update` 生成并刷新项目文档，保证每一条事实——文件路径、函数签名、CLI 命令、HTTP 端点、配置键——都**对照活代码核验过**，不出现幻觉路径、幽灵端点或过期签名。它先探测仓库现有的文档结构，列出待办清单，按文档类型派发**读取/撰写子代理**直接探索代码，再用**核验子代理**逐条 fact-check，最后一个有界修复循环修正不准确处。

与上游 GSD 的 `docs-update` 不同点：tunan 不用本地 `.planning/` 工作清单文件，也不固定 9 种文档类型——它适配仓库**已有的**文档布局，把工作清单留在 chat 的任务列表里（`TaskCreate`/`TaskUpdate`），产物就是仓库里的 markdown 文档本身。文档是代码树文件，不是 issue，这是本 skill 唯一会写盘的 tunan skill 之一，符合预期。

## Interaction Method

决策点一律走平台的阻塞问询工具：`AskUserQuestion`（Claude Code；schema 未加载时先 `ToolSearch` `select:AskUserQuestion`）、`request_user_input`（Codex）、`ask_user`（Gemini；Pi 经 `pi-ask-user` 扩展）。无阻塞工具或调用出错时退化为 chat 编号列表并等待，绝不静默跳过。用于：覆盖已有手写文档前的保留确认、最终写盘前的清单确认。

## Argument

<doc_target> #$ARGUMENTS </doc_target>

- 无参数：扫描全仓库文档，对每种检测到的文档类型走"生成+核验"全流程。
- 指定目标（如 `README` / `architecture` / `docs/api.md` / 一个路径）：只处理该项。
- `--verify-only`：只核验现有文档准确性，**不写任何文件**，报告不一致项。
- `--force`：重写所有文档，跳过保留确认（手写内容也会被覆盖——危险，需在确认问询里点明）。
- `--verify-only` 与 `--force` 同时出现时 `--force` 优先（生成模式）。
- flag 只有字面 token 出现在 `$ARGUMENTS` 里才算激活，文档里列出 ≠ 默认开启。

## 子代理派发约定

用平台的子代理原语（`Agent`/`Task` in Claude Code、`spawn_agent` in Codex、`subagent` in Pi）。优先用本插件自带的 `tunan:*` 代理或内置 `Explore`（只读勘探）。受平台并发上限约束，溢出排队，limit 报错当背压处理；不支持并行的平台退化为顺序执行。给子代理**传文件路径而非文件内容**，让它只读自己需要的部分。探索代码优先用 CodeGraph MCP（`codegraph_*`，结构化、亚毫秒）而非 grep/read 循环。

## 执行流程

### Phase 0：探测文档布局

只读探测，确定工作清单。用原生工具（Glob/Grep；勿用 shell `find`/`ls`/`cat`）：

- 根级文档：`README*`、`ARCHITECTURE*`、`CONTRIBUTING*`、`CHANGELOG*`、`AGENTS.md`/`CLAUDE.md`。
- `docs/` 目录下的现有文档。
- 项目类型线索：`package.json` / `pyproject.toml` / `Cargo.toml` / `go.mod` 决定 API/usage 文档的形态。

把每个"文档项"建成一条任务（`TaskCreate`）。读 `references/doc-types.md` 取标准文档类型目录与各自该覆盖的内容契约。

### Phase 1：保留确认（生成模式）

对每个**已存在且含手写内容**的文档项，在覆盖前用阻塞问询工具确认：*整体重写* / *仅补缺失与过期段落（推荐）* / *跳过此项*。`--force` 时跳过本 phase，全部重写并在开场点明这会覆盖手写内容。`--verify-only` 时跳过本 phase（不写盘）。

### Phase 2：派发撰写子代理（按波次并行）

对每个待生成/更新的文档项，派发一个撰写子代理：

- 输入：文档类型契约（`references/doc-types.md` 里对应段落）、目标文件路径、相关代码区域的路径。
- 职责：直接探索代码（优先 CodeGraph），写出/更新该文档；**只写它能在代码里证实的内容**，不确定的事实标 `<!-- VERIFY: <claim> -->` 留给 Phase 3，而不是编造。
- 产物：写入目标 markdown 文件，返回它新增/改动的**可核验事实清单**（路径、签名、命令、端点）。

按波次派发，尊重并发上限。

### Phase 3：核验子代理 fact-check

对 Phase 2 产出的每条可核验事实（及所有 `<!-- VERIFY -->` 标记），派发核验子代理逐条对照活代码检查：路径是否存在、签名是否吻合、命令/端点是否真实。返回 `{claim, status: ok|wrong|unverifiable, evidence}`。读 `references/verification-contract.md` 取核验输出契约。

`--verify-only` 模式到此为止：汇总 ok/wrong/unverifiable 计数并逐条列出 wrong 项（文件、claim、实际值），不写任何文件。

### Phase 4：有界修复循环

把 Phase 3 标 `wrong` 的项交回撰写子代理修正（每项带上核验给出的实际值）。修正后重新核验。**最多 2 轮**；2 轮后仍 `wrong` 的项，在文档里就地标 `<!-- VERIFY: 无法对齐，需人工确认 -->` 并在收尾报告里点出，不假装已修好。`unverifiable` 项同样保留标记。

### Phase 5：收尾报告

汇总：写/改了哪些文档文件、核验通过多少条、剩余多少 `VERIFY` 待人工确认。列出改动文件路径。**停在 unstaged 状态**——不 `git add`／commit／push（仓库规则：等用户显式说 commit/提交/push）。

## 不要做

- 不写 issue（文档是仓库文件，不是 issue-state）。
- 不编造无法在代码里证实的路径/签名/端点——宁可标 `VERIFY` 也不要幻觉。
- 不 commit/push——停在 unstaged。
- 不用 shell `find`/`ls`/`cat`/`grep` 做常规文件勘探——用原生 Glob/Grep/Read 与 CodeGraph。
