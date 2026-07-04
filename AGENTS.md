# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## What this repo is

This is the **tunan** plugin — 43 agents, 66 skills, and 4 MCP servers that ship as a marketplace plugin and npx-installable skill collection for Claude Code, Codex, OpenCode, Reasonix, and other AI coding agents.

## Repo structure

```
skills/<name>/SKILL.md           # Each skill = SKILL.md + references/ (root level, npx-discoverable)
agents/<name>.md                 # Each agent = bare-name .md file (root level)
plugins/                         # Plugin manifest payload for Claude Code / Codex marketplaces
├── .claude-plugin/plugin.json   # Claude Code manifest (version, skills path "../skills/", MCP servers)
├── .codex-plugin/plugin.json    # Codex manifest (version + interface section)
├── .mcp.json                    # Bundled MCP server config
├── AGENTS.md                    # Comprehensive authoring guide (read this first)
└── CLAUDE.md                    # Claude Code companion instructions
install.sh                       # Local skill installer (bash)
install.ps1                      # Local skill installer (PowerShell)
bin/cli.js                       # npx entry point
package.json                     # npm package (enables npx tunan install)
```

Skills and agents live at the repo root so that `npx skills add raptoravis/tunan` can discover them. The `plugins/` directory holds the Claude Code and Codex marketplace manifests; plugin manifests reference the root `skills/` via relative paths (`"skills": "../skills/"`).

## Installation

Users install tunan in three ways:

1. **npx (recommended):** `npx skills add raptoravis/tunan --skill '*' -a <agent> -g -y`
2. **From checkout:** `./install.sh --claude` or `./install.ps1 -Codex`
3. **Marketplace:** Register `raptoravis/tunan` in Claude Code or Codex plugin marketplace

## No build / test / lint toolchain

This repo was simplified — the Bun toolchain, release-please, CI workflows, and test suite were removed. There is no `bun run`, `npm test`, or `CHANGELOG.md` automation. Do not reference them.

## Version bumping

Both manifests MUST stay in sync. When bumping:

```
plugins/.claude-plugin/plugin.json  →  "version": "X.Y.Z"
plugins/.codex-plugin/plugin.json   →  "version": "X.Y.Z"
```

## Local development (testing skills live)

Run Claude Code pointed at the checkout so skills load from disk:

```bash
claude --plugin-dir .
```

**Cache trap:** `~/.claude/plugins/cache/tunan/` is a stale cache copy. Always edit under `skills/` in the repo, not the cache. If you accidentally edited the cache, diff it against the repo source and re-apply to the correct file.

## Key conventions (from plugins/AGENTS.md)

### Naming

- Skills and agents use **bare names** with no `tunan-` prefix. The host namespace supplies `tunan:`.
- Skill directory name = `SKILL.md` `name:` frontmatter = bare name (e.g., `code-review`)
- Agent filename = bare name (e.g., `correctness-reviewer.md`), frontmatter `name:` = bare name

### Windows support

Every helper script under `skills/*/scripts/` ships in both `.sh` (bash) and `.ps1` (PowerShell 5.1) form with identical args and stdout contracts. PowerShell variants target Windows PowerShell 5.1 (no 7+-only syntax). When adding or changing one, change the other in the same commit.

**SKILL.md** invokes the OS-appropriate variant:

```markdown
```bash
bash scripts/gate.sh plan-exists <N>
```

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/gate.ps1 plan-exists <N>
```
```

### Artifact model: GitHub issues, not local files

Durable artifacts live as GitHub issues. A feature is **one issue** for its lifetime:
- Issue body = requirement (`tunan:req`)
- `<!-- tunan:plan -->` marker comment = plan (label `tunan:plan`)
- `<!-- tunan:gate -->` marker comment = acceptance gate (label `tunan:gate`)
- `<!-- tunan:solution -->` marker comment = solution (label `tunan:solution`)

Other artifact kinds (ideas, reports, retros, review residuals) are their own issues distinguished by label. There is no local-file fallback.

### Skill design principles

- **Calibrate prescription to failure mode.** Hard rules for deterministic safety, strong guidance + examples for judgment calls, trust where prescription would harm.
- **SKILL.md caches at session start; references load on demand.** Load-bearing rules go in SKILL.md, not just references.
- **Rationale discipline.** Every line in SKILL.md loads on every invocation — include rationale only when it changes agent behavior.
- **Extract conditional or late-sequence blocks to `references/`** when they represent ~20%+ of the skill and fire after many tool/agent calls.
- **Process exhaust stays out of artifacts.** Engineering metadata belongs in chat, not in user-facing docs.

Full conventions live in `plugins/AGENTS.md` — read it before making substantial changes.

## Skill editing checklist

- `name:` in frontmatter matches directory name
- `description:` describes what + when, ≤1024 chars, colons quoted, no raw `<angle-bracket>` tokens
- Reference files use backtick paths (`` `references/foo.md` ``), NOT markdown links
- Cross-platform: blocking questions use the platform tool (`AskUserQuestion` / `request_user_input` / `ask_user`)
- Sub-agent dispatch names platform primitives (`Agent`/`Task` in Claude Code, `spawn_agent` in Codex)
- Script references use relative paths (`bash scripts/foo.sh`), not `${CLAUDE_PLUGIN_ROOT}`
- OS: every `.sh` has a `.ps1` twin