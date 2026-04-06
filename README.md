# ClaudeMeter

A macOS menu bar app that tracks your Claude API usage in real time — tokens, cost, sessions, and burn rate.

## Features

- Real-time token and cost tracking
- Burn rate monitoring (tokens/second)
- Session history with project grouping
- Model breakdown with usage percentages
- Launch at login support

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
