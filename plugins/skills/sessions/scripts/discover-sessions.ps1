# Discover session files across Claude Code, Codex, and Cursor.
#
# PowerShell 5.1-compatible port of discover-sessions.sh. Outputs one file path
# per line (native Windows paths). `find -mtime -<days>` is replaced with a
# LastWriteTime cutoff; `$HOME` with `$env:USERPROFILE`.
#
# Usage: discover-sessions.ps1 <repo-name> <days> [--platform claude|codex|cursor]
#   repo-name  Folder name of the repo (e.g., "my-repo"). Used for dir matching.
#   days       Scan window in days. Files older than this are skipped.
#   --platform Restrict to a single platform. Omit to search all.

$ErrorActionPreference = 'Stop'

# Positional + optional --platform parsing (mirrors the bash positional contract).
$RepoName = $args[0]
$DaysArg = $args[1]
$Platform = 'all'
for ($i = 2; $i -lt $args.Count; $i++) {
  if ($args[$i] -eq '--platform') { $Platform = $args[$i + 1]; $i++ }
}

if ([string]::IsNullOrWhiteSpace($RepoName) -or [string]::IsNullOrWhiteSpace($DaysArg)) {
  [Console]::Error.WriteLine("Usage: discover-sessions.ps1 <repo-name> <days> [--platform claude|codex|cursor]")
  exit 1
}
$Days = [int]$DaysArg
$cutoff = (Get-Date).AddDays(-$Days)
$userHome = $env:USERPROFILE

# Emit *.jsonl under $dir modified within the scan window. $recurse controls
# whether subdirectories are searched (find default vs. -maxdepth 1).
function Emit-Jsonl($dir, $recurse) {
  if (-not (Test-Path -LiteralPath $dir -PathType Container)) { return }
  $params = @{ LiteralPath = $dir; Filter = '*.jsonl'; File = $true; ErrorAction = 'SilentlyContinue' }
  if ($recurse) { $params['Recurse'] = $true }
  Get-ChildItem @params | Where-Object { $_.LastWriteTime -ge $cutoff } | ForEach-Object { Write-Output $_.FullName }
}

function Discover-Claude {
  $base = Join-Path $userHome '.claude/projects'
  if (-not (Test-Path -LiteralPath $base -PathType Container)) { return }
  Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "*$RepoName*" } |
    ForEach-Object { Emit-Jsonl $_.FullName $false }
}

function Discover-Codex {
  foreach ($base in @((Join-Path $userHome '.codex/sessions'), (Join-Path $userHome '.agents/sessions'))) {
    Emit-Jsonl $base $true
  }
}

function Discover-Cursor {
  $base = Join-Path $userHome '.cursor/projects'
  if (-not (Test-Path -LiteralPath $base -PathType Container)) { return }
  Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "*$RepoName*" } |
    ForEach-Object {
      $transcripts = Join-Path $_.FullName 'agent-transcripts'
      Emit-Jsonl $transcripts $true
    }
}

switch ($Platform) {
  'claude' { Discover-Claude }
  'codex'  { Discover-Codex }
  'cursor' { Discover-Cursor }
  'all'    { Discover-Claude; Discover-Codex; Discover-Cursor }
  default  {
    [Console]::Error.WriteLine("Unknown platform: $Platform")
    exit 1
  }
}
