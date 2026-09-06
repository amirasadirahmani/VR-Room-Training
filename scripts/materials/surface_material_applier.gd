class_name SurfaceMaterialApplier
extends Node3D

@export var surface_material: Material

func _ready() -> void:
	if surface_material == null:
		return
	_apply_recursive(self)

func _apply_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = surface_material
	for child in node.get_children():
		_apply_recursive(child)
