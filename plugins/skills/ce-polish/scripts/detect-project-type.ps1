# detect-project-type.ps1 — inspect signature files at the repo root (and, if
# no root match is found, probe shallow subdirectories) to emit a project-type
# identifier on stdout. PowerShell 5.1-compatible port of detect-project-type.sh.
#
# Output grammar (one line on stdout):
#   <type>                              — single signature match at root
#   <type>@<relative-dir>              — single monorepo hit (no root match)
#   multiple                            — two or more disjoint root signatures
#   multiple:<type>@<dir>,<type>@<dir>  — multiple monorepo hits (no root match)
#   unknown                             — no signatures found at root or in probe
#
# Supported root types: rails, next, vite, nuxt, astro, remix, sveltekit, procfile
# Monorepo probe runs only on ZERO root matches; descends to dir depth 3.
# `find -maxdepth/-prune` is replaced by a bounded BFS that skips excluded dirs.

$repoRoot = (git rev-parse --show-toplevel 2>$null | Select-Object -First 1)
if ([string]::IsNullOrWhiteSpace($repoRoot)) {
  [Console]::Error.WriteLine("ERROR: not in a git repository")
  exit 1
}
$rootFull = (Get-Item -LiteralPath $repoRoot -ErrorAction SilentlyContinue).FullName
if (-not $rootFull) {
  [Console]::Error.WriteLine("ERROR: cannot resolve repo root")
  exit 1
}

function Test-RootFile($name) { Test-Path -LiteralPath (Join-Path $rootFull $name) -PathType Leaf }

$rootMatches = @()

# Rails: bin/dev AND Gemfile together.
if ((Test-RootFile 'bin/dev') -and (Test-RootFile 'Gemfile')) { $rootMatches += 'rails' }
# Next.js
if ((Test-RootFile 'next.config.js') -or (Test-RootFile 'next.config.mjs') -or (Test-RootFile 'next.config.ts') -or (Test-RootFile 'next.config.cjs')) { $rootMatches += 'next' }
# Vite
if ((Test-RootFile 'vite.config.js') -or (Test-RootFile 'vite.config.ts') -or (Test-RootFile 'vite.config.mjs') -or (Test-RootFile 'vite.config.cjs')) { $rootMatches += 'vite' }
# Nuxt
if ((Test-RootFile 'nuxt.config.js') -or (Test-RootFile 'nuxt.config.mjs') -or (Test-RootFile 'nuxt.config.ts')) { $rootMatches += 'nuxt' }
# Astro
if ((Test-RootFile 'astro.config.js') -or (Test-RootFile 'astro.config.mjs') -or (Test-RootFile 'astro.config.ts')) { $rootMatches += 'astro' }
# Remix (classic)
if ((Test-RootFile 'remix.config.js') -or (Test-RootFile 'remix.config.ts')) { $rootMatches += 'remix' }
# SvelteKit
if ((Test-RootFile 'svelte.config.js') -or (Test-RootFile 'svelte.config.mjs') -or (Test-RootFile 'svelte.config.ts')) { $rootMatches += 'sveltekit' }
# Procfile — only if we didn't already detect rails
if ($rootMatches.Count -eq 0 -or $rootMatches[0] -ne 'rails') {
  if ((Test-RootFile 'Procfile') -or (Test-RootFile 'Procfile.dev')) { $rootMatches += 'procfile' }
}

# -- Root result --------------------------------------------------------------
if ($rootMatches.Count -eq 1) { Write-Output $rootMatches[0]; exit 0 }
if ($rootMatches.Count -ge 2) { Write-Output 'multiple'; exit 0 }

# -- Monorepo probe (zero root matches) ---------------------------------------
$excludeDirs = @('node_modules', '.git', 'vendor', 'dist', 'build', 'coverage', '.next', '.nuxt', '.svelte-kit', '.turbo', 'tmp', 'fixtures')
$signatureNames = @(
  'next.config.js', 'next.config.mjs', 'next.config.ts', 'next.config.cjs',
  'vite.config.js', 'vite.config.ts', 'vite.config.mjs', 'vite.config.cjs',
  'nuxt.config.js', 'nuxt.config.mjs', 'nuxt.config.ts',
  'astro.config.js', 'astro.config.mjs', 'astro.config.ts',
  'remix.config.js', 'remix.config.ts',
  'svelte.config.js', 'svelte.config.mjs', 'svelte.config.ts'
)

# BFS to dir depth 3, skipping excluded directory names. Collect signature
# config files and Gemfiles (with their containing directory).
$sigFiles = @()
$gemfileDirs = @()
$queue = New-Object System.Collections.Queue
$queue.Enqueue([pscustomobject]@{ Path = $rootFull; Depth = 0 })
while ($queue.Count -gt 0) {
  $cur = $queue.Dequeue()
  $children = Get-ChildItem -LiteralPath $cur.Path -Force -ErrorAction SilentlyContinue
  foreach ($c in $children) {
    if ($c.PSIsContainer) {
      if ($excludeDirs -contains $c.Name) { continue }
      if ($cur.Depth -lt 3) { $queue.Enqueue([pscustomobject]@{ Path = $c.FullName; Depth = $cur.Depth + 1 }) }
    } else {
      if ($signatureNames -contains $c.Name) { $sigFiles += $c.FullName }
      elseif ($c.Name -eq 'Gemfile') { $gemfileDirs += $c.DirectoryName }
    }
  }
}

# Relative dir (forward slashes) of an absolute path under the repo root.
# Returns "." for the root itself.
function Get-RelDir($absDir) {
  $rel = $absDir.Substring($rootFull.Length).TrimStart('\', '/') -replace '\\', '/'
  if ([string]::IsNullOrEmpty($rel)) { return '.' }
  return $rel
}

$monoHits = New-Object System.Collections.Generic.List[string]
function Add-MonoHit($hit) {
  if (-not $monoHits.Contains($hit)) { $monoHits.Add($hit) }
}

foreach ($f in $sigFiles) {
  $fname = Split-Path -Leaf $f
  $fdir = Get-RelDir (Split-Path -Parent $f)
  if ($fdir -eq '.') { continue }  # root hits already handled
  # Depth cap: at most 2 slashes in the relative dir (dir depth <= 3).
  if (($fdir.ToCharArray() | Where-Object { $_ -eq '/' }).Count -gt 2) { continue }
  $ftype = switch -wildcard ($fname) {
    'next.config.*'   { 'next' }
    'vite.config.*'   { 'vite' }
    'nuxt.config.*'   { 'nuxt' }
    'astro.config.*'  { 'astro' }
    'remix.config.*'  { 'remix' }
    'svelte.config.*' { 'sveltekit' }
    default           { $null }
  }
  if ($null -eq $ftype) { continue }
  Add-MonoHit "$ftype@$fdir"
}

foreach ($gdir in $gemfileDirs) {
  if (-not (Test-Path -LiteralPath (Join-Path $gdir 'bin/dev') -PathType Leaf)) { continue }
  $rdir = Get-RelDir $gdir
  if ($rdir -eq '.' -or [string]::IsNullOrEmpty($rdir)) { continue }
  if (($rdir.ToCharArray() | Where-Object { $_ -eq '/' }).Count -gt 2) { continue }
  Add-MonoHit "rails@$rdir"
}

$sorted = @($monoHits | Sort-Object)

if ($sorted.Count -eq 0) {
  Write-Output 'unknown'
} elseif ($sorted.Count -eq 1) {
  Write-Output $sorted[0]
} else {
  Write-Output ("multiple:" + ($sorted -join ','))
}
