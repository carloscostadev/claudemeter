# Thoth

[![Latest Release](https://img.shields.io/github/v/release/carloscostadev/thoth)](https://github.com/carloscostadev/thoth/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/carloscostadev/thoth/total)](https://github.com/carloscostadev/thoth/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)
![Swift](https://img.shields.io/badge/swift-5.9-orange)

Named after Thoth, the Egyptian god of writing and measure.

A lightweight macOS menu bar app that turns the JSONL logs Claude Code writes
to disk into a live view of your usage: tokens, costs, activity breakdown,
project ranking, daily trends and burn rate.

No API keys. No network requests. No telemetry. Everything is read locally
from `~/.claude/`.

## Quick start

1. Download from [Releases](https://github.com/carloscostadev/thoth/releases/latest)
2. Drag `Thoth.app` to `/Applications`
3. Right-click the app and pick **Open** once to bypass Gatekeeper
4. Click the icon in the menu bar

## Features

- **Today, this week, this month, all time.** Cost, calls and tokens for each
  window, all on one screen.
- **Live burn rate.** Tokens/second with activity states: Sleeping, Light,
  Active, Sprinting.
- **Activity breakdown.** What you're actually doing today (Conversation,
  Coding, Exploration, Terminal, Planning, Design), classified from the tools
  used in each assistant turn.
- **Model breakdown.** Per-model cost and token share (Opus, Sonnet, Haiku)
  with up-to-date pricing including `claude-opus-4-7`.
- **Trends tab.** Last-30-days daily cost chart, projected month-end cost and
  prompt-cache savings.
- **Projects tab.** Top projects by cost (resolved from each session's `cwd`,
  not just the encoded folder name), plus a weekday × hour heatmap of when
  you burn the most.
- **Project filter.** Slice every number by a single project.
- **Launch at login.** Optional, toggled from the popover.

## How it works

Claude Code writes one JSONL file per session under
`~/.claude/projects/<encoded-cwd>/<session-id>.jsonl`. Thoth watches that
tree and the `~/.claude/sessions/*.json` heartbeats, aggregates every
`message.usage` block it finds, and prices it against a built-in rate card.

To stay cheap on a large history (the author's local tree is ~450 MB across
~600 files), scanning is layered:

- **Active-session poll** every 5 s. Reads only bytes appended since the last
  poll, on a background queue.
- **Today summary** every 5 s. Per-file incremental cache keyed by mtime;
  unchanged files are skipped without I/O.
- **Heavy scan** every 5 min. Per-file aggregate cache keyed by `(mtime,
  size)`. Files that haven't changed contribute their cached numbers without
  being re-parsed. Period buckets (week / 15d / month) are derived from a
  per-day breakdown at aggregation time, so the calendar can advance without
  invalidating caches. Switching the project filter is aggregation-time too,
  so it doesn't re-read any files.

All file I/O and JSON parsing happens on a dedicated serial dispatch queue;
the main thread is reserved for SwiftUI updates.

## Install

Download `Thoth-<version>-mac.zip` from
[Releases](https://github.com/carloscostadev/thoth/releases), unzip it, and
drag `Thoth.app` to `/Applications`.

The first launch is quarantined by Gatekeeper because the binary isn't
notarised. Right-click the app and pick **Open** once to bypass it.

## Development

```bash
# Open in Xcode (with SwiftUI previews)
open Package.swift

# Or build and run from the terminal
./scripts/dev.sh

# Build a release .app bundle into build/
./scripts/build.sh
```

## Requirements

- macOS 14.0+
- Xcode 15+ (for development)

## License

MIT
