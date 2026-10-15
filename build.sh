#!/usr/bin/env bash
set -e
cd ~/iOS/rental
echo "=== xtool dev build ==="
xtool dev build 2>&1 | tail -60
echo "=== output ==="
ls -la xtool/ 2>/dev/null || true
