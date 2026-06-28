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
- Available agents (planner, code-reviewer, security-reviewer)
- Available commands (plan, code-review, security)
- Skills paths
- MCP server configurations

## Usage

After installation, restart OpenCode and use:

- `/plan` - Create implementation plans
- `/code-review` - Review code changes
- `/security` - Perform security reviews

## Requirements

- OpenCode installed
- Node.js >= 18
- GitHub CLI (`gh`) authenticated