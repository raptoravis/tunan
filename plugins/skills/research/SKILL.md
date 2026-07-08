---
name: research
description: "Investigate a question against high-trust primary sources and capture the findings as a GitHub issue labeled tunan:research. Use when the user wants a topic researched, docs or API facts gathered, or reading legwork delegated to a background agent."
argument-hint: "[the research question]"
---

# Research

Spin up a **background agent** to do the research, so the user keeps working while it reads. The agent investigates the question against primary sources and writes findings to a durable GitHub issue — not a local file that gets lost.

## When to Use

- "research X for me"
- "look into how Y works"
- "find the official docs on Z"
- "what does the spec say about W"
- Any time the user wants facts gathered from primary sources without derailing the current session

## Interaction Method

This skill fires one question — whether to launch now or refine the question first — via the platform's blocking question tool. `AskUserQuestion` in Claude Code (call `ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded), `request_user_input` in Codex, `ask_user` in Gemini/Pi. Fall back to a numbered list in chat only when no blocking tool exists or the call errors.

## Process

### 1. Clarify the question

If the user passed a research topic as `$ARGUMENTS`, use it. If the topic is vague or the user invoked the skill with no arguments, ask one blocking question to narrow it: "What should the agent research?" with the user's original words as a free-form starting point.

Once the question is clear, confirm via blocking tool: launch now (Recommended), or refine the question further.

### 2. Launch the background agent

Dispatch a **background agent** via the platform's subagent primitive (`Agent` in Claude Code, `spawn_agent` in Codex). Pass `run_in_background: true` so the user keeps working while it researches.

The agent's brief:

1. **Investigate against primary sources** — official docs, source code, specs, first-party APIs. Follow every claim back to the source that owns it. Do not rely on secondary write-ups, blog posts, or LLM-generated summaries.
2. **Write findings to a GitHub issue** labeled `tunan:research`. Each claim must cite its source (URL, doc section, file path). Use a temp file for the body and `gh issue create --body-file`.
3. **Return a one-line summary** — the issue number, title, and a gist of the key finding — so the orchestrator can relay it to the user.

Ensure the `tunan:research` label exists before creating:

```bash
gh label list --search "tunan:research" --json name --jq '.[].name' | grep -q . || \
  gh label create "tunan:research" --color 0e8a16 --description "tunan research findings"
```

```bash
gh issue create --title "[research] <descriptive title>" --label "tunan:research" --body-file <body-file>
```

### 3. Relay the result

When the background agent completes, surface its one-line summary to the user with a link to the issue. The full findings live in the issue — the chat gets the headline and the pointer.

## Anti-patterns

- **Researching inline** — the point is to delegate to a background agent so the current session isn't blocked. Never run the research synchronously unless the platform lacks background agent support.
- **Secondary sources** — blog posts, forum threads, and LLM summaries are not primary sources. The agent must trace claims to the official doc, spec, or source code that owns them.
- **Writing a local file** — findings go in a `tunan:research` GitHub issue, never a local `.md` file. If `gh` is unavailable, abort with a clear message; do not fall back to local storage.
- **Researching without a clear question** — a vague "look into X" produces an unfocused report. Narrow the question in Step 1 before launching.
