# Print the upstream `version` field from plugins/tunan/.claude-plugin/plugin.json
# on main, or the literal sentinel `__CE_UPDATE_VERSION_FAILED__` if the lookup fails.
#
# PowerShell 5.1-compatible port of upstream-version.sh. stdout contract is
# identical: a single line containing the version or the failure sentinel.
#
# Compared to release tags, this reads the current main HEAD because the marketplace
# installs plugin contents from main HEAD; comparing against tags false-positives
# whenever main is ahead of the last tag.

$ErrorActionPreference = 'SilentlyContinue'

$version = gh api repos/EveryInc/tunan-plugin/contents/plugins/tunan/.claude-plugin/plugin.json --jq '.content | @base64d | fromjson | .version' 2>$null

if (-not [string]::IsNullOrWhiteSpace($version)) {
  Write-Output ($version | Select-Object -First 1)
} else {
  Write-Output '__CE_UPDATE_VERSION_FAILED__'
}
