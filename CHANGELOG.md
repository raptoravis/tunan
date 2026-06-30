# Changelog

All notable changes to the tunan plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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