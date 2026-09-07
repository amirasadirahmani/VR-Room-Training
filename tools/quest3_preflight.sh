#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

ok(){ printf 'OK    %s\n' "$1"; }
warn(){ printf 'WARN  %s\n' "$1"; }
fail(){ printf 'FAIL  %s\n' "$1"; FAIL=1; }
require_grep(){ local p="$1" f="$2" label="$3"; grep -Fq "$p" "$f" && ok "$label" || fail "$label"; }

[[ -f "$ROOT/project.godot" ]] && ok "project.godot" || fail "project.godot missing"
[[ -f "$ROOT/export_presets.cfg" ]] && ok "export_presets.cfg" || fail "export_presets.cfg missing"
[[ -d "$ROOT/addons/godotopenxrvendors" ]] && ok "OpenXR Vendors installed" || fail "OpenXR Vendors missing — run ./tools/install_openxr_vendors_5_1.sh"
[[ -d "$ROOT/android/build" ]] && ok "Gradle Android template installed" || fail "android/build missing — run ./tools/quest3_prepare.sh"

require_grep 'run/main_scene="res://main.tscn"' "$ROOT/project.godot" "Path-based main scene for clean fresh-clone export"
require_grep 'renderer/rendering_method="mobile"' "$ROOT/project.godot" "Mobile renderer retained"
require_grep 'openxr/enabled=true' "$ROOT/project.godot" "OpenXR enabled"
require_grep 'export_filter="resources"' "$ROOT/export_presets.cfg" "Production-only resource export enabled"
require_grep 'res://main.tscn' "$ROOT/export_presets.cfg" "Main scene selected for export"
require_grep 'res://openxr_action_map.tres' "$ROOT/export_presets.cfg" "OpenXR action map selected for export"
require_grep 'res://scenes/environment/workshop_polish.tscn' "$ROOT/export_presets.cfg" "Dynamic workshop polish selected for export"
require_grep 'res://scenes/ui/scenario_panel.tscn' "$ROOT/export_presets.cfg" "Dynamic scenario panel selected for export"
require_grep 'res://scenes/grinder/parts/part_handle.tscn' "$ROOT/export_presets.cfg" "Dynamic handle selected for export"
require_grep 'res://scenes/grinder/parts/part_motor_unit.tscn' "$ROOT/export_presets.cfg" "Dynamic motor unit selected for export"
require_grep 'res://scenes/grinder/parts/part_sausage_attachment.tscn' "$ROOT/export_presets.cfg" "Dynamic sausage attachment selected for export"
require_grep 'res://assets/audio/score.wav' "$ROOT/export_presets.cfg" "Dynamic manager audio selected for export"
require_grep 'res://assets/audio/pickup.wav' "$ROOT/export_presets.cfg" "Dynamic part audio selected for export"
require_grep 'res://assets/audio/menu_click.wav' "$ROOT/export_presets.cfg" "Dynamic menu audio selected for export"
require_grep 'gradle_build/use_gradle_build=true' "$ROOT/export_presets.cfg" "Gradle export enabled"
require_grep 'gradle_build/min_sdk="32"' "$ROOT/export_presets.cfg" "minSdk 32"
require_grep 'gradle_build/target_sdk="34"' "$ROOT/export_presets.cfg" "targetSdk 34"
require_grep 'architectures/arm64-v8a=true' "$ROOT/export_presets.cfg" "ARM64 enabled"
require_grep 'architectures/armeabi-v7a=false' "$ROOT/export_presets.cfg" "ARMv7 disabled"
require_grep 'xr_features/xr_mode=1' "$ROOT/export_presets.cfg" "OpenXR Android mode"
require_grep 'xr_features/enable_meta_plugin=true' "$ROOT/export_presets.cfg" "Meta OpenXR vendor plugin enabled"
require_grep 'meta_xr_features/quest_3_support=true' "$ROOT/export_presets.cfg" "Quest 3 / Quest 3S support enabled"
require_grep 'meta_xr_features/quest_2_support=false' "$ROOT/export_presets.cfg" "Quest 2 excluded from target manifest"

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
[[ -d "$SDK" ]] && ok "Android SDK: $SDK" || fail "Android SDK not found: $SDK"
[[ -d "$SDK/platforms/android-34" ]] && ok "Android API 34 installed" || fail "Android API 34 missing"

if command -v java >/dev/null 2>&1; then
  JAVA_LINE="$(java -version 2>&1 | head -n 1)"
  ok "Java present: $JAVA_LINE"
else
  fail "Java/JDK missing"
fi

if grep -R --line-number --include='*.gd' --include='*.tscn' --include='*.tres' --include='*.godot' 'assets/textures/workshop' "$ROOT" >/dev/null 2>&1; then
  ok "Workshop Poly Haven references retained"
else
  warn "No workshop texture reference found by text scan (verify materials in editor)"
fi

# Regression guards for fixes validated in Phases 8–9.
require_grep 'SAUSAGE_SEQUENCE' "$ROOT/scripts/assembly/assembly_manager.gd" "Sausage scenario present"
require_grep '&"lock_ring", &"sausage_attachment"' "$ROOT/scripts/assembly/assembly_manager.gd" "Sausage order: Lock Ring before attachment"
require_grep '_drop_by_step' "$ROOT/scripts/assembly/assembly_manager.gd" "VR-fair drop dedup present"
require_grep '50%' "$ROOT/PHASE_9_ASSESSMENT_FA.md" "VR-fair 50/50 assessment documented"

if (( FAIL )); then
  echo "Preflight FAILED. Fix FAIL items before APK export." >&2
  exit 1
fi

echo "Preflight PASSED. Ready for Quest 3 APK export."
