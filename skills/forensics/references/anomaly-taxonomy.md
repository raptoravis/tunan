# 异常分类与报告格式

forensics 比对的异常模式清单、各自的信号与置信度判据，以及报告输出格式。改编自 GSD forensics 工作流，但证据来源换成 tunan 的 git + issue 标记模型（无本地 `.planning/` 文件）。

## 读取 tunan:progress 进度评论

功能 issue 上由 `work` 维护一条 `<!-- tunan:progress -->` 标记评论，含 `units_done/units_total`。读取（PowerShell 下注意原生参数转义，见仓库 AGENTS.md）：取 issue 的全部评论 JSON，找 body 以 `<!-- tunan:progress -->` 开头的那条，解析其中的进度数字。它反映 work 推进到几成——半截（如 3/8 且无新提交）是中断信号。

## 异常清单

### 1. 卡死循环（stuck loop）

**信号：** 同一文件在 3+ 连续提交里反复出现，时间窗很短。
- 置信度 **HIGH**：连续提交的 message 高度相似（如连着几个 `fix:` 都打同一文件）。
- 置信度 **MEDIUM**：该文件高频出现但 message 各异。
判据数据：`git log --name-only --format="---COMMIT---" -20` 解析提交边界后统计连续命中。

### 2. 标记缺失 / 阶段不一致（missing markers）

**信号：** 流水线某阶段看似完成（有提交、issue 带对应阶段标签）却缺该有的 tunan 标记。
- 有 `tunan:plan` 标签但找不到成型的 plan marker 评论 → 规划被跳过或中断。
- 有功能提交但 `<!-- tunan:progress -->` 不存在或 `units_done` 远低于 `units_total` 且无新提交 → work 没正常推进/收尾。
- 提交历史显示已"完成"但无 PR → ship 阶段没走完。

### 3. 废弃的未提交工作（abandoned work）

**信号：** `git status` 有大量未提交改动 + 分支已久未提交（时间线最后一条提交距今很久）。可能是崩溃或人为中断遗留。

### 4. 崩溃 / 中断（crash / interruption）

**信号：** `git worktree list` 出现孤立 worktree（崩掉的并行子代理留下）；或进度评论停在半截（`units_done < units_total`）且无对应收尾提交。

### 5. CI thrash

**信号：** open PR 的 `statusCheckRollup` 显示 CI 反复失败；或提交时间线里出现一串 `ci:`/`fix ci` 类提交密集打在一起 → 流水线卡在 CI 修复循环里。

## 报告格式

纯文本，**不用 markdown 表格**（`|---|`）。inline 呈现：

```
## 复盘报告：<功能/分支/运行的简称>

### 命中异常（按置信度）

[HIGH] <异常类型简称>
  证据：<具体数据，如 "auth.ts 出现在最近 4 个连续提交，message 均为 fix:">
  含义：<这说明流水线发生了什么>

[MEDIUM] <异常类型简称>
  证据：<...>
  含义：<...>

### 最可能根因

<单一根因的一句话判断>

### 建议纠正动作

→ <一条具体动作，指向用户该显式触发的 skill，如 "resume #<N> 从 work 阶段继续">
```

每条异常都要有 `证据:` + `含义:`；报告末尾给**单一根因** + **一条**具体纠正动作。

## 严禁

- 不改任何文件、不动 git、不改 issue/PR 状态——只读取与报告。
- 不引入 HIGH/MEDIUM/LOW 之外的置信度等级。
- 不用 markdown 表格渲染报告。
- 纠正动作只是建议，由用户显式执行，forensics 不代为修改。
