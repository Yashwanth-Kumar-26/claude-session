# csessions

Browse and resume [Claude Code](https://claude.ai/code) CLI sessions interactively — zero dependencies, works on Windows / macOS / Linux.

```bash
npm install -g csessions
csessions --all
```

Pick a session by **number**, paste a **full UUID**, or type a **partial prefix** — it runs `claude --resume <id>` and drops you right back in.

## Install

### Recommended — npm (any OS)

```bash
npm install -g csessions
csessions --all
```

Zero dependencies. Uses only Node.js built-in `fs`, `path`, `os`, `readline`.

### Bash (Linux / macOS / WSL)

```bash
sudo curl -L -o /usr/local/bin/claude-sessions \
  https://raw.githubusercontent.com/Yashwanth-Kumar-26/claude-session/main/claude-sessions
sudo chmod +x /usr/local/bin/claude-sessions
```

Requires `bash` 4+, `jq`.

### PowerShell (Windows)

```powershell
curl -LO https://raw.githubusercontent.com/Yashwanth-Kumar-26/claude-session/main/claude-sessions.ps1
.\claude-sessions.ps1 -All
```

No extra deps — uses native `ConvertFrom-Json`.

## Usage

```
csessions                       sessions for current directory
csessions --all                 all projects
csessions --with-mem            include memory-agent/internal sessions
csessions deploy                filter sessions matching "deploy"
```

## What it looks like

```
$ csessions

  Claude Code sessions  → /home/siddu/MyProJects/X

  1  Give me Everything.md here in this folder including all what we discusse
     fbe1abe4-0945-4516-9c90-ee32e83b16a4  •  11d
  2  /superpowers:brainstorming # PRD v1 — Social Platform for Builders (MVP)
     3265e913-87fd-4b97-8947-a66644136712  •  13d

────────────────────────────────────
Pick a session to resume  (# / UUID / prefix / Enter=quit):
> 2
Resuming: 3265e913-87fd-4b97-8947-a66644136712
```

With `--all`:

```
$ csessions --all

  All Claude Code sessions
  (agent/memory sessions hidden — use --with-mem to show)

  1  /skill-writer for this project…                  [-home-siddu-MyProJects-TeleRiHa]
     8dd00428-5819-4c8a-9ce2-02c4aade4369  •  15d
  2  fix the setup script                              [-home-siddu-claudefree]
     38d0f926-d762-4731-8785-de1d4e7247fe  •  9d
```

## Features

- **Smart labels** — reads `sessions-index.json` first, falls back to extracting your first message from the session file
- **Multi-user** — finds sessions across `$HOME`, `/home/*`, `/root` (or `%USERPROFILE%` on Windows)
- **Noise filter** — hides `mem-observer`, `knowledge-agent` and other internal sessions by default (`--with-mem` to show)
- **Partial UUID matching** — type just the first few characters of a session ID
- **Non-interactive safe** — when piped, lists sessions and exits without prompting
- **Case-preserving encoding** — matches Claude Code's actual folder naming exactly

## How it works

Claude Code stores sessions as JSONL files at `~/.claude/projects/<encoded-path>/<uuid>.jsonl`. The `<encoded-path>` is your working directory with non-alphanumeric chars replaced by `-` (case preserved). The tool reads `sessions-index.json` for labels, and falls back to extracting the first user prompt from the session file directly.

## npm

```
https://www.npmjs.com/package/csessions
```
