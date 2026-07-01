# Contributing to tunan

Thank you for your interest in contributing to tunan! This document provides guidelines and information for contributors.

## Getting Started

1. Fork the repository
2. Clone your fork
3. Create a feature branch
4. Make your changes
5. Submit a pull request

## Development Setup

### Prerequisites

- Node.js >= 18
- Git
- GitHub CLI (`gh`) - authenticated

### Local Development

```bash
# Clone the repository
git clone https://github.com/your-username/tunan.git
cd tunan

# Install dependencies (if any)
npm install

# Run the doctor script to check your environment
./scripts/doctor.sh
```

### Testing Changes

1. Make your changes in the `plugins/` directory
2. Test with Claude Code:
   ```bash
   claude --plugin-dir ./plugins
   ```
3. Test with Codex:
   ```bash
   codex --plugin-dir ./plugins
   ```
4. Test with OpenCode:
   ```bash
   opencode --plugin-dir ./plugins
   ```

## Contributing Guidelines

### Skills

Skills are the primary entry points for engineering work. Each skill should:

- Have a clear `SKILL.md` with YAML frontmatter
- Include `name` and `description` in the frontmatter
- Be self-contained with no external dependencies
- Include references for complex logic
- Support cross-platform execution (bash and PowerShell)

### Agents

Agents are specialized subagents invoked by skills. Each agent should:

- Have a clear markdown file with frontmatter
- Include `name` and `description`
- Be focused on a specific task
- Return structured output when possible

### MCP Servers

MCP servers should:

- Be lightweight and fast-loading
- Not require API keys when possible
- Include clear documentation
- Support multiple platforms

## Pull Request Process

1. Update documentation if needed
2. Verify changes locally with `claude --plugin-dir ./plugins`
3. Request review from maintainers
4. Address feedback promptly

## Code Style

- Use clear, concise comments
- Follow existing code patterns
- Keep functions focused and small
- Use descriptive variable names

## Documentation

- Update README.md for new features
- Add or update skill documentation in SKILL.md files
- Include examples where helpful
- Keep documentation up-to-date

## Reporting Issues

- Use GitHub Issues
- Include clear reproduction steps
- Provide environment details
- Include error messages if applicable

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Questions?

If you have questions about contributing, feel free to open an issue or reach out to the maintainers.