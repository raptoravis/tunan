# Project intent interview

Loaded at the start of Phase 1 (and revisited per-section when revising an existing project). Each section maps to a section in the `tunan:project` issue body (see `project-issue-contract.md`). For each: ask the opening question, evaluate against the quality bar, push back when the answer falls into a named anti-pattern, and capture the answer in the user's own words.

This interview is inherited from the retired `strategy` skill. The rigor is in the questions, not the headings.

## Overall rules

1. **Ask, don't prescribe.** Free-form responses for the open sections (problem, approach, persona). Reserve single-select for routing.
2. **Push back once, maybe twice.** If the first answer is weak, name the specific issue and ask a sharper question. If still weak, capture what's given and note the section is worth revisiting. Do not spiral.
3. **Quote the user back at them.** Challenge with their own words verbatim; paraphrasing softens the challenge.
4. **Keep each answer to 1–3 sentences.** Longer answers usually hide something vague.
5. **Don't leak anti-pattern names.** Don't say "that's a vanity metric" — just ask the sharper follow-up.

---

## 1. Target problem

**Opening:** "What's the core problem this project solves — and what makes that problem hard?"

Strong answers name a specific user situation, identify what makes it hard *right now*, and are falsifiable.

**Pushback:**
- **Goal stated as problem** ("we need to grow revenue") → "That's a goal, not a problem. What's making it hard? Whose situation are you changing?"
- **Vague wish** ("people need better tools for X") → "Whose situation specifically? Doing what? What do they try today, and why doesn't it work?"
- **Symptom, not cause** ("users churn after 30 days") → "That's a symptom. What's happening in their world that makes them stop caring?"
- **Too broad** ("communication at work is broken") → "Narrow it to a situation you can actually affect — which users, doing what, when does it hurt most?"
- **Feature-shaped** ("there's no good way to do [workflow] with AI") → "That's a missing feature. What outcome do users want that the feature would give them?"

**Capture:** 1–2 sentences naming the situation and the crux. No solution language.

---

## 2. Our approach

**Opening:** "Given that problem, what's your approach — the commitment or principle that makes it tractable?"

Strong answers are a choice (implying alternatives not pursued), general enough to direct many decisions but specific enough to rule things out.

**Pushback:**
- **Fluff / values** ("customer-obsessed, move fast") → "Those are values. What are you doing *differently* from the alternatives users could pick?"
- **Feature list** ("AI-powered X, Y, Z") → "What's the underlying bet that makes you pick those features? What principle guides what you ship?"
- **Product description** ("we use AI to draft replies") → "That's what it does. What's the *choice* inside it that the obvious alternative isn't making?"
- **Goal restated** ("be the market leader") → "Still the goal. What choice are you making that competitors aren't?"
- **Doesn't connect to the problem** → "How does that approach solve the problem you named? If there's no line between them, one of the two is wrong."

**Capture:** 1–2 sentences, ideally ending with "...so that [outcome tied to the problem]".

---

## 3. Who it's for

**Opening:** "Who is the primary user, and what job are they hiring this product to do?"

Jobs-to-be-done framing. Strong answers name one primary persona by role/situation (not demographic) and a concrete job as a verb phrase.

**Pushback:**
- **Too many primaries** ("founders, PMs, engineers, designers") → "If it's for everyone, it's for no one. Who matters most?"
- **Demographic** ("25–45 professionals") → "That's a demographic. What are they trying to do that makes them pick this up?"
- **Role without situation** ("PMs") → "PMs doing what? The situation is where the product matters."
- **Generic job** ("be more productive") → "Productive at what? They're hiring this to do *what*?"

**Capture:** Persona name + JTBD sentence.

---

## 4. Key metrics

**Opening:** "What 3–5 metrics will tell you whether the approach is working?"

Strong answers stay at 3–5, mix leading and lagging, and could plausibly regress if the product got worse.

**Pushback:**
- **Vanity** ("total signups, pageviews") → "Those go up while the product gets worse. What moves when users actually get value?"
- **Too many** ("12 metrics") → "A dashboard isn't a strategy. Pick the 3–5 you'd stake the quarter on."
- **Outputs not outcomes** ("deploys per week") → "Those measure the team. If velocity doubled but users didn't care, is it a win?"
- **Can only go up** ("cumulative hours saved") → "What's the rate, ratio, or thing that can regress?"
- **Unmeasurable** ("user delight") → "How would you check it on a Tuesday? If you can't, it's aspirational."

**Capture:** 3–5 metrics, each with a one-line definition and where it's measured (analytics/DB/qualitative). If undefined: "Where does this live today? If nowhere, can you start measuring it?"

---

## 5. Tracks

**Opening:** "What are the 2–4 tracks of work you're investing in to execute the approach?"

Tracks are named domains of investment, not feature lists or todos. Strong answers stay at 2–4, connect to the approach, and are broad enough that multiple features live inside each.

**Pushback:**
- **Feature list in disguise** ("Slack integration; mobile app; dark mode") → "Those are features. What investment area does each live inside? 'Integrations' might be one track."
- **Too many** ("7 tracks") → "Every track is starved. Which 3 are load-bearing?"
- **Doesn't connect to approach** → "How does that track serve the approach? If it's a separate bet, name it as one."
- **Too vague** ("improve the product") → "What's the specific investment area different from the others?"
- **One track only** → "With one track there's no real choice. What are the 2–3 things the product must be good at?"

**Capture:** 2–4 tracks; each a name, one-line purpose, and why it serves the approach.

---

## Optional sections

- **Not working on** — "Anything you've explicitly decided *not* to do that the team keeps being tempted by?" Skip by default; one line each if named.
- **Marketing** — "Any positioning/tagline/key message the doc should carry?" Skip by default; 2–3 lines if present.

Milestones are **not** captured here — they are the `## Roadmap` section, owned by `new-project` Phase 2 and `new-milestone`.

## After the interview

Once sections 1–5 are captured, hand back to the SKILL.md flow: Phase 2 builds the roadmap, later phases seed requirements, Phase 5 assembles and writes the `tunan:project` issue per `project-issue-contract.md`.
