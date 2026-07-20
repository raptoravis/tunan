#!/usr/bin/env bash
# tunan phase detector — infer a feature's lifecycle phase from its GitHub issue.
#
# The feature issue IS the state machine: labels + marker comments + an open PR
# encode how far the pipeline got. This reads that state so an interrupted run can
# resume at the right stage instead of re-running lfg from step 1. State lives in
# GitHub (not a local .yaml), keeping tunan's "artifacts are issues" invariant.
#
# Usage:
#   phase.sh detect <issue>
#
# Emits ONE machine line on stdout, then human hints on stderr:
#   phase=<plan|work|review-ci|done|unknown> next=<skill|none> pr=<url|-> issue=<N> units_done=<csv|-> units_total=<N|-> label_stale=<stage|->
#
# units_done / units_total come from an optional <!-- tunan:progress --> comment
# that `work` maintains as a resume hint (git stays authoritative for shipped
# code). They are `-` when no progress comment exists.
#
# label_stale is the bare stage name (e.g. "plan") when the stage label exists on
# the issue but its marker comment does not — the label was applied (manually or
# by an interrupted run) but the content was never written. `-` otherwise.
# Callers can report this so the next stage self-heals (re-running the missing
# stage is safe: --add-label is idempotent, and the create-or-update pattern
# writes the missing comment). Appended fields keep the line backward-compatible
# — callers that parse only phase/next/pr/issue still work.
#
# Phase ladder (each later phase implies the earlier evidence is present):
#   plan       — feature issue exists, no <!-- tunan:plan --> comment yet  -> run plan
#   work       — plan comment present, no open PR, no solution               -> run work
#   review-ci  — an open PR references the issue, no solution comment yet     -> resume at code-review / CI watch
#   done       — <!-- tunan:solution --> comment present                   -> nothing to resume
#   unknown    — issue not found / gh unavailable                            -> caller decides
set -o pipefail

cmd="${1:-}"; n="${2:-}"

err() { echo "$*" >&2; }
udone="-"; utotal="-"; lstale="-"
emit() { # phase next pr
  echo "phase=$1 next=$2 pr=${3:--} issue=${n:--} units_done=$udone units_total=$utotal label_stale=$lstale"
}

# Check whether a stage label exists on the issue without its matching marker
# comment — the label was applied (manually or by an interrupted run) but the
# content never landed.  Callers can report this and self-heal (re-running the
# stage is safe: --add-label is idempotent, and the comment create-or-update
# pattern writes the missing content).
check_stale_label() { # <stage-label>  (e.g. "tunan:plan")
  local label="$1"
  lstale="-"
  local labels
  labels="$(gh api "repos/$slug/issues/$n" --jq '.labels[].name' 2>/dev/null)"
  if printf '%s' "$labels" | grep -qx "$label"; then
    lstale="${label#tunan:}"
  fi
}

# Populate udone/utotal from the optional <!-- tunan:progress --> comment, whose
# machine line looks like: <!-- progress: done=U1,U2,U3 total=5 -->
read_progress() {
  local body
  body="$(gh api "repos/$slug/issues/$n/comments" \
    --jq '.[] | select(.body | startswith("<!-- tunan:progress -->")) | .body' 2>/dev/null)"
  [ -n "$body" ] || return 0
  local d t
  d="$(printf '%s' "$body" | sed -n 's/.*progress: done=\([^ ]*\) total=.*/\1/p' | head -1)"
  t="$(printf '%s' "$body" | sed -n 's/.*progress:.* total=\([0-9]*\).*/\1/p' | head -1)"
  [ -n "$d" ] && udone="$d"
  [ -n "$t" ] && utotal="$t"
}

[ "$cmd" = "detect" ] || { err "usage: phase.sh detect <issue>"; exit 2; }
[ -n "$n" ] || { err "usage: phase.sh detect <issue>"; exit 2; }

command -v gh >/dev/null 2>&1 || { emit unknown none -; err "gh not installed"; exit 2; }
gh auth status >/dev/null 2>&1 || { emit unknown none -; err "gh not authenticated"; exit 2; }

slug="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)"
[ -n "$slug" ] || { emit unknown none -; err "cannot resolve repo"; exit 2; }

# Issue must exist.
if ! gh issue view "$n" --json number >/dev/null 2>&1; then
  emit unknown none -; err "feature issue #$n not found"; exit 1
fi

has_marker() { # marker
  gh api "repos/$slug/issues/$n/comments" \
    --jq ".[] | select(.body | startswith(\"$1\")) | .id" 2>/dev/null | grep -q .
}

if has_marker "<!-- tunan:solution -->"; then
  emit done none -
  err "Feature #$n is complete (solution comment present). Nothing to resume."
  exit 0
fi

# An open PR whose body references this issue means plan+work happened and we are
# in the review / CI tail of the pipeline.
pr_url="$(gh pr list --state open --search "$n in:body" --json number,url \
  --jq '.[0].url' 2>/dev/null)"
if [ -z "$pr_url" ]; then
  # Fallback: current branch's PR, if any.
  pr_url="$(gh pr view --json url --jq .url 2>/dev/null)"
fi

if [ -n "$pr_url" ]; then
  read_progress
  emit review-ci code-review "$pr_url"
  err "Open PR for #$n: $pr_url — resume at code-review, then CI watch + compound (lfg steps 3-9)."
  exit 0
fi

if has_marker "<!-- tunan:plan -->"; then
  read_progress
  emit work work -
  err "Plan comment present on #$n, no PR yet — resume at work (lfg step 2)."
  exit 0
fi

check_stale_label "tunan:plan"
emit plan plan -
err "Feature #$n has no plan comment — resume at plan (lfg step 1)."
exit 0
