# Print the marketplace-name segment of the skill's own location when it
# matches the marketplace cache layout
# `~/.claude/plugins/cache/<marketplace>/tunan/<version>/skills/update`,
# or the literal sentinel `__CE_UPDATE_NOT_MARKETPLACE__` otherwise.
#
# PowerShell 5.1-compatible port of marketplace-name.sh. Derives skill_dir from
# $PSScriptRoot (the script's own directory) rather than $CLAUDE_SKILL_DIR, for
# the same reason the bash version uses BASH_SOURCE. Path separators are
# normalized to `/` so the marketplace regex matches on Windows backslash paths.

$skillDir = (Split-Path -Parent $PSScriptRoot) -replace '\\', '/'

# Capture group 1 is the marketplace segment.
$m = [regex]::Match($skillDir, '.*/plugins/cache/([^/]+)/tunan/[^/]+/skills/update/?$')

if ($m.Success) {
  Write-Output $m.Groups[1].Value
} else {
  Write-Output '__CE_UPDATE_NOT_MARKETPLACE__'
}
