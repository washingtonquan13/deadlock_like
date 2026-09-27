class_name ZiplineRail
extends RefCounted
## Baked world-space polyline used by the sim (design §7.12). Pure data, no scene access.

var id: int = -1
var points: PackedVector3Array = PackedVector3Array()   # world space, ~0.25 m spacing
var speed: float = 18.0                                 # m/s, CUSTOM lane speed (spec: movement.md §16)
var lane: int = 0                                       # Zipline.Lane: 0 CUSTOM, 1 INNER, 2 OUTER
var express: bool = false                               # spec: movement.md §16 express line
var _cum: PackedFloat64Array = PackedFloat64Array()     # cumulative arc length per point


func _init(p_id: int = -1, p_points: PackedVector3Array = PackedVector3Array(), p_speed: float = 18.0, p_lane: int = 0, p_express: bool = false) -> void:
	id = p_id
	speed = p_speed
	lane = p_lane
	express = p_express
	set_points(p_points)


func set_points(p_points: PackedVector3Array) -> void:
	points = p_points
	_cum = PackedFloat64Array()
	_cum.resize(points.size())
	var acc := 0.0
	for i in points.size():
		if i > 0:
			acc += points[i].distance_to(points[i - 1])
		_cum[i] = acc


func length() -> float:
	return _cum[_cum.size() - 1] if _cum.size() > 0 else 0.0


func _segment_for(s: float) -> int:
	# binary search: last index i with _cum[i] <= s
	var lo := 0
	var hi := points.size() - 2
	if hi < 0:
		return 0
	while lo < hi:
		var mid := (lo + hi + 1) >> 1
		if _cum[mid] <= s:
			lo = mid
		else:
			hi = mid - 1
	return lo


func sample(s: float) -> Vector3:
	if points.is_empty():
		return Vector3.ZERO
	if points.size() == 1:
		return points[0]
	s = clampf(s, 0.0, length())
	var i := _segment_for(s)
	var seg := _cum[i + 1] - _cum[i]
	var t := 0.0 if seg <= 1e-9 else (s - _cum[i]) / seg
	return points[i].lerp(points[i + 1], t)


func tangent(s: float) -> Vector3:
	if points.size() < 2:
		return Vector3.FORWARD
	s = clampf(s, 0.0, length())
	var i := _segment_for(s)
	var d := points[i + 1] - points[i]
	return d.normalized() if d.length_squared() > 1e-12 else Vector3.FORWARD


## Returns { s, point, distance } for the closest point on the rail.
func closest(pos: Vector3) -> Dictionary:
	var best := {"s": 0.0, "point": points[0] if points.size() > 0 else Vector3.ZERO, "distance": INF}
	if points.size() == 1:
		best["distance"] = pos.distance_to(points[0])
		return best
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var ab := b - a
		var l2 := ab.length_squared()
		var t := 0.0 if l2 <= 1e-12 else clampf((pos - a).dot(ab) / l2, 0.0, 1.0)
		var q := a + ab * t
		var d := pos.distance_to(q)
		if d < float(best["distance"]):
			best = {"s": _cum[i] + (_cum[i + 1] - _cum[i]) * t, "point": q, "distance": d}
	return best
