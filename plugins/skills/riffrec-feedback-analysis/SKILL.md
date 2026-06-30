---
name: riffrec-feedback-analysis
description: Riffrec product-feedback workflow. ALWAYS load when the user posts a `riffrec-*.zip`, a bundle with `session.json` + `events.json` + `recording.webm` + `voice.webm`, a video/audio recording for product feedback, or asks how to capture and share Riffrec sessions. Routes between setup, quick bug report, and extensive analysis.
---

# Riffrec Feedback Analysis

Turn raw product feedback into structured evidence for downstream agents. This skill is the consumption side of [Riffrec](https://github.com/kieranklaassen/riffrec), a capture tool that records synchronized screen + voice + event sessions and emits a `riffrec-*.zip` bundle.

## Choose the path

Route to the matching reference based on the input. Read only that reference; do not load the others.

- **Setup** — user has no recording yet and asks how to install Riffrec, capture a session, or share feedback. Read `references/install-riffrec.md`.
- **Quick bug report** — input is a short recording (under ~60 seconds), the user describes a single specific issue, or asks for "quick", "small", or "just transcribe". Read `references/quick-bug-report.md`. Emit one concise bug report; skip the full artifact set and brainstorm handoff.
- **Extensive analysis** — input is a longer recording, contains multiple issues / requirements / workflow walkthroughs, or the user wants requirements or brainstorm material. Read `references/extensive-analysis.md`. Always continue into the `brainstorm` skill.

When the input is ambiguous (e.g., a zip arrived without context), inspect the recording length and event count before choosing. If still unclear, ask the user which path applies before running anything heavy — present the three paths (Setup / Quick bug report / Extensive analysis) through the platform's blocking question tool: `AskUserQuestion` in Claude Code (call `ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded), `request_user_input` in Codex, `ask_user` in Gemini/Pi. Fall back to a numbered list in chat only when no blocking tool exists or the call errors. Never silently skip the question.

## Issue storage (GH preflight)

Both the quick and extensive paths store their durable output as a GitHub issue, never a local file. Run the GH preflight before any issue read/write — abort with the guidance shown if any check fails; NEVER fall back to a local file (the analyzer's temp scaffolds are working material, not the durable artifact). The Setup path does not touch issues, so it skips this.

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

**Ensure the `tunan:req` label exists** (both paths create issues under this label):

```bash
gh label list --search "tunan:req"
```

If it is absent, create it:

```bash
gh label create "tunan:req" --color 1f883d --description "tunan requirements"
```

## Common rules

- Keep raw recordings, audio chunks, zip contents, session dumps, and extracted screenshots transient and local-only. Extract them to an OS temp dir (`${TMPDIR:-/tmp}` / `$env:TEMP`). Do not commit `raw/` or `frames/` directories.
- Durable text artifacts (requirements, analysis summaries, problem analyses, bug reports) are stored as **GitHub issues** distinguished by label, never as local files. The extensive path's requirements material becomes a `tunan:req` issue; the quick path's bug report becomes a GitHub issue. Requirements live in GitHub issues, never local files.
- When referencing screenshots or evidence inside an issue body, note their transient temp-dir paths and the original source location so later agents can re-extract from the source recording — the temp media is not committed and may be cleaned up by the OS.

## Analyzer entrypoint

All non-setup paths share the same analyzer. Run it to a temp output dir (use `python3` on macOS/Linux, `python` or `py -3` on Windows):

```bash
python scripts/analyze_riffrec_zip.py /path/to/input --output-dir "$(mktemp -d -t riffrec-XXXXXX)"
```

Accepted inputs: a Riffrec `.zip`, an `.mp4` / `.mov` / `.webm` video, an `.m4a` / `.mp3` / `.wav` audio file, or a meeting-notes `.md`. The analyzer extracts **transient media** (frames, raw, chunk transcripts) plus scaffold markdown. Always point `--output-dir <dir>` at an OS temp dir so nothing pollutes the repo — the durable analysis/requirements output does NOT live in that directory, it goes into a GitHub issue (extensive path → `tunan:req` issue; quick path → bug-report issue). Treat the analyzer's `.md` scaffolds as working material read from temp and synthesized into the issue body, not as committed artifacts.

The tunan output format used by the extensive path is documented in `references/compound-engineering-feedback-format.md`.
