# Phase 2 Dispatch — Divergent Ideation Fleet

Loaded at the start of ideate Phase 2 (SKILL.md) — after Phase 1 grounding and any Phase 1.5 decomposition / evidence scouts complete, and before building any ideation dispatch prompt. It defines the ideation fleet, the cache-friendly dispatch payload, the frames, the per-idea output contract, and the generation rules. Model tier names (extraction / generation / ceiling) are defined in SKILL.md Model Tiers; `<scratch-dir>`, the axis list, and the grounding summary come from Phase 1 / 1.5.

## Fleet

**Fleet (tiered — see Model Tiers).** Dispatch parallel ideation sub-agents. Omit the `mode` parameter so the user's configured permission settings apply. The default fleet is **5 agents covering all six frames**:

- **3 generation-tier agents**, one per evidence-driven frame (Pain and friction; Inversion, removal, or automation; Leverage and compounding). These frames live on evidence — the dossiers do the heavy lifting, so the mid-tier model performs well here.
- **2 ceiling-tier agents** for the ceiling frames, where the strong model's reasoning is the product and must not be tiered down: one takes Cross-domain analogy; the other takes Assumption-breaking and reframing **plus** Constraint-flipping (cousins — both invert givens; one agent holds both as starting biases).

Fleet variants: **surprise-me** and **`go deep`** dispatch 6 agents, one frame each, all ceiling-tier. **Issue-tracker mode** dispatches 4 agents only when issue-tracker intent was detected in Phase 0.2 AND the issue intelligence agent returned usable themes (see override below — cluster-derived frames capped at 4, dispatched on the generation tier; padded frames keep their native tier). The insufficient-issue-signal fallback from Phase 1 uses the default 5-agent fleet. When the platform cannot select per-agent models, the degradation rule applies — dispatch all frames on the inherited model and keep the read budgets and dossier caps.

Each frame targets ~6-8 ideas (a two-frame agent targets that per frame), yielding ~36-48 raw ideas in the default path or ~24-32 across 4 frames in issue-tracker mode; roughly 25-30 survive dedupe in the default path and fewer in the 4-frame path. Adjust per-frame targets when volume overrides apply (e.g., "100 ideas" raises it, "top 3" may lower the survivor count instead).

## Dispatch Payload (cache-friendly, long-context ordered)

Build one shared grounding block and keep it byte-identical across every ideation dispatch this run — identical prefixes let platforms with prompt caching reuse the expensive part. Longform shared material goes first; the agent-specific task goes last:

- `<grounding>` — the consolidated grounding summary, including the evidence gists and the absolute paths of the dossier files under `<scratch-dir>` (identical bytes across agents). Instruct each agent to read the dossier files before generating — they are the evidence layer its `direct:` bases cite; the gists are orientation, not evidence. In elsewhere modes there are no repo dossiers; the grounding summary itself is the evidence layer.
- `<constraints>` — the user's prompt, the focus hint, and any _User-named references_: ideas that violate these are out regardless of basis
- `<background>` — everything else in the grounding (codebase context, additional context, learnings, external context): informative, not directive — it can supply an idea's basis, but it must not pull ideation toward whatever was loudest in the corpus when the user named a different focus
- `<axes>` — the Phase 1.5 axis list, when present
- `<task>` — the frame assignment, per-frame volume target, the ambition charter below, the verification-read budget, and the per-idea output contract; generate raw candidates only (critique comes later)

The `<constraints>`/`<background>` split is the primary defense against grounding noise shaping survivors against user intent — keep it mechanical via the tags. Each agent's first few ideas tend to be obvious — push past them.

**Ambition charter (include verbatim in every ideation dispatch):**

> This ideation exists so the user can choose a direction worth building — the output's value is decided by whether one idea changes what they do next. Generate the smartest, most inventive ideas your frame can reach: ideas a strong team would say "we have to do this" about. Your first few ideas will be the obvious ones — treat them as warm-up, and keep only the ones that still earn their place after the non-obvious ideas exist. If an idea would appear in a generic listicle about this topic, sharpen it with grounding evidence or drop it. Anchor every idea in specific entries from the grounding.

**Verification reads (repo mode).** After an agent makes its internal cut, it may spend up to 5 targeted reads (10 under `go deep`) following dossier `file:line` pointers to verify or deepen the bases of ideas it will submit. A `direct:` basis must quote a line the agent actually read — in a dossier or in the repo — never a guessed citation. Elsewhere modes verify against the user-supplied context instead of reading repo files.

**Axis spread instruction.** When an axis list is present, instruct each sub-agent to distribute its ideas across multiple axes — the frame's lens applies to every axis, but ideas should not all cluster on one. Each idea must be tagged with the axis it targets. The frame is a lens; the axis list is the surface map. A frame that plausibly reaches an axis should produce at least one idea there before doubling up on a different axis. When decomposition was skipped (atomic subject or surprise-me), omit the axis instruction entirely — do not invent axes at dispatch time.

**Constraint vs background.** In the dispatch prompt, mark the user's prompt, focus hint, and any _User-named references_ (root-level files the user named in their focus and the codebase-scan fully read) as _constraints_ — ideas that violate them are out regardless of basis. Mark the rest of the grounding summary (codebase context, additional context, learnings, external context) as _background_ — informative, not directive. Background can support an idea's basis and inform direction; it must not pull ideation toward whatever was loudest in the corpus when the user named a different focus. This is the primary defense against grounding noise (an unrelated `FEEDBACK.md` the user did not name, a tangentially-cited prior-art result) shaping survivors against user intent.

## Frames

Assign each sub-agent a different ideation frame as a **starting bias, not a constraint**. Prompt each to begin from its assigned perspective but follow any promising thread -- cross-cutting ideas that span multiple frames are valuable.

**Frame selection (mode-symmetric — same six frames in repo and elsewhere modes):**

1. **Pain and friction** — user, operator, or topic-level pain points; what is consistently slow, broken, or annoying.
2. **Inversion, removal, or automation** — invert a painful step, remove it entirely, or automate it away.
3. **Assumption-breaking and reframing** — what is being treated as fixed that is actually a choice; reframe one level up or sideways.
4. **Leverage and compounding** — choices that, once made, make many future moves cheaper or stronger; second-order effects.
5. **Cross-domain analogy** — generate ideas by asking how completely different fields solve a structurally analogous problem. The grounding domain is the user's topic; the analogy domain is anywhere else (other industries, biology, games, infrastructure, history). Push past the obvious analogy to non-obvious ones.
6. **Constraint-flipping** — invert the obvious constraint to its opposite or extreme. What if the budget were 10x or 0? What if the team were 100 people or 1? What if there were no users, or 1M? Use the resulting design as a candidate even if the constraint flip itself is not realistic.

**Issue-tracker mode override (repo mode only).** When issue-tracker intent is active and themes were returned by the issue intelligence agent: each high/medium-confidence theme becomes a frame. Pad with frames from the 6-frame default pool (in the order listed above) if fewer than 3 cluster-derived frames. Cap at 4 total — issue-tracker mode keeps its tighter dispatch by design.

## Per-Idea Output Contract (uniform across all frames, all modes)

Each sub-agent returns this structure per idea:

- **title**
- **summary** (2-4 sentences)
- **axis** — required when Phase 1.5 produced an axis list. Pick the one axis this idea most centrally targets; do not span. Omit entirely when decomposition was skipped.
- **basis** (required, tagged) — one of:
  - `direct:` quoted line / specific file / named issue / explicit user-supplied context
  - `external:` named prior art, domain research, adjacent pattern, with source
  - `reasoned:` explicit first-principles argument for why this move likely applies — not a gesture; the argument is written out
- **why_it_matters** — connects the basis to the move's significance
- **meeting_test** — one line confirming this would warrant team discussion (waived when Phase 0.5 detected tactical focus signals)

Basis is required, not optional. If a sub-agent cannot articulate a basis of at least one type, the idea does not surface. The failure mode to prevent is generic "AI-slop" ideas that sound plausible but lack a basis the user can verify.

**Generation rules (uniform across frames, all modes):**

- Every idea carries an articulated basis. Unjustified speculation does not surface, regardless of how plausible it sounds.
- Bias toward the basis type your frame naturally produces — pain/inversion/leverage tend toward `direct:`; analogy and constraint-flipping tend toward `reasoned:`; assumption-breaking is mixed — but don't exclude other basis types.
- Apply the meeting-test as a default floor: would this idea warrant team discussion? If not, it's below the floor and does not surface. The floor is relaxed only when Phase 0.5 detected tactical focus signals.
- Stay within the subject's identity. Product expansions, new surfaces, new markets, retirements, and architectural pivots are fair game when the basis supports them. Subject-replacement moves (abandoning the project, pivoting to unrelated domains, becoming a different organization) are out regardless of basis.
- **Honor the asked scope.** When the focus hint names a part of the subject (a flow, a stage, a section, a feature within a larger product — e.g., "account settings", "onboarding flow", "pricing page copy", "gameplay rules"), ideate at full ambition _within that scope_. Expanding the surface to the whole subject — proposing fundamental changes to the broader product when the user named one slice — is a scope mismatch even when no subject-replacement occurred. Big-picture thinking still applies; it just operates inside the bounded surface the user named, not by widening the surface.

**Surprise-me mode addendum.** When Phase 0.2 routed to surprise-me, include this additional instruction in each sub-agent's dispatch prompt:

> No user-specified subject. Through your frame's lens, explore the Phase 1 material and identify the subject(s) you find most interesting for this frame. Different frames finding different subjects is the feature — cross-subject divergence is what makes surprise-me valuable. Each idea still carries a basis; the basis may include identification of the subject itself (why _this_ subject is worth ideating on through your lens, citing what in the Phase 1 material signals it).
