class_name RopeRail
extends RefCounted
## Vertical rope segment used by the sim (design §7.12). s = distance down from `top`.

var id: int = -1
var top: Vector3 = Vector3.ZERO
var bottom: Vector3 = Vector3.ZERO


func _init(p_id: int = -1, p_top: Vector3 = Vector3.ZERO, p_bottom: Vector3 = Vector3.ZERO) -> void:
	id = p_id
	top = p_top
	bottom = p_bottom


func length() -> float:
	return top.distance_to(bottom)


func sample(s: float) -> Vector3:
	var l := length()
	if l <= 1e-9:
		return top
	return top.lerp(bottom, clampf(s / l, 0.0, 1.0))


## Returns { s, point, distance }.
func closest(pos: Vector3) -> Dictionary:
	var ab := bottom - top
	var l2 := ab.length_squared()
	var t := 0.0 if l2 <= 1e-12 else clampf((pos - top).dot(ab) / l2, 0.0, 1.0)
	var q := top + ab * t
	return {"s": sqrt(l2) * t, "point": q, "distance": pos.distance_to(q)}
