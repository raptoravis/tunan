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
    Write-Info "Installing tunan for OpenCode..."

    $OpenCodeConfigDir = Join-Path $HOME ".config\opencode"
    $OpenCodeSkillsDir = Join-Path $OpenCodeConfigDir "skills"
    $OpenCodeAgentsDir = Join-Path $OpenCodeConfigDir "agents"
    $OpenCodeConfigFile = Join-Path $OpenCodeConfigDir "opencode.json"

    if ($DryRun) {
        Write-Info "[DRY RUN] Would install skills -> $OpenCodeSkillsDir"
        Write-Info "[DRY RUN] Would install agents -> $OpenCodeAgentsDir"
        Write-Info "[DRY RUN] Would update $OpenCodeConfigFile (MCP merge, skills path, remove wrong plugin)"
        return
    }

    $null = New-Item -ItemType Directory -Force -Path $OpenCodeConfigDir

    # Find Python for the conversion script
    $python = $null
    if (Get-Command 'python3' -ErrorAction SilentlyContinue) { $python = 'python3' }
    elseif (Get-Command 'python' -ErrorAction SilentlyContinue) { $python = 'python' }
    elseif (Get-Command 'py' -ErrorAction SilentlyContinue) {
        $v = & py -3 --version 2>$null
        if ($LASTEXITCODE -eq 0) { $python = 'py -3' }
    }

    $convScript = Join-Path $ScriptDir "plugins\scripts\convert-agents.py"

    # --- 1. Install skills (with tunan- prefix) ---
    # OpenCode has no plugin namespace, so skills get a tunan- prefix
    $skillsSrc = Join-Path $ScriptDir "plugins\skills"
    if ((Test-Path $skillsSrc) -and ($python)) {
        if (Test-Path $OpenCodeSkillsDir) { Remove-Item -Recurse -Force $OpenCodeSkillsDir }
        $null = New-Item -ItemType Directory -Force -Path $OpenCodeSkillsDir
        & $python "$convScript" "skills" "$skillsSrc" "$OpenCodeSkillsDir" 2>$null
        $count = @(Get-ChildItem $OpenCodeSkillsDir -Directory).Count
        Write-Success "tunan skills installed at $OpenCodeSkillsDir ($count skills, prefixed with tunan-)"
    } elseif (Test-Path $skillsSrc) {
        Write-Warn "Python not found — installing skills without tunan- prefix"
        $null = New-Item -ItemType Directory -Force -Path $OpenCodeSkillsDir
        Get-ChildItem "$skillsSrc\*" -Directory | ForEach-Object {
            $target = Join-Path $OpenCodeSkillsDir $_.Name
            if (Test-Path $target) { Remove-Item -Recurse -Force $target }
            Copy-Item -Recurse $_.FullName "$target"
        }
        Write-Success "tunan skills installed at $OpenCodeSkillsDir (no prefix — may conflict with other skills)"
    }

    # --- 2. Install agents (with format conversion + tunan- prefix) ---
    $agentsSrc = Join-Path $ScriptDir "plugins\agents"
    if ((Test-Path $agentsSrc) -and ($python)) {
        if (Test-Path $OpenCodeAgentsDir) { Remove-Item -Recurse -Force $OpenCodeAgentsDir }
        $null = New-Item -ItemType Directory -Force -Path $OpenCodeAgentsDir
        & $python "$convScript" "agents" "$agentsSrc" "$OpenCodeAgentsDir" 2>$null
        $count = @(Get-ChildItem "$OpenCodeAgentsDir\*.md").Count
        Write-Success "tunan agents installed at $OpenCodeAgentsDir ($count agents, format converted for OpenCode)"
    } elseif (Test-Path $agentsSrc) {
        Write-Warn "Python not found — copying agents without format conversion"
        if (Test-Path $OpenCodeAgentsDir) { Remove-Item -Recurse -Force $OpenCodeAgentsDir }
        $null = New-Item -ItemType Directory -Force -Path $OpenCodeAgentsDir
        Get-ChildItem "$agentsSrc\*.md" | ForEach-Object {
            Copy-Item -Force $_.FullName (Join-Path $OpenCodeAgentsDir $_.Name)
        }
    }

    # --- 3. Merge MCP servers from tunan's .mcp.json into OpenCode config ---
    # OpenCode MCP format: {"mcp": {"name": {"type": "local", "command": [...], "enabled": true}}}
    # Only adds servers not already present in the config; never overwrites existing.
    # For codegraph, prefers local binary (codegraph serve --mcp) over npx.
    $mcpSrc = Join-Path $ScriptDir "plugins\.mcp.json"
    $mcpEntriesToAdd = @{}
    if (Test-Path $mcpSrc) {
        try {
            $mcpData = Get-Content $mcpSrc -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($mcpData.PSObject.Properties.Name -contains 'mcpServers') {
                foreach ($prop in $mcpData.mcpServers.PSObject.Properties) {
                    $name = $prop.Name
                    $entry = $prop.Value
                    $cmdArray = @($entry.command)
                    if ($entry.PSObject.Properties.Name -contains 'args' -and $null -ne $entry.args) {
                        $cmdArray += @($entry.args)
                    }
                    # For codegraph, prefer local binary over npx
                    if ($name -eq 'codegraph' -and (Get-Command 'codegraph' -ErrorAction SilentlyContinue)) {
                        $cmdArray = @('codegraph', 'serve', '--mcp')
                    }
                    $mcpEntriesToAdd[$name] = @{
                        type    = 'local'
                        command = @($cmdArray)
                        enabled = $true
                    }
                }
            }
        } catch {
            Write-Warn "Could not parse .mcp.json"
        }
    }

    # --- 4. Write/update global OpenCode config ---
    $config = $null
    if (Test-Path $OpenCodeConfigFile) {
        try {
            $content = Get-Content $OpenCodeConfigFile -Raw -Encoding UTF8
            $config = $content | ConvertFrom-Json
        } catch {
            $config = $null
        }
    }

    if ($null -eq $config) {
        $config = [PSCustomObject]@{
            '$schema' = 'https://opencode.ai/config.json'
        }
    }

    # Remove incorrect "plugin": ["plugins/tunan"] entry
    if ($config.PSObject.Properties.Name -contains 'plugin') {
        $plugins = @($config.plugin)
        $filtered = @($plugins | Where-Object { $_ -ne 'plugins/tunan' })
        if ($filtered.Length -eq 0) {
            $config.PSObject.Properties.Remove('plugin')
            Write-Info "Removed incorrect 'plugin' entry from config"
        } elseif ($filtered.Length -ne $plugins.Length) {
            $config | Add-Member -MemberType NoteProperty -Name 'plugin' -Value $filtered -Force
            Write-Info "Removed 'plugins/tunan' from plugin array"
        }
    }

    # Merge MCP servers (only add non-existing; never overwrite)
    if ($mcpEntriesToAdd.Keys.Count -gt 0) {
        # Gather existing MCP names
        $existingMcpNames = @()
        if ($config.PSObject.Properties.Name -contains 'mcp' -and $null -ne $config.mcp) {
            $mcpObj = $config.mcp
            $props = if ($mcpObj -is [PSCustomObject]) { $mcpObj.PSObject.Properties } else { @() }
            foreach ($p in $props) { $existingMcpNames += $p.Name }
        }

        $addedNames = @()
        $merged = @{}
        # Seed merged with existing entries
        if ($config.PSObject.Properties.Name -contains 'mcp' -and $null -ne $config.mcp) {
            $mcpObj = $config.mcp
            if ($mcpObj -is [PSCustomObject]) {
                foreach ($p in $mcpObj.PSObject.Properties) { $merged[$p.Name] = $p.Value }
            }
        }
        # Add new entries
        foreach ($k in $mcpEntriesToAdd.Keys) {
            if ($existingMcpNames -notcontains $k) {
                $merged[$k] = $mcpEntriesToAdd[$k]
                $addedNames += $k
            }
        }
        if ($addedNames.Count -gt 0) {
            $mergedObj = [PSCustomObject]$merged
            $config | Add-Member -MemberType NoteProperty -Name 'mcp' -Value $mergedObj -Force
            Write-Success "MCP servers added: $($addedNames -join ', ')"
        }
    }

    # Ensure skills path is registered in config
    if (-not ($config.PSObject.Properties.Name -contains 'skills')) {
        $skillsCfg = [PSCustomObject]@{
            paths = @($OpenCodeSkillsDir)
        }
        $config | Add-Member -MemberType NoteProperty -Name 'skills' -Value $skillsCfg -Force
        Write-Info "Registered skills path in config"
    }

    # Write config
    $config | ConvertTo-Json -Depth 10 | Set-Content -Path $OpenCodeConfigFile -Encoding UTF8
    Write-Success "Global OpenCode config updated at $OpenCodeConfigFile"

    Write-Info "Restart OpenCode to activate tunan skills"
}

# Install for MiMoCode
function Install-MiMoCode {
    Write-Info "Installing tunan plugin for MiMoCode..."

    $MiMoCodeConfigDir = Join-Path $HOME ".config\mimocode"
    $MiMoCodePluginDir = Join-Path $MiMoCodeConfigDir "plugins\tunan"
    $MiMoCodeConfigFile = Join-Path $MiMoCodeConfigDir "mimocode.json"

    if ($DryRun) {
        Write-Info "[DRY RUN] Would create: $MiMoCodePluginDir"
        Write-Info "[DRY RUN] Would copy skills/ agents/ .mcp.json -> $MiMoCodePluginDir"
        Write-Info "[DRY RUN] Would update: $MiMoCodeConfigFile"
        return
    }

    # Create plugin directory
    $null = New-Item -ItemType Directory -Force -Path $MiMoCodePluginDir

    # Copy skills
    $skillsSrc = Join-Path $ScriptDir "plugins\skills"
    if (Test-Path $skillsSrc) {
        Copy-Item -Recurse -Force $skillsSrc (Join-Path $MiMoCodePluginDir "skills")
    }

    # Copy agents
    $agentsSrc = Join-Path $ScriptDir "plugins\agents"
    if (Test-Path $agentsSrc) {
        Copy-Item -Recurse -Force $agentsSrc (Join-Path $MiMoCodePluginDir "agents")
    }

    # Copy MCP config (dotfile — explicit)
    $mcpSrc = Join-Path $ScriptDir "plugins\.mcp.json"
    if (Test-Path $mcpSrc) {
        Copy-Item -Force $mcpSrc $MiMoCodePluginDir
    }

    # Copy README
    $readmeSrc = Join-Path $ScriptDir "plugins\README.md"
    if (Test-Path $readmeSrc) {
        Copy-Item -Force $readmeSrc $MiMoCodePluginDir
    }

    # Create plugin manifest
    $pluginManifest = @'
{
  "skills": {
    "paths": ["./skills"]
  }
}
'@
    Set-Content -Path (Join-Path $MiMoCodePluginDir "mimocode.json") -Value $pluginManifest -Encoding UTF8

    Write-Success "tunan plugin files installed at $MiMoCodePluginDir"

    # --- Register plugin in global MiMoCode config ---
    $null = New-Item -ItemType Directory -Force -Path $MiMoCodeConfigDir

    $config = $null
    if (Test-Path $MiMoCodeConfigFile) {
        try {
            $content = Get-Content $MiMoCodeConfigFile -Raw -Encoding UTF8
            $config = $content | ConvertFrom-Json
        } catch {
            $config = $null
        }
    }

    if ($null -eq $config) {
        $config = [PSCustomObject]@{
            plugin = @('plugins/tunan')
        }
    } else {
        $plugins = @($config.plugin)
        if ($plugins -notcontains 'plugins/tunan') {
            $plugins = @($plugins + @('plugins/tunan'))
            $config | Add-Member -MemberType NoteProperty -Name 'plugin' -Value $plugins -Force
        }
    }

    $config | ConvertTo-Json -Depth 10 | Set-Content -Path $MiMoCodeConfigFile -Encoding UTF8
    Write-Success "tunan plugin registered in MiMoCode global config"

    Write-Info "Restart MiMoCode to activate tunan skills"
}

# Install for ReasoniX
function Install-ReasoniX {
    Write-Info "Installing tunan skills for ReasoniX..."

    $ReasoniXConfigDir = Join-Path $HOME ".config\reasonix"
    $ReasoniXSkillsDir = Join-Path $ReasoniXConfigDir "skills"
    $ReasoniXConfigFile = Join-Path $ReasoniXConfigDir "reasonix.toml"

    if ($DryRun) {
        Write-Info "[DRY RUN] Would create: $ReasoniXSkillsDir"
        Write-Info "[DRY RUN] Would copy skills -> $ReasoniXSkillsDir"
        Write-Info "[DRY RUN] Would update: $ReasoniXConfigFile"
        return
    }

    # Create skills directory
    $null = New-Item -ItemType Directory -Force -Path $ReasoniXSkillsDir

    # Copy skills (individual subdirs for auto-discovery)
    $skillsSrc = Join-Path $ScriptDir "plugins\skills"
    if (Test-Path $skillsSrc) {
        Get-ChildItem "$skillsSrc\*" -Directory | ForEach-Object {
            Copy-Item -Recurse -Force $_.FullName (Join-Path $ReasoniXSkillsDir $_.Name)
        }
    }

    # Copy MCP config (ReasoniX reads .mcp.json directly)
    $mcpSrc = Join-Path $ScriptDir "plugins\.mcp.json"
    if (Test-Path $mcpSrc) {
        Copy-Item -Force $mcpSrc $ReasoniXConfigDir
    }

    Write-Success "tunan skills installed at $ReasoniXSkillsDir"

    # --- Register in ReasoniX config ---
    $null = New-Item -ItemType Directory -Force -Path $ReasoniXConfigDir

    $tomlEntry = @"

[skills]
paths = ["~/.config/reasonix/skills"]
"@

    if (Test-Path $ReasoniXConfigFile) {
        $existing = Get-Content $ReasoniXConfigFile -Raw -Encoding UTF8
        if ($existing -match 'tunan') {
            Write-Info "tunan already registered in ReasoniX config"
        } else {
            Add-Content -Path $ReasoniXConfigFile -Value $tomlEntry -Encoding UTF8
            Write-Success "tunan registered in ReasoniX config"
        }
    } else {
        Set-Content -Path $ReasoniXConfigFile -Value $tomlEntry.TrimStart() -Encoding UTF8
        Write-Success "tunan registered in ReasoniX config"
    }

    Write-Info "Restart ReasoniX to activate tunan skills"
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