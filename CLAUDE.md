# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Windows hooks for Claude Code that log every session to Obsidian and show desktop notifications. Two standalone Go binaries, pre-built and committed to the repo. An installer (`install.ps1`) copies them to `~/.claude/hooks/` and wires up `settings.json`.

## Repo contents

- `go-hooks/` — Go source code for both binaries
  - `cmd/notify/` — `claude-notify.exe` entry point (desktop notifications via `beeep`)
  - `cmd/obsidian/` — `claude-obsidian.exe` entry point (session logging, stdlib only)
  - `internal/hookdata/` — stdin JSON parsing (shared types)
  - `internal/obsidian/` — Obsidian formatting, frontmatter, daily index, tag stripping
  - `internal/session/` — session-to-file mapping via temp files
  - `bin/` — pre-built binaries (committed, no Go required to install)
- `hooks/` — legacy PowerShell scripts (kept as reference, not used by installer)
- `skills/` — Claude Code skills (synopsis generator)
- `claude-sessions.css` — Obsidian CSS snippet for callout styling
- `install.ps1` — one-step installer

## Architecture

Two independent Go binaries with zero shared code:

| Binary | Source | Purpose | Deps |
|--------|--------|---------|------|
| `claude-notify.exe` | `cmd/notify/` | Desktop notifications | `beeep` |
| `claude-obsidian.exe` | `cmd/obsidian/` | Session logging | stdlib only |

Both binaries have `defer recover()` in `main()` — they must never block Claude Code.

### Hook data flow

```
Claude Code event
  -> C:\Users\<user>\.claude\hooks\claude-obsidian.exe log-prompt
    -> stdin: JSON { session_id, cwd, prompt }
    -> reads/writes: %TEMP%\claude_session_<id>.txt (session mapping)
    -> writes: %CLAUDE_VAULT%\<project>\<date>_<time>.md (Obsidian note)

  -> C:\Users\<user>\.claude\hooks\claude-notify.exe --message "..."
    -> shows Windows toast notification
```

### Stdin JSON shapes

**UserPromptSubmit** (received by `claude-obsidian.exe log-prompt`):
```json
{ "session_id": "...", "cwd": "C:\\...", "prompt": "user's message with system tags" }
```

**Stop** (received by `claude-obsidian.exe log-response`):
```json
{ "session_id": "...", "transcript_path": "C:\\...\\<id>.jsonl" }
```

### Session state

`log-prompt` creates `%TEMP%\claude_session_<session_id>.txt` mapping the session to its Obsidian file path and prompt counter. `log-response` reads this to find where to append. Stale files (>24h) are cleaned up automatically.

### Key design constraints

- Hooks **must never block Claude Code** — both binaries use `defer recover()` and exit silently on errors
- Hooks receive JSON on **stdin** (parsed via `internal/hookdata`)
- `SanitizeProject` strips leading dots (Obsidian hides dotfolders) and illegal path characters
- `StripSystemTags` removes `<system-reminder>`, `<task-notification>`, etc. before logging
- `readTranscript` walks backwards through JSONL (up to 50 lines) to find the last assistant response

## Build

```powershell
cd go-hooks
go build -ldflags="-s -w" -o bin/claude-notify.exe ./cmd/notify
go build -ldflags="-s -w" -o bin/claude-obsidian.exe ./cmd/obsidian
```

After rebuilding, copy to `~/.claude/hooks/` or re-run `install.ps1`.

## Tests

```powershell
cd go-hooks
go test ./internal/obsidian/ -v
```

12 tests covering formatting, frontmatter, truncation, tag stripping, and daily index generation.

## Install

```powershell
.\install.ps1
```

Copies pre-built binaries from `go-hooks/bin/` to `~/.claude/hooks/`, installs skills, CSS snippet, sets `CLAUDE_VAULT` env var, and merges hooks config into `~/.claude/settings.json`.

## Verify

1. Both binaries exist in `~/.claude/hooks/`
2. `settings.json` hooks point to `claude-notify.exe` and `claude-obsidian.exe`
3. `claude-notify.exe --message "Test"` — toast appears
4. Send a prompt in Claude Code — check `%CLAUDE_VAULT%\<project>\` for session file
