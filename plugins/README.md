# Compounding Engineering

AI-powered development tools that get smarter with every use. Make each unit of engineering work easier than the last.

## Getting Started

> **⚠️ Required next step after install — run `/yunxing:setup`.** Installing the plugin only registers the skills; it does not configure your environment. Run `/yunxing:setup` in any project to diagnose your environment, install missing tools and MCP servers, verify `gh` is installed and authenticated, and bootstrap project config in one interactive flow. Skipping it is the most common cause of skills failing on first use; re-run it anytime to re-check.

**Artifacts are GitHub issues, not local files.** Durable per-item artifacts are stored as GitHub issues, never as local files. A feature is **one issue** for its lifetime: the requirement is the issue body (label `yunxing:req`), and `plan` and `solution` land as **comments** on that same issue, each keyed by a first-line marker (`<!-- yunxing:plan -->` / `<!-- yunxing:solution -->`). The feature issue accumulates a stage label as each stage lands (`yunxing:req` → `+yunxing:plan` → `+yunxing:solution`), so a label like `yunxing:solution` still indexes every feature that reached that stage. Other artifact kinds — ideas, reports, dogfood runs, and review residuals — are their own issues distinguished by label (`yunxing:idea`, `yunxing:pulse`, `yunxing:dogfood`, `yunxing:review`). This requires `gh` to be installed and authenticated (`gh auth status`); `/yunxing:setup` verifies both. Skills create their labels on demand.

**Windows:** the skills run on Windows as well as macOS/Linux. Bundled helper scripts ship in both bash (`.sh`) and PowerShell (`.ps1`) form — the PowerShell variants are Windows PowerShell 5.1-compatible (no extra install) and are used automatically on Windows.

## Components

| Component   | Count |
| ----------- | ----- |
| Agents      | 50+   |
| Skills      | 40+   |
| MCP Servers | 5     |

## Skills

The primary entry points for engineering work, invoked as slash commands. Detailed user-facing documentation for many skills lives in [`docs/skills/`](../../docs/skills/) — each linked skill name below points to its page (purpose, novel mechanics, use cases, chain position). Skills without dedicated docs are still listed; their `SKILL.md` in the source tree is authoritative.

### Core Workflow

`strategy` anchors the loop upstream; `product-pulse` closes it with a read on user outcomes.

| Skill                                                              | Description                                                                                                                                                                                                                                                                             |
| ------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`/yunxing:strategy`](../../docs/skills/strategy.md)                 | Create or maintain `STRATEGY.md` — the product's target problem, approach, persona, key metrics, and tracks. Re-runnable to update. Read as grounding by `/yunxing:ideate`, `/yunxing:brainstorm`, and `/yunxing:plan` when present                                                                    |
| [`/yunxing:ideate`](../../docs/skills/ideate.md)                     | Optional big-picture ideation: generate and critically evaluate grounded ideas, then route the strongest one into brainstorming. Stores the ideation record as a GitHub issue labeled `yunxing:idea`                                                                                     |
| [`/yunxing:newreq`](../../docs/skills/newreq.md)                     | Capture a requirement described in conversation (text plus screenshots/videos) into a GitHub issue labeled `yunxing:req` — the source of truth that `/yunxing:brainstorm` and `/yunxing:plan` read and write back to                                                                     |
| [`/yunxing:brainstorm`](../../docs/skills/brainstorm.md)             | Interactive Q&A to think through a feature or problem; writes a right-sized requirements doc into a GitHub issue labeled `yunxing:req` (the source of truth) before planning. Pass a `yunxing:req` issue ref to resume or expand one captured by `/yunxing:newreq`                        |
| `/yunxing:req`                                                              | Short alias for `/yunxing:brainstorm` — same workflow, named after the `yunxing:req` artifact it produces                                                                                                                                                                               |
| [`/yunxing:plan`](../../docs/skills/plan.md)                         | Create structured plans for any multi-step task -- software features, research workflows, events, study plans -- with automatic confidence checking. Writes the plan as a `<!-- yunxing:plan -->` comment on the feature's `yunxing:req` issue (adding the `yunxing:plan` label) and reads requirements from that same issue body |
| [`/yunxing:code-review`](../../docs/skills/code-review.md)           | Structured code review with tiered persona agents, confidence gating, and dedup pipeline                                                                                                                                                                                                |
| [`/yunxing:work`](../../docs/skills/work.md)                         | Execute work items systematically                                                                                                                                                                                                                                                       |
| [`/yunxing:debug`](../../docs/skills/debug.md)                       | Systematically find root causes and fix bugs -- traces causal chains, forms testable hypotheses, and implements test-first fixes                                                                                                                                                        |
| [`/yunxing:compound`](../../docs/skills/compound.md)                 | Document solved problems to compound team knowledge                                                                                                                                                                                                                                     |
| [`/yunxing:compound-refresh`](../../docs/skills/compound-refresh.md) | Refresh stale or drifting learnings and decide whether to keep, update, replace, or archive them                                                                                                                                                                                        |
| [`/yunxing:optimize`](../../docs/skills/optimize.md)                 | Run iterative optimization loops with parallel experiments, measurement gates, and LLM-as-judge quality scoring                                                                                                                                                                         |
| [`/yunxing:product-pulse`](../../docs/skills/product-pulse.md)       | Generate a single-page, time-windowed report on usage, performance, errors, and followups. Stores each report as a GitHub issue labeled `yunxing:pulse`; the labeled issue list is the browseable timeline of what users experienced                                                                                                    |

### Research & Context

| Skill                                                                               | Description                                                                                                                                                                                                                 |
| ----------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`/yunxing:sessions`](../../docs/skills/sessions.md)                                  | Ask questions about session history across Claude Code, Codex, and Cursor                                                                                                                                                   |
| [`/yunxing:slack-research`](../../docs/skills/slack-research.md)                      | Search Slack for interpreted organizational context -- decisions, constraints, and discussion arcs                                                                                                                          |
| [`riffrec-feedback-analysis`](../../docs/skills/riffrec-feedback-analysis.md) | Convert [Riffrec](https://github.com/kieranklaassen/riffrec) recordings, videos, audio, or notes into structured feedback. Routes between setup, quick bug report, and extensive analysis that hands off to `brainstorm` |

### Git Workflow

| Skill                                                                   | Description                                                                                                                                               |
| ----------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`clean-gone-branches`](../../docs/skills/clean-gone-branches.md) | Clean up local branches whose remote tracking branch is gone                                                                                              |
| [`commit`](../../docs/skills/commit.md)                           | Create a git commit with a value-communicating message                                                                                                    |
| [`commit-push-pr`](../../docs/skills/commit-push-pr.md)           | Commit, push, and open a PR with an adaptive description; also update an existing PR description, or generate a description on its own without committing |
| `cp`                                                              | Commit + push the current changes; auto-drafts the message and follows the global git-commit-push discipline. On a protected base (`main` / `master` / `dev` / `test`) it asks before pushing unless `--am` is passed                                                                |
| `cpm`                                                             | Same as `cp` but with `--am` defaulted on — pushes directly to a protected base without the confirmation prompt (a thin delegate to `cp`; pass `--no-am` to restore the prompt)                                                                                                       |
| [`worktree`](../../docs/skills/worktree.md)                       | Manage Git worktrees for parallel development                                                                                                             |
| `merge-pr-verify-close`                                          | Merge a reviewed, CI-green PR, verify the merged base branch, then close the feature issue only when verification passes (never force-merges or bypasses branch protection). Invoke explicitly after human PR review — `lfg` does not call it                                              |

### Workflow Utilities

| Skill                                                                    | Description                                                                                                                                                                                                    |
| ------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`/yunxing:demo-reel`](../../docs/skills/demo-reel.md)                     | Capture a visual demo reel (GIF demos, terminal recordings, screenshots) for PRs with project-type-aware tier selection                                                                                        |
| [`/yunxing:promote`](../../docs/skills/promote.md)                         | Draft user-facing announcement copy for a shipped feature (X post, changelog blurb, LinkedIn, email); voice-matched via the Spiral CLI when installed, a lite layer of editorial & social expertise without it |
| [`/yunxing:report-bug`](../../docs/skills/report-bug.md)                   | Report a bug in the yunxing plugin                                                                                                                                                                               |
| [`/yunxing:resolve-pr-feedback`](../../docs/skills/resolve-pr-feedback.md) | Resolve PR review feedback in parallel                                                                                                                                                                         |
| [`/yunxing:test-browser`](../../docs/skills/test-browser.md)               | Run browser tests on PR-affected pages                                                                                                                                                                         |
| [`/yunxing:test-xcode`](../../docs/skills/test-xcode.md)                   | Build and test iOS apps on simulator using XcodeBuildMCP                                                                                                                                                       |
| [`/yunxing:setup`](../../docs/skills/setup.md)                             | Diagnose environment, install missing tools, and bootstrap project config                                                                                                                                      |
| [`/yunxing:update`](../../docs/skills/update.md)                           | Check yunxing plugin version and fix stale cache (Claude Code only)                                                                                                                                              |
| [`/yunxing:release-notes`](../../docs/skills/release-notes.md)             | Summarize recent yunxing plugin releases, or answer a question about a past release with a version citation                                                                                                      |
| `/yunxing:align`                                                                 | AI-initiated alignment: at every decision point, surface at least 3 ranked options with the best pre-selected as the default, so the sponsor confirms the optimal choice in one tap. Invoked by other skills at decision points |

### Development Frameworks

| Skill                                                           | Description                                                                                                                                           |
| --------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `agent-native-architecture`                                  | Build AI agents using prompt-native architecture                                                                                                      |
| `dhh-rails-style`                                            | Write Ruby/Rails code in DHH's 37signals style                                                                                                        |
| [`frontend-design`](../../docs/skills/frontend-design.md) | Create production-grade frontend interfaces                                                                                                           |
| [`polish`](../../docs/skills/polish.md)                   | Conversational UX polish — start a dev server, open the feature in a browser, and iterate together; auto-detects 8 frameworks. Manual invocation only |

### Review & Quality

| Skill                                                        | Description                                                                                                                                 |
| ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------- |
| [`doc-review`](../../docs/skills/doc-review.md)        | Review documents using parallel persona agents for role-specific feedback                                                                   |
| `verify`                                                    | Run a project's test/lint/build checks (and optionally delegate dynamic observation to `test-browser`) and emit the same schema-versioned `mode:agent` contract as `code-review`; used as `lfg`'s local green gate. Invoke as `yunxing:verify`                |
| [`/yunxing:simplify-code`](../../docs/skills/simplify-code.md) | Simplify recent code changes for reuse, quality, and efficiency — parallel reviewers find issues, fixes applied, behavior verified by tests |

### Content & Collaboration

| Skill                                       | Description                                                      |
| ------------------------------------------- | ---------------------------------------------------------------- |
| [`proof`](../../docs/skills/proof.md) | Create, edit, and share documents via Proof collaborative editor |

### Automation & Tools

| Skill                | Description                                        |
| -------------------- | -------------------------------------------------- |
| `gemini-imagegen` | Generate and edit images using Google's Gemini API |

### Beta / Experimental

| Skill             | Description                                                                                                                                                                                                       |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `dogfood-beta` | Diff-scoped browser QA of the active branch: builds an exhaustive test matrix of every change, drives the app with agent-browser, then auto-fixes issues, adds regression tests, and commits each fix until green |
| `/lfg`            | Full autonomous engineering pipeline end-to-end: plan, work, code review, test, commit, push, open PR, watch CI, and fix CI failures until green — stops at an open PR for human review (does not auto-merge or close the issue)                                                                                                                                                 |

## MCP Servers

The plugin ships a bundled [`.mcp.json`](.mcp.json). Two lightweight, no-API-key servers load automatically the moment the plugin is enabled:

| Server                | Auto-loads | Purpose                                          |
| --------------------- | ---------- | ------------------------------------------------ |
| `context7`            | ✅          | Up-to-date library / API documentation lookup    |
| `sequential-thinking` | ✅          | Structured multi-step reasoning                  |

Two heavier servers are **opt-in** — they pull large dependencies (browser binaries, a Chrome install), so `/yunxing:setup` offers them but leaves them unchecked by default:

| Server            | Installs via                          | Purpose                                  |
| ----------------- | ------------------------------------- | ---------------------------------------- |
| `playwright`      | `claude mcp add playwright …`         | Cross-browser automation                 |
| `chrome-devtools` | `claude mcp add chrome-devtools …`    | Performance / DevTools inspection        |

Run `/yunxing:setup` to check which MCP servers are registered (via `claude mcp list`) and install any missing ones interactively. MCP detection and `claude mcp add` install are Claude Code-specific; on other harnesses the MCP section is skipped.

## Agents

Agents are specialized subagents invoked by skills — you typically don't call these directly.

### Review

| Agent                               | Description                                                                                                |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `yunxing:agent-native-reviewer`          | Verify features are agent-native (action + context parity)                                                 |
| `yunxing:api-contract-reviewer`          | Detect breaking API contract changes                                                                       |
| `yunxing:architecture-strategist`        | Analyze architectural decisions and compliance                                                             |
| `yunxing:code-simplicity-reviewer`       | Final pass for simplicity and minimalism                                                                   |
| `yunxing:correctness-reviewer`           | Logic errors, edge cases, state bugs                                                                       |
| `yunxing:data-integrity-guardian`        | Database migrations and data integrity                                                                     |
| `yunxing:data-migration-reviewer`        | Schema drift, migration safety, mapping verification, deploy-window checks                                 |
| `yunxing:deployment-verification-agent`  | Create Go/No-Go deployment checklists for risky data changes                                               |
| `yunxing:julik-frontend-races-reviewer`  | Review JavaScript/Stimulus code for race conditions                                                        |
| `yunxing:maintainability-reviewer`       | Coupling, complexity, naming, dead code                                                                    |
| `yunxing:pattern-recognition-specialist` | Analyze code for patterns and anti-patterns                                                                |
| `yunxing:performance-oracle`             | Performance analysis and optimization                                                                      |
| `yunxing:performance-reviewer`           | Runtime performance with confidence calibration                                                            |
| `yunxing:reliability-reviewer`           | Production reliability and failure modes                                                                   |
| `yunxing:security-reviewer`              | Exploitable vulnerabilities with confidence calibration                                                    |
| `yunxing:security-sentinel`              | Security audits and vulnerability assessments                                                              |
| `yunxing:swift-ios-reviewer`             | Swift and iOS code review -- SwiftUI state, retain cycles, concurrency, Core Data threading, accessibility |
| `yunxing:testing-reviewer`               | Test coverage gaps, weak assertions                                                                        |
| `yunxing:project-standards-reviewer`     | CLAUDE.md and AGENTS.md compliance                                                                         |
| `yunxing:adversarial-reviewer`           | Construct failure scenarios to break implementations across component boundaries                           |

### Document Review

| Agent                              | Description                                                                      |
| ---------------------------------- | -------------------------------------------------------------------------------- |
| `yunxing:coherence-reviewer`            | Review documents for internal consistency, contradictions, and terminology drift |
| `yunxing:design-lens-reviewer`          | Review plans for missing design decisions, interaction states, and AI slop risk  |
| `yunxing:feasibility-reviewer`          | Evaluate whether proposed technical approaches will survive contact with reality |
| `yunxing:product-lens-reviewer`         | Challenge problem framing, evaluate scope decisions, surface goal misalignment   |
| `yunxing:scope-guardian-reviewer`       | Challenge unjustified complexity, scope creep, and premature abstractions        |
| `yunxing:security-lens-reviewer`        | Evaluate plans for security gaps at the plan level (auth, data, APIs)            |
| `yunxing:adversarial-document-reviewer` | Challenge premises, surface unstated assumptions, and stress-test decisions      |

### Research

| Agent                           | Description                                                                                                                                     |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `yunxing:best-practices-researcher`  | Gather external best practices and examples                                                                                                     |
| `yunxing:framework-docs-researcher`  | Research framework documentation and best practices                                                                                             |
| `yunxing:git-history-analyzer`       | Analyze git history and code evolution                                                                                                          |
| `yunxing:issue-intelligence-analyst` | Analyze GitHub issues to surface recurring themes and pain patterns                                                                             |
| `yunxing:learnings-researcher`       | Search institutional learnings for relevant past solutions                                                                                      |
| `yunxing:repo-research-analyst`      | Research repository structure and conventions                                                                                                   |
| `yunxing:session-historian`          | Search prior Claude Code, Codex, and Cursor sessions for related investigation context                                                          |
| `yunxing:slack-researcher`           | Search Slack for organizational context relevant to the current task                                                                            |
| `yunxing:web-researcher`             | Perform iterative web research and return structured external grounding (prior art, adjacent solutions, market signals, cross-domain analogies) |

### Design

| Agent                               | Description                                                |
| ----------------------------------- | ---------------------------------------------------------- |
| `yunxing:design-implementation-reviewer` | Verify UI implementations match Figma designs              |
| `yunxing:design-iterator`                | Iteratively refine UI through systematic design iterations |
| `yunxing:figma-design-sync`              | Synchronize web implementations with Figma designs         |

### Workflow

| Agent                    | Description                                            |
| ------------------------ | ------------------------------------------------------ |
| `yunxing:pr-comment-resolver` | Address PR comments and implement fixes                |
| `yunxing:spec-flow-analyzer`  | Analyze user flows and identify gaps in specifications |

### Docs

| Agent                     | Description                                                  |
| ------------------------- | ------------------------------------------------------------ |
| `yunxing:ankane-readme-writer` | Create READMEs following Ankane-style template for Ruby gems |

## Installation

See the repo root [Install section](../../README.md#install) for current installation instructions across Claude Code, Codex, Cursor, Copilot, Droid, Qwen, and converter-backed targets.

Then run `/yunxing:setup` to check your environment and install recommended tools.

## Version History

See the repo root [CHANGELOG.md](../../CHANGELOG.md) for canonical release history.

## License

MIT
