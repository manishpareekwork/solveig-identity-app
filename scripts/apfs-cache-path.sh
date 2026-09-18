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
echo ">>> [1/4] Syncing project to APFS cache (1–3 min on exFAT, please wait)…" >&2
echo "    $ROOT" >&2
echo " -> $CACHE" >&2
rsync -a --delete --info=progress2 \
  --exclude '._*' \
  --exclude '.DS_Store' \
  --exclude build \
  --exclude .dart_tool \
  --exclude android/.gradle \
  --exclude ios/Pods \
  --exclude .gradle-home \
  "$ROOT/" "$CACHE/"
echo ">>> Sync complete." >&2

echo "$CACHE"
