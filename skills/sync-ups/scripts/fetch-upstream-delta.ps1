# Clone the upstream everyinc/compound-engineering-plugin to a scratch dir and
# print the skill-scoped delta since the last-synced upstream commit.
#
# Usage: fetch-upstream-delta.ps1 [LAST_SYNCED_SHA]
#
# Stdout contract is byte-for-byte identical to fetch-upstream-delta.sh.
# Targets Windows PowerShell 5.1 (no 7+-only syntax).

param([string]$LastSha = "")

$ErrorActionPreference = "SilentlyContinue"

$scratch = Join-Path $env:TEMP "tunan-syncups-upstream"
$repo = "https://github.com/everyinc/compound-engineering-plugin.git"
$skillsPath = "plugins/compound-engineering/skills/"

if (Test-Path $scratch) { Remove-Item -Recurse -Force $scratch }
git clone --quiet $repo $scratch 2>$null
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $scratch)) {
  Write-Output "__SYNCUPS_CLONE_FAILED__"
  exit 0
}

Push-Location $scratch
$headSha = (git rev-parse HEAD 2>$null)
Write-Output "UPSTREAM_HEAD=$headSha"
Write-Output "UPSTREAM_ROOT=$scratch"

$hasSha = $false
if ($LastSha -ne "") {
  git cat-file -e "$LastSha^{commit}" 2>$null
  if ($LASTEXITCODE -eq 0) { $hasSha = $true }
}

if ($hasSha) {
  Write-Output "=== COMMITS $LastSha..HEAD ==="
  git log --oneline "$LastSha..HEAD"
  Write-Output "=== CHANGED FILES (skills) ==="
  git diff --stat "$LastSha..HEAD" -- $skillsPath
} else {
  Write-Output "=== COMMITS $LastSha..HEAD ==="
  Write-Output "__SYNCUPS_LAST_SHA_MISSING__"
  Write-Output "=== CHANGED FILES (skills) ==="
  Write-Output "__SYNCUPS_LAST_SHA_MISSING__"
}
Pop-Location
