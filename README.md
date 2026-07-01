# csessions

> Browse and resume **Claude Code CLI** sessions interactively.
> **Zero dependencies. Cross-platform. Fast.**

[![npm version](https://img.shields.io/npm/v/csessions)](https://www.npmjs.com/package/csessions)
[![npm downloads](https://img.shields.io/npm/dm/csessions)](https://www.npmjs.com/package/csessions)
[![License](https://img.shields.io/github/license/Yashwanth-Kumar-26/claude-session)](https://github.com/Yashwanth-Kumar-26/claude-session)

## Features

* Browse Claude Code sessions interactively
* Resume any session instantly
* Falls back to the first user prompt when no title exists
* Hides internal memory/agent sessions by default
* Works on **Windows**, **macOS**, and **Linux**
* Zero runtime dependencies (Node.js built-ins only)

---

## Installation

### npm (Recommended)

```bash
npm install -g csessions
```

Resume sessions for the current project:

```bash
csessions
```

Show sessions from every project:

```bash
csessions --all
```

---

### Bash (Linux / macOS / WSL)

```bash
sudo curl -L \
  -o /usr/local/bin/claude-sessions \
  https://raw.githubusercontent.com/Yashwanth-Kumar-26/claude-session/main/claude-sessions

sudo chmod +x /usr/local/bin/claude-sessions
```

**Requirements**

* Bash 4+
* jq

---

### PowerShell (Windows)

```powershell
curl -LO https://raw.githubusercontent.com/Yashwanth-Kumar-26/claude-session/main/claude-sessions.ps1

.\claude-sessions.ps1 -All
```

No additional dependencies required.

---

## Usage

```bash
csessions
```

Browse sessions for the current directory.

```bash
csessions --all
```

Browse sessions across all projects.

```bash
csessions --with-mem
```

Include internal memory/agent sessions.

```bash
csessions deploy
```

Filter sessions containing **"deploy"**.

---

## Example

```text
$ csessions

  Claude Code sessions → /home/user/project

  1  Give me Everything.md here in this folder...
     fbe1abe4-0945-4516-9c90-ee32e83b16a4 • 11d

  2  PRD v1 — Social for Builders
     3265e913-87fd-4b97-8947-a66644136712 • 13d

──────────────────────────────────────────

Pick a session (# / UUID / prefix / Enter = quit):
> 2

Resuming: 3265e913-87fd-4b97-8947-a66644136712
```

---

## How It Works

Claude Code stores conversations as JSONL files under:

```text
~/.claude/projects/<encoded-path>/<uuid>.jsonl
```

`csessions`:

1. Finds available sessions.
2. Reads `sessions-index.json` for labels.
3. Falls back to the first user message when necessary.
4. Lets you select a session interactively.
5. Runs:

```bash
claude --resume <session-id>
```

---

## Smart Features

* **Interactive session picker**
* **Partial UUID matching**
* **Session title extraction**
* **Current-project or all-project browsing**
* **Automatic filtering of internal Claude sessions**
* **Safe non-interactive mode** (lists sessions without prompting)
* **Case-preserving path encoding** matching Claude Code

---

## Requirements

### npm version

* Node.js 18+
* No external dependencies

### Bash version

* Bash 4+
* jq

### PowerShell version

* PowerShell 5+
* Native `ConvertFrom-Json`

---

## Links

* **npm:** https://www.npmjs.com/package/csessions
* **GitHub:** https://github.com/Yashwanth-Kumar-26/claude-session

---

Made for people who use **Claude Code** every day and want to jump back into any conversation in seconds.
