# tunan OpenCode Plugin

This directory contains OpenCode-specific configuration for the tunan plugin.

## Installation

### Via git-backed plugin

Add to the `plugin` array in your `opencode.json`:

```json
{
  "plugin": ["tunan@git+https://github.com/raptoravis/tunan.git"]
}
```

### Manual

Copy the contents of this directory to `~/.opencode/plugins/tunan/`.

## Configuration

The `opencode.json` file defines:
- **1 primary agent** (`build`) with full tool access
- **43 tunan subagents** — all review, research, design, workflow, and docs agents from the tunan plugin, each with tool access appropriate to their role (read-only reviewers get `read` + `bash`; implementer agents get `read` + `write` + `edit` + `bash`)
- **66 commands** — every tunan skill is registered as a slash command (`/brainstorm`, `/plan`, `/code-review`, `/work`, `/debug`, `/compound`, etc.)
- Skills paths pointing to the full `skills/` directory
- Agent prompts referencing the authoritative `agents/<name>.md` definitions

## Usage

After installation, restart OpenCode and use any of the 66 slash commands. Key entry points:

- `/brainstorm` - Explore requirements and capture as a tunan:req GitHub issue
- `/plan` - Create structured implementation plans
- `/work` - Execute work systematically
- `/code-review` - Structured code review with tiered persona agents
- `/debug` - Systematically find root causes and fix bugs
- `/compound` - Document solved problems to compound team knowledge
- `/lfg` - Full autonomous engineering pipeline end-to-end
- `/setup` - Diagnose and configure tunan environment

## Requirements

- OpenCode installed
- Node.js >= 18
- GitHub CLI (`gh`) authenticated