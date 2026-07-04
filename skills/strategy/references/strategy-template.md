# Strategy Template (tunan:project intent sections)

Loaded by `SKILL.md` after the interview is complete. Fill in the **intent sections** of the `tunan:project` issue body. These sections must match the `tunan:project` body contract exactly (the same shape `new-project` writes), so the issue stays consistent no matter which skill last edited it.

## Rules for filling in

- Use the user's own language where possible. Do not paraphrase into generic PM-speak.
- Intent sections stay compact: ≤4 sentences each (Tracks excepted). Metric count 3–5; track count 2–4.
- Section order is locked. Do not add new top-level intent sections.
- Optional sections (Not working on, Marketing): delete entirely if unused. Do not leave empty headers.
- Never emit a `## Roadmap`, `## Milestones`, or `current_milestone` value of your own on an update — those are owned by `new-project` / `new-milestone` and carried forward verbatim (see SKILL.md Phase 2 merge rule).

## First-run body (no `tunan:project` issue yet)

Write the full issue body: the YAML frontmatter, the filled intent sections below, then a placeholder roadmap. Omit `current_milestone` until a milestone exists.

~~~markdown
```yaml
name: {{project_name}}
last_updated: {{YYYY-MM-DD}}
```

## Target problem

{{1-2 sentence diagnosis. Names the user situation and the crux that makes it hard. No solution language.}}

## Our approach

{{1-2 sentence guiding policy. What the project commits to, so the target problem becomes tractable.}}

## Who it's for

**Primary:** {{persona}} — {{one-sentence JTBD}}

## Key metrics

- **{{metric 1}}** — {{one-line definition; where it's measured}}
- **{{metric 2}}** — {{...}}
- **{{metric 3}}** — {{...}}
<!-- 3-5 total. -->

## Tracks

### {{Track 1 name}}

{{One line: the investment area, not a feature list.}}
_Why it serves the approach:_ {{one line}}
<!-- 2-4 tracks. -->

## Roadmap

_No milestones yet — run `/tunan:new-milestone` to plan the first._

## Not working on

- {{one line per item}}
<!-- Optional. Delete the section if unused. -->

## Marketing

**One-liner:** {{single-sentence pitch}}
<!-- Optional. Delete the section if unused. -->
~~~

## Update run (existing `tunan:project` issue)

Replace only the intent sections you revised, using the same shape above. Carry forward verbatim: the frontmatter (update `last_updated` to today; keep `current_milestone` / `codebase_map`), the entire `## Roadmap` section, unrevised optional sections, and any `<!-- tunan:project-revision -->` comments.

## Post-write checklist

Before confirming the write, scan the body for:

- [ ] Frontmatter present with `name` and a today-dated `last_updated` (and `current_milestone` preserved on an update).
- [ ] Intent sections in locked order; no section over 4 sentences except Tracks.
- [ ] No placeholders remain (`{{...}}`).
- [ ] Metric count 3-5; track count 2-4.
- [ ] Target problem and Our approach are connected - one clearly responds to the other.
- [ ] The `## Roadmap` section is present and (on an update) byte-for-byte the pre-edit roadmap.
