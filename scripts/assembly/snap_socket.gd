class_name SnapSocket
extends Area3D

enum GuideState { OFF, TARGET, READY, PLACED }
enum GuideAxis { X_POS, X_NEG, Y_POS, Y_NEG, Z_POS, Z_NEG }

@export var socket_id: StringName = &""
@export var expected_part_id: StringName = &""
@export var required_step: int = 0
@export var manager_path: NodePath
@export var snap_point_path: NodePath = ^"SnapPoint"
@export var snap_radius_override_m: float = -1.0
@export var ready_radius_override_m: float = -1.0

## انیمیشن اتصال مکانیکی: قطعه اول در بیرون محل نصب Align می‌شود و سپس
## روی این محور به سمت SnapPoint حرکت می‌کند.
@export var approach_axis_local: Vector3 = Vector3.ZERO
@export var approach_distance_m: float = 0.0

@export var guide_axis: int = GuideAxis.X_POS
@export var guide_offset_m: float = 0.0
@export var guide_inner_radius_m: float = 0.020
@export var guide_outer_radius_m: float = 0.028

var _snapping: bool = false
var _guide_visual: MeshInstance3D = null
var _guide_state: int = GuideState.OFF
var _drop_fallback_connected: bool = false

@onready var manager: AssemblyManager = get_node_or_null(manager_path) as AssemblyManager
@onready var snap_point: Node3D = get_node(snap_point_path) as Node3D
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D

func _ready() -> void:
	_setup_guide_visual()
	_update_debug_area_radius()
	# همه قطعات بعد از ساخت Scene در گروه assembly_parts ثبت می‌شوند.
	# اتصال deferred باعث می‌شود fallback رها کردن قطعه در محدوده سبز هم همیشه آماده باشد.
	call_deferred("_connect_drop_fallback")

func _physics_process(_delta: float) -> void:
	if _snapping:
		return

	if manager == null or not manager.is_socket_active(expected_part_id):
		_set_guide_state(GuideState.OFF)
		return

	var part := _find_expected_part()
	if part == null or part.is_placed:
		_set_guide_state(GuideState.OFF)
		return

	if not _drop_fallback_connected:
		_connect_drop_fallback()

	var distance := part.global_position.distance_to(snap_point.global_position)
	if distance <= _ready_radius():
		# قانون UX: سبز شدن یعنی اتصال قطعی. کاربر نباید لازم باشد قطعه را رها کند.
		_set_guide_state(GuideState.READY)
		part.set_guide_ready()
		part.set_snap_clearance(true)

		if AssemblySettings.AUTO_SNAP_ENABLED:
			_attempt_auto_snap(part, distance)
		return

	_set_guide_state(GuideState.TARGET)
	part.set_guide_target()
	part.set_snap_clearance(false)

func _find_expected_part() -> AssemblyPart:
	for node in get_tree().get_nodes_in_group("assembly_parts"):
		var part := node as AssemblyPart
		if part and part.part_id == expected_part_id:
			return part
	return null

func _snap_radius() -> float:
	return snap_radius_override_m if snap_radius_override_m >= 0.0 else AssemblySettings.SNAP_RADIUS_M

func _ready_radius() -> float:
	return ready_radius_override_m if ready_radius_override_m >= 0.0 else AssemblySettings.READY_RADIUS_M

func _attempt_auto_snap(part: AssemblyPart, distance: float) -> void:
	if _snapping or part.is_placed or manager == null or not manager.can_place(part.part_id):
		return

	_snapping = true
	_set_guide_state(GuideState.READY)
	part.set_guide_ready()
	part.set_snap_clearance(true)

	if AssemblySettings.DEBUG_SNAP_LOGS:
		print("AUTO SNAP: ", part.part_id, " -> ", socket_id, " distance=", snappedf(distance, 0.001), " m")

	await part.snap_to(snap_point.global_transform, _approach_offset_global())
	_set_guide_state(GuideState.PLACED)
	manager.register_correct(part)
	_snapping = false

func _connect_drop_fallback() -> void:
	if _drop_fallback_connected:
		return
	var part := _find_expected_part()
	if part == null:
		return
	if not part.dropped.is_connected(_on_expected_part_dropped):
		part.dropped.connect(_on_expected_part_dropped)
	_drop_fallback_connected = true

func _on_expected_part_dropped(_pickable: XRToolsPickable) -> void:
	# Safety net: اگر به هر دلیل auto-snap همان فریم اجرا نشد، رها کردن قطعه
	# داخل محدوده سبز نباید باعث افتادن آن روی زمین شود.
	if _snapping or manager == null or not manager.is_socket_active(expected_part_id):
		return

	var part := _find_expected_part()
	if part == null or part.is_placed or not manager.can_place(part.part_id):
		return

	var distance := part.global_position.distance_to(snap_point.global_position)
	if distance <= _ready_radius():
		_attempt_auto_snap(part, distance)

func _approach_offset_global() -> Vector3:
	if approach_distance_m <= 0.0 or approach_axis_local.length_squared() < 0.000001:
		return Vector3.ZERO
	var axis_global := global_transform.basis * approach_axis_local.normalized()
	return axis_global * approach_distance_m

func _update_debug_area_radius() -> void:
	if collision_shape == null or collision_shape.shape == null:
		return
	if collision_shape.shape is SphereShape3D:
		var sphere := collision_shape.shape.duplicate() as SphereShape3D
		sphere.radius = _ready_radius()
		collision_shape.shape = sphere

func _setup_guide_visual() -> void:
	_guide_visual = MeshInstance3D.new()
	_guide_visual.name = "SocketMatingEdgeGuide"
	var mesh := TorusMesh.new()
	mesh.inner_radius = guide_inner_radius_m
	mesh.outer_radius = guide_outer_radius_m
	mesh.rings = 16
	mesh.ring_segments = 28
	_guide_visual.mesh = mesh
	_guide_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_guide_visual.position = _guide_axis_vector() * guide_offset_m
	_guide_visual.rotation = _guide_axis_rotation()
	snap_point.add_child(_guide_visual)
	_guide_visual.visible = false

func _guide_axis_vector() -> Vector3:
	match guide_axis:
		GuideAxis.X_POS: return Vector3.RIGHT
		GuideAxis.X_NEG: return Vector3.LEFT
		GuideAxis.Y_POS: return Vector3.UP
		GuideAxis.Y_NEG: return Vector3.DOWN
		GuideAxis.Z_POS: return Vector3.BACK
		GuideAxis.Z_NEG: return Vector3.FORWARD
		_: return Vector3.ZERO

func _guide_axis_rotation() -> Vector3:
	match guide_axis:
		GuideAxis.X_POS, GuideAxis.X_NEG:
			return Vector3(0.0, 0.0, deg_to_rad(90.0))
		GuideAxis.Z_POS, GuideAxis.Z_NEG:
			return Vector3(deg_to_rad(90.0), 0.0, 0.0)
		_:
			return Vector3.ZERO

func _set_guide_state(state: int) -> void:
	if _guide_visual == null:
		return
	# OFF/PLACED must always win, even if another frame just repainted the guide.
	if state == GuideState.OFF or state == GuideState.PLACED:
		_guide_state = state
		_guide_visual.visible = false
		return
	if _guide_state == state:
		return
	_guide_state = state
	match state:
		GuideState.TARGET:
			_guide_visual.visible = true
			_apply_guide_material(AssemblySettings.GUIDE_COLOR_TARGET)
		GuideState.READY:
			_guide_visual.visible = true
			_apply_guide_material(AssemblySettings.GUIDE_COLOR_READY)

func _apply_guide_material(color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.55
	mat.roughness = 0.18
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	_guide_visual.material_override = mat
