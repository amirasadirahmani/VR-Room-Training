class_name VRMenuButton3D
extends Area3D

@export_enum("training", "free_practice", "reset") var action: String = "training"
@export var manager_path: NodePath
@export var cooldown_s: float = 0.8

var _cooldown: float = 0.0

@onready var manager: AssemblyManager = get_node_or_null(manager_path) as AssemblyManager
@onready var mesh: MeshInstance3D = get_node_or_null("Mesh") as MeshInstance3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_cooldown = max(0.0, _cooldown - delta)

func _on_body_entered(body: Node3D) -> void:
	if _cooldown > 0.0 or manager == null or not body.is_in_group("vr_hand"):
		return
	_cooldown = cooldown_s
	_pulse()
	match action:
		"training": manager.start_training()
		"free_practice": manager.start_free_practice()
		"reset": manager.reset_assembly()

func _pulse() -> void:
	if mesh == null:
		return
	var original := mesh.scale
	var tween := create_tween()
	tween.tween_property(mesh, "scale", original * 0.94, 0.06)
	tween.tween_property(mesh, "scale", original, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
