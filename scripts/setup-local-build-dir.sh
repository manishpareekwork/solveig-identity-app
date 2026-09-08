#!/usr/bin/env bash
# Projects on /Volumes/ (exFAT) must build from APFS — see scripts/apfs-cache-path.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "$ROOT" == /Volumes/* ]] && [[ -L "$ROOT/build" ]]; then
  rm "$ROOT/build"
  echo "Removed stale build/ symlink."
fi
"$(dirname "$0")/clean-apple-double.sh" 2>/dev/null || true
