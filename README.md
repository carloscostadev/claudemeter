# ClaudeMeter

A lightweight macOS menu bar app that tracks your Claude Code usage in real time — tokens, costs, activity breakdown, and burn rate.

## Features

- **Activity Tracking** — see what you spend on Conversation, Coding, Exploration, Terminal, Planning, and Design
- **Real-time burn rate** — tokens/second with activity states (Sleeping, Idle, Active, Sprinting)
- **Model breakdown** — cost and token usage per model (Opus, Sonnet, Haiku)
- **Period summaries** — quick view of 7 Days, 15 Days, and Monthly totals
- **Launch at login** — starts automatically with macOS

## How It Works

ClaudeMeter reads session data from `~/.claude/` — the same files Claude Code writes locally. No API keys or network requests needed. All data stays on your machine.

## Install

Download the latest `.zip` from [Releases](https://github.com/carloscostadev/claudemeter/releases), unzip, and drag `ClaudeMeter.app` to `/Applications`.

## Development

```bash
# Open in Xcode (with SwiftUI previews)
open Package.swift

# Or build and run from terminal
./scripts/dev.sh
```

## Requirements

- macOS 14.0+
- Xcode 15+ (for development)

## License

MIT
