<#
  tunan phase detector — infer a feature's lifecycle phase from its GitHub issue
  (Windows twin of phase.sh).

  The feature issue IS the state machine: labels + marker comments + an open PR encode
  how far the pipeline got. This reads that state so an interrupted run can resume at the
  right stage instead of re-running lfg from step 1.

  Usage:
    phase.ps1 detect <issue>

  Emits ONE machine line on stdout, then human hints on stderr:
    phase=<plan|work|review-ci|done|unknown> next=<skill|none> pr=<url|-> issue=<N> units_done=<csv|-> units_total=<N|->

  units_done / units_total come from an optional <!-- tunan:progress --> comment
  that `work` maintains as a resume hint (git stays authoritative for shipped code).
  They are `-` when no progress comment exists. Appended fields keep the line
  backward-compatible — callers parsing only phase/next/pr/issue still work.
#>
[CmdletBinding()]
param(
  [Parameter(Position = 0)][string]$Cmd,
  [Parameter(Position = 1)][string]$N
)

$ErrorActionPreference = 'Continue'

$script:Udone = '-'
$script:Utotal = '-'
function Emit($phase, $next, $pr) {
  if (-not $pr) { $pr = '-' }
  $iss = if ($N) { $N } else { '-' }
  Write-Output "phase=$phase next=$next pr=$pr issue=$iss units_done=$script:Udone units_total=$script:Utotal"
}

# Populate Udone/Utotal from the optional <!-- tunan:progress --> comment, whose
# machine line looks like: <!-- progress: done=U1,U2,U3 total=5 -->
function Read-Progress {
  $body = & gh api "repos/$slug/issues/$N/comments" `
    --jq '.[] | select(.body | startswith("<!-- tunan:progress -->")) | .body' 2>$null | Out-String
  if (-not $body) { return }
  $m = [regex]::Match($body, 'progress: done=(?<d>\S*) total=(?<t>\d+)')
  if ($m.Success) {
    if ($m.Groups['d'].Value) { $script:Udone = $m.Groups['d'].Value }
    if ($m.Groups['t'].Value) { $script:Utotal = $m.Groups['t'].Value }
  }
}

if ($Cmd -ne 'detect' -or -not $N) { Write-Error "usage: phase.ps1 detect <issue>"; exit 2 }

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { Emit unknown none -; Write-Error "gh not installed"; exit 2 }
& gh auth status *> $null
if ($LASTEXITCODE -ne 0) { Emit unknown none -; Write-Error "gh not authenticated"; exit 2 }

$slug = (& gh repo view --json nameWithOwner --jq .nameWithOwner 2>$null | Out-String).Trim()
if (-not $slug) { Emit unknown none -; Write-Error "cannot resolve repo"; exit 2 }

& gh issue view $N --json number *> $null
if ($LASTEXITCODE -ne 0) { Emit unknown none -; Write-Error "feature issue #$N not found"; exit 1 }

function Has-Marker([string]$marker) {
  $ids = & gh api "repos/$slug/issues/$N/comments" `
    --jq ".[] | select(.body | startswith(`"$marker`")) | .id" 2>$null
  return [bool]$ids
}

if (Has-Marker "<!-- tunan:solution -->") {
  Emit done none -
  Write-Error "Feature #$N is complete (solution comment present). Nothing to resume."
  exit 0
}

$pr = (& gh pr list --state open --search "$N in:body" --json number,url --jq '.[0].url' 2>$null | Out-String).Trim()
if (-not $pr) {
  $pr = (& gh pr view --json url --jq .url 2>$null | Out-String).Trim()
}

if ($pr) {
  Read-Progress
  Emit review-ci code-review $pr
  Write-Error "Open PR for #${N}: $pr — resume at code-review, then CI watch + compound (lfg steps 3-9)."
  exit 0
}

if (Has-Marker "<!-- tunan:plan -->") {
  Read-Progress
  Emit work work -
  Write-Error "Plan comment present on #$N, no PR yet — resume at work (lfg step 2)."
  exit 0
}

Emit plan plan -
Write-Error "Feature #$N has no plan comment — resume at plan (lfg step 1)."
exit 0
