class_name RoomBoundary
extends XROrigin3D

@export var camera_path: NodePath = ^"XRCamera3D"
@export var min_x: float = -2.95
@export var max_x: float = 2.95
@export var min_z: float = -3.02
@export var max_z: float = 2.10
@export var clamp_rear_boundary: bool = true
@export var debug_boundary: bool = false

@onready var xr_camera: XRCamera3D = get_node(camera_path) as XRCamera3D

func _ready() -> void:
	# Phase 7 bootstrap. If main.tscn already contains the polish scene this is a no-op.
	call_deferred("_ensure_visual_polish")

func _ensure_visual_polish() -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var environment_root := scene_root.get_node_or_null("EnvironmentRoot") as Node3D
	if environment_root == null:
		return
	if environment_root.get_node_or_null("WorkshopPolish") == null:
		var packed := load("res://scenes/environment/workshop_polish.tscn") as PackedScene
		if packed:
			var polish := packed.instantiate()
			polish.name = "WorkshopPolish"
			environment_root.add_child(polish)
	var directional := environment_root.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if directional:
		directional.light_color = Color(0.82, 0.89, 1.0, 1.0)
		directional.light_energy = 0.64
	var key := environment_root.get_node_or_null("KeyLight") as OmniLight3D
	if key:
		key.light_color = Color(1.0, 0.90, 0.78, 1.0)
		key.light_energy = 1.52
	var fill := environment_root.get_node_or_null("FillLight") as OmniLight3D
	if fill:
		fill.light_color = Color(0.68, 0.82, 1.0, 1.0)
		fill.light_energy = 0.76
	var board := environment_root.get_node_or_null("BoardLight") as SpotLight3D
	if board:
		board.light_color = Color(0.86, 0.93, 1.0, 1.0)
		board.light_energy = 1.16
	var world_env := scene_root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env and world_env.environment:
		world_env.environment.ambient_light_energy = 0.42

func _process(_delta: float) -> void:
	if xr_camera == null:
		return
	var camera_position := xr_camera.global_position
	var corrected := camera_position
	corrected.x = clampf(camera_position.x, min_x, max_x)
	corrected.z = maxf(camera_position.z, min_z)
	if clamp_rear_boundary:
		corrected.z = minf(corrected.z, max_z)
	var correction := corrected - camera_position
	correction.y = 0.0
	if correction.length_squared() > 0.0000001:
		global_position += correction
		if debug_boundary:
			print("ROOM BOUNDARY correction: ", correction)
