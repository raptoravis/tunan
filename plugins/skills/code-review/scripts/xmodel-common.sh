#!/usr/bin/env bash
# xmodel-common.sh — shared kernel for the cross-model peer scripts.
#
# Sourced (never executed directly) by:
#   cross-model-adversarial-review.sh, cross-model-doc-review.sh, cross-model-pov.sh
# Byte-identical across code-review, doc-review, pov (skills/<skill>/scripts/).
# Apply any change to ALL THREE in the same commit — no automated parity test.
# Verify: md5sum skills/*/scripts/xmodel-common.sh
#
# Defines ONLY the shared mechanism: model-identity receipts, routing helpers,
# process/signal machinery (reap/on_term/on_exit/heartbeat), and the run
# dispatchers. It executes nothing at source time except the M_* constant
# assignments, MODEL_ACTUAL init, and _HEARTBEAT_PID="" — all pure definitions,
# safe to source at any point after the caller's globals exist.
#
# Caller contract (values read at CALL time, so set before the functions run):
#   LOG_PREFIX                          log tag ("cross-model" / "cross-model-pov" / ...)
#   PEER_CWD                            dir the peer runs in ($PEER_WORKDIR or $READ_ROOT)
#   CMD                                 worker argv array (built by caller's build_cmd)
#   PROMPT_FILE PEERLOG PEERERR         peer stdio paths
#   IDLE_SECS HARD_SECS TO_BIN          timeout knobs
#   CROSS_MODEL_HEARTBEAT_SECS          heartbeat interval (optional)
#   CROSS_MODEL_MODEL_OVERRIDE[_TARGET] model override (optional)
#   cleanup_peer_scratch()              function the CALLER defines — on_exit's
#                                       tail hook. Must guard unset vars
#                                       (${VAR:-}); EXIT can fire before mktemp.
#   adapter_argv()                      function the CALLER defines — build_cmd's
#                                       route-flag builder (per-skill isolation policy).

M_CODEX="gpt-5.6-sol"          # codex CLI            (-c model_reasoning_effort="high")
M_CLAUDE="opus"                # claude CLI, Opus 4.8 (--effort high)
M_GROK="grok-4.5"              # grok CLI             (--effort high)
M_GROK_CURSOR="cursor-grok-4.5-high"  # fixed cursor-agent Grok route (current id)
M_COMPOSER="composer-2.5-fast" # cursor-agent composer (no high tier; -fast is the ceiling)

log()  { printf '[%s] %s\n' "${LOG_PREFIX:-cross-model}" "$*" >&2; }
skip() { log "$*"; exit 0; }   # non-blocking: announce reason, exit clean, no output

# --- model-identity receipt (R7/R8) -----------------------------------------
# "Which model ran" is a claim that needs a serving-side receipt. Only the
# claude CLI reports one today: its JSON envelope carries a modelUsage object
# keyed by the full dated id that actually served the run. Match requested vs
# actual by expected full-family prefix (alias -> dated id counts as a match;
# never substring). Every other route records the literal "unverified" — never
# a fallback to the requested value.
expected_model_prefix() {   # <requested-alias> -> expected served-id prefix
  case "$1" in
    opus)   printf 'claude-opus-' ;;
    sonnet) printf 'claude-sonnet-' ;;
    haiku)  printf 'claude-haiku-' ;;
  esac
}

route_model() {   # <route> -> the M_* constant that route requests
  local target
  target="$(route_target "$1")"
  if [ -n "${CROSS_MODEL_MODEL_OVERRIDE:-}" ] &&
     [ "${CROSS_MODEL_MODEL_OVERRIDE_TARGET:-}" = "$target" ] &&
     [ "$target" != "cursor" ]; then
    printf '%s' "$CROSS_MODEL_MODEL_OVERRIDE"
    return 0
  fi
  case "$1" in
    codex)       printf '%s' "$M_CODEX" ;;
    claude)      printf '%s' "$M_CLAUDE" ;;
    grok-cli)    printf '%s' "$M_GROK" ;;
    grok-cursor) printf '%s' "$M_GROK_CURSOR" ;;
    cursor)      printf 'auto' ;;
    composer)    printf '%s' "$M_COMPOSER" ;;
  esac
}

route_target() {
  case "$1" in
    codex|claude|cursor|composer) printf '%s' "$1" ;;
    grok-cli|grok-cursor) printf 'grok' ;;
  esac
}

route_harness() {
  case "$1" in
    codex) printf 'codex' ;;
    claude) printf 'claude' ;;
    grok-cli) printf 'grok' ;;
    grok-cursor|cursor|composer) printf 'cursor-agent' ;;
  esac
}

target_serving_family() {
  case "$1" in
    codex|claude|grok|composer) printf '%s' "$1" ;;
    cursor) printf 'unknown' ;;
  esac
}

MODEL_ACTUAL="unverified"
extract_model_receipt() {   # <route>; reads the envelope in $PEERLOG, sets MODEL_ACTUAL
  MODEL_ACTUAL="unverified"
  [ "$1" = "claude" ] || return 0
  local requested actual prefix matched
  requested="$(route_model claude)"
  prefix="$(expected_model_prefix "$requested")"
  # jq `keys` is sorted, so keys[0] is the alphabetically-first model, not
  # necessarily the one that served the run (a multi-key envelope can also carry
  # an auxiliary model's usage). Prefer a key matching the requested family's
  # expected prefix; fall back to the first key only when none matches, and warn
  # only then. A missing/unparseable envelope stays "unverified" (never the
  # requested value).
  matched=""
  if [ -n "$prefix" ]; then
    # first modelUsage key matching the expected family prefix (jq-native, no
    # external `head`: the route sandbox may not carry coreutils on PATH).
    matched="$(jq -r --arg p "$prefix" 'first((.modelUsage // {} | keys[] | select(startswith($p)))) // empty' "$PEERLOG" 2>/dev/null)"
  fi
  if [ -n "$matched" ]; then
    MODEL_ACTUAL="$matched"
    return 0
  fi
  actual="$(jq -r '.modelUsage // empty | keys[0] // empty' "$PEERLOG" 2>/dev/null)"
  if [ -z "$actual" ]; then
    log "model receipt absent/unparseable on claude route; recording unverified"
    return 0
  fi
  MODEL_ACTUAL="$actual"
  log "WARNING: model mismatch - requested $requested, backend served $actual; reconcile must surface this"
}

in_csv() { case ",$2," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }

# --- process / signal machinery ---------------------------------------------
# Reap a backgrounded job's whole process group: TERM, then KILL after a grace.
reap() {
  local pid="$1" grp
  if kill -TERM -- -"$pid" 2>/dev/null; then grp=1; else kill -TERM "$pid" 2>/dev/null; grp=0; fi
  for _ in 1 2 3 4 5; do
    if [ "$grp" = 1 ]; then kill -0 -- -"$pid" 2>/dev/null || return 0
    else kill -0 "$pid" 2>/dev/null || return 0; fi
    sleep 1
  done
  if [ "$grp" = 1 ]; then kill -KILL -- -"$pid" 2>/dev/null; else kill -KILL "$pid" 2>/dev/null; fi
}

# TERM/INT: reap the live peer group, then exit cleanly (HUP remains ignored).
on_term() {
  if [ -n "${_HEARTBEAT_PID:-}" ]; then
    kill "$_HEARTBEAT_PID" 2>/dev/null || true
    wait "$_HEARTBEAT_PID" 2>/dev/null || true
    _HEARTBEAT_PID=""
  fi
  if [ -n "${ACTIVE_PEER_PID:-}" ]; then
    log "received TERM/INT; reaping peer process group $ACTIVE_PEER_PID"
    reap "$ACTIVE_PEER_PID" 2>/dev/null || true
    ACTIVE_PEER_PID=""
  fi
  exit 0
}

# EXIT: reap any live peer group + heartbeat so an abnormal exit (SIGSEGV / OOM
# kill / `set -u` abort) cannot orphan them, then hand scratch cleanup to the
# caller's hook. TERM/INT funnel here too via on_term -> exit. The hook is
# resolved at trigger time, so defining it after this file is sourced is safe.
on_exit() {
  if [ -n "${_HEARTBEAT_PID:-}" ]; then
    kill "$_HEARTBEAT_PID" 2>/dev/null || true
    wait "$_HEARTBEAT_PID" 2>/dev/null || true
    _HEARTBEAT_PID=""
  fi
  if [ -n "${ACTIVE_PEER_PID:-}" ]; then
    log "exiting; reaping peer process group $ACTIVE_PEER_PID"
    reap "$ACTIVE_PEER_PID" 2>/dev/null || true
    ACTIVE_PEER_PID=""
  fi
  cleanup_peer_scratch
}

build_cmd() {
  CMD=()
  while IFS= read -r -d '' tok; do CMD+=("$tok"); done < <(adapter_argv "$1")
}

# --- liveness heartbeat -----------------------------------------------------
# The peer CLI streams into $PEERLOG (private), so nothing reaches this script's
# own stdout/stderr during a long model call. An outer supervisor that watches
# THIS process's output for liveness (the peer-job runner's out.log byte-growth
# idle window) would mistake a healthy multi-minute run for a wedge. A background
# writer emits one stderr line every CROSS_MODEL_HEARTBEAT_SECS (default 60s) so
# that liveness is visible; it is torn down as soon as the foreground wait returns,
# so it adds no latency to a fast run.
_HEARTBEAT_PID=""
start_heartbeat() {
  local every="${CROSS_MODEL_HEARTBEAT_SECS:-60}" parent_pid="$$"
  # Floor to 1s: a non-numeric or 0 value would make `sleep` return instantly and
  # spin the loop, flooding out.log into the runner's byte cap.
  case "$every" in ''|*[!0-9]*) every=60 ;; esac; [ "$every" -lt 1 ] && every=1
  ( local t0 n; t0="$(date +%s)"
    while kill -0 "$parent_pid" 2>/dev/null; do
      sleep "$every"
      kill -0 "$parent_pid" 2>/dev/null || break
      n="$(date +%s)"; log "peer alive ($(( n - t0 ))s elapsed)"
    done ) &
  _HEARTBEAT_PID=$!
}
stop_heartbeat() {
  if [ -n "$_HEARTBEAT_PID" ]; then
    kill "$_HEARTBEAT_PID" 2>/dev/null || true
    wait "$_HEARTBEAT_PID" 2>/dev/null || true
  fi
  _HEARTBEAT_PID=""
}

# --- run dispatchers --------------------------------------------------------
run_codex_cmd() {
  RUN_SUCCEEDED=false
  local prev; case "$-" in *m*) prev=1;; *) prev=0;; esac
  set -m
  # `command` bypasses shell functions/aliases that could strip -s read-only.
  command "${CMD[@]}" < "$PROMPT_FILE" > "$PEERLOG" 2>&1 &
  local pid=$!
  ACTIVE_PEER_PID="$pid"
  [ "$prev" = 0 ] && set +m
  start_heartbeat
  local start last=-1 lastchg now size
  start="$(date +%s)"; lastchg="$start"
  while kill -0 "$pid" 2>/dev/null; do
    sleep 5; now="$(date +%s)"; size="$(wc -c <"$PEERLOG" 2>/dev/null || echo 0)"
    [ "$size" != "$last" ] && { last="$size"; lastchg="$now"; }
    if [ $(( now - lastchg )) -ge "$IDLE_SECS" ]; then
      log "codex output idle ${IDLE_SECS}s; reaping peer process group"; reap "$pid"; break
    fi
    if [ $(( now - start )) -ge "$HARD_SECS" ]; then
      log "codex exceeded hard cap ${HARD_SECS}s; reaping peer process group"; reap "$pid"; break
    fi
  done
  if wait "$pid" 2>/dev/null; then RUN_SUCCEEDED=true
  else log "peer exited non-zero or timed out"; fi
  # Sweep any survivor the provider left in its OWN process group. `set -m` puts
  # the provider in a separate pgid, and on a clean worker exit the runner's
  # final sweep only kills the worker's pgid while a group-orphan reparents off
  # the worker's process tree -- so it must be reaped here, where the pgid is
  # known. reap() returns immediately when the group is already empty.
  reap "$pid" 2>/dev/null || true
  stop_heartbeat
  ACTIVE_PEER_PID=""
}

run_timeout_cmd() {   # $1 = stdin file ("" -> /dev/null). CMD already built.
  RUN_SUCCEEDED=false
  local stdin_file="${1:-}"; [ -n "$stdin_file" ] || stdin_file=/dev/null
  local prev; case "$-" in *m*) prev=1;; *) prev=0;; esac
  set -m
  if [ -n "$TO_BIN" ]; then
    ( cd "$PEER_CWD" && exec "$TO_BIN" -k 10 "$HARD_SECS" "${CMD[@]}" ) < "$stdin_file" > "$PEERLOG" 2>"$PEERERR" &
  else
    # No (g)timeout: emulate `timeout -k 10` in perl — fork the peer so a perl
    # parent stays alive to enforce the alarm (a bare `exec` would hand SIGALRM
    # to a peer that can ignore it and escape HARD_SECS). TERM, then KILL after
    # a 10s grace, exit 124 on timeout; otherwise pass through the child code.
    ( cd "$PEER_CWD" && exec perl -e '
      my $secs = shift; my @cmd = @ARGV;
      my $pid = fork();
      die "fork failed" unless defined $pid;
      if ($pid == 0) { exec { $cmd[0] } @cmd or die "exec failed" }
      $SIG{ALRM} = sub { kill "TERM", $pid; sleep 10; kill "KILL", $pid; exit 124 };
      alarm $secs;
      waitpid($pid, 0);
      exit($? >> 8);
    ' "$HARD_SECS" "${CMD[@]}" ) < "$stdin_file" > "$PEERLOG" 2>"$PEERERR" &
  fi
  local pid=$!
  ACTIVE_PEER_PID="$pid"
  [ "$prev" = 0 ] && set +m
  start_heartbeat
  if wait "$pid" 2>/dev/null; then RUN_SUCCEEDED=true
  else log "peer exited non-zero or timed out"; fi
  reap "$pid" 2>/dev/null || true   # sweep survivors in the provider's own group (see run_codex_cmd)
  stop_heartbeat
  ACTIVE_PEER_PID=""
}
