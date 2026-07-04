<#
.SYNOPSIS
Installs tunan skills into local agent skill directories.

.DESCRIPTION
Copies skills from .\skills into agent skill directories for Codex, Claude Code,
OpenCode, Reasonix, or .agents.

.PARAMETER Codex
Install into $env:CODEX_HOME\skills (defaults to $HOME\.codex\skills)

.PARAMETER Claude
Install into $env:CLAUDE_SKILLS_DIR (defaults to $HOME\.claude\skills)

.PARAMETER OpenCode
Install into $env:OPENCODE_SKILLS_DIR (defaults to $HOME\.config\opencode\skills)

.PARAMETER Reasonix
Install into $env:REASONIX_SKILLS_DIR (defaults to $HOME\.reasonix\skills)

.PARAMETER Agents
Install into $env:AGENTS_SKILLS_DIR (defaults to $HOME\.agents\skills)

.PARAMETER All
Install into Codex, Claude, OpenCode, and Reasonix

.PARAMETER Force
Replace same-named skills in the target directory

.PARAMETER PruneManaged
Remove stale skills recorded in this repo's managed manifest

.EXAMPLE
.\install.ps1 -Codex
.\install.ps1 -Claude
.\install.ps1 -Reasonix
.\install.ps1 -All -Force
#>

[CmdletBinding()]
param(
    [switch]$Codex,
    [switch]$Claude,
    [switch]$OpenCode,
    [switch]$Reasonix,
    [switch]$Agents,
    [switch]$All,
    [switch]$Force,
    [switch]$PruneManaged
)

$ErrorActionPreference = "Stop"

if ($All) {
    $Codex = $true
    $Claude = $true
    $OpenCode = $true
    $Reasonix = $true
}

if (-not ($Codex -or $Claude -or $OpenCode -or $Reasonix -or $Agents)) {
    Write-Host "Usage: .\install.ps1 [-Codex] [-Claude] [-OpenCode] [-Reasonix] [-Agents] [-All] [-Force] [-PruneManaged]"
    Write-Host ""
    Write-Host "Targets:"
    Write-Host "  -Codex     Install into Codex skills directory"
    Write-Host "  -Claude    Install into Claude Code skills directory"
    Write-Host "  -OpenCode  Install into OpenCode skills directory"
    Write-Host "  -Reasonix  Install into Reasonix skills directory"
    Write-Host "  -Agents    Install into .agents skills directory"
    Write-Host "  -All       Install into Codex, Claude, OpenCode, and Reasonix"
    exit 1
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceDir = Join-Path $scriptDir "skills"

if (-not (Test-Path $sourceDir)) {
    Write-Error "Source skills directory not found: $sourceDir"
    exit 1
}

function Copy-Skill {
    param([string]$Source, [string]$Dest)

    New-Item -ItemType Directory -Path $Dest -Force | Out-Null

    $excludeDirs = @('.DS_Store', '__pycache__', 'node_modules', 'dist', 'artifacts', 'test-results', 'playwright-report', 'coverage')

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
            if ($parentName -notin $excludeDirs -and
                $parentDir -notmatch '(\\|/)__(?:pycache|init)__') {
                Copy-Item -Path $_.FullName -Destination $destPath -Force
            }
        }
    }
}

function Install-Skills {
    param([string]$Target, [string]$Label)

    $manifest = Join-Path $Target ".tunan-skills-managed"
    $sourceNames = " "

    New-Item -ItemType Directory -Path $Target -Force | Out-Null
    Write-Host "Installing tunan skills for $Label -> $Target"

    Get-ChildItem -Path $sourceDir -Directory | ForEach-Object {
        $skillDir = $_.FullName
        $skillFile = Join-Path $skillDir "SKILL.md"
        if (-not (Test-Path $skillFile)) { return }

        $skillName = $_.Name
        $sourceNames = "$sourceNames$skillName "
        $dest = Join-Path $Target $skillName

        if ((Test-Path $dest) -and (-not $Force)) {
            Write-Host "Skipping existing skill: $dest"
            return
        }

        Remove-Item -Recurse -Force $dest -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
        Copy-Skill -Source $skillDir -Dest $dest
        Write-Host "Installed $skillName -> $dest"
    }

    if ($PruneManaged -and (Test-Path $manifest)) {
        Get-Content $manifest | ForEach-Object {
            $installedName = $_.Trim()
            if ([string]::IsNullOrEmpty($installedName)) { return }
            if ($sourceNames -notmatch " $installedName ") {
                $stalePath = Join-Path $Target $installedName
                if (Test-Path $stalePath) {
                    Remove-Item -Recurse -Force $stalePath
                    Write-Host "Pruned stale managed skill: $stalePath"
                }
            }
        }
    }

    Get-ChildItem -Path $sourceDir -Directory | ForEach-Object {
        $skillFile = Join-Path $_.FullName "SKILL.md"
        if (Test-Path $skillFile) { $_.Name }
    } | Sort-Object | Set-Content $manifest
}

$homeDir = $env:USERPROFILE
if (-not $homeDir) { $homeDir = $env:HOME }

if ($Codex) {
    $codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $homeDir ".codex" }
    Install-Skills -Target (Join-Path $codexHome "skills") -Label "Codex"
}

if ($Claude) {
    $claudeDir = if ($env:CLAUDE_SKILLS_DIR) { $env:CLAUDE_SKILLS_DIR } else { Join-Path $homeDir ".claude\skills" }
    Install-Skills -Target $claudeDir -Label "Claude"
}

if ($OpenCode) {
    $opencodeDir = if ($env:OPENCODE_SKILLS_DIR) { $env:OPENCODE_SKILLS_DIR } else { Join-Path $homeDir ".config\opencode\skills" }
    Install-Skills -Target $opencodeDir -Label "OpenCode"
}

if ($Reasonix) {
    $reasonixDir = if ($env:REASONIX_SKILLS_DIR) { $env:REASONIX_SKILLS_DIR } else { Join-Path $homeDir ".reasonix\skills" }
    Install-Skills -Target $reasonixDir -Label "Reasonix"
}

if ($Agents) {
    Write-Warning "--Agents can duplicate skills in Codex if Codex also reads ~/.agents/skills."
    $agentsDir = if ($env:AGENTS_SKILLS_DIR) { $env:AGENTS_SKILLS_DIR } else { Join-Path $homeDir ".agents\skills" }
    Install-Skills -Target $agentsDir -Label ".agents"
}