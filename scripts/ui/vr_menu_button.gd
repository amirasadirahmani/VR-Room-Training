class_name VRMenuButton3D
extends Area3D

## 3D workshop menu button.
## In Meta XR Simulator, U drives the OpenXR `grip` action.
## The button is selected by hand proximity, then activated on a fresh Grip press.

@export_enum("training", "free_practice", "reset") var action: String = "training"
@export var manager_path: NodePath
@export var cooldown_s: float = 0.65
@export var hover_radius_m: float = 0.22
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

@onready var manager: AssemblyManager = get_node_or_null(manager_path) as AssemblyManager
@onready var mesh: MeshInstance3D = get_node_or_null("Mesh") as MeshInstance3D
@onready var label: Label3D = get_node_or_null("Label") as Label3D

func _ready() -> void:
	add_to_group("vr_menu_button")
	if mesh:
		_base_mesh_scale = mesh.scale
	if label:
		_base_label_scale = label.scale
		_base_label_text = label.text
		_base_label_color = label.modulate

func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)

	var hover_hand := _get_hover_hand()
	_set_hovered(hover_hand != null)

	# Track Grip state continuously so a new press is required while hovering.
	for controller in _controllers():
		var key := controller.get_instance_id()
		var down := _controller_grip_down(controller)
		var previous := bool(_grip_previous.get(key, false))

		if hover_hand != null and hover_hand.get_parent() == controller:
			if down and not previous and _cooldown <= 0.0:
				_activate()

		_grip_previous[key] = down

func _controllers() -> Array[XRController3D]:
	var result: Array[XRController3D] = []
	for controller_name in ["left_hand", "right_hand"]:
		var node := get_tree().root.find_child(controller_name, true, false)
		if node is XRController3D:
			result.append(node as XRController3D)
	return result

func _controller_grip_down(controller: XRController3D) -> bool:
	return (
		controller.get_float(grip_action) >= grip_threshold
		or controller.is_button_pressed(grip_click_action)
	)

func _get_hover_hand() -> Node3D:
	var best_hand: Node3D = null
	var best_distance := INF

	for node in get_tree().get_nodes_in_group("vr_hand"):
		var hand := node as Node3D
		if hand == null:
			continue

		var distance := global_position.distance_to(hand.global_position)
		if distance > hover_radius_m:
			continue

		# Only the nearest menu button to this hand is allowed to react.
		var nearest_button: VRMenuButton3D = null
		var nearest_button_distance := INF
		for button_node in get_tree().get_nodes_in_group("vr_menu_button"):
			var button := button_node as VRMenuButton3D
			if button == null:
				continue
			var button_distance := button.global_position.distance_to(hand.global_position)
			if button_distance < nearest_button_distance:
				nearest_button_distance = button_distance
				nearest_button = button

		if nearest_button != self:
			continue

		if distance < best_distance:
			best_distance = distance
			best_hand = hand

	return best_hand

func _activate() -> void:
	if manager == null:
		push_warning("VRMenuButton3D: AssemblyManager not found for %s" % name)
		return

	_cooldown = cooldown_s
	_pulse()

	match action:
		"training":
			manager.start_training()
		"free_practice":
			manager.start_free_practice()
		"reset":
			manager.reset_assembly()

func _set_hovered(value: bool) -> void:
	if _hovered == value:
		return
	_hovered = value

	if _visual_tween and _visual_tween.is_running():
		_visual_tween.kill()
	_visual_tween = create_tween().set_parallel(true)

	if mesh:
		var target_mesh_scale := _base_mesh_scale * (1.08 if value else 1.0)
		_visual_tween.tween_property(mesh, "scale", target_mesh_scale, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if label:
		label.text = ("[U]  " + _base_label_text) if value else _base_label_text
		var target_label_scale := _base_label_scale * (1.08 if value else 1.0)
		_visual_tween.tween_property(label, "scale", target_label_scale, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_visual_tween.tween_property(
			label,
			"modulate",
			Color(1.0, 0.92, 0.48, 1.0) if value else _base_label_color,
			0.12
		)

func _pulse() -> void:
	if mesh == null:
		return
	if _visual_tween and _visual_tween.is_running():
		_visual_tween.kill()
	_visual_tween = create_tween()
	_visual_tween.tween_property(mesh, "scale", _base_mesh_scale * 0.94, 0.055)
	_visual_tween.tween_property(mesh, "scale", _base_mesh_scale * 1.08, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
