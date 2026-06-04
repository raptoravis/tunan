# Compounding Engineering Plugin

AI-powered development tools that get smarter with every use. Make each unit of engineering work easier than the last.

## Getting Started

After installing, run `/yunxing-setup` in any project. It diagnoses your environment, installs missing tools and MCP servers, and bootstraps project config in one interactive flow.

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

`yunxing-strategy` anchors the loop upstream; `yunxing-product-pulse` closes it with a read on user outcomes.

| Skill                                                              | Description                                                                                                                                                                                                                                                                             |
| ------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`/yunxing-strategy`](../../docs/skills/yunxing-strategy.md)                 | Create or maintain `STRATEGY.md` — the product's target problem, approach, persona, key metrics, and tracks. Re-runnable to update. Read as grounding by `/yunxing-ideate`, `/yunxing-brainstorm`, and `/yunxing-plan` when present                                                                    |
| [`/yunxing-ideate`](../../docs/skills/yunxing-ideate.md)                     | Optional big-picture ideation: generate and critically evaluate grounded ideas, then route the strongest one into brainstorming                                                                                                                                                         |
| [`/yunxing-brainstorm`](../../docs/skills/yunxing-brainstorm.md)             | Interactive Q&A to think through a feature or problem and write a right-sized requirements doc before planning. Pass `output:html` to write the doc as a single self-contained HTML file instead of markdown (exclusive — md OR html, never both)                                       |
| [`/yunxing-plan`](../../docs/skills/yunxing-plan.md)                         | Create structured plans for any multi-step task -- software features, research workflows, events, study plans -- with automatic confidence checking. Pass `output:html` to write the plan as a single self-contained HTML file instead of markdown (exclusive — md OR html, never both) |
| [`/yunxing-code-review`](../../docs/skills/yunxing-code-review.md)           | Structured code review with tiered persona agents, confidence gating, and dedup pipeline                                                                                                                                                                                                |
| [`/yunxing-work`](../../docs/skills/yunxing-work.md)                         | Execute work items systematically                                                                                                                                                                                                                                                       |
| [`/yunxing-debug`](../../docs/skills/yunxing-debug.md)                       | Systematically find root causes and fix bugs -- traces causal chains, forms testable hypotheses, and implements test-first fixes                                                                                                                                                        |
| [`/yunxing-compound`](../../docs/skills/yunxing-compound.md)                 | Document solved problems to compound team knowledge                                                                                                                                                                                                                                     |
| [`/yunxing-compound-refresh`](../../docs/skills/yunxing-compound-refresh.md) | Refresh stale or drifting learnings and decide whether to keep, update, replace, or archive them                                                                                                                                                                                        |
| [`/yunxing-optimize`](../../docs/skills/yunxing-optimize.md)                 | Run iterative optimization loops with parallel experiments, measurement gates, and LLM-as-judge quality scoring                                                                                                                                                                         |
| [`/yunxing-product-pulse`](../../docs/skills/yunxing-product-pulse.md)       | Generate a single-page, time-windowed report on usage, performance, errors, and followups. Saves reports to `docs/pulse-reports/` as a browseable timeline of what users experienced                                                                                                    |

### Research & Context

| Skill                                                                               | Description                                                                                                                                                                                                                 |
| ----------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`/yunxing-sessions`](../../docs/skills/yunxing-sessions.md)                                  | Ask questions about session history across Claude Code, Codex, and Cursor                                                                                                                                                   |
| [`/yunxing-slack-research`](../../docs/skills/yunxing-slack-research.md)                      | Search Slack for interpreted organizational context -- decisions, constraints, and discussion arcs                                                                                                                          |
| [`yunxing-riffrec-feedback-analysis`](../../docs/skills/yunxing-riffrec-feedback-analysis.md) | Convert [Riffrec](https://github.com/kieranklaassen/riffrec) recordings, videos, audio, or notes into structured feedback. Routes between setup, quick bug report, and extensive analysis that hands off to `yunxing-brainstorm` |

### Git Workflow

| Skill                                                                   | Description                                                                                                                                               |
| ----------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`yunxing-clean-gone-branches`](../../docs/skills/yunxing-clean-gone-branches.md) | Clean up local branches whose remote tracking branch is gone                                                                                              |
| [`yunxing-commit`](../../docs/skills/yunxing-commit.md)                           | Create a git commit with a value-communicating message                                                                                                    |
| [`yunxing-commit-push-pr`](../../docs/skills/yunxing-commit-push-pr.md)           | Commit, push, and open a PR with an adaptive description; also update an existing PR description, or generate a description on its own without committing |
| [`yunxing-worktree`](../../docs/skills/yunxing-worktree.md)                       | Manage Git worktrees for parallel development                                                                                                             |

### Workflow Utilities

| Skill                                                                    | Description                                                                                                                                                                                                    |
| ------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`/yunxing-demo-reel`](../../docs/skills/yunxing-demo-reel.md)                     | Capture a visual demo reel (GIF demos, terminal recordings, screenshots) for PRs with project-type-aware tier selection                                                                                        |
| [`/yunxing-promote`](../../docs/skills/yunxing-promote.md)                         | Draft user-facing announcement copy for a shipped feature (X post, changelog blurb, LinkedIn, email); voice-matched via the Spiral CLI when installed, a lite layer of editorial & social expertise without it |
| [`/yunxing-report-bug`](../../docs/skills/yunxing-report-bug.md)                   | Report a bug in the yunxing plugin                                                                                                                                                                               |
| [`/yunxing-resolve-pr-feedback`](../../docs/skills/yunxing-resolve-pr-feedback.md) | Resolve PR review feedback in parallel                                                                                                                                                                         |
| [`/yunxing-test-browser`](../../docs/skills/yunxing-test-browser.md)               | Run browser tests on PR-affected pages                                                                                                                                                                         |
| [`/yunxing-test-xcode`](../../docs/skills/yunxing-test-xcode.md)                   | Build and test iOS apps on simulator using XcodeBuildMCP                                                                                                                                                       |
| [`/yunxing-setup`](../../docs/skills/yunxing-setup.md)                             | Diagnose environment, install missing tools, and bootstrap project config                                                                                                                                      |
| [`/yunxing-update`](../../docs/skills/yunxing-update.md)                           | Check yunxing plugin version and fix stale cache (Claude Code only)                                                                                                                                              |
| [`/yunxing-release-notes`](../../docs/skills/yunxing-release-notes.md)             | Summarize recent yunxing plugin releases, or answer a question about a past release with a version citation                                                                                                      |
| `/yunxing-align`                                                                 | AI-initiated alignment: at every decision point, surface at least 3 ranked options with the best pre-selected as the default, so the sponsor confirms the optimal choice in one tap. Invoked by other skills at decision points |

### Development Frameworks

| Skill                                                           | Description                                                                                                                                           |
| --------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `yunxing-agent-native-architecture`                                  | Build AI agents using prompt-native architecture                                                                                                      |
| `yunxing-dhh-rails-style`                                            | Write Ruby/Rails code in DHH's 37signals style                                                                                                        |
| [`yunxing-frontend-design`](../../docs/skills/yunxing-frontend-design.md) | Create production-grade frontend interfaces                                                                                                           |
| [`yunxing-polish`](../../docs/skills/yunxing-polish.md)                   | Conversational UX polish — start a dev server, open the feature in a browser, and iterate together; auto-detects 8 frameworks. Manual invocation only |

### Review & Quality

| Skill                                                        | Description                                                                                                                                 |
| ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------- |
| [`yunxing-doc-review`](../../docs/skills/yunxing-doc-review.md)        | Review documents using parallel persona agents for role-specific feedback                                                                   |
| [`/yunxing-simplify-code`](../../docs/skills/yunxing-simplify-code.md) | Simplify recent code changes for reuse, quality, and efficiency — parallel reviewers find issues, fixes applied, behavior verified by tests |

### Content & Collaboration

| Skill                                       | Description                                                      |
| ------------------------------------------- | ---------------------------------------------------------------- |
| [`yunxing-proof`](../../docs/skills/yunxing-proof.md) | Create, edit, and share documents via Proof collaborative editor |

### Automation & Tools

| Skill                | Description                                        |
| -------------------- | -------------------------------------------------- |
| `yunxing-gemini-imagegen` | Generate and edit images using Google's Gemini API |

### Beta / Experimental

| Skill             | Description                                                                                                                                                                                                       |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `yunxing-dogfood-beta` | Diff-scoped browser QA of the active branch: builds an exhaustive test matrix of every change, drives the app with agent-browser, then auto-fixes issues, adds regression tests, and commits each fix until green |
| `/lfg`            | Full autonomous engineering workflow                                                                                                                                                                              |

## MCP Servers

The plugin ships a bundled [`.mcp.json`](.mcp.json). Two lightweight, no-API-key servers load automatically the moment the plugin is enabled:

| Server                | Auto-loads | Purpose                                          |
| --------------------- | ---------- | ------------------------------------------------ |
| `context7`            | ✅          | Up-to-date library / API documentation lookup    |
| `sequential-thinking` | ✅          | Structured multi-step reasoning                  |

Three heavier servers are **opt-in** — they pull large dependencies (browser binaries, a Python `uvx` toolchain, a Chrome install), so `/yunxing-setup` offers them but leaves them unchecked by default:

| Server            | Installs via                          | Purpose                                  |
| ----------------- | ------------------------------------- | ---------------------------------------- |
| `playwright`      | `claude mcp add playwright …`         | Cross-browser automation                 |
| `serena`          | `claude mcp add serena …`             | Codebase session memory (needs `uvx`)    |
| `chrome-devtools` | `claude mcp add chrome-devtools …`    | Performance / DevTools inspection        |

Run `/yunxing-setup` to check which MCP servers are registered (via `claude mcp list`) and install any missing ones interactively. MCP detection and `claude mcp add` install are Claude Code-specific; on other harnesses the MCP section is skipped.

## Agents

Agents are specialized subagents invoked by skills — you typically don't call these directly.

### Review

| Agent                               | Description                                                                                                |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `yunxing-agent-native-reviewer`          | Verify features are agent-native (action + context parity)                                                 |
| `yunxing-api-contract-reviewer`          | Detect breaking API contract changes                                                                       |
| `yunxing-architecture-strategist`        | Analyze architectural decisions and compliance                                                             |
| `yunxing-code-simplicity-reviewer`       | Final pass for simplicity and minimalism                                                                   |
| `yunxing-correctness-reviewer`           | Logic errors, edge cases, state bugs                                                                       |
| `yunxing-data-integrity-guardian`        | Database migrations and data integrity                                                                     |
| `yunxing-data-migration-reviewer`        | Schema drift, migration safety, mapping verification, deploy-window checks                                 |
| `yunxing-deployment-verification-agent`  | Create Go/No-Go deployment checklists for risky data changes                                               |
| `yunxing-julik-frontend-races-reviewer`  | Review JavaScript/Stimulus code for race conditions                                                        |
| `yunxing-maintainability-reviewer`       | Coupling, complexity, naming, dead code                                                                    |
| `yunxing-pattern-recognition-specialist` | Analyze code for patterns and anti-patterns                                                                |
| `yunxing-performance-oracle`             | Performance analysis and optimization                                                                      |
| `yunxing-performance-reviewer`           | Runtime performance with confidence calibration                                                            |
| `yunxing-reliability-reviewer`           | Production reliability and failure modes                                                                   |
| `yunxing-security-reviewer`              | Exploitable vulnerabilities with confidence calibration                                                    |
| `yunxing-security-sentinel`              | Security audits and vulnerability assessments                                                              |
| `yunxing-swift-ios-reviewer`             | Swift and iOS code review -- SwiftUI state, retain cycles, concurrency, Core Data threading, accessibility |
| `yunxing-testing-reviewer`               | Test coverage gaps, weak assertions                                                                        |
| `yunxing-project-standards-reviewer`     | CLAUDE.md and AGENTS.md compliance                                                                         |
| `yunxing-adversarial-reviewer`           | Construct failure scenarios to break implementations across component boundaries                           |

### Document Review

| Agent                              | Description                                                                      |
| ---------------------------------- | -------------------------------------------------------------------------------- |
| `yunxing-coherence-reviewer`            | Review documents for internal consistency, contradictions, and terminology drift |
| `yunxing-design-lens-reviewer`          | Review plans for missing design decisions, interaction states, and AI slop risk  |
| `yunxing-feasibility-reviewer`          | Evaluate whether proposed technical approaches will survive contact with reality |
| `yunxing-product-lens-reviewer`         | Challenge problem framing, evaluate scope decisions, surface goal misalignment   |
| `yunxing-scope-guardian-reviewer`       | Challenge unjustified complexity, scope creep, and premature abstractions        |
| `yunxing-security-lens-reviewer`        | Evaluate plans for security gaps at the plan level (auth, data, APIs)            |
| `yunxing-adversarial-document-reviewer` | Challenge premises, surface unstated assumptions, and stress-test decisions      |

### Research

| Agent                           | Description                                                                                                                                     |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `yunxing-best-practices-researcher`  | Gather external best practices and examples                                                                                                     |
| `yunxing-framework-docs-researcher`  | Research framework documentation and best practices                                                                                             |
| `yunxing-git-history-analyzer`       | Analyze git history and code evolution                                                                                                          |
| `yunxing-issue-intelligence-analyst` | Analyze GitHub issues to surface recurring themes and pain patterns                                                                             |
| `yunxing-learnings-researcher`       | Search institutional learnings for relevant past solutions                                                                                      |
| `yunxing-repo-research-analyst`      | Research repository structure and conventions                                                                                                   |
| `yunxing-session-historian`          | Search prior Claude Code, Codex, and Cursor sessions for related investigation context                                                          |
| `yunxing-slack-researcher`           | Search Slack for organizational context relevant to the current task                                                                            |
| `yunxing-web-researcher`             | Perform iterative web research and return structured external grounding (prior art, adjacent solutions, market signals, cross-domain analogies) |

### Design

| Agent                               | Description                                                |
| ----------------------------------- | ---------------------------------------------------------- |
| `yunxing-design-implementation-reviewer` | Verify UI implementations match Figma designs              |
| `yunxing-design-iterator`                | Iteratively refine UI through systematic design iterations |
| `yunxing-figma-design-sync`              | Synchronize web implementations with Figma designs         |

### Workflow

| Agent                    | Description                                            |
| ------------------------ | ------------------------------------------------------ |
| `yunxing-pr-comment-resolver` | Address PR comments and implement fixes                |
| `yunxing-spec-flow-analyzer`  | Analyze user flows and identify gaps in specifications |

### Docs

| Agent                     | Description                                                  |
| ------------------------- | ------------------------------------------------------------ |
| `yunxing-ankane-readme-writer` | Create READMEs following Ankane-style template for Ruby gems |

## Installation

See the repo root [Install section](../../README.md#install) for current installation instructions across Claude Code, Codex, Cursor, Copilot, Droid, Qwen, and converter-backed targets.

Then run `/yunxing-setup` to check your environment and install recommended tools.

## Version History

See the repo root [CHANGELOG.md](../../CHANGELOG.md) for canonical release history.

## License

MIT
