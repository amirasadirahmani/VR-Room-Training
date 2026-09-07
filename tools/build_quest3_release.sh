#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRESET="Meta Quest 3"
OUT="$ROOT/builds/quest3/vr-training-room-quest3-release.apk"

find_godot() {
  if command -v godot >/dev/null 2>&1; then command -v godot; return; fi
  if command -v godot4 >/dev/null 2>&1; then command -v godot4; return; fi
  if [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then echo /Applications/Godot.app/Contents/MacOS/Godot; return; fi
  return 1
}
GODOT="${GODOT_BIN:-$(find_godot || true)}"
[[ -n "$GODOT" ]] || { echo "ERROR: Godot not found." >&2; exit 1; }

"$ROOT/tools/quest3_preflight.sh"
cat <<'NOTICE'
Release export requires your own Android release keystore/signing configuration.
This script does not create, store, or guess private signing credentials.
NOTICE
mkdir -p "$(dirname "$OUT")"
"$GODOT" --headless --path "$ROOT" --export-release "$PRESET" "$OUT"
[[ -s "$OUT" ]] || { echo "ERROR: release APK was not created. Configure release signing in Godot first." >&2; exit 1; }
ls -lh "$OUT"
echo "Release APK ready: $OUT"
