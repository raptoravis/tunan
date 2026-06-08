#!/usr/bin/env bash
# tunan lfg gate — script-enforced phase exit conditions.
#
# Replaces lfg's prose "GATE: STOP ..." self-checks with deterministic checks so
# an agent cannot hallucinate progress past a stage whose evidence does not exist.
# Inspired by comet's comet-guard.sh: the guard, not the agent's word, decides
# whether a phase may transition.
#
# Usage:
#   gate.sh plan-exists <issue>        # feature issue carries a <!-- tunan:plan --> comment
#   gate.sh solution-exists <issue>    # feature issue carries a <!-- tunan:solution --> comment
#   gate.sh work-done [base-branch]    # working tree dirty OR HEAD diverged from base
#   gate.sh verify-green [file|-]      # a verify mode:agent JSON contract is authoritative-green
#
# Exit codes (lfg branches on these, it does not parse stdout prose):
#   0  PASS   — gate satisfied, proceed
#   1  FAIL   — gate not satisfied, run the stage's recovery path
#   2  ERROR  — infra/usage problem (gh/jq missing, unreadable input); abort, don't loop
#   3  SOFT   — non-authoritative result (verify degraded/skipped); proceed but note it
set -o pipefail

cmd="${1:-}"; shift 2>/dev/null || true

pass()  { echo "GATE PASS: $*"; exit 0; }
fail()  { echo "GATE FAIL: $*" >&2; exit 1; }
infra() { echo "GATE ERROR: $*" >&2; exit 2; }
soft()  { echo "GATE SOFT: $*" >&2; exit 3; }

need_gh() {
  command -v gh >/dev/null 2>&1 || infra "gh not installed"
  gh auth status >/dev/null 2>&1 || infra "gh not authenticated"
}

repo_slug() { gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null; }

has_marker_comment() { # <issue> <marker>
  local n="$1" marker="$2" slug
  slug="$(repo_slug)" || return 2
  [ -n "$slug" ] || return 2
  gh api "repos/$slug/issues/$n/comments" \
    --jq ".[] | select(.body | startswith(\"$marker\")) | .id" 2>/dev/null | grep -q .
}

case "$cmd" in
  plan-exists)
    n="${1:?usage: gate.sh plan-exists <issue>}"; need_gh
    rc=0; has_marker_comment "$n" "<!-- tunan:plan -->" || rc=$?
    [ "$rc" = 2 ] && infra "cannot resolve repo to read issue #$n comments"
    [ "$rc" = 0 ] \
      && pass "plan comment present on feature issue #$n" \
      || fail "no <!-- tunan:plan --> comment on feature issue #$n — re-run plan"
    ;;
  solution-exists)
    n="${1:?usage: gate.sh solution-exists <issue>}"; need_gh
    rc=0; has_marker_comment "$n" "<!-- tunan:solution -->" || rc=$?
    [ "$rc" = 2 ] && infra "cannot resolve repo to read issue #$n comments"
    [ "$rc" = 0 ] \
      && pass "solution comment present on feature issue #$n" \
      || fail "no <!-- tunan:solution --> comment on feature issue #$n — re-run compound"
    ;;
  work-done)
    base="${1:-}"
    if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
      pass "working tree has uncommitted changes"
    fi
    if [ -z "$base" ]; then
      base="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)"
      [ -z "$base" ] && base="origin/main"
    fi
    mb="$(git merge-base HEAD "$base" 2>/dev/null)"
    if [ -n "$mb" ] && [ -n "$(git diff --name-only "$mb"..HEAD 2>/dev/null)" ]; then
      pass "HEAD diverged from $base (committed work present)"
    fi
    fail "no code changes detected (clean tree, no divergence from $base) — work did not run"
    ;;
  verify-green)
    src="${1:--}"
    command -v jq >/dev/null 2>&1 || infra "jq not installed"
    if [ "$src" = "-" ]; then
      json="$(cat)"
    else
      json="$(cat "$src" 2>/dev/null)" || infra "cannot read contract file: $src"
    fi
    [ -n "$json" ] || infra "empty verify contract"
    vc="$(printf '%s' "$json" | jq -r '.verdict_code // empty' 2>/dev/null)"
    st="$(printf '%s' "$json" | jq -r '.status // empty' 2>/dev/null)"
    [ -n "$vc" ] || infra "contract has no verdict_code (not a verify mode:agent JSON?)"
    case "$st" in
      degraded|skipped) soft "verify status=$st — non-authoritative; CI remains the backstop" ;;
    esac
    [ "$vc" = "ready" ] \
      && pass "verify verdict_code=ready (local green)" \
      || fail "verify verdict_code=$vc status=$st — local checks red, run the autofix loop"
    ;;
  ""|-h|--help|help)
    sed -n '2,30p' "$0"
    exit 0
    ;;
  *)
    infra "unknown gate '$cmd' (expected: plan-exists | solution-exists | work-done | verify-green)"
    ;;
esac
