#!/usr/bin/env bash
# Remove AppleDouble (._*) and Gradle outputs after a failed build on exFAT (/Volumes/...).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
echo "Cleaning build outputs and AppleDouble files under $ROOT"
find . -name '._*' -type f -delete 2>/dev/null || true
dot_clean -m . 2>/dev/null || true
rm -rf build android/.gradle android/app/build android/build .dart_tool
echo ""
echo "Done. Do NOT run 'flutter build' or 'flutter run' directly on /Volumes — use:"
echo "  ./scripts/flutter-run.sh          # debug on device/emulator"
echo "  ./scripts/build-android.sh debug  # debug APK"
echo "  ./scripts/build-apk.sh            # release APK"
