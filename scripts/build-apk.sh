#!/usr/bin/env bash
# Release APK — delegates to build-android.sh (APFS cache on exFAT volumes).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export SOLVEIG_FLUTTER_CLEAN=1
exec "$ROOT/scripts/build-android.sh" release
