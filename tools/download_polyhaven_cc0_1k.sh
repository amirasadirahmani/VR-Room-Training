#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/assets/textures/workshop"
mkdir -p "$OUT"

fetch() {
  local url="$1"
  local out="$2"
  echo "  -> $(basename "$out")"
  curl -L --fail --retry 3 --connect-timeout 15 "$url" -o "$out"
}

echo "Installing Poly Haven CC0 1K PBR maps..."

echo "Concrete Wall 004: Diffuse + Normal GL + ARM"
fetch "https://dl.polyhaven.org/file/ph-assets/Textures/png/1k/concrete_wall_004/concrete_wall_004_diff_1k.png" "$OUT/concrete_wall_albedo.png"
fetch "https://dl.polyhaven.org/file/ph-assets/Textures/png/1k/concrete_wall_004/concrete_wall_004_nor_gl_1k.png" "$OUT/concrete_wall_normal.png"
fetch "https://dl.polyhaven.org/file/ph-assets/Textures/png/1k/concrete_wall_004/concrete_wall_004_arm_1k.png" "$OUT/concrete_wall_arm.png"

echo "Concrete Floor: Diffuse + Normal GL + ARM"
fetch "https://dl.polyhaven.org/file/ph-assets/Textures/png/1k/concrete_floor/concrete_floor_diff_1k.png" "$OUT/concrete_floor_albedo.png"
fetch "https://dl.polyhaven.org/file/ph-assets/Textures/png/1k/concrete_floor/concrete_floor_nor_gl_1k.png" "$OUT/concrete_floor_normal.png"
fetch "https://dl.polyhaven.org/file/ph-assets/Textures/png/1k/concrete_floor/concrete_floor_arm_1k.png" "$OUT/concrete_floor_arm.png"

echo "Green Metal Rust: Diffuse + Normal GL + ARM"
fetch "https://dl.polyhaven.org/file/ph-assets/Textures/png/1k/green_metal_rust/green_metal_rust_diff_1k.png" "$OUT/painted_steel_albedo.png"
fetch "https://dl.polyhaven.org/file/ph-assets/Textures/png/1k/green_metal_rust/green_metal_rust_nor_gl_1k.png" "$OUT/painted_steel_normal.png"
fetch "https://dl.polyhaven.org/file/ph-assets/Textures/png/1k/green_metal_rust/green_metal_rust_arm_1k.png" "$OUT/painted_steel_arm.png"

echo
echo "PBR maps installed. Godot will re-import them automatically."
echo "If the editor is already open, wait a few seconds before pressing Run."
