<#
.SYNOPSIS
  cross-model-pov.ps1 — PowerShell 5.1 twin of cross-model-pov.sh.

  Args (positional): HOST_PROVIDER FIXED_ROUTE PAYLOAD_PATH RUN_DIR
  Fixed-route only: runs the one host-sanctioned route, writes $RUN_DIR/pov-<provider>.json
  carrying the POV fold-in envelope. Non-blocking skip -> exit 0. --emit-adapter <route>
  prints argv. Sibling parity with cross-model-{adversarial-review,doc-review,pov}.sh/.ps1.
  Targets PS 5.1. JSON via ConvertFrom/ConvertTo-Json (no jq dep).
#>
$ErrorActionPreference = "Stop"
$prevOutEnc = [Console]::OutputEncoding; $prevPrefEnc = $OutputEncoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; $OutputEncoding = [System.Text.Encoding]::UTF8

if ($args.Count -ge 1 -and $args[0] -eq "--emit-adapter") {
  $HostProviderArg = "--emit-adapter"; $FIXED_ROUTE = if ($args.Count -ge 2) { $args[1] } else { "" }
} else {
  $HostProviderArg = if ($args.Count -ge 1) { $args[0] } else { "unknown" }
  $FIXED_ROUTE     = if ($args.Count -ge 2) { $args[1] } else { "" }
  $PAYLOAD_PATH    = if ($args.Count -ge 3) { $args[2] } else { "" }
  $RunDir          = if ($args.Count -ge 4) { $args[3] } else { "" }
}

$script:M_CODEX="gpt-5.6-sol"; $script:M_CLAUDE="opus"; $script:M_GROK="grok-4.5"
$script:M_GROK_CURSOR="cursor-grok-4.5-high"; $script:M_COMPOSER="composer-2.5-fast"

function Log  { param([string]$Msg) [Console]::Error.WriteLine("[cross-model-pov] $Msg") }
function Skip { param([string]$Msg) Log $Msg; [Console]::OutputEncoding=$prevOutEnc; $OutputEncoding=$prevPrefEnc; exit 0 }
function Expected-ModelPrefix { param([string]$a) switch ($a){"opus"{"claude-opus-"}"sonnet"{"claude-sonnet-"}"haiku"{"claude-haiku-"}}; return "" }
function Route-Target { param([string]$r) switch -Wildcard($r){"codex"{"codex"}"claude"{"claude"}"cursor"{"cursor"}"composer"{"composer"}"grok-*"{"grok"}}; return "" }
function Route-Model { param([string]$r)
  $t=Route-Target $r; $ov=$env:CROSS_MODEL_MODEL_OVERRIDE; $ovt=$env:CROSS_MODEL_MODEL_OVERRIDE_TARGET
  if($ov -and $ovt -eq $t -and $t -ne "cursor"){return $ov}
  switch($r){"codex"{return $script:M_CODEX}"claude"{return $script:M_CLAUDE}"grok-cli"{return $script:M_GROK}"grok-cursor"{return $script:M_GROK_CURSOR}"cursor"{return "auto"}"composer"{return $script:M_COMPOSER}}; return "" }
function Route-Harness { param([string]$r) switch -Wildcard($r){"codex"{"codex"}"claude"{"claude"}"grok-cli"{"grok"}default{"cursor-agent"}} }
function Target-ServingFamily { param([string]$t) switch($t){"codex"{"codex"}"claude"{"claude"}"grok"{"grok"}"composer"{"composer"}"cursor"{"unknown"}}; return "unknown" }

# POV adapter: codex uses --search + READ_ROOT; claude allowlist; grok denies (no --disable-web-search).
function Get-AdapterArgv { param([string]$route,[string]$ReadRoot,[string]$RawOut,[string]$PromptFile,[string]$SchemaRef)
  switch ($route) {
    "codex" { return @("codex","--search","exec","-","-C",$ReadRoot,"--skip-git-repo-check","-s","read-only","-o",$RawOut,"-m",(Route-Model "codex"),"-c",'model_reasoning_effort="high"',"-c",'hide_agent_reasoning=false') }
    "claude" { return @("claude","-p","--model",(Route-Model "claude"),"--effort","high","--permission-mode","dontAsk","--bare","--tools","Read,Glob,Grep,WebSearch,WebFetch","--max-turns","15","--no-session-persistence","--json-schema",$SchemaRef,"--output-format","json") }
    "grok-cli" { return @("grok","--prompt-file",$PromptFile,"--model",(Route-Model "grok-cli"),"--effort","high","--cwd",$ReadRoot,"--permission-mode","dontAsk","--deny","Edit","--deny","Write","--deny","Bash","--deny","Task","--deny","mcp__*","--no-subagents","--max-turns","15","--json-schema",$SchemaRef,"--output-format","json") }
    "grok-cursor" { return @("cursor-agent","-p","--model",(Route-Model "grok-cursor"),"--mode","ask","--trust","--sandbox","enabled","--workspace",$ReadRoot,"--output-format","json") }
    "cursor" { return @("cursor-agent","-p","--mode","ask","--trust","--sandbox","enabled","--workspace",$ReadRoot,"--output-format","json") }
    "composer" { return @("cursor-agent","-p","--model",(Route-Model "composer"),"--mode","ask","--trust","--sandbox","enabled","--workspace",$ReadRoot,"--output-format","json") }
  }
  throw "unknown route"
}

$script:ModelActual="unverified"
function Extract-ModelReceipt { param([string]$route,[string]$PeerLog)
  $script:ModelActual="unverified"; if($route -ne "claude"){return}; if(-not(Test-Path $PeerLog)){return}
  $requested=Route-Model "claude"; $prefix=Expected-ModelPrefix $requested
  try{$e=Get-Content -Raw $PeerLog|ConvertFrom-Json -ErrorAction Stop}catch{Log "model receipt absent/unparseable on claude route; recording unverified";return}
  if($null -eq $e.modelUsage){return}
  $matched=$null; if($prefix){foreach($k in $e.modelUsage.PSObject.Properties.Name){if($k.StartsWith($prefix)){$matched=$k;break}}}
  if($matched){$script:ModelActual=$matched;return}
  $keys=@($e.modelUsage.PSObject.Properties.Name); if($keys.Count -eq 0){return}
  $script:ModelActual=$keys[0]; Log "WARNING: model mismatch - requested $requested, backend served $($keys[0]); reconcile must surface this"
}

$script:ActivePeerPid=0
function Invoke-PeerRun { param([string[]]$Argv,[string]$StdinFile,[string]$PeerLog,[string]$PeerErr,[int]$IdleSecs,[int]$HardSecs,[string]$PeerCwd,[ref]$ExitCode)
  # Empty stdin (grok-cli reads --prompt-file) would crash Start-Process under Stop mode;
  # substitute a temp empty file (bash twin uses /dev/null).
  $stdinTmp=$null
  if(-not $StdinFile){ $stdinTmp=Join-Path $env:TEMP ("xmodel-stdin-"+[guid]::NewGuid().ToString("N")); New-Item -ItemType File -Path $stdinTmp -Force|Out-Null; $StdinFile=$stdinTmp }
  try {
    $proc=Start-Process -FilePath $Argv[0] -ArgumentList ($Argv[1..($Argv.Length-1)]) -WorkingDirectory $PeerCwd -NoNewWindow -PassThru -RedirectStandardOutput $PeerLog -RedirectStandardError $PeerErr -RedirectStandardInput $StdinFile
    $script:ActivePeerPid=$proc.Id; $start=Get-Date; $lastSize=0; $lastGrowth=$start; $exited=$false
    $hbEvery=60; if($env:CROSS_MODEL_HEARTBEAT_SECS){$hbEvery=[int]$env:CROSS_MODEL_HEARTBEAT_SECS}; if($hbEvery -lt 1){$hbEvery=1}; $lastHb=$start
    while(-not $exited){ if($proc.WaitForExit(2000)){$exited=$true;break}; $now=Get-Date
      try{$size=(Get-Item $PeerLog -ErrorAction Stop).Length}catch{$size=$lastSize}
      if($size -ne $lastSize){$lastSize=$size;$lastGrowth=$now}
      if(((New-TimeSpan -Start $lastGrowth -End $now).TotalSeconds) -ge $IdleSecs){Log "peer output idle ${IdleSecs}s; killing peer tree";break}
      if(((New-TimeSpan -Start $start -End $now).TotalSeconds) -ge $HardSecs){Log "peer exceeded hard cap ${HardSecs}s; killing peer tree";break}
      if(((New-TimeSpan -Start $lastHb -End $now).TotalSeconds) -ge $hbEvery){Log ("peer alive ($([int](New-TimeSpan -Start $start -End $now).TotalSeconds)s elapsed)");$lastHb=$now} }
    & taskkill /PID $proc.Id /T /F 2>$null|Out-Null; $proc.WaitForExit(5000)|Out-Null
    if(-not $exited){ $ExitCode.Value=-1; return $false }
    $ExitCode.Value=$proc.ExitCode; return ($proc.ExitCode -eq 0)
  } finally { if($stdinTmp){ Remove-Item $stdinTmp -Force -ErrorAction SilentlyContinue } }
}

# POV predicate: voice/position/reasoning non-empty strings, evidence array, valid enum fields.
function Test-ValidPov { param($o)
  if($null -eq $o){return $false}
  return ($o.voice -is [string] -and $o.voice.Length -gt 0) -and ($o.position -is [string] -and $o.position.Length -gt 0) `
    -and ($o.reasoning -is [string] -and $o.reasoning.Length -gt 0) -and ($o.evidence -is [System.Array]) `
    -and (@("ran","unavailable") -contains $o.external_check) `
    -and (@("independent","skeptic") -contains $o.mode) `
    -and (@("initial","moved","held") -contains $o.movement)
}
# Recover a POV-shaped object from raw stdout via python brace-match.
function Recover-PovJson { param([string]$LogFile,[string]$OutFile)
  $py=Get-Command python -ErrorAction SilentlyContinue; if(-not $py){$py=Get-Command python3 -ErrorAction SilentlyContinue}; if(-not $py){return $false}
  $script=@"
import sys,json
txt=open(sys.argv[1],encoding='utf-8',errors='replace').read()
best,depth,start=None,0,None
for i,ch in enumerate(txt):
    if ch=='{':
        if depth==0:start=i
        depth+=1
    elif ch=='}' and depth>0:
        depth-=1
        if depth==0 and start is not None:
            try:
                obj=json.loads(txt[start:i+1])
                req=('voice','position','reasoning','evidence','external_check','mode','movement')
                if isinstance(obj,dict) and all(k in obj for k in req):best=obj
            except Exception:pass
if best is not None:open(sys.argv[2],'w').write(json.dumps(best))
"@
  $tmp=[System.IO.Path]::GetTempFileName(); try{Set-Content -Path $tmp -Value $script -Encoding UTF8; & $py.Source $tmp $LogFile $OutFile 2>$null|Out-Null}finally{Remove-Item $tmp -Force -ErrorAction SilentlyContinue}
  return ((Test-Path $OutFile) -and ((Get-Item $OutFile).Length -gt 0))
}
function Test-OutMissingOrInvalid { param([string]$RawOut)
  if(-not(Test-Path $RawOut)){return $true}; if((Get-Item $RawOut).Length -eq 0){return $true}
  try{$o=Get-Content -Raw $RawOut|ConvertFrom-Json -ErrorAction Stop}catch{return $true}
  return -not (Test-ValidPov $o)
}
function Test-RouteAllowlisted { param([string]$route)
  $ALLOW=$env:CROSS_MODEL_PEERS; if(-not $ALLOW){return $true}
  $t=Route-Target $route
  if($t -eq "cursor"){return (($ALLOW -split ',') -contains 'cursor')}
  if($t -eq "grok"){return (($ALLOW -split ',') -contains 'grok') -or (($ALLOW -split ',') -contains 'composer') -or (($ALLOW -split ',') -contains 'cursor')}
  return (($ALLOW -split ',') -contains $t)
}
function Test-RouteAvailable { param([string]$route)
  switch($route){"codex"{return [bool](Get-Command codex -ErrorAction SilentlyContinue)}"claude"{return [bool](Get-Command claude -ErrorAction SilentlyContinue)}
    "grok-cli"{return [bool](Get-Command grok -ErrorAction SilentlyContinue)}default{return [bool](Get-Command cursor-agent -ErrorAction SilentlyContinue)}} }
function Apply-ModelOverride { param([string]$route)  # pov (fixed-route): returns false if override incompatible
  $ov=$env:CROSS_MODEL_MODEL_OVERRIDE; $ovt=$env:CROSS_MODEL_MODEL_OVERRIDE_TARGET
  if(-not $ov){ return (-not $ovt) }
  if(-not $ovt){ return $false }
  $t=Route-Target $route; if(-not $t){ return $false }
  if($ovt -ne $t){ return $false }                   # cross-target: pov runs ONE fixed route -> incompatible
  if($t -eq "cursor"){ return $false }
  switch -Wildcard ("${route}:$ov"){"codex:gpt-*"{return $true}"codex:o[0-9]*"{return $true}"claude:opus"{return $true}"claude:sonnet"{return $true}"claude:haiku"{return $true}"claude:claude-*"{return $true}"grok-cli:grok-*"{return $true}"grok-cursor:cursor-grok-*"{return $true}"composer:composer-*"{return $true}default{return $false}} }

# === --emit-adapter ===
if ($HostProviderArg -eq "--emit-adapter") {
  $route=$FIXED_ROUTE
  try{ if(-not(Apply-ModelOverride $route)){[Console]::Error.WriteLine("model override '$env:CROSS_MODEL_MODEL_OVERRIDE' not compatible with route '$route'");exit 2}
       $null=Get-AdapterArgv $route "<read-root>" "<peer-workdir>/pov-<provider>.raw.json" "<prompt-file>" "<schema>" }
  catch{ [Console]::Error.WriteLine("unknown route '$route' (want codex|claude|grok-cli|grok-cursor|cursor|composer)"); exit 2 }
  (Get-AdapterArgv $route "<read-root>" "<peer-workdir>/pov-<provider>.raw.json" "<prompt-file>" "<schema>") -join ' '; exit 0
}

# === main flow ===
$HOST_PROVIDER=$HostProviderArg; $HOST_HARNESS= if($env:CROSS_MODEL_HOST_HARNESS){$env:CROSS_MODEL_HOST_HARNESS}else{"unknown"}
if(-not $PAYLOAD_PATH -or -not(Test-Path $PAYLOAD_PATH -PathType Leaf)){Skip "subject payload '$PAYLOAD_PATH' not readable on disk; skipping"}
$READ_ROOT= if($env:CROSS_MODEL_READ_ROOT){$env:CROSS_MODEL_READ_ROOT}else{(Get-Location).Path}
if(-not(Test-Path $READ_ROOT -PathType Container)){Skip "declared repository/read root '$READ_ROOT' is not a directory"}
$READ_ROOT=(Resolve-Path $READ_ROOT).Path
$RUN_DIR_RESOLVED= if($RunDir){(Resolve-Path $RunDir -ErrorAction SilentlyContinue).Path}else{""}
if($RUN_DIR_RESOLVED -and $READ_ROOT -and $RUN_DIR_RESOLVED.StartsWith($READ_ROOT.TrimEnd('\','/') + [System.IO.Path]::DirectorySeparatorChar)){Skip "run-dir must be outside the repository"}
if(-not $RUN_DIR_RESOLVED -or -not(Test-Path $RUN_DIR_RESOLVED -PathType Container)){Skip "run-dir '$RunDir' must already exist"}
$RunDir=$RUN_DIR_RESOLVED
switch($HOST_PROVIDER){"codex"{}"claude"{}"grok"{}"composer"{}"unknown"{}default{Skip "host serving family '$HOST_PROVIDER' invalid"}}
switch($HOST_HARNESS){"codex"{}"claude"{}"grok"{}"cursor"{}"unknown"{}default{Skip "host harness '$HOST_HARNESS' invalid"}}
if("codex","claude","grok-cli","grok-cursor","cursor","composer" -notcontains $FIXED_ROUTE){Skip "unknown fixed route '$FIXED_ROUTE'; host must resolve one route before egress"}
$TARGET=Route-Target $FIXED_ROUTE
if(-not(Apply-ModelOverride $FIXED_ROUTE)){Skip "model override '$env:CROSS_MODEL_MODEL_OVERRIDE' not compatible with route '$FIXED_ROUTE'"}

$SKILL_ROOT=(Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$PERSONA=Join-Path $SKILL_ROOT "references/agents/pov-peer.md"; $SCHEMA=Join-Path $SKILL_ROOT "references/pov-schema.json"
if(-not(Test-Path $PERSONA)){Skip "persona brief not found at $PERSONA; skipping"}
if(-not(Test-Path $SCHEMA)){Skip "POV schema not found at $SCHEMA; skipping"}
$SCHEMA_CONTENT=Get-Content -Raw $SCHEMA; $SCHEMA_REF=$SCHEMA_CONTENT

$MAX_PAYLOAD_CHARS= if($env:CROSS_MODEL_MAX_PAYLOAD_CHARS){[int]$env:CROSS_MODEL_MAX_PAYLOAD_CHARS}else{200000}
$PAYLOAD_CHARS=(Get-Item $PAYLOAD_PATH).Length
if($PAYLOAD_CHARS -gt $MAX_PAYLOAD_CHARS){Skip "subject payload is $PAYLOAD_CHARS bytes (limit $MAX_PAYLOAD_CHARS); skipping cross-model pass rather than truncating"}

if(-not(Test-RouteAllowlisted $FIXED_ROUTE)){Skip "fixed route '$FIXED_ROUTE' is not fully sanctioned by CROSS_MODEL_PEERS; skipping before egress"}
if(-not(Test-RouteAvailable $FIXED_ROUTE)){Skip "fixed route '$FIXED_ROUTE' is unavailable; host must disclose and choose any retry"}
Log "fixed cross-model POV route: target=$TARGET route=$FIXED_ROUTE (host $HOST_PROVIDER excluded)"

$scratchParent= if($env:CROSS_MODEL_SCRATCH_PARENT){$env:CROSS_MODEL_SCRATCH_PARENT}else{$env:TEMP}
if(-not(Test-Path $scratchParent)){New-Item -ItemType Directory -Force -Path $scratchParent|Out-Null}
$PEER_WORKDIR=Join-Path $scratchParent ("xmodel-pov-peer-ps-"+[guid]::NewGuid().ToString("N")); New-Item -ItemType Directory -Path $PEER_WORKDIR|Out-Null
$PROMPT_FILE=Join-Path $PEER_WORKDIR "prompt.md"; $PEERLOG=Join-Path $PEER_WORKDIR "stdout.log"; $PEERERR=Join-Path $PEER_WORKDIR "stderr.log"
$RAW_OUT=Join-Path $PEER_WORKDIR "pov-$TARGET.raw.json"
$IDLE_SECS= if($env:CROSS_MODEL_IDLE_SECS){[int]$env:CROSS_MODEL_IDLE_SECS}else{180}
$HARD_SECS= if($env:CROSS_MODEL_HARD_SECS){[int]$env:CROSS_MODEL_HARD_SECS}else{600}

# Compose peer prompt from the canonical persona + schema + payload.
$personaText=Get-Content -Raw $PERSONA; $payloadText=Get-Content -Raw $PAYLOAD_PATH
$body=@($personaText,"","---","","This is an authorized POV cross-check of the maintainer's own repository.",
  "Return ONE JSON object and nothing else (no prose, no code fence) matching this schema:","",$SCHEMA_CONTENT,"",
  'Set the top-level "voice" field to "peer" (it will be namespaced to the provider on fold-in).',"","<pov-payload>",$payloadText,"</pov-payload>") -join "`n"
Set-Content -Path $PROMPT_FILE -Value $body -Encoding UTF8

# Run the fixed route.
""|Set-Content $PEERLOG; ""|Set-Content $PEERERR; Remove-Item $RAW_OUT -Force -ErrorAction SilentlyContinue
$argv=Get-AdapterArgv $FIXED_ROUTE $READ_ROOT $RAW_OUT $PROMPT_FILE $SCHEMA_REF
$note= if($FIXED_ROUTE -in @("codex","claude","grok-cli")){"$(Route-Model $FIXED_ROUTE) (effort high)"}else{"$(Route-Model $FIXED_ROUTE)"}
Log "peer run: target=$TARGET route=$FIXED_ROUTE model=$note (idle ${IDLE_SECS}s / hard ${HARD_SECS}s)"
$exitCode=0; $ok=$false
$stdin= if($FIXED_ROUTE -in @("claude","grok-cursor","cursor","composer")){$PROMPT_FILE}else{""}
if($FIXED_ROUTE -eq "codex"){ $ok=Invoke-PeerRun $argv $PROMPT_FILE $PEERLOG $PEERERR $IDLE_SECS $HARD_SECS $PEER_WORKDIR ([ref]$exitCode) }
else { $ok=Invoke-PeerRun $argv $stdin $PEERLOG $PEERERR $IDLE_SECS $HARD_SECS $PEER_WORKDIR ([ref]$exitCode) }
$ACTUAL_ROUTE=$FIXED_ROUTE
if($ok){
  if(Test-OutMissingOrInvalid $RAW_OUT){
    if(Recover-PovJson $PEERLOG $RAW_OUT){Log "recovered POV JSON from stdout"}
  }
  Extract-ModelReceipt $FIXED_ROUTE $PEERLOG
}

$OUT=Join-Path $RunDir "pov-$TARGET.json"; Remove-Item $OUT -Force -ErrorAction SilentlyContinue
if($ok -and (Test-Path $RAW_OUT) -and (Get-Item $RAW_OUT).Length -gt 0){
  try{ $raw=Get-Content -Raw $RAW_OUT|ConvertFrom-Json -ErrorAction Stop }catch{ $raw=$null }
  if($raw -and (Test-ValidPov $raw)){
    $fam= if($ACTUAL_ROUTE -eq "cursor"){"unknown"}elseif($script:ModelActual -eq "unverified" -and $ACTUAL_ROUTE -in @("composer","grok-cursor")){"unknown"}else{Target-ServingFamily $TARGET}
    $independent=($HOST_PROVIDER -ne "unknown") -and ($fam -ne "unknown") -and ($HOST_PROVIDER -ne $fam)
    $folded=[pscustomobject]@{
      voice="peer-$TARGET"; cross_model_route=$ACTUAL_ROUTE; cross_model_target=$TARGET
      cross_model_harness=(Route-Harness $ACTUAL_ROUTE); serving_family=$fam
      model_requested=(Route-Model $ACTUAL_ROUTE); model_actual=$script:ModelActual; independence_verified=$independent
      position=$raw.position; reasoning=$raw.reasoning; evidence=@($raw.evidence)
      external_check=$raw.external_check; mode=$raw.mode; movement=$raw.movement }
    $folded|ConvertTo-Json -Depth 20|Set-Content -Path $OUT -Encoding UTF8
  }
  Remove-Item $RAW_OUT -Force -ErrorAction SilentlyContinue
}
if((Test-Path $OUT) -and (Get-Item $OUT).Length -gt 0){
  try{ $chk=Get-Content -Raw $OUT|ConvertFrom-Json -ErrorAction Stop
    if((Test-ValidPov $chk) -and ($chk.independence_verified -is [bool])){ Log "wrote peer POV to $OUT (voice peer-$TARGET)" }
    else{ Log "peer produced no usable POV; skipping fold-in"; Remove-Item $OUT -Force -ErrorAction SilentlyContinue } }
  catch{ Log "peer produced no usable POV; skipping fold-in"; Remove-Item $OUT -Force -ErrorAction SilentlyContinue }
} else {
  if(-not $ok){ Log "peer run failed or produced no output; skipping" }
  else { Log "peer produced no usable POV; skipping fold-in" }
  foreach($pf in @($PEERLOG,$PEERERR)){ if((Test-Path $pf) -and (Get-Item $pf).Length -gt 0){ $t=(Get-Content -Raw $pf)-replace "`r?`n"," "; if($t.Length -gt 300){$t=$t.Substring($t.Length-300)}; $tag=if($pf -eq $PEERERR){" (stderr)"}else{""}; Log "  peer skip evidence${tag}: $t" } }
}
Remove-Item -Recurse -Force $PEER_WORKDIR -ErrorAction SilentlyContinue
[Console]::OutputEncoding=$prevOutEnc; $OutputEncoding=$prevPrefEnc
exit 0
