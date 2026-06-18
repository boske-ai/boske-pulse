#!/usr/bin/env bash
# One-shot local setup for Boske Pulse on macOS.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== Boske Pulse setup =="

if [[ "$(uname)" != "Darwin" ]]; then
  echo "ERROR: Boske Pulse builds on macOS only (Xcode required)."
  exit 1
fi

if [[ ! -f Config/boske-production.json ]]; then
  cp Config/boske-production.example.json Config/boske-production.json
  echo "✓ Created Config/boske-production.json from example"
else
  echo "✓ Config/boske-production.json already exists"
fi

APP_SUPPORT="$HOME/Library/Application Support/Boske Pulse"
mkdir -p "$APP_SUPPORT"
cp Config/boske-production.json "$APP_SUPPORT/boske-production.json"
echo "✓ Synced config to $APP_SUPPORT/boske-production.json (app reads this first)"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Install XcodeGen: brew install xcodegen"
  exit 1
fi

xcodegen generate
echo "✓ Generated BoskePulse.xcodeproj"

echo ""
echo "Next:"
echo "  open BoskePulse.xcodeproj"
echo "  Set signing team on BoskePulse + BoskePulseWidget targets"
echo "  Run (⌘R) — menu bar icon appears top-right"
echo ""
echo "Optional:"
echo "  cd BoskePulseCore && swift test"
