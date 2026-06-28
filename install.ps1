#!/usr/bin/env pwsh
# install.ps1 — Windows-native installer for tunan plugin.
#
# Supports OpenCode, MiMoCode, and ReasoniX.
# Usage:
#   .\install.ps1 -Target opencode    # Install for OpenCode
#   .\install.ps1 -Target mimocode    # Install for MiMoCode
#   .\install.ps1 -Target reasonix    # Install for ReasoniX
#   .\install.ps1 -Target all         # Install for all platforms
#   .\install.ps1 -DryRun             # Preview what would be installed

param(
    [ValidateSet('opencode', 'mimocode', 'reasonix', 'all')]
    [string]$Target = 'opencode',

    [switch]$DryRun,

    [switch]$VerboseOutput
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Colors for output
$Red = "`e[31m"
$Green = "`e[32m"
$Yellow = "`e[33m"
$Blue = "`e[34m"
$NoColor = "`e[0m"

# Get script directory
$ScriptPath = $PSCommandPath
$ScriptDir = Split-Path -Parent $ScriptPath

# Logging functions
function Write-Info    { param([string]$Message) Write-Host "${Blue}[INFO]${NoColor} $Message" }
function Write-Success { param([string]$Message) Write-Host "${Green}[SUCCESS]${NoColor} $Message" }
function Write-Warn    { param([string]$Message) Write-Host "${Yellow}[WARNING]${NoColor} $Message" }
function Write-Err     { param([string]$Message) Write-Host "${Red}[ERROR]${NoColor} $Message" }

# Install for OpenCode
function Install-OpenCode {
    Write-Info "Installing tunan plugin for OpenCode..."

    $OpenCodePluginDir = Join-Path $HOME ".opencode\plugins\tunan"

    if ($DryRun) {
        Write-Info "[DRY RUN] Would create: $OpenCodePluginDir"
        Write-Info "[DRY RUN] Would copy: $ScriptDir\plugins\* -> $OpenCodePluginDir\"
        return
    }

    New-Item -ItemType Directory -Force -Path $OpenCodePluginDir | Out-Null
    Copy-Item -Recurse -Force "$ScriptDir\plugins\*" $OpenCodePluginDir

    Write-Success "tunan plugin installed for OpenCode"
    Write-Info "Restart OpenCode to activate the plugin"
}

# Install for MiMoCode
function Install-MiMoCode {
    Write-Info "Installing tunan plugin for MiMoCode..."

    $MiMoCodePluginDir = Join-Path $HOME ".mimocode\plugins\tunan"

    if ($DryRun) {
        Write-Info "[DRY RUN] Would create: $MiMoCodePluginDir"
        Write-Info "[DRY RUN] Would copy: $ScriptDir\plugins\* -> $MiMoCodePluginDir\"
        return
    }

    New-Item -ItemType Directory -Force -Path $MiMoCodePluginDir | Out-Null
    Copy-Item -Recurse -Force "$ScriptDir\plugins\*" $MiMoCodePluginDir

    Write-Success "tunan plugin installed for MiMoCode"
    Write-Info "Restart MiMoCode to activate the plugin"
}

# Install for ReasoniX
function Install-ReasoniX {
    Write-Info "Installing tunan plugin for ReasoniX..."

    $ReasoniXSkillsDir = Join-Path $HOME ".reasonix\skills"

    if ($DryRun) {
        Write-Info "[DRY RUN] Would create: $ReasoniXSkillsDir"
        Write-Info "[DRY RUN] Would copy: $ScriptDir\plugins\skills\* -> $ReasoniXSkillsDir\"
        return
    }

    New-Item -ItemType Directory -Force -Path $ReasoniXSkillsDir | Out-Null
    Copy-Item -Recurse -Force "$ScriptDir\plugins\skills\*" $ReasoniXSkillsDir

    Write-Success "tunan skills installed for ReasoniX"
    Write-Info "Restart ReasoniX to activate the skills"
}

# Main
Write-Host "${Blue}tunan plugin installer${NoColor}"
Write-Host "===================="
Write-Host ""

switch ($Target) {
    'opencode' { Install-OpenCode }
    'mimocode' { Install-MiMoCode }
    'reasonix' { Install-ReasoniX }
    'all' {
        Install-OpenCode
        Install-MiMoCode
        Install-ReasoniX
    }
}

Write-Host ""
Write-Success "Installation complete!"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Restart your AI coding assistant"
Write-Host "  2. Run /tunan:setup to configure your environment"
Write-Host ""