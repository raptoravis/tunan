# tunan

AI-powered development tools that get smarter with every use — make each unit of engineering work easier than the last. Brainstorm requirements, plan implementations, review code with specialized reviewers, research institutional learnings, and capture solved problems so future work compounds.

This repository ships the **`tunan`** plugin, bundling 43 agents, 64 skills, and 5 MCP servers for Claude Code, Codex, and OpenCode.

| Component   | Count |
| ----------- | ----- |
| Agents      | 43    |
| Skills      | 64    |
| MCP Servers | 5     |

See the [full component reference](plugins/README.md) for the complete inventory, grouped by category.

## Install

### Claude Code

Register this repository as a plugin marketplace, then install the plugin:

```text
/plugin marketplace add raptoravis/tunan
/plugin install tunan@tunan
```

Reload when prompted.

> **⚠️ Required next step — run setup.** Installing the plugin only registers the skills; it does **not** configure your environment. Once the plugin is installed and reloaded, run this in any project:
>
> ```text
> /tunan:setup
> ```
>
> It diagnoses your environment, installs missing CLI tools and MCP servers, verifies `gh` is installed **and** authenticated (the workflow stores its artifacts in GitHub issues), and bootstraps project config — all in one interactive flow. Skipping setup is the most common cause of skills failing on first use. Re-run `/tunan:setup` anytime to re-check.

### Codex

Register the marketplace, then install through the Codex TUI:

```bash
codex plugin marketplace add raptoravis/tunan
codex
```

Inside Codex, run `/plugins`, select the **tunan** marketplace, choose the **tunan** plugin, and install. Restart Codex afterward. (Codex installs the skill set natively; the review/research/workflow agents that some skills spawn are a Claude Code feature.)

> **⚠️ Required next step — run setup.** After restarting, run `/tunan:setup` in any project to diagnose your environment, install missing tools, verify `gh` auth, and bootstrap project config. Don't skip it — it's what makes the skills work on first use.

### OpenCode

Install via CLI (this also adds the entry to your config automatically):

```bash
opencode plugin -g tunan@git+https://github.com/raptoravis/tunan.git
```

Or add to the `plugin` array in your `opencode.json` (global at `~/.config/opencode/opencode.json` or project-level):

```json
{
  "plugin": ["tunan@git+https://github.com/raptoravis/tunan.git"]
}
```

Restart OpenCode. The plugin installs through OpenCode's plugin manager and registers all tunan skills.

> **Updating**: To pull the latest version after the repo has been updated, use `--force` to bypass npm's cache:
>
> ```bash
> opencode plugin -g tunan@git+https://github.com/raptoravis/tunan.git --force
> ```

Or run OpenCode directly from a checkout:

```bash
git clone https://github.com/raptoravis/tunan.git
cd tunan
opencode
```

> **⚠️ Required next step — run setup.** After installation, run `/tunan:setup` in any project to diagnose your environment, install missing tools, verify `gh` auth, and bootstrap project config.

### Local development (from a checkout)

To run the plugin straight from a working copy — useful when developing or testing changes — point Claude Code at the bundled plugin directory:

```bash
git clone https://github.com/raptoravis/tunan.git
claude --plugin-dir ./tunan/plugins
```

This loads the plugin's skills, agents, and MCP servers directly from your checkout, no marketplace registration required.

## MCP servers

The plugin ships a bundled [`.mcp.json`](plugins/.mcp.json). Three lightweight, no-API-key servers load **automatically** the moment the plugin is enabled:

- `context7` — up-to-date library / API documentation lookup
- `sequential-thinking` — structured multi-step reasoning
- `codegraph` — structural code search via AST index (callers, callees, impact analysis)

Two heavier servers are **opt-in** (they pull large dependencies — browser binaries, a Chrome install): `playwright` and `chrome-devtools`. Run `/tunan:setup` to check which MCP servers are registered and install any missing ones interactively. See the [MCP reference](plugins/README.md#mcp-servers) for details.

## Getting started

After install, run `/tunan:setup` first to verify your environment (see the **⚠️ Required next step** note above), then try:

- `/tunan:new-project` — bootstrap a new project: define intent (problem, approach, persona, metrics, tracks) and lay out an initial milestone roadmap, stored as a `tunan:project` issue that ideate/brainstorm/plan read as grounding
- `/tunan:strategy` — sharpen the product strategy through a Rumelt-style interview that pushes back on weak answers; refines the `tunan:project` issue bootstrapped by `new-project`
- `/tunan:new-raw` — capture a 'raw' requirement into a GitHub issue (labeled `tunan:raw`); brainstorm later promotes it to `tunan:req`
- `/tunan:brainstorm` — explore requirements and approaches through collaborative dialogue before planning
- `/tunan:plan` — create a structured implementation plan with automatic confidence checking
- `/tunan:work` — execute work items systematically
- `/tunan:code-review` — run a comprehensive multi-agent review with tiered persona agents
- `/tunan:lfg` — full autonomous engineering pipeline end-to-end (plan → work → review → PR → CI → green)

## License

MIT — see [LICENSE](LICENSE).
