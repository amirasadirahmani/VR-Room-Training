#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="5.1.0-stable"
URL="https://github.com/GodotVR/godot_openxr_vendors/releases/download/${VERSION}/godotopenxrvendorsaddon.zip"
TARGET="$ROOT/addons/godotopenxrvendors"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

printf 'Installing Godot OpenXR Vendors %s...\n' "$VERSION"
curl -fL --retry 3 --retry-delay 2 "$URL" -o "$TMP/vendors.zip"
unzip -q "$TMP/vendors.zip" -d "$TMP/unpacked"
SOURCE="$(find "$TMP/unpacked" -type d -path '*/addons/godotopenxrvendors' -print -quit)"
if [[ -z "$SOURCE" ]]; then
  echo "ERROR: addons/godotopenxrvendors was not found in release archive." >&2
  exit 1
fi
rm -rf "$TARGET"
mkdir -p "$ROOT/addons"
cp -R "$SOURCE" "$TARGET"

# OpenXR Vendors 5.1 ships its GDExtension entry point as plugin.gdextension.
# Keep the older names as fallbacks so this installer remains tolerant of
# packaging changes between vendor releases.
if [[ ! -f "$TARGET/plugin.gdextension" && ! -f "$TARGET/plugin.cfg" && ! -f "$TARGET/godotopenxrvendors.gdextension" ]]; then
  echo "ERROR: OpenXR Vendors install looks incomplete." >&2
  exit 1
fi

echo "OpenXR Vendors $VERSION installed at: $TARGET"
echo "This directory is intentionally ignored by Git and can be recreated with this script."
