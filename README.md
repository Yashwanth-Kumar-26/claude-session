# claude-sessions

Browse and resume [Claude Code](https://claude.ai/code) CLI sessions interactively from the terminal — with no setup, no GUI, just pick a number and go.

## Installation

### Linux / macOS

```bash
sudo curl -L -o /usr/local/bin/claude-sessions \
  https://raw.githubusercontent.com/Yashwanth-Kumar-26/claude-session/main/claude-sessions
sudo chmod +x /usr/local/bin/claude-sessions
```

Dependencies: `bash` 4+, `jq`, `claude` CLI.

### Any OS (Node.js 18+)

```bash
# Run directly with npx (no install needed)
npx github:Yashwanth-Kumar-26/claude-session

# Or install globally
npm install -g https://github.com/Yashwanth-Kumar-26/claude-session
claude-sessions --all
```

Zero dependencies — uses only Node.js built-in `fs`, `path`, `os`, `readline`.

### Windows (PowerShell 5.1+)

```powershell
# Option 1 — save to a project folder
curl -LO https://raw.githubusercontent.com/Yashwanth-Kumar-26/claude-session/main/claude-sessions.ps1

# Option 2 — install as a global command
$dir = "$env:USERPROFILE\Documents\PowerShell\Scripts"
md $dir -Force
curl -Lo "$dir\claude-sessions.ps1" `
  https://raw.githubusercontent.com/Yashwanth-Kumar-26/claude-session/main/claude-sessions.ps1
# Then add $dir to your PATH or run: powershell -File "$dir\claude-sessions.ps1"
```

Dependencies: `claude` CLI in PATH (no `jq` needed — uses native `ConvertFrom-Json`).

## Versions

| File | Language | Platform | Deps |
|------|----------|----------|------|
| `claude-sessions` | Bash | Linux / macOS / WSL | `jq` |
| `claude-sessions.ps1` | PowerShell | Windows | none (native) |
| `claude-sessions.js` | Node.js | Windows / macOS / Linux | none (built-ins) |

All three share the same features, flags, and interactive picker.

## Usage

```
claude-sessions                 sessions for current directory
claude-sessions --all           all projects
claude-sessions --with-mem      include memory-agent/internal sessions
claude-sessions deploy          filter sessions matching "deploy"
```

On Windows:

```
.\claude-sessions.ps1
.\claude-sessions.ps1 -All
.\claude-sessions.ps1 -All -WithMem
.\claude-sessions.ps1 -Filter deploy
```

Node.js (any OS):

```
node claude-sessions.js
node claude-sessions.js --all
node claude-sessions.js --with-mem
node claude-sessions.js deploy
```

Or via `npx` (no download needed):

```
npx github:Yashwanth-Kumar-26/claude-session
```

Pick a session by **number**, paste a **full UUID**, or type a **partial UUID prefix** (e.g. `07947d09` is enough). The tool runs `claude --resume <uuid>` and drops you right back into that session.

## What it looks like

```
  Claude Code sessions  → /home/siddu/MyProJects/X

  1  Give me Everything.md here in this folder including all what we discusse
     fbe1abe4-0945-4516-9c90-ee32e83b16a4  •  11d
  2  /superpowers:brainstorming # PRD v1 — Social Platform for Builders (MVP)
     3265e913-87fd-4b97-8947-a66644136712  •  13d
```

With `--all`:

```
  All Claude Code sessions
  (agent/memory sessions hidden — use --with-mem to show)

  1  /skill-writer for this project…                  [-home-siddu-MyProJects-TeleRiHa]
     8dd00428-5819-4c8a-9ce2-02c4aade4369  •  15d
  2  fix the setup script                              [-home-siddu-claudefree]
     38d0f926-d762-4731-8785-de1d4e7247fe  •  9d
```

## Features

- **Smart labels** — reads `sessions-index.json` first, falls back to extracting your first message from the session JSONL
- **Multi-user** — finds sessions across `$HOME`, `/home/*`, `/root` (or `$env:USERPROFILE` on Windows)
- **Noise filter** — hides `mem-observer`, `knowledge-agent`, and other internal sessions by default (`--with-mem` to show)
- **Partial UUID matching** — type just the first few characters of a session ID
- **Non-interactive safe** — when piped, lists sessions and exits without prompting
- **Case-preserving encoding** — matches Claude Code's actual folder naming exactly

## How it works

Claude Code stores sessions as JSONL files:
- Linux: `~/.claude/projects/<encoded-path>/<uuid>.jsonl`
- Windows: `%USERPROFILE%\.claude\projects\<encoded-path>\<uuid>.jsonl`

The `<encoded-path>` is your working directory with non-alphanumeric characters replaced by `-` (case is preserved). The script scans the right directories, reads `sessions-index.json` for labels, and if there's no index yet it extracts your first user message directly from the session file.

Run `--help` for full options.
