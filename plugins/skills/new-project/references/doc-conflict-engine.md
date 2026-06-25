# 文档冲突检测引擎（ingest 模式专用）

当 `new-project` 从仓库里**已有的**规划文档（ADR / PRD / SPEC / RFC / design docs）合成项目意图与需求时，必须先做冲突检测——避免把与既有"已锁定决策"矛盾的内容写进 `tunan:project` / `tunan:req`。本文件定义报告格式、严重度语义和安全闸门。具体哪些条件落入哪个桶由 ingest 流程自身定义（见 SKILL.md 的 ingest phase）。

改编自上游 GSD 的 doc-conflict-engine；tunan 把"已锁定决策"的来源从本地 `.planning/PROJECT.md` 换成**已存在的 `tunan:project` issue 的意图段落**（若有）。

## 严重度语义

- **[BLOCKER]** — 不安全，**不可继续**。流程必须退出且**不写任何目标 issue/段落**。用于：与已锁定决策矛盾、缺前置条件、目标不可能成立。
- **[WARNING]** — 含糊或部分重叠。必须把警告呈现给用户并**取得显式批准**后才写，绝不自动放行。
- **[INFO]** — 仅供参考。无闸门、不需确认，列入报告求透明。

## 报告格式

纯文本，**绝不用 markdown 表格**（无 `|---|`）。原样呈现给用户：

```
## 冲突检测报告

### BLOCKERS ({N})

[BLOCKER] {短标题}
  发现：{incoming 文档说了什么}
  期望：{既有项目上下文要求什么}
  → {解决该冲突的具体动作}

### WARNINGS ({N})

[WARNING] {短标题}
  发现：{检测到什么}
  影响：{可能出什么问题}
  → {建议动作}

### INFO ({N})

[INFO] {短标题}
  备注：{相关信息}
```

每条都要有 `发现:` 加上 `期望:`/`影响:`/`备注:` 之一；BLOCKER/WARNING 还要有 `→` 解决行。

## 安全闸门

**存在任一 [BLOCKER]：**

显示：
```
tunan > 已阻断：{N} 个 BLOCKER 必须先解决，ingest 才能继续。
```
退出，**不写任何目标 issue/段落**。无论 WARNING/INFO 多少，闸门照旧生效。

**只有 WARNING 和/或 INFO（无 BLOCKER）：** 呈现完整报告，再用阻塞问询工具取批准（*批准并写入* / *修订后再来* / *中止*）。用户中止则干净退出。

**报告为空（三桶都无条目）：** 静默继续或显示"tunan > 未检测到冲突"，二者皆可。

## 优先级规则

合成多份文档时，文档类型间的优先级：**ADR > SPEC > PRD > DOC**（可由用户在 ingest 时覆盖）。高优先级文档与低优先级文档对同一决策表述不一时，以高优先级为准并把分歧记为 INFO；与**已锁定决策**（既有 `tunan:project` 意图）矛盾才升级为 BLOCKER。

## 严禁

- 不引入 BLOCKER/WARNING/INFO 之外的严重度。
- 不用 markdown 表格渲染报告。
- 存在 BLOCKER 时不写任何目标 issue/段落——没有"小 blocker"的例外。
- 不绕过闸门、不在无用户输入时自动放行 WARNING。
