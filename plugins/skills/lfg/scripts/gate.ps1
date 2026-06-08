<#
  yunxing lfg gate — script-enforced phase exit conditions (Windows twin of gate.sh).

  Replaces lfg's prose "GATE: STOP ..." self-checks with deterministic checks so an
  agent cannot hallucinate progress past a stage whose evidence does not exist.

  Usage:
    gate.ps1 plan-exists <issue>
    gate.ps1 solution-exists <issue>
    gate.ps1 work-done [base-branch]
    gate.ps1 verify-green [file]        # omit file to read the contract from stdin

  Exit codes (lfg branches on these, it does not parse stdout prose):
    0  PASS   — gate satisfied, proceed
    1  FAIL   — gate not satisfied, run the stage's recovery path
    2  ERROR  — infra/usage problem (gh/jq missing, unreadable input); abort, don't loop
    3  SOFT   — non-authoritative result (verify degraded/skipped); proceed but note it
#>
[CmdletBinding()]
param(
  [Parameter(Position = 0)][string]$Cmd,
  [Parameter(Position = 1)][string]$Arg
)

$ErrorActionPreference = 'Continue'

function Pass($m)  { Write-Output "GATE PASS: $m";  exit 0 }
function Fail($m)  { Write-Error  "GATE FAIL: $m";  exit 1 }
function Infra($m) { Write-Error  "GATE ERROR: $m"; exit 2 }
function Soft($m)  { Write-Error  "GATE SOFT: $m";  exit 3 }

function Need-Gh {
  if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { Infra "gh not installed" }
  & gh auth status *> $null
  if ($LASTEXITCODE -ne 0) { Infra "gh not authenticated" }
}

function Repo-Slug {
  $slug = & gh repo view --json nameWithOwner --jq .nameWithOwner 2>$null
  return ($slug | Out-String).Trim()
}

function Has-MarkerComment([string]$n, [string]$marker) {
  $slug = Repo-Slug
  if ([string]::IsNullOrWhiteSpace($slug)) { return 2 }
  $ids = & gh api "repos/$slug/issues/$n/comments" `
    --jq ".[] | select(.body | startswith(`"$marker`")) | .id" 2>$null
  if ($ids) { return 0 } else { return 1 }
}

switch ($Cmd) {
  'plan-exists' {
    if (-not $Arg) { Infra "usage: gate.ps1 plan-exists <issue>" }
    Need-Gh
    $rc = Has-MarkerComment $Arg "<!-- yunxing:plan -->"
    if ($rc -eq 2) { Infra "cannot resolve repo to read issue #$Arg comments" }
    if ($rc -eq 0) { Pass "plan comment present on feature issue #$Arg" }
    else { Fail "no <!-- yunxing:plan --> comment on feature issue #$Arg — re-run plan" }
  }
  'solution-exists' {
    if (-not $Arg) { Infra "usage: gate.ps1 solution-exists <issue>" }
    Need-Gh
    $rc = Has-MarkerComment $Arg "<!-- yunxing:solution -->"
    if ($rc -eq 2) { Infra "cannot resolve repo to read issue #$Arg comments" }
    if ($rc -eq 0) { Pass "solution comment present on feature issue #$Arg" }
    else { Fail "no <!-- yunxing:solution --> comment on feature issue #$Arg — re-run compound" }
  }
  'work-done' {
    $porcelain = (& git status --porcelain 2>$null | Out-String)
    if (-not [string]::IsNullOrWhiteSpace($porcelain)) { Pass "working tree has uncommitted changes" }
    $base = $Arg
    if (-not $base) {
      $base = (& git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>$null | Out-String).Trim()
      if (-not $base) { $base = "origin/main" }
    }
    $mb = (& git merge-base HEAD $base 2>$null | Out-String).Trim()
    if ($mb) {
      $diff = (& git diff --name-only "$mb..HEAD" 2>$null | Out-String)
      if (-not [string]::IsNullOrWhiteSpace($diff)) { Pass "HEAD diverged from $base (committed work present)" }
    }
    Fail "no code changes detected (clean tree, no divergence from $base) — work did not run"
  }
  'verify-green' {
    if (-not (Get-Command jq -ErrorAction SilentlyContinue)) { Infra "jq not installed" }
    if ($Arg) {
      if (-not (Test-Path $Arg)) { Infra "cannot read contract file: $Arg" }
      $json = Get-Content -Raw $Arg
    } else {
      $json = [Console]::In.ReadToEnd()
    }
    if ([string]::IsNullOrWhiteSpace($json)) { Infra "empty verify contract" }
    $vc = ($json | & jq -r '.verdict_code // empty' 2>$null | Out-String).Trim()
    $st = ($json | & jq -r '.status // empty' 2>$null | Out-String).Trim()
    if (-not $vc) { Infra "contract has no verdict_code (not a verify mode:agent JSON?)" }
    if ($st -eq 'degraded' -or $st -eq 'skipped') { Soft "verify status=$st — non-authoritative; CI remains the backstop" }
    if ($vc -eq 'ready') { Pass "verify verdict_code=ready (local green)" }
    else { Fail "verify verdict_code=$vc status=$st — local checks red, run the autofix loop" }
  }
  { $_ -in @('', '-h', '--help', 'help', $null) } {
    Get-Content $PSCommandPath | Select-Object -First 24
    exit 0
  }
  default {
    Infra "unknown gate '$Cmd' (expected: plan-exists | solution-exists | work-done | verify-green)"
  }
}
