# Claude Code Hooks

Portable hooks for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) on Windows that provide:

- **Obsidian logging** — every prompt and response is logged to Obsidian as a nicely-formatted session note with frontmatter, callouts, and a daily index
- **Windows notifications** — balloon notifications when Claude finishes a task or needs your attention, plus a sound on questions

## Prerequisites

- Windows 10/11
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code)
- PowerShell 5.1+
- [Obsidian](https://obsidian.md/) (optional but recommended for the logging hooks)

## Quick install

```powershell
git clone <your-repo-url> claude-hooks
cd claude-hooks
.\install.ps1
```

The installer will:

1. Ask for your Obsidian vault path (or accept the default)
2. Set the `CLAUDE_VAULT` environment variable
3. Copy hook scripts to `~/.claude/`
4. Merge hooks config into `~/.claude/settings.json` (existing settings like `model`, `env`, `enabledPlugins` are preserved)

## Manual install

If you prefer not to run the installer:

1. Copy all `.ps1` files to `%USERPROFILE%\.claude\`
2. Set the `CLAUDE_VAULT` user environment variable to your Obsidian vault path:
   ```powershell
   [Environment]::SetEnvironmentVariable("CLAUDE_VAULT", "C:\path\to\your\vault", "User")
   ```
3. Add the hooks config to `~/.claude/settings.json` — see `install.ps1` for the exact structure. All hook commands follow this pattern:
   ```
   powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File C:\Users\<you>\.claude\<script>.ps1
   ```

## Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `CLAUDE_VAULT` | Path to the Obsidian folder where session logs are written | `C:\Obsidian\Personal\Work\Claude` |

Set it permanently:
```powershell
[Environment]::SetEnvironmentVariable("CLAUDE_VAULT", "D:\MyVault\Claude", "User")
```

## What each hook does

| Script | Hook event | Description |
|--------|-----------|-------------|
| `log_prompt.ps1` | UserPromptSubmit | Logs each user prompt to an Obsidian session note with frontmatter, project folders, and resumed-session linking |
| `log_response.ps1` | Stop | Extracts the last assistant response from the transcript and appends it to the session note; updates duration and daily index |
| `notify_stop.ps1` | Stop | Plays a sound and shows a Windows balloon notification when Claude finishes |
| `notify_notification.ps1` | Notification | Plays a sound and shows a balloon when Claude needs attention |
| `notify_done.ps1` | (spare) | Minimal balloon notification for task completion |
| `notify_question.ps1` | (spare) | Plays a system sound |

## Plugins

These Claude Code plugins complement the hooks. Install via the Claude Code plugin manager:

```
superpowers@superpowers-marketplace
beads@beads-marketplace
context7-plugin@context7-marketplace
claude-md-management@claude-plugins-official
claude-code-setup@claude-plugins-official
```
