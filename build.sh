#!/bin/bash
set -e
swift build -c release
echo "Build complete: $(swift build -c release --show-bin-path)/ClaudeMeter"
