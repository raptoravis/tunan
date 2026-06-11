---
name: setup
description: "Diagnose and configure tunan environment. Checks CLI dependencies, plugin version, and repo-local config. Offers guided installation for missing tools. Use when troubleshooting missing tools, verifying setup, or before onboarding."
disable-model-invocation: true
---

# Compound Engineering Setup

## Interaction Method

Ask the user each question below using the platform's blocking question tool: `AskUserQuestion` in Claude Code (call `ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded), `request_user_input` in Codex, `ask_user` in Gemini, `ask_user` in Pi (requires the `pi-ask-user` extension). Fall back to presenting each question as a numbered list in chat only when no blocking tool exists in the harness or the call errors (e.g., Codex edit modes) — not because a schema load is required. Never silently skip or auto-configure. For multiSelect questions, accept comma-separated numbers (e.g. `1, 3`).

**Alignment protocol.** When asking the sponsor to choose between options, follow the align protocol: offer at least 3 ranked options with the single best one pre-selected as the default — place it first and append `(Recommended)` to its label — so the sponsor lands on the optimal choice by accepting the default. Load the `align` skill for the full protocol. Never hand an open-ended choice back to the sponsor.

Interactive setup for tunan — diagnoses environment health, cleans obsolete repo-local CE config, and helps configure required tools. Review agent selection is handled automatically by `code-review`; project-specific review guidance belongs in `CLAUDE.md` or `AGENTS.md`.

## Phase 1: Diagnose

### Step 1: Determine Plugin Version

Detect the installed tunan plugin version by reading the plugin metadata or manifest. This is platform-specific -- use whatever mechanism is available (e.g., reading `plugin.json` from the plugin root or cache directory). If the version cannot be determined, skip this step.

If a version is found, pass it to the check script via `--version`. Otherwise omit the flag.

### Step 2: Run the Health Check Script

Before running the script, display: "Compound Engineering -- checking your environment..."

Run the bundled check script. Do not perform manual dependency checks -- the script handles all CLI tools, agent skills, MCP servers, repo-local CE file checks, and `.gitignore` guidance in one pass. Pick the variant for the current OS: PowerShell (`.ps1`) on Windows, bash (`.sh`) on macOS/Linux. Both accept the same arguments and print identical output.

Windows (PowerShell):

```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/check-health.ps1 --version VERSION
```

macOS / Linux (bash):

```bash
bash scripts/check-health.sh --version VERSION
```

Or without version if Step 1 could not determine it, omit the `--version VERSION` argument (e.g. `bash scripts/check-health.sh`, or `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/check-health.ps1`).

Script reference: `scripts/check-health.sh` (and its `.ps1` Windows twin).

Display the script's output to the user.

### Step 3: Evaluate Results

**Plugin root (pre-resolved):** !`echo "${CLAUDE_PLUGIN_ROOT}"`

If the line above resolved to an absolute path (starts with `/` and contains no `${`), this is a Claude Code session and `/tunan:update` is available. Anything else — empty, the literal `${CLAUDE_PLUGIN_ROOT}` token, or an unresolved command string like `echo "${CLAUDE_PLUGIN_ROOT}"` left in place by a non-Claude harness that doesn't process `!` pre-resolution — means this is not Claude Code; omit any `/tunan:update` references from output.

After the diagnostic report, check whether:

- any CLI tools are missing (reported as yellow in the Tools section)
- `gh` is present but not authenticated (reported as yellow `gh (not authenticated)` in the Tools section). The tunan workflow stores requirements and state in GitHub issues, so a valid `gh auth status` is required — not just an installed `gh`. The fix is `gh auth login`, not reinstalling the tool.
- any agent skills are missing (reported as yellow in the Skills section)
- any MCP servers are missing (reported as yellow in the MCP Servers section; the section is absent on harnesses without the `claude` CLI)
- `tunan.local.md` is present and needs cleanup
- a `tunan:config` issue does not yet exist (project config lives in a GitHub issue, not a local file — see `references/config-issue-storage.md`)

If everything is installed (tools, skills, and any MCP servers), no repo-local cleanup is needed, and a `tunan:config` issue already exists, display the tool, skill, and MCP list and completion message. Parse the tool, skill, and MCP server names from the script output and list each with a green circle. Omit the Skills line if the Skills section is absent from the script output, and omit the MCP line if the MCP Servers section is absent (non-Claude harnesses):

```
 ✅ Compound Engineering setup complete

    Tools:  🟢 agent-browser  🟢 gh  🟢 jq  🟢 vhs  🟢 silicon  🟢 ffmpeg  🟢 ast-grep
    Skills: 🟢 ast-grep
    MCP:    🟢 context7  🟢 sequential-thinking  🟢 playwright  🟢 chrome-devtools
    Config: ✅

    Run /tunan:setup anytime to re-check.
```

If this is a Claude Code session (the **Plugin root** above resolved to a non-empty path), append to the message: "Run /tunan:update to grab the latest plugin version."

Stop here.

Otherwise proceed to Phase 2 to resolve any issues. Handle repo-local cleanup (Step 4) first, then config bootstrapping (Step 5), then missing dependencies (Step 6).

## Phase 2: Fix

### Step 4: Resolve Repo-Local CE Issues

Resolve the repository root (`git rev-parse --show-toplevel`). If `tunan.local.md` exists at the repo root, explain that it is obsolete because review-agent selection is automatic and CE now stores project config in a `tunan:config` GitHub issue, not a local file. Ask whether to delete it now. Use the repo-root path when deleting. Likewise, if a legacy `.tunan/config.local.yaml` (or `.tunan/config.local.example.yaml`) exists, offer to migrate its set keys into the `tunan:config` issue (Step 5) and delete the local file afterward — config no longer lives on disk.

### Step 5: Bootstrap Project Config

Project config lives in a **GitHub issue labeled `tunan:config`**, not a local file. Read `references/config-issue-storage.md` for the full contract (issue shape, read/write recipes, team-shared vs per-machine semantics). A working, authenticated `gh` is required — if it is missing, skip this step and surface the gh setup hint.

**Check for the config issue:**

```bash
gh issue list --label "tunan:config" --state open --json number --jq '.[0].number // empty'
```

**Absent (create once):** ask whether to create it:

```
Set up a tunan config issue for this project?
This stores your Compound Engineering preferences (which tools to use, how workflows behave) in a GitHub issue shared across the project. Everything starts commented out -- you only enable what you need.

1. Yes, create it (Recommended)
2. No thanks
```

If the user approves, ensure the `tunan:config` label exists (`gh label list --search "tunan:config"`, else `gh label create "tunan:config" --color 6f42c1 --description "tunan project config"`), then create the issue with the annotated template as its body — wrap the contents of `references/config-template.yaml` in a fenced ```yaml block under the `<!-- tunan:config -->` marker (per `references/config-issue-storage.md`):

```bash
gh issue create --title "[config] tunan settings" --label "tunan:config" --body-file <tmpfile>
```

**Present (refresh option):** the config issue already exists — leave it as-is unless the user wants to edit it. If a legacy local `.tunan/config.local.yaml` is also present, offer to merge its set keys into the issue body and delete the local file (config no longer lives on disk).

There is no `.gitignore` entry to manage — config is an issue, not a tracked-or-ignored file.

### Step 6: Offer Installation

Present the missing tools, skills, and MCP servers using a multiSelect question. Use the install commands and URLs from the script's diagnostic output. Group items under `Tools:`, `Skills:`, and `MCP Servers:` so the user can see which runtime each item targets; omit a group whose items are all installed.

Pre-select all missing tools and skills. For MCP servers, pre-select the `recommended` ones (context7, sequential-thinking) but leave the `optional` ones (playwright, chrome-devtools) **unchecked** by default — they pull heavyweight dependencies (browser binaries, a Chrome install) that many users will not want, so let the user opt in deliberately.

```
The following items are missing. Select which to install:
(Tools and skills are pre-selected; optional MCP servers are not)

Tools:
  [x] agent-browser - Browser automation for testing and screenshots
  [x] gh - GitHub CLI for issues and PRs
  [x] jq - JSON processor
  [x] vhs (charmbracelet/vhs) - Create GIFs from CLI output
  [x] silicon (Aloxaf/silicon) - Generate code screenshots
  [x] ffmpeg - Video processing for feature demos
  [x] ast-grep - Structural code search using AST patterns

Skills:
  [x] ast-grep - Agent skill for structural code search with ast-grep

MCP Servers:
  [x] context7 - Up-to-date library/API documentation lookup
  [x] sequential-thinking - Structured multi-step reasoning
  [ ] playwright - Browser automation (downloads browser binaries)
  [ ] chrome-devtools - Performance and DevTools inspection (requires Chrome)
```

Only show items that are actually missing. Omit installed ones. Omit the MCP Servers group entirely when the diagnostic output had no MCP Servers section (non-Claude harnesses).

**`gh` authentication is not an install.** If `gh` is reported as `gh (not authenticated)`, do not offer a package-manager install command for it — `gh` is already on the machine. Instead, offer to run `gh auth login` (interactive). Because `gh auth login` is an interactive login that the agent cannot complete on the user's behalf, instruct the user to run it themselves (in Claude Code, suggest typing `! gh auth login` so its output lands in the session), then re-run `/tunan:setup` to confirm. Treat this as its own item, separate from the install list.

### Step 7: Install Selected Dependencies

For each selected dependency, in order:

1. **Show the install command** (from the diagnostic output) and ask for approval:

   ```
   Install agent-browser?
   Command: CI=true npm install -g agent-browser --no-audit --no-fund --loglevel=error && agent-browser install && npx skills add https://github.com/vercel-labs/agent-browser --skill agent-browser -g -y

   1. Run this command
   2. Skip - I'll install it manually
   ```

2. **If approved:** Run the install command using a shell execution tool. After the command completes, verify installation:
   - For a CLI tool, run the dependency's check command (e.g., `command -v agent-browser`).
   - For an agent skill, prefer `npx --yes skills list --global --json | jq -r '.[].name' | grep -qx <skill-name>` when `npx` is available; otherwise fall back to checking that `~/.claude/skills/<skill-name>`, `~/.agents/skills/<skill-name>`, or `~/.codex/skills/<skill-name>` exists (file, directory, or symlink).
   - For an MCP server, run `claude mcp get <name>` and treat a successful (zero exit) result as installed. The `claude mcp add ...` commands register the server at user scope by default; a server can take a few seconds to connect on first launch, so a registered-but-not-yet-connected status still counts as installed.

3. **If verification succeeds:** Report success.

4. **If verification fails or install errors:** Display the project URL as fallback and continue to the next dependency.

### Step 8: Summary

Display a brief summary:

```
 ✅ Compound Engineering setup complete

    Installed: agent-browser, gh, jq
    Skipped:   rtk

    Run /tunan:setup anytime to re-check.
```

If this is a Claude Code session (per platform detection in Step 3), append: "Run /tunan:update to grab the latest plugin version."
