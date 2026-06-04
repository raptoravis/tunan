# Print the version segment of the skill's own location when it matches the
# marketplace cache layout `~/.claude/plugins/cache/<marketplace>/tunan/<version>/skills/ce-update`,
# or the literal sentinel `__CE_UPDATE_NOT_MARKETPLACE__` otherwise.
#
# PowerShell 5.1-compatible port of currently-loaded-version.sh. Derives
# skill_dir from $PSScriptRoot (reliable self-location) rather than
# $CLAUDE_SKILL_DIR. Path separators are normalized to `/` so the marketplace
# regex matches on Windows backslash paths.

$skillDir = (Split-Path -Parent $PSScriptRoot) -replace '\\', '/'

# Match `.../plugins/cache/*/tunan/<version>/skills/ce-update[/]?`
# Capture group 1 is the version segment.
$m = [regex]::Match($skillDir, '.*/plugins/cache/[^/]+/tunan/([^/]+)/skills/ce-update/?$')

if ($m.Success) {
  Write-Output $m.Groups[1].Value
} else {
  Write-Output '__CE_UPDATE_NOT_MARKETPLACE__'
}
