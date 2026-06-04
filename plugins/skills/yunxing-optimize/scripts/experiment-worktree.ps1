# Experiment Worktree Manager (PowerShell 5.1-compatible port of
# experiment-worktree.sh). Creates, cleans up, and manages worktrees for
# optimization experiments. stdout contract is preserved: `create` prints only
# the worktree path, `count` prints only the integer, `help` prints usage; all
# diagnostics go to stderr (ANSI color is dropped — cosmetic on stderr only).
#
# Usage:
#   experiment-worktree.ps1 create <spec_name> <exp_index> <base_branch> [shared_file ...]
#   experiment-worktree.ps1 cleanup <spec_name> <exp_index>
#   experiment-worktree.ps1 cleanup-all <spec_name>
#   experiment-worktree.ps1 count
#
# Worktrees: .worktrees/optimize-<spec>-exp-<NNN>/   Branches: optimize-exp/<spec>/exp-<NNN>

$ErrorActionPreference = 'Continue'

$gitRoot = (git rev-parse --show-toplevel 2>$null | Select-Object -First 1)
if ([string]::IsNullOrWhiteSpace($gitRoot)) {
  [Console]::Error.WriteLine("Error: Not in a git repository")
  exit 1
}
$worktreeDir = "$gitRoot/.worktrees"

function Get-ExperimentBranchName($specName, $paddedIndex) {
  # Keep experiment refs outside optimize/<spec> so they do not collide with
  # the long-lived optimization branch namespace.
  return "optimize-exp/$specName/exp-$paddedIndex"
}

function Ensure-WorktreeExclude {
  $excludeFile = (git rev-parse --git-path info/exclude 2>$null | Select-Object -First 1)
  if ([string]::IsNullOrWhiteSpace($excludeFile)) { return }
  $parent = Split-Path -Parent $excludeFile
  if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  $has = $false
  if (Test-Path -LiteralPath $excludeFile -PathType Leaf) {
    $has = [bool]((Get-Content -LiteralPath $excludeFile -ErrorAction SilentlyContinue) | Where-Object { $_ -eq '.worktrees' })
  }
  if (-not $has) { Add-Content -LiteralPath $excludeFile -Value '.worktrees' }
}

function Test-RegisteredWorktree($worktreePath) {
  $lines = git worktree list --porcelain 2>$null
  return [bool]($lines | Where-Object { $_ -eq "worktree $worktreePath" })
}

function Test-BranchCheckedOut($branchName) {
  $ref = "refs/heads/$branchName"
  $lines = git worktree list --porcelain 2>$null
  return [bool]($lines | Where-Object { $_ -eq "branch $ref" })
}

function Reset-WorktreeToBase($worktreePath, $branchName, $baseBranch) {
  $current = (git -C $worktreePath symbolic-ref --quiet --short HEAD 2>$null | Select-Object -First 1)
  if ($current -ne $branchName) {
    $shown = if ([string]::IsNullOrEmpty($current)) { 'detached' } else { $current }
    [Console]::Error.WriteLine("Error: Existing worktree is on unexpected branch: $shown (expected $branchName)")
    [Console]::Error.WriteLine("Clean up the stale worktree before rerunning this experiment.")
    return $false
  }
  [Console]::Error.WriteLine("Resetting existing experiment worktree to base: $branchName -> $baseBranch")
  git -C $worktreePath reset --hard $baseBranch 2>$null | Out-Null
  git -C $worktreePath clean -fdx 2>$null | Out-Null
  return $true
}

function Create-Worktree($argv) {
  $specName = $argv[0]; $expIndex = $argv[1]; $baseBranch = $argv[2]
  if ([string]::IsNullOrWhiteSpace($specName)) { [Console]::Error.WriteLine("Error: spec_name required"); exit 1 }
  if ([string]::IsNullOrWhiteSpace($expIndex)) { [Console]::Error.WriteLine("Error: exp_index required"); exit 1 }
  if ([string]::IsNullOrWhiteSpace($baseBranch)) { [Console]::Error.WriteLine("Error: base_branch required"); exit 1 }
  $sharedFiles = @($argv | Select-Object -Skip 3)

  $paddedIndex = '{0:D3}' -f [int]$expIndex
  $worktreeName = "optimize-$specName-exp-$paddedIndex"
  $branchName = Get-ExperimentBranchName $specName $paddedIndex
  $worktreePath = "$worktreeDir/$worktreeName"

  if (Test-Path -LiteralPath $worktreePath -PathType Container) {
    git -C $worktreePath rev-parse --is-inside-work-tree 2>$null | Out-Null
    $insideWorkTree = ($LASTEXITCODE -eq 0)
    if ((-not $insideWorkTree) -or (-not (Test-RegisteredWorktree $worktreePath))) {
      [Console]::Error.WriteLine("Error: Existing path is not a valid registered git worktree: $worktreePath")
      [Console]::Error.WriteLine("Remove or repair that directory before rerunning the experiment.")
      exit 1
    }
    [Console]::Error.WriteLine("Worktree already exists: $worktreePath")
    if (-not (Reset-WorktreeToBase $worktreePath $branchName $baseBranch)) { exit 1 }
  } else {
    New-Item -ItemType Directory -Force -Path $worktreeDir | Out-Null
    Ensure-WorktreeExclude

    git worktree add -b $branchName $worktreePath $baseBranch --quiet 2>$null
    if ($LASTEXITCODE -ne 0) {
      git show-ref --verify --quiet "refs/heads/$branchName" 2>$null
      if ($LASTEXITCODE -eq 0) {
        if (Test-BranchCheckedOut $branchName) {
          [Console]::Error.WriteLine("Error: Existing experiment branch is already checked out: $branchName")
          [Console]::Error.WriteLine("Clean up the stale worktree before rerunning this experiment.")
          exit 1
        }
        [Console]::Error.WriteLine("Resetting existing experiment branch to base: $branchName -> $baseBranch")
        git branch -f $branchName $baseBranch 2>$null | Out-Null
        git worktree add $worktreePath $branchName --quiet
      } else {
        [Console]::Error.WriteLine("Error: Failed to create worktree for $branchName from $baseBranch")
        exit 1
      }
    }
  }

  # Copy .env files from main repo (skip .env.example).
  Get-ChildItem -LiteralPath $gitRoot -Filter '.env*' -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.Name -ne '.env.example') {
      Copy-Item -LiteralPath $_.FullName -Destination "$worktreePath/$($_.Name)" -Force
    }
  }

  # Copy shared files/dirs.
  foreach ($sharedFile in $sharedFiles) {
    $src = "$gitRoot/$sharedFile"
    $dst = "$worktreePath/$sharedFile"
    if (Test-Path -LiteralPath $src -PathType Leaf) {
      $dir = Split-Path -Parent $dst
      if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
      Copy-Item -LiteralPath $src -Destination $dst -Force
    } elseif (Test-Path -LiteralPath $src -PathType Container) {
      $dir = Split-Path -Parent $dst
      if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
      if (Test-Path -LiteralPath $dst) { Remove-Item -LiteralPath $dst -Recurse -Force -ErrorAction SilentlyContinue }
      Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
    }
  }

  Write-Output $worktreePath
}

function Cleanup-Worktree($argv) {
  $specName = $argv[0]; $expIndex = $argv[1]
  if ([string]::IsNullOrWhiteSpace($specName)) { [Console]::Error.WriteLine("Error: spec_name required"); exit 1 }
  if ([string]::IsNullOrWhiteSpace($expIndex)) { [Console]::Error.WriteLine("Error: exp_index required"); exit 1 }

  $paddedIndex = '{0:D3}' -f [int]$expIndex
  $worktreeName = "optimize-$specName-exp-$paddedIndex"
  $branchName = Get-ExperimentBranchName $specName $paddedIndex
  $worktreePath = "$worktreeDir/$worktreeName"

  if (Test-Path -LiteralPath $worktreePath -PathType Container) {
    git worktree remove $worktreePath --force 2>$null
    if ($LASTEXITCODE -ne 0) {
      Remove-Item -LiteralPath $worktreePath -Recurse -Force -ErrorAction SilentlyContinue
      git worktree prune 2>$null | Out-Null
    }
  }

  git branch -D $branchName 2>$null | Out-Null

  [Console]::Error.WriteLine("Cleaned up: $worktreeName")
}

function Cleanup-All($argv) {
  $specName = $argv[0]
  if ([string]::IsNullOrWhiteSpace($specName)) { [Console]::Error.WriteLine("Error: spec_name required"); exit 1 }
  $prefix = "optimize-$specName-exp-"
  $count = 0

  if (-not (Test-Path -LiteralPath $worktreeDir -PathType Container)) {
    [Console]::Error.WriteLine("No worktrees directory found")
    return
  }

  $candidates = Get-ChildItem -LiteralPath $worktreeDir -Directory -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "$prefix*" }
  foreach ($wt in $candidates) {
    $worktreePath = "$worktreeDir/$($wt.Name)"
    $indexStr = $wt.Name.Substring($prefix.Length)

    git worktree remove $worktreePath --force 2>$null
    if ($LASTEXITCODE -ne 0) {
      Remove-Item -LiteralPath $worktreePath -Recurse -Force -ErrorAction SilentlyContinue
    }

    $branchName = Get-ExperimentBranchName $specName $indexStr
    git branch -D $branchName 2>$null | Out-Null

    $count++
  }

  git worktree prune 2>$null | Out-Null

  if ((Test-Path -LiteralPath $worktreeDir -PathType Container) -and
      (-not (Get-ChildItem -LiteralPath $worktreeDir -Force -ErrorAction SilentlyContinue))) {
    Remove-Item -LiteralPath $worktreeDir -Force -ErrorAction SilentlyContinue
  }

  [Console]::Error.WriteLine("Cleaned up $count experiment worktree(s) for $specName")
}

function Count-Worktrees {
  $count = 0
  if (Test-Path -LiteralPath $worktreeDir -PathType Container) {
    foreach ($d in (Get-ChildItem -LiteralPath $worktreeDir -Directory -Force -ErrorAction SilentlyContinue)) {
      if (Test-Path -LiteralPath "$($d.FullName)/.git") { $count++ }
    }
  }
  Write-Output $count
}

# -- Main ---------------------------------------------------------------------
$command = if ($args.Count -ge 1) { $args[0] } else { 'help' }
# Pipe through Select-Object so the result is always a real array. A naive
# `$rest = if (...) { @($args[1..N]) }` collapses to a scalar string when there
# is exactly ONE trailing arg (an if-expression unwraps a single-element array),
# which would make $rest[0] index the first CHARACTER instead of the first arg.
$rest = @($args | Select-Object -Skip 1)

switch ($command) {
  'create'      { Create-Worktree $rest }
  'cleanup'     { Cleanup-Worktree $rest }
  'cleanup-all' { Cleanup-All $rest }
  'count'       { Count-Worktrees }
  'help' {
    Write-Output @'
Experiment Worktree Manager

Usage:
  experiment-worktree.ps1 create <spec_name> <exp_index> <base_branch> [shared_file ...]
  experiment-worktree.ps1 cleanup <spec_name> <exp_index>
  experiment-worktree.ps1 cleanup-all <spec_name>
  experiment-worktree.ps1 count

Commands:
  create       Create an experiment worktree with copied shared files
  cleanup      Remove a single experiment worktree and its branch
  cleanup-all  Remove all experiment worktrees for a spec
  count        Count total active worktrees (for budget checking)

Worktrees:  .worktrees/optimize-<spec>-exp-<NNN>/
Branches:   optimize-exp/<spec>/exp-<NNN>
'@
  }
  default {
    [Console]::Error.WriteLine("Unknown command: $command")
    exit 1
  }
}
