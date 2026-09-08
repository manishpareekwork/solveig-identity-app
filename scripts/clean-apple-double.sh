#!/usr/bin/env bash
# macOS on exFAT (/Volumes/*) creates AppleDouble (._*) files that break Android resource parsing.
# Gradle strips them automatically (see android/build.gradle.kts). This script removes stale ones.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"

if [[ ! -d "$BUILD" ]]; then
  echo "No build/ directory yet."
  exit 0
fi

count="$(find "$BUILD" -name '._*' -print | wc -l | tr -d ' ')"
if [[ "$count" == "0" ]]; then
  echo "No AppleDouble files under build/."
  exit 0
fi

find "$BUILD" -name '._*' -delete
echo "Removed $count AppleDouble (._*) files under build/."
