class_name LaneMapBuilder
extends RefCounted
## Three-lane 5v5 prototype map (docs/design/three_lane_map.md). All static; built by
## ArenaBuilder.build(root, &"three_lane").
##
## Layout: a 720 m square, team A's base in the south-west corner, team B's in the north-east.
## Top and bottom lanes run along the map edges, mid runs the diagonal, and a river crosses the
## other diagonal with the boss pit under the mid bridge. Four jungle quadrants fill the rest.
## The map is point-symmetric: team B's half is team A's half rotated 180 degrees about the
## origin. Team A's west jungle is authored and reflected across the mid diagonal for its south
## jungle.
##
## Coordinates: meters, +Y up, x east, -Z north (minimap up). Heights: ground 0, river bed -3,
## boss pit -10, base plateaus +7.

const HALF := 360.0
const CELL := 2.0
const CHUNKS := 8
const R2 := 0.70710678

const PLATEAU_H := 7.0
const BASE_EDGE := 235.0               # plateau covers x <= -235, z >= 235 (team A frame)
const BASTION_OUT := 10.0              # the mid ramp's plateau corner juts 10 m along the diagonal
const RAMP_ANGLE := 16.0
const RAMP_WIDTH := 26.0
const LANE_HALF := 14.0
const OUTER_LANE := 320.0

const RIVER_BED := -3.0
const RIVER_HALF := 9.0                # flat bed half width
const RIVER_BANK := 14.0               # bank width, bed to ground
const MEANDER := 10.0
const PIT_FLOOR := -10.0
const PIT_R := 22.0
const PIT_WALL := 4.0
const PIT_ENTRY_HALF := 5.0

const RAIL_HEIGHT := 3.0               # above the lane surface; a standing jump reaches it
const RAIL_STEP := 6.0
const SIDE_RAIL_OFF := 7.0
const MID_RAIL_OFF := 6.0

const TEAM_COLORS: Array[Color] = [Color("3cc6d0"), Color("f0913a")]
const C_GROUND := Color(0.47, 0.53, 0.45)
const C_LANE := Color(0.66, 0.62, 0.52)
const C_RIVER := Color(0.33, 0.45, 0.58)
const C_PIT := Color(0.30, 0.28, 0.36)
const C_HILL := Color(0.56, 0.60, 0.46)

# ---------------------------------------------------------------------------------------------
# authored content, team A west jungle (between the top lane and mid, south of the river)
# ---------------------------------------------------------------------------------------------

## [center, radius, height]
const HILLS := [
	[Vector2(-230, 70), 28.0, 5.0], [Vector2(-130, 40), 22.0, 3.0],
	[Vector2(-268, -60), 24.0, 4.0], [Vector2(-190, -150), 20.0, 2.5],
]
## [position, tier 0 small / 1 medium / 2 large]
const CAMPS := [
	[Vector2(-275, 110), 0], [Vector2(-215, -10), 1], [Vector2(-190, 120), 2],
	[Vector2(-240, -150), 1], [Vector2(-100, -30), 0],
]
const CAMP_NAMES := ["small camp", "medium camp", "large camp"]
const CAMP_UNITS := [1, 2, 3]
const CAMP_RADIUS := [6.0, 8.0, 10.0]
## Solid blocks: [center (feet), size, yaw]. Ridges along the lanes (3.5 m, mantle height),
## a building pair, a wall-jump alley, a tunnel and two watchtowers with ropes.
const BLOCKS := [
	[Vector3(-296, 0, 140), Vector3(4, 3.5, 50), 0.0],
	[Vector3(-296, 0, 30), Vector3(4, 3.5, 60), 0.0],
	[Vector3(-296, 0, -100), Vector3(4, 3.5, 40), 0.0],
	[Vector3(-132.7, 0, 107.3), Vector3(4, 3.5, 40), -PI / 4.0],
	[Vector3(-72.7, 0, 47.3), Vector3(4, 3.5, 30), -PI / 4.0],
	[Vector3(-245, 0, 20), Vector3(10, 2.4, 8), 0.0],
	[Vector3(-250, 0, 30), Vector3(8, 6.0, 8), 0.0],
	[Vector3(-161.75, 0, 60), Vector3(0.5, 9.0, 14), 0.0],
	[Vector3(-158.25, 0, 60), Vector3(0.5, 9.0, 14), 0.0],
	[Vector3(-123.5, 0, -70), Vector3(1, 2.6, 20), 0.0],
	[Vector3(-116.5, 0, -70), Vector3(1, 2.6, 20), 0.0],
	[Vector3(-120, 2.6, -70), Vector3(8, 0.6, 20), 0.0],
	[Vector3(-280, 0, 175), Vector3(6, 10.0, 6), 0.0],
	[Vector3(-286, 0, 166), Vector3(6, 3.5, 6), 0.0],
	[Vector3(-170, 0, -75), Vector3(6, 8.0, 6), 0.0],
]
## [top, length]
const ROPES := [
	[Vector3(-276.4, 10.3, 175), 10.3],
	[Vector3(-170, 8.3, -78.6), 8.3],
]
## Jungle zipline between the two watchtower tops.
const JUNGLE_LINE := [Vector3(-280, 12.8, 175), Vector3(-170, 10.8, -75)]
const JUNGLE_LINE_SPEED := 16.0
const SECRET_SHOP := Vector2(-235, -105)
## Areas kept clear of scatter cover: [center, radius].
const KEEP_CLEAR := [
	[Vector2(-280, 172), 14.0], [Vector2(-170, -75), 10.0], [Vector2(-248, 25), 14.0],
	[Vector2(-160, 60), 12.0], [Vector2(-120, -70), 16.0], [Vector2(-235, -105), 10.0],
]

## Lane centerlines from team A's base to team B's (xz). Index 1 is A's ramp top, 2 its bottom.
static func lanes() -> Array[PackedVector2Array]:
	var run := PLATEAU_H / tan(deg_to_rad(RAMP_ANGLE))
	var d := Vector2(R2, -R2)                                  # mid, towards team B
	var face := Vector2(-BASE_EDGE, BASE_EDGE) + d * BASTION_OUT
	var top := PackedVector2Array([
		Vector2(-OUTER_LANE, 280), Vector2(-OUTER_LANE, BASE_EDGE), Vector2(-OUTER_LANE, BASE_EDGE - run),
		Vector2(-OUTER_LANE, -270), Vector2(-270, -OUTER_LANE),
		Vector2(BASE_EDGE - run, -OUTER_LANE), Vector2(BASE_EDGE, -OUTER_LANE), Vector2(280, -OUTER_LANE)])
	var mid := PackedVector2Array([
		Vector2(-265, 265), face, face + d * run, -(face + d * run), -face, Vector2(265, -265)])
	var bot := PackedVector2Array()
	for i in range(top.size() - 1, -1, -1):
		bot.append(-top[i])
	return [top, mid, bot]


# =============================================================================================
# build
# =============================================================================================

static func build(root: Node3D, out: Dictionary) -> void:
	var ctx := {"icons": [], "dummies": [], "cables": [], "posts": [], "keep": []}
	for k in KEEP_CLEAR:
		for m in 4:
			ctx["keep"].append([_map2(k[0], m), k[1]])
	for c in CAMPS:
		for m in 4:
			ctx["keep"].append([_map2(c[0], m), CAMP_RADIUS[c[1]] + 6.0])
	var terrain := _build_terrain(root)
	_build_bounds(root)
	for team in 2:
		_build_base(root, ctx, team)
	_build_bridges(root)
	_build_lanes(root, ctx)
	for m in 4:
		_build_jungle(root, ctx, m)
	_scatter(root, ctx)
	_build_visual_batches(root, ctx)
	# boss pit and powerups
	var boss := Vector3(0.0, PIT_FLOOR, 0.0)
	ctx["icons"].append({"kind": &"boss", "team": -1, "pos": Vector2.ZERO})
	ctx["dummies"].append([boss, 0.0, 6000.0])
	_pad(root, boss, 8.0, Color(0.6, 0.35, 0.8), "Mid Boss (placeholder)")
	for m: int in [0, 2]:
		var p := _map2(Vector2(-295, -295), m)
		ctx["icons"].append({"kind": &"powerup", "team": -1, "pos": p})
		_pad(root, Vector3(p.x, 0.0, p.y), 3.0, Color(0.3, 0.9, 0.9), "Powerup")
	# spawn and teleport points (F4 cycles them, F8 goes to the first)
	var spawn := Vector3(-338.0, PLATEAU_H, 338.0)
	out["spawn"] = spawn
	out["spawn_yaw"] = -PI / 4.0
	var lane_pts := lanes()
	var marks := {
		"01_spawn_a": spawn,
		"02_mid_ramp_a": _v3(lane_pts[1][2]),
		"03_top_guardian_a": _v3(_lane_point(lane_pts[0], 330.0) + Vector2(12, 0)),
		"04_bot_guardian_a": _v3(_lane_point(lane_pts[2], 380.0) + Vector2(0, -12)),
		"05_jungle_west_a": _v3(Vector2(-205, 60)),
		"06_jungle_south_a": _v3(_map2(Vector2(-205, 60), 1)),
		"07_secret_shop_a": _v3(SECRET_SHOP + Vector2(6, 0)),
		"08_top_bridge": _v3(Vector2(-295, -295)),
		"09_mid_bridge": _v3(Vector2(4, -4)),
		"10_boss_pit": Vector3(6.0, PIT_FLOOR, 6.0),
		"11_bot_bridge": _v3(Vector2(295, 295)),
		"12_spawn_b": Vector3(338.0, PLATEAU_H, -338.0),
	}
	for k: String in marks:
		ArenaBuilder.add_marker(root, k, marks[k])
		(out["markers"] as Dictionary)[k] = marks[k]
	out["dummies"] = ctx["dummies"]
	out["fog"] = true
	out["minimap"] = {
		"rect": Rect2(-HALF, -HALF, HALF * 2.0, HALF * 2.0),
		"image": terrain["image"],
		"icons": ctx["icons"],
		"name": "Three Lanes",
	}


# =============================================================================================
# symmetry
# =============================================================================================

## Mode 0 = as authored (team A west), 1 = reflected across the mid diagonal (team A south),
## 2 = rotated 180 degrees (team B), 3 = both.
static func _map2(p: Vector2, mode: int) -> Vector2:
	var q := p
	if mode & 1:
		q = Vector2(-q.y, -q.x)
	if mode & 2:
		q = -q
	return q


static func _map3(p: Vector3, mode: int) -> Vector3:
	var q := _map2(Vector2(p.x, p.z), mode)
	return Vector3(q.x, p.y, q.y)


static func _map_yaw(yaw: float, mode: int) -> float:
	var y := yaw
	if mode & 1:
		y = PI * 0.5 - y
	if mode & 2:
		y += PI
	return y


static func _v3(p: Vector2) -> Vector3:
	return Vector3(p.x, ground_y(p.x, p.y), p.y)


# =============================================================================================
# heights
# =============================================================================================

static func _meander(s: float) -> float:
	# odd in s (point symmetry) and zero at the centre and under both side bridges (s = +-417)
	return MEANDER * sin(TAU * s / (295.0 / R2))


## Terrain without hills: river channel, boss pit and its two entrances along the river.
static func _base_height(x: float, z: float) -> float:
	var s := (x + z) * R2
	var u := (x - z) * R2
	var h := 0.0
	var du := absf(u - _meander(s))
	if du < RIVER_HALF + RIVER_BANK:
		h = RIVER_BED * (1.0 - smoothstep(RIVER_HALF, RIVER_HALF + RIVER_BANK, du))
	var r2 := x * x + z * z
	if r2 < 40.0 * 40.0:
		var r := sqrt(r2)
		var wall := lerpf(PIT_FLOOR, 0.0, clampf((r - PIT_R) / PIT_WALL, 0.0, 1.0))
		var pit := minf(h, wall)
		var ramp := lerpf(PIT_FLOOR, RIVER_BED, clampf((absf(s) - (PIT_R - 6.0)) / 19.0, 0.0, 1.0))
		if ramp < pit:
			var w := smoothstep(PIT_ENTRY_HALF, PIT_ENTRY_HALF + 3.0, absf(u - _meander(s)))
			pit = lerpf(ramp, pit, w)
		h = pit
	return h


static func _hill_add(d: float, r: float, hh: float) -> float:
	if d >= r:
		return 0.0
	var k := 1.0 - d / r
	return hh * k * k * (3.0 - 2.0 * k)


## Terrain height at (x, z), same function the terrain mesh is built from.
static func terrain_height(x: float, z: float) -> float:
	var h := _base_height(x, z)
	var p := Vector2(x, z)
	for hl in HILLS:
		for m in 4:
			h += _hill_add(p.distance_to(_map2(hl[0], m)), hl[1], hl[2])
	return h


## Walkable surface at (x, z): plateaus, ramps, bridge decks, else terrain. Blocks are ignored.
static func ground_y(x: float, z: float) -> float:
	for sgn: float in [1.0, -1.0]:
		var q := Vector2(x, z) * sgn
		if _in_plateau(q):
			return PLATEAU_H
		var ry := _ramp_y(q)
		if ry >= 0.0:
			return ry
	var t := terrain_height(x, z)
	if t < 0.0 and _on_bridge(Vector2(x, z)):
		return 0.0
	return t


static func _in_plateau(q: Vector2) -> bool:
	if q.x <= -BASE_EDGE and q.y >= BASE_EDGE:
		return true
	# bastion: 26 m wide, 40 m deep, its outer face 10 m past the corner along the diagonal
	var c := Vector2(-BASE_EDGE, BASE_EDGE)
	var n := Vector2(R2, -R2)
	var a := (q - c).dot(n)
	var b := (q - c).dot(Vector2(R2, R2))
	return a <= BASTION_OUT and a >= BASTION_OUT - 40.0 and absf(b) <= RAMP_WIDTH * 0.5


## [top edge centre, outward direction] for team A's three ramps.
static func _ramps() -> Array:
	var n := Vector2(R2, -R2)
	return [
		[Vector2(-OUTER_LANE, BASE_EDGE), Vector2(0, -1)],
		[Vector2(-BASE_EDGE, BASE_EDGE) + n * BASTION_OUT, n],
		[Vector2(-BASE_EDGE, OUTER_LANE), Vector2(1, 0)],
	]


static func _ramp_y(q: Vector2) -> float:
	var run := PLATEAU_H / tan(deg_to_rad(RAMP_ANGLE))
	for r in _ramps():
		var t: Vector2 = r[0]
		var d: Vector2 = r[1]
		var a := (q - t).dot(d)
		var b := (q - t).dot(Vector2(-d.y, d.x))
		if a >= 0.0 and a <= run and absf(b) <= RAMP_WIDTH * 0.5:
			return PLATEAU_H * (1.0 - a / run)
	return -1.0


## [centre, length along the lane, width] of the three bridge decks (top 0, 0.8 thick).
static func _bridges() -> Array:
	return [
		[Vector2(-295, -295), 60.0, 24.0],
		[Vector2.ZERO, 64.0, 18.0],
		[Vector2(295, 295), 60.0, 24.0],
	]


static func _on_bridge(p: Vector2) -> bool:
	var along := Vector2(R2, -R2)
	for b in _bridges():
		var q: Vector2 = p - b[0]
		if absf(q.dot(along)) <= b[1] * 0.5 and absf(q.dot(Vector2(R2, R2))) <= b[2] * 0.5:
			return true
	return false


# =============================================================================================
# terrain
# =============================================================================================

static func _build_terrain(root: Node3D) -> Dictionary:
	var n := int(HALF * 2.0 / CELL) + 1
	var h := PackedFloat32Array()
	h.resize(n * n)
	for j in n:
		var z := -HALF + j * CELL
		for i in n:
			h[j * n + i] = _base_height(-HALF + i * CELL, z)
	# hills, stamped over their footprint only
	for hl in HILLS:
		for m in 4:
			var c := _map2(hl[0], m)
			var r: float = hl[1]
			for j in range(maxi(0, int((c.y - r + HALF) / CELL)), mini(n, int((c.y + r + HALF) / CELL) + 2)):
				for i in range(maxi(0, int((c.x - r + HALF) / CELL)), mini(n, int((c.x + r + HALF) / CELL) + 2)):
					var p := Vector2(-HALF + i * CELL, -HALF + j * CELL)
					h[j * n + i] += _hill_add(p.distance_to(c), r, hl[2])
	# lane tint mask
	var lane := PackedByteArray()
	lane.resize(n * n)
	for poly in lanes():
		for k in poly.size() - 1:
			var a := poly[k]
			var b := poly[k + 1]
			var lo := a.min(b) - Vector2.ONE * LANE_HALF
			var hi := a.max(b) + Vector2.ONE * LANE_HALF
			for j in range(maxi(0, int((lo.y + HALF) / CELL)), mini(n, int((hi.y + HALF) / CELL) + 2)):
				for i in range(maxi(0, int((lo.x + HALF) / CELL)), mini(n, int((hi.x + HALF) / CELL) + 2)):
					var p := Vector2(-HALF + i * CELL, -HALF + j * CELL)
					if p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) <= LANE_HALF:
						lane[j * n + i] = 1
	# colours (sRGB) and minimap image with hill shading
	var cols := PackedColorArray()
	cols.resize(n * n)
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var light := Vector3(-0.5, 0.8, -0.35).normalized()
	var nrm := PackedVector3Array()
	nrm.resize(n * n)
	for j in n:
		for i in n:
			var y := h[j * n + i]
			var c := C_LANE if lane[j * n + i] == 1 else C_GROUND
			if y > 0.3:
				c = c.lerp(C_HILL, clampf(y / 5.0, 0.0, 1.0))
			if y < -0.2:
				c = c.lerp(C_RIVER, clampf(-y / 2.5, 0.0, 1.0))
			if y < RIVER_BED - 0.5:
				c = c.lerp(C_PIT, clampf((RIVER_BED - y) / 4.0, 0.0, 1.0))
			cols[j * n + i] = c
			var hx := h[j * n + mini(i + 1, n - 1)] - h[j * n + maxi(i - 1, 0)]
			var hz := h[mini(j + 1, n - 1) * n + i] - h[maxi(j - 1, 0) * n + i]
			var nv := Vector3(-hx, CELL * 2.0, -hz).normalized()
			nrm[j * n + i] = nv
			img.set_pixel(i, j, c * (0.72 + 0.35 * maxf(0.0, nv.dot(light))))
	var mat := ShaderMaterial.new()
	mat.shader = MovementArena.GRID_SHADER
	mat.set_shader_parameter(&"use_vertex_color", true)
	mat.set_shader_parameter(&"minor_period", 2.0)
	mat.set_shader_parameter(&"major_period", 10.0)
	mat.set_shader_parameter(&"line_color", Color(0.2, 0.22, 0.2))
	mat.set_shader_parameter(&"major_color", Color(0.15, 0.16, 0.15))
	mat.set_shader_parameter(&"line_strength", 0.35)
	var terrain := Node3D.new()
	terrain.name = "Terrain"
	root.add_child(terrain)
	var per := int((n - 1) / float(CHUNKS))
	for cj in CHUNKS:
		for ci in CHUNKS:
			_terrain_chunk(terrain, h, nrm, cols, n, ci * per, cj * per, per, mat)
	return {"image": img}


static func _terrain_chunk(parent: Node3D, h: PackedFloat32Array, nrm: PackedVector3Array, cols: PackedColorArray,
		n: int, i0: int, j0: int, per: int, mat: Material) -> void:
	var w := per + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(w * w)
	norms.resize(w * w)
	colors.resize(w * w)
	for jj in w:
		for ii in w:
			var g := (j0 + jj) * n + i0 + ii
			verts[jj * w + ii] = Vector3(-HALF + (i0 + ii) * CELL, h[g], -HALF + (j0 + jj) * CELL)
			norms[jj * w + ii] = nrm[g]
			colors[jj * w + ii] = cols[g].srgb_to_linear()
	var idx := PackedInt32Array()
	var faces := PackedVector3Array()
	for jj in per:
		for ii in per:
			var a := jj * w + ii
			var b := a + 1
			var c := a + w
			var d := c + 1
			# clockwise seen from above = front face
			idx.append_array([a, b, d, a, d, c])
			faces.append_array([verts[a], verts[b], verts[d], verts[a], verts[d], verts[c]])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var body := StaticBody3D.new()
	body.name = "Chunk_%d_%d" % [i0, j0]
	body.collision_layer = ArenaBuilder.WORLD_LAYER
	body.collision_mask = 0
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)
	parent.add_child(body)


static func _build_bounds(root: Node3D) -> void:
	var len := HALF * 2.0 + 8.0
	for s: float in [-1.0, 1.0]:
		ArenaBuilder.add_box(root, Vector3(0, 3, s * (HALF + 2.0)), Vector3(len, 30, 4), "Bound")
		ArenaBuilder.add_box(root, Vector3(s * (HALF + 2.0), 3, 0), Vector3(4, 30, len), "Bound")


# =============================================================================================
# bases, bridges, lanes
# =============================================================================================

static func _build_base(root: Node3D, ctx: Dictionary, team: int) -> void:
	var m := team * 2
	var base := Node3D.new()
	base.name = "BaseA" if team == 0 else "BaseB"
	root.add_child(base)
	var size := HALF - BASE_EDGE
	_block(base, m, Vector3(-HALF + size * 0.5, 0, HALF - size * 0.5), Vector3(size, PLATEAU_H, size), 0.0, "Plateau")
	var n := Vector2(R2, -R2)
	var bc := Vector2(-BASE_EDGE, BASE_EDGE) + n * (BASTION_OUT - 20.0)
	_block(base, m, Vector3(bc.x, 0, bc.y), Vector3(RAMP_WIDTH, PLATEAU_H, 40.0), -PI / 4.0, "Bastion")
	var run := PLATEAU_H / tan(deg_to_rad(RAMP_ANGLE))
	for r in _ramps():
		var t: Vector2 = r[0]
		var d: Vector2 = r[1]
		var bottom := _map2(t + d * run, m)
		var dm := _map2(d, m) - _map2(Vector2.ZERO, m)
		ArenaBuilder.add_ramp(base, Vector3(bottom.x, 0, bottom.y), RAMP_ANGLE, PLATEAU_H / sin(deg_to_rad(RAMP_ANGLE)),
				RAMP_WIDTH, atan2(dm.x, dm.y))
		# base guardians flank the ramp top
		var lat := Vector2(-d.y, d.x)
		for s: float in [-1.0, 1.0]:
			var p := t - d * 10.0 + lat * 16.0 * s
			_structure(base, ctx, team, &"base_guardian", _map2(p, m), Vector3(4, 8, 4), "Base Guardian")
	# climbable spots on the cliffs: 3.5 m shelves (two mantles) and a rope
	_block(base, m, Vector3(-275, 0, BASE_EDGE - 1.5), Vector3(8, 3.5, 3), 0.0, "Shelf")
	_block(base, m, Vector3(-BASE_EDGE + 1.5, 0, 275), Vector3(3, 3.5, 8), 0.0, "Shelf")
	_rope(base, _map3(Vector3(-296, PLATEAU_H + 1.5, BASE_EDGE - 0.6), m), PLATEAU_H + 1.5)
	_rope(base, _map3(Vector3(-BASE_EDGE + 0.6, PLATEAU_H + 1.5, 296), m), PLATEAU_H + 1.5)
	_structure(base, ctx, team, &"patron", _map2(Vector2(-310, 310), m), Vector3(10, 16, 10), "Patron")
	_structure(base, ctx, team, &"shrine", _map2(Vector2(-285, 262), m), Vector3(6, 10, 6), "Shrine")
	_structure(base, ctx, team, &"shrine", _map2(Vector2(-262, 285), m), Vector3(6, 10, 6), "Shrine")
	_structure(base, ctx, team, &"shop", _map2(Vector2(-348, 318), m), Vector3(3, 3, 3), "Shop")
	var sp := _map2(Vector2(-338, 338), m)
	ctx["icons"].append({"kind": &"spawn", "team": team, "pos": sp})
	_pad(base, Vector3(sp.x, PLATEAU_H, sp.y), 8.0, TEAM_COLORS[team], "")
	if team == 0:
		# practice range next to the spawn
		for x: float in [-322.0, -312.0, -302.0, -287.0, -272.0]:
			ctx["dummies"].append([Vector3(x, PLATEAU_H, 352.0), 0.0, 800.0])


static func _build_bridges(root: Node3D) -> void:
	var along := Vector2(R2, -R2)
	var across := Vector2(R2, R2)
	for b in _bridges():
		var c: Vector2 = b[0]
		var length: float = b[1]
		var width: float = b[2]
		ArenaBuilder.add_box(root, Vector3(c.x, -0.4, c.y), Vector3(width, 0.8, length), "Bridge", -PI / 4.0)
		# pillars down to the river bed / pit floor
		for sa: float in [-1.0, 1.0]:
			for sb: float in [-1.0, 1.0]:
				var p := c + along * sa * length * 0.3 + across * sb * (width * 0.5 - 2.0)
				var bottom := terrain_height(p.x, p.y) - 0.5
				var tall := -0.8 - bottom
				if tall > 0.3:
					ArenaBuilder.add_box(root, Vector3(p.x, bottom + tall * 0.5, p.y), Vector3(1.2, tall, 1.2), "Pillar")


static func _build_lanes(root: Node3D, ctx: Dictionary) -> void:
	var lp := lanes()
	var names := ["Top", "Mid", "Bot"]
	# team A's structure distances from its ramp bottom; team B mirrors team A (point symmetry)
	var walker := [160.0, 90.0, 160.0]
	var guardian := [330.0, 200.0, 380.0]
	for li in 3:
		var poly := lp[li]
		var node := Node3D.new()
		node.name = names[li] + "Lane"
		root.add_child(node)
		for team in 2:
			# team B's lane li is the rotation of team A's lane 2 - li
			var src := lp[li] if team == 0 else lp[2 - li]
			var m := team * 2
			var wp := _map2(_lane_point(src, walker[li if team == 0 else 2 - li]), m)
			var gp := _map2(_lane_point(src, guardian[li if team == 0 else 2 - li]), m)
			_structure(node, ctx, team, &"walker", wp, Vector3(8, 14, 8), "Walker")
			_structure(node, ctx, team, &"guardian", gp, Vector3(4, 10, 4), "Guardian")
			# side shop towards the map centre, beside the guardian
			var tan_v := _lane_tangent(poly, gp)
			var lat := Vector2(-tan_v.y, tan_v.x)
			if lat.dot(-gp) < 0.0:
				lat = -lat
			_structure(node, ctx, team, &"shop", gp + lat * 24.0, Vector3(3, 3, 3), "Shop")
		# team ziplines on either side of the lane; mid is the slower inner line
		var off := MID_RAIL_OFF if li == 1 else SIDE_RAIL_OFF
		for s: float in [1.0, -1.0]:
			_lane_rail(node, ctx, poly, off * s, Zipline.Lane.INNER if li == 1 else Zipline.Lane.OUTER)


## Point `dist` metres along a lane from team A's ramp bottom (vertex 2).
static func _lane_point(poly: PackedVector2Array, dist: float) -> Vector2:
	var left := dist
	for k in range(2, poly.size() - 1):
		var seg := poly[k].distance_to(poly[k + 1])
		if left <= seg:
			return poly[k].lerp(poly[k + 1], left / seg)
		left -= seg
	return poly[poly.size() - 1]


static func _lane_tangent(poly: PackedVector2Array, p: Vector2) -> Vector2:
	var best := INF
	var t := Vector2.RIGHT
	for k in poly.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(p, poly[k], poly[k + 1])
		if p.distance_to(q) < best:
			best = p.distance_to(q)
			t = (poly[k + 1] - poly[k]).normalized()
	return t


## Zipline along a lane, `off` metres to its left, RAIL_HEIGHT above the lane surface.
static func _lane_rail(parent: Node3D, ctx: Dictionary, poly: PackedVector2Array, off: float, lane: Zipline.Lane) -> void:
	var pts := PackedVector3Array()
	for k in poly.size() - 1:
		var a := poly[k]
		var b := poly[k + 1]
		var dir := (b - a).normalized()
		var nrm := Vector2(-dir.y, dir.x)
		var steps := maxi(1, ceili(a.distance_to(b) / RAIL_STEP))
		for s in steps:
			var c := a.lerp(b, float(s) / steps)
			var o := nrm
			if s == 0 and k > 0:
				# miter at the corner
				var pd := (a - poly[k - 1]).normalized()
				var pn := Vector2(-pd.y, pd.x)
				o = (pn + nrm).normalized()
				o /= maxf(0.5, o.dot(nrm))
			var p := c + o * off
			pts.append(Vector3(p.x, ground_y(c.x, c.y) + RAIL_HEIGHT, p.y))
	var last := poly[poly.size() - 1]
	var ld := (last - poly[poly.size() - 2]).normalized()
	var lpnt := last + Vector2(-ld.y, ld.x) * off
	pts.append(Vector3(lpnt.x, ground_y(last.x, last.y) + RAIL_HEIGHT, lpnt.y))
	_zipline(parent, ctx, pts, lane, 18.0)


static func _zipline(parent: Node3D, ctx: Dictionary, pts: PackedVector3Array, lane: Zipline.Lane, speed: float) -> void:
	var z := Zipline.new()
	z.name = "Zipline"
	z.lane = lane
	z.lane_speed = speed
	z.use_points = true
	var c := Curve3D.new()
	for p in pts:
		c.add_point(p)
	z.curve = c
	parent.add_child(z)
	for i in pts.size() - 1:
		ctx["cables"].append([pts[i], pts[i + 1]])
	var since := 0.0
	for i in pts.size():
		if i > 0:
			since += pts[i].distance_to(pts[i - 1])
		if i == 0 or i == pts.size() - 1 or since >= 36.0:
			since = 0.0
			var g := ground_y(pts[i].x, pts[i].z)
			ctx["posts"].append([Vector3(pts[i].x, g, pts[i].z), pts[i].y - g])


# =============================================================================================
# jungle
# =============================================================================================

static func _build_jungle(root: Node3D, ctx: Dictionary, m: int) -> void:
	var node := Node3D.new()
	node.name = "Jungle%d" % m
	root.add_child(node)
	for b in BLOCKS:
		_block(node, m, b[0], b[1], b[2], "Block")
	for r in ROPES:
		_rope(node, _map3(r[0], m), r[1])
	var line := PackedVector3Array()
	for p in JUNGLE_LINE:
		line.append(_map3(p, m))
	_zipline(node, ctx, line, Zipline.Lane.CUSTOM, JUNGLE_LINE_SPEED)
	for c in CAMPS:
		var p := _map2(c[0], m)
		var tier: int = c[1]
		var g := ground_y(p.x, p.y)
		ctx["icons"].append({"kind": [&"camp_small", &"camp_medium", &"camp_large"][tier], "team": -1, "pos": p})
		_pad(node, Vector3(p.x, g, p.y), CAMP_RADIUS[tier], Color(0.85, 0.75, 0.35), CAMP_NAMES[tier])
		var units: int = CAMP_UNITS[tier]
		for u in units:
			var a := TAU * u / units + 0.6
			var q := p + Vector2(cos(a), sin(a)) * (0.0 if units == 1 else 3.0)
			ctx["dummies"].append([Vector3(q.x, ground_y(q.x, q.y), q.y), a, 600.0 + 300.0 * tier])
	if m == 0 or m == 2:
		var sp := _map2(SECRET_SHOP, m)
		ctx["icons"].append({"kind": &"secret_shop", "team": -1, "pos": sp})
		_kiosk(node, Vector3(sp.x, ground_y(sp.x, sp.y), sp.y), Color(0.9, 0.75, 0.25), "Secret Shop")


## Seeded cover blocks over team A's half (mirrored for team B): crates, low walls and ledges at
## crouch, mantle and rooftop heights, kept off lanes, the river, bases and authored features.
static func _scatter(root: Node3D, ctx: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7351
	var node := Node3D.new()
	node.name = "Cover"
	root.add_child(node)
	var lp := lanes()
	var placed: Array = []
	var heights := [1.1, 2.4, 2.4, 3.6, 3.6, 5.0]
	var tries := 0
	while placed.size() < 150 and tries < 6000:
		tries += 1
		var p := Vector2(rng.randf_range(-HALF + 6, HALF - 6), rng.randf_range(-HALF + 6, HALF - 6))
		var size := Vector3(rng.randf_range(2.0, 7.0), heights[rng.randi() % heights.size()], rng.randf_range(2.0, 7.0))
		var rad := Vector2(size.x, size.z).length() * 0.5
		if (p.x - p.y) * R2 > -(RIVER_HALF + RIVER_BANK + MEANDER + 4.0 + rad):
			continue
		if _in_plateau(p + Vector2(-rad - 8, rad + 8)) or _in_plateau(p) or _in_plateau(p + Vector2(0, rad + 8)) or _in_plateau(p + Vector2(-rad - 8, 0)):
			continue
		if _ramp_y(p) >= 0.0:
			continue
		var ok := true
		for poly in lp:
			for k in poly.size() - 1:
				if p.distance_to(Geometry2D.get_closest_point_to_segment(p, poly[k], poly[k + 1])) < LANE_HALF + 3.0 + rad:
					ok = false
					break
			if not ok:
				break
		if not ok:
			continue
		for k in ctx["keep"]:
			if p.distance_to(k[0]) < k[1] + rad:
				ok = false
				break
		for q in placed:
			if p.distance_to(q[0]) < q[1] + rad + 4.0:
				ok = false
				break
		if not ok or absf(terrain_height(p.x, p.y)) > 0.05:
			continue
		# keep the block off hills: all corners flat
		for cx: float in [-1.0, 1.0]:
			for cz: float in [-1.0, 1.0]:
				if absf(terrain_height(p.x + cx * rad, p.y + cz * rad)) > 0.05:
					ok = false
		if not ok:
			continue
		placed.append([p, rad])
		var yaw := 0.0 if rng.randf() < 0.6 else rng.randf_range(0.0, PI)
		for m: int in [0, 2]:
			_block(node, m, Vector3(p.x, 0, p.y), size, yaw, "Cover")


# =============================================================================================
# pieces
# =============================================================================================

## Greybox block standing on y = feet.y (team A frame, mapped by `mode`).
static func _block(parent: Node3D, mode: int, feet: Vector3, size: Vector3, yaw: float, name: String) -> void:
	var p := _map3(feet, mode)
	ArenaBuilder.add_box(parent, p + Vector3.UP * size.y * 0.5, size, name, _map_yaw(yaw, mode))


static func _rope(parent: Node3D, top: Vector3, length: float) -> void:
	ArenaBuilder.add_rope(parent, top, length)
	var vis := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, length, 0.06)
	mesh.material = _flat(Color(0.55, 0.4, 0.2))
	vis.mesh = mesh
	vis.position = top + Vector3.DOWN * length * 0.5
	parent.add_child(vis)


## Team-coloured solid structure with a floating name.
static func _structure(parent: Node3D, ctx: Dictionary, team: int, kind: StringName, p: Vector2, size: Vector3, label: String) -> void:
	var g := ground_y(p.x, p.y)
	var body := ArenaBuilder._new_body(label.replace(" ", ""))
	body.position = Vector3(p.x, g + size.y * 0.5, p.y)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var col := TEAM_COLORS[team] if team >= 0 else Color(0.9, 0.75, 0.25)
	if kind == &"shop":
		col = col.lerp(Color(0.9, 0.75, 0.25), 0.6)
	mesh.material = _lit(col)
	mi.mesh = mesh
	body.add_child(mi)
	parent.add_child(body)
	_label(parent, label, Vector3(p.x, g + size.y + 1.5, p.y))
	ctx["icons"].append({"kind": kind, "team": team, "pos": p})


static func _kiosk(parent: Node3D, feet: Vector3, col: Color, label: String) -> void:
	var body := ArenaBuilder._new_body("Kiosk")
	body.position = feet + Vector3.UP * 1.5
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3, 3, 3)
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(3, 3, 3)
	mesh.material = _lit(col)
	mi.mesh = mesh
	body.add_child(mi)
	parent.add_child(body)
	_label(parent, label, feet + Vector3.UP * 4.5)


## Flat coloured disc on the ground (no collision).
static func _pad(parent: Node3D, feet: Vector3, radius: float, col: Color, label: String) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.06
	var mat := _flat(Color(col, 0.35))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = feet + Vector3.UP * 0.04
	parent.add_child(mi)
	if label != "":
		_label(parent, label, feet + Vector3.UP * 3.0)


static func _label(parent: Node3D, text: String, pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = 0.02
	l.outline_size = 12
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	l.visibility_range_end = 120.0
	parent.add_child(l)


## Zipline cables and posts as two MultiMeshes (hundreds of segments, two draw calls).
static func _build_visual_batches(root: Node3D, ctx: Dictionary) -> void:
	var cables: Array = ctx["cables"]
	var cm := MultiMesh.new()
	cm.transform_format = MultiMesh.TRANSFORM_3D
	var cable := BoxMesh.new()
	cable.size = Vector3(0.06, 0.06, 1.0)
	cable.material = _flat(Color(0.15, 0.15, 0.17))
	cm.mesh = cable
	cm.instance_count = cables.size()
	for i in cables.size():
		var a: Vector3 = cables[i][0]
		var b: Vector3 = cables[i][1]
		var basis := Basis.looking_at((b - a).normalized(), Vector3.UP) * Basis.from_scale(Vector3(1, 1, a.distance_to(b)))
		cm.set_instance_transform(i, Transform3D(basis, (a + b) * 0.5))
	var cmi := MultiMeshInstance3D.new()
	cmi.name = "ZiplineCables"
	cmi.multimesh = cm
	cmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(cmi)
	var posts: Array = ctx["posts"]
	var pm := MultiMesh.new()
	pm.transform_format = MultiMesh.TRANSFORM_3D
	var post := BoxMesh.new()
	post.size = Vector3(0.25, 1.0, 0.25)
	post.material = _lit(Color(0.3, 0.3, 0.34))
	pm.mesh = post
	pm.instance_count = posts.size()
	for i in posts.size():
		var feet: Vector3 = posts[i][0]
		var tall: float = posts[i][1]
		pm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(1, tall, 1)), feet + Vector3.UP * tall * 0.5))
	var pmi := MultiMeshInstance3D.new()
	pmi.name = "ZiplinePosts"
	pmi.multimesh = pm
	root.add_child(pmi)


static func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func _lit(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m
