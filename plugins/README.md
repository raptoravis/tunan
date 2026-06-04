# Compounding Engineering Plugin

AI-powered development tools that get smarter with every use. Make each unit of engineering work easier than the last.

## Getting Started

After installing, run `/tunan-setup` in any project. It diagnoses your environment, installs missing tools and MCP servers, and bootstraps project config in one interactive flow.

**Windows:** the skills run on Windows as well as macOS/Linux. Bundled helper scripts ship in both bash (`.sh`) and PowerShell (`.ps1`) form — the PowerShell variants are Windows PowerShell 5.1-compatible (no extra install) and are used automatically on Windows.

## Components

| Component   | Count |
| ----------- | ----- |
| Agents      | 50+   |
| Skills      | 38+   |
| MCP Servers | 5     |

## Skills

The primary entry points for engineering work, invoked as slash commands. Detailed user-facing documentation for many skills lives in [`docs/skills/`](../../docs/skills/) — each linked skill name below points to its page (purpose, novel mechanics, use cases, chain position). Skills without dedicated docs are still listed; their `SKILL.md` in the source tree is authoritative.

### Core Workflow

`tunan-strategy` anchors the loop upstream; `tunan-product-pulse` closes it with a read on user outcomes.

| Skill                                                              | Description                                                                                                                                                                                                                                                                             |
| ------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`/tunan-strategy`](../../docs/skills/tunan-strategy.md)                 | Create or maintain `STRATEGY.md` — the product's target problem, approach, persona, key metrics, and tracks. Re-runnable to update. Read as grounding by `/tunan-ideate`, `/tunan-brainstorm`, and `/tunan-plan` when present                                                                    |
| [`/tunan-ideate`](../../docs/skills/tunan-ideate.md)                     | Optional big-picture ideation: generate and critically evaluate grounded ideas, then route the strongest one into brainstorming                                                                                                                                                         |
| [`/tunan-brainstorm`](../../docs/skills/tunan-brainstorm.md)             | Interactive Q&A to think through a feature or problem and write a right-sized requirements doc before planning. Pass `output:html` to write the doc as a single self-contained HTML file instead of markdown (exclusive — md OR html, never both)                                       |
| [`/tunan-plan`](../../docs/skills/tunan-plan.md)                         | Create structured plans for any multi-step task -- software features, research workflows, events, study plans -- with automatic confidence checking. Pass `output:html` to write the plan as a single self-contained HTML file instead of markdown (exclusive — md OR html, never both) |
| [`/tunan-code-review`](../../docs/skills/tunan-code-review.md)           | Structured code review with tiered persona agents, confidence gating, and dedup pipeline                                                                                                                                                                                                |
| [`/tunan-work`](../../docs/skills/tunan-work.md)                         | Execute work items systematically                                                                                                                                                                                                                                                       |
| [`/tunan-debug`](../../docs/skills/tunan-debug.md)                       | Systematically find root causes and fix bugs -- traces causal chains, forms testable hypotheses, and implements test-first fixes                                                                                                                                                        |
| [`/tunan-compound`](../../docs/skills/tunan-compound.md)                 | Document solved problems to compound team knowledge                                                                                                                                                                                                                                     |
| [`/tunan-compound-refresh`](../../docs/skills/tunan-compound-refresh.md) | Refresh stale or drifting learnings and decide whether to keep, update, replace, or archive them                                                                                                                                                                                        |
| [`/tunan-optimize`](../../docs/skills/tunan-optimize.md)                 | Run iterative optimization loops with parallel experiments, measurement gates, and LLM-as-judge quality scoring                                                                                                                                                                         |
| [`/tunan-product-pulse`](../../docs/skills/tunan-product-pulse.md)       | Generate a single-page, time-windowed report on usage, performance, errors, and followups. Saves reports to `docs/pulse-reports/` as a browseable timeline of what users experienced                                                                                                    |

### Research & Context

| Skill                                                                               | Description                                                                                                                                                                                                                 |
| ----------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`/tunan-sessions`](../../docs/skills/tunan-sessions.md)                                  | Ask questions about session history across Claude Code, Codex, and Cursor                                                                                                                                                   |
| [`/tunan-slack-research`](../../docs/skills/tunan-slack-research.md)                      | Search Slack for interpreted organizational context -- decisions, constraints, and discussion arcs                                                                                                                          |
| [`tunan-riffrec-feedback-analysis`](../../docs/skills/tunan-riffrec-feedback-analysis.md) | Convert [Riffrec](https://github.com/kieranklaassen/riffrec) recordings, videos, audio, or notes into structured feedback. Routes between setup, quick bug report, and extensive analysis that hands off to `tunan-brainstorm` |

### Git Workflow

| Skill                                                                   | Description                                                                                                                                               |
| ----------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`tunan-clean-gone-branches`](../../docs/skills/tunan-clean-gone-branches.md) | Clean up local branches whose remote tracking branch is gone                                                                                              |
| [`tunan-commit`](../../docs/skills/tunan-commit.md)                           | Create a git commit with a value-communicating message                                                                                                    |
| [`tunan-commit-push-pr`](../../docs/skills/tunan-commit-push-pr.md)           | Commit, push, and open a PR with an adaptive description; also update an existing PR description, or generate a description on its own without committing |
| [`tunan-worktree`](../../docs/skills/tunan-worktree.md)                       | Manage Git worktrees for parallel development                                                                                                             |

### Workflow Utilities

| Skill                                                                    | Description                                                                                                                                                                                                    |
| ------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`/tunan-demo-reel`](../../docs/skills/tunan-demo-reel.md)                     | Capture a visual demo reel (GIF demos, terminal recordings, screenshots) for PRs with project-type-aware tier selection                                                                                        |
| [`/tunan-promote`](../../docs/skills/tunan-promote.md)                         | Draft user-facing announcement copy for a shipped feature (X post, changelog blurb, LinkedIn, email); voice-matched via the Spiral CLI when installed, a lite layer of editorial & social expertise without it |
| [`/tunan-report-bug`](../../docs/skills/tunan-report-bug.md)                   | Report a bug in the tunan plugin                                                                                                                                                                               |
| [`/tunan-resolve-pr-feedback`](../../docs/skills/tunan-resolve-pr-feedback.md) | Resolve PR review feedback in parallel                                                                                                                                                                         |
| [`/tunan-test-browser`](../../docs/skills/tunan-test-browser.md)               | Run browser tests on PR-affected pages                                                                                                                                                                         |
| [`/tunan-test-xcode`](../../docs/skills/tunan-test-xcode.md)                   | Build and test iOS apps on simulator using XcodeBuildMCP                                                                                                                                                       |
| [`/tunan-setup`](../../docs/skills/tunan-setup.md)                             | Diagnose environment, install missing tools, and bootstrap project config                                                                                                                                      |
| [`/tunan-update`](../../docs/skills/tunan-update.md)                           | Check tunan plugin version and fix stale cache (Claude Code only)                                                                                                                                              |
| [`/tunan-release-notes`](../../docs/skills/tunan-release-notes.md)             | Summarize recent tunan plugin releases, or answer a question about a past release with a version citation                                                                                                      |

### Development Frameworks

| Skill                                                           | Description                                                                                                                                           |
| --------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `tunan-agent-native-architecture`                                  | Build AI agents using prompt-native architecture                                                                                                      |
| `tunan-dhh-rails-style`                                            | Write Ruby/Rails code in DHH's 37signals style                                                                                                        |
| [`tunan-frontend-design`](../../docs/skills/tunan-frontend-design.md) | Create production-grade frontend interfaces                                                                                                           |
| [`tunan-polish`](../../docs/skills/tunan-polish.md)                   | Conversational UX polish — start a dev server, open the feature in a browser, and iterate together; auto-detects 8 frameworks. Manual invocation only |

### Review & Quality

| Skill                                                        | Description                                                                                                                                 |
| ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------- |
| [`tunan-doc-review`](../../docs/skills/tunan-doc-review.md)        | Review documents using parallel persona agents for role-specific feedback                                                                   |
| [`/tunan-simplify-code`](../../docs/skills/tunan-simplify-code.md) | Simplify recent code changes for reuse, quality, and efficiency — parallel reviewers find issues, fixes applied, behavior verified by tests |

### Content & Collaboration

| Skill                                       | Description                                                      |
| ------------------------------------------- | ---------------------------------------------------------------- |
| [`tunan-proof`](../../docs/skills/tunan-proof.md) | Create, edit, and share documents via Proof collaborative editor |

### Automation & Tools

| Skill                | Description                                        |
| -------------------- | -------------------------------------------------- |
| `tunan-gemini-imagegen` | Generate and edit images using Google's Gemini API |

### Beta / Experimental

| Skill             | Description                                                                                                                                                                                                       |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `tunan-dogfood-beta` | Diff-scoped browser QA of the active branch: builds an exhaustive test matrix of every change, drives the app with agent-browser, then auto-fixes issues, adds regression tests, and commits each fix until green |
| `/lfg`            | Full autonomous engineering workflow                                                                                                                                                                              |

## MCP Servers

The plugin ships a bundled [`.mcp.json`](.mcp.json). Two lightweight, no-API-key servers load automatically the moment the plugin is enabled:

| Server                | Auto-loads | Purpose                                          |
| --------------------- | ---------- | ------------------------------------------------ |
| `context7`            | ✅          | Up-to-date library / API documentation lookup    |
| `sequential-thinking` | ✅          | Structured multi-step reasoning                  |

Three heavier servers are **opt-in** — they pull large dependencies (browser binaries, a Python `uvx` toolchain, a Chrome install), so `/tunan-setup` offers them but leaves them unchecked by default:

| Server            | Installs via                          | Purpose                                  |
| ----------------- | ------------------------------------- | ---------------------------------------- |
| `playwright`      | `claude mcp add playwright …`         | Cross-browser automation                 |
| `serena`          | `claude mcp add serena …`             | Codebase session memory (needs `uvx`)    |
| `chrome-devtools` | `claude mcp add chrome-devtools …`    | Performance / DevTools inspection        |

Run `/tunan-setup` to check which MCP servers are registered (via `claude mcp list`) and install any missing ones interactively. MCP detection and `claude mcp add` install are Claude Code-specific; on other harnesses the MCP section is skipped.

## Agents

Agents are specialized subagents invoked by skills — you typically don't call these directly.

### Review

| Agent                               | Description                                                                                                |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `tunan-agent-native-reviewer`          | Verify features are agent-native (action + context parity)                                                 |
| `tunan-api-contract-reviewer`          | Detect breaking API contract changes                                                                       |
| `tunan-architecture-strategist`        | Analyze architectural decisions and compliance                                                             |
| `tunan-code-simplicity-reviewer`       | Final pass for simplicity and minimalism                                                                   |
| `tunan-correctness-reviewer`           | Logic errors, edge cases, state bugs                                                                       |
| `tunan-data-integrity-guardian`        | Database migrations and data integrity                                                                     |
| `tunan-data-migration-reviewer`        | Schema drift, migration safety, mapping verification, deploy-window checks                                 |
| `tunan-deployment-verification-agent`  | Create Go/No-Go deployment checklists for risky data changes                                               |
| `tunan-julik-frontend-races-reviewer`  | Review JavaScript/Stimulus code for race conditions                                                        |
| `tunan-maintainability-reviewer`       | Coupling, complexity, naming, dead code                                                                    |
| `tunan-pattern-recognition-specialist` | Analyze code for patterns and anti-patterns                                                                |
| `tunan-performance-oracle`             | Performance analysis and optimization                                                                      |
| `tunan-performance-reviewer`           | Runtime performance with confidence calibration                                                            |
| `tunan-reliability-reviewer`           | Production reliability and failure modes                                                                   |
| `tunan-security-reviewer`              | Exploitable vulnerabilities with confidence calibration                                                    |
| `tunan-security-sentinel`              | Security audits and vulnerability assessments                                                              |
| `tunan-swift-ios-reviewer`             | Swift and iOS code review -- SwiftUI state, retain cycles, concurrency, Core Data threading, accessibility |
| `tunan-testing-reviewer`               | Test coverage gaps, weak assertions                                                                        |
| `tunan-project-standards-reviewer`     | CLAUDE.md and AGENTS.md compliance                                                                         |
| `tunan-adversarial-reviewer`           | Construct failure scenarios to break implementations across component boundaries                           |

### Document Review

| Agent                              | Description                                                                      |
| ---------------------------------- | -------------------------------------------------------------------------------- |
| `tunan-coherence-reviewer`            | Review documents for internal consistency, contradictions, and terminology drift |
| `tunan-design-lens-reviewer`          | Review plans for missing design decisions, interaction states, and AI slop risk  |
| `tunan-feasibility-reviewer`          | Evaluate whether proposed technical approaches will survive contact with reality |
| `tunan-product-lens-reviewer`         | Challenge problem framing, evaluate scope decisions, surface goal misalignment   |
| `tunan-scope-guardian-reviewer`       | Challenge unjustified complexity, scope creep, and premature abstractions        |
| `tunan-security-lens-reviewer`        | Evaluate plans for security gaps at the plan level (auth, data, APIs)            |
| `tunan-adversarial-document-reviewer` | Challenge premises, surface unstated assumptions, and stress-test decisions      |

### Research

| Agent                           | Description                                                                                                                                     |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `tunan-best-practices-researcher`  | Gather external best practices and examples                                                                                                     |
| `tunan-framework-docs-researcher`  | Research framework documentation and best practices                                                                                             |
| `tunan-git-history-analyzer`       | Analyze git history and code evolution                                                                                                          |
| `tunan-issue-intelligence-analyst` | Analyze GitHub issues to surface recurring themes and pain patterns                                                                             |
| `tunan-learnings-researcher`       | Search institutional learnings for relevant past solutions                                                                                      |
| `tunan-repo-research-analyst`      | Research repository structure and conventions                                                                                                   |
| `tunan-session-historian`          | Search prior Claude Code, Codex, and Cursor sessions for related investigation context                                                          |
| `tunan-slack-researcher`           | Search Slack for organizational context relevant to the current task                                                                            |
| `tunan-web-researcher`             | Perform iterative web research and return structured external grounding (prior art, adjacent solutions, market signals, cross-domain analogies) |

### Design

| Agent                               | Description                                                |
| ----------------------------------- | ---------------------------------------------------------- |
| `tunan-design-implementation-reviewer` | Verify UI implementations match Figma designs              |
| `tunan-design-iterator`                | Iteratively refine UI through systematic design iterations |
| `tunan-figma-design-sync`              | Synchronize web implementations with Figma designs         |

### Workflow

| Agent                    | Description                                            |
| ------------------------ | ------------------------------------------------------ |
| `tunan-pr-comment-resolver` | Address PR comments and implement fixes                |
| `tunan-spec-flow-analyzer`  | Analyze user flows and identify gaps in specifications |

### Docs

| Agent                     | Description                                                  |
| ------------------------- | ------------------------------------------------------------ |
| `tunan-ankane-readme-writer` | Create READMEs following Ankane-style template for Ruby gems |

## Installation

See the repo root [Install section](../../README.md#install) for current installation instructions across Claude Code, Codex, Cursor, Copilot, Droid, Qwen, and converter-backed targets.

Then run `/tunan-setup` to check your environment and install recommended tools.

## Version History

See the repo root [CHANGELOG.md](../../CHANGELOG.md) for canonical release history.

## License

MIT
