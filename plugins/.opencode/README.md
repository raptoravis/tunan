# tunan OpenCode Plugin (V2)

This directory contains OpenCode-specific configuration for the tunan plugin.

## Installation

### Via git-backed plugin

Add to the `plugin` array in your `opencode.json`:

```json
{
  "plugin": ["tunan@git+https://github.com/raptoravis/tunan.git"],
  "skills": {
    "paths": ["plugins/skills"]
  },
  "instructions": [
    ".opencode/instructions/BOOTSTRAP.md"
  ]
}
```

### Manual

Copy the contents of this directory to `~/.opencode/plugins/tunan/`.

## Configuration

The `opencode.json` file defines:
- **1 primary agent** (`build`) with full tool access (`permission: "allow"`)
- **43 tunan subagents** -- all review, research, design, workflow, and docs agents from the tunan plugin, each with permission scoped to their role (read-only reviewers get `{ read: "allow", bash: "allow", write: "deny", edit: "deny" }`; implementer agents get `permission: "allow"`)
- **66 commands** -- every tunan skill is registered as a slash command (`/tunan:brainstorm`, `/tunan:plan`, `/tunan:code-review`, `/tunan:work`, `/tunan:debug`, `/tunan:compound`, etc.)
- Skills paths pointing to the full `skills/` directory
- Agent prompts referencing the authoritative `agents/<name>.md` definitions

### V2 Plugin API

The plugin uses OpenCode's V2 Plugin API with named exports and `(input, output)` hook signatures:

- **`tool.execute.before`** -- Warns on git push (strict profile), detects hardcoded secrets
- **`tool.execute.after`** -- Runs prettier (strict) and tsc --noEmit (standard) on changed TS/JS files
- **`session.created`** -- Logs available skills count
- **`shell.env`** -- Injects `TUNAN_SESSION` and `TUNAN_HOOK_PROFILE` env vars
- **`permission.asked`** -- Auto-approves safe read-only tools and safe bash commands

Hook behavior is controlled via environment variables:
- `ECC_HOOK_PROFILE` -- `minimal`, `standard` (default), or `strict`
- `ECC_DISABLED_HOOKS` -- Comma-separated hook IDs to disable

## Usage

After installation, restart OpenCode and use any of the 66 slash commands. Key entry points:

- `/tunan:brainstorm` - Explore requirements and capture as a tunan:req GitHub issue
- `/tunan:plan` - Create structured implementation plans
- `/tunan:work` - Execute work systematically
- `/tunan:code-review` - Structured code review with tiered persona agents
- `/tunan:debug` - Systematically find root causes and fix bugs
- `/tunan:compound` - Document solved problems to compound team knowledge
- `/tunan:lfg` - Full autonomous engineering pipeline end-to-end
- `/tunan:setup` - Diagnose and configure tunan environment

## Requirements

- OpenCode installed
- Node.js >= 18
- GitHub CLI (`gh`) authenticated
