# resolve-package-manager.ps1 — detect which JS package manager a project uses
# by inspecting lockfiles, and emit the binary name plus canonical command tail.
#
# PowerShell 5.1-compatible port of resolve-package-manager.sh. stdout contract
# is identical (two lines):
#   Line 1: package-manager binary token (`npm` | `pnpm` | `yarn` | `bun`)
#   Line 2: canonical argv tail for running a dev script (`run dev` | `dev`)
#
# Lockfile priority: pnpm-lock.yaml > yarn.lock > bun.lock > bun.lockb > package-lock.json
# Sentinel (stdout, exit 0): __NO_PACKAGE_JSON__
# Errors (stderr, exit 1): path missing / not a dir / not in a git repo
#
# Usage: resolve-package-manager.ps1 [path]

param([string]$TargetPath = '')

# Resolve target directory: positional arg or git repo root.
if (-not [string]::IsNullOrWhiteSpace($TargetPath)) {
  if (-not (Test-Path -LiteralPath $TargetPath -PathType Container)) {
    [Console]::Error.WriteLine("ERROR: path does not exist or is not a directory: $TargetPath")
    exit 1
  }
} else {
  $TargetPath = (git rev-parse --show-toplevel 2>$null | Select-Object -First 1)
  if ([string]::IsNullOrWhiteSpace($TargetPath)) {
    [Console]::Error.WriteLine("ERROR: not in a git repository and no path argument provided")
    exit 1
  }
}

# Sentinel: no package.json means this is not a JS/TS project.
if (-not (Test-Path -LiteralPath (Join-Path $TargetPath 'package.json') -PathType Leaf)) {
  Write-Output '__NO_PACKAGE_JSON__'
  exit 0
}

# Check lockfiles in priority order.
if (Test-Path -LiteralPath (Join-Path $TargetPath 'pnpm-lock.yaml') -PathType Leaf) {
  Write-Output 'pnpm'; Write-Output 'dev'; exit 0
}
if (Test-Path -LiteralPath (Join-Path $TargetPath 'yarn.lock') -PathType Leaf) {
  Write-Output 'yarn'; Write-Output 'dev'; exit 0
}
if (Test-Path -LiteralPath (Join-Path $TargetPath 'bun.lock') -PathType Leaf) {
  Write-Output 'bun'; Write-Output 'run dev'; exit 0
}
if (Test-Path -LiteralPath (Join-Path $TargetPath 'bun.lockb') -PathType Leaf) {
  Write-Output 'bun'; Write-Output 'run dev'; exit 0
}
if (Test-Path -LiteralPath (Join-Path $TargetPath 'package-lock.json') -PathType Leaf) {
  Write-Output 'npm'; Write-Output 'run dev'; exit 0
}

# Fallback: package.json present but no recognized lockfile.
Write-Output 'npm'; Write-Output 'run dev'; exit 0
