# Fix Reasonix on Windows:
#   1. Disable bash sandbox (enforce → off)
#   2. Set permissions mode to yolo (ask → allow)
$configPath = "$env:APPDATA\reasonix\config.toml"

if (-not (Test-Path $configPath)) {
    Write-Host "ERROR: config.toml not found at $configPath" -ForegroundColor Red
    exit 1
}

$content = Get-Content $configPath -Raw -Encoding UTF8
$original = $content
$changes = @()

# 1. Disable bash sandbox
$newContent = $content -replace '\bbash\s*=\s*"enforce"', 'bash    = "off"'
if ($newContent -ne $content) {
    $changes += "[sandbox] bash = ""off""  (was ""enforce"")"
    $content = $newContent
} else {
    Write-Host "bash: already not 'enforce', skipping." -ForegroundColor Gray
}

# 2. Set permissions mode to allow (yolo)
$newContent = $content -replace '(\[permissions\]\s*\n\s*mode\s*=\s*)"ask"', '$1"allow"'
if ($newContent -ne $content) {
    $changes += '[permissions] mode = "allow"  (was "ask")'
    $content = $newContent
} else {
    Write-Host "permissions mode: already not 'ask', skipping." -ForegroundColor Gray
}

if ($changes.Count -eq 0) {
    Write-Host "No changes needed — config is already set correctly." -ForegroundColor Yellow
    exit 0
}

# Backup
$backupPath = "$configPath.bak"
Copy-Item $configPath $backupPath -Force
Write-Host "Backup: $backupPath" -ForegroundColor Cyan

# Write
Set-Content $configPath $content -Encoding UTF8 -NoNewline

Write-Host ""
Write-Host "SUCCESS — the following changes were made:" -ForegroundColor Green
foreach ($c in $changes) {
    Write-Host "  $c" -ForegroundColor White
}
Write-Host ""
Write-Host "NOTE: Reasonix CLI does not support a config key for default YOLO mode."
Write-Host "To start CLI in YOLO mode, use:  reasonix --yolo"
Write-Host 'Or add to your PowerShell profile:  Set-Alias reasonix "reasonix --yolo"'
