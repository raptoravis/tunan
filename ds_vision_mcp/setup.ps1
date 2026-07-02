# ds_vision_mcp 一键注册/卸载脚本
# 用法: 在本目录右键 "用 PowerShell 运行",或:  powershell -ExecutionPolicy Bypass -File setup.ps1
# 注册:   setup.ps1 [-Name <注册名>] [-Python <python可执行文件>] [-Scope <local|project|user>]
# 卸载:   setup.ps1 -Uninstall [-Name <注册名>] [-Scope <local|project|user>]
#         (-Remove 为兼容别名, 等同 -Uninstall)
# Scope 默认 user(跨项目全局, 写入 ~/.claude.json 顶层 mcpServers);
#   local=仅当前项目, project=项目根 .mcp.json(可入 git)。详见 claude mcp add -h。

param(
    [string]$Name   = "ds-vision",
    [string]$Python = "python",
    [ValidateSet("local","project","user")]
    [string]$Scope  = "user",
    [Alias("Remove")]
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

# 脚本所在目录 -> server.py 绝对路径(用正斜杠,跨平台更稳)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Server    = (Join-Path $ScriptDir "server.py") -replace '\\', '/'

if ($Uninstall) {
    Write-Host "ds_vision_mcp uninstall" -ForegroundColor Cyan
    Write-Host "  name   : $Name"
    Write-Host "  scope  : $Scope"

    if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
        Write-Host "✗ 找不到 claude CLI,请先安装 Claude Code。" -ForegroundColor Red
        exit 1
    }

    Write-Host "`n移除 MCP 注册..." -ForegroundColor DarkGray
    try {
        claude mcp remove $Name -s $Scope
    } catch {
        Write-Host "  $Name 在 [$Scope] scope 未注册(无需移除)" -ForegroundColor Yellow
    }

    Write-Host "`n当前 MCP 列表:" -ForegroundColor Cyan
    claude mcp list

    Write-Host "`n完成。$Name 已从 [$Scope] scope 移除。" -ForegroundColor Green
    exit 0
}

Write-Host "ds_vision_mcp setup" -ForegroundColor Cyan
Write-Host "  server : $Server"
Write-Host "  name   : $Name"
Write-Host "  scope  : $Scope"

# 检查 claude CLI
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host "✗ 找不到 claude CLI,请先安装 Claude Code。" -ForegroundColor Red
    exit 1
}

# 提醒 ~/.env
$EnvFile = Join-Path $HOME ".env"
if (Test-Path $EnvFile) {
    Write-Host "  .env   : $EnvFile (已存在)" -ForegroundColor Green
} else {
    Write-Host "  .env   : $EnvFile (不存在 — 记得写入 DS_VISION_API_KEY)" -ForegroundColor Yellow
}

# 先移除同名旧注册(忽略不存在的报错),再添加
Write-Host "`n移除同名旧注册(如有)..." -ForegroundColor DarkGray
try {
    claude mcp remove $Name -s $Scope 2>$null | Out-Null
} catch {
    Write-Host "  (无旧注册或已忽略)" -ForegroundColor DarkGray
}

Write-Host "注册 MCP..." -ForegroundColor DarkGray
claude mcp add $Name -s $Scope -- $Python "$Server"

# 本地自检
Write-Host "`n本地自检..." -ForegroundColor DarkGray
& $Python (Join-Path $ScriptDir "selftest.py")

Write-Host "`n当前 MCP 列表:" -ForegroundColor Cyan
claude mcp list

Write-Host "`n完成。若上面 $Name 显示 ✓ Connected 即可使用。" -ForegroundColor Green
