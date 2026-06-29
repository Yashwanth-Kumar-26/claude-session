# claude-sessions

Browse and resume [Claude Code](https://claude.ai/code) CLI sessions interactively from the terminal.

## Install

```bash
sudo curl -L -o /usr/local/bin/claude-sessions \
  https://raw.githubusercontent.com/Yashwanth-Kumar-26/claude-session/main/claude-sessions
sudo chmod +x /usr/local/bin/claude-sessions
```

Dependencies: `bash` 4+, `jq`, `claude` CLI.

## Usage

```
claude-sessions                sessions for current directory
claude-sessions --all          all projects
claude-sessions --with-mem     include memory-agent sessions
claude-sessions deploy         filter sessions matching "deploy"
```

Pick a session by number, full UUID, or partial UUID prefix to resume it.

Run `claude-sessions --help` for full options.

## How it works

Sessions live as JSONL files under `~/.claude/projects/<encoded-path>/<uuid>.jsonl`.
The script scans all home directories (`$HOME`, `/home/*`, `/root`) to find them,
reads `sessions-index.json` for labels, and falls back to extracting the first
user prompt from the session file.
