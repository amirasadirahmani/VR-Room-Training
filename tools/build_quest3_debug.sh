#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRESET="Meta Quest 3"
OUT="$ROOT/builds/quest3/vr-training-room-quest3-debug.apk"

find_godot() {
  if command -v godot >/dev/null 2>&1; then command -v godot; return; fi
  if command -v godot4 >/dev/null 2>&1; then command -v godot4; return; fi
  if [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then echo /Applications/Godot.app/Contents/MacOS/Godot; return; fi
  return 1
}
GODOT="${GODOT_BIN:-$(find_godot || true)}"
[[ -n "$GODOT" ]] || { echo "ERROR: Godot not found." >&2; exit 1; }

"$ROOT/tools/quest3_preflight.sh"
mkdir -p "$(dirname "$OUT")"
echo "Building Quest 3 debug APK..."
"$GODOT" --headless --path "$ROOT" --export-debug "$PRESET" "$OUT"
[[ -s "$OUT" ]] || { echo "ERROR: APK was not created." >&2; exit 1; }

if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$OUT"; elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$OUT"; fi
ls -lh "$OUT"
echo "Debug APK ready: $OUT"
