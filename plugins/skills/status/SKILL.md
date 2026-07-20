---
name: status
description: "列出当前仓库还没合并的 open PR、还没关闭的 open issue,以及 tunan:handoff 交接单里还没完成的事项,快速看还剩什么工作。默认只查当前用户, `--user <name>` 查指定用户, `--all` 查所有人, `--req` 只看 tunan:req 需求项, `--triage` 把 open issue/PR 对照 .github 模板做合规审阅(默认仍只读;加 `--label` / `--close-incomplete` 才会打标签/关闭,且每步需确认)。只读,不创建任何 issue。"
---

# status — 看还剩什么工作

> 运行环境入口约定：本仓库的 `.claude/skills` 以 Claude Code 为源，示例默认写 `/tunan:*`。若同一 skill 在 Codex 中运行，所有面向 sponsor 的可复制入口在输出前改写为 `$tunan:*`；Claude Code 中保持 `/tunan:*`。

> **何时触发**：用户说 "还剩什么" / "剩余工作" / "还有什么没做" / "open issues" / "what's left" / "/tunan:status"。

只读快照：列出仓库里还没合并的 open PR、还没关闭的 open issue,以及 `tunan:handoff` 交接单里还没勾掉的待办事项。**默认只看当前用户**的工作;`--user <name>` 查指定用户;`--all` 查所有人。**不创建、不修改、不关闭任何 issue 或 PR** —— 想周期性复盘并存档报告用 `retro`,这个 skill 只做即时查询。

## 调用语法

```
/tunan:status [--user <github-username>] [--all] [--req] [--triage [--label] [--close-incomplete]]
```

**开关(都可选)**：

- `--user <github-username>` — 查指定用户的 open PR 和 issue(按 author 过滤)
- `--all` — 查所有人;与 `--user` 互斥,同时传时 `--all` 优先
- `--req` — open issue 只看带 `tunan:req` 标签的需求项(过滤掉报告/存档类 issue)
- `--triage` — 切到合规审阅模式:把 open issue/PR 逐个对照仓库 `.github` 模板与 `CONTRIBUTING` 审阅完整度,报告缺失字段与标签缺口。**默认仍只读、只报告**(保持 status 的只读契约)。
  - `--label`(仅 `--triage` 下生效)— 审阅后允许应用建议标签,**每批改动需经阻塞问询确认**。
  - `--close-incomplete`(仅 `--triage` 下生效)— 允许关闭不合规项(带说明评论),**每项关闭需经阻塞问询确认**。

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

4. 列出 open 的 `tunan:handoff` 交接单,并取出每张里**还没完成的事项**(`--req` 时跳过这一步 —— `--req` 只看需求项)。先连 body 一起拉出来:

   ```bash
   gh issue list --label "tunan:handoff" --state open --limit 50 [--author "<value>"] --json number,title,url,body,updatedAt
   ```

   对每张交接单解析 body:统计 `## Not Yet Done` 段落下未勾选的 `- [ ]` 行(已勾选的 `- [x]` 是 Completed,跳过)。一张交接单的"剩余"= 它的未勾选项数;为 0(全部勾掉)说明这张已基本完成,降级处理(只在汇总里点一句"#N 交接单已无未完成项,可考虑 resume 后关闭"),不算进待办。`status: Blocked` 的交接单要醒目标出。

5. 汇总解读,而不是只贴原始输出:
   - 报出 open PR 数、open issue 数,以及 handoff 交接单数 + 其中未完成事项总数,说明当前过滤的用户范围。
   - 区分**真正的待办**与**报告存档**:`tunan:retro` / `tunan:pulse` / `tunan:idea` 标签的 issue 是历史报告归档,不是待办工作 —— 单独点出或排除,不要混进"剩余工作"里。
   - `tunan:handoff` 交接单本身也是带标签的 open issue,会在第 3 步里被重复列出 —— 在汇总时把它从普通 open issue 里剔除,只在 handoff 区块展示(连同其未完成事项),不要两边各算一次。
   - 三者(PR / issue / handoff 未完成项)都为空时,明确说"当前没有剩余/未完成的工作"。

## Triage 模式(`--triage`)

`--triage` 把 status 从"剩余工作快照"切到"合规审阅":把 open issue/PR 对照仓库自己的贡献模板逐个审,报告每项是否齐全。**默认只读、只报告** —— 不打标签、不关闭、不评论,保持 status 的只读契约。只有显式加 `--label` / `--close-incomplete` 才会动手,且每步都经阻塞问询确认。

**问询工具**:`AskUserQuestion`(Claude Code;未加载 schema 先 `ToolSearch` `select:AskUserQuestion`)、`request_user_input`(Codex)、`ask_user`(Gemini;Pi 经 `pi-ask-user`)。无工具或出错退化为 chat 编号列表并等待,绝不静默跳过。

流程:

1. **读审阅标准**(用原生 Read,不用 shell `cat`):`.github/ISSUE_TEMPLATE/*.yml`(各类 issue 的必填字段)、`.github/PULL_REQUEST_TEMPLATE*`(PR 清单)、`CONTRIBUTING.md`(issue-first 规则与审批闸门)。仓库没有这些模板时,只做"有没有标签、标题是否清楚、body 是否为空"的轻量检查,并在报告里点明"无模板,按通用标准审"。
2. **拉取并分类**:`gh issue list --state open --limit 100 --json number,title,labels,body,author` 和 `gh pr list --state open --limit 100 --json number,title,labels,body,author`。按标签+body 特征把每项归到对应模板类型(feature / enhancement / bug / chore / fix PR …);归不出来的标 `needs-triage`。
3. **逐项审合规**:对每项核对其模板要求的必填字段是否齐、是否选了类型、标签是否到位。输出纯文本报告(不用 markdown 表格):每项给 `#<n> <title>` + 合规/缺失清单 + 建议标签。
4. **可选动作(仅显式 flag 时)**:
   - `--label`:把建议标签**成批**列给用户,经阻塞问询确认后再 `gh issue edit` / `gh pr edit` 加标签。未确认不加。
   - `--close-incomplete`:对不合规项,**逐项**经阻塞问询确认后才 `gh issue close` / `gh pr close`(附带说明评论解释为何关闭)。未确认不关。
   - 两个 flag 都没给时,到第 3 步报告即止 —— 一个字都不改。

## 不要做

- 默认(无 `--triage` 显式动作 flag)不创建、关闭、合并、编辑任何 issue / PR(那是 `closeissue` / `merge-pr-verify-close` 的事)。**例外**:`--triage --label` / `--triage --close-incomplete` 在每步阻塞确认后可打标签/关闭不合规项 —— 这是显式 opt-in,不破坏默认只读契约。
- 不写任何报告 issue(那是 `retro` / `product-pulse` 的事)。
- **不在 chat 里即兴写"想从哪个开始 / 接下来做什么"的散文式追问**(违反对齐硬规则)—— 要征求下一步就走下面 `## 收尾` 的阻塞问询工具。
- 默认快照模式全程只读;收尾的下一步**只是加载**目标 skill,status 自身不执行任何写操作。唯一的写动作入口是 `--triage` 配 `--label` / `--close-incomplete` 这两个显式 flag,且每步经阻塞确认 —— 没显式给这两个 flag 时,连 triage 也只读、只报告。

## 输出

> 📋 剩余工作(`<过滤范围>`): `<N>` 个 open PR · `<M>` 个 open issue · `<H>` 张 handoff(`<K>` 项未完成)
> - PR: #<n> <title> — <author>
> - Issue: #<n> <title>
> - Handoff #<n> <title>(`<status>`,剩 `<k>` 项):
>   - [ ] <未完成事项>
>   - [ ] <未完成事项>
>
> （三者都为空时:✅ 当前没有剩余工作。）

## 收尾:选下一步(交互)

报完快照后,**只要存在至少一个真正的待办**(open PR、未 plan/可推进的 issue,或还有未完成事项的 handoff 交接单;排除 `tunan:retro` / `tunan:pulse` / `tunan:idea` 归档类),用平台的阻塞问询工具让 sponsor 选下一步并路由到对应 skill。这是一个对齐点,必须走工具 —— 绝不在 chat 里即兴写"想从哪个开始?"这种征求选择的散文追问。

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
- 还有未完成事项的 `tunan:handoff` 交接单 → 载入 `handoff` skill 的 resume 模式(`/tunan:handoff resume #<N>`)从交接单继续
- open PR(有 review 反馈)→ 载入 `resolve-pr-feedback`;PR 就绪可合 → 载入 `merge-pr-verify-close`
- sponsor 选"先不动" → 结束,不路由
