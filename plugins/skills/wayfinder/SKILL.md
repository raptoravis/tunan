---
name: wayfinder
description: "Plan a large chunk of work — more than one agent session can hold — as a shared map of decision tickets on the issue tracker, and resolve them one at a time until the way to the destination is clear. Use when a loose idea arrives that is too big for one session and the path forward is unclear."
argument-hint: "[a loose idea, or a map issue #N to continue working through]"
---

# Wayfinder

A loose idea has arrived — too big for one agent session, and wrapped in fog: the way from here to the **destination** isn't visible yet. Wayfinding is about finding that way, not charging at the destination. This skill charts the way as a **shared map** on the issue tracker, then works its tickets one at a time until the route is clear.

The destination varies per effort: a spec to hand off, a decision to lock before planning starts, or a change made in place like a data-structure migration. The map is domain-agnostic — engineering work, course content, whatever fits the shape.

## Plan, don't do

Wayfinder is **planning** by default: each ticket resolves a decision, and the map is done when the way is clear — nothing left to decide before someone goes and does the thing. The pull to just do the work is usually the signal you've reached the edge of the map and it's time to hand off. An effort can override this in its **Notes** — carrying execution into the map itself — but absent that, produce decisions, not deliverables.

## Refer by name

Every map and ticket is a GitHub issue, so it has a **name** — its title. In everything the user reads — narration, the map's Decisions-so-far — refer to it by that name, never by a bare id, number, or slug. A wall of `#42, #43, #44` is illegible; names read at a glance. The id and URL don't vanish — a name wraps its link — but they ride *inside* the name, never stand in for it.

## The Map

The map is a single GitHub issue labeled `tunan:wayfinder-map` — the canonical artifact. Its tickets are **child issues** (GitHub sub-issues) of the map.

The map is an **index**, not a store. It lists the decisions made and points at the tickets that hold their detail; a decision lives in exactly one place — its ticket — so the map never restates it, only gists it and links.

### The map body

The whole map at low resolution, loaded once per session. Open tickets are **not** listed — they are open child issues, found by query.

```markdown
## Destination

<what reaching the end of this map looks like — the spec, decision, or change this effort is finding its way to. One or two lines; every session orients to it before choosing a ticket.>

## Notes

<domain; skills every session should consult; standing preferences for this effort>

## Decisions so far

<!-- the index — one line per closed ticket: enough to judge relevance, then zoom the link for the detail -->

- [<closed ticket title>](link) — <one-line gist of the answer>

## Not yet specified

<!-- in-scope fog you can't ticket yet; graduates as the frontier advances -->

## Out of scope

<!-- work ruled beyond the destination; closed, never graduates -->
```

### Tickets

Each ticket is a **child issue** (GitHub sub-issue) of the map. Its body is the question, sized to one agent session:

```markdown
## Question

<the decision or investigation this ticket resolves>
```

Each ticket carries a label for its type — one of `tunan:wayfinder-research`, `tunan:wayfinder-prototype`, `tunan:wayfinder-grilling`, `tunan:wayfinder-task` (see [Ticket Types](#ticket-types)).

A session **claims** a ticket by assigning it to the dev driving the map, **first**, before any work, so concurrent sessions skip it. That assignee *is* the claim: an open, unassigned ticket is unclaimed.

Blocking uses GitHub's **native** sub-issue relationship. A ticket is **unblocked** when every ticket blocking it is closed; the **frontier** is the open, unblocked, unclaimed children — the edge of the known.

The answer isn't part of the body — it's recorded on resolution (see [Work through the map](#work-through-the-map)). Assets created while resolving a ticket are linked from the issue, not pasted in.

## Ticket Types

Every ticket is either **HITL** — human in the loop, worked *with* a human who speaks for themselves — or **AFK**, driven by the agent alone. A HITL ticket only resolves through that live exchange; the agent never stands in for the human's side of it.

- **Research** (AFK, label `tunan:wayfinder-research`): Reading documentation, third-party APIs, or local resources. Creates findings as a linked asset or a `tunan:research` issue. Use when knowledge outside the current working directory is required. Resolve with `research` skill or `web-researcher` agent.
- **Prototype** (HITL, label `tunan:wayfinder-prototype`): Raise the fidelity of the discussion by making a cheap, rough, concrete artifact to react to — an outline, a rough take, a stub, or UI/logic code. Links the prototype as an asset. Use when "how should it look" or "how should it behave" is the key question. Resolve by building a quick prototype and discussing it with the user.
- **Grilling** (HITL, label `tunan:wayfinder-grilling`): Conversation via `grill-me` — one question at a time, adversarial Q&A to sharpen thinking. The default ticket type for decisions that need human judgment.
- **Task** (HITL or AFK, label `tunan:wayfinder-task`): Manual work that must happen before a *decision* can be made — nothing to decide, prototype, or research, but the discussion is blocked until it's done. Signing up for a service so its API can be judged, provisioning access, moving data so its shape can be seen. This is the one type that *does* rather than decides — and it earns its place by unblocking a decision, not by delivering the destination. The agent drives it alone where it can (AFK); otherwise it hands the user a precise checklist (HITL). Resolved when the work is done; the answer records what was done and any resulting facts (credentials location, new URLs, row counts) later tickets depend on.

## Fog of war

The map is *deliberately* incomplete: don't chart what you can't yet see. Beyond the live tickets lies the **fog of war** — the dim view of decisions and investigations you can tell are coming but can't yet pin down, because they hang on questions still open. Resolving a ticket clears the fog ahead of it, graduating whatever's now specifiable into fresh tickets — one at a time, until the way to the destination is clear and no tickets remain.

The map's **Not yet specified** section is where that dim view is written down: the suspected question, the area to revisit later. Write as loosely or as fully as the view allows.

**Fog or ticket?** The test is whether you can state the question precisely now — *not* whether you can answer it now.

- **Ticket when** the question is already sharp — even if it's blocked and you can't act on it yet.
- **Not yet specified when** you can't yet phrase it that sharply.

## Out of scope

Fog only ever gathers *toward* the destination. The destination fixes the scope, so work beyond it is **out of scope**. It gets its own **Out of scope** section on the map: work you've consciously ruled out of *this* effort.

Ruling something out of scope is a scoping act, not a step on the route. When a ticket that already exists turns out to sit past the destination, **close it** and leave one line in the **Out of scope** section: the gist plus why, linking the closed ticket.

## Invocation

Two modes. **Never resolve more than one ticket per session.**

### Chart the map

User invokes with a loose idea.

1. **Name the destination.** Run a `grill-me` session (one question at a time, adversarial Q&A) to pin down what this map is finding its way to — the spec, decision, or change. The destination fixes the scope, so it's settled first. For domain-heavy efforts, also explore the domain vocabulary through `brainstorm`.
2. **Map the frontier.** Grill again, **breadth-first** this time: fan out across the whole space rather than deep on any one thread, surfacing the open decisions and the first steps takeable now. **If this surfaces no fog** — the way to the destination is already clear, the whole journey small enough for one session — you don't need a map. Stop and ask the user how they'd like to proceed.
3. **Ensure the labels exist**, then **create the map** as a GitHub issue labeled `tunan:wayfinder-map`: Destination and Notes filled in, Decisions-so-far empty, the fog sketched into **Not yet specified**.

   ```bash
   for label in "tunan:wayfinder-map" "tunan:wayfinder-research" "tunan:wayfinder-prototype" "tunan:wayfinder-grilling" "tunan:wayfinder-task"; do
     gh label list --search "$label" --json name --jq '.[].name' | grep -q . || \
       gh label create "$label" --color 0052cc --description "tunan wayfinder"
   done
   ```

   ```bash
   gh issue create --title "[wayfinder] <destination name>" --label "tunan:wayfinder-map" --body-file <body-file>
   ```

4. **Create the tickets you can specify now** as child issues (GitHub sub-issues) of the map — then wire blocking edges in a **second pass** (issues need ids before they can reference each other). Wiring sorts them into the frontier and the blocked; everything you can't yet specify stays in the fog — the **Not yet specified** section.
5. Stop — charting the map is one session's work; do not also resolve tickets.

### Work through the map

User invokes with a map (issue number or URL). A ticket is **optional** — without one, pick the next decision, not the user.

1. **Load the map** — read the issue body (the low-res view), not every ticket body.
2. **Choose the ticket.** If the user named one, use it. Otherwise list open child issues (unblocked, unassigned) — the frontier — and take the first one. **Claim it**: assign it to yourself (`gh issue edit <N> --add-assignee @me`) before any work.
3. **Resolve it** — zoom as needed: fetch the full body of any related or closed ticket on demand; invoke the skills the `## Notes` block names. For grilling tickets, use `grill-me`. For research tickets, use `research` or `web-researcher`. For prototype tickets, build a quick prototype and discuss with the user.
4. **Record the resolution**: post the answer as a comment, **close** the issue, and **append a context pointer** to the map's Decisions-so-far.

   ```bash
   gh issue comment <N> --body "<resolution summary>"
   gh issue close <N>
   ```

   Then update the map body: append to Decisions-so-far and clear any graduated fog from Not yet specified.

5. **Add newly-surfaced tickets** (create as child issues, then wire blocking edges); **graduate any fog** the answer has made specifiable, clearing each graduated patch from **Not yet specified** so it lives only as its new ticket. If the answer reveals a ticket sits beyond the destination, **rule it out of scope** rather than resolving it on the route. If the decision invalidates other parts of the map, update or delete those tickets.

## GH preflight (required)

Wayfinder artifacts are GitHub issues, so a working, authenticated `gh` is mandatory:

```bash
gh --version
gh auth status
gh repo view --json nameWithOwner
```

If any fails, stop and tell the user to fix gh setup. Never fall back to local files.

## Interaction Method

When this skill needs the user to choose (which ticket to resolve, confirm a destination, decide scope boundaries), use the platform's blocking question tool. `AskUserQuestion` in Claude Code (call `ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded), `request_user_input` in Codex, `ask_user` in Gemini/Pi. Cap at 4 options; surface extra destinations in the question stem. Fall back to a numbered list in chat only when no blocking tool exists or the call errors.

## Common mistakes

- **Charging at the destination** — wayfinding is finding the way, not doing the work. Each ticket resolves a decision; the pull to just build the thing is the signal to hand off.
- **Charting everything upfront** — the map is deliberately incomplete. Only ticket what's specifiable now; leave the rest in the fog.
- **Resolving multiple tickets in one session** — one ticket per session. The map is a shared artifact; other sessions may be working tickets in parallel.
- **Answering your own grilling questions** — a HITL grilling ticket requires a live human exchange. The agent never stands in for the human's side.
- **Writing tickets as to-do items** — a ticket is a question to resolve, not a task to complete. "Decide: should we use Postgres or SQLite for the cache layer?" not "Set up the cache database."
- **Skipping the destination** — the destination fixes scope. Without it, the map has no boundary and fog never clears.
