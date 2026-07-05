#!/usr/bin/env bash
# Fix Reasonix sandbox + yolo mode:
#   1. Disable bash sandbox (enforce → off)
#   2. Set permissions mode to yolo (ask → allow)
set -euo pipefail

# Resolve config path: Windows (Git Bash / WSL) vs Unix
if [[ "${OS:-}" == "Windows_NT" || -n "${APPDATA:-}" ]]; then
    CONFIG="${APPDATA}/reasonix/config.toml"
else
    CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/reasonix/config.toml"
fi

if [[ ! -f "$CONFIG" ]]; then
    echo "ERROR: config.toml not found at $CONFIG"
    exit 1
fi

echo "Target: $CONFIG"
echo ""

changes=0

# Check what needs changing
grep -q 'bash.*"enforce"' "$CONFIG" && need_bash=1 || need_bash=0
grep -q 'mode\s*=\s*"ask"' <(sed -n '/^\[permissions\]/,/^\[/p' "$CONFIG") && need_perm=1 || need_perm=0

if [[ $need_bash -eq 0 && $need_perm -eq 0 ]]; then
    echo "No changes needed — config is already set correctly."
    exit 0
fi

# Backup
cp "$CONFIG" "${CONFIG}.bak"
echo "Backup: ${CONFIG}.bak"

# 1. Disable bash sandbox
if [[ $need_bash -eq 1 ]]; then
    sed -i.bak2 -E 's/(bash\s*=\s*)"enforce"/\1"off"/' "$CONFIG"
    rm -f "${CONFIG}.bak2"
    echo '  [sandbox] bash = "off"  (was "enforce")'
    ((changes++))
else
    echo "  bash: already not 'enforce', skipping."
fi

# 2. Set permissions mode to allow (yolo) — only in [permissions] section
if [[ $need_perm -eq 1 ]]; then
    sed -i.bak2 -E '/^\[permissions\]/,/^\[/ s/(mode\s*=\s*)"ask"/\1"allow"/' "$CONFIG"
    rm -f "${CONFIG}.bak2"
    echo '  [permissions] mode = "allow"  (was "ask")'
    ((changes++))
else
    echo "  permissions mode: already not 'ask', skipping."
fi

echo ""
echo "SUCCESS — $changes change(s) applied."
echo ""
echo "NOTE: Reasonix CLI does not support a config key for default YOLO mode."
echo "To start CLI in YOLO mode, use:  reasonix --yolo"
echo "Or add to your shell profile:     alias reasonix='reasonix --yolo'"
