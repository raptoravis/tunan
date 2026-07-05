# read-launch-json.ps1 — read .claude/launch.json from the repo root and emit
# the selected configuration as JSON on stdout, or a sentinel on failure.
#
# PowerShell 5.1-compatible port of read-launch-json.sh. Uses the built-in
# ConvertFrom-Json/ConvertTo-Json instead of jq (one fewer dependency on
# Windows). The stdout contract is identical:
#
#   Success: single-line compact JSON object for the chosen configuration.
#   Sentinels (one per line):
#     __NO_LAUNCH_JSON__           - file not found
#     __INVALID_LAUNCH_JSON__      - file exists but fails JSON parsing
#     __MISSING_CONFIGURATIONS__   - valid JSON but no `configurations` array
#     __MULTIPLE_CONFIGS__         - ambiguity; followed by a JSON array of names
#     __CONFIG_NOT_FOUND__         - caller-provided name doesn't match any entry
#
# Never exits non-zero for a missing/malformed file — callers parse the
# sentinel. Exit code 1 is reserved for genuine operational failures
# (git root not found).
#
# Usage: read-launch-json.ps1 [config-name]

param([string]$RequestedName = '')

$repoRoot = (git rev-parse --show-toplevel 2>$null | Select-Object -First 1)
if ([string]::IsNullOrWhiteSpace($repoRoot)) {
  [Console]::Error.WriteLine("ERROR: not in a git repository")
  exit 1
}

$launchPath = Join-Path $repoRoot '.claude/launch.json'

if (-not (Test-Path -LiteralPath $launchPath -PathType Leaf)) {
  Write-Output '__NO_LAUNCH_JSON__'
  exit 0
}

# Validate JSON before any downstream query runs.
try {
  $data = Get-Content -Raw -LiteralPath $launchPath | ConvertFrom-Json
} catch {
  Write-Output '__INVALID_LAUNCH_JSON__'
  exit 0
}

$configs = @($data.configurations)
$count = $configs.Count

if ($count -eq 0) {
  Write-Output '__MISSING_CONFIGURATIONS__'
  exit 0
}

if ($count -eq 1) {
  Write-Output ($configs[0] | ConvertTo-Json -Compress -Depth 20)
  exit 0
}

# Multiple configurations. If the caller named one, emit it. Otherwise, emit
# the sentinel + name list so the caller can prompt the user.
if (-not [string]::IsNullOrWhiteSpace($RequestedName)) {
  $match = $configs | Where-Object { $_.name -eq $RequestedName } | Select-Object -First 1
  if ($null -eq $match) {
    Write-Output '__CONFIG_NOT_FOUND__'
    exit 0
  }
  Write-Output ($match | ConvertTo-Json -Compress -Depth 20)
  exit 0
}

Write-Output '__MULTIPLE_CONFIGS__'
# Always 2+ names here, so ConvertTo-Json yields a JSON array (no scalar unwrap).
Write-Output (@($configs | ForEach-Object { $_.name }) | ConvertTo-Json -Compress)
exit 0
