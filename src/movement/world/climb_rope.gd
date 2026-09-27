@tool
class_name ClimbRope
extends Node3D
## Vertical climbable rope hanging from this node's origin down -Y (design §7.12, spec: movement.md §17).

@export var length: float = 10.0


func _ready() -> void:
	add_to_group(&"climb_rope")


func to_rail(id: int) -> RopeRail:
	var top := global_position
	return RopeRail.new(id, top, top + Vector3.DOWN * length)
