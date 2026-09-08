#!/usr/bin/env bash
# Run/build from APFS — exFAT under /Volumes/ creates AppleDouble (._*) files that Gradle
# cannot strip reliably (they are re-created while tasks run).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="${SOLVEIG_APP_CACHE:-$HOME/Library/Caches/solveig-identity-app-build}"

if [[ ! "$ROOT" == /Volumes/* ]]; then
  echo "$ROOT"
  exit 0
fi

mkdir -p "$CACHE"
echo "Syncing project to APFS cache: $CACHE" >&2
rsync -a --delete \
  --exclude build \
  --exclude .dart_tool \
  --exclude android/.gradle \
  --exclude ios/Pods \
  --exclude .gradle-home \
  "$ROOT/" "$CACHE/"

echo "$CACHE"
