#!/usr/bin/env bash
# Build APK on APFS cache when project lives on exFAT (/Volumes/...).
# Usage: ./scripts/build-android.sh [debug|release]   (default: release)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="$("$(dirname "$0")/apfs-cache-path.sh")"
MODE="${1:-release}"

if [[ "$MODE" != "debug" && "$MODE" != "release" ]]; then
  echo "Usage: $0 [debug|release]" >&2
  exit 1
fi

source "$(dirname "$0")/use-java23.sh"

DART_DEFINES=()
if [[ -f "$ROOT/secrets.json" ]]; then
  DART_DEFINES=(--dart-define-from-file="$ROOT/secrets.json")
fi

if [[ "$CACHE" == "$ROOT" ]]; then
  cd "$ROOT"
else
  cd "$CACHE"
  if [[ -f "$ROOT/secrets.json" ]]; then
    cp "$ROOT/secrets.json" "$CACHE/secrets.json"
    DART_DEFINES=(--dart-define-from-file="$CACHE/secrets.json")
  fi
fi

find . -name '._*' -type f -delete 2>/dev/null || true
flutter pub get
if [[ "${SOLVEIG_FLUTTER_CLEAN:-0}" == "1" ]]; then
  flutter clean
  flutter pub get
fi

if [[ "$MODE" == "debug" ]]; then
  flutter build apk --debug "${DART_DEFINES[@]}"
  OUT_NAME="app-debug.apk"
else
  flutter build apk --release "${DART_DEFINES[@]}"
  OUT_NAME="app-release.apk"
fi

OUT="$ROOT/build/app/outputs/flutter-apk"
mkdir -p "$OUT"
cp "$CACHE/build/app/outputs/flutter-apk/$OUT_NAME" "$OUT/$OUT_NAME"
echo "APK: $OUT/$OUT_NAME"
ls -lh "$OUT/$OUT_NAME"
