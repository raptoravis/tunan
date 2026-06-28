# Compounding Engineering

AI-powered development tools that get smarter with every use. Make each unit of engineering work easier than the last.

## Getting Started

> **⚠️ Required next step after install — run `/tunan:setup`.** Installing the plugin only registers the skills; it does not configure your environment. Run `/tunan:setup` in any project to diagnose your environment, install missing tools and MCP servers, verify `gh` is installed and authenticated, and bootstrap project config in one interactive flow. Skipping it is the most common cause of skills failing on first use; re-run it anytime to re-check.

**Artifacts are GitHub issues, not local files.** Durable per-item artifacts are stored as GitHub issues, never as local files. A feature is **one issue** for its lifetime: the requirement is the issue body (label `tunan:req`), and `plan` and `solution` land as **comments** on that same issue, each keyed by a first-line marker (`<!-- tunan:plan -->` / `<!-- tunan:solution -->`). The feature issue accumulates a stage label as each stage lands (`tunan:req` → `+tunan:plan` → `+tunan:solution`), so a label like `tunan:solution` still indexes every feature that reached that stage. Other artifact kinds — ideas, reports, retros, dogfood runs, and review residuals — are their own issues distinguished by label (`tunan:idea`, `tunan:pulse`, `tunan:retro`, `tunan:dogfood`, `tunan:review`). This requires `gh` to be installed and authenticated (`gh auth status`); `/tunan:setup` verifies both. Skills create their labels on demand.

**Windows:** the skills run on Windows as well as macOS/Linux. Bundled helper scripts ship in both bash (`.sh`) and PowerShell (`.ps1`) form — the PowerShell variants are Windows PowerShell 5.1-compatible (no extra install) and are used automatically on Windows.

## Components

| Component   | Count |
| ----------- | ----- |
| Agents      | 50+   |
| Skills      | 41+   |
| MCP Servers | 5     |

## Skills

The primary entry points for engineering work, invoked as slash commands. Detailed user-facing documentation for many skills lives in [`docs/skills/`](../../docs/skills/) — each linked skill name below points to its page (purpose, novel mechanics, use cases, chain position). Skills without dedicated docs are still listed; their `SKILL.md` in the source tree is authoritative.

### Core Workflow

`new-project` anchors the loop upstream; `product-pulse` closes it with a read on user outcomes.

| Skill                                                              | Description                                                                                                                                                                                                                                                                             |
| ------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/tunan:new-project`                                                      | Bootstrap a new project: establish intent (problem, approach, persona, key metrics, tracks) and an initial milestone roadmap, optionally seeding the first milestone's requirements. Stores everything in one GitHub issue labeled `tunan:project` (replaces the former `STRATEGY.md`). Read as grounding by `/tunan:ideate`, `/tunan:brainstorm`, `/tunan:plan`, `/tunan:product-pulse`, and `/tunan:dogfood-beta`                |
| `/tunan:new-milestone`                                                    | Start the next cycle of an existing project: close the current milestone, define and scope the next, and extend the roadmap in the `tunan:project` issue. Brownfield complement of `/tunan:new-project`                                                                          |
| `/tunan:strategy`                                                         | Sharpen the product strategy — the intent sections (target problem, approach, persona, key metrics, tracks) of the `tunan:project` issue — through a rigorous Rumelt-style interview that pushes back on weak answers. Writes the same issue `/tunan:new-project` bootstraps and `/tunan:new-milestone` extends, preserving the roadmap; `new-project` is the quick bootstrap, `strategy` is the deep intent refinement                |
| `/tunan:map-codebase`                                                     | Map an existing codebase into a durable current-state snapshot (stack, integrations, architecture, structure, conventions, testing, concerns) stored as one GitHub issue labeled `tunan:codebase-map`. Read as grounding by `/tunan:plan`, `/tunan:work`, and technical `/tunan:brainstorm`                |
| [`/tunan:ideate`](../../docs/skills/ideate.md)                     | Optional big-picture ideation: generate and critically evaluate grounded ideas, then route the strongest one into brainstorming. Stores the ideation record as a GitHub issue labeled `tunan:idea`                                                                                     |
| `/tunan:capture`                                                          | Zero-friction capture of a passing idea, note, backlog item, or seed (a forward-looking idea with a trigger condition) into a lightweight GitHub issue labeled `tunan:capture` / `tunan:backlog`, without derailing the current task. `--list` browses and triages captured items, promoting them to `tunan:raw`. The lightest rung before `/tunan:new-raw` |
| [`/tunan:new-raw`](../../docs/skills/new-raw.md)                     | Capture a requirement described in conversation (text plus screenshots/videos) into a GitHub issue labeled `tunan:raw` — the raw source of truth that `/tunan:brainstorm` reads, normalizes, and promotes to `tunan:req`                                                            |
| [`/tunan:brainstorm`](../../docs/skills/brainstorm.md)             | Interactive Q&A to think through a feature or problem; writes a right-sized requirements doc into a GitHub issue labeled `tunan:req` (the source of truth) before planning. Pass a `tunan:raw` capture or `tunan:req` issue ref to resume or expand one captured by `/tunan:new-raw`  |
| `/tunan:req`                                                              | Short alias for `/tunan:brainstorm` — same workflow, named after the `tunan:req` artifact it produces                                                                                                                                                                               |
| [`/tunan:plan`](../../docs/skills/plan.md)                         | Create structured plans for any multi-step task -- software features, research workflows, events, study plans -- with automatic confidence checking. Writes the plan as a `<!-- tunan:plan -->` comment on the feature's `tunan:req` issue (adding the `tunan:plan` label) and reads requirements from that same issue body. For software plans it also freezes an acceptance gate (a `<!-- tunan:gate -->` comment, label `tunan:gate`) — the verbatim criteria `tunan:verify` / `code-review` later judge the work against |
| [`/tunan:code-review`](../../docs/skills/code-review.md)           | Structured code review with tiered persona agents, confidence gating, and dedup pipeline                                                                                                                                                                                                |
| [`/tunan:work`](../../docs/skills/work.md)                         | Execute work items systematically                                                                                                                                                                                                                                                       |
| [`/tunan:debug`](../../docs/skills/debug.md)                       | Systematically find root causes and fix bugs -- traces causal chains, forms testable hypotheses, and implements test-first fixes                                                                                                                                                        |
| [`/tunan:compound`](../../docs/skills/compound.md)                 | Document solved problems to compound team knowledge                                                                                                                                                                                                                                     |
| [`/tunan:compound-refresh`](../../docs/skills/compound-refresh.md) | Refresh stale or drifting learnings and decide whether to keep, update, replace, or archive them                                                                                                                                                                                        |
| [`/tunan:optimize`](../../docs/skills/optimize.md)                 | Run iterative optimization loops with parallel experiments, measurement gates, and LLM-as-judge quality scoring                                                                                                                                                                         |
| [`/tunan:product-pulse`](../../docs/skills/product-pulse.md)       | Generate a single-page, time-windowed report on usage, performance, errors, and followups. Stores each report as a GitHub issue labeled `tunan:pulse`; the labeled issue list is the browseable timeline of what users experienced                                                                                                    |
| `/tunan:retro`                                                              | Engineering-cadence complement of `product-pulse`: a zero-config, time-windowed retrospective on what actually shipped (merged PRs, closed features), cadence (shipping streak, PR cycle time, per-author), in-flight/stuck work, and the window's `tunan:solution` learnings. Reads `git` + `gh` only; stores each report as a GitHub issue labeled `tunan:retro`                                                                    |

### Research & Context

| Skill                                                                               | Description                                                                                                                                                                                                                 |
| ----------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`/tunan:sessions`](../../docs/skills/sessions.md)                                  | Ask questions about session history across Claude Code, Codex, and Cursor                                                                                                                                                   |
| [`/tunan:slack-research`](../../docs/skills/slack-research.md)                      | Search Slack for interpreted organizational context -- decisions, constraints, and discussion arcs                                                                                                                          |
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
| `closeissue`                                                    | Close a specified issue, or the feature issue for the req/plan currently being worked on — resolves the target by explicit number, current branch's PR body, branch name, or a req/plan search, and confirms before closing (never reopens, deletes, or force-closes)                     |
| `status`                                                        | Read-only snapshot of what's left — lists open PRs, open issues, and unfinished items in `tunan:handoff` handoffs. Defaults to current user; `--user <name>` queries a specific user, `--all` shows everyone, `--req` filters issues to `tunan:req`. Creates nothing (unlike `retro`)                                                    |
| `resume`                                                        | Resume an interrupted `lfg` feature pipeline at the right stage instead of re-running from step 1 — reads the feature issue's labels, marker comments, and any open PR to detect the phase (`plan` / `work` / `review-ci` / `done`) and dispatches to the correct next skill                |
| `handoff`                                                       | Transfer working context between AI coding sessions via a GitHub issue labeled `tunan:handoff` instead of a local `HANDOFF.md`. `create` captures the task, progress, failed approaches, key decisions, and resume steps into an issue; `resume` reads the latest handoff issue, checks for git drift, and continues. Free-form session transfer, distinct from `resume` (which routes a feature pipeline by phase markers) |
| `hotfix`                                                        | Fast-path `lfg` for a bug fix — full pipeline (work → verify → review → PR → CI watch → compound) but skips brainstorm and plan deepening for a minimal plan. Evidence gates (verify, CI, compound) are never waived. Equivalent to `lfg --hotfix`                                            |
| `tweak`                                                         | Fast-path `lfg` for a small change — minimal plan plus the lightest code review (always-on correctness only). Evidence gates are never waived. Equivalent to `lfg --tweak`                                                                                                                  |

### Workflow Utilities

| Skill                                                                    | Description                                                                                                                                                                                                    |
| ------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`/tunan:demo-reel`](../../docs/skills/demo-reel.md)                     | Capture a visual demo reel (GIF demos, terminal recordings, screenshots) for PRs with project-type-aware tier selection                                                                                        |
| [`/tunan:promote`](../../docs/skills/promote.md)                         | Draft user-facing announcement copy for a shipped feature (X post, changelog blurb, LinkedIn, email); voice-matched via the Spiral CLI when installed, a lite layer of editorial & social expertise without it |
| [`/tunan:report-bug`](../../docs/skills/report-bug.md)                   | Report a bug in the tunan plugin                                                                                                                                                                               |
| [`/tunan:resolve-pr-feedback`](../../docs/skills/resolve-pr-feedback.md) | Resolve PR review feedback in parallel                                                                                                                                                                         |
| [`/tunan:test-browser`](../../docs/skills/test-browser.md)               | Run browser tests on PR-affected pages                                                                                                                                                                         |
| [`/tunan:test-xcode`](../../docs/skills/test-xcode.md)                   | Build and test iOS apps on simulator using XcodeBuildMCP                                                                                                                                                       |
| [`/tunan:setup`](../../docs/skills/setup.md)                             | Diagnose environment, install missing tools, and bootstrap project config                                                                                                                                      |
| [`/tunan:update`](../../docs/skills/update.md)                           | Check tunan plugin version and fix stale cache (Claude Code only)                                                                                                                                              |
| `/tunan:sync-ups`                                                                 | Maintainer: merge the latest upstream `everyinc/compound-engineering-plugin` changes into the local tunan fork — computes the delta since the last synced commit, ports skill changes with the branding transform, flags dead files, and records the new sync point |
| `/tunan:sync-gsd`                                                                 | Maintainer: audit upstream `open-gsd/gsd-core` for new capabilities worth absorbing into tunan — computes the delta since the last-absorbed commit, classifies it into capabilities (changesets are the index), surfaces each for a keep/skip decision, re-expresses accepted ones in tunan's own skill shapes, and records the new audit baseline. Capability audit, not a file port |
| [`/tunan:release-notes`](../../docs/skills/release-notes.md)             | Summarize recent tunan plugin releases, or answer a question about a past release with a version citation                                                                                                      |
| `/tunan:align`                                                                 | AI-initiated alignment: at every decision point, surface at least 3 ranked options with the best pre-selected as the default, so the sponsor confirms the optimal choice in one tap. Invoked by other skills at decision points |

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
| `verify`                                                    | Run a project's test/lint/build checks (and optionally delegate dynamic observation to `test-browser`), judge the feature's frozen acceptance gate (`gate:#N`) verbatim into a `gates[]` PASS/FAIL/INVALID dimension, and emit the same schema-versioned `mode:agent` contract as `code-review`; used as `lfg`'s local green gate. Invoke as `tunan:verify`                |
| [`/tunan:simplify-code`](../../docs/skills/simplify-code.md) | Simplify recent code changes for reuse, quality, and efficiency — parallel reviewers find issues, fixes applied, behavior verified by tests |

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
| `codegraph`           | ✅          | Structural code search via AST index             |

Two heavier servers are **opt-in** — they pull large dependencies (browser binaries, a Chrome install), so `/tunan:setup` offers them but leaves them unchecked by default:

| Server            | Installs via                          | Purpose                                  |
| ----------------- | ------------------------------------- | ---------------------------------------- |
| `playwright`      | `claude mcp add playwright …`         | Cross-browser automation                 |
| `chrome-devtools` | `claude mcp add chrome-devtools …`    | Performance / DevTools inspection        |

Run `/tunan:setup` to check which MCP servers are registered (via `claude mcp list`) and install any missing ones interactively. MCP detection and `claude mcp add` install are Claude Code-specific; on other harnesses the MCP section is skipped.

## Agents

Agents are specialized subagents invoked by skills — you typically don't call these directly.

### Review

| Agent                               | Description                                                                                                |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `tunan:agent-native-reviewer`          | Verify features are agent-native (action + context parity)                                                 |
| `tunan:api-contract-reviewer`          | Detect breaking API contract changes                                                                       |
| `tunan:architecture-strategist`        | Analyze architectural decisions and compliance                                                             |
| `tunan:code-simplicity-reviewer`       | Final pass for simplicity and minimalism                                                                   |
| `tunan:correctness-reviewer`           | Logic errors, edge cases, state bugs                                                                       |
| `tunan:data-integrity-guardian`        | Database migrations and data integrity                                                                     |
| `tunan:data-migration-reviewer`        | Schema drift, migration safety, mapping verification, deploy-window checks                                 |
| `tunan:deployment-verification-agent`  | Create Go/No-Go deployment checklists for risky data changes                                               |
| `tunan:julik-frontend-races-reviewer`  | Review JavaScript/Stimulus code for race conditions                                                        |
| `tunan:maintainability-reviewer`       | Coupling, complexity, naming, dead code                                                                    |
| `tunan:pattern-recognition-specialist` | Analyze code for patterns and anti-patterns                                                                |
| `tunan:performance-oracle`             | Performance analysis and optimization                                                                      |
| `tunan:performance-reviewer`           | Runtime performance with confidence calibration                                                            |
| `tunan:reliability-reviewer`           | Production reliability and failure modes                                                                   |
| `tunan:security-reviewer`              | Exploitable vulnerabilities with confidence calibration                                                    |
| `tunan:security-sentinel`              | Security audits and vulnerability assessments                                                              |
| `tunan:swift-ios-reviewer`             | Swift and iOS code review -- SwiftUI state, retain cycles, concurrency, Core Data threading, accessibility |
| `tunan:testing-reviewer`               | Test coverage gaps, weak assertions                                                                        |
| `tunan:project-standards-reviewer`     | CLAUDE.md and AGENTS.md compliance                                                                         |
| `tunan:adversarial-reviewer`           | Construct failure scenarios to break implementations across component boundaries                           |

### Document Review

| Agent                              | Description                                                                      |
| ---------------------------------- | -------------------------------------------------------------------------------- |
| `tunan:coherence-reviewer`            | Review documents for internal consistency, contradictions, and terminology drift |
| `tunan:design-lens-reviewer`          | Review plans for missing design decisions, interaction states, and AI slop risk  |
| `tunan:feasibility-reviewer`          | Evaluate whether proposed technical approaches will survive contact with reality |
| `tunan:product-lens-reviewer`         | Challenge problem framing, evaluate scope decisions, surface goal misalignment   |
| `tunan:scope-guardian-reviewer`       | Challenge unjustified complexity, scope creep, and premature abstractions        |
| `tunan:security-lens-reviewer`        | Evaluate plans for security gaps at the plan level (auth, data, APIs)            |
| `tunan:adversarial-document-reviewer` | Challenge premises, surface unstated assumptions, and stress-test decisions      |

### Research

| Agent                           | Description                                                                                                                                     |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `tunan:best-practices-researcher`  | Gather external best practices and examples                                                                                                     |
| `tunan:framework-docs-researcher`  | Research framework documentation and best practices                                                                                             |
| `tunan:git-history-analyzer`       | Analyze git history and code evolution                                                                                                          |
| `tunan:issue-intelligence-analyst` | Analyze GitHub issues to surface recurring themes and pain patterns                                                                             |
| `tunan:learnings-researcher`       | Search institutional learnings for relevant past solutions                                                                                      |
| `tunan:repo-research-analyst`      | Research repository structure and conventions                                                                                                   |
| `tunan:session-historian`          | Search prior Claude Code, Codex, and Cursor sessions for related investigation context                                                          |
| `tunan:slack-researcher`           | Search Slack for organizational context relevant to the current task                                                                            |
| `tunan:web-researcher`             | Perform iterative web research and return structured external grounding (prior art, adjacent solutions, market signals, cross-domain analogies) |

### Design

| Agent                               | Description                                                |
| ----------------------------------- | ---------------------------------------------------------- |
| `tunan:design-implementation-reviewer` | Verify UI implementations match Figma designs              |
| `tunan:design-iterator`                | Iteratively refine UI through systematic design iterations |
| `tunan:figma-design-sync`              | Synchronize web implementations with Figma designs         |

### Workflow

| Agent                    | Description                                            |
| ------------------------ | ------------------------------------------------------ |
| `tunan:pr-comment-resolver` | Address PR comments and implement fixes                |
| `tunan:spec-flow-analyzer`  | Analyze user flows and identify gaps in specifications |

### Docs

| Agent                     | Description                                                  |
| ------------------------- | ------------------------------------------------------------ |
| `tunan:ankane-readme-writer` | Create READMEs following Ankane-style template for Ruby gems |

## Installation

See the repo root [Install section](../../README.md#install) for current installation instructions across Claude Code, Codex, OpenCode, and other platforms.

### Cross-platform installer

For a unified installation experience, use the install scripts:

```bash
# Clone the repository
git clone https://github.com/raptoravis/tunan.git
cd tunan

# Install for specific platform
./install.sh --target claude    # Claude Code
./install.sh --target codex     # Codex
./install.sh --target opencode  # OpenCode
./install.sh --target all       # All platforms

# Preview what would be installed
./install.sh --dry-run
```

Windows PowerShell:

```powershell
# Install for specific platform
.\install.ps1 -Target claude    # Claude Code
.\install.ps1 -Target codex     # Codex
.\install.ps1 -Target opencode  # OpenCode
.\install.ps1 -Target all       # All platforms

# Preview what would be installed
.\install.ps1 -DryRun
```

Then run `/tunan:setup` to check your environment and install recommended tools.

## Version History

See the repo root [CHANGELOG.md](../../CHANGELOG.md) for canonical release history.

## License

MIT
