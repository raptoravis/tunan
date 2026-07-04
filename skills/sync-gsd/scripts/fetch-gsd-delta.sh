#!/usr/bin/env bash
# Clone the upstream open-gsd/gsd-core to a scratch dir and print the
# capability-scoped delta since the last-absorbed GSD commit.
#
# Usage: fetch-gsd-delta.sh [LAST_SYNCED_SHA]
#
# Stdout contract (stable — the .ps1 twin must match byte-for-byte):
#   GSD_HEAD=<sha>                 current upstream default-branch (next) HEAD
#   GSD_ROOT=<path>                scratch checkout the agent reads files from
#   === COMMITS <sha>..HEAD ===    followed by `git log --oneline` lines
#   === CHANGED CAPABILITIES (changesets) ===  changed .changeset/*.md paths
#   === CHANGED FILES (capabilities) ===  followed by `git diff --stat` lines
# On clone failure prints the single sentinel __SYNCGSD_CLONE_FAILED__.
# Never deletes or writes anything outside the scratch dir.

set -u

LAST_SHA="${1:-}"
SCRATCH="${TMPDIR:-/tmp}/tunan-syncgsd-upstream"
REPO="https://github.com/open-gsd/gsd-core.git"
CAP_PATHS="gsd-core capabilities agents commands"
CHANGESET_PATH=".changeset"

rm -rf "$SCRATCH" 2>/dev/null
git clone --quiet "$REPO" "$SCRATCH" 2>/dev/null || { echo "__SYNCGSD_CLONE_FAILED__"; exit 0; }
cd "$SCRATCH" 2>/dev/null || { echo "__SYNCGSD_CLONE_FAILED__"; exit 0; }

HEAD_SHA=$(git rev-parse HEAD 2>/dev/null)
echo "GSD_HEAD=$HEAD_SHA"
echo "GSD_ROOT=$SCRATCH"

if [ -n "$LAST_SHA" ] && git cat-file -e "${LAST_SHA}^{commit}" 2>/dev/null; then
  echo "=== COMMITS ${LAST_SHA}..HEAD ==="
  git log --oneline "${LAST_SHA}..HEAD"
  echo "=== CHANGED CAPABILITIES (changesets) ==="
  git diff --name-only "${LAST_SHA}..HEAD" -- "$CHANGESET_PATH"
  echo "=== CHANGED FILES (capabilities) ==="
  git diff --stat "${LAST_SHA}..HEAD" -- $CAP_PATHS
else
  echo "=== COMMITS ${LAST_SHA}..HEAD ==="
  echo "__SYNCGSD_LAST_SHA_MISSING__"
  echo "=== CHANGED CAPABILITIES (changesets) ==="
  echo "__SYNCGSD_LAST_SHA_MISSING__"
  echo "=== CHANGED FILES (capabilities) ==="
  echo "__SYNCGSD_LAST_SHA_MISSING__"
fi
