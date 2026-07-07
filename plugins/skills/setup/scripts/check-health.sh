#!/usr/bin/env bash
# tunan environment health check
# Outputs a formatted diagnostic report in one pass

set -o pipefail

# =====================================================
#  Dependency config
# =====================================================
# Format: name|tier|install_cmd|url
# Tiers: recommended (flagged if missing), optional (noted if missing)
# To add a dependency: add a line here. No other changes needed.

deps=(
  "agent-browser|recommended|CI=true npm install -g agent-browser --no-audit --no-fund --loglevel=error && agent-browser install && npx skills add https://github.com/vercel-labs/agent-browser --skill agent-browser -g -y|https://github.com/vercel-labs/agent-browser"
  "gh|recommended|NONINTERACTIVE=1 HOMEBREW_NO_AUTO_UPDATE=1 brew install -q gh|https://cli.github.com"
  "jq|recommended|NONINTERACTIVE=1 HOMEBREW_NO_AUTO_UPDATE=1 brew install -q jq|https://jqlang.github.io/jq/"
  "vhs|recommended|NONINTERACTIVE=1 HOMEBREW_NO_AUTO_UPDATE=1 brew install -q vhs|https://github.com/charmbracelet/vhs"
  "silicon|recommended|NONINTERACTIVE=1 HOMEBREW_NO_AUTO_UPDATE=1 brew install -q silicon|https://github.com/Aloxaf/silicon"
  "ffmpeg|recommended|NONINTERACTIVE=1 HOMEBREW_NO_AUTO_UPDATE=1 brew install -q ffmpeg|https://ffmpeg.org/download.html"
  "ast-grep|recommended|NONINTERACTIVE=1 HOMEBREW_NO_AUTO_UPDATE=1 brew install -q ast-grep|https://ast-grep.github.io"
)

# Agent skills installed via the `skills` CLI (vercel-labs/skills).
# Format: name|tier|install_cmd|url
# Presence is resolved via `npx --yes skills list --global --json`
# when npx and jq are available, then by probing known global skill roots.

skills=(
  "ast-grep|recommended|npx skills add ast-grep/agent-skill -g -y|https://github.com/ast-grep/agent-skill"
)

# MCP servers (Claude Code). Presence is resolved via `claude mcp list`.
# context7 and sequential-thinking ship in the plugin's .mcp.json and load
# automatically when the plugin is enabled, so they normally report green.
# The heavier servers (browser/Python/Chrome dependencies) are installed
# on demand via the `claude mcp add` commands below.
# Format: name|tier|install_cmd|url

mcp=(
  "context7|recommended|claude mcp add context7 -- npx -y @upstash/context7-mcp@latest|https://github.com/upstash/context7"
  "sequential-thinking|recommended|claude mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking|https://github.com/modelcontextprotocol/servers/tree/main/src/sequentialthinking"
  "playwright|optional|claude mcp add playwright -- npx @playwright/mcp@latest|https://github.com/microsoft/playwright-mcp"
  "chrome-devtools|optional|claude mcp add chrome-devtools -- npx chrome-devtools-mcp@latest|https://github.com/ChromeDevTools/chrome-devtools-mcp"
)

# =====================================================
#  Args
# =====================================================
# --version VERSION  (optional) plugin version to display (passed by the agent)

plugin_version=""
while [ $# -gt 0 ]; do
  case "$1" in
    --version) [ -n "$2" ] && plugin_version="$2" && shift 2 || shift ;;
    *) shift ;;
  esac
done

# =====================================================
#  Helpers
# =====================================================

ok()      { echo "  🟢  $1"; }
fail()    { echo "  🔴  $1"; }
warn()    { echo "  🟡  $1"; }
skip()    { echo "  ➖  $1"; }
detail()  { echo "       $1"; }
section() { echo ""; echo " $1"; }

has_brew=$(command -v brew >/dev/null 2>&1 && echo "yes" || echo "no")
in_repo=$(git rev-parse --is-inside-work-tree >/dev/null 2>&1 && echo "yes" || echo "no")

# =====================================================
#  Check tools
# =====================================================

cli_ok=0; cli_total=0; issues=0

results=()
for entry in "${deps[@]}"; do
  IFS='|' read -r name tier install_cmd url <<< "$entry"
  cli_total=$((cli_total + 1))
  if command -v "$name" >/dev/null 2>&1; then
    # gh must be installed AND authenticated to be usable. The whole tunan
    # workflow stores requirements/state in GitHub issues, so an unauthenticated
    # gh is as broken as a missing one -- flag it and count it as not-ok.
    if [ "$name" = "gh" ] && ! gh auth status >/dev/null 2>&1; then
      results+=("$name|$tier|unauthenticated|$install_cmd|$url")
    else
      cli_ok=$((cli_ok + 1))
      results+=("$name|$tier|ok|$install_cmd|$url")
    fi
  else
    results+=("$name|$tier|missing|$install_cmd|$url")
  fi
done

# =====================================================
#  Check skills
# =====================================================

has_npx="no"
has_jq="no"
command -v npx >/dev/null 2>&1 && has_npx="yes"
command -v jq >/dev/null 2>&1 && has_jq="yes"

installed_skill_names=""
if [ "$has_npx" = "yes" ] && [ "$has_jq" = "yes" ]; then
  installed_skill_names=$(npx --yes skills list --global --json 2>/dev/null | jq -r '.[].name' 2>/dev/null)
fi

skill_ok=0; skill_total=0
skill_results=()
skill_roots=(
  "$HOME/.claude/skills"
  "$HOME/.agents/skills"
  "$HOME/.codex/skills"
)

skill_exists_on_disk() {
  local name="$1"
  local root

  for root in "${skill_roots[@]}"; do
    if [ -e "$root/$name" ]; then
      return 0
    fi
  done

  return 1
}

for entry in "${skills[@]}"; do
  IFS='|' read -r name tier install_cmd url <<< "$entry"
  skill_total=$((skill_total + 1))

  is_installed="no"
  if [ -n "$installed_skill_names" ]; then
    if printf '%s\n' "$installed_skill_names" | grep -qx "$name"; then
      is_installed="yes"
    fi
  fi

  if [ "$is_installed" = "no" ] && skill_exists_on_disk "$name"; then
    is_installed="yes"
  fi

  if [ "$is_installed" = "yes" ]; then
    skill_ok=$((skill_ok + 1))
    skill_results+=("$name|$tier|ok|$install_cmd|$url")
  else
    skill_results+=("$name|$tier|missing|$install_cmd|$url")
  fi
done

# =====================================================
#  Check MCP servers (Claude Code only)
# =====================================================
# `claude mcp list` enumerates every configured server across plugin, user,
# project, and local scopes. When the `claude` CLI is absent (e.g. Codex or
# other harnesses), the MCP section is skipped entirely -- MCP install on
# those platforms is handled separately by the setup skill.

has_claude="no"
command -v claude >/dev/null 2>&1 && has_claude="yes"

mcp_listing=""
if [ "$has_claude" = "yes" ]; then
  mcp_listing=$(claude mcp list 2>/dev/null)
fi

mcp_ok=0; mcp_total=0
mcp_results=()
for entry in "${mcp[@]}"; do
  IFS='|' read -r name tier install_cmd url <<< "$entry"
  mcp_total=$((mcp_total + 1))
  if [ "$has_claude" = "yes" ] && printf '%s\n' "$mcp_listing" | grep -qE "^${name}[: ]"; then
    mcp_ok=$((mcp_ok + 1))
    mcp_results+=("$name|$tier|ok|$install_cmd|$url")
  else
    mcp_results+=("$name|$tier|missing|$install_cmd|$url")
  fi
done

# =====================================================
#  Project checks (repo only)
# =====================================================

legacy_cfg="skip"
config_issue="skip"

if [ "$in_repo" = "yes" ]; then
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  legacy_cfg="missing"
  [ -f "$repo_root/tunan.local.md" ] && legacy_cfg="present"

  # The config issue is the source of truth. Checking it needs an authenticated
  # gh; when gh is unavailable leave config_issue=skip (offline diagnostic).
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    if [ -n "$(gh issue list --label "tunan:config" --state all --json number --jq '.[0].number // empty' 2>/dev/null)" ]; then
      config_issue="present"
    else
      config_issue="missing"
    fi
  fi
fi

# =====================================================
#  Output
# =====================================================

echo ""
if [ -n "$plugin_version" ]; then
  ok "Plugin version v${plugin_version}"
fi

# --- Tools ---

section "Tools  ${cli_ok}/${cli_total}"

for result in "${results[@]}"; do
  IFS='|' read -r name tier status install_cmd url <<< "$result"
  if [ "$status" = "ok" ]; then
    ok "$name"
  elif [ "$status" = "unauthenticated" ]; then
    warn "$name (not authenticated)"
    issues=$((issues + 1))
    detail "Run: gh auth login"
  else
    warn "$name"
    issues=$((issues + 1))
    case "$install_cmd" in
      *brew\ install*)
        if [ "$has_brew" = "yes" ]; then detail "$install_cmd"
        else detail "$url"; fi ;;
      *)
        detail "$install_cmd"
        detail "$url" ;;
    esac
  fi
done

# --- Skills ---

if [ "${#skills[@]}" -gt 0 ]; then
  section "Skills  ${skill_ok}/${skill_total}"

  for result in "${skill_results[@]}"; do
    IFS='|' read -r name tier status install_cmd url <<< "$result"
    if [ "$status" = "ok" ]; then
      ok "$name"
    else
      warn "$name"
      issues=$((issues + 1))
      detail "$install_cmd"
      detail "$url"
    fi
  done
fi

# --- MCP servers ---

if [ "$has_claude" = "yes" ] && [ "${#mcp[@]}" -gt 0 ]; then
  section "MCP Servers  ${mcp_ok}/${mcp_total}"

  for result in "${mcp_results[@]}"; do
    IFS='|' read -r name tier status install_cmd url <<< "$result"
    if [ "$status" = "ok" ]; then
      ok "$name"
    else
      warn "$name"
      issues=$((issues + 1))
      detail "$install_cmd"
      detail "$url"
    fi
  done
fi

# --- Project ---

if [ "$in_repo" = "yes" ]; then
  has_project_issues="no"

  if [ "$legacy_cfg" = "present" ]; then
    has_project_issues="yes"
  fi
  if [ "$config_issue" = "missing" ]; then
    has_project_issues="yes"
  fi

  if [ "$has_project_issues" = "yes" ]; then
    section "Project"

    if [ "$legacy_cfg" = "present" ]; then
      warn "Outdated tunan config in this repo"
      issues=$((issues + 1))
    fi

    if [ "$config_issue" = "missing" ]; then
      warn "No tunan:config issue yet — run /tunan:setup to create one"
      issues=$((issues + 1))
    fi
  fi
fi

# --- Bottom line ---

echo ""
summary="${cli_ok}/${cli_total} tools  ${skill_ok}/${skill_total} skills"
if [ "$has_claude" = "yes" ]; then
  summary="${summary}  ${mcp_ok}/${mcp_total} mcp"
fi

if [ "$issues" -eq 0 ]; then
  echo " ✅  All clear  ${summary}"
else
  echo " ⚠️   ${issues} issue(s) found  ${summary}"
fi

echo ""
