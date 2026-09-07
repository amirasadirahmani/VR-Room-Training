class_name VRMenuButton3D
extends Area3D

## Robust 3D menu button for Meta XR Simulator / Quest.
## The whole CollisionShape3D is interactable (not only the button center).
## Move a hand over the button, then make a fresh Grip/U press.

@export_enum(
	"training",
	"free_practice",
	"reset",
	"restart",
	"main_menu",
	"difficulty_easy",
	"difficulty_normal",
	"difficulty_hard",
	"scenario_manual",
	"scenario_electric",
	"scenario_sausage",
	"timed_challenge"
) var action: String = "training"

@export var manager_path: NodePath
@export var cooldown_s: float = 0.40
@export var hover_radius_m: float = 0.22 # fallback for buttons without a BoxShape3D
@export var hover_padding_m: float = 0.055
@export var hover_depth_m: float = 0.18
@export var grip_threshold: float = 0.55
@export var grip_action: StringName = &"grip"
@export var grip_click_action: StringName = &"grip_click"

var _cooldown: float = 0.0
var _hovered: bool = false
var _grip_previous: Dictionary = {}
var _visual_tween: Tween = null
var _base_mesh_scale: Vector3 = Vector3.ONE
var _base_label_scale: Vector3 = Vector3.ONE
var _base_label_text: String = ""
var _base_label_color: Color = Color.WHITE
var _click_audio: AudioStreamPlayer = null
var _hover_audio: AudioStreamPlayer = null

@onready var manager: AssemblyManager = get_node_or_null(manager_path) as AssemblyManager
@onready var mesh: MeshInstance3D = get_node_or_null("Mesh") as MeshInstance3D
@onready var label: Label3D = get_node_or_null("Label") as Label3D
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D

func _ready() -> void:
	add_to_group("vr_menu_button")
	_resolve_manager()

	if mesh != null:
		_base_mesh_scale = mesh.scale
	if label != null:
		_base_label_scale = label.scale
		_base_label_text = label.text
		_base_label_color = label.modulate

	# UI sounds are non-positional so they remain clearly audible in the simulator
	# and on Quest regardless of panel position/orientation.
	_click_audio = AudioStreamPlayer.new()
	_click_audio.name = "MenuClick"
	_click_audio.stream = load("res://assets/audio/menu_click.wav") as AudioStream
	_click_audio.volume_db = -3.0
	add_child(_click_audio)

	_hover_audio = AudioStreamPlayer.new()
	_hover_audio.name = "MenuHover"
	_hover_audio.stream = load("res://assets/audio/menu_click.wav") as AudioStream
	_hover_audio.volume_db = -14.0
	_hover_audio.pitch_scale = 1.30
	add_child(_hover_audio)

func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)

	var hover_hand: Node3D = _get_hover_hand()
	_set_hovered(hover_hand != null)
	var hover_controller: XRController3D = _controller_for_hand(hover_hand)

	for controller: XRController3D in _controllers():
		var key: int = controller.get_instance_id()
		var down: bool = _controller_grip_down(controller)
		var previous: bool = bool(_grip_previous.get(key, false))

		if hover_controller == controller and down and not previous and _cooldown <= 0.0:
			_activate()

		_grip_previous[key] = down

	_update_selected_visual()

func _resolve_manager() -> void:
	if manager != null and is_instance_valid(manager):
		return
	if not manager_path.is_empty():
		manager = get_node_or_null(manager_path) as AssemblyManager
	if manager != null:
		return
	# Dynamic Phase 8 panels are instantiated at runtime. Group lookup makes the
	# action wiring independent of the panel's exact scene-tree depth.
	var managers: Array[Node] = get_tree().get_nodes_in_group("assembly_manager")
	if not managers.is_empty():
		manager = managers[0] as AssemblyManager

func _controllers() -> Array[XRController3D]:
	var result: Array[XRController3D] = []
	for controller_name: String in ["left_hand", "right_hand"]:
		var node: Node = get_tree().root.find_child(controller_name, true, false)
		if node is XRController3D:
			result.append(node as XRController3D)
	return result

func _controller_grip_down(controller: XRController3D) -> bool:
	return (
		controller.get_float(grip_action) >= grip_threshold
		or controller.is_button_pressed(grip_click_action)
	)

func _controller_for_hand(hand: Node3D) -> XRController3D:
	if hand == null:
		return null
	var current: Node = hand
	while current != null:
		if current is XRController3D:
			return current as XRController3D
		current = current.get_parent()
	return null

func _get_hover_hand() -> Node3D:
	# Exactly ONE visible menu button may own hover at a time, even when both
	# XR hands are near different/adjacent buttons. This prevents two rows from
	# scaling/highlighting together when their interaction volumes overlap.
	var winning_button: VRMenuButton3D = null
	var winning_hand: Node3D = null
	var winning_distance_sq: float = INF
	var winning_button_id: int = 0

	for button_node: Node in get_tree().get_nodes_in_group("vr_menu_button"):
		var button: VRMenuButton3D = button_node as VRMenuButton3D
		if button == null or not button.is_visible_in_tree():
			continue

		for hand: Node3D in _interaction_hands():
			if not button._hand_is_in_interaction_zone(hand):
				continue

			var distance_sq: float = button.global_position.distance_squared_to(hand.global_position)
			var button_id: int = button.get_instance_id()
			var is_better: bool = distance_sq < winning_distance_sq - 0.000001
			var is_tie: bool = absf(distance_sq - winning_distance_sq) <= 0.000001
			if is_better or (is_tie and (winning_button == null or button_id < winning_button_id)):
				winning_distance_sq = distance_sq
				winning_button = button
				winning_hand = hand
				winning_button_id = button_id

	return winning_hand if winning_button == self else null

func _interaction_hands() -> Array[Node3D]:
	var result: Array[Node3D] = []
	var seen: Dictionary = {}

	for node: Node in get_tree().get_nodes_in_group("vr_hand"):
		if node is Node3D:
			var hand: Node3D = node as Node3D
			var hand_id: int = hand.get_instance_id()
			if not seen.has(hand_id):
				seen[hand_id] = true
				result.append(hand)

	# Fallback/controllers are also included so Simulator setups without a
	# vr_hand group still participate in the same global arbitration.
	for controller: XRController3D in _controllers():
		var controller_id: int = controller.get_instance_id()
		if not seen.has(controller_id):
			seen[controller_id] = true
			result.append(controller)

	return result

func _hand_is_in_interaction_zone(hand: Node3D) -> bool:
	if hand == null:
		return false

	if collision_shape != null and collision_shape.shape is BoxShape3D:
		var box: BoxShape3D = collision_shape.shape as BoxShape3D
		var local_hand: Vector3 = collision_shape.global_transform.affine_inverse() * hand.global_position
		var half_size: Vector3 = box.size * 0.5
		return (
			absf(local_hand.x) <= half_size.x + hover_padding_m
			and absf(local_hand.y) <= half_size.y + hover_padding_m
			and absf(local_hand.z) <= half_size.z + hover_depth_m
		)

	return global_position.distance_to(hand.global_position) <= hover_radius_m

func _activate() -> void:
	_resolve_manager()
	if manager == null:
		push_warning("VRMenuButton3D: AssemblyManager not found for %s action=%s" % [name, action])
		return

	_cooldown = cooldown_s
	_pulse()
	_play_click()
	manager.menu_haptic()

	match action:
		"training":
			manager.start_training()
		"free_practice":
			manager.start_free_practice()
		"reset":
			manager.reset_assembly()
		"restart":
			manager.restart_current_mode()
		"main_menu":
			manager.show_main_menu()
		"difficulty_easy":
			manager.set_difficulty_easy()
		"difficulty_normal":
			manager.set_difficulty_normal()
		"difficulty_hard":
			manager.set_difficulty_hard()
		"scenario_manual":
			manager.select_scenario_manual()
		"scenario_electric":
			manager.select_scenario_electric()
		"scenario_sausage":
			manager.select_scenario_sausage()
		"timed_challenge":
			manager.start_timed_challenge()
		_:
			push_warning("VRMenuButton3D: unknown action %s" % action)

func _play_click() -> void:
	if _click_audio != null and _click_audio.stream != null:
		_click_audio.stop()
		_click_audio.play()

func _play_hover() -> void:
	if _hover_audio != null and _hover_audio.stream != null:
		_hover_audio.stop()
		_hover_audio.play()

func _set_hovered(value: bool) -> void:
	if _hovered == value:
		return
	_hovered = value

	if _visual_tween != null and _visual_tween.is_running():
		_visual_tween.kill()
	_visual_tween = create_tween().set_parallel(true)

	if value:
		_play_hover()

	if mesh != null:
		var target_mesh_scale: Vector3 = _base_mesh_scale * (1.10 if value else 1.0)
		_visual_tween.tween_property(mesh, "scale", target_mesh_scale, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if label != null:
		label.text = ("[U]  " + _base_label_text) if value else _base_label_text
		var target_label_scale: Vector3 = _base_label_scale * (1.10 if value else 1.0)
		_visual_tween.tween_property(label, "scale", target_label_scale, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _update_selected_visual() -> void:
	if label == null:
		return
	_resolve_manager()
	if manager == null or _hovered:
		return
	if manager.is_menu_action_selected(action):
		label.modulate = Color(0.55, 1.0, 0.72, 1.0)
	else:
		label.modulate = _base_label_color

func _pulse() -> void:
	if mesh == null:
		return
	if _visual_tween != null and _visual_tween.is_running():
		_visual_tween.kill()
	_visual_tween = create_tween()
	_visual_tween.tween_property(mesh, "scale", _base_mesh_scale * 0.92, 0.055)
	_visual_tween.tween_property(mesh, "scale", _base_mesh_scale * 1.10, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
