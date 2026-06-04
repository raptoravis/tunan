# Create a new git worktree with environment files and dev-tool trust.
#
# PowerShell 5.1-compatible port of worktree-manager.sh. Behavior, command
# grammar, and human-readable stdout match the bash version. The distinctive
# work (vs. raw `git worktree add`):
#   1. Copies .env* files from the main repo (skipping .env.example)
#   2. Trusts mise/direnv configs with branch-aware safety rules
#   3. Ensures .worktrees is gitignored (via `git check-ignore`)
#
# List / remove / switch operations are NOT provided here. Use git directly:
#   git worktree list
#   git worktree remove <path>
#   Set-Location <worktree-path>   # switching is just a cd

$ErrorActionPreference = 'Continue'

# Resolve the MAIN worktree's working tree (always the first --porcelain entry),
# not the current worktree's toplevel. Handles linked worktrees, submodules, and
# --separate-git-dir setups. The whole line after "worktree " is preserved so
# paths containing spaces survive.
$gitRoot = (git worktree list --porcelain 2>$null | Where-Object { $_ -match '^worktree ' } | Select-Object -First 1) -replace '^worktree ', ''
if ([string]::IsNullOrWhiteSpace($gitRoot)) {
  [Console]::Error.WriteLine("Error: not in a git repository")
  exit 1
}
$worktreeDir = "$gitRoot/.worktrees"

function Write-Usage($toErr) {
  $text = @'
Usage: worktree-manager.ps1 create <branch-name> [from-branch]

Creates .worktrees/<branch-name> with <branch-name> branched from
[from-branch] (default: origin's default branch, or main).

The main repo checkout is not modified; from-branch is fetched but
not checked out.
'@
  if ($toErr) { [Console]::Error.WriteLine($text) } else { Write-Output $text }
}

# Ensure .worktrees is ignored in the main repo (sees the main repo's
# .gitignore, which linked worktrees do not inherit).
function Ensure-Gitignore {
  Push-Location -LiteralPath $gitRoot
  try {
    git check-ignore -q .worktrees 2>$null | Out-Null
    $ignored = ($LASTEXITCODE -eq 0)
  } finally {
    Pop-Location
  }
  if ($ignored) { return }
  $giPath = Join-Path $gitRoot '.gitignore'
  if (Test-Path -LiteralPath $giPath -PathType Leaf) {
    if ((Get-Content -LiteralPath $giPath -ErrorAction SilentlyContinue) -contains '.worktrees') { return }
  }
  Add-Content -LiteralPath $giPath -Value '.worktrees'
  Write-Output 'Added .worktrees to .gitignore'
}

# Copy .env* files (except .env.example) from main repo to worktree.
function Copy-EnvFiles($worktreePath) {
  $copied = 0
  $sources = Get-ChildItem -LiteralPath $gitRoot -Filter '.env*' -File -Force -ErrorAction SilentlyContinue
  foreach ($source in $sources) {
    $name = $source.Name
    if ($name -eq '.env.example') { continue }
    $dest = "$worktreePath/$name"
    if (Test-Path -LiteralPath $dest -PathType Leaf) {
      Copy-Item -LiteralPath $dest -Destination "$dest.backup" -Force
      Write-Output "  Backed up existing $name to $name.backup"
    }
    Copy-Item -LiteralPath $source.FullName -Destination $dest -Force
    Write-Output "  Copied $name"
    $copied++
  }
  if ($copied -eq 0) { Write-Output '  No .env files in main repo' }
}

function Get-DefaultBranch {
  $headRef = (git symbolic-ref refs/remotes/origin/HEAD 2>$null | Select-Object -First 1)
  if (-not [string]::IsNullOrWhiteSpace($headRef)) {
    return ($headRef -replace '^refs/remotes/origin/', '')
  }
  return 'main'
}

# Auto-trust is only safe when the worktree is based on a long-lived branch the
# developer already controls.
function Test-TrustedBaseBranch($branch, $defaultBranch) {
  if ($branch -eq $defaultBranch) { return $true }
  if ($branch -match '^(develop|dev|trunk|staging)$') { return $true }
  if ($branch -match '^release/') { return $true }
  return $false
}

# True if worktree's copy of $file has the same blob hash as $baseRef's.
# Symlinks (reparse points) are rejected.
function Test-ConfigUnchanged($file, $baseRef, $worktreePath) {
  $full = "$worktreePath/$file"
  $item = Get-Item -LiteralPath $full -Force -ErrorAction SilentlyContinue
  if ($item -and ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) { return $false }
  $baseHash = (git rev-parse "${baseRef}:${file}" 2>$null | Select-Object -First 1)
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($baseHash)) { return $false }
  $worktreeHash = (git hash-object $full 2>$null | Select-Object -First 1)
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($worktreeHash)) { return $false }
  return ($baseHash.Trim() -eq $worktreeHash.Trim())
}

# Trust dev tool configs (mise, direnv) so hooks/scripts don't block on
# interactive trust prompts. Auto-trusts only against the trusted baseline.
function Trust-DevTools($worktreePath, $baseRef, $allowDirenvAuto) {
  $trusted = 0
  $manual = @()

  if (Get-Command mise -ErrorAction SilentlyContinue) {
    foreach ($f in @('.mise.toml', 'mise.toml', '.tool-versions')) {
      if (-not (Test-Path -LiteralPath "$worktreePath/$f" -PathType Leaf)) { continue }
      $ok = $false
      if (Test-ConfigUnchanged $f $baseRef $worktreePath) {
        Push-Location -LiteralPath $worktreePath
        try { mise trust $f --quiet 2>$null | Out-Null; $ok = ($LASTEXITCODE -eq 0) } finally { Pop-Location }
      }
      if ($ok) { $trusted++ } else { $manual += "mise trust $f" }
      break
    }
  }

  if ((Get-Command direnv -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath "$worktreePath/.envrc" -PathType Leaf)) {
    $ok = $false
    if ($allowDirenvAuto -eq 'true' -and (Test-ConfigUnchanged '.envrc' $baseRef $worktreePath)) {
      Push-Location -LiteralPath $worktreePath
      try { direnv allow 2>$null | Out-Null; $ok = ($LASTEXITCODE -eq 0) } finally { Pop-Location }
    }
    if ($ok) { $trusted++ } else { $manual += 'direnv allow' }
  }

  if ($trusted -gt 0) { Write-Output "  Trusted $trusted dev tool config(s)" }
  if ($manual.Count -gt 0) {
    Write-Output ("  Manual review required for: " + ($manual -join ' '))
    Write-Output "  Review the diff, then run from $worktreePath"
  }
}

function Create-Worktree($branchName, $fromBranch) {
  if ([string]::IsNullOrWhiteSpace($branchName)) {
    [Console]::Error.WriteLine("Error: branch name required")
    Write-Usage $true
    exit 1
  }

  $defaultBranch = Get-DefaultBranch
  if ([string]::IsNullOrWhiteSpace($fromBranch)) { $fromBranch = $defaultBranch }

  $worktreePath = "$worktreeDir/$branchName"
  if (Test-Path -LiteralPath $worktreePath -PathType Container) {
    [Console]::Error.WriteLine("Error: worktree already exists at $worktreePath")
    [Console]::Error.WriteLine("Use 'cd $worktreePath' to switch, or 'git worktree remove' first.")
    exit 1
  }

  Write-Output "Creating worktree $branchName from $fromBranch"

  New-Item -ItemType Directory -Force -Path $worktreeDir | Out-Null
  Ensure-Gitignore

  # Fetch from-branch without touching the main checkout.
  git fetch origin $fromBranch --quiet 2>$null
  if ($LASTEXITCODE -ne 0) {
    [Console]::Error.WriteLine("Warning: could not fetch origin/$fromBranch; using local ref")
  }

  # Prefer origin/<from> if available, else fall back to local ref.
  $baseRef = "origin/$fromBranch"
  git rev-parse --verify $baseRef 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) { $baseRef = $fromBranch }

  git worktree add -b $branchName $worktreePath $baseRef
  if ($LASTEXITCODE -ne 0) { exit 1 }

  Write-Output "Environment files:"
  Copy-EnvFiles $worktreePath

  Write-Output "Dev tool trust:"
  $trustBranch = $defaultBranch
  $allowDirenvAuto = 'false'
  if (Test-TrustedBaseBranch $fromBranch $defaultBranch) {
    $trustBranch = $fromBranch
    $allowDirenvAuto = 'true'
  }
  # Refresh the trust baseline before the hash-baseline check.
  if ($trustBranch -ne $fromBranch) {
    git fetch origin $trustBranch --quiet 2>$null
    if ($LASTEXITCODE -ne 0) {
      [Console]::Error.WriteLine("  Warning: could not fetch origin/$trustBranch; baseline may be stale")
    }
  }
  $trustRef = "origin/$trustBranch"
  git rev-parse --verify $trustRef 2>$null | Out-Null
  if ($LASTEXITCODE -eq 0) {
    Trust-DevTools $worktreePath $trustRef $allowDirenvAuto
  } else {
    Write-Output "  Skipped: $trustRef not available locally"
  }

  Write-Output ""
  Write-Output "Worktree ready: $worktreePath"
  Write-Output "Switch with: cd $worktreePath"
}

# -- Dispatch -----------------------------------------------------------------
$command = if ($args.Count -ge 1) { $args[0] } else { '' }
# Pipe through Select-Object so the result is always a real array. A naive
# `$rest = if (...) { @($args[1..N]) }` collapses to a scalar string when there
# is exactly ONE trailing arg (an if-expression unwraps a single-element array),
# which would make $rest[0] index the first CHARACTER instead of the first arg.
$rest = @($args | Select-Object -Skip 1)

switch ($command) {
  'create' { Create-Worktree $rest[0] $rest[1] }
  { @('', 'help', '-h', '--help') -contains $_ } { Write-Usage $false }
  default {
    [Console]::Error.WriteLine("Error: unknown command '$command'")
    Write-Usage $true
    exit 1
  }
}
