# resolve-port.ps1 -- resolve the dev-server port for a project.
#
# PowerShell 5.1-compatible port of resolve-port.sh. stdout contract is
# identical: a single line with the resolved port number. stderr is reserved
# for ERROR: messages only. Probe order and first-hit-wins semantics match the
# bash version exactly (see resolve-port.sh header for the full rationale).
#
# Usage: resolve-port.ps1 [path] [--type <type>] [--port <n>]

# -- Argument parsing (mirrors the bash positional + flag contract) -----------
$ProjectRoot = ''
$ProjType = ''
$ExplicitPort = ''
for ($i = 0; $i -lt $args.Count; $i++) {
  switch ($args[$i]) {
    '--type' { $ProjType = $args[$i + 1]; $i++ }
    '--port' { $ExplicitPort = $args[$i + 1]; $i++ }
    default  { if ($ProjectRoot -eq '') { $ProjectRoot = $args[$i] } }
  }
}

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = (git rev-parse --show-toplevel 2>$null | Select-Object -First 1)
  if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    [Console]::Error.WriteLine("ERROR: not in a git repository and no path provided")
    exit 1
  }
}
if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
  [Console]::Error.WriteLine("ERROR: path does not exist: $ProjectRoot")
  exit 1
}

# -- Helpers ------------------------------------------------------------------

# Returns $true if the probe should run for the given --type.
function Should-Probe($ptype, $probe) {
  if ([string]::IsNullOrEmpty($ptype)) { return $true }  # no filter -- run all
  switch ($ptype) {
    'rails' { return @('puma', 'procfile', 'docker-compose', 'env', 'default') -contains $probe }
    { @('next', 'nuxt', 'astro', 'remix', 'vite', 'sveltekit') -contains $_ } {
      return @('framework-config', 'package-json', 'env', 'default') -contains $probe
    }
    'procfile' { return @('procfile', 'docker-compose', 'env', 'default') -contains $probe }
    default { return $true }  # unknown type -- run all probes
  }
}

# Parses PORT=<n> from the given file. Strips surrounding quotes and inline
# comments. Returns the port string or $null.
function Parse-EnvPort($envfile) {
  if (-not (Test-Path -LiteralPath $envfile -PathType Leaf)) { return $null }
  $line = Get-Content -LiteralPath $envfile -ErrorAction SilentlyContinue |
    Where-Object { $_ -match '^PORT=' } | Select-Object -Last 1
  if ([string]::IsNullOrEmpty($line)) { return $null }

  $value = $line -replace '^PORT=', ''
  # Comment stripping must happen BEFORE quote stripping so
  # PORT="3001" # comment -> "3001" -> 3001
  $value = $value -replace '^\s*', '' -replace '\s*#.*$', '' -replace '\s*$', ''
  # Strip surrounding double quotes, then single quotes.
  $value = $value -replace '^"', '' -replace '"$', ''
  $value = $value -replace "^'", '' -replace "'$", ''
  $value = $value.Trim()
  if ($value) { return $value }
  return $null
}

# -- Probe 1: Explicit --port flag --------------------------------------------
if (-not [string]::IsNullOrEmpty($ExplicitPort)) {
  Write-Output $ExplicitPort
  exit 0
}

# -- Probe 2: Framework config files ------------------------------------------
if (Should-Probe $ProjType 'framework-config') {
  $names = @(
    'next.config.js', 'next.config.ts', 'next.config.mjs', 'next.config.cjs',
    'vite.config.js', 'vite.config.ts', 'vite.config.mjs', 'vite.config.cjs',
    'nuxt.config.js', 'nuxt.config.ts', 'nuxt.config.mjs', 'nuxt.config.cjs',
    'astro.config.js', 'astro.config.ts', 'astro.config.mjs', 'astro.config.cjs'
  )
  foreach ($name in $names) {
    $cfg = Join-Path $ProjectRoot $name
    if (-not (Test-Path -LiteralPath $cfg -PathType Leaf)) { continue }
    $line = Get-Content -LiteralPath $cfg -ErrorAction SilentlyContinue |
      Where-Object { $_ -match 'port:\s*["'']?\d+' } | Select-Object -First 1
    if ([string]::IsNullOrEmpty($line)) { continue }
    $m = [regex]::Match($line, 'port:\s*["'']?(\d+)["'']?')
    if (-not $m.Success) { continue }
    $port = $m.Groups[1].Value
    # Reject variable references: nothing non-structural may follow the literal.
    $after = $line.Substring($m.Index + $m.Length)
    if ($after -eq '' -or $after -match '^[\s,})]*$') {
      Write-Output $port
      exit 0
    }
  }
}

# -- Probe 3: Rails config/puma.rb --------------------------------------------
if (Should-Probe $ProjType 'puma') {
  $pumaFile = Join-Path $ProjectRoot 'config/puma.rb'
  if (Test-Path -LiteralPath $pumaFile -PathType Leaf) {
    $m = [regex]::Match((Get-Content -Raw -LiteralPath $pumaFile), 'port\s+(\d+)')
    if ($m.Success) { Write-Output $m.Groups[1].Value; exit 0 }
  }
}

# -- Probe 4: Procfile.dev ----------------------------------------------------
if (Should-Probe $ProjType 'procfile') {
  $procfile = Join-Path $ProjectRoot 'Procfile.dev'
  if (Test-Path -LiteralPath $procfile -PathType Leaf) {
    $webLine = Get-Content -LiteralPath $procfile -ErrorAction SilentlyContinue |
      Where-Object { $_ -match '^web:' } | Select-Object -First 1
    if (-not [string]::IsNullOrEmpty($webLine)) {
      $m = [regex]::Match($webLine, '(-p[= ]*|--port[= ]+)(\d+)')
      if ($m.Success) { Write-Output $m.Groups[2].Value; exit 0 }
    }
  }
}

# -- Probe 5: docker-compose.yml ----------------------------------------------
if (Should-Probe $ProjType 'docker-compose') {
  $composeFile = Join-Path $ProjectRoot 'docker-compose.yml'
  if (Test-Path -LiteralPath $composeFile -PathType Leaf) {
    $m = [regex]::Match((Get-Content -Raw -LiteralPath $composeFile), '"(\d+):(\d+)"')
    if ($m.Success) { Write-Output $m.Groups[1].Value; exit 0 }
  }
}

# -- Probe 6: package.json scripts --------------------------------------------
if (Should-Probe $ProjType 'package-json') {
  $pkgFile = Join-Path $ProjectRoot 'package.json'
  if (Test-Path -LiteralPath $pkgFile -PathType Leaf) {
    $m = [regex]::Match((Get-Content -Raw -LiteralPath $pkgFile), '(-p[= ]+|--port[= ]+)(\d+)')
    if ($m.Success) { Write-Output $m.Groups[2].Value; exit 0 }
  }
}

# -- Probe 7: .env files ------------------------------------------------------
if (Should-Probe $ProjType 'env') {
  foreach ($envname in @('.env.local', '.env.development', '.env')) {
    $envPort = Parse-EnvPort (Join-Path $ProjectRoot $envname)
    if (-not [string]::IsNullOrEmpty($envPort)) {
      Write-Output $envPort
      exit 0
    }
  }
}

# -- Probe 8: Framework default lookup table ----------------------------------
if (Should-Probe $ProjType 'default') {
  switch ($ProjType) {
    { @('rails', 'next', 'nuxt', 'remix', 'procfile', '') -contains $_ } { Write-Output '3000'; exit 0 }
    { @('vite', 'sveltekit') -contains $_ } { Write-Output '5173'; exit 0 }
    'astro' { Write-Output '4321'; exit 0 }
    default { Write-Output '3000'; exit 0 }
  }
}

# Final fallback (should not normally be reached)
Write-Output '3000'
exit 0
