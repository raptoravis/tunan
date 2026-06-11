---
name: capture
description: "Zero-friction capture of an idea, note, or follow-up that surfaces mid-work, into a lightweight GitHub issue so it is not lost and does not derail the current task. Four maturity levels — a quick note (default), a backlog parking-lot item, a seed (a forward-looking idea with a trigger condition), and list (browse and triage what was captured). Use when the user says capture this, note this for later, park this idea, jot this down, add to backlog, seed this, or wants to record a passing thought without stopping to brainstorm or plan it now. The captured item is a valid input to brainstorm and plan later."
argument-hint: "[--note|--backlog|--seed|--list] [text]"
---

# capture — record a passing idea without derailing the current task

The point of this skill is **low friction**: a thought surfaces while the user
is doing something else, and they want it recorded and out of the way in one
step — not expanded, not planned, not turned into a conversation. Capture it
faithfully, confirm in one line, and return. Do **not** fire a "what next"
handoff menu in capture modes; derailing the current task is exactly what this
skill exists to avoid. Only `--list` is interactive.

Captured items live in **GitHub issues**, never in local files — same
invariant as `newreq` and `brainstorm`. This skill never edits the working
tree and never commits.

Capture is the lightest rung of the capture ladder: **capture** (record a
thought) → `newreq` (structured requirement capture) → `brainstorm` (think it
through) → `plan` (decide how to build). A captured item is a valid input to
`newreq`/`brainstorm`/`plan` later, via `--list` triage.

## Invocation

```
/tunan:capture <text>              # default: a quick note (same as --note)
/tunan:capture --note <text>       # a quick timestamped note
/tunan:capture --backlog <text>    # a parking-lot item on the shared backlog issue
/tunan:capture --seed <text>       # a forward-looking idea with a trigger condition
/tunan:capture --list              # browse and triage captured items
```

If no text is given (and the mode is not `--list`), pull the thing to capture
from the most recent user message in the conversation. Keep the user's own
words verbatim — do not translate, do not expand, do not invent scope.

## Step 1: Preflight (all modes)

Captured items are GitHub issues, so a working, authenticated `gh` is
mandatory. Run these and **abort with a clear message** if any fails — never
fall back to a local file:

1. `gh` installed (else: install from `https://cli.github.com` or run `/tunan:setup`).
2. `gh auth status` exits 0 (else: run `gh auth login`; in Claude Code suggest typing `! gh auth login`).
3. `gh repo view --json nameWithOwner` resolves (else: a GitHub repo is required).

Ensure the labels this skill uses exist; create the missing one:

```bash
gh label list --search "tunan:capture"
```
```bash
gh label create "tunan:capture" --color c5def5 --description "tunan captured idea"
```

For `--backlog`, also ensure `tunan:backlog`:

```bash
gh label create "tunan:backlog" --color fef2c0 --description "tunan backlog parking lot"
```

A missing `tunan:config` issue is non-blocking — mention `/tunan:setup`
once and continue.

## Step 2: Route by mode

### `--note` (default)

Create one minimal issue. No expansion, no acceptance criteria, no research.

- Title: `[capture] <first line of the note as a short readable phrase>`.
- Body:

  ````markdown
  ```yaml
  kind: note
  captured: <YYYY-MM-DD>
  ```

  <the user's own words, verbatim, language preserved>
  ````

- Create:

  ```bash
  gh issue create --title "[capture] <title>" --label "tunan:capture" --body-file <body-file>
  ```

### `--backlog`

A parking lot — one shared issue that accumulates low-priority items as a
checklist, rather than one issue per item. Find the existing backlog issue;
create it once if absent.

```bash
gh issue list --label "tunan:backlog" --state open --json number,url --jq '.[0]'
```

- **Absent** → create it:

  ```bash
  gh issue create --title "[backlog] parking lot" --label "tunan:backlog" --body-file <seed-body-file>
  ```

  with an initial body of `# Backlog parking lot` and a `## Items` heading.

- **Exists** → append a checklist line to its body (read the body, add
  `- [ ] <verbatim item> — captured <YYYY-MM-DD>` under `## Items`, PATCH it
  back):

  ```bash
  gh issue edit <N> --body-file <updated-body-file>
  ```

### `--seed`

A forward-looking idea that only becomes actionable under some condition —
capture both the idea and its trigger so it can be surfaced later when the
condition holds. If the user did not state a trigger, infer a short one from
the idea and record it; do not block to ask.

- Title: `[seed] <short phrase>`.
- Body:

  ````markdown
  ```yaml
  kind: seed
  captured: <YYYY-MM-DD>
  ```

  **Idea:** <the user's own words, verbatim>

  **Trigger:** <the condition under which this becomes worth acting on — e.g. "once we add multi-tenant support", "if error rate exceeds 1%", "when the v2 API ships">
  ````

- Create:

  ```bash
  gh issue create --title "[seed] <title>" --label "tunan:capture" --body-file <body-file>
  ```

### `--list` (browse and triage)

Read open captured items and the backlog, then let the user triage them.

```bash
gh issue list --label "tunan:capture" --state open --json number,title,url
```
```bash
gh issue list --label "tunan:backlog" --state open --json number,title,url
```

Show them as a compact numbered list (number, kind, one-line summary, and for
seeds their trigger). For seeds, note whether the trigger now appears met.

Then ask the user which item to act on and how, using the platform's blocking
question tool (this triage is an answer-alignment moment): `AskUserQuestion` in
Claude Code (call `ToolSearch` with `select:AskUserQuestion` first if its
schema isn't loaded), `request_user_input` in Codex, `ask_user` in Gemini,
`ask_user` in Pi (requires the `pi-ask-user` extension). When there are 5+
items to browse, render the browse list as a numbered list in chat and accept a
number or free-text in the blocking tool. Per the chosen item, offer:

- **Promote to a requirement** — hand the item's text to `newreq` (or
  `brainstorm` when the user wants to think it through first); once promoted,
  close the capture issue with a comment linking the new `tunan:req` issue so
  it is not double-counted.
- **Keep** — leave it open, unchanged.
- **Close** — it is a duplicate, already done, or no longer wanted; close the
  capture issue (or check off the backlog line).

Fall back to a numbered list in chat only when no blocking tool exists or the
call errors — never silently skip the question.

## Step 3: Confirm (capture modes) — one line, then stop

For `--note`, `--backlog`, `--seed`, print one confirmation line with the URL
and **return without a handoff menu**:

```
✅ Captured (<kind>): #<N> — <title>   🔗 <url>
```

For `--backlog`, confirm the item was appended to the backlog issue and give
its URL. Do not ask "what next" — the user is mid-task; let them get back to it.

## Common mistakes

- **Firing a "what next" menu after a capture** — capture modes confirm in one
  line and stop. Only `--list` is interactive. Derailing the current task
  defeats the skill's purpose.
- **Expanding the idea** — capture verbatim; acceptance criteria, research, and
  scope belong to `newreq`/`brainstorm`/`plan` after `--list` promotion.
- **Falling back to a local file when `gh` is missing** — abort instead;
  captured items live in GitHub issues.
- **Opening a new issue per backlog item** — `--backlog` appends to the single
  shared `tunan:backlog` issue; only `--note` and `--seed` create per-item
  issues.
- **Dropping a seed's trigger** — a seed without a trigger condition is just a
  note; always record the condition (inferred if not stated).
- **Double-counting after promotion** — when `--list` promotes an item to a
  requirement, close the original capture issue so it does not linger as an
  open duplicate.
