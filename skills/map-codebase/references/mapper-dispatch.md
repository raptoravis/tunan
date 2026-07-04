# Mapper dispatch — parallel agents, serial write

`full` mode runs four mappers in parallel; `fast --focus <area>` runs the one matching mapper. Every mapper **returns its section markdown as its final message** — it never writes the issue. The orchestrator collects the returned sections and writes the issue once (SKILL.md Phase 2). Concurrent issue edits clobber; this split keeps discovery parallel and the write serial.

## Area → section assignment

| Mapper (area) | Produces sections | `--focus` value |
|---|---|---|
| Tech | `STACK`, `INTEGRATIONS` | `tech` |
| Architecture | `ARCHITECTURE`, `STRUCTURE` | `arch` |
| Quality | `CONVENTIONS`, `TESTING` | `quality` |
| Concerns | `CONCERNS` | `concerns` |

`fast` default focus is `tech+arch` (Tech + Architecture mappers).

## Dispatch rules

- Use the platform subagent primitive (`Agent`/`Task` in Claude Code, `spawn_agent` in Codex, `subagent` in Pi). Prefer bundled tunan agents or the `Explore` agent over platform-built-in bare names.
- Respect the platform's active-subagent cap; queue overflow; fall back to sequential dispatch where parallel is unsupported.
- Pass each mapper the repo root and the section contract location (`references/section-contract.md`) by path, not by inlining — the mapper reads only what it needs.

## CodeGraph-first instruction (include in every mapper prompt)

> Structural questions — what calls what, module layering, change-impact, where a symbol is defined — go through CodeGraph (`codegraph_context` first, then one `codegraph_explore` for the surfaced symbols; `codegraph_impact`/`codegraph_callers` for blast radius). CodeGraph is a pre-built AST index; do not rebuild it with grep+read loops. Use native file-search/read only for literal text (config values, comments, log strings) or to confirm a specific detail CodeGraph did not cover. If CodeGraph is not initialized, note `codegraph: unavailable` in your return and fall back to native search.

## Per-mapper prompt skeletons

Each prompt: name the area, name the exact sections to return, set the current-state framing, and require the CodeGraph-first rule above. Keep returns tight — honest one-liners for thin areas, no invented structure.

**Tech mapper** — "Map the technology surface of the repo at `<root>`. Return two markdown sections, `## STACK` (languages, runtimes, frameworks, build tooling, package managers, versions actually in use) and `## INTEGRATIONS` (external systems the code talks to — DBs, queues, third-party APIs, auth, cloud, MCP — and how each is reached). Read manifests/lockfiles for ground truth. 'No external integrations' is a valid answer. Return only the two sections."

**Architecture mapper** — "Map the architecture of the repo at `<root>`. Return `## ARCHITECTURE` (layers, major modules and responsibilities, dominant patterns, data/control flow) and `## STRUCTURE` (directory layout, entry points, where features vs. infra vs. tests live, file/dir naming). Use CodeGraph for layering and flow. Return only the two sections."

**Quality mapper** — "Map the code-quality conventions of the repo at `<root>`. Return `## CONVENTIONS` (error handling, naming, state management, lint/format rules, recurring idioms a reviewer expects new code to match — code style, not domain vocabulary) and `## TESTING` (frameworks, where tests live, coverage vs. gaps, how the suite runs, CI gates). Be honest about gaps. Return only the two sections."

**Concerns mapper** — "Surface the current technical risk and debt in the repo at `<root>`. Return one section `## CONCERNS`: fragile areas, known bugs, missing coverage, tight coupling, security/scaling worries, drift. Real and observed, not speculative — cite files/areas. This section is what planning reads first. Return only the one section."
