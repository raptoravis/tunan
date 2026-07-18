<#
.SYNOPSIS
  cross-model-doc-review.ps1 — PowerShell 5.1 twin of cross-model-doc-review.sh.

  Args (positional): HOST_PROVIDER CANDIDATES REVIEWER_NAME DOC_PATH DOC_TYPE ORIGIN RUN_DIR
  Emits one folded JSON object per reachable peer to $RUN_DIR/<reviewer>-<provider>.json.
  Non-blocking: skips log to stderr and exit 0. --emit-adapter <route> prints argv.
  Sibling parity with cross-model-{adversarial-review,doc-review,pov}.sh/.ps1 (verify by diff).
  Targets PS 5.1 (no ??, ternary, -Parallel). JSON via ConvertFrom/ConvertTo-Json (no jq dep).
#>
$ErrorActionPreference = "Stop"
$prevOutEnc = [Console]::OutputEncoding; $prevPrefEnc = $OutputEncoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; $OutputEncoding = [System.Text.Encoding]::UTF8

# Args parsed from $args so "--emit-adapter" is not mistaken for a named parameter.
if ($args.Count -ge 1 -and $args[0] -eq "--emit-adapter") {
  $HostProviderArg = "--emit-adapter"; $REVIEWER_NAME = if ($args.Count -ge 2) { $args[1] } else { "" }
} else {
  $HostProviderArg = if ($args.Count -ge 1) { $args[0] } else { "" }
  $CandidatesRaw   = if ($args.Count -ge 2) { $args[1] } else { "" }
  $REVIEWER_NAME   = if ($args.Count -ge 3) { $args[2] } else { "" }
  $DOC_PATH        = if ($args.Count -ge 4) { $args[3] } else { "" }
  $DOC_TYPE        = if ($args.Count -ge 5) { $args[4] } else { "unified-plan" }
  $ORIGIN          = if ($args.Count -ge 6) { $args[5] } else { "none" }
  $RunDir          = if ($args.Count -ge 7) { $args[6] } else { "" }
}

$script:M_CODEX="gpt-5.6-sol"; $script:M_CLAUDE="opus"; $script:M_GROK="grok-4.5"
$script:M_GROK_CURSOR="cursor-grok-4.5-high"; $script:M_COMPOSER="composer-2.5-fast"

function Log  { param([string]$Msg) [Console]::Error.WriteLine("[cross-model-doc] $Msg") }
function Skip { param([string]$Msg) Log $Msg; [Console]::OutputEncoding=$prevOutEnc; $OutputEncoding=$prevPrefEnc; exit 0 }
function Expected-ModelPrefix { param([string]$a) switch ($a){"opus"{"claude-opus-"}"sonnet"{"claude-sonnet-"}"haiku"{"claude-haiku-"}}; return "" }
function Route-Target { param([string]$r) switch -Wildcard($r){"codex"{"codex"}"claude"{"claude"}"cursor"{"cursor"}"composer"{"composer"}"grok-*"{"grok"}}; return "" }
function Route-Model { param([string]$r)
  $t=Route-Target $r; $ov=$env:CROSS_MODEL_MODEL_OVERRIDE; $ovt=$env:CROSS_MODEL_MODEL_OVERRIDE_TARGET
  if ($ov -and $ovt -eq $t -and $t -ne "cursor"){return $ov}
  switch($r){"codex"{return $script:M_CODEX}"claude"{return $script:M_CLAUDE}"grok-cli"{return $script:M_GROK}"grok-cursor"{return $script:M_GROK_CURSOR}"cursor"{return "auto"}"composer"{return $script:M_COMPOSER}}; return "" }
function Route-Harness { param([string]$r) switch -Wildcard($r){"codex"{"codex"}"claude"{"claude"}"grok-cli"{"grok"}default{"cursor-agent"}} }
function Target-ServingFamily { param([string]$t) switch($t){"codex"{"codex"}"claude"{"claude"}"grok"{"grok"}"composer"{"composer"}"cursor"{"unknown"}}; return "unknown" }

function Get-AdapterArgv { param([string]$route,[string]$PeerWorkdir,[string]$RawOut,[string]$PromptFile,[string]$SchemaRef)
  switch ($route) {
    "codex" { return @("codex","exec","-","-C",$PeerWorkdir,"--skip-git-repo-check","-s","read-only","-o",$RawOut,"-m",(Route-Model "codex"),"-c",'model_reasoning_effort="high"',"-c",'hide_agent_reasoning=false') }
    "claude" { return @("claude","-p","--model",(Route-Model "claude"),"--effort","high","--permission-mode","dontAsk","--bare","--tools","","--max-turns","15","--no-session-persistence","--json-schema",$SchemaRef,"--output-format","json") }
    "grok-cli" { return @("grok","--prompt-file",$PromptFile,"--model",(Route-Model "grok-cli"),"--effort","high","--cwd",$PeerWorkdir,"--permission-mode","dontAsk","--deny","Read","--deny","Edit","--deny","Write","--deny","Bash","--deny","Task","--deny","mcp__*","--disable-web-search","--no-subagents","--max-turns","15","--json-schema",$SchemaRef,"--output-format","json") }
    "grok-cursor" { return @("cursor-agent","-p","--model",(Route-Model "grok-cursor"),"--mode","ask","--trust","--sandbox","enabled","--workspace",$PeerWorkdir,"--output-format","json") }
    "cursor" { return @("cursor-agent","-p","--mode","ask","--trust","--sandbox","enabled","--workspace",$PeerWorkdir,"--output-format","json") }
    "composer" { return @("cursor-agent","-p","--model",(Route-Model "composer"),"--mode","ask","--trust","--sandbox","enabled","--workspace",$PeerWorkdir,"--output-format","json") }
  }
  throw "unknown route"
}

$script:ModelActual = "unverified"
function Extract-ModelReceipt { param([string]$route,[string]$PeerLog)
  $script:ModelActual="unverified"; if($route -ne "claude"){return}; if(-not(Test-Path $PeerLog)){return}
  $requested=Route-Model "claude"; $prefix=Expected-ModelPrefix $requested
  try{ $e=Get-Content -Raw $PeerLog | ConvertFrom-Json -ErrorAction Stop }catch{ Log "model receipt absent/unparseable on claude route; recording unverified"; return }
  if($null -eq $e.modelUsage){return}
  $matched=$null; if($prefix){ foreach($k in $e.modelUsage.PSObject.Properties.Name){ if($k.StartsWith($prefix)){$matched=$k;break} } }
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
    $proc = Start-Process -FilePath $Argv[0] -ArgumentList ($Argv[1..($Argv.Length-1)]) -WorkingDirectory $PeerCwd -NoNewWindow -PassThru -RedirectStandardOutput $PeerLog -RedirectStandardError $PeerErr -RedirectStandardInput $StdinFile
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

function Recover-FindingsJson { param([string]$LogFile,[string]$OutFile)
  $py = Get-Command python -ErrorAction SilentlyContinue; if(-not $py){$py=Get-Command python3 -ErrorAction SilentlyContinue}; if(-not $py){return $false}
  $script=@"
import sys, json
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
                if isinstance(obj,dict) and 'findings' in obj:best=obj
            except Exception:pass
if best is not None:open(sys.argv[2],'w').write(json.dumps(best))
"@
  $tmp=[System.IO.Path]::GetTempFileName(); try{Set-Content -Path $tmp -Value $script -Encoding UTF8; & $py.Source $tmp $LogFile $OutFile 2>$null|Out-Null}finally{Remove-Item $tmp -Force -ErrorAction SilentlyContinue}
  return ((Test-Path $OutFile) -and ((Get-Item $OutFile).Length -gt 0))
}
function Parse-Structured { param([string]$LogFile,[string]$OutFile)
  if(-not(Test-Path $LogFile)){return $false}
  try{$o=Get-Content -Raw $LogFile|ConvertFrom-Json -ErrorAction Stop}catch{$o=$null}
  if($o){ $src=$null
    if($o.PSObject.Properties['structured_output'] -and $o.structured_output.findings -is [System.Array]){$src=$o.structured_output}
    elseif($o.PSObject.Properties['result'] -and $o.result.findings -is [System.Array]){$src=$o.result}
    if($src){$src|ConvertTo-Json -Depth 20|Set-Content -Path $OutFile -Encoding UTF8;return $true} }
  return (Recover-FindingsJson $LogFile $OutFile)
}
function Test-OutMissingOrInvalid { param([string]$RawOut)
  if(-not(Test-Path $RawOut)){return $true}; if((Get-Item $RawOut).Length -eq 0){return $true}
  try{$o=Get-Content -Raw $RawOut|ConvertFrom-Json -ErrorAction Stop}catch{return $true}
  return -not ($o.findings -is [System.Array])
}
function Test-CursorEgressOk { if(-not $env:CROSS_MODEL_PEERS){return $true}; return (($env:CROSS_MODEL_PEERS -split ',') -contains 'cursor') -or (($env:CROSS_MODEL_PEERS -split ',') -contains 'composer') }
function Test-ProviderAvailable { param([string]$p)
  switch($p){"codex"{return [bool](Get-Command codex -ErrorAction SilentlyContinue)}"claude"{return [bool](Get-Command claude -ErrorAction SilentlyContinue)}
    "grok"{return [bool](Get-Command grok -ErrorAction SilentlyContinue) -or (Test-CursorEgressOk -and (Get-Command cursor-agent -ErrorAction SilentlyContinue))}
    "cursor"{return [bool](Get-Command cursor-agent -ErrorAction SilentlyContinue)}"composer"{return [bool](Get-Command cursor-agent -ErrorAction SilentlyContinue)}default{return $false}} }
function Test-ModelOverride { param([string]$route)
  # Mirrors bash validate_model_override: cross-target override does not apply to this route ($true).
  $ov=$env:CROSS_MODEL_MODEL_OVERRIDE; $ovt=$env:CROSS_MODEL_MODEL_OVERRIDE_TARGET
  if(-not $ov){ return (-not $ovt) }
  if(-not $ovt){ return $false }
  $t=Route-Target $route; if(-not $t){ return $false }
  if($ovt -ne $t){ return $true }
  if($t -eq "cursor"){ return $false }
  switch -Wildcard ("${route}:$ov"){"codex:gpt-*"{return $true}"codex:o[0-9]*"{return $true}"claude:opus"{return $true}"claude:sonnet"{return $true}"claude:haiku"{return $true}"claude:claude-*"{return $true}"grok-cli:grok-*"{return $true}"grok-cursor:cursor-grok-*"{return $true}"composer:composer-*"{return $true}default{return $false}} }

# === --emit-adapter ===
if ($HostProviderArg -eq "--emit-adapter") {
  $route = $REVIEWER_NAME
  try { if(-not(Test-ModelOverride $route)){[Console]::Error.WriteLine("model override '$env:CROSS_MODEL_MODEL_OVERRIDE' not compatible with route '$route'");exit 2}
        $null=Get-AdapterArgv $route "<peer-workdir>" "<peer-workdir>/<lens>-<provider>.raw.json" "<prompt-file>" "<schema>" }
  catch { [Console]::Error.WriteLine("unknown route '$route'"); exit 2 }
  (Get-AdapterArgv $route "<peer-workdir>" "<peer-workdir>/<lens>-<provider>.raw.json" "<prompt-file>" "<schema>") -join ' '; exit 0
}

# === main flow ===
$HOST_PROVIDER=$HostProviderArg; $HOST_HARNESS= if($env:CROSS_MODEL_HOST_HARNESS){$env:CROSS_MODEL_HOST_HARNESS}else{"unknown"}
if(-not $REVIEWER_NAME){Skip "no reviewer-name given; skipping"}
if(-not $DOC_PATH -or -not(Test-Path $DOC_PATH -PathType Leaf)){Skip "document '$DOC_PATH' not readable on disk; skipping"}
if(-not $RunDir){Skip "run-dir not given; skipping"}
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null
if(-not(Test-Path $RunDir -PathType Container)){Skip "run-dir '$RunDir' could not be created; skipping"}
switch($HOST_PROVIDER){"codex"{}"claude"{}"grok"{}"composer"{}"unknown"{}default{Skip "host serving family '$HOST_PROVIDER' invalid"}}
switch($HOST_HARNESS){"codex"{}"claude"{}"grok"{}"cursor"{}"unknown"{}default{Skip "host harness '$HOST_HARNESS' invalid"}}
if($HOST_PROVIDER -eq "unknown"){Skip "host serving family unattested; automatic cross-model review skipped"}
switch($REVIEWER_NAME){"security-lens"{$PERSONA_FILE="security-lens-reviewer"}"adversarial"{$PERSONA_FILE="adversarial-document-reviewer"}"product-lens"{$PERSONA_FILE="product-lens-reviewer"}"whole-doc"{$PERSONA_FILE="whole-doc-reviewer"}default{Skip "reviewer-name '$REVIEWER_NAME' is not a cross-model reviewer"}}

$SKILL_ROOT=(Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$PERSONA=Join-Path $SKILL_ROOT "references/personas/$PERSONA_FILE.md"; $SCHEMA=Join-Path $SKILL_ROOT "references/findings-schema.json"
if(-not(Test-Path $PERSONA)){Skip "persona brief not found at $PERSONA; skipping"}
if(-not(Test-Path $SCHEMA)){Skip "findings schema not found at $SCHEMA; skipping"}
$SCHEMA_CONTENT=Get-Content -Raw $SCHEMA; $SCHEMA_REF=$SCHEMA_CONTENT

$ALLOW=$env:CROSS_MODEL_PEERS; $MAX_PEERS= if($env:CROSS_MODEL_MAX_PEERS){[int]$env:CROSS_MODEL_MAX_PEERS}else{1}; if($MAX_PEERS -lt 1){$MAX_PEERS=1}; if($MAX_PEERS -gt 2){$MAX_PEERS=2}
$MAX_DOC_CHARS= if($env:CROSS_MODEL_MAX_DOC_CHARS){[int]$env:CROSS_MODEL_MAX_DOC_CHARS}else{200000}
$DOC_CHARS=(Get-Item $DOC_PATH).Length
if($DOC_CHARS -gt $MAX_DOC_CHARS){Skip "document is $DOC_CHARS bytes (limit $MAX_DOC_CHARS); skipping cross-model pass rather than truncating"}

$SELECTED=New-Object System.Collections.Generic.List[string]
foreach($p in ($CandidatesRaw -split ',')){ $p=$p.Trim(); if(-not $p){continue}
  if("codex","claude","grok","cursor","composer" -notcontains $p){Log "ignoring unknown target '$p' in candidates";continue}
  if($HOST_PROVIDER -ne "unknown" -and (Target-ServingFamily $p) -eq $HOST_PROVIDER){continue}
  if($SELECTED -contains $p){continue}
  if($ALLOW -and -not (($ALLOW -split ',') -contains $p)){Log "provider '$p' not in CROSS_MODEL_PEERS allowlist; skipping";continue}
  if(-not(Test-ProviderAvailable $p)){Log "provider '$p' has no installed route; skipping";continue}
  $SELECTED.Add($p)|Out-Null }
if($MAX_PEERS -lt 1){Skip "CROSS_MODEL_MAX_PEERS=0; cross-model pass disabled"}
if($SELECTED.Count -eq 0){Skip "no different-provider peer reachable (host=$HOST_PROVIDER, candidates='$CandidatesRaw'); skipping"}
Log "reachable cross-model candidates for lens ${REVIEWER_NAME}: $($SELECTED -join ' ') (host $HOST_PROVIDER excluded; up to $MAX_PEERS successful peer(s))"

$scratch=Join-Path $env:TEMP ("xmodel-doc-ps-"+[guid]::NewGuid().ToString("N")); New-Item -ItemType Directory -Path $scratch|Out-Null
$PROMPT_FILE=Join-Path $scratch "prompt.md"; $PEERLOG=Join-Path $scratch "stdout.log"; $PEERERR=Join-Path $scratch "stderr.log"
$RAW_DIR=Join-Path $scratch "raw"; New-Item -ItemType Directory -Path $RAW_DIR|Out-Null
$DOC_BASENAME=Split-Path $DOC_PATH -Leaf
$IDLE_SECS= if($env:CROSS_MODEL_IDLE_SECS){[int]$env:CROSS_MODEL_IDLE_SECS}else{180}
$HARD_SECS= if($env:CROSS_MODEL_HARD_SECS){[int]$env:CROSS_MODEL_HARD_SECS}else{600}

# Compose the peer prompt: persona + contract + review-context(document embedded).
$personaText=Get-Content -Raw $PERSONA
$docText=Get-Content -Raw $DOC_PATH
$body=@($personaText,"","---","","This is an authorized document review of the maintainer's own repository.",
  "Return ONE JSON object and nothing else (no prose, no code fence) matching this schema:","",$SCHEMA_CONTENT,"",
  'Set the top-level "reviewer" field to "{0}" (it will be namespaced to the peer provider on fold-in).' -f $REVIEWER_NAME,"",
  "<review-context>","Document type: $DOC_TYPE","Document path: $DOC_BASENAME","Origin: $ORIGIN","",
  "<prior-decisions>Round 1 — no prior decisions.</prior-decisions>","","Document content:","$docText","</review-context>") -join "`n"
Set-Content -Path $PROMPT_FILE -Value $body -Encoding UTF8

function Invoke-AttemptRoute { param([string]$provider,[string]$route)
  if(Test-Path $PEERLOG){Clear-Content $PEERLOG}else{""|Set-Content $PEERLOG}
  if(Test-Path $PEERERR){Clear-Content $PEERERR}else{""|Set-Content $PEERERR}
  $RAW_OUT=Join-Path $RAW_DIR "$REVIEWER_NAME-$provider.raw.json"; Remove-Item $RAW_OUT -Force -ErrorAction SilentlyContinue
  $PEER_WORKDIR=$scratch   # empty per-peer workspace (claude has no cwd flag)
  $argv=Get-AdapterArgv $route $PEER_WORKDIR $RAW_OUT $PROMPT_FILE $SCHEMA_REF
  $note= switch($route){{$_ -in @("codex","claude","grok-cli")}{"$(Route-Model $route) (effort high)"}default{"$(Route-Model $route)"}}
  Log "peer run: provider=$provider route=$route model=$note lens=$REVIEWER_NAME (idle ${IDLE_SECS}s / hard ${HARD_SECS}s); reviewed document may egress to this provider"
  $exitCode=0; $ok=$false
  switch($route){
    "codex" { $ok=Invoke-PeerRun $argv $PROMPT_FILE $PEERLOG $PEERERR $IDLE_SECS $HARD_SECS $PEER_WORKDIR ([ref]$exitCode)
              if($ok -and (Test-OutMissingOrInvalid $RAW_OUT)){ if(Recover-FindingsJson $PEERLOG $RAW_OUT){Log "recovered codex JSON from stdout"} } }
    default { $stdin = if($route -in @("claude","grok-cursor","cursor","composer")){$PROMPT_FILE}else{""}
              $ok=Invoke-PeerRun $argv $stdin $PEERLOG $PEERERR $IDLE_SECS $HARD_SECS $PEER_WORKDIR ([ref]$exitCode)
              if($ok){$null=Parse-Structured $PEERLOG $RAW_OUT} }
  }
  $script:ActualRoute=$route
  if(-not $ok){Remove-Item $RAW_OUT -Force -ErrorAction SilentlyContinue; return}
  Extract-ModelReceipt $route $PEERLOG
}

function Invoke-Provider { param([string]$provider)
  $OUT=Join-Path $RunDir "$REVIEWER_NAME-$provider.json"
  $RAW_OUT=Join-Path $RAW_DIR "$REVIEWER_NAME-$provider.raw.json"
  $fixed=$env:CROSS_MODEL_FIXED_ROUTE
  if(-not $fixed){Log "host must resolve one fixed route before egress; skipping";Remove-Item $OUT -Force -ErrorAction SilentlyContinue;return}
  if((Route-Target $fixed) -ne $provider){Log "fixed route '$fixed' does not match target '$provider'; skipping";Remove-Item $OUT -Force -ErrorAction SilentlyContinue;return}
  if($fixed -eq "grok-cursor" -and -not(Test-CursorEgressOk)){Log "fixed route 'grok-cursor' requires Cursor intermediary sanction; skipping";Remove-Item $OUT -Force -ErrorAction SilentlyContinue;return}
  if(-not(Test-ModelOverride $fixed)){Log "model override not compatible with route '$fixed'; skipping";Remove-Item $OUT -Force -ErrorAction SilentlyContinue;return}
  Invoke-AttemptRoute $provider $fixed
  Remove-Item $OUT -Force -ErrorAction SilentlyContinue
  if((Test-Path $RAW_OUT) -and (Get-Item $RAW_OUT).Length -gt 0){
    try{$raw=Get-Content -Raw $RAW_OUT|ConvertFrom-Json -ErrorAction Stop}catch{$raw=$null}
    if($raw -and $raw.findings -is [System.Array]){
      $fam= if($script:ActualRoute -eq "cursor"){"unknown"}elseif($script:ModelActual -eq "unverified" -and $script:ActualRoute -in @("composer","grok-cursor")){"unknown"}else{Target-ServingFamily $provider}
      $independent=($HOST_PROVIDER -ne "unknown") -and ($fam -ne "unknown") -and ($HOST_PROVIDER -ne $fam)
      $findings=@(); foreach($f in $raw.findings){ if($f.PSObject.Properties['autofix_class'] -and $f.autofix_class -eq "safe_auto"){$f.autofix_class="gated_auto"}; $findings+=$f }
      $folded=[pscustomobject]@{ reviewer="$REVIEWER_NAME-$provider"; cross_model_route=$script:ActualRoute; cross_model_target=$provider;
        cross_model_harness=(Route-Harness $script:ActualRoute); serving_family=$fam; independence_verified=$independent;
        model_requested=(Route-Model $script:ActualRoute); model_actual=$script:ModelActual; findings=$findings;
        residual_risks=@($raw.residual_risks); testing_gaps=@($raw.testing_gaps) }
      $folded|ConvertTo-Json -Depth 20|Set-Content -Path $OUT -Encoding UTF8
    }
    Remove-Item $RAW_OUT -Force -ErrorAction SilentlyContinue
  }
  if((Test-Path $OUT) -and (Get-Item $OUT).Length -gt 0){
    try{$chk=Get-Content -Raw $OUT|ConvertFrom-Json -ErrorAction Stop
       if($chk.reviewer -is [string] -and $chk.findings -is [System.Array] -and $chk.residual_risks -is [System.Array] -and $chk.testing_gaps -is [System.Array]){Log "wrote $($chk.findings.Count) finding(s) to $OUT (reviewer $REVIEWER_NAME-$provider)"}
       else{Log "provider $provider produced no usable schema-shaped output; skipping fold-in";Remove-Item $OUT -Force -ErrorAction SilentlyContinue}}
    catch{Log "provider $provider produced no usable schema-shaped output; skipping fold-in";Remove-Item $OUT -Force -ErrorAction SilentlyContinue}
  } else {
    Log "provider $provider produced no usable schema-shaped output; skipping fold-in"
    foreach($pf in @($PEERLOG,$PEERERR)){ if((Test-Path $pf) -and (Get-Item $pf).Length -gt 0){ $t=(Get-Content -Raw $pf)-replace "`r?`n"," "; if($t.Length -gt 300){$t=$t.Substring($t.Length-300)}; $tag=if($pf -eq $PEERERR){" (stderr)"}else{""}; Log "  peer skip evidence${tag}: $t" } }
  }
}

$FIXED_TARGET=Route-Target $env:CROSS_MODEL_FIXED_ROUTE
if($FIXED_TARGET){ if($SELECTED -contains $FIXED_TARGET){Invoke-Provider $FIXED_TARGET}else{Log "fixed route target '$FIXED_TARGET' is not an eligible reachable candidate; skipping"} }
else {Log "host must resolve one fixed route before egress; skipping"}
Remove-Item -Recurse -Force $scratch -ErrorAction SilentlyContinue
[Console]::OutputEncoding=$prevOutEnc; $OutputEncoding=$prevPrefEnc
exit 0
