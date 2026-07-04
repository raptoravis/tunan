# tunan

AI 驱动的开发工具，每次使用都更智能——让每个工程任务都比上一个更容易。探索需求、规划实现、使用专业审查器审查代码、研究机构经验，并捕获已解决的问题，使未来的工作能够复合增长。

本仓库发布 **`tunan`** 插件，包含 43 个代理、66 个技能和 4 个 MCP 服务器，支持 Claude Code、Codex、OpenCode 和 Reasonix。

| 组件 | 数量 |
|------|------|
| 代理 | 43 |
| 技能 | 66 |
| MCP 服务器 | 4 |

完整组件清单（按类别分组）见 [组件参考](plugins/README.md)。

## 安装

### 通过 npx 快速安装（推荐）

一键安装所有 tunan 技能到你的 AI 编码 agent：

```bash
npx skills add raptoravis/tunan --skill '*' -a claude-code -g -y   # Claude Code
npx skills add raptoravis/tunan --skill '*' -a codex -g -y         # Codex
npx skills add raptoravis/tunan --skill '*' -a reasonix -g -y      # Reasonix
```

或从已克隆的仓库安装：

```bash
git clone https://github.com/raptoravis/tunan.git
cd tunan
./install.sh --codex      # Codex
./install.sh --claude     # Claude Code
./install.sh --opencode   # OpenCode
./install.sh --reasonix   # Reasonix
./install.sh --all        # 全部安装
```

Windows (PowerShell):

```powershell
.\install.ps1 -Codex
.\install.ps1 -Claude
.\install.ps1 -OpenCode
.\install.ps1 -Reasonix
.\install.ps1 -All
```

使用 `--force`（Windows 上为 `-Force`）可覆盖已有技能。适用于任何从 `~/.codex/skills/`、`~/.claude/skills/`、`~/.reasonix/skills/` 或 `~/.config/opencode/skills/` 读取技能的 agent。

> **⚠️ 必需的下一步——运行 setup。** 安装后，在任何项目中运行 `/tunan:setup`，诊断你的环境、安装缺少的 CLI 工具和 MCP 服务器、验证 `gh` 已安装**且**已认证（工作流将工件存储在 GitHub issues 中），并引导项目配置——全部在一个交互式流程中完成。跳过 setup 是技能首次使用时失败的最常见原因。随时重新运行 `/tunan:setup` 重新检查。

### 通过插件市场安装

如需更深入的集成（斜杠命令、MCP 自动加载），可通过 agent 的市场安装为原生插件。

**Claude Code：**

```text
/plugin marketplace add raptoravis/tunan
/plugin install tunan@tunan
```

重新加载时会收到提示。

**Codex：**

```bash
codex plugin marketplace add raptoravis/tunan
codex
```

在 Codex 中，运行 `/plugins`，选择 **tunan** 市场，选择 **tunan** 插件并安装。之后重启 Codex。

**OpenCode：**

```bash
opencode plugin -g tunan@git+https://github.com/raptoravis/tunan.git
```

或添加到 `opencode.json` 的 `plugin` 数组中：

```json
{
  "plugin": ["tunan@git+https://github.com/raptoravis/tunan.git"]
}
```

重启 OpenCode。

> **更新**：仓库更新后如需拉取最新版本，使用 `--force` 跳过 npm 缓存：
>
> ```bash
> opencode plugin -g tunan@git+https://github.com/raptoravis/tunan.git --force
> ```

### 本地开发（从检出）

将 agent 直接指向仓库检出，实时测试技能改动：

```bash
git clone https://github.com/raptoravis/tunan.git
claude --plugin-dir ./tunan/plugins
```

**缓存陷阱：** `~/.claude/plugins/cache/tunan/` 是过期的缓存副本。始终编辑仓库中的 `skills/`，而不是缓存。

## MCP 服务器

插件捆绑了 [`.mcp.json`](plugins/.mcp.json)。两个轻量级、无需 API 密钥的服务器在插件启用时**自动**加载：

- `context7` — 最新的库/API 文档查找
- `sequential-thinking` — 结构化多步推理

两个较重的服务器是**可选的**（它们会拉取大型依赖——浏览器二进制文件、Chrome 安装）：`playwright` 和 `chrome-devtools`。我们还推荐 `codegraph`（基于 AST 索引的结构化代码搜索：调用者、被调用者、影响分析），需一次性全局安装（`npm i -g @colbymchenry/codegraph`）。运行 `/tunan:setup` 检查哪些 MCP 服务器已注册，并交互式安装缺少的服务器。详见 [MCP 参考](plugins/README.md#mcp-servers)。

## 快速开始

安装后，首先运行 `/tunan:setup` 验证你的环境，然后尝试：

- `/tunan:new-project` — 引导新项目：定义意图（问题、方案、用户画像、关键指标、轨道）并制定初始里程碑路线图，存储为 `tunan:project` issue，ideate/brainstorm/plan 作为基础读取
- `/tunan:strategy` — 通过 Rumelt 式访谈打磨产品策略，对薄弱的回答穷追不舍；在 `new-project` 引导的 `tunan:project` issue 上做深度细化
- `/tunan:new-raw` — 将原始需求捕获到 GitHub issue（标记为 `tunan:raw`）；brainstorm 稍后将其提升为 `tunan:req`
- `/tunan:brainstorm` — 通过协作对话探索需求和方法，然后制定规模合适的需求
- `/tunan:plan` — 创建结构化实现计划，含自动置信度检查
- `/tunan:work` — 系统地执行工作项
- `/tunan:code-review` — 运行全面的多代理审查，含分层审查者
- `/tunan:lfg` — 完整的自主工程流水线（规划 → 工作 → 审查 → PR → CI → 绿灯）

## 许可证

MIT — 参见 [LICENSE](LICENSE)。