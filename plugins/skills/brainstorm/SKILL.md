---
name: brainstorm
description: 'Explore requirements and approaches through collaborative dialogue, then capture a right-sized requirement as a GitHub issue labeled tunan:req. Use when the user says "let''s brainstorm", "what should we build", or "help me think through X", presents a vague or ambitious feature request, or seems unsure about scope or direction -- even without explicitly asking to brainstorm. Accepts an existing tunan:raw capture or tunan:req issue ref to resume and update (a tunan:raw capture is promoted to tunan:req).'
argument-hint: "[feature idea or problem to explore, or a tunan:raw / tunan:req issue ref #N / URL] [--search]"
---

# Brainstorm a Feature or Improvement

**Note: The current year is 2026.** Use this when dating the requirement issue body.

Brainstorming helps answer **WHAT** to build through collaborative dialogue. It precedes `/tunan:plan`, which answers **HOW** to build it.

The durable output of this workflow is a **`tunan:req` GitHub issue** — a single issue whose markdown body holds the finished requirement. In other workflows this might be called a lightweight PRD or feature brief. In compound engineering, keep the workflow name `brainstorm`, but make the written artifact strong enough that planning does not need to invent product behavior, scope boundaries, or success criteria. Requirements live in GitHub issues, never in local files.

`new-raw` creates standalone `tunan:raw` issues — raw, pre-brainstorm captures. When this skill is invoked with such an issue (or a `tunan:req` issue from any earlier `brainstorm` run), it **updates that same issue** rather than creating a duplicate, and promotes a `tunan:raw` capture to `tunan:req` once the normalized requirement is written.

This skill does not implement code. It explores, clarifies, and documents decisions for later planning or execution.

**IMPORTANT: All file references inside the issue body must use repo-relative paths (e.g., `src/models/user.rb`), never absolute paths. Absolute paths break portability across machines, worktrees, and teammates.**

## Core Principles

1. **Assess scope first** - Match the amount of ceremony to the size and ambiguity of the work.
2. **Be a thinking partner** - Suggest alternatives, challenge assumptions, and explore what-ifs instead of only extracting requirements.
3. **Resolve product decisions here** - User-facing behavior, scope boundaries, and success criteria belong in this workflow. Detailed implementation belongs in planning.
4. **Keep implementation out of the requirements doc by default** - Do not include libraries, schemas, endpoints, file layouts, or code-level design unless the brainstorm itself is inherently about a technical or architectural change.
5. **Right-size the artifact** - Simple work gets a compact requirements document or brief alignment. Larger work gets a fuller document. Do not add ceremony that does not help planning.
6. **Apply YAGNI to carrying cost, not coding effort** - Prefer the simplest approach that delivers meaningful value. Avoid speculative complexity and hypothetical future-proofing, but low-cost polish or delight is worth including when its ongoing cost is small and easy to maintain.

## Interaction Rules

These rules apply to every brainstorm, including the universal (non-software) flow routed to `references/universal-brainstorming.md`.

1. **Ask one question at a time** - One question per turn, even when sub-questions feel related. Stacking several questions in a single message produces diluted answers; pick the single most useful one and ask it.
2. **Prefer single-select multiple choice** - Use single-select when choosing one direction, one priority, or one next step.
3. **Use multi-select rarely and intentionally** - Use it only for compatible sets such as goals, constraints, non-goals, or success criteria that can all coexist. If prioritization matters, follow up by asking which selected item is primary.
4. **Default to the platform's blocking question tool** - Use `AskUserQuestion` in Claude Code (call `ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded), `request_user_input` in Codex, `ask_user` in Gemini, `ask_user` in Pi (requires the `pi-ask-user` extension). These tools include a free-text fallback (e.g., "Other" in Claude Code), so options scaffold the answer without confining it — well-chosen options surface dimensions the user may not have separated, and pick-plus-optional-note is lower activation energy than composing prose from scratch. This default holds for opening and elicitation questions too, not only narrowing. Fall back to numbered options in chat only when no blocking tool exists in the harness or the call errors (e.g., Codex edit modes) — not because a schema load is required. Never silently skip the question.

   **Hard rule — if it's enumerable, it goes through the tool.** Whenever the agent can write 2–4 distinct, plausible options for a question — any direction choice, priority, scope/mechanism confirmation, yes/no with named consequences, or next-step — it MUST fire the blocking tool, even when the question carries setup prose. Put the framing in the question stem and the choices in the tool; do not emit an options-bearing question as plain chat text. Asking "is it A, or B?" (or "..., or X?") in prose when A/B/X are nameable options is the single most common regression in this skill and counts as silently skipping the tool. "It needs a `ToolSearch` load first," "there was explanatory context to convey," and "it felt conversational" are all non-reasons — load the tool and ask. The ONLY exemption is Rule 5: rigor probes and genuinely diagnostic/narrative questions stay open-ended even when options could be written. When unsure whether a question is enumerable or open, default to the tool.

**Alignment protocol.** When asking the sponsor to choose between options, follow the align protocol: offer at least 3 ranked options with the single best one pre-selected as the default — place it first and append `(Recommended)` to its label — so the sponsor lands on the optimal choice by accepting the default. Load the `align` skill for the full protocol. Never hand an open-ended choice back to the sponsor.

5. **Use an open-ended question only when the question is genuinely open** - Drop the blocking tool only when (a) the answer is inherently narrative ("walk me through how you got here"), (b) the question is diagnostic or introspective and presented options would unintentionally influence the user's answer (e.g., "what concerns you most?" — a 4-option menu would nudge them toward those axes rather than the ones actually on their mind), or (c) you cannot write 3-4 genuinely distinct, plausibly-correct options that cover the space without padding or strawmen. The test: if you'd be straining to fill the option slots, the question is open — ask it open-ended. Rule 1 still applies: still one question per turn.
6. **Open-ended questions earn their place only when they're specific enough to elicit a substantive answer** - Apply Rule 5 silently: just ask the question, do not narrate the form choice. The question itself must give the user something concrete to anchor on. Good: _"What's the most concrete thing someone's already done about this — paid for it, built a workaround, quit a tool over it?"_ (this is one of Phase 1.2's rigor probes — it earns its open-endedness by naming what counts as an answer). Too thin: _"What's your take?"_ (nothing to bite into; user defaults to a one-liner that wastes the open question). Avoid (a) narrating the form choice ("the most useful question I can ask here is..."), (b) framings that imply a short answer ("briefly", "in one sentence"), (c) yes/no traps, and (d) AI-slop warmth wrappers ("take it wherever feels relevant").

## Output Guidance

- **Keep outputs concise** - Prefer short sections, brief bullets, and only enough detail to support the next decision.
- **Use repo-relative paths** - When referencing files in the issue body, use paths relative to the repo root (e.g., `src/models/user.rb`), never absolute paths. Absolute paths make the requirement non-portable across machines and teammates.

## Feature Description

<feature_description> #$ARGUMENTS </feature_description>

`$ARGUMENTS` may be either a free-text feature description OR a reference to an existing `tunan:req` issue (a `#<N>` token or a full GitHub issue URL). When it is an issue ref, Phase 0.0 binds that issue and reads its body as the feature description / resume source; otherwise the text is the feature description.

**If the feature description above is empty (no text and no issue ref), ask the user:** "What would you like to explore? Please describe the feature, problem, or improvement you're thinking about, or pass an existing `tunan:req` issue (`#<N>` or its URL) to continue."

Do not proceed until you have a feature description or a bound issue.

## Execution Flow

### Phase 0: Resume, Assess, and Route

#### 0.0 Resolve the Requirement Issue

The durable requirement is a **`tunan:req` GitHub issue** (markdown body), never a local file. Run the GH preflight, then resolve whether this run binds an existing issue or will create one at Phase 3.

**GH preflight — run before any issue read/write. Abort with the guidance shown if any check fails; NEVER fall back to a local file.**

1. `gh` installed. If not: tell the user to install it from `https://cli.github.com` or run `/tunan:setup`.

```bash
gh --version
```

2. `gh auth status` exits 0. If not: tell the user to run `gh auth login` (in Claude Code they can type `! gh auth login` so the output lands in the session), then re-run.

```bash
gh auth status
```

3. The repo resolves. If not: a GitHub repository is required — abort and explain.

```bash
gh repo view --json nameWithOwner
```

4. **Setup reminder (non-blocking).** If the repo has no `tunan:config` issue, this repo hasn't been through tunan setup — tell the user once, "This repo isn't set up for tunan yet; run `/tunan:setup` to configure it," then continue. A missing config is non-blocking and never aborts the run.

**Ensure the `tunan:req` label exists** (needed when Phase 3 creates the issue):

```bash
gh label list --search "tunan:req"
```

If it is absent, create it:

```bash
gh label create "tunan:req" --color 1f883d --description "tunan requirements"
```

**Resolve the issue binding:**

- **`$ARGUMENTS` contains an issue ref** (a `#<N>` token or a full GitHub issue URL): bind that issue as `REQ_ISSUE`. Read its body and use it as the feature description / resume source (Phase 0.1). This is the path taken when `brainstorm` is invoked on a `tunan:raw` issue produced by `new-raw` (or an earlier `tunan:req` issue) — the same issue is updated in place at Phase 3, not duplicated, and a `tunan:raw` issue is promoted to `tunan:req` there.

```bash
gh issue view <N> --json title,body,url,labels
```

- **No issue ref**: leave `REQ_ISSUE` unbound for now. Before Phase 3 creates a new issue, check for an existing matching open req issue to update instead of duplicating (Phase 0.1 / Phase 3).

The requirement body is markdown-in-issue only — there is no local-file or HTML output mode and no `output:` argument. The section content is defined by `references/brainstorm-sections.md`; `references/markdown-rendering.md` describes how those sections render as the issue body markdown.

**Token-parsing convention:** an issue ref (`#<N>` or issue URL) is consumed as the binding and not treated as part of the feature description. Other `<word>:<word>` tokens — including conventional commit prefixes like `feat:`, `fix:`, `chore:` that may appear inside a feature description — pass through verbatim as description text.

The handoff to `plan` passes the req issue ref (`#<N>` or URL), not a file path — see `references/handoff.md`.

**Current-state grounding (optional, technical brainstorms only).** When the brainstorm is inherently about a technical or architectural change (Principle 4), a `tunan:codebase-map` issue — if one exists — is useful grounding for feasibility and for the concerns already present in the repo. Resolve and read it: `gh issue list --label "tunan:codebase-map" --state open --json number --jq '.[0].number // empty'`, then `gh issue view <N> --json body --jq .body` (read its ARCHITECTURE/CONCERNS). Use it to inform what is realistic to build; do not pull implementation detail into the requirement body. For non-technical/product brainstorms, skip it. Absent → skip silently, never block.

#### 0.1 Resume Existing Work When Appropriate

Resume from an existing `tunan:raw` or `tunan:req` issue — never from a local file.

- **A `REQ_ISSUE` was bound in Phase 0.0** (issue ref passed): its body is already the resume source. Read it (`gh issue view <N> --json title,body,url,labels`), summarize the current state briefly, and continue from its existing decisions and outstanding questions. If the issue was created by `new-raw` (label `tunan:raw`) and holds only the captured requirement (no finished brainstorm sections yet), treat its body as the feature description and proceed through the dialogue phases normally. Phase 3 then **merges** the finished requirement into the body — it preserves the `new-raw`-authored capture (the sponsor's verbatim original words and the asset placeholders), it does not clobber them, and it promotes the label `tunan:raw → tunan:req`.
- **No `REQ_ISSUE`, but the user references an existing brainstorm topic:** locate a candidate issue by topic before starting fresh — search both the raw captures and the normalized requirements:

```bash
gh issue list --label "tunan:raw" --search "<terms>" --json number,title,url,labels
gh issue list --label "tunan:req" --search "<terms>" --json number,title,url,labels
```

  Confirm with the user before resuming: "Found an existing #<N> for [topic]. Should I continue from this, or start a new one?" If resuming, bind it as `REQ_ISSUE`, read its body, and update that issue at Phase 3 instead of creating a duplicate (promoting its label to `tunan:req` if it is still `tunan:raw`).
- **Nothing matches:** continue fresh; Phase 3 creates a new issue.

#### 0.1b Classify Task Domain

Before proceeding to Phase 0.2, classify whether this is a software task. The key question is: **does the task involve building, modifying, or architecting software?** -- not whether the task _mentions_ software topics.

**Software** (continue to Phase 0.2) -- the task references code, repositories, APIs, databases, or asks to build/modify/debug/deploy software.

**Non-software brainstorming** (route to universal brainstorming) -- BOTH conditions must be true:

- None of the software signals above are present
- The task describes something the user wants to explore, decide, or think through in a non-software domain

**Neither** (respond directly, skip all brainstorming phases) -- the input is a quick-help request, error message, factual question, or single-step task that doesn't need a brainstorm.

**If non-software brainstorming is detected:** Read `references/universal-brainstorming.md` and use those facilitation principles. Skip Phases 0.2–4 below — the **Core Principles and Interaction Rules above still apply unchanged**, including one-question-per-turn and the default to the platform's blocking question tool.

#### 0.2 Assess Whether Brainstorming Is Needed

**Clear requirements indicators:**

- Specific acceptance criteria provided
- Referenced existing patterns to follow
- Described exact expected behavior
- Constrained, well-defined scope

**If requirements are already clear:**
Keep the interaction brief. Confirm understanding and present concise next-step options rather than forcing a long brainstorm. Only write a short requirements document when a durable handoff to planning or later review would be valuable. Skip Phase 1.1 and 1.2 entirely — go straight to Phase 1.3 or Phase 2.5 in announce-mode (synthesis emitted for visibility, no blocking confirmation), then to Phase 3.

#### 0.3 Assess Scope

Use the feature description plus a light repo scan to classify the work:

- **Lightweight** - small, well-bounded, low ambiguity
- **Standard** - normal feature or bounded refactor with some decisions to make
- **Deep** - cross-cutting, strategic, or highly ambiguous

If the scope is unclear, ask one targeted question to disambiguate and then proceed.

**Deep sub-mode: feature vs product.** For Deep scope, also classify whether the brainstorm must establish product shape or inherit it:

- **Deep — feature** (default): existing product shape anchors decisions. Primary actors, core outcome, positioning, and primary flows are already established in the product or repo. The brainstorm extends or refines within that shape.
- **Deep — product**: the brainstorm must establish product shape rather than inherit it. Primary actors, core outcome, positioning against adjacent products, or primary end-to-end flows are materially unresolved. Existing code lowers the odds of product-tier but does not by itself rule it out — a half-built tool with ambiguous shape is still product-tier.

Product-tier triggers additional Phase 1.2 questions and additional sections in the requirements document. Feature-tier uses the current Deep behavior unchanged.

**Visual probe tripwire.** If the feature is inherently visual or spatial — drawing/canvas tools, annotation behavior, visual editors, UI layout or navigation, interaction states, charts, diagrams, animation, maps, timelines, or spatial flows — read `references/visual-probes.md` now and remember that a visual-probe gate is pending. Strong signals include freehand vs constrained drawing behavior, canvas annotation tools, layout comparisons, and state/flow placement. Loading the reference here is readiness only; do not offer the visual path until the first concrete shape/behavior decision. If the user later chooses visual, run the helper at `scripts/visual-probe-server.js` by resolving it relative to this loaded `brainstorm` skill directory; if the runtime does not expose a concrete skill directory, do not guess from the project CWD — use the text path.

### Phase 1: Understand the Idea

#### 1.1 Existing Context Scan

Scan the repo before substantive brainstorming. Match depth to scope:

**Lightweight** — Search for the topic, check if something similar already exists, and move on.

**Standard and Deep** — Two passes:

_Constraint Check_ — Check project instruction files (`AGENTS.md`, and `CLAUDE.md` only if retained as compatibility context) for workflow, product, or scope constraints that affect the brainstorm. Also read the `tunan:project` issue if it exists (`gh issue list --label "tunan:project" --state open --json number --jq '.[0].number // empty'`, then `gh issue view <N> --json body --jq .body`) — the project's target problem, approach, persona, active tracks, and current milestone are direct input to what this brainstorm should deliver and should shape scope, success criteria, and which approaches are aligned vs out-of-scope. Also read `CONCEPTS.md` at repo root if it exists — the project's authoritative vocabulary. Use these names in dialogue, approaches, and the requirements doc; map user-offered synonyms back. If any of these add nothing, move on.

_Topic Scan_ — Search for relevant terms. Read the most relevant existing artifact if one exists (brainstorm, plan, spec, skill, feature doc). Skim adjacent examples covering similar behavior.

If nothing obvious appears after a short scan, say so and continue. Two rules govern technical depth during the scan:

1. **Verify before claiming** — When the brainstorm touches checkable infrastructure (database tables, routes, config files, dependencies, model definitions), read the relevant source files to confirm what actually exists. Any claim that something is absent — a missing table, an endpoint that doesn't exist, a dependency not in the Gemfile, a config option with no current support — must be verified against the codebase first; if not verified, label it as an unverified assumption. This applies to every brainstorm regardless of topic.

2. **Defer design decisions to planning** — Implementation details like schemas, migration strategies, endpoint structure, or deployment topology belong in planning, not here — unless the brainstorm is itself about a technical or architectural decision, in which case those details are the subject of the brainstorm and should be explored.

**Web search** (opt-in via `--search`; default is **no-search**) — brainstorm stays intentionally shallow and does **not** go to the web by default; its job is to clarify WHAT, leaving landscape and prior-art depth to `plan`. Route by condition:

- **`--search` passed (or the prompt explicitly points outside the repo — competitor/prior-art scan, "from the web", "what should we borrow", a named external tool)**: Dispatch `tunan:web-researcher` with a focus hint plus a brief summary of the brainstorm topic, in parallel with the rest of Phase 1.1. Do not pass codebase content — it operates externally. Fold findings into constraint awareness and the Phase 2 approaches; keep them at landscape/product-shape granularity, not implementation detail. If web tools are unavailable or the researcher fails, warn and proceed without blocking.
- **No `--search` and no explicit external signal**: Skip web research entirely (default). When the topic plausibly has relevant prior art, note once: "Run with `--search` if you want me to scan the web for prior art and alternatives."

**Slack context** (opt-in, Standard and Deep only) — never auto-dispatch. Route by condition:

- **Tools available + user asked**: Dispatch `tunan:slack-researcher` with a brief summary of the brainstorm topic alongside Phase 1.1 work. Incorporate findings into constraint and context awareness.
- **Tools available + user didn't ask**: Note in output: "Slack tools detected. Ask me to search Slack for organizational context at any point, or include it in your next prompt."
- **No tools + user asked**: Note in output: "Slack context was requested but no Slack tools are available. Install and authenticate the Slack plugin to enable organizational context search."

#### 1.2 Product Pressure Test

Before generating approaches, scan the user's opening for rigor gaps. Match depth to scope.

This is agent-internal analysis, not a user-facing checklist. Read the opening, note which gaps actually exist, and raise only those as questions during Phase 1.3 — folded into the normal flow of dialogue, not fired as a pre-flight gauntlet. A fuzzy opening may earn three or four probes; a concrete, well-framed one may earn zero because no scope-appropriate gaps were found.

**Lightweight:**

- Is this solving the real user problem?
- Are we duplicating something that already covers this?
- Is there a clearly better framing with near-zero extra cost?

**Standard — scan for these gaps:**

- **Evidence gap.** The opening asserts want or need, but doesn't point to anything the would-be user has already done — time spent, money paid, workarounds built — that would make the want observable. When present, ask for the most concrete thing someone has already done about this.

- **Specificity gap.** The opening describes the beneficiary at a level of abstraction where the agent couldn't design without silently inventing who they are and what changes for them. When present, ask the user to name a specific person or narrow segment, and what changes for that person when this ships.

- **Counterfactual gap.** The opening doesn't make visible what users do today when this problem arises, nor what changes if nothing ships. When present, ask what the current workaround is, even if it's messy — and what it costs them.

- **Attachment gap.** The opening treats a particular solution shape as the thing being built, rather than the value that shape is supposed to deliver, and hasn't been examined against smaller forms that might deliver the same value. When present, ask what the smallest version that still delivers real value would look like.

Plus these synthesis questions — not gap lenses, product-judgment the agent weighs in its own reasoning:

- Is there a nearby framing that creates more user value without more carrying cost? If so, what complexity does it add?
- Given the current project state, user goal, and constraints, what is the single highest-leverage move right now: the request as framed, a reframing, one adjacent addition, a simplification, or doing nothing?

Favor moves that compound value, reduce future carrying cost, or make the product meaningfully more useful or compelling. Use the result to sharpen the conversation, not to bulldoze the user's intent.

**Deep** — Standard lenses and synthesis questions plus:

- Is this a local patch, or does it move the broader system toward where it wants to be?

**Deep — product** — Deep plus:

- **Durability gap.** The opening's value proposition rests on a current state of the world that may shift in predictable ways within the horizon the user cares about. When present, ask how the idea fares under the most plausible near-term shifts — and push past rising-tide answers every competitor could make.

- What adjacent product could we accidentally build instead, and why is that the wrong one?
- What would have to be true in the world for this to fail?

These questions force an explicit product thesis and feed the Scope Boundaries subsections ("Deferred for later" and "Outside this product's identity") and Dependencies / Assumptions in the requirements document.

#### 1.3 Collaborative Dialogue

Follow the Interaction Rules above. **This is where most questions fire, so the enumerable-means-tool hard rule (Interaction Rule 4) is load-bearing here: every direction, priority, scope/mechanism-confirmation, or yes/no-with-consequences question gets asked through `AskUserQuestion` (load it via `ToolSearch select:AskUserQuestion` first if needed) — never as a prose "is it A or B?". Only rigor probes (Phase 1.2 gap lenses) and genuinely diagnostic/narrative questions stay open-ended (Interaction Rule 5). When in doubt, fire the tool.**

**Visual-probe gate — check this as a precondition, do not rely on remembering it.** If the Phase 0.3 tripwire fired (inherently-visual topic), then before you raise the **first** decision about shape, behavior, state, layout, flow, or a diagram — in any form, plain chat or a blocking tool — that decision must first go through the text-vs-visual offer from `references/visual-probes.md`. The condition is state-based: offer unless this specific decision has already been through the offer (the user already chose text or visual for it). Anchor the check to the decision you are about to raise, not to a "pending gate" held in memory since Phase 0.3.

This gate **takes precedence over the default blocking-question path** (Interaction Rule 4) for that decision: do not raise the shape decision as an `AskUserQuestion`/`request_user_input` menu — or as a plain-chat shape question — until the user has declined visual (or visual feedback has returned to chat). **Putting an ASCII preview or text mockup inside the question's choices does NOT satisfy the offer — that is the exact shortcut this gate exists to stop.** The offer is its own prior question with two options: sketch rough options in a local browser, or describe them in chat. Use the platform's blocking question tool for this text-vs-visual offer when available. Once the user chooses text, continue in chat and do not re-offer for that decision. If they choose visual, build the cheapest display-only probe per `references/visual-probes.md`, then gather bounded feedback with the blocking question tool; the browser artifact stays display-only.

**Guidelines:**

- Ask what the user is already thinking before offering your own ideas. This surfaces hidden context and prevents fixation on AI-generated framings.
- Start broad (problem, users, value) then narrow (constraints, exclusions, edge cases)
- **Rigor probes fire before Phase 2 and are open-ended, not menus.** Narrowing is legitimate, but Phase 1 cannot end with un-probed rigor gaps. Each scope-appropriate gap from Phase 1.2 fires as a **separate** direct open-ended probe — one probe satisfies one gap, not multiple. Standard brainstorms scan four gap lenses (evidence, specificity, counterfactual, attachment); Deep-product adds durability (five total), but only the gaps actually present in the opening must be probed. Surface those probes progressively across the conversation — interleaving with narrowing moves is fine, as long as every scope-appropriate gap that was found in Phase 1.2 has been probed open-ended before Phase 2. Rigor probes map to Interaction Rule 5(b): a 4-option menu signals which kinds of evidence count and lets the user pick rather than produce. Open-ended questions force them to produce real observation or surface their uncertainty. Examples (one per gap): _evidence — "What's the most concrete thing someone's already done about this — paid, built a workaround, quit a tool over it?"_ / _specificity — "Can you name a team you've actually watched hit this, or are you reasoning?"_ / _counterfactual — "What do teams do today when this breaks — who reconciles?"_ / _attachment — "Before we move to shapes or approaches — what's the smallest version that would still prove the bet right, and what's excluded?"_ — **attachment is the final rigor probe before Phase 2 when the attachment gap is present. Fire it regardless of whether a specific shape has emerged through narrowing; its job is to pressure-test the user's implicit framing of the product before Phase 2 inherits it** / _durability — "Under the most plausible near-term shifts, how does this bet hold?"_ If the answer reveals genuine uncertainty, record it as an explicit assumption in the requirements document rather than skipping the probe.
- Clarify the problem frame, validate assumptions, and ask about success criteria
- Make requirements concrete enough that planning will not need to invent behavior
- Surface dependencies or prerequisites only when they materially affect scope
- Resolve product decisions here; leave technical implementation choices for planning
- Bring ideas, alternatives, and challenges instead of only interviewing
- **Visual-probe gate.** Governed by the bold gate checkpoint at the top of this phase — the offer fires before the first shape/behavior/state/layout/flow/diagram question, and an ASCII or text mockup inside a blocking question never satisfies it.

**Before exiting Phase 1.3: integration check.** Mentally combine what the user has said so far and surface any non-obvious consequences the dialogue hasn't probed. If user-stated X plus user-stated Y plus your-default-Z produces a downstream effect the user is unlikely to have tracked through one-question-at-a-time dialogue ("if mute lives on the rule AND we don't warn on delete, then rule-delete silently loses pause state"), probe it now while you're still in dialogue. One probe per genuine combination effect, asked open-ended, same discipline as rigor probes. Phase 2.5's call-outs are a safety net for residuals (silent agent inferences, pre-loaded contexts with no dialogue) — NOT a punt list for consequences you could have asked about now.

**Exit condition:** Continue until the idea is clear AND no integration-check questions are pending, OR the user explicitly wants to proceed.

### Phase 2: Explore Approaches

If multiple plausible directions remain, propose **2-3 concrete approaches** based on research and conversation. Otherwise state the recommended direction directly.

Use at least one non-obvious angle — inversion (what if we did the opposite?), constraint removal (what if X weren't a limitation?), or analogy from how another domain solves this. The first approaches that come to mind are usually variations on the same axis.

Present approaches first, then evaluate. Let the user see all options before hearing which one is recommended — leading with a recommendation before the user has seen alternatives anchors the conversation prematurely.

If approach differences are spatial, behavioral, or otherwise visual enough that prose would be slower or lower-fidelity, use `references/visual-probes.md` before presenting the choice. For inherently visual topics caught by the Phase 0.3 visual-probe tripwire, this is a gate before the first approach choice about behavior, shape, state, layout, flow, or diagrams; do not substitute an ASCII preview in a blocking question for the visual offer. The visual path remains opt-in and display-only; text remains a first-class path.

When useful, include one deliberately higher-upside alternative:

- Identify what adjacent addition or reframing would most increase usefulness, compounding value, or durability without disproportionate carrying cost. Present it as a challenger option alongside the baseline, not as the default. Omit it when the work is already obviously over-scoped or the baseline request is clearly the right move.

At product tier, alternatives should differ on _what_ is built (product shape, actor set, positioning), not _how_ it is built. Implementation-variant alternatives belong at feature tier.

For each approach, provide:

- Brief description (2-3 sentences)
- Pros and cons
- Key risks or unknowns
- When it's best suited

**Approach granularity: mechanism / product shape, not architecture.** Approach descriptions name mechanism-level distinctions ("pause as a rule property" vs "pause as an event filter" vs "pause as a separate entity") and product-relevant trade-offs (plan-tier coupling, complexity surface, migration difficulty). They do NOT name implementation specifics — column names, table names, file paths, service classes, JSON shapes, exact method names. Those are plan's job. Bringing architecture forward at brainstorm time forces the user to make architectural decisions on brainstorm's intentionally-shallow research, and the synthesis at Phase 2.5 then has to filter out the leak.

After presenting all approaches, state your recommendation and explain why. Prefer simpler solutions when added complexity creates real carrying cost, but do not reject low-cost, high-value polish just because it is not strictly necessary.

If one approach is clearly best and alternatives are not meaningful, skip the menu and state the recommendation directly.

If relevant, call out whether the choice is:

- Reuse an existing pattern
- Extend an existing capability
- Build something net new

### Phase 2.5: Synthesis Summary

**STOP. Before composing the synthesis, read `references/synthesis-summary.md`.** The two-stage shape (internal three-bucket draft → chat-time scoping synthesis), the Path A / Path B gate, the four scoping synthesis sections with their keep tests, the tier-aware bullet budget with re-cut rule, anti-pattern guidance, soft-cut behavior, self-redirect support, and internal-draft routing into doc body sections all live there. Composing a synthesis without these rules loaded reliably produces malformed output — pasting the full internal three-bucket draft verbatim into chat, implementation-detail leakage into the scoping synthesis, the proposal-pitch anti-pattern. **Each scoping synthesis bullet must pass the affirmability test (can the user evaluate this without reading code?) AND the detail test (1–2 lines max, conversational not documentary); over-share and over-detail are the failure modes to avoid.** This is not optional supplementary reading; it is the source of truth for how the phase behaves.

Surface a scoping synthesis to the user before Phase 3 writes the `tunan:req` issue — the user's last opportunity to correct scope before the artifact lands. The scoping synthesis is shaped like what two product collaborators would confirm before writing a PRD, not like a comprehensive audit or a one-line preview.

Fires for **all tiers** including Lightweight. Skip Phase 2.5 entirely on the Phase 0.1b non-software (universal-brainstorming) route.

**Path A vs Path B:** the scoping synthesis shape depends on TWO signals — whether any blocking question fired AND what tier Phase 0.3 classified the scope as.

- **Path A — no blocking questions fired AND tier is Lightweight**: announce-mode. Emit "What we're building" prose only (1–3 sentences), then proceed to Phase 3 doc-write in the same turn. No other sections, no confirmation question. Do NOT end the turn waiting for acknowledgment. The user can revise after the doc lands if the shape is wrong — Lightweight Path A docs are short, post-hoc revision is cheap.
- **Path B — at least one blocking question fired, OR tier is Standard / Deep-feature / Deep-product**: full tier-aware scoping synthesis with confirmation gate. Two scenarios fire Path B: (a) the user invested answer-time during dialogue, or (b) the user pre-loaded substantive scope content (Phase 0.2 fast-path with a richly-specified opening prompt). Either way, the substance earns a real checkpoint. Confirmation is unconditional even when zero call-outs survive the keep test.

**Why the tier guard on Path A**: Phase 0.2's fast path serves two very different cases — a tight one-liner that needs no dialogue ("fix the typo on line 47") and a richly pre-loaded brainstorm context that ALSO needs no dialogue because the user pre-stated everything. Without the tier guard, both route to Path A and the pre-loaded case gets a 1-sentence checkpoint for what may be 20+ items worth of scope. Tier-classifying Phase 0.3 distinguishes the two — pre-loaded substance makes the tier Standard or Deep, which then routes to Path B.

### Phase 3: Capture the Requirements

Write the requirement to a `tunan:req` GitHub issue only when the conversation produced durable decisions worth preserving — see `references/brainstorm-sections.md` "Decide whether a doc is warranted at all" for the criteria and the bug-fix stress test. Skip issue creation when the user only needs brief alignment and the decisions can flow downstream (plan, commit message, `tunan:solution` learnings) without a requirement artifact in the middle. (When a `REQ_ISSUE` is already bound — e.g., a `new-raw` issue — still update it even for slim outcomes, since the issue already exists.)

When a requirement is warranted, compose its markdown body using:

- `references/brainstorm-sections.md` — section contract (outcomes, hard floor, include-when-material catalog, agency rules, ID conventions).
- `references/markdown-rendering.md` — how those sections render as the issue body markdown. Put the brainstorm metadata fields (`date`, `topic`) as a fenced ```yaml block at the top of the body.

Build the body in an OS temp file (bash `${TMPDIR:-/tmp}`, PowerShell `$env:TEMP`), then write the issue:

- **`REQ_ISSUE` is bound** (issue ref passed, or a match found in Phase 0.1): rewrite that issue's body with the finished requirement. The title becomes `[req] <topic>` — **always replace a `[raw]` prefix with `[req]`** when promoting a `new-raw` capture; otherwise update the title only if it is a stale placeholder, preserving a good user-set title.

  **Merge, do not clobber.** When the bound issue already has a populated body — the common case for a `new-raw` issue — read the current body first and **carry forward verbatim** the sections `new-raw` authored that the finished requirement does not regenerate:
  - the sponsor's original words (the `## Background / original words` section) — this is the verbatim source of truth for what the user asked; the agent-synthesized Problem Frame does not replace it.
  - the assets section (`## Assets to upload`, its to-upload checklist, and any `<!-- TODO: drag in ... -->` placeholder comments) — dropping it loses the pending-asset list and the drag-in instructions the user still needs.
  - the `kind:` and `priority:` YAML fields — merge them into the metadata block alongside `date` / `topic`; do not lose them by replacing the whole block.

  Dropping the verbatim sponsor words, the pending-asset checklist, or the `kind`/`priority` fields when overwriting a `new-raw` body is a regression. Build the merged body, then write it:

```bash
gh issue edit <N> --body-file <body-file>
```

  **Verify the merge preserved the capture.** After the edit, re-read the body and confirm the `## Background / original words` section is still present with the sponsor's verbatim words intact (and that the `## Assets to upload` checklist and `kind:` / `priority:` fields survived, when they were in the original). If the section was dropped or the words were paraphrased, the merge clobbered the capture — restore it from the pre-edit body read and re-write. Do not report the requirement as captured until the verbatim original input is confirmed present.

```bash
gh issue view <N> --json body --jq .body
```

  **Promote the label `tunan:raw → tunan:req`.** A `new-raw` capture carries `tunan:raw`; once `brainstorm` has written the normalized requirement back, the issue IS a `tunan:req` requirement and the rest of the pipeline (`plan`, `doc-review`, `status`, `closeissue`) keys off `tunan:req`. Ensure the `tunan:req` label is present, then drop `tunan:raw` **only when the bound issue currently carries it** (known from the labels read in Phase 0.0 — `gh issue edit --remove-label` errors on a label the issue does not have). When the bound issue was already `tunan:req`, the add is idempotent and the remove is skipped.

```bash
gh issue edit <N> --add-label "tunan:req"
gh issue edit <N> --remove-label "tunan:raw"   # only when the issue currently carries tunan:raw
```

  **Verify the promotion.** After the label edits, re-read the issue's labels and confirm `tunan:req` is present and `tunan:raw` is absent. If the swap did not take (a CLI error, wrong issue number, or the conditional remove was skipped when it should have run), an issue left carrying only `tunan:raw` is invisible to every downstream skill that keys off `tunan:req` (`plan`, `doc-review`, `status`, `closeissue`). Re-run the failed edit before reporting the requirement as captured.

```bash
gh issue view <N> --json labels --jq '[.labels[].name]'
```

- **No `REQ_ISSUE`:** create a new issue.

```bash
gh issue create --title "[req] <topic>" --label "tunan:req" --body-file <body-file>
```

Capture the resulting issue number/URL — Phase 4 passes it downstream. Report the issue URL to the user (a `🔗` line) so it is clickable; do not write or confirm any local file path.

#### Vocabulary Capture — after the requirement issue (only if CONCEPTS.md already exists)

**Skip this step entirely if `CONCEPTS.md` does not exist at repo root** — creation is owned by compound and compound-refresh.

Run this **after** the approaches, the scope synthesis, and the requirement issue — that is where the canonical term often gets chosen or corrected, so capturing during early dialogue (before this point) would miss the final resolved name. If it exists, scan the full dialogue and the requirement issue body for **resolved** domain terms — terms where the conversation actively pinned down a precise local meaning, not terms merely mentioned in passing. **Resolved means the definition is settled, not still under discussion.** Provisional terms that may still revise stay in the conversation only.

For each resolved term: if missing, add it; if present but new precision surfaced, refine it; if already consistent, no action.

**Domain entities, named processes, and status concepts with project-specific meaning only.** Not file paths, class names, function signatures, or implementation decisions — `CONCEPTS.md` is a glossary, not a spec or catch-all.

Follow the format set by existing entries. Apply edits silently. (If Phase 3 skipped the issue, still run this against the resolved dialogue.)

### Phase 4: Handoff

Present next-step options and execute the user's selection. Read `references/handoff.md` for the option logic, dispatch instructions, and closing summary format.

**REQUIRED — route the next-step menu through the blocking question tool, not an ad-hoc chat list.** This is an answer-alignment moment: when 4 or fewer options are visible (the common case), present them with the platform's blocking question tool — `AskUserQuestion` in Claude Code, `request_user_input` in Codex, `ask_user` in Gemini/Pi. Do **not** improvise a "接下来做什么 / what next" numbered list in chat as a substitute, and do **not** invent options — use the canonical handoff options from `references/handoff.md`, shown only when their state conditions hold. When more than 4 options are visible, still fire the blocking tool: present the 4 highest-priority options and name the rest in the question stem for free-form selection (see `references/handoff.md`) — `AskUserQuestion` caps at 4, so do **not** fall back to a numbered list to fit them all. A bare numbered list in chat is the fallback **only** when no blocking tool exists or the call errors — never a default convenience, and option count alone never justifies it. Never silently skip the question.

**In Claude Code — mandatory first step before presenting the menu:**

```
Call ToolSearch with query "select:AskUserQuestion" to load the tool schema. Do this BEFORE composing the menu options. A pending schema load is not a valid reason to fall back to plain text — load the tool first, then fire it.
```

After loading, present the Phase 4 menu via `AskUserQuestion`. Do NOT write "继续打磨，还是转 plan？" or any equivalent phrasing as plain chat text — this is the single most common regression in this phase and is never acceptable when the tool is available.
