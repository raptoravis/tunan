#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: ./install.sh [--claude] [--codex] [--opencode] [--cursor] [--reasonix] [--all] [--force]

Installs tunan for AI coding agents using each platform's native install mechanism:
  Claude Code / Codex / OpenCode → native plugin commands
  Cursor / Reasonix              → file copy (no plugin marketplace)

Targets:
  --claude   Install via: claude plugin marketplace add raptoravis/tunan && claude plugin install tunan@tunan
  --codex    Install via: codex plugin marketplace add raptoravis/tunan && codex plugin add tunan@tunan
  --opencode Install via: opencode plugin -g tunan@git+https://github.com/raptoravis/tunan.git
  --cursor   Install Cursor rules globally into ${CURSOR_RULES_DIR:-$HOME/.cursor}/rules
  --reasonix Install skills into ${REASONIX_SKILLS_DIR:-$HOME/.reasonix}/skills
  --all      Install for all five platforms

Options:
  --force   Force a fresh install (uninstall first) instead of updating in place.
USAGE
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_dir="$script_dir/plugins/skills"
rules_source_dir="$script_dir/plugins/.cursor-plugin/rules"
claude="false"
codex="false"
opencode="false"
cursor="false"
reasonix="false"
force="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --codex)    codex="true"; shift ;;
    --claude)   claude="true"; shift ;;
    --opencode) opencode="true"; shift ;;
    --cursor)   cursor="true"; shift ;;
    --reasonix) reasonix="true"; shift ;;
    --all)
      codex="true"
      claude="true"
      opencode="true"
      cursor="true"
      reasonix="true"
      shift
      ;;
    --force)    force="true"; shift ;;
    -h|--help)  usage; exit 0 ;;
    *)          usage; exit 1 ;;
  esac
done

if [[ "$codex" != "true" && "$claude" != "true" && "$opencode" != "true" && "$cursor" != "true" && "$reasonix" != "true" ]]; then
  usage
  exit 1
fi

# ── Claude Code ──
if [[ "$claude" == "true" ]]; then
  echo "Installing tunan for Claude Code (native plugin)…"
  if command -v claude >/dev/null 2>&1; then
    claude plugin marketplace add raptoravis/tunan 2>/dev/null || true
    if [[ "$force" == "true" ]]; then
      echo "Force: reinstalling from scratch…"
      claude plugin uninstall tunan@tunan 2>/dev/null || true
      claude plugin install tunan@tunan
    elif claude plugin update tunan@tunan 2>/dev/null; then
      echo "Updated tunan to latest."
    else
      echo "Not yet installed — installing…"
      claude plugin install tunan@tunan
    fi
    echo "Claude Code: done. Restart Claude Code, then run /tunan:setup."
  else
    echo "Claude Code CLI not found. Install it first, then run:"
    echo "  claude plugin marketplace add raptoravis/tunan"
    echo "  claude plugin install tunan@tunan"
  fi
fi

# ── Codex ──
if [[ "$codex" == "true" ]]; then
  echo "Installing tunan for Codex (native plugin)…"
  if command -v codex >/dev/null 2>&1; then
    codex plugin marketplace add raptoravis/tunan 2>/dev/null || true
    if [[ "$force" == "true" ]]; then
      echo "Force: reinstalling from scratch…"
      codex plugin remove tunan@tunan 2>/dev/null || true
      codex plugin add tunan@tunan
    elif codex plugin update tunan@tunan 2>/dev/null; then
      echo "Updated tunan to latest."
    else
      echo "Not yet installed — installing…"
      codex plugin add tunan@tunan
    fi
    echo "Codex: done. Restart Codex, then run /tunan:setup."
  else
    echo "Codex CLI not found. Install it first, then run:"
    echo "  codex plugin marketplace add raptoravis/tunan"
    echo "  codex plugin add tunan@tunan"
  fi
fi

# ── OpenCode ──
if [[ "$opencode" == "true" ]]; then
  echo "Installing tunan for OpenCode (native plugin)…"
  if command -v opencode >/dev/null 2>&1; then
    plugin_spec="tunan@git+https://github.com/raptoravis/tunan.git"
    if [[ "$force" == "true" ]]; then
      echo "Force: reinstalling from scratch…"
      opencode plugin -g "$plugin_spec" --force
    else
      opencode plugin -g "$plugin_spec"
    fi
    echo "OpenCode: done. Restart OpenCode, then run /tunan:setup."
  else
    echo "OpenCode CLI not found. Install it first, then run:"
    echo "  opencode plugin -g tunan@git+https://github.com/raptoravis/tunan.git"
  fi
fi

# ── Cursor (file copy) ──
if [[ "$cursor" == "true" ]]; then
  if [[ ! -d "$rules_source_dir" ]]; then
    echo "Source rules directory not found: $rules_source_dir" >&2
    exit 1
  fi

  target="${CURSOR_RULES_DIR:-$HOME/.cursor}/rules"
  echo "Installing tunan Cursor rules -> $target"

  mkdir -p "$target"

  count=0
  updated=0
  for rule in "$rules_source_dir"/*.mdc; do
    [[ -f "$rule" ]] || continue
    rule_name="$(basename "$rule")"
    dest="$target/$rule_name"
    if [[ -e "$dest" ]]; then
      updated=$((updated + 1))
    else
      echo "  Installing $rule_name"
    fi
    cp "$rule" "$dest"
    count=$((count + 1))
  done

  echo "Installed $count Cursor rule(s) -> $target (${updated} updated, $((count - updated)) new)"
  echo "Cursor: done. Restart Cursor to load them, then run /tunan:setup."
fi

# ── Reasonix (file copy) ──
if [[ "$reasonix" == "true" ]]; then
  if [[ ! -d "$source_dir" ]]; then
    echo "Source skills directory not found: $source_dir" >&2
    exit 1
  fi

  target="${REASONIX_SKILLS_DIR:-$HOME/.reasonix}/skills"
  manifest="$target/.tunan-skills-managed"
  source_names=" "

  mkdir -p "$target"
  echo "Installing tunan skills for Reasonix -> $target"

  copy_skill() {
    if command -v rsync >/dev/null 2>&1; then
      rsync -a --exclude '.DS_Store' --exclude '__pycache__/' --exclude 'node_modules/' \
        --exclude 'dist/' --exclude 'artifacts/' --exclude 'test-results/' \
        --exclude 'playwright-report/' --exclude 'coverage/' "$1"/ "$2"/
    else
      cp -R "$1"/. "$2"/
      find "$2" \( -name '.DS_Store' -o -name '__pycache__' -o -name 'node_modules' \
        -o -name 'dist' -o -name 'artifacts' -o -name 'test-results' \
        -o -name 'playwright-report' -o -name 'coverage' \) -prune -exec rm -rf {} +
    fi
  }

  count=0
  updated=0
  for skill in "$source_dir"/*; do
    [[ -d "$skill" && -f "$skill/SKILL.md" ]] || continue
    skill_name="$(basename "$skill")"
    source_names="$source_names$skill_name "
    dest="$target/$skill_name"
    if [[ -d "$dest" ]]; then
      updated=$((updated + 1))
    else
      echo "  Installing $skill_name"
    fi
    rm -rf "$dest"
    mkdir -p "$dest"
    copy_skill "$skill" "$dest"
    count=$((count + 1))
  done
  echo "Installed $count skills -> $target (${updated} updated, $((count - updated)) new)"

  for skill in "$source_dir"/*; do
    [[ -d "$skill" && -f "$skill/SKILL.md" ]] || continue
    basename "$skill"
  done | sort > "$manifest"

  echo "Reasonix: done. Restart Reasonix, then run /tunan:setup."
fi
