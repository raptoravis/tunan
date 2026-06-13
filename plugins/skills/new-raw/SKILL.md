---
name: new-raw
description: "Capture a requirement described in the current conversation (text plus any screenshots or videos) into a single GitHub issue that becomes the raw source of truth for that requirement. Creates the issue with a `tunan:raw` label, a one-line summary, the sponsor's original words, and asset placeholders to drag in. Downstream skills like brainstorm read the issue as input and write the finished requirements back to it, promoting it to a `tunan:req` requirement. Use when the user says capture this, save this as a requirement, log a req, or wants a conversation turned into a tracked GitHub issue before brainstorming or planning."
argument-hint: "[slug] [--align] [--kind=feature|bug|chore] [--priority=P0|P1|P2] [--dry-run]"
---

# new-raw — capture a raw requirement into a GitHub issue

This skill turns a requirement the user just described in conversation (text plus any pasted screenshots or videos) into one **GitHub issue** labeled `tunan:raw`. That issue is the durable **raw** source of truth for the requirement: downstream skills (`brainstorm`, `plan`) read it as input. `brainstorm` writes the finished, normalized requirements back into it and **promotes it from `tunan:raw` to `tunan:req`** — at which point it is a normalized requirement the rest of the pipeline (`plan`, `doc-review`, `status`) recognizes. Requirements and their state live in GitHub issues, never in local files.

This skill only **creates the issue**. It does not expand the requirement into acceptance criteria, run research, or write a plan — that is `brainstorm`'s and `plan`'s job. Keep the capture faithful to what the user actually said; do not invent scope.

**Boundary with `brainstorm`:** if the user wants to *think through* a vague idea, route to `brainstorm` directly. Use this skill when the user wants to *record* a stated requirement first ("capture this", "save this as a requirement", "log a req"). The issue this skill produces is a valid input to `brainstorm` and `plan`.

## Invocation

```
/tunan:new-raw                         # default: extract from the current conversation, fast path
/tunan:new-raw <slug>                  # explicit kebab-case slug for the title
/tunan:new-raw --kind=feature|bug|chore  # explicit kind; default auto-detected, else feature
/tunan:new-raw --priority=P0|P1|P2     # explicit priority; default P2
/tunan:new-raw --align                 # ask at every soft decision via align
/tunan:new-raw --dry-run               # print the title + body + asset list, create nothing
```

Do not accept destructive flags. This skill never edits local files and never commits.

## Default mode (fast path) vs `--align`

**Default** (no `--align`): emit **no** blocking questions *during capture*. Take the best default at every soft decision and continue — auto-detect `kind` (fall back to `feature`), use `priority=P2`, skip the pre-create confirmation, and create the issue directly. Conversation extraction, asset preparation, token rewriting, and post-create verification still run. This silence applies to capture-time soft decisions only; the terminal "what next" handoff in Step 8 always fires the blocking question tool regardless of mode.

**`--align`:** ask at every soft decision (kind, priority, asset names, final confirmation) using the platform's blocking question tool, following the `align` protocol — at least 3 ranked options with the single best one placed first and labeled `(Recommended)`. Load the `align` skill for the full protocol. Use `AskUserQuestion` in Claude Code (call `ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded), `request_user_input` in Codex, `ask_user` in Gemini, `ask_user` in Pi (requires the `pi-ask-user` extension). Fall back to a numbered list in chat only when no blocking tool exists or the call errors — never silently skip a question.

`--dry-run` takes precedence over `--align`: print the plan and stop without asking.

## Step 1: Preflight

The requirement is stored in a GitHub issue, so a working, authenticated `gh` is mandatory. Run these checks and **abort with a clear message** if any fails — never fall back to a local file:

1. `gh` is installed. If not, tell the user to install it (`https://cli.github.com`) or run `/tunan:setup`.
2. `gh auth status` succeeds. If it exits non-zero, tell the user to run `gh auth login` (in Claude Code they can type `! gh auth login` so the output lands in the session), then re-run this skill.
3. Resolve the target repo with `gh repo view --json nameWithOwner`. If there is no repo, abort and explain that this skill needs a GitHub repository.
4. **Setup reminder (non-blocking).** If the repo has no `tunan:config` issue, this repo hasn't been through tunan setup — tell the user once, "This repo isn't set up for tunan yet; run `/tunan:setup` to configure it," then continue. A missing config is non-blocking and never aborts the run.

Then ensure the `tunan:raw` label exists in the repo:

```bash
gh label list --search "tunan:raw"
```

If it is absent, create it:

```bash
gh label create "tunan:raw" --color e8a317 --description "tunan raw requirement (pre-brainstorm)"
```

## Step 2: Extract the requirement from the conversation (do not invent)

Scan the **most recent** stretch of the user's own messages (not the assistant's). Pull out:

- the core one-line summary
- the original words (keep the user's language verbatim — do not translate)
- reproduction steps, current behavior, and expected behavior **if** the requirement is a bug
- any screenshots, videos, links, or file paths the user referenced

Do not expand the requirement, do not add acceptance criteria, do not research. Preview three blocks in the terminal: **original words**, **one-line summary**, **asset list**.

## Step 3: Resolve kind, priority, and slug

- **kind** — `--kind=` if given; otherwise auto-detect from the conversation (`bug` when the user reports something broken, `chore` for maintenance, else `feature`). In `--align`, ask via `align` with the most likely kind first.
- **priority** — `--priority=` if given; otherwise `P2`. In `--align`, ask via `align` (`P2` placeholder first, then `P1`, then `P0`; promote `P0` to first when the user's words signal a blocker — "can't", "blocked", "down", "broken in production").
- **slug** — the positional argument if given, else derive a short kebab-case slug from the summary. The issue title is `[raw] <slug rendered as a readable title>`.

Ensure the `kind:<value>` and `priority:<value>` labels exist (list, then create the missing one with `gh label create`), so they can be attached at create time. Keep the label values in sync with the body YAML.

## Step 4: Prepare assets (placeholders only)

This skill does **not** upload assets — `gh` has no API to attach files to an issue body, and using a release or branch to host them pollutes the repo. Instead, build a to-upload list and leave a placeholder line per asset in the body. After the issue is created, the user drags each file into the issue's comment box in the browser; GitHub converts each to a user-content URL they paste back into the body.

For every asset the user referenced, give it a semantic kebab-case name (2–5 words, lowercase, ASCII, keep the original extension). Read images as multimodal input to name them from content; infer video/binary names from context without reading their bytes. Disambiguate duplicates with `-2`, `-3`.

Rewrite every placeholder token in the user's original words — `[Image #N]`, `[Image: source: ...]`, `<image_N>`, and similar — into an HTML comment like `<!-- TODO: drag in wrong-page-screenshot.png, then replace with its user-content URL -->`. **Never** let a literal `[Image #N]` token survive into the issue body.

## Step 5: Confirm (only in `--align`)

In `--align`, show the assembled plan (title, labels, body YAML, asset placeholder list) and ask via `align`: `apply (Recommended)` / `tweak slug / kind / priority / asset names` (free-text) / `abort`. In default mode, skip straight to Step 6.

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
gh issue create --title "[raw] <title>" --label "tunan:raw,kind:<kind>,priority:<priority>" --body-file <body-file>
```

Do **not** `git add` or commit — this skill never touches the local working tree.

## Step 7: Verify

- `gh issue view <number> --json labels` includes `tunan:raw` (and the `kind:` / `priority:` labels).
- The body contains the three YAML lines (`kind` / `priority` / `created`).
- The body contains no literal `[Image #N]` / `[Image: source:` token (grep match = failure; fix and re-edit).

## Step 8: Output and handoff

Put the issue URL on its own line at the top with a `🔗` so it is easy to click, then print the capture summary:

```
✅ Requirement captured: #<N> [raw] <title>

🔗 <issue URL>

   labels: tunan:raw, kind:<kind>, priority:<priority>
   assets to upload: <count>   # omit when zero

Next (if assets were referenced): open the URL, drag the files into the comment
box, and paste their user-content URLs back into the body's TODO lines.
```

Then ask the "what next" handoff via the platform's **blocking question tool** — this terminal menu is an answer-alignment moment and always fires the tool, even in default mode (the default-mode "no blocking questions" rule governs capture-time soft decisions, not this handoff). Use `AskUserQuestion` in Claude Code (call `ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded), `request_user_input` in Codex, `ask_user` in Gemini, `ask_user` in Pi (requires the `pi-ask-user` extension). Follow the `align` protocol: the single best option placed first and labeled `(Recommended)`. Use these canonical options (each label self-contained):

- **brainstorm #<N> (Recommended)** — think it through; the finished requirements are written back into this issue
- **plan #<N>** — plan the implementation directly from the captured requirement
- **edit #<N> by hand** — refine the capture manually with `gh issue edit #<N>`

Fall back to a numbered list in chat only when no blocking tool exists in the harness or the call errors — never silently skip the question.

## Common mistakes

- **Falling back to a local file when `gh` is missing or unauthenticated** — abort instead; requirements live in GitHub issues.
- **Inventing scope** — capture only what the user said; acceptance criteria and research belong to `brainstorm`.
- **Leaving a literal `[Image #N]` token in the body** — always rewrite to a `<!-- TODO -->` comment.
- **Asking questions in default mode, or staying silent in `--align`** — default mode is silent on capture-time soft decisions and takes defaults; `--align` asks at every soft decision. The Step 8 terminal handoff is not a soft decision — it always fires the blocking question tool in both modes.
- **Printing the "what next" menu as a plain numbered list** — Step 8 must fire the blocking question tool (`AskUserQuestion` etc.); a chat numbered list is the fallback only when no tool exists or the call errors.
- **Label / YAML mismatch** — the `kind:` and `priority:` labels must match the body YAML values.
- **Forgetting to prompt for asset upload** — the body holds only placeholders; tell the user to drag the files in after creation.
