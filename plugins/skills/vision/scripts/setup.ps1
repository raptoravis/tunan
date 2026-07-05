# vision skill setup — 跨平台双胞胎(setup.sh / setup.ps1),参数与 stdout 对齐。
#
# 用法:
#   powershell -NoProfile -ExecutionPolicy Bypass -File setup.ps1                  # 依赖 smoke test,不动 CLAUDE.md
#   powershell -NoProfile -ExecutionPolicy Bypass -File setup.ps1 -MergeClaude     # 上述 + 合并 UI 检查流程到 ~/.claude/CLAUDE.md
#   powershell -NoProfile -ExecutionPolicy Bypass -File setup.ps1 -Uninstall       # 仅移除 CLAUDE.md 里合并的段落
#   powershell -NoProfile -ExecutionPolicy Bypass -File setup.ps1 -NoInstall       # 跳过依赖检查
#
# stdout sentinel(与 setup.sh 对齐,脚本/CI 可解析):
#   vision-setup: dep-check | dep-ok | dep-warn | dep-skip
#   vision-setup: merge-ok | merge-skip | merge-removed
#   vision-setup: done

param(
    [switch]$MergeClaude,
    [switch]$Uninstall,
    [switch]$NoInstall
)

$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$HomeDir    = if ($env:VISION_SETUP_HOME) { $env:VISION_SETUP_HOME } else { $HOME }
$FRAG       = Join-Path $SCRIPT_DIR "claude-md-fragment.md"
$MS = "<!-- === TUNAN_VISION_START === -->"
$ME = "<!-- === TUNAN_VISION_END === -->"

# 无 BOM UTF-8 读写(避免 PS5.1 默认 ANSI 误读中文 / Set-Content 加 BOM)
$UTF8 = New-Object System.Text.UTF8Encoding $false

function Read-Text([string]$path) {
    return [System.IO.File]::ReadAllText($path, $UTF8)
}
function Write-Text([string]$path, [string]$content) {
    [System.IO.File]::WriteAllText($path, $content, $UTF8)
}

# ── 依赖 smoke test ────────────────────────────────────────────────
function Invoke-DepCheck {
    if ($NoInstall) { Write-Output "vision-setup: dep-skip"; return }

    $uv = Get-Command uv -ErrorAction SilentlyContinue
    if ($uv) {
        Write-Output "vision-setup: dep-check (uv smoke test)"
        Push-Location $SCRIPT_DIR
        try {
            & uv run vision.py --help 2>$null | Out-Null
            $code = $LASTEXITCODE
        } finally { Pop-Location }
        if ($code -eq 0) {
            Write-Output "vision-setup: dep-ok (uv run auto-installs openai)"
        } else {
            Write-Output "vision-setup: dep-ok (uv present; smoke test non-fatal)"
        }
        return
    }

    Write-Output "vision-setup: dep-warn (uv not on PATH - install: pip install uv / winget install astral-sh.uv)"
}

# ── 从内容里删掉 marker 段(IndexOf/Substring,PS5.1 友好) ──────────
function Remove-Markers([string]$content) {
    $sIdx = $content.IndexOf($MS)
    $eIdx = $content.IndexOf($ME)
    if ($sIdx -ge 0 -and $eIdx -gt $sIdx) {
        $end = $eIdx + $ME.Length
        return $content.Substring(0, $sIdx) + $content.Substring($end)
    }
    return $content
}

# ── 合并 UI 检查流程到 ~/.claude/CLAUDE.md(幂等) ───────────────────
function Invoke-MergeClaude {
    $mc = Join-Path $HomeDir ".claude\CLAUDE.md"
    $dir = Split-Path -Parent $mc
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }

    $frag = (Read-Text $FRAG).TrimEnd()
    $marked = "`n`n$MS`n$frag`n$ME`n"

    if (Test-Path $mc) {
        $existing = Read-Text $mc
        if ($existing.Contains($MS) -and $existing.Contains($ME)) {
            $stripped = Remove-Markers $existing
            Write-Text $mc ($stripped.TrimEnd() + "`n" + $marked)
            Write-Output "vision-setup: merge-ok (replaced existing section)"
        } else {
            Write-Text $mc ($existing.TrimEnd() + "`n" + $marked)
            Write-Output "vision-setup: merge-ok (appended)"
        }
    } else {
        Write-Text $mc $marked
        Write-Output "vision-setup: merge-ok (created CLAUDE.md)"
    }
}

# ── 卸载:移除合并段 ────────────────────────────────────────────────
function Invoke-Uninstall {
    $mc = Join-Path $HomeDir ".claude\CLAUDE.md"
    if ((Test-Path $mc) -and ((Read-Text $mc).Contains($MS))) {
        $stripped = Remove-Markers (Read-Text $mc)
        Write-Text $mc $stripped
        Write-Output "vision-setup: merge-removed"
    } else {
        Write-Output "vision-setup: merge-skip (no section found)"
    }
}

# ── 主流程 ─────────────────────────────────────────────────────────
if ($Uninstall) {
    Invoke-Uninstall
} else {
    Invoke-DepCheck
    if ($MergeClaude) {
        Invoke-MergeClaude
    } else {
        Write-Output "vision-setup: merge-skip (pass -MergeClaude to inject the UI-check flow into ~/.claude/CLAUDE.md)"
    }
}

Write-Output "vision-setup: done"
