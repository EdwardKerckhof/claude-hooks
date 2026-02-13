# Claude Code Hooks

Portable hooks for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) on Windows that provide:

- **Obsidian logging** — every prompt and response is logged to Obsidian as a nicely-formatted session note with frontmatter, callouts, and a daily index
- **Windows notifications** — balloon notifications when Claude finishes a task or needs your attention

## Prerequisites

- Windows 10/11
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code)
- [Obsidian](https://obsidian.md/) (for the logging hooks)

## Quick install

```powershell
git clone https://github.com/Valiice/claude-hooks.git
cd claude-hooks
.\install.ps1
```

The installer will:

1. Ask for your Obsidian vault path (the folder where session logs will be written)
2. Set the `CLAUDE_VAULT` environment variable (user-level, persistent)
3. Copy pre-built Go binaries (`claude-notify.exe`, `claude-obsidian.exe`) to `~/.claude/hooks/`
4. Copy skills to `~/.claude/skills/`
5. Install `claude-sessions.css` to your Obsidian vault's snippets folder
6. Merge hooks config into `~/.claude/settings.json` (existing settings are preserved)
7. Clean up old `claude-hooks.exe` if present

No Go installation required — the pre-built binaries are included in the repo.

## Install with Claude

You can also ask Claude Code to install the hooks for you. Clone the repo and tell Claude:

> Install the claude-hooks from `C:\path\to\claude-hooks`. Run `install.ps1` with my vault path `C:\path\to\vault\Claude`. Then verify that:
> - `claude-notify.exe` and `claude-obsidian.exe` were copied to `~/.claude/hooks/`
> - `settings.json` hooks point to the correct exe paths
> - The Go binaries do NOT need to be rebuilt — they're pre-built in `go-hooks/bin/`
> - Start a new session and check that Obsidian session files are being created in the vault

## Manual install

If you prefer not to run the installer:

1. Copy `go-hooks\bin\claude-notify.exe` and `go-hooks\bin\claude-obsidian.exe` to `%USERPROFILE%\.claude\hooks\`
2. Copy the `skills\` folder to `%USERPROFILE%\.claude\skills\`
3. Copy `claude-sessions.css` to your vault's `.obsidian\snippets\` folder
4. Set the `CLAUDE_VAULT` user environment variable to your Obsidian vault path:
   ```powershell
   [Environment]::SetEnvironmentVariable("CLAUDE_VAULT", "C:\path\to\your\vault\Claude", "User")
   ```
5. Add the hooks config to `~/.claude/settings.json`:
   ```json
   {
     "hooks": {
       "Stop": [{
         "matcher": "*",
         "hooks": [
           { "type": "command", "command": "C:\\Users\\<you>\\.claude\\hooks\\claude-notify.exe --message \"Waiting for you!\"" },
           { "type": "command", "command": "C:\\Users\\<you>\\.claude\\hooks\\claude-obsidian.exe log-response" }
         ]
       }],
       "UserPromptSubmit": [{
         "hooks": [
           { "type": "command", "command": "C:\\Users\\<you>\\.claude\\hooks\\claude-obsidian.exe log-prompt" }
         ]
       }],
       "Notification": [{
         "matcher": "*",
         "hooks": [
           { "type": "command", "command": "C:\\Users\\<you>\\.claude\\hooks\\claude-notify.exe --message \"Needs your attention!\"" }
         ]
       }]
     }
   }
   ```

## Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `CLAUDE_VAULT` | Path to the Obsidian folder where session logs are written | *(set by installer)* |

Set it permanently:
```powershell
[Environment]::SetEnvironmentVariable("CLAUDE_VAULT", "D:\MyVault\Claude", "User")
```

## Architecture

The hooks use two standalone Go binaries with zero shared code:

| Binary | Purpose | Commands | External Deps |
|--------|---------|----------|---------------|
| `claude-notify.exe` | Desktop notifications | `--title`, `--message` flags | `beeep` |
| `claude-obsidian.exe` | Session logging | `log-prompt`, `log-response` subcommands | None (stdlib only) |

Source code is in `go-hooks/cmd/notify/` and `go-hooks/cmd/obsidian/`. Internal packages (`internal/hookdata/`, `internal/obsidian/`, `internal/session/`) are used only by the obsidian binary.

### Rebuilding (for contributors)

If you modify the Go source, rebuild and commit the binaries:

```powershell
cd go-hooks
go build -ldflags="-s -w" -o bin/claude-notify.exe ./cmd/notify
go build -ldflags="-s -w" -o bin/claude-obsidian.exe ./cmd/obsidian
```

### Legacy PowerShell hooks

The `hooks/` folder contains the original PowerShell implementations. These are kept as reference but are no longer used by the installer. The Go binaries are significantly faster (~5ms startup vs ~500ms for PowerShell).

## Skills

The installer copies Claude Code skills to `~/.claude/skills/`. These are available as slash commands in any Claude Code session.

| Skill | Command | Description |
|-------|---------|-------------|
| synopsis | `/synopsis` | Generates a retrospective of your Claude Code sessions from the Obsidian logs and writes it to the vault. Supports arguments: `/synopsis`, `/synopsis 2026-02-12`, `/synopsis week` |

## Obsidian CSS snippet

`claude-sessions.css` styles the custom callouts (`[!user]`, `[!claude]`, `[!plan]`) used in the session notes.

The installer copies this to your vault automatically. To enable it in Obsidian:

**Settings > Appearance > CSS snippets** > enable **claude-sessions**

If you installed manually, copy `claude-sessions.css` to your vault's `.obsidian/snippets/` folder.
