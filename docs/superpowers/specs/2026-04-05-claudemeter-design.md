# ClaudeMeter — Design Spec

## Overview

Native macOS menu bar app (SwiftUI, macOS 14+) that monitors Claude Code token usage, cost, and activity in real-time. Reads data directly from `~/.claude/` — no network, no config, no dependencies.

## Data Sources

### 1. Active Sessions — `~/.claude/sessions/*.json`

```json
{
  "pid": 10638,
  "sessionId": "dd05473b-...",
  "cwd": "/Users/carloscosta/Documents/Analises",
  "startedAt": 1775421611997,
  "kind": "interactive",
  "entrypoint": "cli"
}
```

- Each file represents a session. Filename is `<pid>.json`.
- Session is active if the PID is still running (`kill -0 <pid>`).
- `cwd` maps the session to a project group.

### 2. Session Messages — `~/.claude/projects/*/*.jsonl`

- Each line is a JSON object. Assistant messages contain a `message.usage` field:

```json
{
  "message": {
    "model": "claude-opus-4-6",
    "usage": {
      "input_tokens": 3,
      "output_tokens": 39,
      "cache_creation_input_tokens": 6797,
      "cache_read_input_tokens": 11604
    }
  }
}
```

- Used for per-session token counts, cost calculation, and burn rate.

### 3. Aggregated Stats — `~/.claude/stats-cache.json`

```json
{
  "modelUsage": {
    "claude-opus-4-6": {
      "inputTokens": 299825,
      "outputTokens": 530729,
      "cacheReadInputTokens": 838597965,
      "cacheCreationInputTokens": 36091368,
      "costUSD": 0
    }
  },
  "totalSessions": 92,
  "totalMessages": 29588,
  "dailyModelTokens": [...]
}
```

- Used for historical totals and model breakdown.
- Note: `costUSD` is 0 in this file — we calculate cost ourselves from token counts.

## Architecture

```
ClaudeMeter.app
├── ClaudeMeterApp.swift          — App entry point, NSStatusItem setup
├── Models/
│   ├── SessionData.swift         — Session model + active PID check
│   ├── TokenUsage.swift          — Token/cost calculation per message
│   ├── ProjectGroup.swift        — Project grouping logic
│   └── Pricing.swift             — Anthropic pricing constants
├── Services/
│   ├── ClaudeDataService.swift   — Reads ~/.claude/, parses JSONL, polls for changes
│   └── BurnRateTracker.swift     — 60s sliding window burn rate calculation
├── Views/
│   ├── MenuBarIcon.swift         — Animated status bar icon
│   ├── PopoverView.swift         — Main popover container
│   ├── StatusHeaderView.swift    — Connection status + activity state
│   ├── StatsCardsView.swift      — Burn rate, tokens, cost cards
│   ├── ModelsTabView.swift       — Per-model breakdown with progress bars
│   ├── SessionsTabView.swift     — Active sessions list
│   └── ProjectFilterView.swift   — Project group filter dropdown
└── Resources/
    └── Assets.xcassets            — App icon, status bar icon frames
```

## Menu Bar Icon

A sparkle icon (✦) inspired by Claude's branding, with 4 animation states:

| State     | Condition    | Animation                          |
|-----------|--------------|------------------------------------|
| Sleep     | 0 t/s        | Static, 50% opacity                |
| Idle      | < 100 t/s    | Gentle pulse (opacity 70%-100%)    |
| Active    | 100-1000 t/s | Slow rotation                      |
| Sprint    | > 1000 t/s   | Fast rotation + glow effect        |

The icon also shows a tiny cost indicator next to it: e.g., `✦ $82.39`

## Popover UI

### Layout (top to bottom)

**1. Header**
- "ClaudeMeter" title (left)
- Connection status dot + label (right): green "Connected" if any active session, red "No Sessions"

**2. Activity State**
- Large animated icon matching current state
- State label: "Sleeping" / "Idle" / "Active" / "Sprinting"
- Burn rate text: e.g., "6.9k t/s - full throttle"

**3. Stats Cards (3 in a row)**
- Burn Rate: `🔥 BURN RATE` / `6.9k t/s`
- Tokens: `# TOKENS` / `53.87M`
- Cost: `💰 COST` / `$82.39`

**4. Project Filter**
- Dropdown at the top of the tab area
- Options: "All Projects", then auto-detected groups (e.g., "Importrust", "Projetos Internos", etc.)
- Groups are derived from `~/.claude/projects/` directory names by extracting the second-to-last path component from the encoded directory name
- Selecting a group filters all data below (models, sessions, stats cards)
- Each group is expandable to show individual projects within it

**5. Tabs: Models | Sessions**

**Models tab:**
- List of models used (opus, sonnet, haiku)
- Each row: colored dot + model name + cost (right-aligned)
- Progress bar showing percentage of total cost
- Subtitle: token count + session count + percentage

**Sessions tab:**
- List of active sessions
- Each row: project name (from cwd), token count, cost, duration
- Inactive sessions (dead PID) are hidden

**6. Footer**
- "Quit" button (left)
- Version info (right)

### Visual Style
- Dark theme with semi-transparent backgrounds
- Rounded corners (12px)
- Cards with subtle gradient backgrounds
- Colors: orange/yellow for active states, green for connected, magenta for Opus, blue for Sonnet, green for Haiku
- Monospace font for numbers (SF Mono)
- Popover width: ~380px

## Project Grouping Logic

The `~/.claude/projects/` directory contains folders with encoded paths like:
- `-Users-carloscosta-Documents-Importrust-dashboard-importrust`
- `-Users-carloscosta-Documents-Importrust-importrust-hub`
- `-Users-carloscosta-Documents-Projetos Internos - Carlos-ClaudeMeter`

Grouping algorithm:
1. Decode the directory name by replacing `-` with `/` (being careful with multi-word folder names)
2. Extract the path after `Documents/` (or the second meaningful directory)
3. Group by the first directory component: `Importrust`, `Projetos Internos - Carlos`, `Analises`, etc.
4. Display group name as the label, with count of projects
5. "All Projects" shows aggregated totals

## Cost Calculation

Prices per million tokens (as of April 2025):

| Model         | Input   | Output  | Cache Read | Cache Write |
|---------------|---------|---------|------------|-------------|
| claude-opus-4-6   | $15.00  | $75.00  | $1.50      | $18.75      |
| claude-sonnet-4-6 | $3.00   | $15.00  | $0.30      | $3.75       |
| claude-haiku-4-5  | $0.80   | $4.00   | $0.08      | $1.00       |

Formula per message:
```
cost = (input_tokens * input_price
      + output_tokens * output_price
      + cache_read_input_tokens * cache_read_price
      + cache_creation_input_tokens * cache_write_price) / 1_000_000
```

## Burn Rate Calculation

- Maintain a 60-second sliding window of token events
- Poll active session JSONL files every 2 seconds for new lines
- Track file position (byte offset) to only read new lines
- Each new assistant message with `usage` adds a data point: (timestamp, total_tokens)
- Burn rate = sum of tokens in window / window duration
- Tokens per event = input_tokens + output_tokens + cache_read_input_tokens + cache_creation_input_tokens

## Polling Strategy

- **Every 2s:** Check active session JSONLs for new messages (incremental read from last position)
- **Every 10s:** Scan `~/.claude/sessions/` for new/removed session files, verify PIDs
- **Every 60s:** Re-read `stats-cache.json` for historical totals
- Use `DispatchSource.makeFileSystemObjectSource` for file change monitoring where possible

## Build & Install

```sh
cd ClaudeMeter
swift build -c release
# OR
xcodebuild -scheme ClaudeMeter -configuration Release
cp -R build/Release/ClaudeMeter.app /Applications/
```

Single binary, no external dependencies. Built with Swift Package Manager.

## Out of Scope (v1)

- Notifications/alerts for cost thresholds
- Historical charts/graphs
- Menu bar click-through to specific sessions
- Auto-update mechanism
- Preferences window
