<#
.SYNOPSIS
    Browse and resume Claude Code CLI sessions interactively.
.DESCRIPTION
    Lists Claude Code sessions from ~\.claude\projects\, shows labels, timestamps,
    and lets you pick one to resume with claude --resume <uuid>.
.PARAMETER All
    Show sessions from all projects (not just current directory).
.PARAMETER WithMem
    Include memory-agent and internal sessions (hidden by default).
.PARAMETER Filter
    Substring filter against session label, project name, or UUID.
.PARAMETER Help
    Show this help message.
.PARAMETER Version
    Show version.
.EXAMPLE
    .\claude-sessions.ps1
    .\claude-sessions.ps1 -All
    .\claude-sessions.ps1 -All -WithMem
    .\claude-sessions.ps1 -Filter deploy
#>

param(
    [switch]$All,
    [switch]$WithMem,
    [switch]$Help,
    [switch]$Version,
    [string]$Filter = ""
)

# --- helpers ---
$uuidRegex = '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
$ESC = [char]27
$RED = "${ESC}[0;31m"; $GREEN = "${ESC}[0;32m"; $YELLOW = "${ESC}[1;33m"
$CYAN = "${ESC}[0;36m"; $BOLD = "${ESC}[1m"; $DIM = "${ESC}[2m"; $RESET = "${ESC}[0m"

function die { Write-Output "${RED}error:${RESET} $args"; exit 1 }

function is-uuid($s) { $s -match $uuidRegex }

# --- path encoding (case-preserving, non-alnum → '-') ---
function Encode-Path($p) {
    return ($p -replace '[^a-zA-Z0-9]', '-')
}

# --- discover .claude/projects ---
$projectBase = Join-Path $env:USERPROFILE ".claude" "projects"
if (-not (Test-Path $projectBase)) {
    die "No .claude/projects directory at $projectBase. Is Claude Code installed?"
}

function Find-ProjectDir($cwd) {
    $encoded = Encode-Path $cwd
    $candidate = Join-Path $projectBase $encoded
    if (Test-Path $candidate) { return $candidate }

    # fallback: scan all folders
    Get-ChildItem $projectBase -Directory | ForEach-Object {
        if ($_.Name -eq $encoded) { return $_.FullName }
    }
    return $null
}

# --- sessions-index.json reader ---
function Read-Index($projectDir) {
    $indexFile = Join-Path $projectDir "sessions-index.json"
    if (-not (Test-Path $indexFile)) { return @{} }

    try {
        $raw = Get-Content $indexFile -Raw -ErrorAction Stop
        $obj = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch { return @{} }

    $index = @{}

    # handle { "sessions": { ... } } wrapper and flat { "<uuid>": { ... } }
    $data = $obj
    if ($obj.sessions -ne $null) { $data = $obj.sessions }

    $data.PSObject.Properties | ForEach-Object {
        $uuid = $_.Name
        if ($uuid -match $uuidRegex) {
            $v = $_.Value
            $index[$uuid] = @{
                name      = if ($v.name)      { $v.name }      else { "" }
                summary   = if ($v.summary)   { $v.summary }   else { "" }
                updatedAt = if ($v.updatedAt) { $v.updatedAt } else { "" }
            }
        }
    }
    return $index
}

# --- internal/memory session detection ---
$internalProjectRe = 'mem-observer|mem_observer|memory-observer|memory_observer'
$internalLabelRe  = '^(You are a Claude-Mem|Hello memory agent|claude-mem|knowledge-agent)'

function Is-Internal($projectName, $label) {
    if ($projectName -match $internalProjectRe) { return $true }
    if ($label -match $internalLabelRe) { return $true }
    return $false
}

# --- best label for a session ---
function Get-SessionLabel($filePath, $sessionId, $index) {
    if ($index.ContainsKey($sessionId)) {
        $entry = $index[$sessionId]
        if ($entry.name -and $entry.name -ne "") { return $entry.name }
        if ($entry.summary -and $entry.summary -ne "") { return $entry.summary }
    }

    # fallback: first user message
    try {
        $reader = [System.IO.StreamReader]::new($filePath)
        while (-not $reader.EndOfStream) {
            $line = $reader.ReadLine()
            if ($line -match '"role":"user"') {
                $msg = $line | ConvertFrom-Json
                $content = $msg.content
                if ($content -is [array]) {
                    $text = ($content | Where-Object { $_.type -eq "text" } | ForEach-Object { $_.text }) -join " "
                } else { $text = "$content" }
                if ($text -and $text.Trim() -ne "") {
                    if ($text.Length -gt 100) { $text = $text.Substring(0, 97) + "…" }
                    return $text.Trim()
                }
                break
            }
        }
    } catch {}

    # another fallback: lastPrompt
    try {
        $reader2 = [System.IO.StreamReader]::new($filePath)
        while (-not $reader2.EndOfStream) {
            $line = $reader2.ReadLine()
            if ($line -match '"lastPrompt"') {
                $lp = ($line | ConvertFrom-Json).lastPrompt
                if ($lp -and $lp.Trim() -ne "") {
                    if ($lp.Length -gt 100) { $lp = $lp.Substring(0, 97) + "…" }
                    return $lp.Trim()
                }
                break
            }
        }
    } catch {}

    return "(no summary)"
}

# --- human time ---
function Format-TimeAgo($epoch) {
    try {
        $dt = [DateTimeOffset]::FromUnixTimeSeconds($epoch)
    } catch {
        $dt = [DateTime]::UnixEpoch.AddSeconds($epoch)
    }
    $diff = [DateTime]::UtcNow - $dt.UtcDateTime
    $totalSec = [int]$diff.TotalSeconds
    if ($totalSec -lt 0)   { return "just now" }
    if ($totalSec -lt 60)   { return "${totalSec}s" }
    if ($totalSec -lt 3600) { return "$([int]($totalSec/60))m" }
    if ($totalSec -lt 86400){ return "$([int]($totalSec/3600))h $([int](($totalSec%3600)/60))m" }
    return "$([int]($totalSec/86400))d"
}

# --- collect sessions from one project ---
$script:sessionIds = @()
$script:sessionCount = 0

function List-Project($projectDir, $showProject, $hideNoise) {
    $projectName = Split-Path $projectDir -Leaf
    $index = Read-Index $projectDir

    $files = Get-ChildItem $projectDir -Filter "*.jsonl" -File `
        | Where-Object { $_.BaseName -match $uuidRegex } `
        | Sort-Object LastWriteTime -Descending

    foreach ($f in $files) {
        $sid = $f.BaseName
        $label = Get-SessionLabel $f.FullName $sid $index

        if ($hideNoise -and (Is-Internal $projectName $label)) { continue }
        if ($Filter -ne "" -and "$label $sid $projectName" -notmatch $Filter) { continue }

        $script:sessionCount++
        $script:sessionIds += $sid

        $time = Format-TimeAgo ($f.LastWriteTimeUtc | Get-Date -UFormat %s)
        $num = "{0,3}" -f $script:sessionCount

        $projHint = ""
        if ($showProject) { $projHint = " ${DIM}[${projectName}]${RESET}" }

        Write-Host "${CYAN}${num}${RESET}  ${BOLD}$($label.Substring(0, [Math]::Min($label.Length, 72)).PadRight(72))${RESET}${projHint}"
        Write-Host "     ${DIM}${sid}  •  ${time}${RESET}"
    }
}

# --- interactive picker ---
function Prompt-Resume {
    if ($script:sessionCount -eq 0) { return }

    $interactive = $true
    try { if ([Console]::IsInputRedirected) { $interactive = $false } } catch {}

    if (-not $interactive) { return }

    Write-Host ""
    Write-Host "${DIM}────────────────────────────────────${RESET}"
    Write-Host "${BOLD}Pick a session to resume${RESET}  ${DIM}(# / UUID / prefix / Enter=quit)${RESET}"
    Write-Host -NoNewline "> "
    $choice = Read-Host
    if ([string]::IsNullOrEmpty($choice)) { Write-Host "Bye."; return }

    $sid = ""
    if (is-uuid $choice) {
        $sid = $choice
    } elseif ($choice -match '^\d+$') {
        $idx = [int]$choice - 1
        if ($idx -ge 0 -and $idx -lt $script:sessionIds.Count) { $sid = $script:sessionIds[$idx] }
    } else {
        # partial UUID prefix
        $matches = $script:sessionIds | Where-Object { $_ -like "$choice*" }
        if ($matches.Count -eq 1) { $sid = $matches[0] }
        elseif ($matches.Count -gt 1) { Write-Host "${YELLOW}multiple match, be more specific${RESET}"; Prompt-Resume; return }
    }

    if (-not $sid) { Write-Host "${RED}invalid${RESET}"; Prompt-Resume; return }
    Write-Host ""
    Write-Host "${GREEN}Resuming:${RESET} ${BOLD}$sid${RESET}"
    Write-Host ""
    & claude --resume $sid
}

# ============================================================
# main
# ============================================================
if ($Help) {
    Write-Output @"
Usage: claude-sessions.ps1 [OPTIONS] [-Filter <query>]

Browse and resume Claude Code sessions interactively.

Options:
  -All        Show sessions from all projects (not just cwd)
  -WithMem    Include memory-agent and internal sessions
  -Help, -h   This help
  -Version    Show version

Arguments:
  -Filter     Substring filter against session label / project / UUID

Examples:
  .\claude-sessions.ps1           sessions for current directory
  .\claude-sessions.ps1 -All      all projects
  .\claude-sessions.ps1 -All -WithMem  include agent sessions
  .\claude-sessions.ps1 -Filter deploy  only matching "deploy"
"@
    exit 0
}
if ($Version) { Write-Output "claude-sessions 1.0.0"; exit 0 }

# verify claude is available
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    die "'claude' not found in PATH. Is Claude Code installed?"
}

# header
if ($All) {
    Write-Host "${BOLD}${YELLOW}All Claude Code sessions${RESET}"
    if (-not $WithMem) { Write-Host "${DIM}(agent/memory sessions hidden - use -WithMem to show)${RESET}" }
    Write-Host ""
    Get-ChildItem $projectBase -Directory | ForEach-Object {
        List-Project $_.FullName $true (-not $WithMem)
    }
} else {
    $cwd = (Get-Location).Path
    $projDir = Find-ProjectDir $cwd

    Write-Host "${BOLD}${YELLOW}Claude Code sessions${RESET}  ${DIM}→ ${cwd}${RESET}"

    if (-not $projDir) {
        Write-Host "${DIM}No sessions for this directory.${RESET}"
        Write-Host "${DIM}Try ${BOLD}claude-sessions -All${DIM} to browse all projects.${RESET}"
        exit 0
    }
    Write-Host ""
    List-Project $projDir $false (-not $WithMem)
    if ($script:sessionCount -eq 0) { Write-Host "${DIM}(none)${RESET}" }
}

Prompt-Resume
