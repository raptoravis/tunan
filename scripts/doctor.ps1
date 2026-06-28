#!/usr/bin/env pwsh
# doctor.ps1 — Check environment for tunan plugin requirements.
#
# Usage: .\scripts\doctor.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Colors for output
$Red = "`e[31m"
$Green = "`e[32m"
$Yellow = "`e[33m"
$Blue = "`e[34m"
$NoColor = "`e[0m"

# Check results
$ChecksPassed = 0
$ChecksFailed = 0
$ChecksWarning = 0

# Logging functions
function Write-Pass { param([string]$Message) Write-Host "${Green}[PASS]${NoColor} $Message"; $script:ChecksPassed++ }
function Write-Fail { param([string]$Message) Write-Host "${Red}[FAIL]${NoColor} $Message"; $script:ChecksFailed++ }
function Write-Warn { param([string]$Message) Write-Host "${Yellow}[WARN]${NoColor} $Message"; $script:ChecksWarning++ }
function Write-Info { param([string]$Message) Write-Host "${Blue}[INFO]${NoColor} $Message" }

# Check if a command exists
function Check-Command {
    param(
        [string]$Command,
        [string]$Name = $Command
    )
    
    if (Get-Command $Command -ErrorAction SilentlyContinue) {
        Write-Pass "$Name is installed"
        return $true
    } else {
        Write-Fail "$Name is not installed"
        return $false
    }
}

# Check if gh is authenticated
function Check-GhAuth {
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        try {
            gh auth status 2>&1 | Out-Null
            Write-Pass "GitHub CLI is authenticated"
            return $true
        } catch {
            Write-Warn "GitHub CLI is installed but not authenticated"
            return $false
        }
    }
    return $false
}

# Check Node.js version
function Check-NodeVersion {
    if (Get-Command node -ErrorAction SilentlyContinue) {
        $version = (node --version).TrimStart('v')
        $major = [int]($version.Split('.')[0])
        
        if ($major -ge 18) {
            Write-Pass "Node.js version $version (>= 18)"
            return $true
        } else {
            Write-Fail "Node.js version $version (< 18 required)"
            return $false
        }
    }
    return $false
}

# Check if plugin directory exists
function Check-PluginDirs {
    $claudeDir = Join-Path $HOME ".claude\plugins\tunan"
    $codexDir = Join-Path $HOME ".codex\plugins\tunan"
    $opencodeDir = Join-Path $HOME ".opencode\plugins\tunan"
    
    if (Test-Path $claudeDir) {
        Write-Pass "Claude Code plugin directory exists"
    } else {
        Write-Info "Claude Code plugin directory not found (install with -Target claude)"
    }
    
    if (Test-Path $codexDir) {
        Write-Pass "Codex plugin directory exists"
    } else {
        Write-Info "Codex plugin directory not found (install with -Target codex)"
    }
    
    if (Test-Path $opencodeDir) {
        Write-Pass "OpenCode plugin directory exists"
    } else {
        Write-Info "OpenCode plugin directory not found (install with -Target opencode)"
    }
}

# Main function
function Main {
    Write-Host "${Blue}tunan plugin doctor${NoColor}"
    Write-Host "=================="
    Write-Host ""
    
    # Check required commands
    Write-Info "Checking required commands..."
    Check-Command "git" "Git"
    Check-Command "node" "Node.js"
    Check-NodeVersion
    Check-Command "npm" "npm"
    
    # Check optional commands
    Write-Info "Checking optional commands..."
    Check-Command "gh" "GitHub CLI"
    Check-GhAuth
    
    # Check plugin directories
    Write-Info "Checking plugin directories..."
    Check-PluginDirs
    
    # Summary
    Write-Host ""
    Write-Host "=================="
    Write-Host "${Blue}Summary${NoColor}"
    Write-Host "=================="
    Write-Host ""
    Write-Host "${Green}Passed: $ChecksPassed${NoColor}"
    Write-Host "${Yellow}Warnings: $ChecksWarning${NoColor}"
    Write-Host "${Red}Failed: $ChecksFailed${NoColor}"
    Write-Host ""
    
    if ($ChecksFailed -eq 0) {
        Write-Host "${Green}All checks passed!${NoColor}"
        return 0
    } else {
        Write-Host "${Red}Some checks failed. Please fix the issues above.${NoColor}"
        return 1
    }
}

# Run main function
Main