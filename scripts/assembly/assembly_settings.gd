class_name AssemblySettings
extends RefCounted

## ============================================================
## VR MEAT GRINDER - GLOBAL TRAINING / PHYSICS TUNING
## فاصله‌ها بر حسب متر هستند. 0.10 = 10 cm
## ============================================================

enum Difficulty { EASY, NORMAL, HARD }

const AUTO_SNAP_ENABLED: bool = true

## These two are runtime values because the Phase 6 menu can change difficulty.
static var READY_RADIUS_M: float = 0.16
static var SNAP_RADIUS_M: float = 0.10
static var CURRENT_DIFFICULTY: int = Difficulty.NORMAL

const SNAP_DURATION_S: float = 0.18
const SNAP_ALIGN_DURATION_S: float = 0.14
const SNAP_INSERT_DURATION_S: float = 0.24
const REQUIRE_CORRECT_ORDER: bool = true

## Training scoring
const CORRECT_PLACEMENT_SCORE: int = 10
const FIRST_TRY_BONUS: int = 5
const COMPLETION_BONUS: int = 25
const WRONG_PART_PENALTY: int = 2
const MISPLACED_DROP_PENALTY: int = 1
const MAX_TRAINING_SCORE: int = 115

## Name label near the user's hand
const PART_NAME_HAND_RADIUS_M: float = 0.34
const PART_NAME_FADE_S: float = 0.18

## Collision layers
const LAYER_WORLD: int = 1
const LAYER_PLAYER_BODY: int = 2
const LAYER_PARTS: int = 4
const LAYER_HANDS: int = 8
const LAYER_UI_TOUCH: int = 16

const PART_NORMAL_MASK: int = LAYER_WORLD | LAYER_PLAYER_BODY | LAYER_PARTS | LAYER_HANDS
const PART_HELD_MASK: int = LAYER_WORLD | LAYER_PLAYER_BODY | LAYER_PARTS

## Only legal mating geometry gets temporary collision exceptions.
const USE_SELECTIVE_MATING_CLEARANCE: bool = true

const GUIDE_COLOR_TARGET: Color = Color(0.95, 0.18, 0.18, 0.98)
const GUIDE_COLOR_READY: Color = Color(0.15, 0.95, 0.34, 0.98)
const GUIDE_COLOR_INACTIVE: Color = Color(0.5, 0.55, 0.6, 0.15)

const DEBUG_SNAP_LOGS: bool = true

static func apply_difficulty(level: int) -> void:
	CURRENT_DIFFICULTY = level
	match level:
		Difficulty.EASY:
			READY_RADIUS_M = 0.22
			SNAP_RADIUS_M = 0.15
		Difficulty.NORMAL:
			READY_RADIUS_M = 0.16
			SNAP_RADIUS_M = 0.10
		Difficulty.HARD:
			READY_RADIUS_M = 0.10
			SNAP_RADIUS_M = 0.06

static func difficulty_name_fa() -> String:
	match CURRENT_DIFFICULTY:
		Difficulty.EASY:
			return "آسان"
		Difficulty.HARD:
			return "سخت"
		_:
			return "معمولی"
