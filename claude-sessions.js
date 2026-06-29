#!/usr/bin/env node
/**
 * claude-sessions — browse & resume Claude Code CLI sessions.
 * Zero dependencies, works on Windows / macOS / Linux.
 */
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');
const readline = require('readline');
const { spawn } = require('child_process');
const pkg = require('./package.json');

// ── Colours (ANSI, stripped when piped) ──────────────────────────
const tty = process.stdout.isTTY;
const esc = (n, s) => tty ? `\x1b[${n}${s}\x1b[0m` : s;
const R = s => esc('0;31m', s);  // red
const G = s => esc('0;32m', s);  // green
const Y = s => esc('1;33m', s);  // yellow
const C = s => esc('0;36m', s);  // cyan
const B = s => esc('1m', s);     // bold
const D = s => esc('2m', s);     // dim

// ── Helpers ──────────────────────────────────────────────────────
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const die = m => (console.error(R(`error: ${m}`)), process.exit(1));
const home = os.homedir();

// ── Discover all .claude/projects directories ────────────────────
function findBases() {
  const dirs = [];
  const seen = new Set();
  const add = d => { if (d && fs.existsSync(d) && !seen.has(d)) { seen.add(d); dirs.push(d); } };
  add(path.join(home, '.claude', 'projects'));
  // Multi-user on Linux: scan /home/* and /root
  if (process.platform === 'linux') {
    try {
      for (const u of fs.readdirSync('/home')) add(path.join('/home', u, '.claude', 'projects'));
      add('/root/.claude/projects');
    } catch {}
  }
  if (!dirs.length) die('No .claude/projects/ found.');
  return dirs;
}
// Allow env override (like the bash version)
const BASES = process.env.CLAUDE_PROJECTS_DIR
  ? [process.env.CLAUDE_PROJECTS_DIR].filter(d => fs.existsSync(d))
  : findBases();
if (!BASES.length) die('No .claude/projects/ found (checked $HOME, /home/*, /root).');

// ── Path encoding (case-preserving) ───────────────────────────────
const encodePath = p => p.replace(/[^a-zA-Z0-9]/g, '-');

function findProjectDir(cwd) {
  const enc = encodePath(cwd);
  for (const base of BASES) {
    const c = path.join(base, enc);
    if (fs.existsSync(c)) return c;
  }
  return null;
}

// ── sessions-index.json reader ────────────────────────────────────
function readIndex(dir) {
  const fp = path.join(dir, 'sessions-index.json');
  if (!fs.existsSync(fp)) return {};
  try {
    const raw = fs.readFileSync(fp, 'utf8');
    const obj = JSON.parse(raw);
    const data = obj && typeof obj.sessions === 'object' ? obj.sessions : obj;
    const idx = {};
    for (const [k, v] of Object.entries(data))
      if (UUID_RE.test(k)) idx[k] = { name: v.name || '', summary: v.summary || '', updatedAt: v.updatedAt || '' };
    return idx;
  } catch { return {}; }
}

// ── Session label (index → first user msg → lastPrompt) ──────────
function getLabel(fp, sid, idx) {
  const e = idx[sid];
  if (e?.name) return e.name;
  if (e?.summary) return e.summary;
  try {
    const lines = fs.readFileSync(fp, 'utf8').split('\n');
    // first user message
    for (const line of lines) {
      if (!line.includes('"role":"user"')) continue;
      try {
        const msg = JSON.parse(line);
        const c = msg.content;
        let t = Array.isArray(c) ? c.filter(x => x.type === 'text').map(x => x.text).join(' ') : String(c ?? '');
        t = t.trim();
        if (t) return t.length > 100 ? t.slice(0, 97) + '…' : t;
      } catch {}
      break;
    }
    // lastPrompt fallback
    for (const line of lines) {
      if (!line.includes('"lastPrompt"')) continue;
      try {
        let t = JSON.parse(line).lastPrompt?.trim() ?? '';
        if (t) return t.length > 100 ? t.slice(0, 97) + '…' : t;
      } catch {}
      break;
    }
  } catch {}
  return '(no summary)';
}

// ── Noise filter ──────────────────────────────────────────────────
const IS_RE = /mem-observer|mem_observer|memory-observer|memory_observer/i;
const IL_RE = /^(You are a Claude-Mem|Hello memory agent|claude-mem|knowledge-agent)/i;
const isNoise = (proj, label) => IS_RE.test(proj) || IL_RE.test(label);

const timeAgo = ms => {
  const d = Math.floor((Date.now() - ms) / 1000);
  if (d < 0) return 'just now';
  if (d < 60) return `${d}s`;
  if (d < 3600) return `${Math.floor(d / 60)}m`;
  if (d < 86400) return `${Math.floor(d / 3600)}h ${Math.floor((d % 3600) / 60)}m`;
  return `${Math.floor(d / 86400)}d`;
};

// ── Collect sessions from one project directory ───────────────────
function collect(dir, hideNoise, filter) {
  const proj = path.basename(dir);
  const idx = readIndex(dir);
  let files;
  try { files = fs.readdirSync(dir); } catch { return []; }
  return files
    .filter(f => f.endsWith('.jsonl'))
    .map(f => ({ name: f, sid: f.slice(0, -6) }))
    .filter(f => UUID_RE.test(f.sid))
    .map(f => {
      const st = fs.statSync(path.join(dir, f.name), { throwIfNoEntry: false });
      return { ...f, mtime: st?.mtimeMs ?? 0, path: path.join(dir, f.name) };
    })
    .filter(f => f.mtime)
    .sort((a, b) => b.mtime - a.mtime)
    .flatMap(f => {
      const label = getLabel(f.path, f.sid, idx);
      if (hideNoise && isNoise(proj, label)) return [];
      if (filter && !`${label} ${f.sid} ${proj}`.toLowerCase().includes(filter.toLowerCase())) return [];
      return [{ sid: f.sid, label, proj, mtime: f.mtime }];
    });
}

// ── Interactive picker ────────────────────────────────────────────
function picker(sessions) {
  if (!sessions.length) return;
  if (!process.stdin.isTTY) return;
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  const ask = () => {
    console.log(`\n${D('────────────────────────────────────')}`);
    rl.question(`${B('Pick a session to resume')}  ${D('(# / UUID / prefix / Enter=quit): ')}`, choice => {
      choice = choice.trim();
      if (!choice) { console.log('Bye.'); return rl.close(); }
      let sid;
      if (UUID_RE.test(choice)) sid = choice;
      else if (/^\d+$/.test(choice)) sid = sessions[+choice - 1]?.sid;
      else {
        const m = sessions.filter(s => s.sid.startsWith(choice));
        if (m.length === 1) sid = m[0].sid;
        else if (m.length > 1) { console.log(Y('multiple match, be more specific')); return rl.close(); }
      }
      if (!sid) { console.log(R('invalid')); return rl.close(); }
      rl.close();
      console.log(`\n${G('Resuming:')} ${B(sid)}\n`);
      const child = spawn('claude', ['--resume', sid], { stdio: 'inherit' });
      child.on('close', code => process.exit(code ?? 0));
    });
  };
  ask();
}

// ── Main ──────────────────────────────────────────────────────────
function main() {
  const args = process.argv.slice(2);
  let all = false, hideNoise = true, filter = '';

  for (const a of args) {
    if (a === '--help' || a === '-h') {
      console.log(`
Usage: claude-sessions [OPTIONS] [<filter>]

Browse and resume Claude Code sessions interactively.

Options:
  --all        Show sessions from all projects (not just cwd)
  --with-mem   Include memory-agent and internal sessions
  --help, -h   This help
  --version    Show version

Arguments:
  <filter>     Substring filter against session label / project / UUID

Examples:
  claude-sessions           sessions for current directory
  claude-sessions --all     all projects
  claude-sessions --with-mem    include agent sessions
  claude-sessions deploy    only sessions matching "deploy"
`);
      process.exit(0);
    }
    if (a === '--version') { console.log(`claude-sessions ${pkg?.version || '1.0.0'}`); process.exit(0); }
    if (a === '--all') { all = true; continue; }
    if (a === '--with-mem') { hideNoise = false; continue; }
    if (a.startsWith('-')) die(`Unknown flag: ${a}`);
    filter = a;
  }

  let sessions;
  if (all) {
    console.log(`${B(Y('All Claude Code sessions'))}`);
    if (hideNoise) console.log(D('(agent/memory sessions hidden — use --with-mem to show)'));
    console.log();
    sessions = BASES.flatMap(base => {
      let dirs;
      try { dirs = fs.readdirSync(base); } catch { return []; }
      return dirs.flatMap(d => {
        const fp = path.join(base, d);
        return fs.statSync(fp, { throwIfNoEntry: false })?.isDirectory() ? collect(fp, hideNoise, filter) : [];
      });
    });
  } else {
    const cwd = process.cwd();
    const projDir = findProjectDir(cwd);
    console.log(`${B(Y('Claude Code sessions'))}  ${D(`→ ${cwd}`)}`);
    if (!projDir) {
      console.log(D('No sessions for this directory.'));
      console.log(`${D('Try ')}${B('claude-sessions --all')}${D(' to browse all projects.')}`);
      process.exit(0);
    }
    console.log();
    sessions = collect(projDir, hideNoise, filter);
    if (!sessions.length) console.log(D('(none)'));
  }

  sessions.sort((a, b) => b.mtime - a.mtime);
  sessions.forEach((s, i) => {
    const num = String(i + 1).padStart(3);
    const lbl = s.label.padEnd(72).slice(0, 72);
    const hint = all ? ` ${D(`[${s.proj}]`)}` : '';
    console.log(`${C(num)}  ${B(lbl)}${hint}`);
    console.log(`     ${D(`${s.sid}  •  ${timeAgo(s.mtime)}`)}`);
  });

  picker(sessions);
}

if (require.main === module) main();
