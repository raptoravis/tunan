# Markdown Rendering

This reference describes how the requirement renders as the markdown
**body of a `tunan:req` GitHub issue**. The durable artifact is the issue,
not a local file — there is no `.md`/`.html` file on disk and no exclusive
output mode anymore.

It is paired with a section contract (`brainstorm-sections.md`) that
describes *what* the requirement contains. This reference describes *how*
markdown specifically presents those sections inside the issue body.

## Hard invariants

These hold for every `tunan:req` issue body.

- **Metadata as a fenced `yaml` block at the top of the body.** GitHub issues
  have no frontmatter delimiters, so the stable metadata (e.g. `date`,
  `topic`) renders as a fenced ```` ```yaml ```` block at the very top of the
  issue body rather than a `---`-delimited frontmatter. Exact fields are
  defined in `brainstorm-sections.md`. The block is editable in place;
  agents that update the issue overwrite the body via
  `gh issue edit <N> --body-file <tmpfile>`.
- **ASCII identifiers in anchors.** Markdown headings auto-generate anchors
  from the heading text. Keep headings ASCII so anchors are predictable
  (`#implementation-units`, not `#implementación-units`).
- **Repo-relative paths for file references.** Always. Never absolute paths
  — they break portability across machines, worktrees, teammates.
- **No raw HTML layout.** Keep the body markdown. No `<div>`, no inline
  `<style>`. GitHub renders a constrained markdown subset; `<details>` is
  the one HTML element GitHub supports and is acceptable for collapsible
  sections, but avoid raw layout HTML — it does not render in issue views.

## Format principles

These shape what "good" markdown looks like; the agent applies them per
artifact based on content shape.

### ID prefix format

Stable IDs (R, U, A, F, AE, KTD) appear as plain prefixes at the start of
the bullet or heading — do NOT bold the prefix. The prefix is visually
distinctive on its own; bolding it inflates visual noise.

```markdown
- R1. The plan returns paginated sessions.   ← right
- **R1.** The plan returns paginated sessions.   ← wrong (bolded prefix)
```

Same applies to unit headings: `### U1. Cloak detection in preflight contract`.

### Content shape: prose vs bullets vs tables

The same content can be rendered three ways; the agent picks per content
shape, not by template default.

- **Prose** when the content has narrative flow (motivation, decision
  rationale, problem framing). Bullets fragment narrative into
  disconnected pieces.
- **Bullets** when items share a parallel shape but each carries enough
  prose to not fit a table cell.
- **Tables** when 5+ items share uniform structure (`ID + body`,
  `name + value`, `decision + rationale`, `risk + mitigation`). Tables
  scan faster at that scale and unlock additional columns (status,
  traceability, severity) that bullets can't accommodate cleanly.

The test: which shape would a reader scan fastest for this content? If
items have parallel structure and 5+ instances, table. If items are 3-5
and each has a few lines of prose, bullets. If the content is a single
narrative thought, prose.

### Bold leader labels within bullets

When a bullet has substructure that benefits from named fields (Key Flows
with Trigger / Actors / Steps / Outcome, Acceptance Examples with Covers
/ Given / When / Then), use bold leader labels at the start of nested
bullets — not deeper heading levels.

```markdown
- F1. Anonymous capture
  - **Trigger:** Agent enters Step 2a with no session.
  - **Actors:** A1, A2
  - **Steps:** Preflight detects cloak; agent launches; capture proceeds.
  - **Covered by:** R1, R2, R5
```

This gives the bullet structure without needing H4/H5 headings that would
clutter the doc and break TOC generation.

### Section separators

For substantial artifacts, use horizontal rules (`---`) between top-level
H2 sections. Omit for short docs where separators would dominate.

### Tables for genuinely comparative info only

Use tables for the uniform-shape case in "Content shape" above. Don't use
tables to render content lists that are really bullets — markdown tables
are noisier in raw form and worse for diffs.

## Section anatomy

How section types commonly render in markdown. These are patterns, not
contracts — the agent picks the shape that fits the content.

- **Summary / Problem Frame** — prose paragraphs.
- **Requirements** — bullets with `R<N>.` prefix. When requirements span
  more than one concern, grouping under bold inline headers is the default
  shape, not optional polish (group by capability, not by discussion order);
  render a flat list only when every requirement is about the same thing.
  When requirements have status, traceability, or severity that warrant
  additional columns, escalate to a table.
- **Implementation Units** — H3 heading per unit with `U<N>.` prefix.
  Fields (Goal, Files, Patterns, Test Scenarios, Verification) render as
  bullets with bold leader labels, or as sub-headings if the field has
  multi-paragraph content.
- **Key Technical Decisions** — bullets with bold decision name + prose
  rationale, or numbered KTD-N pattern when traceability matters.
- **Key Flows / Acceptance Examples** — bullets with bold leader labels
  (Trigger / Actors / Steps / Outcome / Covers / Given-When-Then).
- **Scope Boundaries** — bullets, optionally split into "Deferred for
  later" / "Outside this product's identity" sub-headings when the
  positioning distinction matters.

The agent picks more elaborate or simpler shapes based on what each
specific artifact's content needs.

## Diagrams

When the section contract calls for a diagram (architecture, sequence,
flowchart, state machine, swim lane, data-flow), markdown renders it as
a fenced mermaid block:

```markdown
` ``mermaid
flowchart TB
  A[Start] --> B{Decision}
  B -->|yes| C[Action]
  B -->|no| D[Other action]
` ``
```

(`TB` direction default — keeps diagrams narrow in source view and in
narrow rendered viewports.)

**Keep mermaid label/message text free of mermaid syntax characters.**
The most common break is a semicolon `;` inside `sequenceDiagram` message
text (the part after the `:`) or any node label — mermaid treats `;` as a
statement separator, so everything after it parses as a new statement and
the whole diagram fails to render (`Expecting '->>' … got 'NEWLINE'`).
Never put `;` in label text: use a comma, `/`, or `—`, or split one
message into two (`A->>B: approve → insert` / `A->>B: reject → mark
rejected`). The same care applies to other reserved punctuation in node
labels (`[]`, `{}`, `|`, `#`) — when a label must contain them, wrap the
label in double quotes (`A["text (with) chars"]`). Parentheses, `/`, and
CJK text in `sequenceDiagram` message text render fine and need no
escaping.

GitHub renders fenced `mermaid` blocks natively in issue bodies. For
quantitative comparisons (bar charts, scatter plots) markdown has no
native equivalent — use a table with the data and let prose or caption
carry the interpretation.

## Inline code and code blocks

- **Inline code** for identifiers (variable names, function names,
  flag names, file paths, IDs that aren't section anchors).
- **Fenced code blocks** with language tag for code, shell commands,
  API request/response samples. Always specify the language for syntax
  highlighting and accessibility.

```markdown
The flag `--cdp-url` accepts a URL.

` ``bash
browser-use --cdp-url http://localhost:9222
` ``
```

## No process exhaust

Engineering process metadata stays out of the artifact:

- No "captured at Phase X" notes
- No `## Next Steps` pointing to the next skill
- No italic provenance lines ("*Brainstorm completed 2026-05-13*")
- No engineering-flow shepherding ("Now read this file:", "Next, run that
  command:")

This information belongs in commit messages, tool output, and agent
transcripts — not in the artifact a reader returns to weeks later.

## Metadata block shape

The metadata fields are defined in `brainstorm-sections.md` (`date`,
`topic`). Common rules:

- Render as a fenced ```` ```yaml ```` block at the very top of the issue
  body — GitHub issues have no `---` frontmatter delimiters.
- Field names in lowercase snake_case (`created_at`, not `CreatedAt`).
- Brainstorm requirements have no `status` lifecycle — they are upstream of
  plans and referenced from a plan by the req issue `#<N>`. Do not introduce
  a `status` field. (Issue open/closed state is GitHub's own lifecycle, not
  a body field.)
- Stable across revisions — never rename or repurpose a field.
- When rewriting a body that `new-req` created, **merge** its `kind` / `priority`
  fields into this block alongside `date` / `topic` — do not drop them by
  replacing the whole block (see `brainstorm-sections.md` "Preserve
  `new-req`-authored sections").

## Post-write audit

Before declaring the issue body written (or updated), scan it for these
common slips:

- All stable IDs are plain-prefix format, not bolded.
- No raw HTML layout elements.
- All file paths are repo-relative.
- Horizontal rule separators between H2s (for Standard / Deep requirements).
- No process exhaust (Phase X notes, Next Steps pointers, provenance
  lines).
- Tables only where 5+ uniform-shape items justify them.
- The leading ```` ```yaml ```` block has the required fields (`date`,
  `topic`) with reasonable values.
- When rewriting a `new-req` body, the sponsor's `## Background / original
  words` section, the `## Assets to upload` section (with its checklist and any
  `<!-- TODO: drag in ... -->` comments), and the `kind` / `priority` metadata
  fields all survived the rewrite — none were clobbered.
