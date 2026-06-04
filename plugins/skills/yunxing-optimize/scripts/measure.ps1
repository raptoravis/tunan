# Measurement Runner (PowerShell 5.1-compatible port of measure.sh).
# Runs a measurement command with a timeout, passing stdout/stderr through to
# the caller. The orchestrating agent (not this script) evaluates gates.
#
# Usage: measure.ps1 <command> <timeout_seconds> [working_directory] [KEY=VALUE ...]
#   command          - Command to run (executed via `cmd.exe /c`, the Windows
#                      analog of bash -c)
#   timeout_seconds  - Maximum seconds before killing the command (and its tree)
#   working_directory - Directory to run in (default: .)
#   KEY=VALUE        - Optional environment variables to set before running
#
# Output:
#   stdout: passed through from the measurement command
#   stderr: passed through from the measurement command
#   exit code: same as the measurement command (124 for timeout)

$command = $args[0]
$timeoutArg = $args[1]
if ([string]::IsNullOrWhiteSpace($command)) { [Console]::Error.WriteLine("Error: command argument required"); exit 1 }
if ([string]::IsNullOrWhiteSpace($timeoutArg)) { [Console]::Error.WriteLine("Error: timeout_seconds argument required"); exit 1 }
$timeout = [int]$timeoutArg

# Pipe through Select-Object so $rest is always a real array (a naive
# `if (...) { @($args[2..N]) }` collapses to a scalar string for a single
# trailing arg, breaking the workdir/env split below).
$rest = @($args | Select-Object -Skip 2)

# First trailing arg without an '=' is the working directory.
$workdir = '.'
$envStart = 0
if ($rest.Count -gt 0 -and ($rest[0] -notmatch '=')) {
  $workdir = $rest[0]
  $envStart = 1
}

# Set any KEY=VALUE environment variables (process scope; inherited by child).
for ($i = $envStart; $i -lt $rest.Count; $i++) {
  $kv = $rest[$i]
  $eq = $kv.IndexOf('=')
  if ($eq -ge 0) {
    $k = $kv.Substring(0, $eq)
    $v = $kv.Substring($eq + 1)
    if ($k) { Set-Item -Path ("Env:" + $k) -Value $v }
  }
}

try {
  Set-Location -LiteralPath $workdir -ErrorAction Stop
} catch {
  [Console]::Error.WriteLine("Error: cannot cd to $workdir")
  exit 1
}

# Launch via cmd.exe /c with inherited console streams (UseShellExecute=$false,
# no redirection) so stdout/stderr pass straight through to our caller.
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $env:ComSpec
if ([string]::IsNullOrEmpty($psi.FileName)) { $psi.FileName = 'cmd.exe' }
$psi.Arguments = '/c ' + $command
$psi.UseShellExecute = $false
$psi.WorkingDirectory = (Get-Location).Path

$proc = [System.Diagnostics.Process]::Start($psi)

if (-not $proc.WaitForExit($timeout * 1000)) {
  # Timed out — kill the whole process tree and report 124 (timeout's contract).
  & taskkill /T /F /PID $proc.Id 2>$null | Out-Null
  exit 124
}

exit $proc.ExitCode
