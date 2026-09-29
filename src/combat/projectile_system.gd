class_name ProjectileSystem
extends Node3D
## Every live bullet in one world (spec: combat.md §2 projectiles; docs/design/gun_system_plan.md).
## Bullets are plain data in packed arrays, never physics bodies. Each tick a bullet moves along
## one segment: one ray against WORLD, then segment-vs-capsule math against the registered
## targets (group "bullet_targets"). Dead slots are reused (that is all the pooling there is).
## Tracers are drawn with one MultiMesh.
##
## A target is any Node3D in group "bullet_targets" with:
##   get_hit_capsules() -> Array of [a: Vector3, b: Vector3, radius: float, is_head: bool] (world space)
##   crit_damage_received_scale: float
##   take_bullet_hit(info: Dictionary) -> void

signal bullet_hit(info: Dictionary)          # after the target took it
signal world_hit(point: Vector3, normal: Vector3)

const DT := 1.0 / 64.0
const GRAVITY := 20.32        # m/s^2, the same world gravity as the movement sim (movement_params.gravity)
const WORLD_MASK := 1
const TARGET_GROUP := &"bullet_targets"

## Step on _physics_process. Tests turn it off and call step_tick() themselves.
@export var auto_tick: bool = true
@export var draw_tracers: bool = true
@export var tracer_width: float = 0.045
@export var tracer_max_length: float = 10.0
## Streak length in seconds of travel (capped by tracer_max_length). Long streaks are what make
## a bullet flying away from an over-the-shoulder camera readable at all.
@export var tracer_time: float = 0.03
## When a bullet dies its trail (up to tracer_ghost_length of path) collapses into the impact point
## over this long, so fast bullets that land within a frame or two still read on screen.
@export var tracer_linger: float = 0.08
@export var tracer_ghost_length: float = 40.0
@export var tracer_color: Color = Color(1.0, 0.9, 0.5)
## Tracers leave from a visual muzzle (spawn's visual_offset) and blend onto the true bullet path
## over this many meters. Visual only; hits always use the true path from the eye.
@export var tracer_converge: float = 8.0

var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _origin := PackedVector3Array()
var _voff := PackedVector3Array()        # tracer-only muzzle offset, fades over tracer_converge
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
var _first_dt := PackedFloat32Array()    # sub-tick lead for the first step; <0 after that
var _damage := PackedFloat32Array()
var _grav := PackedFloat32Array()
var _radius := PackedFloat32Array()
var _alive := PackedByteArray()
var _owner := PackedInt64Array()
var _weapon: Array[WeaponData] = []
var _pierced: Dictionary = {}            # slot -> {target instance id: true} (pierce bullets only)
var _free := PackedInt32Array()
var _high := 0                           # slots [0, _high) have been used
var live_count := 0

var _ray := PhysicsRayQueryParameters3D.new()
var _mm: MultiMesh
var _mmi: MultiMeshInstance3D
var _ghosts: Array = []                  # [end, dir, width, length, age] for bullets that just died


func _ready() -> void:
	process_physics_priority = 50   # after the shooters' ticks (their shots carry a sub-tick lead)
	_ray.collision_mask = WORLD_MASK
	_ray.collide_with_areas = false
	_ray.hit_back_faces = false
	if draw_tracers and DisplayServer.get_name() != "headless":
		_setup_tracers()


func _physics_process(_delta: float) -> void:
	if auto_tick:
		step_tick()


func _process(delta: float) -> void:
	if _mm != null:
		_update_tracers(delta)


## Spawn one bullet. `lead` is the part of the current tick left after the shot (WeaponSim);
## the bullet covers only that much on its first step. Shooter velocity is not inherited.
func spawn(origin: Vector3, dir: Vector3, w: WeaponData, damage: float, owner_id: int = 0, lead: float = DT, visual_offset := Vector3.ZERO) -> int:
	var i: int
	if _free.size() > 0:
		i = _free[_free.size() - 1]
		_free.resize(_free.size() - 1)
	else:
		i = _high
		_high += 1
		if i >= _pos.size():
			_grow(maxi(256, _pos.size() * 2))
	_pos[i] = origin
	_origin[i] = origin
	_voff[i] = visual_offset
	_vel[i] = dir.normalized() * w.bullet_speed
	_age[i] = 0.0
	_life[i] = w.max_travel_time()
	_first_dt[i] = clampf(lead, 0.0, DT)
	_damage[i] = damage
	_grav[i] = GRAVITY * w.gravity_scale
	_radius[i] = w.bullet_radius
	_alive[i] = 1
	_owner[i] = owner_id
	_weapon[i] = w
	if w.pierce:
		_pierced[i] = {}
	live_count += 1
	return i


func _grow(n: int) -> void:
	_pos.resize(n); _vel.resize(n); _origin.resize(n); _voff.resize(n)
	_age.resize(n); _life.resize(n); _first_dt.resize(n); _damage.resize(n); _grav.resize(n); _radius.resize(n)
	_alive.resize(n); _owner.resize(n); _weapon.resize(n)


func _kill(i: int) -> void:
	if _mm != null:
		var v := _vel[i]
		var sp := v.length()
		if sp > 1e-3:
			var length := minf(maxf(sp * tracer_time, tracer_ghost_length), _origin[i].distance_to(_pos[i]))
			_ghosts.append([i, _pos[i], v / sp, maxf(tracer_width, _radius[i] * 0.35), length, 0.0, _origin[i], _voff[i]])
	_alive[i] = 0
	_weapon[i] = null
	_pierced.erase(i)
	_free.append(i)
	live_count -= 1


func clear() -> void:
	for i in _high:
		if _alive[i] == 1:
			_kill(i)


func get_bullet_position(i: int) -> Vector3:
	return _pos[i]


func is_alive(i: int) -> bool:
	return i >= 0 and i < _high and _alive[i] == 1


## Advance every live bullet one tick.
func step_tick() -> void:
	if live_count == 0:
		return
	var space := get_world_3d().direct_space_state
	var targets := _gather_targets()
	for i in _high:
		if _alive[i] == 0:
			continue
		var dt := DT
		if _first_dt[i] >= 0.0:
			dt = _first_dt[i]
			_first_dt[i] = -1.0
		var remaining := _life[i] - _age[i]
		var expire := false
		if remaining <= dt:
			dt = maxf(remaining, 0.0)
			expire = true
		var p0 := _pos[i]
		var v := _vel[i]
		var g := _grav[i]
		var p1 := p0 + v * dt + Vector3.DOWN * (0.5 * g * dt * dt)
		v += Vector3.DOWN * g * dt
		_age[i] += dt
		_pos[i] = p1
		_vel[i] = v
		if p0.is_equal_approx(p1):
			if expire:
				_kill(i)
			continue
		# world first: the earliest target hit must come before it
		var wf := 1.0
		var wn := Vector3.ZERO
		_ray.from = p0
		_ray.to = p1
		var wr := space.intersect_ray(_ray)
		if not wr.is_empty():
			wf = p0.distance_to(wr["position"]) / p0.distance_to(p1)
			wn = wr["normal"]
		if _hit_targets(i, targets, p0, p1, wf):
			continue
		if wf < 1.0:
			_pos[i] = p0.lerp(p1, wf)
			world_hit.emit(_pos[i], wn)
			_kill(i)
		elif expire:
			_kill(i)


func _gather_targets() -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group(TARGET_GROUP):
		var t := n as Node3D
		if t == null or not t.is_inside_tree():
			continue
		var caps: Array = t.call(&"get_hit_capsules")
		if caps.is_empty():
			continue
		# bounding sphere for a cheap reject
		var c := Vector3.ZERO
		for cap in caps:
			c += (cap[0] + cap[1]) * 0.5
		c /= caps.size()
		var r := 0.0
		for cap in caps:
			r = maxf(r, maxf(c.distance_to(cap[0]), c.distance_to(cap[1])) + float(cap[2]))
		out.append([t, caps, c, r])
	return out


## Earliest capsule hit along p0 -> p0.lerp(p1, max_f). Returns true if the bullet was consumed.
func _hit_targets(i: int, targets: Array, p0: Vector3, p1: Vector3, max_f: float) -> bool:
	if targets.is_empty():
		return false
	var br := _radius[i]
	var best_f := max_f
	var best_t: Node3D = null
	var best_head := false
	var seg := p1 - p0
	var seg_len2 := seg.length_squared()
	for tgt in targets:
		var node: Node3D = tgt[0]
		if _owner[i] != 0 and node.get_instance_id() == _owner[i]:
			continue
		if _pierced.has(i) and (_pierced[i] as Dictionary).has(node.get_instance_id()):
			continue
		var c: Vector3 = tgt[2]
		var s := clampf((c - p0).dot(seg) / maxf(seg_len2, 1e-12), 0.0, 1.0)
		if (p0 + seg * s).distance_to(c) > float(tgt[3]) + br:
			continue
		for cap in tgt[1]:
			var f := _segment_capsule_first(p0, p1, cap[0], cap[1], float(cap[2]) + br)
			if f < 0.0:
				continue
			# head wins a tie with the same target's body (a fat bullet touching both at once)
			if f < best_f - 1e-6 or (absf(f - best_f) <= 1e-6 and best_t == node and bool(cap[3])):
				best_f = f
				best_t = node
				best_head = bool(cap[3])
	if best_t == null:
		return false
	var point := p0.lerp(p1, best_f)
	_apply_hit(i, best_t, best_head, point)
	if _pierced.has(i):
		(_pierced[i] as Dictionary)[best_t.get_instance_id()] = true
		return false   # keeps flying; a second target on this same segment is picked up next tick at worst
	_pos[i] = point
	_kill(i)
	return true


func _apply_hit(i: int, target: Node3D, head: bool, point: Vector3) -> void:
	var w := _weapon[i]
	var dist := _origin[i].distance_to(point)
	var amount := _damage[i] * CombatMath.falloff_scale(w, dist)
	var crit := head and w.can_crit
	if crit:
		var rs: Variant = target.get(&"crit_damage_received_scale")
		amount *= CombatMath.crit_mult(w.crit_bonus_scale, float(rs) if rs != null else 1.0)
	var info := {
		"amount": amount, "is_crit": crit, "is_head": head, "distance": dist, "point": point,
		"weapon": w, "source_id": _owner[i], "target": target, "direction": _vel[i].normalized(),
	}
	target.call(&"take_bullet_hit", info)
	bullet_hit.emit(info)


## First fraction f in [0, 1] where the segment point comes within `r` of capsule axis a-b, or -1.
## The distance from a moving point to a segment is convex along the path, so bisect up to the
## closest point.
static func _segment_capsule_first(p0: Vector3, p1: Vector3, a: Vector3, b: Vector3, r: float) -> float:
	var r2 := r * r
	if _dist2_point_seg(p0, a, b) <= r2:
		return 0.0
	var cp := Geometry3D.get_closest_points_between_segments(p0, p1, a, b)
	if (cp[0] as Vector3).distance_squared_to(cp[1]) > r2:
		return -1.0
	var seg_len := p0.distance_to(p1)
	var hi := 1.0 if seg_len < 1e-9 else p0.distance_to(cp[0]) / seg_len
	var lo := 0.0
	for k in 14:
		var mid := (lo + hi) * 0.5
		if _dist2_point_seg(p0.lerp(p1, mid), a, b) <= r2:
			hi = mid
		else:
			lo = mid
	return hi


static func _dist2_point_seg(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	var t := 0.0 if l2 < 1e-12 else clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_squared_to(a + ab * t)


# --- tracers ----------------------------------------------------------------------------

func _setup_tracers() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 1.0, 1.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = tracer_color
	mat.emission_enabled = true
	mat.emission = tracer_color
	mat.emission_energy_multiplier = 2.0
	mesh.material = mat
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.mesh = mesh
	_mm.instance_count = 1024
	_mm.visible_instance_count = 0
	_mmi = MultiMeshInstance3D.new()
	_mmi.name = "Tracers"
	_mmi.multimesh = _mm
	_mmi.top_level = true
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mmi.extra_cull_margin = 16384.0
	add_child(_mmi)


func _update_tracers(delta: float) -> void:
	if live_count + _ghosts.size() > _mm.instance_count:
		_mm.instance_count = (live_count + _ghosts.size()) * 2
	var n := 0
	var k := 0
	while k < _ghosts.size():
		var gh: Array = _ghosts[k]
		gh[5] += delta
		var left := 1.0 - float(gh[5]) / tracer_linger
		if left <= 0.0:
			_ghosts.remove_at(k)
			continue
		left *= left   # the tail snaps in fast, then the last bit near the impact hangs
		k += 1
		var end: Vector3 = gh[1]
		_set_streak(n, end - (gh[2] as Vector3) * (float(gh[4]) * left), end, gh[6], gh[7], gh[3])
		n += 1
	var f := clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	for i in _high:
		if _alive[i] == 0:
			continue
		var v := _vel[i]
		var speed := v.length()
		if speed < 1e-3:
			continue
		var dir := v / speed
		var head := _pos[i] + v * (DT * f)
		var length := minf(minf(speed * tracer_time, tracer_max_length), _origin[i].distance_to(head))
		_set_streak(n, head - dir * length, head, _origin[i], _voff[i], maxf(tracer_width, _radius[i] * 0.35))
		n += 1
	_mm.visible_instance_count = n


## One streak instance from tail to head (true path points), shifted by the fading muzzle offset.
func _set_streak(n: int, tail: Vector3, head: Vector3, origin: Vector3, voff: Vector3, w: float) -> void:
	var inv := 1.0 / maxf(tracer_converge, 0.01)
	var t := tail + voff * maxf(0.0, 1.0 - origin.distance_to(tail) * inv)
	var h := head + voff * maxf(0.0, 1.0 - origin.distance_to(head) * inv)
	var seg := h - t
	var length := seg.length()
	var dir := seg / length if length > 1e-5 else Vector3.FORWARD
	_mm.set_instance_transform(n, Transform3D(_streak_basis(dir, w, length), (t + h) * 0.5))


static func _streak_basis(dir: Vector3, w: float, length: float) -> Basis:
	var x := dir.cross(Vector3.UP)
	if x.length_squared() < 1e-6:
		x = dir.cross(Vector3.RIGHT)
	x = x.normalized()
	var y := x.cross(dir).normalized()
	return Basis(x * w, y * w, dir * maxf(length, 0.01))
