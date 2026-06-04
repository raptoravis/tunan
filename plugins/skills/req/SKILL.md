---
name: req
description: 'Short alias for the brainstorm skill — explore requirements and approaches through collaborative dialogue, then capture a right-sized requirement as a GitHub issue labeled yunxing:req. Use when the user types /yunxing:req, says "let''s brainstorm", "what should we build", or "help me think through X", presents a vague or ambitious feature request, or seems unsure about scope or direction. Accepts an existing req issue ref to resume and update.'
argument-hint: "[feature idea or problem to explore, or a req issue ref #N / URL]"
---

# req — alias for brainstorm

`req` is a thin alias for the **`brainstorm`** skill. It exists because the durable artifact this workflow produces is a `yunxing:req` GitHub issue, so users often reach for `/yunxing:req` as the entry point.

There is no separate behavior here. To run it, **load the `brainstorm` skill and execute its workflow exactly** — read `../brainstorm/SKILL.md` and follow it end to end, passing the arguments below through unchanged as the feature description / issue ref.

## Arguments

<feature_description> #$ARGUMENTS </feature_description>

`$ARGUMENTS` is forwarded verbatim to `brainstorm` (free-text feature description OR a `yunxing:req` issue ref — a `#<N>` token or full GitHub issue URL to resume). Do not pre-interpret it here; `brainstorm`'s Phase 0 owns the parsing, GH preflight, resume, scoping, and issue write.

If `$ARGUMENTS` is empty, `brainstorm` will ask what to explore — defer to it rather than asking separately.
