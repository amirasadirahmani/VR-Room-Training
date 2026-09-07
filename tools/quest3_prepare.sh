#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

find_godot() {
  if command -v godot >/dev/null 2>&1; then command -v godot; return; fi
  if command -v godot4 >/dev/null 2>&1; then command -v godot4; return; fi
  if [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then echo /Applications/Godot.app/Contents/MacOS/Godot; return; fi
  return 1
}

GODOT="${GODOT_BIN:-$(find_godot || true)}"
if [[ -z "$GODOT" ]]; then
  echo "ERROR: Godot not found. Set GODOT_BIN or install Godot 4.7.x." >&2
  exit 1
fi

echo "Godot: $GODOT"
"$GODOT" --version

if [[ ! -d "$ROOT/addons/godotopenxrvendors" ]]; then
  "$ROOT/tools/install_openxr_vendors_5_1.sh"
else
  echo "OpenXR Vendors already present."
fi

if [[ ! -d "$ROOT/android/build" ]]; then
  echo "Installing Gradle Android build template..."
  "$GODOT" --headless --path "$ROOT" --install-android-build-template --quit
else
  echo "Android Gradle build template already present."
fi

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
echo "Android SDK candidate: $SDK"
if [[ ! -d "$SDK" ]]; then
  echo "WARNING: Android SDK not found at $SDK. Configure Android SDK in Godot Editor Settings before export."
elif [[ ! -d "$SDK/platforms/android-34" ]]; then
  echo "WARNING: Android SDK Platform 34 is missing. Install Android 14 / API 34 with Android Studio SDK Manager."
else
  echo "Android SDK Platform 34: OK"
fi

if command -v java >/dev/null 2>&1; then
  java -version 2>&1 | head -n 1
else
  echo "WARNING: Java/JDK not found in PATH. Godot Android export expects a compatible JDK (JDK 17 recommended)."
fi

echo "Preparation complete. Next: ./tools/quest3_preflight.sh"
