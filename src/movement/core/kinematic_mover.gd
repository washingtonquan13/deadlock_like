class_name KinematicMover
extends RefCounted
## Collision queries for the pure sim (design §7.7). Two server-side probe bodies (stand and crouch
## capsules, layer 0, mask WORLD) swept with PhysicsServer3D.body_test_motion. No move_and_slide.
## Collide-and-slide / step-up / ground probe are our own implementation of the widely documented
## "sweep, clip velocity against the hit plane, repeat" technique.

const WORLD_MASK := 1
const EPS := 1e-6

var params: MovementParams
var _world: World3D
var _space: RID
var _stand_body: RID
var _crouch_body: RID
var _stand_shape: RID
var _crouch_shape: RID
var _stand_query_shape: RID
var _crouch_query_shape: RID
var _floor_min_y: float = 0.7
var _disposed: bool = false
# Reused query objects (no per-sweep allocation in the hot path).
var _tm_params := PhysicsTestMotionParameters3D.new()
var _tm_result := PhysicsTestMotionResult3D.new()
var _ray_query := PhysicsRayQueryParameters3D.new()
var _shape_query := PhysicsShapeQueryParameters3D.new()


func _init(world: World3D, p_params: MovementParams) -> void:
	params = p_params if p_params != null else MovementParams.new()
	_world = world
	_floor_min_y = cos(deg_to_rad(params.max_floor_angle_deg))
	if world == null:
		push_warning("KinematicMover: null World3D; collision queries will report no hits")
		return
	_space = world.space
	var r := params.capsule_radius
	_stand_shape = _make_capsule(r, params.capsule_height_stand)
	_crouch_shape = _make_capsule(r, params.capsule_height_crouch)
	_stand_query_shape = _make_capsule(r - 0.01, params.capsule_height_stand - 0.02)
	_crouch_query_shape = _make_capsule(r - 0.01, params.capsule_height_crouch - 0.02)
	_stand_body = _make_body(_stand_shape, params.capsule_height_stand)
	_crouch_body = _make_body(_crouch_shape, params.capsule_height_crouch)


func _make_capsule(radius: float, height: float) -> RID:
	var s := PhysicsServer3D.capsule_shape_create()
	PhysicsServer3D.shape_set_data(s, {"radius": radius, "height": height})
	return s


func _make_body(shape: RID, height: float) -> RID:
	var b := PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(b, PhysicsServer3D.BODY_MODE_KINEMATIC)
	PhysicsServer3D.body_set_collision_layer(b, 0)
	PhysicsServer3D.body_set_collision_mask(b, WORLD_MASK)
	# Shape offset so the body origin is at the feet (capsule bottom).
	PhysicsServer3D.body_add_shape(b, shape, Transform3D(Basis.IDENTITY, Vector3(0.0, height * 0.5, 0.0)))
	PhysicsServer3D.body_set_space(b, _space)
	PhysicsServer3D.body_set_state(b, PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(Basis.IDENTITY, Vector3(0.0, -10000.0, 0.0)))
	return b


func dispose() -> void:
	if _disposed:
		return
	_disposed = true
	for rid in [_stand_body, _crouch_body, _stand_shape, _crouch_shape, _stand_query_shape, _crouch_query_shape]:
		if rid.is_valid():
			PhysicsServer3D.free_rid(rid)


func _height(crouched: bool) -> float:
	return params.capsule_height_crouch if crouched else params.capsule_height_stand


# --- raw queries -----------------------------------------------------------------

## Raw body_test_motion wrapper.
## Returns { collided, travel, remainder, normal, point, position, fraction }.
func test_motion(from: Vector3, motion: Vector3, crouched: bool) -> Dictionary:
	var out := {
		"collided": false, "travel": motion, "remainder": Vector3.ZERO,
		"normal": Vector3.ZERO, "point": Vector3.ZERO, "position": from + motion, "fraction": 1.0,
	}
	if _disposed or not _space.is_valid():
		return out
	var body := _crouch_body if crouched else _stand_body
	var p := _tm_params
	p.from = Transform3D(Basis.IDENTITY, from)
	p.motion = motion
	p.margin = params.collision_margin
	p.recovery_as_collision = false
	p.max_collisions = 4
	var res := _tm_result
	var hit := PhysicsServer3D.body_test_motion(body, p, res)
	var travel := res.get_travel()
	if not hit and (travel - motion).length() <= params.collision_margin * 2.0 + 1e-4:
		# An unobstructed sweep is exact kinematics. The engine's travel also folds in contact
		# recovery (depenetration within the margin), which would add ~1 mm of drift whenever the
		# capsule starts touching a surface (e.g. the first tick of a jump off the floor).
		# A larger difference means the start pose was really penetrating: keep the engine's
		# recovery so the capsule is pushed out of the geometry.
		travel = motion
	out["travel"] = travel
	out["position"] = from + travel
	if hit and res.get_collision_count() > 0:
		# Prefer the contact most opposed to the motion (most relevant to the sweep).
		var best := 0
		var best_dot := INF
		var md := motion.normalized() if motion.length_squared() > EPS else Vector3.ZERO
		for i in res.get_collision_count():
			var d := res.get_collision_normal(i).dot(md)
			if d < best_dot:
				best_dot = d
				best = i
		out["collided"] = true
		out["remainder"] = res.get_remainder()
		out["normal"] = res.get_collision_normal(best)
		out["point"] = res.get_collision_point(best)
		out["fraction"] = res.get_collision_safe_fraction()
	return out


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	if _world == null:
		return {}
	var q := _ray_query
	q.from = from
	q.to = to
	q.collision_mask = WORLD_MASK
	q.hit_from_inside = false
	q.collide_with_areas = false
	return _world.direct_space_state.intersect_ray(q)


func _overlaps(feet: Vector3, crouched: bool) -> bool:
	if _world == null:
		return false
	var q := _shape_query
	q.shape_rid = _crouch_query_shape if crouched else _stand_query_shape
	q.transform = Transform3D(Basis.IDENTITY, feet + Vector3(0.0, _height(crouched) * 0.5 + 0.005, 0.0))
	q.collision_mask = WORLD_MASK
	q.collide_with_areas = false
	q.margin = 0.0
	return not _world.direct_space_state.intersect_shape(q, 1).is_empty()


# --- movement ----------------------------------------------------------------------

static func _clip(v: Vector3, n: Vector3) -> Vector3:
	var d := v.dot(n)
	if d < 0.0:
		return v - n * d
	return v


## Projects a horizontal motion onto a walkable plane keeping its horizontal part.
static func project_on_ground(m: Vector3, n: Vector3) -> Vector3:
	if n.y <= EPS:
		return m
	return Vector3(m.x, -(n.x * m.x + n.z * m.z) / n.y, m.z)


## Collide-and-slide pass. grounded: walkable hits keep horizontal speed (motion re-projected
## onto the new ground plane) and steep hits clip with their horizontal normal only.
func _slide(pos: Vector3, vel: Vector3, motion: Vector3, crouched: bool, grounded: bool) -> Dictionary:
	var orig_vel := vel
	var remaining := motion
	var planes: Array[Vector3] = []
	var normals := PackedVector3Array()
	var blocked := false
	var steep_hit := false
	for _bump in maxi(1, params.max_bumps):
		if remaining.length_squared() < EPS * EPS:
			break
		var r := test_motion(pos, remaining, crouched)
		pos = r["position"]
		if not r["collided"]:
			remaining = Vector3.ZERO
			break
		var n: Vector3 = r["normal"]
		normals.append(n)
		remaining = r["remainder"]
		var walkable := n.y >= _floor_min_y
		if grounded and walkable:
			# spec: movement.md §2 ground movement follows walkable slopes without speed loss.
			remaining = project_on_ground(Vector3(remaining.x, 0.0, remaining.z), n)
			continue
		if grounded and not walkable:
			steep_hit = true
			var nh := Vector3(n.x, 0.0, n.z)
			if nh.length_squared() > EPS:
				n = nh.normalized()
		blocked = true
		planes.append(n)
		vel = _clip(vel, n)
		remaining = _clip(remaining, n)
		# Crease: the clipped velocity must not push into any earlier plane.
		for j in planes.size() - 1:
			var pj: Vector3 = planes[j]
			if vel.dot(pj) < -1e-5 or remaining.dot(pj) < -1e-5:
				var crease := pj.cross(n)
				if crease.length_squared() < EPS:
					vel = Vector3.ZERO
					remaining = Vector3.ZERO
				else:
					crease = crease.normalized()
					vel = crease * crease.dot(vel)
					remaining = crease * crease.dot(remaining)
				break
		if planes.size() >= 3:
			vel = Vector3.ZERO
			remaining = Vector3.ZERO
		# Backtrack kill: never turn around because of a clip.
		if vel.dot(orig_vel) <= 0.0 and orig_vel.length_squared() > EPS:
			if grounded:
				vel = Vector3(0.0, vel.y, 0.0)
			else:
				vel = Vector3.ZERO
			remaining = Vector3.ZERO
			break
	return {"position": pos, "velocity": vel, "blocked": blocked, "hit_normals": normals, "steep_hit": steep_hit}


## collide-and-slide (<= max_bumps), crease handling, backtrack kill, two-pass step-up when grounded.
## Returns { position, velocity, blocked, hit_normals }.
func move(state: MoveState, motion: Vector3, crouched: bool) -> Dictionary:
	var start := state.position
	var grounded := state.grounded
	var a := _slide(start, state.velocity, motion, crouched, grounded)
	var result := {"position": a["position"], "velocity": a["velocity"], "blocked": a["blocked"], "hit_normals": a["hit_normals"]}
	var hmotion := Vector3(motion.x, 0.0, motion.z)
	# impl notes (step_height 18 u): step-up only when grounded at tick start and a steep face blocked us.
	if grounded and a["steep_hit"] and hmotion.length_squared() > EPS and params.step_height > 0.0:
		var up := test_motion(start, Vector3.UP * (params.step_height + 0.005), crouched)
		var up_pos: Vector3 = up["position"]
		var lifted := up_pos.y - start.y
		if lifted > 0.01:
			var b := _slide(up_pos, Vector3(state.velocity.x, 0.0, state.velocity.z), hmotion, crouched, false)
			var b_pos: Vector3 = b["position"]
			var down := test_motion(b_pos, Vector3.DOWN * (lifted + 0.01), crouched)
			var dn: Vector3 = down["normal"]
			# A capsule stepping onto a stair usually lands on the tread's front edge first, and that
			# contact normal is slanted (steep). Accept it when the contact is a real step: above the
			# start height, within step_height, and facing up. Walking on then rides over the edge.
			var dpt: Vector3 = down["point"]
			var rise := dpt.y - start.y
			var edge_ok := dn.y > EPS and rise > 0.005 and rise <= params.step_height + 0.005
			if down["collided"] and (dn.y >= _floor_min_y or edge_ok):
				var c_pos: Vector3 = down["position"]
				var da := Vector2(a["position"].x - start.x, a["position"].z - start.z).length()
				var db := Vector2(c_pos.x - start.x, c_pos.z - start.z).length()
				if db > da + 1e-4:
					var bv: Vector3 = b["velocity"]
					result["position"] = c_pos
					result["velocity"] = Vector3(bv.x, state.velocity.y, bv.z)
					result["blocked"] = b["blocked"]
					var hn: PackedVector3Array = b["hit_normals"]
					hn.append(dn)
					result["hit_normals"] = hn
	return result


## Ground probe: short capsule sweep down plus a center ray to recover a walkable normal on edges.
## Returns { hit, normal, distance, walkable }.
func probe_ground(pos: Vector3, crouched: bool) -> Dictionary:
	return probe_ground_dist(pos, crouched, params.ground_probe_distance)


func probe_ground_dist(pos: Vector3, crouched: bool, dist: float) -> Dictionary:
	var r := test_motion(pos, Vector3.DOWN * dist, crouched)
	if not r["collided"]:
		return {"hit": false, "normal": Vector3.UP, "distance": dist, "walkable": false}
	var n: Vector3 = r["normal"]
	var t: Vector3 = r["travel"]
	var walkable := n.y >= _floor_min_y
	if not walkable:
		# On an edge the capsule normal is slanted; accept if the ground under the center is walkable.
		var ray := _ray(pos + Vector3.UP * 0.05, pos + Vector3.DOWN * (dist + 0.05))
		if not ray.is_empty():
			var rn: Vector3 = ray["normal"]
			if rn.y >= _floor_min_y:
				n = rn
				walkable = true
	return {"hit": true, "normal": n, "distance": maxf(0.0, -t.y), "walkable": walkable}


## Conditional snap down up to step_height. Returns the new feet position (unchanged if no walkable floor).
func step_down(pos: Vector3, crouched: bool) -> Vector3:
	var r := test_motion(pos, Vector3.DOWN * params.step_height, crouched)
	if r["collided"]:
		var n: Vector3 = r["normal"]
		if n.y >= _floor_min_y:
			return r["position"]
		var ray := _ray(pos + Vector3.UP * 0.05, pos + Vector3.DOWN * (params.step_height + 0.05))
		if not ray.is_empty() and (ray["normal"] as Vector3).y >= _floor_min_y:
			return r["position"]
	return pos


## Height of the first walkable surface straight below `pos`, searching `max_dist` down.
## Returns NAN when nothing walkable is found. Used to measure ledge heights from the ground
## while airborne (spec: movement.md §15).
func floor_y_below(pos: Vector3, max_dist: float) -> float:
	var ray := _ray(pos + Vector3.UP * 0.01, pos + Vector3.DOWN * max_dist)
	if ray.is_empty() or (ray["normal"] as Vector3).y < _floor_min_y:
		return NAN
	return (ray["position"] as Vector3).y


func can_stand(pos: Vector3) -> bool:
	return not _overlaps(pos, false)


func is_clear(pos: Vector3, crouched: bool) -> bool:
	return not _overlaps(pos, crouched)


## spec: movement.md §14 wall detection. 8 horizontal sweeps of `radius` beyond the capsule.
## Returns [{ normal, point, convex, distance, slanted, raw_normal }].
## include_slanted (G04): also return upward-tilted contacts that are too steep to stand on
## (wall_max_normal_y < n.y < floor limit), e.g. a ledge-top edge, flagged slanted = true.
func find_walls(pos: Vector3, crouched: bool, radius: float, include_slanted: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lift := Vector3.UP * 0.05
	var mid_y := _height(crouched) * 0.5
	for i in 8:
		var ang := TAU * float(i) / 8.0
		var dir := Vector3(sin(ang), 0.0, -cos(ang))
		var r := test_motion(pos + lift, dir * radius, crouched)
		if not r["collided"]:
			continue
		var n: Vector3 = r["normal"]
		var slanted := false
		if absf(n.y) > params.wall_max_normal_y:
			if include_slanted and n.y > params.wall_max_normal_y and n.y < _floor_min_y:
				slanted = true
			else:
				continue
		var nh := Vector3(n.x, 0.0, n.z)
		if nh.length_squared() < EPS:
			continue
		nh = nh.normalized()
		# G13: distance from the capsule to the contact, so callers can pick the closest wall
		var dist := (r["travel"] as Vector3).length()
		var dup := -1
		for wi in out.size():
			if (out[wi]["normal"] as Vector3).dot(nh) > 0.99:
				dup = wi
				break
		if dup >= 0 and float(out[dup]["distance"]) <= dist:
			continue
		# Convex corner test: a ray from the capsule center toward the contact. A flat wall returns the
		# same normal as the capsule contact; a corner/edge returns a face normal > 10 deg away (or misses).
		var point: Vector3 = r["point"]
		var center := pos + Vector3.UP * mid_y
		var target := Vector3(point.x, center.y, point.z)
		var to_t := target - center
		var convex := false
		if to_t.length_squared() > EPS:
			var ray := _ray(center, center + to_t.normalized() * (to_t.length() + radius + 0.1))
			if ray.is_empty():
				convex = true
			else:
				var rn: Vector3 = ray["normal"]
				convex = Vector3(rn.x, 0.0, rn.z).normalized().dot(nh) < cos(deg_to_rad(10.0))
		var entry := {"normal": nh, "point": point, "convex": convex, "distance": dist, "slanted": slanted, "raw_normal": n.normalized()}
		if dup >= 0:
			out[dup] = entry
		else:
			out.append(entry)
	return out


## spec: movement.md §15 ledge detection. Returns { found, height, top, depth }.
func find_ledge(pos: Vector3, forward: Vector3, crouched: bool) -> Dictionary:
	var none := {"found": false, "height": 0.0, "top": Vector3.ZERO, "depth": 0.0}
	var fwd := Vector3(forward.x, 0.0, forward.z)
	if fwd.length_squared() < EPS:
		return none
	fwd = fwd.normalized()
	# 1. Sweep forward: there must be a steep face within reach.
	var sweep := test_motion(pos + Vector3.UP * 0.01, fwd * params.mantle_reach, crouched)
	if not sweep["collided"]:
		return none
	var sn: Vector3 = sweep["normal"]
	if sn.y >= _floor_min_y:
		return none
	var face: Vector3 = sweep["point"]
	var hu := MoveUnits.HU
	var top_u: int = params.mantle_band_tops_u[params.mantle_band_tops_u.size() - 1] if not params.mantle_band_tops_u.is_empty() else 160
	var lo_u := params.mantle_min_height_u - 4
	# 2. Top ray just past the face, from above the highest band down to below the lowest.
	var probe_xz := Vector3(face.x, 0.0, face.z) + fwd * 0.05
	var top_from := Vector3(probe_xz.x, pos.y + (top_u + 4) * hu, probe_xz.z)
	var top_to := Vector3(probe_xz.x, pos.y + lo_u * hu, probe_xz.z)
	var top_hit := _ray(top_from, top_to)
	if top_hit.is_empty():
		return none
	var tn: Vector3 = top_hit["normal"]
	if tn.y < _floor_min_y:
		return none
	var top_y: float = (top_hit["position"] as Vector3).y
	# 3. Depth: the top must continue at least mantle_min_depth past the face.
	var dxz := Vector3(face.x, 0.0, face.z) + fwd * (params.mantle_min_depth - 0.005)
	var depth_hit := _ray(Vector3(dxz.x, top_y + 0.1, dxz.z), Vector3(dxz.x, top_y - 0.1, dxz.z))
	if depth_hit.is_empty() or absf((depth_hit["position"] as Vector3).y - top_y) > 0.05:
		return none
	# 4. Clearance at the rise position and on top.
	var rise := Vector3(pos.x, top_y + 0.01, pos.z)
	var on_top := Vector3(face.x, top_y + 0.01, face.z) + fwd * (params.capsule_radius + 0.05)
	if _overlaps(rise, crouched) or _overlaps(on_top, crouched):
		return none
	return {"found": true, "height": top_y - pos.y, "top": on_top, "depth": params.mantle_min_depth}
