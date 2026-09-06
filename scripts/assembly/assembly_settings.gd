class_name AssemblySettings
extends RefCounted

## ============================================================
## VR MEAT GRINDER - GLOBAL TRAINING / PHYSICS TUNING
## فاصله‌ها بر حسب متر هستند. 0.10 = 10 cm
## ============================================================

const AUTO_SNAP_ENABLED: bool = true
const READY_RADIUS_M: float = 0.11
const SNAP_RADIUS_M: float = 0.11
const SNAP_DURATION_S: float = 0.18
## دو مرحله انیمیشن اتصال: ابتدا Align بیرون محل اتصال، سپس Insert واقعی.
const SNAP_ALIGN_DURATION_S: float = 0.14
const SNAP_INSERT_DURATION_S: float = 0.24
const REQUIRE_CORRECT_ORDER: bool = true

const CORRECT_PLACEMENT_SCORE: int = 10
const WRONG_PART_PENALTY: int = 2
const MISPLACED_DROP_PENALTY: int = 1

## فاصله دست تا قطعه برای ظاهر شدن نام قطعه
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

## در محدوده اتصال مجاز، Collision به طور کلی خاموش نمی‌شود.
## فقط با بدنه چرخ گوشت و قطعاتی که قبلاً نصب شده‌اند exception موقت داده می‌شود.
const USE_SELECTIVE_MATING_CLEARANCE: bool = true

const GUIDE_COLOR_TARGET: Color = Color(0.95, 0.18, 0.18, 0.98)
const GUIDE_COLOR_READY: Color = Color(0.15, 0.95, 0.34, 0.98)
const GUIDE_COLOR_INACTIVE: Color = Color(0.5, 0.55, 0.6, 0.15)

const DEBUG_SNAP_LOGS: bool = true
