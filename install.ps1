#Requires -Version 5.1
<#
.SYNOPSIS
    Installs Claude Code hooks for Obsidian logging and Windows notifications.
.DESCRIPTION
    - Prompts for the Obsidian vault path
    - Sets CLAUDE_VAULT as a user-level environment variable
    - Copies hook scripts to ~/.claude/
    - Merges hooks config into ~/.claude/settings.json (preserving existing settings)
#>

param(
    [string]$VaultPath
)

$ErrorActionPreference = "Stop"

Write-Host "`n=== Claude Code Hooks Installer ===" -ForegroundColor Cyan
Write-Host ""

# 1. Prompt for Obsidian vault path
$defaultVault = "C:\Obsidian\Personal\Work\Claude"
if (-not $VaultPath) {
    $VaultPath = Read-Host "Obsidian vault path for Claude logs (default: $defaultVault)"
    if (-not $VaultPath) { $VaultPath = $defaultVault }
}

# Normalize path (remove trailing slash)
$VaultPath = $VaultPath.TrimEnd("\", "/")

# Create vault dir if it doesn't exist
if (-not (Test-Path $VaultPath)) {
    Write-Host "Creating vault directory: $VaultPath" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $VaultPath -Force | Out-Null
}

# 2. Set CLAUDE_VAULT environment variable (user-level, persistent)
[Environment]::SetEnvironmentVariable("CLAUDE_VAULT", $VaultPath, "User")
$env:CLAUDE_VAULT = $VaultPath
Write-Host "[OK] Set CLAUDE_VAULT = $VaultPath" -ForegroundColor Green

# 3. Ensure ~/.claude/ exists
$claudeDir = Join-Path $env:USERPROFILE ".claude"
if (-not (Test-Path $claudeDir)) {
    New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
    Write-Host "[OK] Created $claudeDir" -ForegroundColor Green
}

# 4. Copy hook scripts
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$scripts = @(
    "log_prompt.ps1",
    "log_response.ps1",
    "notify_stop.ps1",
    "notify_notification.ps1",
    "notify_done.ps1",
    "notify_question.ps1"
)

foreach ($script in $scripts) {
    $src = Join-Path $scriptDir $script
    $dst = Join-Path $claudeDir $script
    if (Test-Path $src) {
        Copy-Item -Path $src -Destination $dst -Force
        Write-Host "[OK] Copied $script" -ForegroundColor Green
    } else {
        Write-Host "[SKIP] $script not found in repo" -ForegroundColor Yellow
    }
}

# 5. Build hooks config with absolute paths for this machine
$psExe = "powershell.exe"
$prefix = "$psExe -ExecutionPolicy Bypass -WindowStyle Hidden -File"
$escapedDir = $claudeDir -replace '\\', '\\'

function Get-HookCommand($scriptName) {
    $path = (Join-Path $claudeDir $scriptName) -replace '\\', '\\'
    return "$prefix $path"
}

$hooksConfig = @{
    "Stop" = @(
        @{
            matcher = "*"
            hooks = @(
                @{ type = "command"; command = (Get-HookCommand "notify_stop.ps1") }
                @{ type = "command"; command = (Get-HookCommand "log_response.ps1") }
            )
        }
    )
    "UserPromptSubmit" = @(
        @{
            hooks = @(
                @{ type = "command"; command = (Get-HookCommand "log_prompt.ps1") }
            )
        }
    )
    "Notification" = @(
        @{
            matcher = "*"
            hooks = @(
                @{ type = "command"; command = (Get-HookCommand "notify_notification.ps1") }
            )
        }
    )
}

# 6. Merge into existing settings.json or create new one
$settingsPath = Join-Path $claudeDir "settings.json"
if (Test-Path $settingsPath) {
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
    Write-Host "[OK] Read existing settings.json" -ForegroundColor Green
} else {
    $settings = [PSCustomObject]@{}
    Write-Host "[OK] Creating new settings.json" -ForegroundColor Green
}

# Convert to hashtable for easier manipulation
$settingsHash = @{}
$settings.PSObject.Properties | ForEach-Object {
    $settingsHash[$_.Name] = $_.Value
}

# Replace hooks config
$settingsHash["hooks"] = $hooksConfig

# Write back
$json = $settingsHash | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($settingsPath, $json, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "[OK] Updated settings.json with hooks config" -ForegroundColor Green

Write-Host "`n=== Installation complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Hooks installed to: $claudeDir" -ForegroundColor White
Write-Host "Vault path:         $VaultPath" -ForegroundColor White
Write-Host ""
Write-Host "Start a new Claude Code session to activate the hooks." -ForegroundColor White
Write-Host ""
