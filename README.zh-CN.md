# tunan

AI 驱动的开发工具，让每次使用都更智能——让每个工程任务都比上一个更容易。探索需求、规划实现、使用专业审查器审查代码、研究机构经验，并捕获已解决的问题，使未来的工作能够复合增长。

本仓库是一个 Claude Code / Codex / OpenCode **插件市场**。它提供一个名为 **`tunan`** 的插件，包含 43 代理、64 技能和 4 个 MCP 服务器。

| 组件 | 数量 |
|------|------|
| 代理 | 43 |
| 技能 | 64 |
| MCP 服务器 | 4 |

完整组件清单（按类别分组）见 [组件参考](plugins/README.md)。

## 安装

### Claude Code

将此仓库注册为插件市场，然后安装插件：

```text
/plugin marketplace add raptoravis/tunan
/plugin install tunan@tunan
```

重新加载时会收到提示。

> **⚠️ 必需的下一步——运行 setup。** 安装插件仅注册技能；它**不会**配置您的环境。插件安装并重新加载后，在任何项目中运行：
>
> ```text
> /tunan:setup
> ```
>
> 它会诊断您的环境、安装缺少的 CLI 工具和 MCP 服务器、验证 `gh` 是否已安装**且**已认证（工作流将其工件存储在 GitHub issues 中），并在一个交互式流程中引导项目配置——跳过设置是技能首次使用时失败的最常见原因。随时重新运行 `/tunan:setup` 以重新检查。

### Codex

注册市场，然后通过 Codex TUI 安装：

```bash
codex plugin marketplace add raptoravis/tunan
codex
```

在 Codex 中，运行 `/plugins`，选择 **tunan** 市场，选择 **tunan** 插件并安装。之后重启 Codex。（Codex 原生安装技能集；一些技能生成的审查/研究/工作流代理是 Claude Code 功能。）

> **⚠️ 必需的下一步——运行 setup。** 重启后，在任何项目中运行 `/tunan:setup` 以诊断您的环境、安装缺少的工具、验证 `gh` 认证并引导项目配置。不要跳过——这是技能首次使用时正常工作的原因。

### OpenCode

通过 CLI 安装（该命令会自动将配置项添加到您的配置文件中）：

```bash
opencode plugin -g tunan@git+https://github.com/raptoravis/tunan.git
```

或者添加到 `opencode.json` 的 `plugin` 数组中（全局 `~/.config/opencode/opencode.json` 或项目级）：

```json
{
  "plugin": ["tunan@git+https://github.com/raptoravis/tunan.git"]
}
```

如果已克隆本仓库并直接在仓库目录下工作，可以改用本地路径（无需远程拉取）：

```json
{
  "plugin": ["./plugins"]
}
```

重启 OpenCode。插件管理器会自动安装并注册所有 tunan 技能。

> **更新**：仓库更新后如需拉取最新版本，可以使用 `--force` 跳过 npm 缓存：
>
> ```bash
> opencode plugin -g tunan@git+https://github.com/raptoravis/tunan.git --force
> ```

或者克隆并直接在仓库中运行 OpenCode：

```bash
git clone https://github.com/raptoravis/tunan.git
cd tunan
opencode
```

> **⚠️ 必需的下一步——运行 setup。** 安装后，在任何项目中运行 `/tunan:setup` 以诊断您的环境、安装缺少的工具、验证 `gh` 认证并引导项目配置。

### 本地开发（从检出）

要直接从工作副本运行插件——在开发或测试更改时很有用——将 Claude Code 指向捆绑的插件目录：

```bash
git clone https://github.com/raptoravis/tunan.git
claude --plugin-dir ./tunan/plugins
```

这会直接从您的检出加载插件的技能、代理和 MCP 服务器，无需市场注册。

## MCP 服务器

插件捆绑了 [`.mcp.json`](plugins/.mcp.json)。两个轻量级、无 API 密钥的服务器在插件启用时**自动**加载：

- `context7` — 最新的库/API 文档查找
- `sequential-thinking` — 结构化多步推理

两个较重的服务器是**可选的**（它们会拉取大型依赖——浏览器二进制文件、Chrome 安装）：`playwright` 和 `chrome-devtools`。我们还推荐 `codegraph`（基于 AST 索引的结构化代码搜索：调用者、被调用者、影响分析），需一次性全局安装（`npm i -g @colbymchenry/codegraph`）。运行 `/tunan:setup` 以检查哪些 MCP 服务器已注册并交互式安装任何缺少的服务器。参见 [MCP 参考](plugins/README.md#mcp-servers) 获取详情。

## 快速开始

安装后，首先运行 `/tunan:setup` 以验证您的环境（参见上面的**⚠️ 必需的下一步**说明），然后尝试：

- `/tunan:new-project` — 引导新项目：定义意图（问题、方案、用户画像、关键指标、轨道）并制定初始里程碑路线图，存储为 `tunan:project` issue，ideate/brainstorm/plan 读取作为基础
- `/tunan:strategy` — 通过 Rumelt 式访谈打磨产品策略，对薄弱的回答穷追不舍；在 `new-project` 引导的 `tunan:project` issue 上做深度细化
- `/tunan:new-raw` — 将原始需求捕获到 GitHub issue（标记为 `tunan:raw`）；brainstorm 稍后将其提升为 `tunan:req`
- `/tunan:brainstorm` — 通过协作对话探索需求和方法，然后制定规模合适的需求
- `/tunan:plan` — 创建结构化实现计划，含自动置信度检查
- `/tunan:work` — 系统地执行工作项
- `/tunan:code-review` — 运行全面的多代理审查，含分层审查者
- `/tunan:lfg` — 完整的自主工程流水线（规划 → 工作 → 审查 → PR → CI → 绿灯）

## 环境检查

运行医生脚本以检查您的环境配置：

```bash
./scripts/doctor.sh
```

Windows PowerShell：

```powershell
.\scripts\doctor.ps1
```

## 许可证

MIT — 参见 [LICENSE](LICENSE)。