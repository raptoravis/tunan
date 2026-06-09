#!/usr/bin/env bash
# Clone the upstream everyinc/compound-engineering-plugin to a scratch dir and
# print the skill-scoped delta since the last-synced upstream commit.
#
# Usage: fetch-upstream-delta.sh [LAST_SYNCED_SHA]
#
# Stdout contract (stable — the .ps1 twin must match byte-for-byte):
#   UPSTREAM_HEAD=<sha>           current upstream main HEAD
#   UPSTREAM_ROOT=<path>          scratch checkout the agent reads files from
#   === COMMITS <sha>..HEAD ===   followed by `git log --oneline` lines
#   === CHANGED FILES (skills) ===  followed by `git diff --stat` lines
# On clone failure prints the single sentinel __GETUPS_CLONE_FAILED__.
# Never deletes or writes anything outside the scratch dir.

set -u

LAST_SHA="${1:-}"
SCRATCH="${TMPDIR:-/tmp}/tunan-getups-upstream"
REPO="https://github.com/everyinc/compound-engineering-plugin.git"
SKILLS_PATH="plugins/compound-engineering/skills/"

rm -rf "$SCRATCH" 2>/dev/null
git clone --quiet "$REPO" "$SCRATCH" 2>/dev/null || { echo "__GETUPS_CLONE_FAILED__"; exit 0; }
cd "$SCRATCH" 2>/dev/null || { echo "__GETUPS_CLONE_FAILED__"; exit 0; }

HEAD_SHA=$(git rev-parse HEAD 2>/dev/null)
echo "UPSTREAM_HEAD=$HEAD_SHA"
echo "UPSTREAM_ROOT=$SCRATCH"

if [ -n "$LAST_SHA" ] && git cat-file -e "${LAST_SHA}^{commit}" 2>/dev/null; then
  echo "=== COMMITS ${LAST_SHA}..HEAD ==="
  git log --oneline "${LAST_SHA}..HEAD"
  echo "=== CHANGED FILES (skills) ==="
  git diff --stat "${LAST_SHA}..HEAD" -- "$SKILLS_PATH"
else
  echo "=== COMMITS ${LAST_SHA}..HEAD ==="
  echo "__GETUPS_LAST_SHA_MISSING__"
  echo "=== CHANGED FILES (skills) ==="
  echo "__GETUPS_LAST_SHA_MISSING__"
fi
