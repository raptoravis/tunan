# tunan

AI-powered development tools that get smarter with every use — make each unit of engineering work easier than the last. Brainstorm requirements, plan implementations, review code with specialized reviewers, research institutional learnings, and capture solved problems so future work compounds.

This repository ships the **`tunan`** plugin, bundling 43 agents, 66 skills, and 4 MCP servers — as a marketplace plugin for Claude Code, Codex, and OpenCode, as an npx-installable skill collection for Reasonix, and as Cursor rules for Cursor.

| Component   | Count |
| ----------- | ----- |
| Agents      | 43    |
| Skills      | 67    |
| MCP Servers | 4     |

See the [full component reference](plugins/README.md) for the complete inventory, grouped by category.

## Install

### Native plugin (recommended for Claude Code, Codex, OpenCode)

For deeper integration (slash commands, MCP auto-load), install as a native plugin through each tool's CLI. Restart your agent afterward.

**Claude Code:**

```text
/plugin marketplace add raptoravis/tunan
/plugin install tunan@tunan
```

Reload when prompted.

```bash
# Install
claude plugin marketplace add raptoravis/tunan
claude plugin install tunan@tunan

# Update
claude plugin update tunan@tunan
```

**Codex:**

```bash
# Install
codex plugin marketplace add raptoravis/tunan
codex plugin add tunan@tunan
```

Restart Codex afterward.

**OpenCode:**

```bash
# Install
opencode plugin -g tunan@git+https://github.com/raptoravis/tunan.git

# Update (use --force to bypass npm cache)
opencode plugin -g tunan@git+https://github.com/raptoravis/tunan.git --force
```

Or add to the `plugin` array in your `opencode.json`:

```json
{
  "plugin": ["tunan@git+https://github.com/raptoravis/tunan.git"]
}
```

**Cursor:**

Cursor does not have a plugin marketplace — install via the install script, which copies tunan's Cursor rules into the global `~/.cursor/rules/` directory (or `CURSOR_RULES_DIR` if set):

```bash
./install.sh --cursor
```

On Windows (PowerShell):

```powershell
.\install.ps1 -Cursor
```

After installing, restart Cursor to load the rules, then run `/tunan:setup`.

### npx install (Reasonix)

Reasonix does not have a plugin marketplace — install via npx:

```bash
npx skills add raptoravis/tunan --skill '*' -a reasonix -g -y
```

### From checkout (Cursor and Reasonix)

For Cursor and Reasonix, you can install directly from a local clone — the script copies rules or skills into the respective directory:

```bash
git clone https://github.com/raptoravis/tunan.git
cd tunan
./install.sh --cursor    # Copies rules into .cursor/rules/
./install.sh --reasonix  # Copies skills into ~/.reasonix/skills/
```

On Windows (PowerShell):

```powershell
.\install.ps1 -Cursor
.\install.ps1 -Reasonix
```

Use `--force` (`-Force` on Windows) to replace existing files.

> For Claude Code, Codex, and OpenCode, install directly via the native plugin commands above — no clone needed. The install script also accepts `--claude` / `--codex` / `--opencode` (which delegate to each platform's plugin CLI), but those still install from the marketplace, not the checkout.

> **⚠️ Required next step — run setup.** After installing, run `/tunan:setup` in any project to diagnose your environment, install missing CLI tools and MCP servers, verify `gh` is installed **and** authenticated (the workflow stores its artifacts in GitHub issues), and bootstrap project config. Skipping setup is the most common cause of skills failing on first use. Re-run `/tunan:setup` anytime to re-check.

### Test skill changes live

Point your agent directly at the checkout to test skill edits:

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
