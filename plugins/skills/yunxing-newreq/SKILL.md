---
name: yunxing-newreq
description: "Capture a requirement described in the current conversation (text plus any screenshots or videos) into a single GitHub issue that becomes the source of truth for that requirement. Creates the issue with a `yunxing:req` label, a one-line summary, the sponsor's original words, and asset placeholders to drag in. Downstream skills like yunxing-brainstorm read the issue as input and write the finished requirements back to it. Use when the user says capture this, save this as a requirement, log a req, or wants a conversation turned into a tracked GitHub issue before brainstorming or planning."
argument-hint: "[slug] [--align] [--kind=feature|bug|chore] [--priority=P0|P1|P2] [--dry-run]"
---

# yunxing-newreq — capture a requirement into a GitHub issue

This skill turns a requirement the user just described in conversation (text plus any pasted screenshots or videos) into one **GitHub issue**. That issue is the durable source of truth for the requirement: downstream skills (`yunxing-brainstorm`, `yunxing-plan`) read it as input and `yunxing-brainstorm` writes the finished requirements back into it. Requirements and their state live in GitHub issues, never in local files.

This skill only **creates the issue**. It does not expand the requirement into acceptance criteria, run research, or write a plan — that is `yunxing-brainstorm`'s and `yunxing-plan`'s job. Keep the capture faithful to what the user actually said; do not invent scope.

**Boundary with `yunxing-brainstorm`:** if the user wants to *think through* a vague idea, route to `yunxing-brainstorm` directly. Use this skill when the user wants to *record* a stated requirement first ("capture this", "save this as a requirement", "log a req"). The issue this skill produces is a valid input to `yunxing-brainstorm` and `yunxing-plan`.

## Invocation

```
/yunxing-newreq                         # default: extract from the current conversation, fast path
/yunxing-newreq <slug>                  # explicit kebab-case slug for the title
/yunxing-newreq --kind=feature|bug|chore  # explicit kind; default auto-detected, else feature
/yunxing-newreq --priority=P0|P1|P2     # explicit priority; default P2
/yunxing-newreq --align                 # ask at every soft decision via yunxing-align
/yunxing-newreq --dry-run               # print the title + body + asset list, create nothing
```

Do not accept destructive flags. This skill never edits local files and never commits.

## Default mode (fast path) vs `--align`

**Default** (no `--align`): emit **no** blocking questions. Take the best default at every soft decision and continue — auto-detect `kind` (fall back to `feature`), use `priority=P2`, skip the pre-create confirmation, and create the issue directly. Conversation extraction, asset preparation, token rewriting, and post-create verification still run.

**`--align`:** ask at every soft decision (kind, priority, asset names, final confirmation) using the platform's blocking question tool, following the `yunxing-align` protocol — at least 3 ranked options with the single best one placed first and labeled `(Recommended)`. Load the `yunxing-align` skill for the full protocol. Use `AskUserQuestion` in Claude Code (call `ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded), `request_user_input` in Codex, `ask_user` in Gemini, `ask_user` in Pi (requires the `pi-ask-user` extension). Fall back to a numbered list in chat only when no blocking tool exists or the call errors — never silently skip a question.

`--dry-run` takes precedence over `--align`: print the plan and stop without asking.

## Step 1: Preflight

The requirement is stored in a GitHub issue, so a working, authenticated `gh` is mandatory. Run these checks and **abort with a clear message** if any fails — never fall back to a local file:

1. `gh` is installed. If not, tell the user to install it (`https://cli.github.com`) or run `/yunxing-setup`.
2. `gh auth status` succeeds. If it exits non-zero, tell the user to run `gh auth login` (in Claude Code they can type `! gh auth login` so the output lands in the session), then re-run this skill.
3. Resolve the target repo with `gh repo view --json nameWithOwner`. If there is no repo, abort and explain that this skill needs a GitHub repository.

Then ensure the `yunxing:req` label exists in the repo:

```bash
gh label list --search "yunxing:req"
```

If it is absent, create it:

```bash
gh label create "yunxing:req" --color 1f883d --description "yunxing requirement"
```

## Step 2: Extract the requirement from the conversation (do not invent)

Scan the **most recent** stretch of the user's own messages (not the assistant's). Pull out:

- the core one-line summary
- the original words (keep the user's language verbatim — do not translate)
- reproduction steps, current behavior, and expected behavior **if** the requirement is a bug
- any screenshots, videos, links, or file paths the user referenced

Do not expand the requirement, do not add acceptance criteria, do not research. Preview three blocks in the terminal: **original words**, **one-line summary**, **asset list**.

## Step 3: Resolve kind, priority, and slug

- **kind** — `--kind=` if given; otherwise auto-detect from the conversation (`bug` when the user reports something broken, `chore` for maintenance, else `feature`). In `--align`, ask via `yunxing-align` with the most likely kind first.
- **priority** — `--priority=` if given; otherwise `P2`. In `--align`, ask via `yunxing-align` (`P2` placeholder first, then `P1`, then `P0`; promote `P0` to first when the user's words signal a blocker — "can't", "blocked", "down", "broken in production").
- **slug** — the positional argument if given, else derive a short kebab-case slug from the summary. The issue title is `[req] <slug rendered as a readable title>`.

Ensure the `kind:<value>` and `priority:<value>` labels exist (list, then create the missing one with `gh label create`), so they can be attached at create time. Keep the label values in sync with the body YAML.

## Step 4: Prepare assets (placeholders only)

This skill does **not** upload assets — `gh` has no API to attach files to an issue body, and using a release or branch to host them pollutes the repo. Instead, build a to-upload list and leave a placeholder line per asset in the body. After the issue is created, the user drags each file into the issue's comment box in the browser; GitHub converts each to a user-content URL they paste back into the body.

For every asset the user referenced, give it a semantic kebab-case name (2–5 words, lowercase, ASCII, keep the original extension). Read images as multimodal input to name them from content; infer video/binary names from context without reading their bytes. Disambiguate duplicates with `-2`, `-3`.

Rewrite every placeholder token in the user's original words — `[Image #N]`, `[Image: source: ...]`, `<image_N>`, and similar — into an HTML comment like `<!-- TODO: drag in wrong-page-screenshot.png, then replace with its user-content URL -->`. **Never** let a literal `[Image #N]` token survive into the issue body.

## Step 5: Confirm (only in `--align`)

In `--align`, show the assembled plan (title, labels, body YAML, asset placeholder list) and ask via `yunxing-align`: `apply (Recommended)` / `tweak slug / kind / priority / asset names` (free-text) / `abort`. In default mode, skip straight to Step 6.

## Step 6: Create the issue

Assemble the body. Render `kind`-specific sections only when they apply; delete sections with nothing to say rather than leaving empty headers.

````markdown
```yaml
kind: feature|bug|chore
priority: P0|P1|P2
created: <YYYY-MM-DD>
```

# <one-line summary>

## Background / original words

<the user's own words, verbatim, language preserved. Placeholder tokens already rewritten to `<!-- TODO: drag in ... -->` comments per Step 4.>

## Reproduction        <!-- bug only; delete otherwise -->

1. ...
2. ...

## Current behavior     <!-- bug: what happens; feature/chore: the pain point. Delete if nothing to say. -->

## Expected             <!-- only when the user stated a clear expectation; delete otherwise -->

## Assets to upload      <!-- only when assets were referenced; delete otherwise -->

<!--
Open this issue in the browser, drag the files below into the comment box, then
replace each `<!-- TODO: drag in ... -->` comment in the body above with the
user-content URL GitHub returns:
  ![alt](<user-content-url>)   for images
  [label](<user-content-url>)  for video / other files
-->

- [ ] **to upload**: `wrong-page-screenshot.png` — wrong page screenshot
- [ ] **to upload**: `bug-repro-recording.mp4` — reproduction recording
````

Then create the issue (use today's date from the environment context — the current year is 2026):

```bash
gh issue create --title "[req] <title>" --label "yunxing:req,kind:<kind>,priority:<priority>" --body-file <body-file>
```

Do **not** `git add` or commit — this skill never touches the local working tree.

## Step 7: Verify

- `gh issue view <number> --json labels` includes `yunxing:req` (and the `kind:` / `priority:` labels).
- The body contains the three YAML lines (`kind` / `priority` / `created`).
- The body contains no literal `[Image #N]` / `[Image: source:` token (grep match = failure; fix and re-edit).

## Step 8: Output and handoff

Put the issue URL on its own line at the top with a `🔗` so it is easy to click. Then offer next steps.

```
✅ Requirement captured: #<N> [req] <title>

🔗 <issue URL>

   labels: yunxing:req, kind:<kind>, priority:<priority>
   assets to upload: <count>   # omit when zero

Next (if assets were referenced): open the URL, drag the files into the comment
box, and paste their user-content URLs back into the body's TODO lines.

What next?
  1. (Recommended) yunxing-brainstorm #<N>  — think it through; the finished requirements are written back into this issue
  2. yunxing-plan #<N>                       — plan the implementation directly from the captured requirement
  3. gh issue edit #<N>                      — refine the capture by hand
```

## Common mistakes

- **Falling back to a local file when `gh` is missing or unauthenticated** — abort instead; requirements live in GitHub issues.
- **Inventing scope** — capture only what the user said; acceptance criteria and research belong to `yunxing-brainstorm`.
- **Leaving a literal `[Image #N]` token in the body** — always rewrite to a `<!-- TODO -->` comment.
- **Asking questions in default mode, or staying silent in `--align`** — default mode is silent and takes defaults; `--align` asks at every soft decision.
- **Label / YAML mismatch** — the `kind:` and `priority:` labels must match the body YAML values.
- **Forgetting to prompt for asset upload** — the body holds only placeholders; tell the user to drag the files in after creation.
