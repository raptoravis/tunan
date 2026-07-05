# Codebase map — issue body contract

The `tunan:codebase-map` issue body is one provenance header followed by seven `##` sections, always in this order. This is the issue-state equivalent of GSD's seven `.planning/codebase/*.md` files — one body, seven headings, no local files.

## Provenance header

The body opens with a fenced `yaml` block. `status`/`diff` parse it to compute drift, so the keys and shape are load-bearing.

````markdown
```yaml
mapped_at_sha: <full git HEAD sha at map time>
mapped_at_date: <YYYY-MM-DD>
mode: full            # full | fast
focus: tech+arch      # present only when mode is fast; omit otherwise
codegraph: indexed    # indexed | unavailable — whether CodeGraph backed this map
```
````

When `fast --focus` rewrites only some sections, still refresh `mapped_at_sha`/`mapped_at_date` so staleness stays meaningful, and set `mode: fast` with the `focus` used.

## The seven sections

Keep each section tight and current-state. A thin section gets one honest line, not invented structure.

1. **`## STACK`** — languages, runtimes, frameworks, build tooling, package managers, and versions actually in use. The "what is this written in and with."
2. **`## INTEGRATIONS`** — external systems the code talks to: databases, queues, third-party APIs, auth providers, cloud services, MCP servers. Note how each is reached (SDK, REST, env-configured). "no external integrations" is a valid, useful answer.
3. **`## ARCHITECTURE`** — the system's shape: layers, major modules and their responsibilities, the dominant patterns and data/control flow between parts. Prefer CodeGraph (`codegraph_context`, `codegraph_explore`, `codegraph_impact`) over prose guessing.
4. **`## STRUCTURE`** — directory layout and where things live: entry points, where features vs. infrastructure vs. tests sit, naming conventions for files/dirs. The map a newcomer needs to find anything.
5. **`## CONVENTIONS`** — coding standards and idioms actually followed: error handling, naming, state management, formatting/lint rules, recurring patterns. What a reviewer would expect new code to match. (Distinct from `CONCEPTS.md`, which is domain vocabulary — this is code style.)
6. **`## TESTING`** — test frameworks, where tests live, what is covered vs. not, how the suite runs, and any CI gates. Honest about gaps.
7. **`## CONCERNS`** — current technical risk and debt: fragile areas, known bugs, missing coverage, coupling, security/scaling worries, drift. Real and observed, not speculative. This is the section planning reads first.

## Diff / revision markers

- A revision changelog comment starts with `<!-- tunan:map-revision -->` then 1–3 lines naming which sections materially changed and the new SHA.
- A `diff`-mode comment (review, not applied) starts with `<!-- tunan:map-diff -->` then a per-section summary of what a refresh would change.

These HTML-comment markers let later runs (and humans) distinguish revision history from review proposals without parsing prose.
