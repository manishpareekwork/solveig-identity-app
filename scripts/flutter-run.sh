#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="$("$(dirname "$0")/apfs-cache-path.sh")"
DART_DEFINES=()
if [[ -f "$ROOT/secrets.json" ]]; then
  DART_DEFINES=(--dart-define-from-file="$ROOT/secrets.json")
fi

if [[ "$CACHE" == "$ROOT" ]]; then
  cd "$ROOT"
  source "$(dirname "$0")/use-java23.sh"
  flutter pub get
  flutter run "${DART_DEFINES[@]}" "$@"
  exit 0
fi

source "$(dirname "$0")/use-java23.sh"
cd "$CACHE"
flutter pub get
# APFS cache copy may not have secrets.json — pass from source tree.
if [[ -f "$ROOT/secrets.json" ]]; then
  cp "$ROOT/secrets.json" "$CACHE/secrets.json"
  DART_DEFINES=(--dart-define-from-file="$CACHE/secrets.json")
fi
flutter run "${DART_DEFINES[@]}" "$@"
