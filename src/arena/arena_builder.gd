class_name ArenaBuilder
extends RefCounted
## Greybox geometry builder for the movement arena and the headless tests
## (docs/design/movement_architecture.md §11). All static.
##
## Conventions (design §3): meters, +Y up, forward is -Z. Every collider is a StaticBody3D on
## collision layer WORLD (1) with mask 0, using a BoxShape3D or ConvexPolygonShape3D.
## All positions are in the local space of `root` (normally the world origin).
## Visual meshes join group &"greybox" so MovementArena can apply the meter grid material.

const WORLD_LAYER := 1                 # design §3 collision layer WORLD
const GREYBOX_GROUP := &"greybox"
const TELEPORT_GROUP := &"teleport_points"
const FLOOR_THICKNESS := 1.0
const HU := 0.0254                     # spec: movement.md §1 (1 u = 0.0254 m), mirrors MoveUnits.HU

# --- full layout tunables (design §11) ------------------------------------------------
const SPRINT_LANE_LENGTH := 60.0
const RAMP_ANGLES: Array[float] = [10.0, 20.0, 30.0, 45.0, 50.0]
const RAMP_LENGTH := 8.0
const RAMP_WIDTH := 3.0
const STAIR_HEIGHTS_U: Array[int] = [8, 16, 18, 20]
const STAIR_DEPTH := 0.5
const STAIR_COUNT := 8
const MANTLE_HEIGHTS_U: Array[int] = [24, 32, 64, 96, 128, 160, 170]
const ZIP_INNER_SPEED := 18.0          # spec: movement.md §16
const ZIP_OUTER_SPEED := 21.0          # spec: movement.md §16


# ============================================================================
# layouts
# ============================================================================

## Builds a layout under `root`. &"none" = nothing, &"flat" = floor only, &"full" = the movement
## debug arena, &"three_lane" = the 5v5 lane map (LaneMapBuilder).
## Returns { "spawn": Vector3, "markers": Dictionary[String, Vector3] }.
static func build(root: Node3D, layout: StringName = &"full") -> Dictionary:
	var out := {"spawn": Vector3.ZERO, "markers": {}}
	match layout:
		&"none":
			return out
		&"flat":
			add_floor(root)
			return out
		&"full":
			_build_full(root, out)
			out["minimap"] = {"rect": Rect2(-100, -100, 200, 200), "name": "Movement Debug"}
			return out
		&"three_lane":
			LaneMapBuilder.build(root, out)
			return out
		_:
			push_warning("ArenaBuilder: unknown layout '%s', building 'flat'" % layout)
			add_floor(root)
			return out


static func _mark(root: Node3D, out: Dictionary, name: String, pos: Vector3) -> void:
	add_marker(root, name, pos)
	(out["markers"] as Dictionary)[name] = pos


static func _build_full(root: Node3D, out: Dictionary) -> void:
	add_floor(root)
	# 01 spawn
	_mark(root, out, "01_spawn", Vector3.ZERO)
	out["spawn"] = Vector3.ZERO
	_build_sprint_lane(root, out)
	_build_ramps(root, out)
	_build_slide_slope(root, out)
	_build_stairs(root, out)
	_build_walls(root, out)
	_build_mantle(root, out)
	_build_ziplines(root, out)
	_build_rope(root, out)
	_build_jump_gauge(root, out)


## 02 sprint lane: z = 0 .. -60 with 1 m floor strips and 5 m distance labels (spec: movement.md §2, §3).
static func _build_sprint_lane(root: Node3D, out: Dictionary) -> void:
	var lane := Node3D.new()
	lane.name = "SprintLane"
	root.add_child(lane)
	for i in int(SPRINT_LANE_LENGTH) + 1:
		var z := -float(i)
		var major := i % 5 == 0
		var strip := _visual_box(Vector3(2.0 if major else 1.0, 0.004, 0.05 if major else 0.025),
				Color(0.95, 0.55, 0.1) if major else Color(0.15, 0.15, 0.15))
		strip.position = Vector3(0.0, 0.002, z)
		lane.add_child(strip)
		if major:
			var lbl := Label3D.new()
			lbl.text = "%d m" % i
			lbl.font_size = 48
			lbl.pixel_size = 0.01
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lbl.position = Vector3(1.6, 0.4, z)
			lane.add_child(lbl)
	_mark(root, out, "02_sprint_lane", Vector3(0.0, 0.0, 0.0))


## 03 ramps at x = 20: 10/20/30/45/50 degrees (45 walkable, 50 not; spec impl notes floor angle).
static func _build_ramps(root: Node3D, out: Dictionary) -> void:
	for i in RAMP_ANGLES.size():
		var a := RAMP_ANGLES[i]
		var x := 20.0 + (float(i) - 2.0) * (RAMP_WIDTH + 1.0)
		add_ramp(root, Vector3(x, 0.0, -5.0), a, RAMP_LENGTH, RAMP_WIDTH)
		_add_label(root, "%d°" % int(a), Vector3(x, 0.6, -3.5))
		_mark(root, out, "03_ramp_%02d" % int(a), Vector3(x, 0.0, -3.0))


## 04 slide slope at x = -30: 20 degrees, 30 m long, 6 m wide (spec: movement.md §13).
## The slope rises toward -Z; the top marker faces down the slope with yaw PI (+Z).
static func _build_slide_slope(root: Node3D, out: Dictionary) -> void:
	var angle := 20.0
	var length := 30.0
	add_ramp(root, Vector3(-30.0, 0.0, -5.0), angle, length, 6.0)
	var run := length * cos(deg_to_rad(angle))
	var h := length * sin(deg_to_rad(angle))
	# flat landing at the top so the player can stand before sliding
	add_box(root, Vector3(-30.0, h * 0.5, -5.0 - run - 2.0), Vector3(6.0, h, 4.0), "SlideSlopeTop")
	_mark(root, out, "04_slide_slope", Vector3(-30.0, h, -5.0 - run - 1.0))
	_mark(root, out, "04_slide_slope_bottom", Vector3(-30.0, 0.0, -3.0))


## 05 stairs at x = 40: step heights 8/16/18/20 u; 20 u must block (step_height 18 u, impl notes).
static func _build_stairs(root: Node3D, out: Dictionary) -> void:
	for i in STAIR_HEIGHTS_U.size():
		var hu_steps := STAIR_HEIGHTS_U[i]
		var x := 40.0 + (float(i) - 1.5) * 4.0
		add_stairs(root, Vector3(x, 0.0, -5.0), float(hu_steps) * HU, STAIR_DEPTH, STAIR_COUNT, 3.0)
		_add_label(root, "%d u" % hu_steps, Vector3(x, 0.6, -3.5))
		_mark(root, out, "05_stairs_%02du" % hu_steps, Vector3(x, 0.0, -3.0))


## 06 walls at x = 60: parallel walls 3 m apart (12 m tall, 20 m long), a lone wall, a 2x2 pillar
## (spec: movement.md §14 wall jump and corner boost).
static func _build_walls(root: Node3D, out: Dictionary) -> void:
	var t := 0.5
	var gap := 3.0
	add_wall(root, Vector3(60.0 - gap * 0.5 - t * 0.5, 6.0, -15.0), Vector3(t, 12.0, 20.0))
	add_wall(root, Vector3(60.0 + gap * 0.5 + t * 0.5, 6.0, -15.0), Vector3(t, 12.0, 20.0))
	_mark(root, out, "06_walls_corridor", Vector3(60.0, 0.0, -4.0))
	add_wall(root, Vector3(70.0, 6.0, -15.0), Vector3(t, 12.0, 20.0))
	_mark(root, out, "06_walls_lone", Vector3(68.0, 0.0, -15.0))
	add_box(root, Vector3(66.0, 6.0, -35.0), Vector3(2.0, 12.0, 2.0), "Pillar")
	_mark(root, out, "06_walls_pillar", Vector3(66.0, 0.0, -31.0))


## 07 mantle at x = 80: ledges 24..170 u, 2 m deep, 4 m apart, plus a 160 u wall 4 u deep
## (spec: movement.md §15 bands 32..160 u, min depth 6 u).
static func _build_mantle(root: Node3D, out: Dictionary) -> void:
	var z_front := -5.0
	for i in MANTLE_HEIGHTS_U.size():
		var h_u := MANTLE_HEIGHTS_U[i]
		var x := 80.0 + float(i) * 4.0
		add_ledge(root, Vector3(x, 0.0, z_front), h_u)
		_add_label(root, "%d u" % h_u, Vector3(x, 0.6, z_front + 1.0))
		_mark(root, out, "07_mantle_%03du" % h_u, Vector3(x, 0.0, z_front + 0.3 + 0.4064))
	var xw := 80.0 + float(MANTLE_HEIGHTS_U.size()) * 4.0
	add_ledge(root, Vector3(xw, 0.0, z_front), 160, 4.0 * HU)
	_add_label(root, "160 u thin", Vector3(xw, 0.6, z_front + 1.0))
	_mark(root, out, "07_mantle_thin_wall", Vector3(xw, 0.0, z_front + 0.3 + 0.4064))


## 08 ziplines: 60 m rail (-50,5,0) -> (-50,9,-60) at 18 m/s and a parallel 21 m/s rail at x = -54
## (spec: movement.md §16). A boarding platform under the rail starts, reached by a 25° ramp.
static func _build_ziplines(root: Node3D, out: Dictionary) -> void:
	add_zipline(root, PackedVector3Array([Vector3(-50.0, 5.0, 0.0), Vector3(-50.0, 9.0, -60.0)]), ZIP_INNER_SPEED)
	add_zipline(root, PackedVector3Array([Vector3(-54.0, 5.0, 0.0), Vector3(-54.0, 9.0, -60.0)]), ZIP_OUTER_SPEED)
	# platform: top at 3.2 m so a standing capsule center (feet + 0.91) is < 1 m under the rail
	var top := 3.2
	add_box(root, Vector3(-52.0, top * 0.5, 0.75), Vector3(7.0, top, 4.5), "ZiplinePlatform")
	var ang := 25.0
	var run := top / tan(deg_to_rad(ang))
	add_ramp(root, Vector3(-52.0, 0.0, 3.0 + run), ang, top / sin(deg_to_rad(ang)), 7.0)
	# end posts (visual only)
	for x in [-50.0, -54.0]:
		for pz in [[0.0, 5.0], [-60.0, 9.0]]:
			var post := _visual_box(Vector3(0.15, pz[1], 0.15), Color(0.3, 0.3, 0.35))
			post.position = Vector3(x, pz[1] * 0.5, pz[0])
			root.add_child(post)
	_mark(root, out, "08_zipline", Vector3(-50.0, top, 0.5))
	_mark(root, out, "08_zipline_ramp", Vector3(-52.0, 0.0, 3.0 + run + 2.0))


## 09 rope: 10 m hanging from (-70, 12, 0) (spec: movement.md §17).
static func _build_rope(root: Node3D, out: Dictionary) -> void:
	add_rope(root, Vector3(-70.0, 12.0, 0.0), 10.0)
	var vis := _visual_box(Vector3(0.06, 10.0, 0.06), Color(0.55, 0.4, 0.2))
	vis.position = Vector3(-70.0, 7.0, 0.0)
	root.add_child(vis)
	_mark(root, out, "09_rope", Vector3(-70.0, 0.0, 0.6))


## 10 jump gauge: a pole with 0.1 m ticks up to 2 m (visual only; spec: movement.md §10 jump height).
static func _build_jump_gauge(root: Node3D, out: Dictionary) -> void:
	var g := Node3D.new()
	g.name = "JumpGauge"
	g.position = Vector3(3.0, 0.0, 2.0)
	root.add_child(g)
	var pole := _visual_box(Vector3(0.05, 2.0, 0.05), Color(0.9, 0.9, 0.9))
	pole.position = Vector3(0.0, 1.0, 0.0)
	g.add_child(pole)
	for i in 21:
		var y := float(i) * 0.1
		var major := i % 5 == 0
		var tick := _visual_box(Vector3(0.4 if major else 0.2, 0.01, 0.01), Color(0.95, 0.2, 0.2) if major else Color(0.1, 0.1, 0.1))
		tick.position = Vector3(0.0, y, 0.0)
		g.add_child(tick)
		if major:
			var lbl := Label3D.new()
			lbl.text = "%.1f m" % y
			lbl.font_size = 32
			lbl.pixel_size = 0.005
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lbl.position = Vector3(0.35, y, 0.0)
			g.add_child(lbl)
	_mark(root, out, "10_jump_gauge", Vector3(3.0, 0.0, 3.0))


# ============================================================================
# primitives
# ============================================================================

## Floor slab with its top face at y = 0.
static func add_floor(root: Node3D, size: Vector2 = Vector2(200, 200)) -> StaticBody3D:
	return add_box(root, Vector3(0.0, -FLOOR_THICKNESS * 0.5, 0.0), Vector3(size.x, FLOOR_THICKNESS, size.y), "Floor")


static func add_box(root: Node3D, center: Vector3, size: Vector3, name: String = "", yaw: float = 0.0) -> StaticBody3D:
	var body := _new_body(name if name != "" else "Box")
	body.position = center
	body.rotation.y = yaw
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.add_to_group(GREYBOX_GROUP)
	body.add_child(mi)
	root.add_child(body)
	return body


## Wedge ramp: the low edge lies on y = base_center.y at base_center, the surface rises toward
## local -Z (rotated by `yaw` about +Y). `length` is measured along the sloped surface.
static func add_ramp(root: Node3D, base_center: Vector3, angle_deg: float, length: float, width: float, yaw: float = 0.0) -> StaticBody3D:
	var a := deg_to_rad(angle_deg)
	var run := length * cos(a)
	var h := length * sin(a)
	var hw := width * 0.5
	var body := _new_body("Ramp%d" % int(round(angle_deg)))
	body.position = base_center
	body.rotation = Vector3(0.0, yaw, 0.0)
	var cs := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array([
		Vector3(-hw, 0.0, 0.0), Vector3(hw, 0.0, 0.0),
		Vector3(-hw, 0.0, -run), Vector3(hw, 0.0, -run),
		Vector3(-hw, h, -run), Vector3(hw, h, -run),
	])
	cs.shape = shape
	body.add_child(cs)
	# PrismMesh with the apex at +X, turned so +X maps to -Z.
	var mi := MeshInstance3D.new()
	var mesh := PrismMesh.new()
	mesh.left_to_right = 1.0
	mesh.size = Vector3(run, h, width)
	mi.mesh = mesh
	mi.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.0, h * 0.5, -run * 0.5))
	mi.add_to_group(GREYBOX_GROUP)
	body.add_child(mi)
	root.add_child(body)
	return body


## Solid stairs rising toward -Z. The first riser's front face is at origin.z; each step is a
## box from origin.y up to its tread. A flat landing (2 m) follows the last step.
static func add_stairs(root: Node3D, origin: Vector3, step_height: float, step_depth: float, count: int, width: float) -> Node3D:
	var n := Node3D.new()
	n.name = "Stairs"
	root.add_child(n)
	for i in count:
		var top := step_height * float(i + 1)
		var depth := step_depth if i < count - 1 else step_depth + 2.0
		var zc := origin.z - step_depth * float(i) - depth * 0.5
		add_box(n, Vector3(origin.x, origin.y + top * 0.5, zc), Vector3(width, top, depth), "Step%d" % i)
	return n


## Mantle ledge: a box `height_u` units tall whose front face (+Z side) is centered on front_center.
static func add_ledge(root: Node3D, front_center: Vector3, height_u: int, depth: float = 2.0, width: float = 3.0) -> StaticBody3D:
	var h := float(height_u) * HU
	return add_box(root, front_center + Vector3(0.0, h * 0.5, -depth * 0.5), Vector3(width, h, depth), "Ledge%du" % height_u)


static func add_wall(root: Node3D, center: Vector3, size: Vector3) -> StaticBody3D:
	return add_box(root, center, size, "Wall")


## Zipline through `points` (root space). Joins group &"zipline" in its _ready.
static func add_zipline(root: Node3D, points: PackedVector3Array, lane_speed: float) -> Zipline:
	var z := Zipline.new()
	z.name = "Zipline"
	z.lane_speed = lane_speed
	var c := Curve3D.new()
	for p in points:
		c.add_point(p)
	z.curve = c
	root.add_child(z)
	# visual cable
	if points.size() >= 2:
		for i in points.size() - 1:
			var a: Vector3 = points[i]
			var b: Vector3 = points[i + 1]
			var seg := _visual_box(Vector3(0.05, 0.05, a.distance_to(b)), Color(0.2, 0.2, 0.2))
			var mid := (a + b) * 0.5
			seg.transform = Transform3D(Basis.looking_at((b - a).normalized(), Vector3.UP), mid)
			root.add_child(seg)
	return z


static func add_rope(root: Node3D, top: Vector3, length: float) -> ClimbRope:
	var r := ClimbRope.new()
	r.name = "ClimbRope"
	r.length = length
	r.position = top
	root.add_child(r)
	return r


static func add_marker(root: Node3D, name: String, pos: Vector3) -> Marker3D:
	var m := Marker3D.new()
	m.name = name
	m.position = pos
	m.add_to_group(TELEPORT_GROUP)
	root.add_child(m)
	return m


# ============================================================================
# helpers
# ============================================================================

static func _new_body(name: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	return body


static func _visual_box(size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _add_label(root: Node3D, text: String, pos: Vector3) -> Label3D:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 48
	lbl.pixel_size = 0.01
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = pos
	root.add_child(lbl)
	return lbl
