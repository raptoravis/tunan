# Changelog

All notable changes to the tunan plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.43.2] - 2026-07-03

### Added

- **vision / check-balance skills**: new image-vision skill and balance-check helper; ds_vision defaults to SiliconFlow provider
- **Upstream sync**: absorbed compound-engineering-plugin capabilities (baseline d29c830) and GSD assumption-delta + honest-verifier capabilities (baseline b31b562)

### Changed

- ds_vision `setup.ps1` supports uninstall and user-scope install; fixed PS5.1 registration failure

### Fixed

- **`--state all` consistency**: `brainstorm`, `plan`, `work` reading `tunan:codebase-map`, plus `handoff` resume mode, now query with `--state all` so closed issues are reused instead of silently missed — aligns with `map-codebase`, `tunan:config`, and `tunan:project`
- Removed non-existent `@anthropics/codegraph-mcp` from `.mcp.json` (MCP conflict)
- Isolated `plan` in subagent to prevent LFG pipeline stall after planning
- Added missing `skills` declaration in `.claude-plugin/plugin.json`
- Synced CN/EN README (brand name and skill count consistency)

## [3.39.0] - 2026-06-30

### Added

-

### Changed

-

### Fixed

-

## [3.38.0] - 2026-06-28

### Added

- **OpenCode support**: Added complete OpenCode plugin configuration with agents, commands, and skills integration
- **Cross-platform installer**: Added `install.sh` and `install.ps1` scripts for unified installation across Claude Code, Codex, and OpenCode
- **Environment doctor**: Added `scripts/doctor.sh` and `scripts/doctor.ps1` for environment health checks
- **npm package**: Added `package.json` for npm distribution with `tunan-install` command

### Changed

- Updated README.md with OpenCode installation instructions and cross-platform installer documentation
- Updated plugins/README.md with cross-platform installer section
- Improved installation documentation with multiple installation methods

### Platform Support

- **Claude Code**: Plugin marketplace registration and direct plugin installation
- **Codex**: Plugin marketplace registration and TUI installation
- **OpenCode**: npm installation and direct plugin directory support

## [3.37.0] - Previous Release

### Added

- 50+ agents for specialized review, research, and workflow automation
- 38+ skills for engineering workflows
- 5 MCP servers for enhanced capabilities
- Cross-platform support for Claude Code and Codex
- Windows PowerShell compatibility for bundled scripts
