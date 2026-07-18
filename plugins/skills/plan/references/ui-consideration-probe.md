# UI Consideration Probe — Plan-Phase Completeness Checklist

Loaded by `plan` when the requirements involve UI surfaces. A closed taxonomy of
project-independent UI state categories every UI feature must account for before
a plan dimension can be considered complete.

**Axis boundary.** This taxonomy covers only the finite, project-independent
content/robustness states. Open-ended UX concerns — real-time/offline modes, deep
accessibility (WCAG breadth), internationalization / RTL, gesture/voice/reduced-motion
interactions — are domain-dependent and explored through the normal plan dialogue,
not this closed checklist.

## Element Kinds

Classify each UI surface in the feature into one or more of these kinds:

| Kind | Examples |
|------|----------|
| `form` | Input fields, validation, submit flows, wizards |
| `list-collection` | Tables, feeds, cards, search results, grids |
| `nav` | Menus, tabs, breadcrumbs, sidebars, drawers |
| `media` | Images, video, audio, file previews, charts |
| `interactive-control` | Buttons, toggles, sliders, drag-and-drop, tooltips |
| `static-content` | Headings, paragraphs, labels, badges, empty-shell layouts |

When an element's kind is unclear from the requirements, propose a classification
and confirm with the user — never silently guess.

## Taxonomy (8 Categories)

For each UI surface in the feature, raise every category whose "applies to" column
intersects the surface's element kind(s). A static label is never asked about loading
or empty state — that is what makes an unresolved consideration meaningful.

| id | name | applies to | consideration |
|----|------|-----------|--------------|
| empty | Empty / no data | form, list-collection, media | What is shown when there is no data — zero items, an unfilled form, or absent media? |
| loading | Loading / in-flight | form, list-collection, media, nav | What is shown while data or content is still loading (skeleton, spinner, progressive reveal)? |
| error | Error / failure | form, list-collection, media, nav | What is shown when the load or submit fails (message, retry affordance, partial fallback)? |
| populated | Populated / happy path | list-collection, media | What does the normal populated (happy-path) state look like at a typical volume of content? |
| partial | Partial / incomplete | form, list-collection | What is shown for partial or incomplete data — some fields or rows present, others missing? |
| overflow | Overflow / truncation | list-collection, nav, static-content | What happens when content exceeds its container — scroll, clip, wrap, or truncate? |
| zero-one-many | Zero / one / many | list-collection | How does the layout read at zero, one, and many items (singular vs plural copy, spacing)? |
| long-text | Long text | form, static-content, interactive-control, nav | What happens with unusually long text — truncation, wrapping, ellipsis, or reflow? |

## Relevance Filter

1. Classify each UI surface's element kind(s) from the requirements.
2. Raise only the categories whose "applies to" column intersects the surface's kind(s).
3. Each raised consideration must be resolved — either with an explicit answer in the
   plan or a reasoned dismissal ("not applicable because X").
4. Silence is not a resolution. An unresolved consideration is a plan gap, not a
   passed check.

## Resolution

For each raised consideration, record one of:

- **Resolved** — the plan explicitly addresses this state (wireframe, behavior description,
  or acceptance criterion).
- **Dismissed** — not applicable to this surface, with a one-line reason.
- **Deferred** — acknowledged but intentionally left for a later milestone.

Surface unresolved considerations in the plan's assumptions section; never silently
drop them.

## When to Load

Load this reference during plan Phase 2 (Explore Approaches) or Phase 3 (Implementation
Plan) when the feature description or requirements mention UI surfaces — forms, pages,
components, views, modals, dashboards, or any visual interface element. Skip for
pure-backend, CLI, API-only, or data-pipeline features.
