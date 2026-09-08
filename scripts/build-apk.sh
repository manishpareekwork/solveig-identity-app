#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="$("$(dirname "$0")/apfs-cache-path.sh")"

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

flutter pub get
flutter build apk --release "${DART_DEFINES[@]}"

OUT="$ROOT/build/app/outputs/flutter-apk"
mkdir -p "$OUT"
cp "$CACHE/build/app/outputs/flutter-apk/app-release.apk" "$OUT/app-release.apk"
echo "APK: $OUT/app-release.apk"
ls -lh "$OUT/app-release.apk"
