---
name: status
description: '列出当前仓库还没合并的 open PR 和还没关闭的 open issue,快速看还剩什么工作。默认只查当前用户,--user <name> 查指定用户,--all 查所有人,--req 只看 tunan:req 需求项。只读,不创建任何 issue。用户说"还剩什么"/"剩余工作"/"还有什么没做"/"open issues"/"what is left"/"/tunan:status" 时用。'
---

# status — 看还剩什么工作

> 运行环境入口约定：本仓库的 `.claude/skills` 以 Claude Code 为源，示例默认写 `/tunan:*`。若同一 skill 在 Codex 中运行，所有面向 sponsor 的可复制入口在输出前改写为 `$tunan:*`；Claude Code 中保持 `/tunan:*`。

> **何时触发**：用户说 "还剩什么" / "剩余工作" / "还有什么没做" / "open issues" / "what's left" / "/tunan:status"。

只读快照：列出仓库里还没合并的 open PR 和还没关闭的 open issue。**默认只看当前用户**的工作;`--user <name>` 查指定用户;`--all` 查所有人。**不创建、不修改、不关闭任何 issue 或 PR** —— 想周期性复盘并存档报告用 `retro`,这个 skill 只做即时查询。

## 调用语法

```
/tunan:status [--user <github-username>] [--all] [--req]
```

**开关(都可选)**：

- `--user <github-username>` — 查指定用户的 open PR 和 issue(按 author 过滤)
- `--all` — 查所有人;与 `--user` 互斥,同时传时 `--all` 优先
- `--req` — open issue 只看带 `tunan:req` 标签的需求项(过滤掉报告/存档类 issue)

不传任何开关时默认等价于 `--user @me`(当前认证用户)。

## 前置

需要 `gh` 已安装并认证、且当前在一个 GitHub 仓库内。若 `gh auth status` 非 0 或 `gh repo view` 解析不到,提示用户认证(`gh auth login`)或确认在 repo 内,然后停止。

## 流程

1. 解析开关,确定 author 过滤值:
   - `--all` → 不加 `--author`
   - `--user <name>` → `--author "<name>"`
   - 默认(无开关)→ `--author "@me"`

2. 列出 open PR:

   ```bash
   gh pr list --state open --limit 100 [--author "<value>"]
   ```

3. 列出 open issue(`--req` 时加 `--label tunan:req`):

   ```bash
   gh issue list --state open --limit 100 [--author "<value>"] [--label tunan:req]
   ```

4. 汇总解读,而不是只贴原始输出:
   - 报出 open PR 数和 open issue 数,说明当前过滤的用户范围。
   - 区分**真正的待办**与**报告存档**:`tunan:retro` / `tunan:pulse` / `tunan:idea` 标签的 issue 是历史报告归档,不是待办工作 —— 单独点出或排除,不要混进"剩余工作"里。
   - 两者都为空时,明确说"当前没有剩余/未完成的工作"。

## 不要做

- 不创建、关闭、合并、编辑任何 issue / PR(那是 `closeissue` / `merge-pr-verify-close` 的事)。
- 不写任何报告 issue(那是 `retro` / `product-pulse` 的事)。
- **不在 chat 里即兴写"想从哪个开始 / 接下来做什么"的散文式追问**(违反对齐硬规则)—— 要征求下一步就走下面 `## 收尾` 的阻塞问询工具。
- 全程只读。收尾的下一步**只是加载**目标 skill,status 自身不执行任何写操作。

## 输出

> 📋 剩余工作(`<过滤范围>`): `<N>` 个 open PR · `<M>` 个 open issue
> - PR: #<n> <title> — <author>
> - Issue: #<n> <title>
> （都为空时:✅ 当前没有剩余工作。）

## 收尾:选下一步(交互)

报完快照后,**只要存在至少一个真正的待办**(排除 `tunan:retro` / `tunan:pulse` / `tunan:idea` 归档类),用平台的阻塞问询工具让 sponsor 选下一步并路由到对应 skill。这是一个对齐点,必须走工具 —— 绝不在 chat 里即兴写"想从哪个开始?"这种征求选择的散文追问。

**问询工具**:`AskUserQuestion`(Claude Code;schema 未加载时先用 `ToolSearch` `select:AskUserQuestion`)、`request_user_input`(Codex)、`ask_user`(Gemini;Pi 经 `pi-ask-user` 扩展)。无阻塞工具或调用出错时,退化为 chat 里的编号列表并等待回应,绝不静默跳过。

**何时不问**:真正的待办为空(或只剩归档类)时**不问** —— 直接报"✅ 当前没有剩余工作"并结束。

**怎么问**(遵循 align 协议):

- 选项 ≤4,每个 label 自包含:含 issue/PR 短引用 + 选它意味着推进到哪个 skill(如 `推进 #25(已规划 → work)`)。
- 把最高杠杆的一项排第一并在 label 末尾加 `(推荐)` —— 一般是已带 `tunan:plan` 标签、可直接进 work 的 issue。
- 始终带一个"先不动,仅查看"的退出项。
- 真正的待办超过 3 项放不下 4 个槽时,改用 chat 编号列表 fallback 全列出,并提示"选编号或描述"。

**路由**(选中后只是**加载**对应 skill,status 自身仍不创建/修改任何东西):

- 带 `tunan:plan` 标签的 issue → 载入 `resume` 或 `work`(`#<N>` 作为工作源)
- `tunan:req` 但还没 plan → 载入 `brainstorm` 或 `plan`
- open PR(有 review 反馈)→ 载入 `resolve-pr-feedback`;PR 就绪可合 → 载入 `merge-pr-verify-close`
- sponsor 选"先不动" → 结束,不路由
