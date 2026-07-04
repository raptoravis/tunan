# tunan

AI-powered development tools that get smarter with every use — make each unit of engineering work easier than the last. Brainstorm requirements, plan implementations, review code with specialized reviewers, research institutional learnings, and capture solved problems so future work compounds.

This repository ships the **`tunan`** plugin, bundling 43 agents, 66 skills, and 4 MCP servers for Claude Code, Codex, OpenCode, and Reasonix.

| Component   | Count |
| ----------- | ----- |
| Agents      | 43    |
| Skills      | 66    |
| MCP Servers | 4     |

See the [full component reference](plugins/README.md) for the complete inventory, grouped by category.

## Install

### Quick install via npx (recommended)

Install all tunan skills for your AI coding agent in one command:

```bash
npx skills add raptoravis/tunan --skill '*' -a claude-code -g -y   # Claude Code
npx skills add raptoravis/tunan --skill '*' -a codex -g -y         # Codex
npx skills add raptoravis/tunan --skill '*' -a reasonix -g -y      # Reasonix
```

Or install from a cloned checkout:

```bash
git clone https://github.com/raptoravis/tunan.git
cd tunan
./install.sh --codex      # Codex
./install.sh --claude     # Claude Code
./install.sh --opencode   # OpenCode
./install.sh --reasonix   # Reasonix
./install.sh --all        # All at once
```

On Windows (PowerShell):

```powershell
.\install.ps1 -Codex
.\install.ps1 -Claude
.\install.ps1 -OpenCode
.\install.ps1 -Reasonix
.\install.ps1 -All
```

Use `--force` (`-Force` on Windows) to replace existing skills. Works with any agent that reads skills from `~/.codex/skills/`, `~/.claude/skills/`, `~/.reasonix/skills/`, or `~/.config/opencode/skills/`.

> **⚠️ Required next step — run setup.** After installing, run `/tunan:setup` in any project to diagnose your environment, install missing CLI tools and MCP servers, verify `gh` is installed **and** authenticated (the workflow stores its artifacts in GitHub issues), and bootstrap project config. Skipping setup is the most common cause of skills failing on first use. Re-run `/tunan:setup` anytime to re-check.

### Plugin marketplace install

For deeper integration (slash commands, MCP auto-load), install as a native plugin through your agent's marketplace.

**Claude Code:**

```text
/plugin marketplace add raptoravis/tunan
/plugin install tunan@tunan
```

Reload when prompted.

**Codex:**

```bash
codex plugin marketplace add raptoravis/tunan
codex
```

Inside Codex, run `/plugins`, select the **tunan** marketplace, choose the **tunan** plugin, and install. Restart Codex afterward.

**OpenCode:**

```bash
opencode plugin -g tunan@git+https://github.com/raptoravis/tunan.git
```

Or add to the `plugin` array in your `opencode.json`:

```json
{
  "plugin": ["tunan@git+https://github.com/raptoravis/tunan.git"]
}
```

Restart OpenCode.

> **Updating**: To pull the latest version, use `--force` to bypass npm's cache:
>
> ```bash
> opencode plugin -g tunan@git+https://github.com/raptoravis/tunan.git --force
> ```

### Local development (from a checkout)

Point your agent directly at the checkout to test skill changes live:

```bash
git clone https://github.com/raptoravis/tunan.git
claude --plugin-dir ./tunan/plugins
```

**Cache trap:** `~/.claude/plugins/cache/tunan/` is a stale cache copy. Always edit under `skills/` in the repo, not the cache.

## MCP servers

The plugin ships a bundled [`.mcp.json`](plugins/.mcp.json). Two lightweight, no-API-key servers load **automatically** the moment the plugin is enabled:

- `context7` — up-to-date library / API documentation lookup
- `sequential-thinking` — structured multi-step reasoning

Two heavier servers are **opt-in** (they pull large dependencies — browser binaries, a Chrome install): `playwright` and `chrome-devtools`. We also recommend `codegraph` (structural code search via AST index: callers, callees, impact analysis), which needs a one-time global install (`npm i -g @colbymchenry/codegraph`). Run `/tunan:setup` to check which MCP servers are registered and install any missing ones interactively. See the [MCP reference](plugins/README.md#mcp-servers) for details.

## Getting started

After install, run `/tunan:setup` first to verify your environment, then try:

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