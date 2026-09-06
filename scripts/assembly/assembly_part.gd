class_name AssemblyPart
extends XRToolsPickable

signal assembly_placed(part: AssemblyPart)

enum GuideState { OFF, TARGET, READY, PLACED }
enum GuideAxis { X_POS, X_NEG, Y_POS, Y_NEG, Z_POS, Z_NEG }

@export var part_id: StringName = &""
@export var display_name: String = "قطعه"
@export var required_step: int = 0
@export var score_value: int = AssemblySettings.CORRECT_PLACEMENT_SCORE
@export var snap_duration_override: float = -1.0

@export var guide_axis: int = GuideAxis.X_POS
@export var guide_offset_m: float = 0.0
@export var guide_inner_radius_m: float = 0.018
@export var guide_outer_radius_m: float = 0.025

@export var name_label_height_m: float = 0.16

var is_placed: bool = false
var wrong_attempts: int = 0

var _guide_visual: MeshInstance3D = null
var _guide_state: int = GuideState.OFF
var _name_label: Label3D = null
var _name_visible: bool = false
var _name_tween: Tween = null
var _snap_clearance: bool = false
var _snap_in_progress: bool = false
var _initial_transform: Transform3D
var _last_safe_transform: Transform3D
var _last_move_pos: Vector3
var _move_sound_cooldown: float = 0.0
var _impact_sound_cooldown: float = 0.0

var _pickup_audio: AudioStreamPlayer3D
var _move_audio: AudioStreamPlayer3D
var _drop_audio: AudioStreamPlayer3D
var _snap_audio: AudioStreamPlayer3D

func _ready() -> void:
	super._ready()
	add_to_group("assembly_parts")
	process_physics_priority = 100
	collision_layer = AssemblySettings.LAYER_PARTS
	collision_mask = AssemblySettings.PART_NORMAL_MASK
	contact_monitor = true
	max_contacts_reported = 8
	second_hand_grab = XRToolsPickable.SecondHandGrab.IGNORE
	release_mode = XRToolsPickable.ReleaseMode.UNFROZEN
	_initial_transform = global_transform
	_last_safe_transform = global_transform
	_last_move_pos = global_position

	_setup_guide_visual()
	_setup_name_label()
	_setup_audio()
	set_guide_off()

	if not picked_up.is_connected(_on_picked_up):
		picked_up.connect(_on_picked_up)
	if not dropped.is_connected(_on_dropped):
		dropped.connect(_on_dropped)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_move_sound_cooldown = max(0.0, _move_sound_cooldown - delta)
	_impact_sound_cooldown = max(0.0, _impact_sound_cooldown - delta)
	_update_name_label()
	_update_move_sound()

func _physics_process(_delta: float) -> void:
	if not is_picked_up() or _snap_clearance or _snap_in_progress:
		_last_safe_transform = global_transform
		return

	var desired := global_transform
	var motion := desired.origin - _last_safe_transform.origin
	if motion.length_squared() < 0.0000001:
		return

	var params := PhysicsTestMotionParameters3D.new()
	params.from = _last_safe_transform
	params.motion = motion
	params.margin = 0.003
	params.max_collisions = 4
	var result := PhysicsTestMotionResult3D.new()

	if PhysicsServer3D.body_test_motion(get_rid(), params, result):
		var safe := desired
		safe.origin = _last_safe_transform.origin + result.get_travel()
		global_transform = safe
		_last_safe_transform = safe
	else:
		_last_safe_transform = desired

func can_pick_up(by: Node3D) -> bool:
	if is_placed:
		return false

	# فقط یک قطعه در کل تجربه می‌تواند همزمان در دست باشد.
	for node in get_tree().get_nodes_in_group("assembly_parts"):
		var other := node as AssemblyPart
		if other != null and other != self and other.is_picked_up():
			return false

	return super.can_pick_up(by)

func pick_up(by: Node3D) -> void:
	if not can_pick_up(by):
		return
	super.pick_up(by)
	collision_layer = AssemblySettings.LAYER_PARTS
	collision_mask = AssemblySettings.PART_HELD_MASK
	_last_safe_transform = global_transform

func let_go(by: Node3D, p_linear_velocity: Vector3, p_angular_velocity: Vector3) -> void:
	super.let_go(by, p_linear_velocity, p_angular_velocity)
	if not is_picked_up():
		collision_layer = AssemblySettings.LAYER_PARTS
		collision_mask = AssemblySettings.PART_NORMAL_MASK

func set_snap_clearance(enabled_clearance: bool) -> void:
	_snap_clearance = enabled_clearance
	if is_picked_up():
		collision_mask = 0 if enabled_clearance else AssemblySettings.PART_HELD_MASK

func snap_to(target: Transform3D) -> void:
	if is_placed:
		return

	_snap_in_progress = true
	set_snap_clearance(true)

	if is_picked_up():
		drop()
		await get_tree().process_frame

	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	enabled = false
	collision_mask = 0

	var duration := AssemblySettings.SNAP_DURATION_S
	if snap_duration_override >= 0.0:
		duration = snap_duration_override

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_transform", target, duration)
	await tween.finished

	global_transform = target
	_play_once(_snap_audio)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	is_placed = true
	_snap_in_progress = false
	_snap_clearance = false
	collision_layer = AssemblySettings.LAYER_PARTS
	collision_mask = AssemblySettings.PART_NORMAL_MASK
	set_guide_placed()
	_hide_name_immediate()
	assembly_placed.emit(self)

func reset_part() -> void:
	if is_picked_up():
		drop()
	is_placed = false
	wrong_attempts = 0
	_snap_clearance = false
	_snap_in_progress = false
	enabled = true
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	collision_layer = AssemblySettings.LAYER_PARTS
	collision_mask = AssemblySettings.PART_NORMAL_MASK
	global_transform = _initial_transform
	_last_safe_transform = global_transform
	set_guide_off()
	_hide_name_immediate()

func set_initial_transform_from_current() -> void:
	_initial_transform = global_transform
	_last_safe_transform = global_transform

func set_guide_off() -> void:
	_set_guide_state(GuideState.OFF)

func set_guide_target() -> void:
	if is_placed:
		set_guide_placed()
		return
	_set_guide_state(GuideState.TARGET)

func set_guide_ready() -> void:
	if is_placed:
		set_guide_placed()
		return
	_set_guide_state(GuideState.READY)

func set_guide_placed() -> void:
	_set_guide_state(GuideState.PLACED)

func _on_picked_up(_pickable: XRToolsPickable) -> void:
	_last_safe_transform = global_transform
	_last_move_pos = global_position
	_play_once(_pickup_audio)
	var manager := _manager()
	if manager:
		manager.notify_part_picked(self)

func _on_dropped(_pickable: XRToolsPickable) -> void:
	if _snap_in_progress:
		return
	var manager := _manager()
	if manager:
		manager.notify_part_dropped(self)

func _on_body_entered(_body: Node) -> void:
	if is_picked_up() or is_placed or _impact_sound_cooldown > 0.0:
		return
	if linear_velocity.length() >= 0.45:
		_impact_sound_cooldown = 0.16
		_play_once(_drop_audio)

func _manager() -> AssemblyManager:
	var nodes := get_tree().get_nodes_in_group("assembly_manager")
	if nodes.is_empty():
		return null
	return nodes[0] as AssemblyManager

func _setup_guide_visual() -> void:
	_guide_visual = MeshInstance3D.new()
	_guide_visual.name = "MatingEdgeGuide"
	var mesh := TorusMesh.new()
	mesh.inner_radius = guide_inner_radius_m
	mesh.outer_radius = guide_outer_radius_m
	mesh.rings = 16
	mesh.ring_segments = 24
	_guide_visual.mesh = mesh
	_guide_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_guide_visual.position = _guide_axis_vector() * guide_offset_m
	_guide_visual.rotation = _guide_axis_rotation()
	add_child(_guide_visual)
	_guide_visual.visible = false

func _setup_name_label() -> void:
	_name_label = Label3D.new()
	_name_label.name = "ProximityName"
	_name_label.text = display_name
	_name_label.position = Vector3(0.0, name_label_height_m, 0.0)
	_name_label.font_size = 28
	_name_label.pixel_size = 0.0017
	_name_label.outline_size = 6
	_name_label.modulate = Color(0.96, 0.98, 1.0, 0.0)
	_name_label.outline_modulate = Color(0.02, 0.03, 0.04, 0.0)
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.no_depth_test = true
	_name_label.scale = Vector3.ONE * 0.78
	add_child(_name_label)

func _update_name_label() -> void:
	if _name_label == null or is_placed:
		_set_name_visible(false)
		return

	var near := false
	for hand_name in ["left_hand", "right_hand"]:
		var hand := get_tree().root.find_child(hand_name, true, false)
		if hand and global_position.distance_to((hand as Node3D).global_position) <= AssemblySettings.PART_NAME_HAND_RADIUS_M:
			near = true
			break
	_set_name_visible(near)

func _set_name_visible(show: bool) -> void:
	if _name_label == null or _name_visible == show:
		return
	_name_visible = show
	if _name_tween and _name_tween.is_running():
		_name_tween.kill()
	_name_tween = create_tween()
	_name_tween.set_parallel(true)
	if show:
		_name_label.visible = true
		_name_tween.tween_property(_name_label, "modulate:a", 1.0, AssemblySettings.PART_NAME_FADE_S)
		_name_tween.tween_property(_name_label, "outline_modulate:a", 0.9, AssemblySettings.PART_NAME_FADE_S)
		_name_tween.tween_property(_name_label, "scale", Vector3.ONE, AssemblySettings.PART_NAME_FADE_S).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_name_tween.tween_property(_name_label, "modulate:a", 0.0, AssemblySettings.PART_NAME_FADE_S)
		_name_tween.tween_property(_name_label, "outline_modulate:a", 0.0, AssemblySettings.PART_NAME_FADE_S)
		_name_tween.tween_property(_name_label, "scale", Vector3.ONE * 0.82, AssemblySettings.PART_NAME_FADE_S)
		_name_tween.chain().tween_callback(func():
			if _name_label and not _name_visible:
				_name_label.visible = false
		)

func _hide_name_immediate() -> void:
	_name_visible = false
	if _name_tween and _name_tween.is_running():
		_name_tween.kill()
	if _name_label:
		_name_label.visible = false
		_name_label.modulate.a = 0.0
		_name_label.outline_modulate.a = 0.0

func _update_move_sound() -> void:
	var p := global_position
	if is_picked_up():
		var moved := p.distance_to(_last_move_pos)
		if moved > 0.012 and _move_sound_cooldown <= 0.0:
			_move_sound_cooldown = 0.24
			_play_once(_move_audio)
	_last_move_pos = p

func _setup_audio() -> void:
	_pickup_audio = _new_audio("PickupAudio", "res://assets/audio/pickup.wav", -7.0)
	_move_audio = _new_audio("MoveAudio", "res://assets/audio/move.wav", -13.0)
	_drop_audio = _new_audio("DropAudio", "res://assets/audio/drop.wav", -5.0)
	_snap_audio = _new_audio("SnapAudio", "res://assets/audio/snap.wav", -3.0)

func _new_audio(node_name: String, path: String, volume_db: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = node_name
	player.stream = load(path)
	player.volume_db = volume_db
	player.max_distance = 5.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(player)
	return player

func _play_once(player: AudioStreamPlayer3D) -> void:
	if player and player.stream:
		player.stop()
		player.play()

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
	if _guide_visual == null or _guide_state == state:
		return
	_guide_state = state
	match state:
		GuideState.OFF, GuideState.PLACED:
			_guide_visual.visible = false
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
	mat.emission_energy_multiplier = 1.35
	mat.roughness = 0.2
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	_guide_visual.material_override = mat
