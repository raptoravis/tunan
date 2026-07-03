#!/usr/bin/env bash
# vision skill setup — 跨平台双胞胎(setup.sh / setup.ps1),参数与 stdout 对齐。
#
# 用法:
#   bash setup.sh                       # 依赖 smoke test,不动 CLAUDE.md
#   bash setup.sh --merge-claude        # 上述 + 把 UI 检查流程合并进 ~/.claude/CLAUDE.md
#   bash setup.sh --uninstall           # 仅移除 CLAUDE.md 里合并的段落
#   bash setup.sh --no-install          # 跳过依赖检查
#
# stdout sentinel(脚本/CI 可解析):
#   vision-setup: dep-check | dep-ok | dep-warn | dep-skip
#   vision-setup: merge-ok | merge-skip | merge-removed
#   vision-setup: done

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${VISION_SETUP_HOME:-$HOME}"
FRAG="$SCRIPT_DIR/claude-md-fragment.md"
MS="<!-- === TUNAN_VISION_START === -->"
ME="<!-- === TUNAN_VISION_END === -->"

DO_MERGE=0
DO_UNINSTALL=0
NO_INSTALL=0

print_help() {
    sed -n '2,12p' "$0"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --merge-claude|-m) DO_MERGE=1 ;;
        --uninstall|-u)    DO_UNINSTALL=1 ;;
        --no-install|-n)   NO_INSTALL=1 ;;
        --help|-h)         print_help; exit 0 ;;
        *) echo "未知参数: $1" >&2; exit 2 ;;
    esac
    shift
done

# ── 依赖 smoke test ────────────────────────────────────────────────
dep_check() {
    if [ "$NO_INSTALL" -eq 1 ]; then
        echo "vision-setup: dep-skip"
        return
    fi
    if command -v uv >/dev/null 2>&1; then
        echo "vision-setup: dep-check (uv smoke test)"
        if uv run "$SCRIPT_DIR/vision.py" --help >/dev/null 2>&1; then
            echo "vision-setup: dep-ok (uv run auto-installs openai)"
        else
            echo "vision-setup: dep-ok (uv present; smoke test non-fatal)"
        fi
    else
        echo "vision-setup: dep-warn (uv not on PATH — install: pip install uv / winget install astral-sh.uv)"
    fi
}

# ── 把 marker 段从文件中删掉(awk 精确行匹配) ──────────────────────
strip_markers() {
    local file="$1"
    awk -v s="$MS" -v e="$ME" '
        $0==s {skip=1; next}
        $0==e {skip=0; next}
        !skip
    ' "$file"
}

# ── 合并 UI 检查流程到 ~/.claude/CLAUDE.md(幂等) ───────────────────
merge_claude() {
    local mc="$HOME_DIR/.claude/CLAUDE.md"
    local frag
    frag="$(cat "$FRAG")"
    # 去掉正文末尾空白,避免 marker 前后多空行
    frag="$(printf '%s' "$frag" | sed -e 's/[[:space:]]*$//')"
    local marked
    marked="$(printf '\n\n%s\n%s\n%s' "$MS" "$frag" "$ME")"

    mkdir -p "$(dirname "$mc")"

    if [ -f "$mc" ]; then
        if grep -qF "$MS" "$mc" && grep -qF "$ME" "$mc"; then
            strip_markers "$mc" > "$mc.tmp"
            printf '%s\n' "$marked" >> "$mc.tmp"
            mv "$mc.tmp" "$mc"
            echo "vision-setup: merge-ok (replaced existing section)"
        else
            printf '%s\n' "$marked" >> "$mc"
            echo "vision-setup: merge-ok (appended)"
        fi
    else
        printf '%s\n' "$marked" > "$mc"
        echo "vision-setup: merge-ok (created CLAUDE.md)"
    fi
}

# ── 卸载:移除合并段 ────────────────────────────────────────────────
uninstall_claude() {
    local mc="$HOME_DIR/.claude/CLAUDE.md"
    if [ -f "$mc" ] && grep -qF "$MS" "$mc"; then
        strip_markers "$mc" > "$mc.tmp" && mv "$mc.tmp" "$mc"
        echo "vision-setup: merge-removed"
    else
        echo "vision-setup: merge-skip (no section found)"
    fi
}

# ── 主流程 ─────────────────────────────────────────────────────────
if [ "$DO_UNINSTALL" -eq 1 ]; then
    uninstall_claude
else
    dep_check
    if [ "$DO_MERGE" -eq 1 ]; then
        merge_claude
    else
        echo "vision-setup: merge-skip (pass --merge-claude to inject the UI-check flow into ~/.claude/CLAUDE.md)"
    fi
fi

echo "vision-setup: done"
