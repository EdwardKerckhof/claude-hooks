#Requires -Version 5.1
<#
.SYNOPSIS
    Installs Claude Code hooks for Obsidian logging and Windows notifications.
.DESCRIPTION
    - Prompts for the Obsidian vault path
    - Sets CLAUDE_VAULT as a user-level environment variable
    - Copies hook scripts to ~/.claude/hooks/
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

# 3. Ensure ~/.claude/hooks/ exists
$claudeDir = Join-Path $env:USERPROFILE ".claude"
$hooksDir = Join-Path $claudeDir "hooks"
if (-not (Test-Path $hooksDir)) {
    New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null
    Write-Host "[OK] Created $hooksDir" -ForegroundColor Green
}

# 4. Copy hook scripts from repo's hooks/ folder
$scriptDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "hooks"
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
    $dst = Join-Path $hooksDir $script
    if (Test-Path $src) {
        Copy-Item -Path $src -Destination $dst -Force
        Write-Host "[OK] Copied $script" -ForegroundColor Green
    } else {
        Write-Host "[SKIP] $script not found in repo" -ForegroundColor Yellow
    }
}

# 5. Build hooks config with absolute paths for this machine
$prefix = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File"

function Get-HookCommand($scriptName) {
    $path = Join-Path $hooksDir $scriptName
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
$utf8 = New-Object System.Text.UTF8Encoding($false)

if (Test-Path $settingsPath) {
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
    Write-Host "[OK] Read existing settings.json" -ForegroundColor Green
} else {
    $settings = [PSCustomObject]@{}
    Write-Host "[OK] Creating new settings.json" -ForegroundColor Green
}

# Replace hooks on the PSCustomObject directly (preserves key order from original file)
if ($settings.PSObject.Properties['hooks']) {
    $settings.hooks = $hooksConfig
} else {
    $settings | Add-Member -NotePropertyName 'hooks' -NotePropertyValue $hooksConfig
}

# Serialize and reformat (PS 5.1's ConvertTo-Json uses inconsistent indentation)
$json = $settings | ConvertTo-Json -Depth 10
$level = 0
$formatted = @()
foreach ($line in ($json -split "`n")) {
    $trimmed = $line.Trim()
    if (-not $trimmed) { continue }
    $trimmed = $trimmed -replace ':\s{2,}', ': '
    if ($trimmed -match '^[\}\]]') { $level = [Math]::Max(0, $level - 1) }
    $formatted += ('  ' * $level) + $trimmed
    if ($trimmed -match '[\{\[]\s*$') { $level++ }
}
$json = $formatted -join "`n"

[System.IO.File]::WriteAllText($settingsPath, $json, $utf8)
Write-Host "[OK] Updated settings.json with hooks config" -ForegroundColor Green

# 7. Install Obsidian CSS snippet
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$cssSource = Join-Path $repoRoot "claude-sessions.css"
if (Test-Path $cssSource) {
    # Walk up from vault path to find .obsidian/snippets/
    $vaultRoot = $VaultPath
    while ($vaultRoot -and -not (Test-Path (Join-Path $vaultRoot ".obsidian"))) {
        $vaultRoot = Split-Path $vaultRoot -Parent
    }
    if ($vaultRoot) {
        $snippetsDir = Join-Path $vaultRoot ".obsidian\snippets"
        if (-not (Test-Path $snippetsDir)) {
            New-Item -ItemType Directory -Path $snippetsDir -Force | Out-Null
        }
        Copy-Item -Path $cssSource -Destination (Join-Path $snippetsDir "claude-sessions.css") -Force
        Write-Host "[OK] Installed claude-sessions.css to Obsidian snippets" -ForegroundColor Green
        Write-Host "     Enable it in Obsidian: Settings > Appearance > CSS snippets" -ForegroundColor Gray
    } else {
        Write-Host "[SKIP] Could not find .obsidian folder - copy claude-sessions.css manually" -ForegroundColor Yellow
    }
}

Write-Host "`n=== Installation complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Hooks installed to: $hooksDir" -ForegroundColor White
Write-Host "Vault path:         $VaultPath" -ForegroundColor White
Write-Host ""
Write-Host "Start a new Claude Code session to activate the hooks." -ForegroundColor White
Write-Host ""
