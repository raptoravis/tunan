<#
.SYNOPSIS
Installs tunan for AI coding agents using each platform's native install mechanism.

.DESCRIPTION
Claude Code / Codex / OpenCode → native plugin commands
Cursor / Reasonix              → file copy (no plugin marketplace)

.PARAMETER Claude
Install via: claude plugin marketplace add raptoravis/tunan && claude plugin install tunan@tunan

.PARAMETER Codex
Install via: codex plugin marketplace add raptoravis/tunan && codex plugin add tunan@tunan

.PARAMETER OpenCode
Install via: opencode plugin -g tunan@git+https://github.com/raptoravis/tunan.git

.PARAMETER Cursor
Install Cursor rules globally into $env:CURSOR_RULES_DIR (defaults to $HOME\.cursor\rules)

.PARAMETER Reasonix
Install skills into $env:REASONIX_SKILLS_DIR (defaults to $HOME\.reasonix\skills)

.PARAMETER All
Install for all five platforms

.PARAMETER Force
For Cursor/Reasonix: replace same-named files. For plugin commands: update/reinstall.

.EXAMPLE
.\install.ps1 -Claude
.\install.ps1 -Codex
.\install.ps1 -Cursor
.\install.ps1 -Reasonix
.\install.ps1 -All -Force
#>

[CmdletBinding()]
param(
    [switch]$Claude,
    [switch]$Codex,
    [switch]$OpenCode,
    [switch]$Cursor,
    [switch]$Reasonix,
    [switch]$All,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

if ($All) {
    $Claude = $true
    $Codex = $true
    $OpenCode = $true
    $Cursor = $true
    $Reasonix = $true
}

if (-not ($Claude -or $Codex -or $OpenCode -or $Cursor -or $Reasonix)) {
    Write-Host "Usage: .\install.ps1 [-Claude] [-Codex] [-OpenCode] [-Cursor] [-Reasonix] [-All] [-Force]"
    Write-Host ""
    Write-Host "Targets:"
    Write-Host "  -Claude    Install via Claude Code native plugin"
    Write-Host "  -Codex     Install via Codex native plugin"
    Write-Host "  -OpenCode  Install via OpenCode native plugin"
    Write-Host "  -Cursor    Install Cursor rules into .cursor\rules\"
    Write-Host "  -Reasonix  Install skills into Reasonix directory"
    Write-Host "  -All       Install for all five platforms"
    exit 1
}

$homeDir = $env:USERPROFILE
if (-not $homeDir) { $homeDir = $env:HOME }

# ── Claude Code ──
if ($Claude) {
    Write-Host "Installing tunan for Claude Code (native plugin)..."
    $claudePath = Get-Command claude -ErrorAction SilentlyContinue
    if ($claudePath) {
        claude plugin marketplace add raptoravis/tunan 2>$null
        if ($Force) {
            Write-Host "Force: reinstalling from scratch..."
            claude plugin uninstall tunan@tunan 2>$null
            claude plugin install tunan@tunan
        } else {
            claude plugin update tunan@tunan 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Updated tunan to latest."
            } else {
                Write-Host "Not yet installed - installing..."
                claude plugin install tunan@tunan
            }
        }
        Write-Host "Claude Code: done. Restart Claude Code, then run /tunan:setup."
    } else {
        Write-Host "Claude Code CLI not found. Install it first, then run:"
        Write-Host "  claude plugin marketplace add raptoravis/tunan"
        Write-Host "  claude plugin install tunan@tunan"
    }
}

# ── Codex ──
if ($Codex) {
    Write-Host "Installing tunan for Codex (native plugin)..."
    $codexPath = Get-Command codex -ErrorAction SilentlyContinue
    if ($codexPath) {
        codex plugin marketplace add raptoravis/tunan 2>$null
        if ($Force) {
            Write-Host "Force: reinstalling from scratch..."
            codex plugin remove tunan@tunan 2>$null
            codex plugin add tunan@tunan
        } else {
            codex plugin update tunan@tunan 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Updated tunan to latest."
            } else {
                Write-Host "Not yet installed - installing..."
                codex plugin add tunan@tunan
            }
        }
        Write-Host "Codex: done. Restart Codex, then run /tunan:setup."
    } else {
        Write-Host "Codex CLI not found. Install it first, then run:"
        Write-Host "  codex plugin marketplace add raptoravis/tunan"
        Write-Host "  codex plugin add tunan@tunan"
    }
}

# ── OpenCode ──
if ($OpenCode) {
    Write-Host "Installing tunan for OpenCode (native plugin)..."
    $opencodePath = Get-Command opencode -ErrorAction SilentlyContinue
    if ($opencodePath) {
        $pluginSpec = "tunan@git+https://github.com/raptoravis/tunan.git"
        if ($Force) {
            Write-Host "Force: reinstalling from scratch..."
            opencode plugin -g $pluginSpec --force
        } else {
            opencode plugin -g $pluginSpec
        }
        Write-Host "OpenCode: done. Restart OpenCode, then run /tunan:setup."
    } else {
        Write-Host "OpenCode CLI not found. Install it first, then run:"
        Write-Host "  opencode plugin -g tunan@git+https://github.com/raptoravis/tunan.git"
    }
}

# ── Cursor (file copy) ──
if ($Cursor) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $rulesSourceDir = Join-Path $scriptDir "plugins\.cursor-plugin\rules"

    if (-not (Test-Path $rulesSourceDir)) {
        Write-Error "Source rules directory not found: $rulesSourceDir"
        exit 1
    }

    $target = if ($env:CURSOR_RULES_DIR) { $env:CURSOR_RULES_DIR } else { Join-Path $homeDir ".cursor\rules" }
    Write-Host "Installing tunan Cursor rules -> $target"

    New-Item -ItemType Directory -Path $target -Force | Out-Null

    $count = 0
    $updated = 0
    Get-ChildItem -Path $rulesSourceDir -Filter "*.mdc" | ForEach-Object {
        $ruleName = $_.Name
        $dest = Join-Path $target $ruleName
        if (Test-Path $dest) {
            Write-Host "  Updating $ruleName"
            $updated++
        } else {
            Write-Host "  Installing $ruleName"
        }
        Copy-Item -Path $_.FullName -Destination $dest -Force
        $count++
    }

    Write-Host "Installed $count Cursor rule(s) -> $target ($updated updated, $($count - $updated) new)"
    Write-Host "Cursor: done. Restart Cursor to load them, then run /tunan:setup."
}

# ── Reasonix (file copy) ──
if ($Reasonix) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $sourceDir = Join-Path $scriptDir "plugins\skills"

    if (-not (Test-Path $sourceDir)) {
        Write-Error "Source skills directory not found: $sourceDir"
        exit 1
    }

    $target = if ($env:REASONIX_SKILLS_DIR) { Join-Path $env:REASONIX_SKILLS_DIR "skills" } else { Join-Path $homeDir ".reasonix\skills" }
    $manifest = Join-Path $target ".tunan-skills-managed"
    $sourceNames = " "

    New-Item -ItemType Directory -Path $target -Force | Out-Null
    Write-Host "Installing tunan skills for Reasonix -> $target"

    $excludeDirs = @('.DS_Store', '__pycache__', 'node_modules', 'dist', 'artifacts', 'test-results', 'playwright-report', 'coverage')

    function Copy-Skill {
        param([string]$Source, [string]$Dest)
        New-Item -ItemType Directory -Path $Dest -Force | Out-Null
        Get-ChildItem -Path $Source -Recurse | ForEach-Object {
            $relativePath = $_.FullName.Substring($Source.Length).TrimStart('\', '/')
            $destPath = Join-Path $Dest $relativePath
            if ($_.PSIsContainer) {
                $dirName = Split-Path $_.FullName -Leaf
                if ($dirName -notin $excludeDirs) {
                    New-Item -ItemType Directory -Path $destPath -Force | Out-Null
                }
            } else {
                $parentDir = Split-Path $_.FullName -Parent
                $parentName = Split-Path $parentDir -Leaf
                if ($parentName -notin $excludeDirs -and $parentDir -notmatch '(\|/)__(?:pycache|init)__') {
                    Copy-Item -Path $_.FullName -Destination $destPath -Force
                }
            }
        }
    }

    $count = 0
    $updated = 0
    Get-ChildItem -Path $sourceDir -Directory | ForEach-Object {
        $skillDir = $_.FullName
        $skillFile = Join-Path $skillDir "SKILL.md"
        if (-not (Test-Path $skillFile)) { return }
        $skillName = $_.Name
        $sourceNames = "$sourceNames$skillName "
        $dest = Join-Path $target $skillName
        if (Test-Path $dest) {
            Write-Host "  Updating $skillName"
            $updated++
        } else {
            Write-Host "  Installing $skillName"
        }
        Remove-Item -Recurse -Force $dest -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
        Copy-Skill -Source $skillDir -Dest $dest
        $count++
    }
    Write-Host "Installed $count skills -> $target ($updated updated, $($count - $updated) new)"

    Get-ChildItem -Path $sourceDir -Directory | ForEach-Object {
        $skillFile = Join-Path $_.FullName "SKILL.md"
        if (Test-Path $skillFile) { $_.Name }
    } | Sort-Object | Set-Content $manifest

    Write-Host "Reasonix: done. Restart Reasonix, then run /tunan:setup."
}
