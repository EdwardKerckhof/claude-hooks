# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Windows PowerShell hooks for Claude Code that log every session to Obsidian and show Windows balloon notifications. An installer (`install.ps1`) copies everything into `~/.claude/` and wires up `settings.json`.

## Repo contents

- `hooks/` — PowerShell hook scripts (logging + notifications)
- `skills/` — Claude Code skills (synopsis generator)
- `claude-sessions.css` — Obsidian CSS snippet for callout styling
- `install.ps1` — one-step installer

## Architecture

There are two parallel copies of every hook script:
- **Repo copy** (`hooks/`) — the source of truth, what gets committed
- **Installed copy** (`~/.claude/hooks/`) — what Claude Code actually executes

When making changes, update both copies together. Edit the repo copy, then copy it to the installed location (or re-run `install.ps1`).

### Hook data flow

```
Claude Code event
  -> powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File %USERPROFILE%\.claude\hooks\<script>.ps1
    -> stdin: JSON (shape depends on event type)
    -> reads/writes: %TEMP%\claude_session_<id>.txt (session-to-file mapping)
    -> writes: %CLAUDE_VAULT%\<project>\<date>_<time>.md (Obsidian note)
```

### Stdin JSON shapes

**UserPromptSubmit** (received by `log_prompt.ps1`):
```json
{ "session_id": "...", "cwd": "C:\\...", "prompt": "user's message with system tags" }
```

**Stop** (received by `log_response.ps1`, `notify_stop.ps1`):
```json
{ "session_id": "...", "transcript_path": "C:\\...\\<id>.jsonl" }
```

**Notification** (received by `notify_notification.ps1`):
```json
{ "session_id": "...", "message": "..." }
```

### Session state

`log_prompt.ps1` creates a temp file at `%TEMP%\claude_session_<session_id>.txt` mapping the session to its Obsidian file path and prompt counter. `log_response.ps1` reads this to find where to append.

### Key design constraints

- Hooks **must never block Claude Code** — all scripts wrap main logic in `try/catch` and `exit 0`
- Hooks receive JSON on **stdin** (read via `[Console]::OpenStandardInput()` with UTF-8 StreamReader, not `$input`)
- `Format-CalloutContent` just prefixes lines with `> ` — inline backticks and fenced code blocks work fine in Obsidian callouts without special handling
- `log_prompt.ps1` strips system-injected tags (`<system-reminder>`, `<task-notification>`, etc.) before logging
- Output files use UTF-8 without BOM (`New-Object System.Text.UTF8Encoding($false)`)

## Testing changes

No test suite. To verify hook changes:

1. Edit the repo copy in `hooks/`
2. Copy it to the installed location: `%USERPROFILE%\.claude\hooks\`
3. Send a prompt in a Claude Code session
4. Check the resulting Obsidian note at `%CLAUDE_VAULT%\<project>\`

To test notifications directly:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\notify_stop.ps1"
```

## Install

```powershell
.\install.ps1
```

Installs hooks, skills, CSS snippet, sets `CLAUDE_VAULT` env var, and merges hooks config into `~/.claude/settings.json`.
