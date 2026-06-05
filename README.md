# yunxing

AI-powered development tools that get smarter with every use — make each unit of engineering work easier than the last. Brainstorm requirements, plan implementations, review code with specialized reviewers, research institutional learnings, and capture solved problems so future work compounds.

This repository is a Claude Code / Codex **plugin marketplace**. It ships a single plugin, **`yunxing`**, bundling 50+ agents, 38+ skills, and 5 MCP servers.

| Component   | Count |
| ----------- | ----- |
| Agents      | 50+   |
| Skills      | 38+   |
| MCP Servers | 5     |

See the [full component reference](plugins/README.md) for the complete inventory, grouped by category.

## Install

### Claude Code

Register this repository as a plugin marketplace, then install the plugin:

```text
/plugin marketplace add raptoravis/yunxing
/plugin install yunxing@yunxing
```

Reload when prompted.

> **⚠️ Required next step — run setup.** Installing the plugin only registers the skills; it does **not** configure your environment. Once the plugin is installed and reloaded, run this in any project:
>
> ```text
> /yunxing:setup
> ```
>
> It diagnoses your environment, installs missing CLI tools and MCP servers, verifies `gh` is installed **and** authenticated (the workflow stores its artifacts in GitHub issues), and bootstraps project config — all in one interactive flow. Skipping setup is the most common cause of skills failing on first use. Re-run `/yunxing:setup` anytime to re-check.

### Codex

Register the marketplace, then install through the Codex TUI:

```bash
codex plugin marketplace add raptoravis/yunxing
codex
```

Inside Codex, run `/plugins`, select the **yunxing** marketplace, choose the **yunxing** plugin, and install. Restart Codex afterward. (Codex installs the skill set natively; the review/research/workflow agents that some skills spawn are a Claude Code feature.)

> **⚠️ Required next step — run setup.** After restarting, run `/yunxing:setup` in any project to diagnose your environment, install missing tools, verify `gh` auth, and bootstrap project config. Don't skip it — it's what makes the skills work on first use.

### Local development (from a checkout)

To run the plugin straight from a working copy — useful when developing or testing changes — point Claude Code at the bundled plugin directory:

```bash
git clone https://github.com/raptoravis/yunxing.git
claude --plugin-dir ./yunxing/plugins
```

This loads the plugin's skills, agents, and MCP servers directly from your checkout, no marketplace registration required.

## MCP servers

The plugin ships a bundled [`.mcp.json`](plugins/.mcp.json). Two lightweight, no-API-key servers load **automatically** the moment the plugin is enabled:

- `context7` — up-to-date library / API documentation lookup
- `sequential-thinking` — structured multi-step reasoning

Three heavier servers are **opt-in** (they pull large dependencies — browser binaries, a Python `uvx` toolchain, a Chrome install): `playwright`, `serena`, and `chrome-devtools`. Run `/yunxing:setup` to check which MCP servers are registered and install any missing ones interactively. See the [MCP reference](plugins/README.md#mcp-servers) for details.

## Getting started

After install, run `/yunxing:setup` first to verify your environment (see the **⚠️ Required next step** note above), then try:

- `/yunxing:brainstorm` — explore requirements and approaches before planning
- `/yunxing:plan` — create an implementation plan
- `/yunxing:code-review` — run a comprehensive multi-agent review
- `/lfg` — full autonomous engineering workflow

## License

MIT — see [LICENSE](LICENSE).
