class_name RoomBoundary
extends XROrigin3D

## Keeps the simulated HMD inside the workshop even though Meta XR Simulator
## moves the tracked headset directly (which normal StaticBody collision cannot stop).
## Bounds are in world meters and already include a safety margin from the walls.

@export var camera_path: NodePath = ^"XRCamera3D"
@export var min_x: float = -2.95
@export var max_x: float = 2.95
@export var min_z: float = -3.02
@export var max_z: float = 2.10
@export var clamp_rear_boundary: bool = true
@export var debug_boundary: bool = false

@onready var xr_camera: XRCamera3D = get_node(camera_path) as XRCamera3D

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
