# tunan:project issue — body contract

The `tunan:project` issue is the project's living document: project intent (the former `STRATEGY.md` content) **plus** the roadmap (an ordered milestone ledger). One per repo, updated in place, never duplicated, never a local file. It is the upstream grounding read by `ideate`, `brainstorm`, `plan`, `product-pulse`, and `dogfood-beta`.

This contract is duplicated byte-for-byte across `new-project/references/project-issue-contract.md` and `new-milestone/references/project-issue-contract.md`. Edits must be applied to both copies in the same commit.

## Read recipe (consumers and both skills)

```bash
gh issue list --label "tunan:project" --state open --json number --jq '.[0].number // empty'
```

If that returns a number `<N>`, read and parse its body:

```bash
gh issue view <N> --json body --jq .body
```

Absent → no project doc on file. Consumers fall through to their own defaults; never block, never read a local `STRATEGY.md`.

## Write / update recipe

Write the assembled body to a temp file, then:

- **First write** — `gh issue create --title "[project] <name>" --label "tunan:project" --body-file <tmpfile>`
- **Update in place** — `gh issue edit <N> --body-file <tmpfile>`
- **Milestone-cycle note** (new-milestone) — after updating, add a comment beginning `<!-- tunan:project-revision -->` with a one-line changelog (`closed M2; opened M3 — <scope>`).

## Body shape

A YAML frontmatter block, five intent sections (locked order), then the roadmap, then optional sections.

````markdown
```yaml
name: <project name>
last_updated: <YYYY-MM-DD>
current_milestone: <milestone id, e.g. M2>
codebase_map: <#N of the tunan:codebase-map issue if one exists; omit otherwise>
```

## Target problem

<1–2 sentence diagnosis: the user situation and the crux that makes it hard. No solution language.>

## Our approach

<1–2 sentence guiding policy: what the project commits to, so the problem becomes tractable.>

## Who it's for

**Primary:** <persona> — <one-sentence JTBD>

## Key metrics

- **<metric>** — <one-line definition; where it's measured>
<!-- 3–5 total. -->

## Tracks

### <Track name>

<one line: the investment area, not a feature list.>
_Why it serves the approach:_ <one line>
<!-- 2–4 tracks. -->

## Roadmap

### M1 — <name> ✅ done (shipped <YYYY-MM-DD>)

<one-line outcome/scope>
- #<req> <title> ✅
- #<req> <title> ✅

### M2 — <name> 🚧 current

<one-line outcome/scope>
- #<req> <title>
- #<req> <title>

### M3 — <name> 📋 planned

<one-line intention — refined by new-milestone when its turn comes>

## Not working on

- <one line per item>
<!-- Optional. Delete the section if unused. -->

## Marketing

**One-liner:** <single-sentence pitch>
<!-- Optional. Delete the section if unused. -->
````

## Rules

- Use the user's own language; do not paraphrase into generic PM-speak.
- Intent sections stay compact (≤4 sentences each, Tracks excepted). Metric count 3–5; track count 2–4.
- `current_milestone` always names the one `🚧 current` milestone. Exactly one milestone is current at a time.
- Milestone status markers: `✅ done` / `🚧 current` / `📋 planned`. Only milestone 1 (or the current one) and earlier are scoped concretely with linked `#<req>` refs; planned milestones are one-liners.
- `last_updated` carries today's ISO date on every write.
- Optional sections: delete entirely if unused; never leave empty headers.
- All issue refs are `#<N>` numbers/URLs — never local file paths.
