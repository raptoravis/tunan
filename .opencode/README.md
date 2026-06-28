# tunan OpenCode Plugin

> WARNING: This README is specific to OpenCode usage. If you installed tunan via the main repository, refer to the root README instead.

tunan plugin for OpenCode - agents, commands, hooks, and skills.

## Installation

### Option 1: npm Package (Recommended)

```bash
npm install tunan-opencode
```

Add to your `opencode.json`:

```json
{
  "plugin": ["tunan-opencode"]
}
```

### Option 2: Direct Use

Clone and run OpenCode in the repository:

```bash
git clone https://github.com/raptoravis/tunan.git
cd tunan
opencode
```

## Features

### Agents (14)

| Agent | Description |
|-------|-------------|
| build | Primary coding agent for development work |
| planner | Implementation planning |
| architect | System design |
| code-reviewer | Code review |
| security-reviewer | Security analysis |
| tdd-guide | Test-driven development |
| build-error-resolver | Build error fixes |
| e2e-runner | E2E testing |
| doc-updater | Documentation |
| refactor-cleaner | Dead code cleanup |
| database-reviewer | Database optimization |
| docs-lookup | Documentation lookup via Context7 |
| harness-optimizer | Harness config tuning |
| loop-operator | Autonomous loop execution |

### Commands (16)

| Command | Description |
|---------|-------------|
| `/plan` | Create implementation plan |
| `/tdd` | TDD workflow |
| `/code-review` | Review code changes |
| `/security` | Security review |
| `/build-fix` | Fix build errors |
| `/e2e` | E2E tests |
| `/refactor-clean` | Remove dead code |
| `/orchestrate` | Multi-agent workflow |
| `/verify` | Verification loop |
| `/update-docs` | Update docs |
| `/test-coverage` | Coverage analysis |
| `/brainstorm` | Explore requirements |
| `/work` | Execute work items |
| `/compound` | Document solved problems |
| `/debug` | Find root causes |
| `/optimize` | Run optimization loops |

### Plugin Hooks

| Hook | Event | Purpose |
|------|-------|---------|
| Security | `tool.execute.before` | Check for secrets |
| Auto-Format | `tool.execute.after` | Format code |
| Session Context | `session.created` | Load project context |
| Console Log Audit | `session.idle` | Audit for console.log |
| Permission Auto-Approve | `permission.ask` | Auto-approve safe operations |

### Custom Tools

| Tool | Description |
|------|-------------|
| run-tests | Run test suite with options |
| check-coverage | Check test coverage |
| security-audit | Security vulnerability scan |
| format-code | Format code using project formatter |
| lint-check | Run linter and check for issues |
| git-summary | Generate git status summary |
| changed-files | List files changed in session |

## Configuration

Full configuration in `opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "anthropic/claude-sonnet-4-5",
  "small_model": "anthropic/claude-haiku-4-5",
  "plugin": ["./plugins"],
  "instructions": [
    "AGENTS.md",
    "instructions/INSTRUCTIONS.md"
  ],
  "agent": { /* 14 agents */ },
  "command": { /* 16 commands */ }
}
```

## Skills

The default OpenCode config loads tunan skills via the `instructions` array. Additional specialized skills are available in the main tunan repository.

## License

MIT
