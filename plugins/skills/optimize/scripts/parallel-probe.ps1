# Parallelism Probe (PowerShell 5.1-compatible port of parallel-probe.sh).
# Detects common parallelism blockers in the target project. Output is advisory.
# Unlike the bash version, JSON is assembled natively, so python3 is NOT required.
#
# Usage: parallel-probe.ps1 <project_directory> [measurement_command] [measurement_workdir] [shared_file ...]
#
# Output: JSON to stdout with
#   mode: "parallel" | "serial" | "user-decision"
#   blockers: [ { type, description, suggestion } ]
#   blocker_count: <n>

$projectDir = $args[0]
if ([string]::IsNullOrWhiteSpace($projectDir)) {
  [Console]::Error.WriteLine("Error: project_directory argument required")
  exit 1
}
$measurementCmd = if ($args.Count -ge 2) { $args[1] } else { '' }
$measurementWorkdir = if ($args.Count -ge 3 -and -not [string]::IsNullOrEmpty($args[2])) { $args[2] } else { '.' }
$sharedFiles = @($args | Select-Object -Skip 3)

try {
  Set-Location -LiteralPath $projectDir -ErrorAction Stop
} catch {
  Write-Output '{"mode":"serial","blockers":[{"type":"error","description":"Cannot access project directory","suggestion":"Check path"}]}'
  exit 0
}

$blockers = New-Object System.Collections.Generic.List[object]
function Add-Blocker($type, $desc, $suggestion) {
  $blockers.Add([ordered]@{ type = $type; description = $desc; suggestion = $suggestion })
}

$scanPaths = New-Object System.Collections.Generic.List[string]
function Add-ScanPath($candidate) {
  if ([string]::IsNullOrEmpty($candidate)) { return }
  if (Test-Path -LiteralPath $candidate) { $scanPaths.Add($candidate) }
}
Add-ScanPath $measurementWorkdir
foreach ($sf in $sharedFiles) { Add-ScanPath $sf }
if ($scanPaths.Count -eq 0) { $scanPaths.Add('.') }

# True if $name matches one of $patterns (wildcards) and is not an excluded name.
function Test-FileMatch($name, $patterns, $excludeNames) {
  foreach ($ex in $excludeNames) { if ($name -eq $ex) { return $false } }
  foreach ($p in $patterns) { if ($name -like $p) { return $true } }
  return $false
}

# Bounded BFS replacement for `find -maxdepth 4 ... ! -path '*/excluded/*'`.
# Returns up to 10 matching file paths. $maxDepth=3 dirs => files up to depth 4.
function Find-ProbeFiles($roots, $patterns, $excludeNames) {
  $excludeSeg = @('.git', 'node_modules', '.claude', '.context', '.worktrees')
  $results = New-Object System.Collections.Generic.List[string]
  foreach ($root in $roots) {
    if ($results.Count -ge 10) { break }
    $item = Get-Item -LiteralPath $root -Force -ErrorAction SilentlyContinue
    if ($null -eq $item) { continue }
    if (-not $item.PSIsContainer) {
      if (Test-FileMatch $item.Name $patterns $excludeNames) { $results.Add($item.FullName) }
      continue
    }
    $q = New-Object System.Collections.Queue
    $q.Enqueue([pscustomobject]@{ Path = $item.FullName; Depth = 0 })
    while ($q.Count -gt 0 -and $results.Count -lt 10) {
      $cur = $q.Dequeue()
      $kids = Get-ChildItem -LiteralPath $cur.Path -Force -ErrorAction SilentlyContinue
      foreach ($k in $kids) {
        if ($results.Count -ge 10) { break }
        if ($k.PSIsContainer) {
          if ($excludeSeg -contains $k.Name) { continue }
          if ($cur.Depth -lt 3) { $q.Enqueue([pscustomobject]@{ Path = $k.FullName; Depth = $cur.Depth + 1 }) }
        } else {
          if (Test-FileMatch $k.Name $patterns $excludeNames) { $results.Add($k.FullName) }
        }
      }
    }
  }
  return $results
}

# Check 1: Hardcoded ports in measurement command.
if (-not [string]::IsNullOrEmpty($measurementCmd)) {
  if ([regex]::IsMatch($measurementCmd, '(--port(?:\s+|=)[0-9]+|:\s*[0-9]{4,5}|PORT=[0-9]+|localhost:[0-9]+)')) {
    Add-Blocker 'port' 'Measurement command contains hardcoded port reference' 'Parameterize port via environment variable (e.g., PORT=$EVAL_PORT)'
  }
}

# Check 2: SQLite databases in scan paths.
$sqliteFiles = Find-ProbeFiles $scanPaths @('*.db', '*.sqlite', '*.sqlite3') @()
if ($sqliteFiles.Count -gt 0) {
  Add-Blocker 'shared_file' "Found $($sqliteFiles.Count) SQLite database file(s)" 'Copy database files into each experiment worktree'
}

# Check 3: Lock/PID files in scan paths (excluding well-known dependency locks).
$lockExclude = @('package-lock.json', 'yarn.lock', 'bun.lock', 'bun.lockb', 'Gemfile.lock', 'poetry.lock', 'Cargo.lock')
$lockFiles = Find-ProbeFiles $scanPaths @('*.lock', '*.pid') $lockExclude
if ($lockFiles.Count -gt 0) {
  Add-Blocker 'lock_file' "Found $($lockFiles.Count) lock/PID file(s) that may cause contention" 'Ensure measurement command cleans up lock files, or run in serial mode'
}

# Check 4: Exclusive resource hints in the measurement command.
if ((-not [string]::IsNullOrEmpty($measurementCmd)) -and
    [regex]::IsMatch($measurementCmd, '(cuda|gpu|tensorflow|torch|nvidia-smi|CUDA_VISIBLE_DEVICES)', 'IgnoreCase')) {
  Add-Blocker 'exclusive_resource' 'Measurement command appears to use GPU or another exclusive accelerator' 'GPU is typically an exclusive resource -- consider serial mode or device parameterization'
}

# Determine mode.
$blockerCount = $blockers.Count
if ($blockerCount -eq 0) {
  $mode = 'parallel'
} elseif ($blockers | Where-Object { $_.type -eq 'exclusive_resource' }) {
  $mode = 'serial'
} else {
  $mode = 'user-decision'
}

# Assemble JSON deterministically (avoids PowerShell's empty/single-element
# array serialization quirks). Blocker strings are author-controlled and
# contain no double quotes or backslashes.
$blockerJsons = @($blockers | ForEach-Object { $_ | ConvertTo-Json -Compress -Depth 3 })
$blockersArray = '[' + ($blockerJsons -join ',') + ']'
Write-Output ('{"mode":"' + $mode + '","blockers":' + $blockersArray + ',"blocker_count":' + $blockerCount + '}')
