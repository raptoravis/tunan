# Compound Engineering environment health check
# PowerShell 5.1-compatible twin of check-health.sh. The stdout contract is
# preserved byte-for-byte: identical status glyphs, section headers, install
# and url detail lines, the issue count, and the tools/skills/mcp summary.
#
# Two PS 5.1 details are handled deliberately:
#  - Emoji are built from code points (not source literals) so this file stays
#    pure-ASCII and decodes correctly regardless of a missing UTF-8 BOM.
#  - Output is buffered and written once via [Console]::Out.Write joined with
#    LF, after setting UTF-8 output encoding, to match the bash LF line endings.

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false } catch {}

# =====================================================
#  Dependency config
# =====================================================
# Format: name|tier|install_cmd|url  -- keep in sync with check-health.sh

$deps = @(
  'agent-browser|recommended|CI=true npm install -g agent-browser --no-audit --no-fund --loglevel=error && agent-browser install && npx skills add https://github.com/vercel-labs/agent-browser --skill agent-browser -g -y|https://github.com/vercel-labs/agent-browser'
  'gh|recommended|NONINTERACTIVE=1 HOMEBREW_NO_AUTO_UPDATE=1 brew install -q gh|https://cli.github.com'
  'jq|recommended|NONINTERACTIVE=1 HOMEBREW_NO_AUTO_UPDATE=1 brew install -q jq|https://jqlang.github.io/jq/'
  'vhs|recommended|NONINTERACTIVE=1 HOMEBREW_NO_AUTO_UPDATE=1 brew install -q vhs|https://github.com/charmbracelet/vhs'
  'silicon|recommended|NONINTERACTIVE=1 HOMEBREW_NO_AUTO_UPDATE=1 brew install -q silicon|https://github.com/Aloxaf/silicon'
  'ffmpeg|recommended|NONINTERACTIVE=1 HOMEBREW_NO_AUTO_UPDATE=1 brew install -q ffmpeg|https://ffmpeg.org/download.html'
  'ast-grep|recommended|NONINTERACTIVE=1 HOMEBREW_NO_AUTO_UPDATE=1 brew install -q ast-grep|https://ast-grep.github.io'
)

$skills = @(
  'ast-grep|recommended|npx skills add ast-grep/agent-skill -g -y|https://github.com/ast-grep/agent-skill'
)

# MCP servers (Claude Code). Presence resolved via `claude mcp list`.
$mcp = @(
  'context7|recommended|claude mcp add context7 -- npx -y @upstash/context7-mcp@latest|https://github.com/upstash/context7'
  'sequential-thinking|recommended|claude mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking|https://github.com/modelcontextprotocol/servers/tree/main/src/sequentialthinking'
  'codegraph|recommended|claude mcp add codegraph -- npx -y @anthropics/codegraph-mcp@latest|https://github.com/anthropics/codegraph'
  'playwright|optional|claude mcp add playwright -- npx @playwright/mcp@latest|https://github.com/microsoft/playwright-mcp'
  'chrome-devtools|optional|claude mcp add chrome-devtools -- npx chrome-devtools-mcp@latest|https://github.com/ChromeDevTools/chrome-devtools-mcp'
)

# =====================================================
#  Args  ( --version VERSION )
# =====================================================

$plugin_version = ''
for ($i = 0; $i -lt $args.Count; $i++) {
  if ($args[$i] -eq '--version' -and ($i + 1) -lt $args.Count) {
    $plugin_version = $args[$i + 1]
    $i++
  }
}

# =====================================================
#  Glyphs (code points, not source literals) + output buffer
# =====================================================

$G    = [char]::ConvertFromUtf32(0x1F7E2)  # green circle
$Y    = [char]::ConvertFromUtf32(0x1F7E1)  # yellow circle
$CHK  = [char]::ConvertFromUtf32(0x2705)   # check mark
$WARN = [char]::ConvertFromUtf32(0x26A0) + [char]::ConvertFromUtf32(0xFE0F)  # warning sign

$lines = New-Object System.Collections.Generic.List[string]
function Add-Ok($s)      { $lines.Add("  $G  $s") }
function Add-Warn($s)    { $lines.Add("  $Y  $s") }
function Add-Detail($s)  { $lines.Add("       $s") }
function Add-Section($s) { $lines.Add(""); $lines.Add(" $s") }

$has_brew = [bool](Get-Command brew -ErrorAction SilentlyContinue)

$has_git = [bool](Get-Command git -ErrorAction SilentlyContinue)
$in_repo = $false
if ($has_git) {
  $null = (git rev-parse --is-inside-work-tree 2>$null)
  $in_repo = ($LASTEXITCODE -eq 0)
}

# =====================================================
#  Check tools
# =====================================================

$cli_ok = 0; $cli_total = 0
$results = @()
foreach ($entry in $deps) {
  $p = $entry.Split('|'); $name = $p[0]; $tier = $p[1]; $install = $p[2]; $url = $p[3]
  $cli_total++
  if (Get-Command $name -ErrorAction SilentlyContinue) {
    # gh must be installed AND authenticated to be usable. The whole tunan
    # workflow stores requirements/state in GitHub issues, so an unauthenticated
    # gh is as broken as a missing one -- flag it and count it as not-ok.
    if ($name -eq 'gh') {
      & gh auth status 2>$null | Out-Null
      if ($LASTEXITCODE -eq 0) { $cli_ok++; $st = 'ok' } else { $st = 'unauthenticated' }
    } else {
      $cli_ok++; $st = 'ok'
    }
  } else {
    $st = 'missing'
  }
  $results += [pscustomobject]@{ name = $name; tier = $tier; status = $st; install = $install; url = $url }
}

# =====================================================
#  Check skills
# =====================================================

$has_npx = [bool](Get-Command npx -ErrorAction SilentlyContinue)
$has_jq  = [bool](Get-Command jq -ErrorAction SilentlyContinue)

$installed_skill_names = @()
if ($has_npx -and $has_jq) {
  try {
    $raw = (& npx --yes skills list --global --json 2>$null | Out-String)
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
      $parsed = $raw | ConvertFrom-Json
      $installed_skill_names = @($parsed | ForEach-Object { $_.name })
    }
  } catch {
    $installed_skill_names = @()
  }
}

$skill_roots = @(
  (Join-Path $env:USERPROFILE '.claude\skills')
  (Join-Path $env:USERPROFILE '.agents\skills')
  (Join-Path $env:USERPROFILE '.codex\skills')
)

function Test-SkillOnDisk($n) {
  foreach ($root in $skill_roots) {
    if (Test-Path -LiteralPath (Join-Path $root $n)) { return $true }
  }
  return $false
}

$skill_ok = 0; $skill_total = 0
$skill_results = @()
foreach ($entry in $skills) {
  $p = $entry.Split('|'); $name = $p[0]; $tier = $p[1]; $install = $p[2]; $url = $p[3]
  $skill_total++
  $isInstalled = $false
  if ($installed_skill_names -contains $name) { $isInstalled = $true }
  if (-not $isInstalled -and (Test-SkillOnDisk $name)) { $isInstalled = $true }
  if ($isInstalled) {
    $skill_ok++; $st = 'ok'
  } else {
    $st = 'missing'
  }
  $skill_results += [pscustomobject]@{ name = $name; tier = $tier; status = $st; install = $install; url = $url }
}

# =====================================================
#  Check MCP servers (Claude Code only)
# =====================================================

$has_claude = [bool](Get-Command claude -ErrorAction SilentlyContinue)
$mcp_listing = ''
if ($has_claude) {
  $mcp_listing = (& claude mcp list 2>$null | Out-String)
}

$mcp_ok = 0; $mcp_total = 0
$mcp_results = @()
foreach ($entry in $mcp) {
  $p = $entry.Split('|'); $name = $p[0]; $tier = $p[1]; $install = $p[2]; $url = $p[3]
  $mcp_total++
  $present = $false
  if ($has_claude) {
    foreach ($line in ($mcp_listing -split "`r?`n")) {
      if ($line -match ('^' + [regex]::Escape($name) + '[: ]')) { $present = $true; break }
    }
  }
  if ($present) {
    $mcp_ok++; $st = 'ok'
  } else {
    $st = 'missing'
  }
  $mcp_results += [pscustomobject]@{ name = $name; tier = $tier; status = $st; install = $install; url = $url }
}

# =====================================================
#  Project checks (repo only)
# =====================================================

$legacy_cfg = 'skip'; $config_issue = 'skip'

if ($in_repo) {
  $repo_root = (git rev-parse --show-toplevel 2>$null | Select-Object -First 1)
  $legacy_cfg = 'missing'
  if (Test-Path -LiteralPath "$repo_root/tunan.local.md") { $legacy_cfg = 'present' }

  # The config issue is the source of truth. Checking it needs an authenticated
  # gh; when gh is unavailable leave config_issue=skip (offline diagnostic).
  if (Get-Command gh -ErrorAction SilentlyContinue) {
    & gh auth status *> $null
    if ($LASTEXITCODE -eq 0) {
      $num = (& gh issue list --label "tunan:config" --state open --json number --jq '.[0].number // empty' 2>$null | Out-String).Trim()
      if ($num) { $config_issue = 'present' } else { $config_issue = 'missing' }
    }
  }
}

# =====================================================
#  Output
# =====================================================

$issues = 0
$lines.Add("")
if ($plugin_version -ne '') {
  Add-Ok "Plugin version v$plugin_version"
}

# --- Tools ---

Add-Section "Tools  $cli_ok/$cli_total"

foreach ($r in $results) {
  if ($r.status -eq 'ok') {
    Add-Ok $r.name
  } elseif ($r.status -eq 'unauthenticated') {
    Add-Warn "$($r.name) (not authenticated)"
    $issues++
    Add-Detail "Run: gh auth login"
  } else {
    Add-Warn $r.name
    $issues++
    if ($r.install -like '*brew install*') {
      if ($has_brew) { Add-Detail $r.install } else { Add-Detail $r.url }
    } else {
      Add-Detail $r.install
      Add-Detail $r.url
    }
  }
}

# --- Skills ---

if ($skills.Count -gt 0) {
  Add-Section "Skills  $skill_ok/$skill_total"

  foreach ($r in $skill_results) {
    if ($r.status -eq 'ok') {
      Add-Ok $r.name
    } else {
      Add-Warn $r.name
      $issues++
      Add-Detail $r.install
      Add-Detail $r.url
    }
  }
}

# --- MCP servers ---

if ($has_claude -and $mcp.Count -gt 0) {
  Add-Section "MCP Servers  $mcp_ok/$mcp_total"

  foreach ($r in $mcp_results) {
    if ($r.status -eq 'ok') {
      Add-Ok $r.name
    } else {
      Add-Warn $r.name
      $issues++
      Add-Detail $r.install
      Add-Detail $r.url
    }
  }
}

# --- Project ---

if ($in_repo) {
  $has_project_issues = $false

  if ($legacy_cfg -eq 'present') { $has_project_issues = $true }
  if ($config_issue -eq 'missing') { $has_project_issues = $true }

  if ($has_project_issues) {
    Add-Section "Project"

    if ($legacy_cfg -eq 'present') {
      Add-Warn "Outdated Compound Engineering config in this repo"
      $issues++
    }

    if ($config_issue -eq 'missing') {
      Add-Warn "No tunan:config issue yet — run /tunan:setup to create one"
      $issues++
    }
  }
}

# --- Bottom line ---

$lines.Add("")
$summary = "$cli_ok/$cli_total tools  $skill_ok/$skill_total skills"
if ($has_claude) {
  $summary = "$summary  $mcp_ok/$mcp_total mcp"
}

if ($issues -eq 0) {
  $lines.Add(" $CHK  All clear  $summary")
} else {
  $lines.Add(" $WARN   $issues issue(s) found  $summary")
}

$lines.Add("")

[Console]::Out.Write((($lines.ToArray()) -join "`n") + "`n")
