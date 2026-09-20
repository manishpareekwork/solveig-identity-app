#!/usr/bin/env bash
# Build APK on APFS cache when project lives on exFAT (/Volumes/...).
# Usage: ./scripts/build-android.sh [debug|release]   (default: release)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="$("$(dirname "$0")/apfs-cache-path.sh" | tail -1)"
MODE="${1:-release}"

if [[ ! -d "$CACHE" ]]; then
  echo "Invalid build cache path: $CACHE" >&2
  exit 1
fi

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

echo ">>> [2/4] flutter pub get…" >&2
flutter pub get
if [[ "${SOLVEIG_FLUTTER_CLEAN:-0}" == "1" ]]; then
  echo ">>> [2/4] flutter clean (release build)…" >&2
  flutter clean
  flutter pub get
fi

if [[ "$MODE" == "debug" ]]; then
  echo ">>> [3/4] Building debug APK (Gradle — often 3–10 min, watch for Running Gradle task…)…" >&2
  flutter build apk --debug "${DART_DEFINES[@]}"
  OUT_NAME="app-debug.apk"
else
  echo ">>> [3/4] Building release APK (Gradle — often 5–15 min, watch for Running Gradle task…)…" >&2
  flutter build apk --release "${DART_DEFINES[@]}"
  OUT_NAME="app-release.apk"
fi

OUT="$ROOT/build/app/outputs/flutter-apk"
mkdir -p "$OUT"
echo ">>> [4/4] Copying APK back to project folder…" >&2
cp "$CACHE/build/app/outputs/flutter-apk/$OUT_NAME" "$OUT/$OUT_NAME"
echo ""
echo ">>> Done. Share this file with your team:"
echo "APK: $OUT/$OUT_NAME"
ls -lh "$OUT/$OUT_NAME"
