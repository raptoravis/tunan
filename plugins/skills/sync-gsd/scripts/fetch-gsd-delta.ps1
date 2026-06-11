# Clone the upstream open-gsd/gsd-core to a scratch dir and print the
# capability-scoped delta since the last-absorbed GSD commit.
#
# Usage: fetch-gsd-delta.ps1 [LAST_SYNCED_SHA]
#
# Stdout contract is byte-for-byte identical to fetch-gsd-delta.sh.
# Targets Windows PowerShell 5.1 (no 7+-only syntax).

param([string]$LastSha = "")

$ErrorActionPreference = "SilentlyContinue"

$scratch = Join-Path $env:TEMP "tunan-syncgsd-upstream"
$repo = "https://github.com/open-gsd/gsd-core.git"
$capPaths = @("gsd-core", "capabilities", "agents", "commands")
$changesetPath = ".changeset"

if (Test-Path $scratch) { Remove-Item -Recurse -Force $scratch }
git clone --quiet $repo $scratch 2>$null
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $scratch)) {
  Write-Output "__SYNCGSD_CLONE_FAILED__"
  exit 0
}

Push-Location $scratch
$headSha = (git rev-parse HEAD 2>$null)
Write-Output "GSD_HEAD=$headSha"
Write-Output "GSD_ROOT=$scratch"

$hasSha = $false
if ($LastSha -ne "") {
  git cat-file -e "$LastSha^{commit}" 2>$null
  if ($LASTEXITCODE -eq 0) { $hasSha = $true }
}

if ($hasSha) {
  Write-Output "=== COMMITS $LastSha..HEAD ==="
  git log --oneline "$LastSha..HEAD"
  Write-Output "=== CHANGED CAPABILITIES (changesets) ==="
  git diff --name-only "$LastSha..HEAD" -- $changesetPath
  Write-Output "=== CHANGED FILES (capabilities) ==="
  git diff --stat "$LastSha..HEAD" -- $capPaths
} else {
  Write-Output "=== COMMITS $LastSha..HEAD ==="
  Write-Output "__SYNCGSD_LAST_SHA_MISSING__"
  Write-Output "=== CHANGED CAPABILITIES (changesets) ==="
  Write-Output "__SYNCGSD_LAST_SHA_MISSING__"
  Write-Output "=== CHANGED FILES (capabilities) ==="
  Write-Output "__SYNCGSD_LAST_SHA_MISSING__"
}
Pop-Location
