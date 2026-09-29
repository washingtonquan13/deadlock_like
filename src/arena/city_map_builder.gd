class_name CityMapBuilder
extends RefCounted
## "The Burrows": 5v5 three-lane city map (docs/design/city_map.md). All static; built by
## ArenaBuilder.build(root, &"city").
##
## A 720 m square of city blocks laid out in the Dota mould rather than a mirrored one. Team A
## holds the south-west corner, team B the north-east.
## - Top lane is a subway. It drops 10 m below the street outside each base and runs
##   underground, with light wells, open-cut stations and stairwells up into the jungle.
## - Bottom lane is a street-level avenue between tower rows, with an elevated rail deck.
## - Mid is a diagonal boulevard cutting the street grid.
## - A sunken canal crosses the other diagonal as the river. It drains into the subway at the
##   north-west corner and rises to the street at the south-east corner.
## - The boss lair is an underground chamber off the canal's upper reach, tied to the subway
##   by a sewer.
## - Each team has a main jungle between mid and its safe lane (A: bottom, B: top) and a
##   smaller triangle on its offlane side. Camps sit in plazas; buildings come from a seeded
##   lot generator, so the two halves differ.
##
## Coordinates: meters, +Y up, x east, -Z north (minimap up). River frame: s = (x + z) / sqrt 2
## runs along the canal from north-west to south-east, u = (x - z) / sqrt 2 across it (team A
## side is u < 0). Heights: street 0, canal bed -3.5, underground floors -10, base plateaus +7.

const HALF := 360.0
const CELL := 2.0
const CHUNKS := 8
const R2 := 0.70710678
const INNER := 334.0                   # grid lots stay inside +-INNER, edge rows fill the rest

const PLATEAU_H := 7.0
const BASE_EDGE := 235.0               # plateau covers x <= -235, z >= 235 (team A frame)
const BASTION_OUT := 10.0
const RAMP_ANGLE := 16.0
const RAMP_WIDTH := 26.0
const LANE_HALF := 14.0
const OUTER_LANE := 320.0
const MID_BAND := 36.0                 # no lots this close to the boulevard (plazas, flatirons)

const UNDER_Y := -10.0
const SUB_HALF := 10.0
const WALL := 2.0                      # channel walls: floor to street over one terrain cell
const ROOF_BELOW := -5.0               # channel floors deeper than this get a roof slab
const CANAL_Y := -3.5
const CANAL_HALF := 10.0
const SEWER_HALF := 4.0
const STAIR_HALF := 3.5

const RAIL_HEIGHT := 3.0               # above the lane surface; a standing jump reaches it
const RAIL_STEP := 6.0
const SIDE_RAIL_OFF := 7.0
const MID_RAIL_OFF := 6.0

const AVENUES := [-275.0, -205.0, -135.0, -65.0, 5.0, 75.0, 145.0, 215.0, 285.0]
const AVENUE_HALF := 6.0
const STREET_HALF := 5.0

const EL_OFF := 342.0                  # elevated deck centreline, outside the bottom lane
const EL_H := 7.0
const EL_W := 8.0
const EL_HALF_LEN := 150.0

const M_BLOCK := 1
const M_MID := 2

const TEAM_COLORS: Array[Color] = [Color("3cc6d0"), Color("f0913a")]
const C_PLAZA := Color(0.62, 0.61, 0.58)
const C_STREET := Color(0.40, 0.41, 0.44)
const C_LANE := Color(0.70, 0.63, 0.48)
const C_WATER := Color(0.30, 0.45, 0.60)
const C_UNDER := Color(0.27, 0.25, 0.33)
const C_PARK := Color(0.45, 0.58, 0.40)

# ---------------------------------------------------------------------------------------------
# authored content
# ---------------------------------------------------------------------------------------------

## [position, tier 0 small / 1 medium / 2 large]
const CAMPS := [
	# team A main jungle (between mid and the bottom lane)
	[Vector2(-100, 190), 0], [Vector2(-10, 150), 1], [Vector2(80, 230), 2], [Vector2(150, 260), 1], [Vector2(20, 60), 0],
	# team A triangle (top side, by the subway and the lair)
	[Vector2(-250, 60), 2], [Vector2(-150, -20), 1], [Vector2(-250, -180), 0],
	# team B main jungle (between mid and the subway)
	[Vector2(40, -240), 2], [Vector2(-100, -230), 1], [Vector2(140, -230), 0], [Vector2(-20, -140), 1], [Vector2(-150, -270), 0],
	# team B triangle (bottom side)
	[Vector2(250, -60), 2], [Vector2(130, 20), 1], [Vector2(230, 150), 0],
]
const CAMP_NAMES := ["small camp", "medium camp", "large camp"]
const CAMP_UNITS := [1, 2, 3]
const CAMP_RADIUS := [6.0, 8.0, 10.0]
## Rooftop zipline towers, in pairs: [centre, height]. Each has a rope on the face toward its partner.
const TOWERS := [
	[Vector2(-60, 230), 16.0], [Vector2(110, 190), 20.0],
	[Vector2(-265, -45), 14.0], [Vector2(-170, 50), 18.0],
	[Vector2(-120, -200), 18.0], [Vector2(90, -190), 16.0],
	[Vector2(200, -120), 16.0], [Vector2(190, 110), 20.0],
]
const TOWER_SIZE := 12.0
const TOWER_LINE_SPEED := 16.0
const SECRET_SHOPS := [Vector2(-30, 172), Vector2(60, -150)]

## Subway roof openings, as arc length from team A's portal: light wells, two open-cut stations,
## and the open north-west corner where the canal drains in.
const SUBWAY_WELLS := [[120.0, 132.0], [230.0, 262.0], [360.0, 372.0], [470.0, 562.0], [640.0, 652.0], [760.0, 792.0], [880.0, 892.0]]
const STATIONS := [[230.0, 262.0], [760.0, 792.0]]
## Stairwells from the subway up into the jungle: z on the west leg, x on the north leg.
const WEST_EXITS := [120.0, -10.0, -200.0]
const NORTH_EXITS := [-190.0, 100.0]
## Ramps out of the canal: [s, side] (side -1 = team A bank).
const CANAL_RAMPS := [[-330.0, -1.0], [-60.0, 1.0], [60.0, -1.0], [330.0, 1.0]]
const FOOTBRIDGES := [-110.0, 150.0, 260.0]
const LAIR_S := -215.0
const LAIR_BACK := 52.0                # lair centre, metres from the canal centreline (team A side)
const POWERUPS := [-300.0, 300.0]

static var _chan_cache: Array = []


## Lane centerlines from team A's base to team B's (xz). Index 1 is A's ramp top, 2 its bottom.
static func lanes() -> Array[PackedVector2Array]:
	var run := PLATEAU_H / tan(deg_to_rad(RAMP_ANGLE))
	var d := Vector2(R2, -R2)
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


static func meander(s: float) -> float:
	return 12.0 * sin(PI * s / 417.0) + 5.0 * sin(TAU * s / 417.0)


## River frame to world xz.
static func su(s: float, u: float) -> Vector2:
	return Vector2((s + u) * R2, (s - u) * R2)


static func _su3(s: float, u: float, y: float) -> Vector3:
	var p := su(s, u)
	return Vector3(p.x, y, p.y)


static func _streets() -> Array:
	var out: Array = []
	var z := -300.0
	while z <= 300.0:
		out.append(z)
		z += 40.0
	return out


# =============================================================================================
# build
# =============================================================================================

static func build(root: Node3D, out: Dictionary) -> void:
	var ctx := {"icons": [], "dummies": [], "cables": [], "posts": [], "lights": [], "keep": [], "rects": []}
	var structs := _lane_structures()
	for s: Dictionary in structs:
		ctx["keep"].append([s["pos"], 8.0])
	for c in CAMPS:
		ctx["keep"].append([c[0], CAMP_RADIUS[c[1]] + 8.0])
	for t in TOWERS:
		ctx["keep"].append([t[0], TOWER_SIZE * 0.5 + 4.0])
	for sp: Vector2 in SECRET_SHOPS:
		ctx["keep"].append([sp, 8.0])
	ctx["rects"].append(Rect2(-EL_HALF_LEN - 30.0, EL_OFF - 6.0, EL_HALF_LEN * 2.0 + 60.0, 11.0))
	ctx["rects"].append(Rect2(EL_OFF - 6.0, -EL_HALF_LEN - 30.0, 11.0, EL_HALF_LEN * 2.0 + 60.0))
	var terrain := _build_terrain(root, ctx)
	_build_bounds(root)
	for team in 2:
		_build_base(root, ctx, team)
	_build_bridges(root)
	_build_lanes(root, ctx, structs)
	_build_underground(root, ctx, structs)
	_build_el(root)
	_build_jungle(root, ctx)
	_build_city(root, terrain["mask"])
	_build_visual_batches(root, ctx)
	# boss lair and powerups
	var lair := su(LAIR_S, meander(LAIR_S) - LAIR_BACK)
	ctx["icons"].append({"kind": &"boss", "team": -1, "pos": lair})
	ctx["dummies"].append([Vector3(lair.x, UNDER_Y, lair.y), PI * 0.75, 6000.0])
	_pad(root, Vector3(lair.x, UNDER_Y, lair.y), 8.0, Color(0.6, 0.35, 0.8), "Boss (placeholder)")
	for s: float in POWERUPS:
		var p := su(s, meander(s))
		ctx["icons"].append({"kind": &"powerup", "team": -1, "pos": p})
		_pad(root, Vector3(p.x, CANAL_Y, p.y), 3.0, Color(0.3, 0.9, 0.9), "Powerup")
	# spawn and teleport points (F4 cycles them, F8 goes to the first)
	var spawn := Vector3(-338.0, PLATEAU_H, 338.0)
	out["spawn"] = spawn
	out["spawn_yaw"] = -PI / 4.0
	var sub: PackedVector3Array = channels()[0]["pts"]
	var marks := {
		"01_spawn_a": spawn,
		"02_subway_portal_a": _v3(Vector2(-OUTER_LANE, 150)),
		"03_subway_station": _v3(_poly_at(sub, 246.0)[0]),
		"04_canal_drain": _v3(su(-380.0, meander(-380.0))),
		"05_boss_lair": _v3(lair + Vector2(10, 10)),
		"06_mid_bridge": _v3(Vector2(4, -4)),
		"07_jungle_a_main": _v3(CAMPS[1][0] + Vector2(12, 0)),
		"08_jungle_a_triangle": _v3(CAMPS[6][0] + Vector2(12, 0)),
		"09_jungle_b_main": _v3(CAMPS[11][0] + Vector2(12, 0)),
		"10_jungle_b_triangle": _v3(CAMPS[14][0] + Vector2(12, 0)),
		"11_bot_elevated": Vector3(0.0, EL_H, EL_OFF),
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
		"name": "The Burrows",
	}


# =============================================================================================
# team frame (bases are point-symmetric; the rest of the map is not)
# =============================================================================================

static func _map2(p: Vector2, team: int) -> Vector2:
	return p if team == 0 else -p


static func _map3(p: Vector3, team: int) -> Vector3:
	return p if team == 0 else Vector3(-p.x, p.y, -p.z)


static func _v3(p: Vector2) -> Vector3:
	return Vector3(p.x, ground_y(p.x, p.y), p.y)


# =============================================================================================
# channels: canal, subway, sewers, stairwells, lair
# =============================================================================================

## Everything cut below the street, as polylines of (x, floor y, z) with a flat floor `half`
## wide each side and WALL-wide walls up to the street. Sections deeper than ROOF_BELOW get
## roof slabs (when "roof"), except the arc-length ranges in "open". Index 0 is the subway.
static func channels() -> Array:
	if not _chan_cache.is_empty():
		return _chan_cache
	var ch: Array = []
	var zb := BASE_EDGE - PLATEAU_H / tan(deg_to_rad(RAMP_ANGLE))
	var w := -OUTER_LANE
	ch.append(_chan("Subway", PackedVector3Array([
		Vector3(w, 0, zb), Vector3(w, 0, zb - 4.6), Vector3(w, UNDER_Y, zb - 40.6), Vector3(w, UNDER_Y, -270),
		Vector3(-270, UNDER_Y, w), Vector3(zb - 40.6, UNDER_Y, w), Vector3(zb - 4.6, 0, w), Vector3(zb, 0, w)]),
		SUB_HALF, true, SUBWAY_WELLS))
	for z: float in WEST_EXITS:
		ch.append(_stair(Vector2(w + SUB_HALF - 2.0, z), Vector2(1, 0)))
	for x: float in NORTH_EXITS:
		ch.append(_stair(Vector2(x, w + SUB_HALF - 2.0), Vector2(0, 1)))
	# canal: from inside the subway's corner, up a spillway, along the diagonal, up to the street
	var ss: Array[float] = [-418.0, -407.0, -372.0]
	var s := -360.0
	while s < 372.0:
		ss.append(s)
		s += 12.0
	ss.append(375.0)
	ss.append(400.0)
	var canal := PackedVector3Array()
	for v in ss:
		canal.append(_su3(v, meander(v), _canal_y(v)))
	ch.append(_chan("Canal", canal, CANAL_HALF, false, []))
	for r in CANAL_RAMPS:
		var rs: float = r[0]
		var side: float = r[1]
		var m := meander(rs)
		ch.append(_chan("CanalRamp", PackedVector3Array([_su3(rs, m + side * 6.0, CANAL_Y), _su3(rs, m + side * 30.0, 0.0)]), 3.0, false, []))
	# boss lair: a chamber off the canal's team A bank with a skylight, an entrance from the canal
	# bed, and a sewer west to the subway
	var lm := meander(LAIR_S)
	var lu := lm - LAIR_BACK
	ch.append(_chan("Lair", PackedVector3Array([_su3(LAIR_S - 17.0, lu, UNDER_Y), _su3(LAIR_S + 17.0, lu, UNDER_Y)]), 16.0, true, [[14.0, 20.0]]))
	ch.append(_chan("LairEntrance", PackedVector3Array([_su3(LAIR_S, lm - 6.0, CANAL_Y), _su3(LAIR_S, lm - 32.0, UNDER_Y), _su3(LAIR_S, lm - 40.0, UNDER_Y)]), 5.0, true, []))
	var lc := su(LAIR_S, lu)
	ch.append(_chan("LairSewer", PackedVector3Array([Vector3(lc.x, UNDER_Y, lc.y), Vector3(w + SUB_HALF - 2.0, UNDER_Y, lc.y)]), SEWER_HALF, true, [[60.0, 66.0]]))
	# team A main jungle sewer: a stairwell by the bottom lane to the canal bed
	ch.append(_chan("SewerA", PackedVector3Array([Vector3(-92, 0, 200), Vector3(-64, UNDER_Y, 200), Vector3(60, UNDER_Y, 200),
		Vector3(60, UNDER_Y, 98), Vector3(60, CANAL_Y, 72), Vector3(60, CANAL_Y, 48)]), SEWER_HALF, true, [[80.0, 86.0]]))
	# team B main jungle sewer: from the subway south to a stairwell
	ch.append(_chan("SewerB", PackedVector3Array([Vector3(-40, UNDER_Y, w + SUB_HALF - 2.0), Vector3(-40, UNDER_Y, -232),
		Vector3(-40, 0, -204)]), SEWER_HALF, true, []))
	_chan_cache = ch
	return ch


static func _chan(name: String, pts: PackedVector3Array, half: float, roof: bool, open: Array) -> Dictionary:
	var box := Rect2(Vector2(pts[0].x, pts[0].z), Vector2.ZERO)
	for p in pts:
		box = box.expand(Vector2(p.x, p.z))
	return {"name": name, "pts": pts, "half": half, "roof": roof, "open": open, "box": box.grow(half + WALL)}


## Stairwell out of the subway: 6 m level, then 28 m up to the street (about 20 degrees).
static func _stair(start: Vector2, dir: Vector2) -> Dictionary:
	var a := start + dir * 6.0
	var b := start + dir * 34.0
	return _chan("Stairwell", PackedVector3Array([Vector3(start.x, UNDER_Y, start.y), Vector3(a.x, UNDER_Y, a.y), Vector3(b.x, 0, b.y)]), STAIR_HALF, true, [])


static func _canal_y(s: float) -> float:
	if s <= -407.0:
		return UNDER_Y
	if s < -372.0:
		return lerpf(UNDER_Y, CANAL_Y, (s + 407.0) / 35.0)
	if s <= 375.0:
		return CANAL_Y
	return lerpf(CANAL_Y, 0.0, clampf((s - 375.0) / 25.0, 0.0, 1.0))


static func _seg_dist(a: Vector3, b: Vector3, p: Vector2) -> Vector2:
	var a2 := Vector2(a.x, a.z)
	var ab := Vector2(b.x, b.z) - a2
	var t := clampf((p - a2).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return Vector2(p.distance_to(a2 + ab * t), t)


## Channel segment surface height at p (0 outside it).
static func _seg_h(a: Vector3, b: Vector3, half: float, p: Vector2) -> float:
	var dt := _seg_dist(a, b, p)
	if dt.x >= half + WALL:
		return 0.0
	var y := lerpf(a.y, b.y, dt.y)
	return y if dt.x <= half else lerpf(y, 0.0, (dt.x - half) / WALL)


## Terrain height at (x, z), the same function the terrain mesh is sampled from.
static func terrain_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var h := 0.0
	for c: Dictionary in channels():
		if not (c["box"] as Rect2).has_point(p):
			continue
		var pts: PackedVector3Array = c["pts"]
		for k in pts.size() - 1:
			h = minf(h, _seg_h(pts[k], pts[k + 1], c["half"], p))
	return h


## Walkable surface at (x, z): plateaus, ramps, bridge decks, else terrain. Roofs and buildings
## are ignored (underground points get the floor).
static func ground_y(x: float, z: float) -> float:
	for team in 2:
		var q := _map2(Vector2(x, z), team)
		if _in_plateau(q):
			return PLATEAU_H
		var ry := _ramp_y(q)
		if ry >= 0.0:
			return ry
	var t := terrain_height(x, z)
	if t < 0.0 and _on_bridge(Vector2(x, z)):
		return 0.0
	return t


## Point `s` metres along a polyline (xz of a Vector3 list): [position, direction].
static func _poly_at(pts: PackedVector3Array, s: float) -> Array:
	var left := s
	for k in pts.size() - 1:
		var a := Vector2(pts[k].x, pts[k].z)
		var b := Vector2(pts[k + 1].x, pts[k + 1].z)
		var len := a.distance_to(b)
		if left <= len or k == pts.size() - 2:
			return [a.lerp(b, clampf(left / len, 0.0, 1.0)), (b - a) / len]
		left -= len
	return [Vector2.ZERO, Vector2.RIGHT]


## Arc length of the point on a polyline closest to p.
static func _poly_s(pts: PackedVector3Array, p: Vector2) -> float:
	var best := INF
	var out := 0.0
	var s0 := 0.0
	for k in pts.size() - 1:
		var dt := _seg_dist(pts[k], pts[k + 1], p)
		var len := Vector2(pts[k].x, pts[k].z).distance_to(Vector2(pts[k + 1].x, pts[k + 1].z))
		if dt.x < best:
			best = dt.x
			out = s0 + dt.y * len
		s0 += len
	return out


# =============================================================================================
# bases
# =============================================================================================

static func _in_plateau(q: Vector2) -> bool:
	if q.x <= -BASE_EDGE and q.y >= BASE_EDGE:
		return true
	# bastion: 26 m wide, 40 m deep, its outer face 10 m past the corner along the diagonal
	var c := Vector2(-BASE_EDGE, BASE_EDGE)
	var a := (q - c).dot(Vector2(R2, -R2))
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


static func _near_base(p: Vector2, margin: float) -> bool:
	for team in 2:
		var q := _map2(p, team)
		if q.x > -150.0 or q.y < 150.0:
			continue
		for o: Vector2 in [Vector2.ZERO, Vector2(margin, 0), Vector2(-margin, 0), Vector2(0, margin), Vector2(0, -margin),
				Vector2(margin, margin) * R2, Vector2(-margin, margin) * R2, Vector2(margin, -margin) * R2, Vector2(-margin, -margin) * R2]:
			if _in_plateau(q + o) or _ramp_y(q + o) >= 0.0:
				return true
	return false


static func _build_base(root: Node3D, ctx: Dictionary, team: int) -> void:
	var base := Node3D.new()
	base.name = "BaseA" if team == 0 else "BaseB"
	root.add_child(base)
	var size := HALF - BASE_EDGE
	_block(base, team, Vector3(-HALF + size * 0.5, 0, HALF - size * 0.5), Vector3(size, PLATEAU_H, size), 0.0, "Plateau")
	var n := Vector2(R2, -R2)
	var bc := Vector2(-BASE_EDGE, BASE_EDGE) + n * (BASTION_OUT - 20.0)
	_block(base, team, Vector3(bc.x, 0, bc.y), Vector3(RAMP_WIDTH, PLATEAU_H, 40.0), -PI / 4.0, "Bastion")
	var run := PLATEAU_H / tan(deg_to_rad(RAMP_ANGLE))
	for r in _ramps():
		var t: Vector2 = r[0]
		var d: Vector2 = r[1]
		var bottom := _map2(t + d * run, team)
		var dm := _map2(d, team)
		ArenaBuilder.add_ramp(base, Vector3(bottom.x, 0, bottom.y), RAMP_ANGLE, PLATEAU_H / sin(deg_to_rad(RAMP_ANGLE)),
				RAMP_WIDTH, atan2(dm.x, dm.y))
		# base guardians flank the ramp top
		var lat := Vector2(-d.y, d.x)
		for s: float in [-1.0, 1.0]:
			var p := t - d * 10.0 + lat * 16.0 * s
			_structure(base, ctx, team, &"base_guardian", _map2(p, team), Vector3(4, 8, 4), "Base Guardian")
	# climbable spots on the podium walls: 3.5 m shelves (two mantles) and ropes
	_block(base, team, Vector3(-275, 0, BASE_EDGE - 1.5), Vector3(8, 3.5, 3), 0.0, "Shelf")
	_block(base, team, Vector3(-BASE_EDGE + 1.5, 0, 275), Vector3(3, 3.5, 8), 0.0, "Shelf")
	_rope(base, _map3(Vector3(-296, PLATEAU_H + 1.5, BASE_EDGE - 0.6), team), PLATEAU_H + 1.5)
	_rope(base, _map3(Vector3(-BASE_EDGE + 0.6, PLATEAU_H + 1.5, 296), team), PLATEAU_H + 1.5)
	_structure(base, ctx, team, &"patron", _map2(Vector2(-310, 310), team), Vector3(10, 16, 10), "Patron")
	_structure(base, ctx, team, &"shrine", _map2(Vector2(-285, 262), team), Vector3(6, 10, 6), "Shrine")
	_structure(base, ctx, team, &"shrine", _map2(Vector2(-262, 285), team), Vector3(6, 10, 6), "Shrine")
	_structure(base, ctx, team, &"shop", _map2(Vector2(-348, 318), team), Vector3(3, 3, 3), "Shop")
	var sp := _map2(Vector2(-338, 338), team)
	ctx["icons"].append({"kind": &"spawn", "team": team, "pos": sp})
	_pad(base, Vector3(sp.x, PLATEAU_H, sp.y), 8.0, TEAM_COLORS[team], "")
	if team == 0:
		# practice range next to the spawn
		for x: float in [-322.0, -312.0, -302.0, -287.0, -272.0]:
			ctx["dummies"].append([Vector3(x, PLATEAU_H, 352.0), 0.0, 800.0])


# =============================================================================================
# terrain and the lot mask
# =============================================================================================

static func _cell_range(lo: Vector2, hi: Vector2, n: int) -> Array[int]:
	return [maxi(0, floori((lo.x + HALF) / CELL)), mini(n - 1, ceili((hi.x + HALF) / CELL)),
			maxi(0, floori((lo.y + HALF) / CELL)), mini(n - 1, ceili((hi.y + HALF) / CELL))]


static func _is_street(p: Vector2) -> bool:
	if absf(p.x) > INNER or absf(p.y) > INNER:
		return false
	for a: float in AVENUES:
		if absf(p.x - a) <= AVENUE_HALF:
			return true
	for z: float in _streets():
		if absf(p.y - z) <= STREET_HALF:
			return true
	return false


## Heightfield (channels cut into a flat street level), its colours and minimap image, and the
## lot mask: M_BLOCK where nothing may be built (lanes, channels, bases, keep-clear circles and
## rects), M_MID along the boulevard.
static func _build_terrain(root: Node3D, ctx: Dictionary) -> Dictionary:
	var n := int(HALF * 2.0 / CELL) + 1
	var h := PackedFloat32Array()
	h.resize(n * n)
	var mask := PackedByteArray()
	mask.resize(n * n)
	var tint := PackedByteArray()        # 1 lane, 2 canal, 3 park
	tint.resize(n * n)
	for c: Dictionary in channels():
		var pts: PackedVector3Array = c["pts"]
		var half: float = c["half"]
		var wet: bool = c["name"] == "Canal" or c["name"] == "CanalRamp"
		for k in pts.size() - 1:
			var a := pts[k]
			var b := pts[k + 1]
			var r := half + WALL + 3.0
			var cr := _cell_range(Vector2(minf(a.x, b.x), minf(a.z, b.z)) - Vector2.ONE * r, Vector2(maxf(a.x, b.x), maxf(a.z, b.z)) + Vector2.ONE * r, n)
			for j in range(cr[2], cr[3] + 1):
				for i in range(cr[0], cr[1] + 1):
					var p := Vector2(-HALF + i * CELL, -HALF + j * CELL)
					var g := j * n + i
					var dt := _seg_dist(a, b, p)
					if dt.x >= r:
						continue
					mask[g] |= M_BLOCK
					var v := _seg_h(a, b, half, p)
					if v < h[g]:
						h[g] = v
					if wet and dt.x < half + WALL:
						tint[g] = 2
	# lanes: tint, a clear margin, and the boulevard band
	var lp := lanes()
	for li in 3:
		var poly := lp[li]
		var r := MID_BAND if li == 1 else LANE_HALF + 2.0
		for k in poly.size() - 1:
			var a := poly[k]
			var b := poly[k + 1]
			var cr := _cell_range(a.min(b) - Vector2.ONE * r, a.max(b) + Vector2.ONE * r, n)
			for j in range(cr[2], cr[3] + 1):
				for i in range(cr[0], cr[1] + 1):
					var p := Vector2(-HALF + i * CELL, -HALF + j * CELL)
					var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
					var g := j * n + i
					if d <= LANE_HALF and tint[g] == 0:
						tint[g] = 1
					if d < LANE_HALF + 2.0:
						mask[g] |= M_BLOCK
					elif d < r:
						mask[g] |= M_MID
	for kc in ctx["keep"]:
		var c: Vector2 = kc[0]
		var r: float = kc[1]
		var cr := _cell_range(c - Vector2.ONE * r, c + Vector2.ONE * r, n)
		for j in range(cr[2], cr[3] + 1):
			for i in range(cr[0], cr[1] + 1):
				if Vector2(-HALF + i * CELL, -HALF + j * CELL).distance_to(c) < r:
					mask[j * n + i] |= M_BLOCK
	for rc: Rect2 in ctx["rects"]:
		var cr := _cell_range(rc.position, rc.end, n)
		for j in range(cr[2], cr[3] + 1):
			for i in range(cr[0], cr[1] + 1):
				if rc.has_point(Vector2(-HALF + i * CELL, -HALF + j * CELL)):
					mask[j * n + i] |= M_BLOCK
	for cp in CAMPS:
		var c: Vector2 = cp[0]
		var r: float = CAMP_RADIUS[cp[1]] + 5.0
		var cr := _cell_range(c - Vector2.ONE * r, c + Vector2.ONE * r, n)
		for j in range(cr[2], cr[3] + 1):
			for i in range(cr[0], cr[1] + 1):
				if Vector2(-HALF + i * CELL, -HALF + j * CELL).distance_to(c) < r:
					tint[j * n + i] = 3
	for j in n:
		for i in n:
			var p := Vector2(-HALF + i * CELL, -HALF + j * CELL)
			if _near_base(p, 6.0):
				mask[j * n + i] |= M_BLOCK
	# colours (sRGB) and the minimap image with slope shading
	var cols := PackedColorArray()
	cols.resize(n * n)
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var light := Vector3(-0.5, 0.8, -0.35).normalized()
	var nrm := PackedVector3Array()
	nrm.resize(n * n)
	for j in n:
		for i in n:
			var g := j * n + i
			var y := h[g]
			var c := C_PLAZA
			match tint[g]:
				1:
					c = C_LANE
				2:
					c = C_WATER
				3:
					c = C_PARK
				_:
					if _is_street(Vector2(-HALF + i * CELL, -HALF + j * CELL)):
						c = C_STREET
			if y < -0.2 and tint[g] != 2:
				c = c.lerp(C_UNDER, clampf(-y / 5.0, 0.0, 1.0))
			cols[g] = c
			var hx := h[j * n + mini(i + 1, n - 1)] - h[j * n + maxi(i - 1, 0)]
			var hz := h[mini(j + 1, n - 1) * n + i] - h[maxi(j - 1, 0) * n + i]
			var nv := Vector3(-hx, CELL * 2.0, -hz).normalized()
			nrm[g] = nv
			img.set_pixel(i, j, c * (0.72 + 0.35 * maxf(0.0, nv.dot(light))))
	var mat := ShaderMaterial.new()
	mat.shader = MovementArena.GRID_SHADER
	mat.set_shader_parameter(&"use_vertex_color", true)
	mat.set_shader_parameter(&"minor_period", 2.0)
	mat.set_shader_parameter(&"major_period", 10.0)
	mat.set_shader_parameter(&"line_color", Color(0.2, 0.2, 0.22))
	mat.set_shader_parameter(&"major_color", Color(0.15, 0.15, 0.17))
	mat.set_shader_parameter(&"line_strength", 0.3)
	var terrain := Node3D.new()
	terrain.name = "Terrain"
	root.add_child(terrain)
	var per := int((n - 1) / float(CHUNKS))
	for cj in CHUNKS:
		for ci in CHUNKS:
			_terrain_chunk(terrain, h, nrm, cols, n, ci * per, cj * per, per, mat)
	return {"image": img, "mask": mask}


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
		ArenaBuilder.add_box(root, Vector3(0, 3, s * (HALF + 2.0)), Vector3(len, 30, 4), "Bound").set_meta(&"minimap", &"skip")
		ArenaBuilder.add_box(root, Vector3(s * (HALF + 2.0), 3, 0), Vector3(4, 30, len), "Bound").set_meta(&"minimap", &"skip")


# =============================================================================================
# bridges, lanes
# =============================================================================================

## [centre, length across the canal, width] of the bridge decks (top 0, 0.8 thick). All run
## along u, the boulevard's direction.
static func _bridges() -> Array:
	var out: Array = [[Vector2.ZERO, 34.0, LANE_HALF * 2.0]]
	for s: float in FOOTBRIDGES:
		out.append([su(s, meander(s)), 34.0, 6.0])
	return out


static func _on_bridge(p: Vector2) -> bool:
	for b in _bridges():
		var q: Vector2 = p - b[0]
		if absf(q.dot(Vector2(R2, -R2))) <= b[1] * 0.5 and absf(q.dot(Vector2(R2, R2))) <= b[2] * 0.5:
			return true
	return false


static func _build_bridges(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Bridges"
	root.add_child(node)
	for b in _bridges():
		var c: Vector2 = b[0]
		ArenaBuilder.add_box(node, Vector3(c.x, -0.4, c.y), Vector3(b[2], 0.8, b[1]), "Bridge", -PI / 4.0)


## Walkers, Guardians and side shops for both teams: {team, kind, pos, size, label}.
static func _lane_structures() -> Array:
	var out: Array = []
	var lp := lanes()
	# distances from the team's own ramp bottom; team B's lane li is the rotation of A's 2 - li
	var walker := [160.0, 90.0, 160.0]
	var guardian := [330.0, 200.0, 380.0]
	for li in 3:
		for team in 2:
			var wi := li if team == 0 else 2 - li
			var src := lp[wi]
			var wp := _map2(_lane_point(src, walker[wi]), team)
			var gp := _map2(_lane_point(src, guardian[wi]), team)
			out.append({"team": team, "kind": &"walker", "pos": wp, "size": Vector3(8, 14, 8), "label": "Walker"})
			out.append({"team": team, "kind": &"guardian", "pos": gp, "size": Vector3(4, 10, 4), "label": "Guardian"})
			# side shop towards the map centre beside the guardian; underground, tucked in by the rail
			var tan_v := _lane_tangent(lp[li], gp)
			var lat := Vector2(-tan_v.y, tan_v.x)
			if lat.dot(-gp) < 0.0:
				lat = -lat
			var sp := gp + lat * 24.0
			if terrain_height(gp.x, gp.y) < ROOF_BELOW:
				sp = gp + lat * 3.5 + tan_v * 6.0
			out.append({"team": team, "kind": &"shop", "pos": sp, "size": Vector3(3, 3, 3), "label": "Shop"})
	return out


static func _build_lanes(root: Node3D, ctx: Dictionary, structs: Array) -> void:
	var lp := lanes()
	var names := ["Top", "Mid", "Bot"]
	var nodes: Array[Node3D] = []
	for li in 3:
		var node := Node3D.new()
		node.name = names[li] + "Lane"
		root.add_child(node)
		nodes.append(node)
		# ziplines on either side of the lane; mid is the slower inner line
		var off := MID_RAIL_OFF if li == 1 else SIDE_RAIL_OFF
		for s: float in [1.0, -1.0]:
			_lane_rail(node, ctx, lp[li], off * s, Zipline.Lane.INNER if li == 1 else Zipline.Lane.OUTER)
	for st: Dictionary in structs:
		_structure(nodes[0], ctx, st["team"], st["kind"], st["pos"], st["size"], st["label"])


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
# underground: roofs, subway columns, station platforms, ceiling lights
# =============================================================================================

static func _build_underground(root: Node3D, ctx: Dictionary, structs: Array) -> void:
	var node := Node3D.new()
	node.name = "Underground"
	root.add_child(node)
	for c: Dictionary in channels():
		if c["roof"]:
			_roofs(node, ctx, c)
	var sub: Dictionary = channels()[0]
	var pts: PackedVector3Array = sub["pts"]
	var total := 0.0
	for k in pts.size() - 1:
		total += Vector2(pts[k].x, pts[k].z).distance_to(Vector2(pts[k + 1].x, pts[k + 1].z))
	# columns between the tracks, clear of structures and roof openings
	var busy: Array[float] = []
	for st: Dictionary in structs:
		var p: Vector2 = st["pos"]
		if terrain_height(p.x, p.y) < ROOF_BELOW:
			busy.append(_poly_s(pts, p))
	var s := 60.0
	while s < total - 60.0:
		var ok := true
		for b in busy:
			if absf(s - b) < 12.0:
				ok = false
		for o in sub["open"]:
			if s > o[0] - 2.0 and s < o[1] + 2.0:
				ok = false
		var pd := _poly_at(pts, s)
		var p: Vector2 = pd[0]
		if ok and terrain_height(p.x, p.y) <= UNDER_Y + 0.01:
			var lat := Vector2(-pd[1].y, pd[1].x)
			for side: float in [-3.5, 3.5]:
				var q := p + lat * side
				ArenaBuilder.add_box(node, Vector3(q.x, UNDER_Y + 4.5, q.y), Vector3(1.0, 9.0, 1.0), "Column").set_meta(&"minimap", &"skip")
		s += 18.0
	# station platforms along both walls (a short mantle up, and a step toward the rails)
	for st in STATIONS:
		var a: float = st[0]
		var b: float = st[1]
		var pd := _poly_at(pts, (a + b) * 0.5)
		var p: Vector2 = pd[0]
		var dir: Vector2 = pd[1]
		var lat := Vector2(-dir.y, dir.x)
		for side: float in [-1.0, 1.0]:
			var q := p + lat * side * (SUB_HALF - 1.5)
			ArenaBuilder.add_box(node, Vector3(q.x, UNDER_Y + 0.6, q.y), Vector3(3.0, 1.2, b - a), "Platform", atan2(dir.x, dir.y)).set_meta(&"minimap", &"skip")


## Roof slabs (top at street level) over a channel's deep sections, minus its open ranges,
## with a strip light every 12 m under each.
static func _roofs(parent: Node3D, ctx: Dictionary, c: Dictionary) -> void:
	var pts: PackedVector3Array = c["pts"]
	var half: float = c["half"]
	var width := (half + WALL + 1.0) * 2.0
	var s0 := 0.0
	for k in pts.size() - 1:
		var a := pts[k]
		var b := pts[k + 1]
		var a2 := Vector2(a.x, a.z)
		var b2 := Vector2(b.x, b.z)
		var len := a2.distance_to(b2)
		if a.y > ROOF_BELOW and b.y > ROOF_BELOW:
			s0 += len
			continue
		var t0 := 0.0
		var t1 := 1.0
		if a.y > ROOF_BELOW:
			t0 = (a.y - ROOF_BELOW) / (a.y - b.y)
		if b.y > ROOF_BELOW:
			t1 = (ROOF_BELOW - a.y) / (b.y - a.y)
		var runs: Array = [[s0 + t0 * len, s0 + t1 * len]]
		for o in c["open"]:
			runs = _subtract(runs, o[0], o[1])
		var dir := (b2 - a2) / len
		var yaw := atan2(dir.x, dir.y)
		for r in runs:
			var sa: float = r[0]
			var sb: float = r[1]
			if sb - sa < 0.5:
				continue
			# reaching a vertex, run on past it to close bends and the channel's rounded ends
			var ea := width * 0.5 if absf(sa - s0) < 0.01 else 0.0
			var eb := width * 0.5 if absf(sb - s0 - len) < 0.01 else 0.0
			var pa := a2 + dir * (sa - s0 - ea)
			var pb := a2 + dir * (sb - s0 + eb)
			var m := (pa + pb) * 0.5
			ArenaBuilder.add_box(parent, Vector3(m.x, -0.5, m.y), Vector3(width, 1.0, pa.distance_to(pb)), "Roof", yaw).set_meta(&"minimap", &"roof")
			var lats: Array = [-4.0, 4.0] if half >= 8.0 else [0.0]
			var l := sa + 6.0
			while l < sb - 3.0:
				var q := a2 + dir * (l - s0)
				for side: float in lats:
					var lq := q + Vector2(-dir.y, dir.x) * side
					ctx["lights"].append([Vector3(lq.x, -1.08, lq.y), yaw])
				l += 12.0
		s0 += len


## Interval list minus [a, b].
static func _subtract(runs: Array, a: float, b: float) -> Array:
	var out: Array = []
	for r in runs:
		var x: float = r[0]
		var y: float = r[1]
		if b <= x or a >= y:
			out.append([x, y])
			continue
		if a > x:
			out.append([x, a])
		if b < y:
			out.append([b, y])
	return out


# =============================================================================================
# elevated deck along the bottom lane
# =============================================================================================

static func _build_el(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Elevated"
	root.add_child(node)
	var run := EL_H / tan(deg_to_rad(RAMP_ANGLE))
	for leg in 2:
		var a := Vector2(-EL_HALF_LEN, EL_OFF) if leg == 0 else Vector2(EL_OFF, EL_HALF_LEN)
		var b := Vector2(EL_HALF_LEN, EL_OFF) if leg == 0 else Vector2(EL_OFF, -EL_HALF_LEN)
		var toward_lane := Vector2(0, -1) if leg == 0 else Vector2(-1, 0)
		var dir := (b - a).normalized()
		var len := a.distance_to(b)
		var m := (a + b) * 0.5
		ArenaBuilder.add_box(node, Vector3(m.x, EL_H - 0.4, m.y), Vector3(EL_W, 0.8, len), "ElDeck", atan2(dir.x, dir.y))
		var t := 0.0
		while t <= len:
			var p := a + dir * t
			ArenaBuilder.add_box(node, Vector3(p.x, (EL_H - 0.8) * 0.5, p.y), Vector3(1.2, EL_H - 0.8, 1.2), "ElPillar")
			t += 25.0
		for e in 2:
			var end := a if e == 0 else b
			var o := -dir if e == 0 else dir
			var bottom := end + o * run
			ArenaBuilder.add_ramp(node, Vector3(bottom.x, 0, bottom.y), RAMP_ANGLE, EL_H / sin(deg_to_rad(RAMP_ANGLE)), EL_W, atan2(o.x, o.y))
		# newsstands on the lane side: 3.5 m, then another 3.5 m mantle onto the deck
		for f: float in [0.2, 0.4, 0.6, 0.8]:
			var p := a + dir * len * f + toward_lane * (EL_W * 0.5 + 1.5)
			ArenaBuilder.add_box(node, Vector3(p.x, 1.75, p.y), Vector3(3, 3.5, 3), "Newsstand")


# =============================================================================================
# jungle: camps, rooftop zipline towers, secret shops
# =============================================================================================

static func _build_jungle(root: Node3D, ctx: Dictionary) -> void:
	var node := Node3D.new()
	node.name = "Jungle"
	root.add_child(node)
	for c in CAMPS:
		var p: Vector2 = c[0]
		var tier: int = c[1]
		var g := ground_y(p.x, p.y)
		ctx["icons"].append({"kind": [&"camp_small", &"camp_medium", &"camp_large"][tier], "team": -1, "pos": p})
		_pad(node, Vector3(p.x, g, p.y), CAMP_RADIUS[tier], Color(0.85, 0.75, 0.35), CAMP_NAMES[tier])
		var units: int = CAMP_UNITS[tier]
		for u in units:
			var a := TAU * u / units + 0.6
			var q := p + Vector2(cos(a), sin(a)) * (0.0 if units == 1 else 3.0)
			ctx["dummies"].append([Vector3(q.x, ground_y(q.x, q.y), q.y), a, 600.0 + 300.0 * tier])
	for i in range(0, TOWERS.size(), 2):
		var line := PackedVector3Array()
		for k in 2:
			var p: Vector2 = TOWERS[i + k][0]
			var hh: float = TOWERS[i + k][1]
			var other: Vector2 = TOWERS[i + 1 - k][0]
			ArenaBuilder.add_box(node, Vector3(p.x, hh * 0.5, p.y), Vector3(TOWER_SIZE, hh, TOWER_SIZE), "Tower")
			var d := other - p
			var face := Vector2(signf(d.x), 0) if absf(d.x) > absf(d.y) else Vector2(0, signf(d.y))
			var rp := p + face * (TOWER_SIZE * 0.5 + 0.6)
			_rope(node, Vector3(rp.x, hh + 0.3, rp.y), hh + 0.3)
			line.append(Vector3(p.x, hh + 2.8, p.y))
		_zipline(node, ctx, line, Zipline.Lane.CUSTOM, TOWER_LINE_SPEED)
	for sp: Vector2 in SECRET_SHOPS:
		ctx["icons"].append({"kind": &"secret_shop", "team": -1, "pos": sp})
		_kiosk(node, Vector3(sp.x, ground_y(sp.x, sp.y), sp.y), Color(0.9, 0.75, 0.25), "Secret Shop")


# =============================================================================================
# city: seeded lots on the street grid, edge rows, boulevard flatirons
# =============================================================================================

static func _intervals(centres: Array, half: float) -> Array:
	var out: Array = []
	var x := -INNER
	for c: float in centres:
		out.append([x, c - half])
		x = c + half
	out.append([x, INNER])
	return out


static func _mask_at(mask: PackedByteArray, p: Vector2) -> int:
	var n := int(HALF * 2.0 / CELL) + 1
	var i := clampi(roundi((p.x + HALF) / CELL), 0, n - 1)
	var j := clampi(roundi((p.y + HALF) / CELL), 0, n - 1)
	return mask[j * n + i]


static func _rect_free(mask: PackedByteArray, r: Rect2, bits: int) -> bool:
	var n := int(HALF * 2.0 / CELL) + 1
	var cr := _cell_range(r.position, r.end, n)
	for j in range(cr[2], cr[3] + 1):
		for i in range(cr[0], cr[1] + 1):
			if mask[j * n + i] & bits:
				return false
	return true


static func _build_city(root: Node3D, mask: PackedByteArray) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var node := Node3D.new()
	node.name = "City"
	root.add_child(node)
	for xi in _intervals(AVENUES, AVENUE_HALF):
		for zi in _intervals(_streets(), STREET_HALF):
			var x0: float = xi[0]
			var z0: float = zi[0]
			var w: float = xi[1] - x0
			var d: float = zi[1] - z0
			var nx := clampi(roundi(w / rng.randf_range(24.0, 40.0)), 1, 3)
			var nz := 2 if d > 26.0 and rng.randf() < 0.3 else 1
			for a in nx:
				for b in nz:
					_try_lot(node, rng, mask, Rect2(x0 + w * a / nx, z0 + d * b / nz, w / nx, d / nz).grow(-1.5), 2)
	# edge rows: tall facades between the side lanes and the map boundary
	var strips := [
		[Rect2(-358, -358, 20, 586), 1], [Rect2(-334, -358, 562, 20), 0],
		[Rect2(-228, 348, 586, 10), 0], [Rect2(348, -228, 10, 574), 1],
	]
	for st in strips:
		var r: Rect2 = st[0]
		var axis: int = st[1]
		var t := 0.0
		var total := r.size[axis]
		while t < total - 8.0:
			var l := minf(rng.randf_range(18.0, 30.0), total - t)
			var lot := r
			lot.position[axis] += t
			lot.size[axis] = l
			if _rect_free(mask, lot, M_BLOCK):
				_box(node, lot, 0.0, rng.randf_range(20.0, 55.0), "Facade")
			t += l + 4.0
	# flatirons along the boulevard, clear of the lane, the canal and structures
	var dir := Vector2(R2, -R2)
	var nrm := Vector2(R2, R2)
	for sgn: float in [-1.0, 1.0]:
		var t := -250.0
		while t <= 250.0:
			if absf(t) > 45.0:
				var c := dir * t + nrm * sgn * 22.0
				var ok := true
				for a: float in [-15.0, 0.0, 15.0]:
					for b: float in [-5.0, 0.0, 5.0]:
						if _mask_at(mask, c + dir * a + nrm * b) & M_BLOCK:
							ok = false
				if ok:
					var hh := rng.randf_range(12.0, 32.0)
					ArenaBuilder.add_box(node, Vector3(c.x, hh * 0.5, c.y), Vector3(12, hh, 34), "Flatiron", -PI / 4.0)
			t += rng.randf_range(52.0, 64.0)


## Builds a lot if it is clear, else splits it and tries the halves (fills jagged edges along
## the boulevard, the canal and the channels).
static func _try_lot(node: Node3D, rng: RandomNumberGenerator, mask: PackedByteArray, r: Rect2, depth: int) -> void:
	if r.size.x < 6.0 or r.size.y < 6.0:
		return
	if _rect_free(mask, r, M_BLOCK | M_MID):
		_lot(node, rng, r)
		return
	if depth <= 0:
		return
	var axis := 0 if r.size.x >= r.size.y else 1
	var half := (r.size[axis] - 3.0) * 0.5
	for k in 2:
		var q := r
		q.size[axis] = half
		q.position[axis] += k * (half + 3.0)
		_try_lot(node, rng, mask, q, depth - 1)


## One lot: podium tower, midrise (maybe with a loading dock), stepped lowrise, open arcade or
## a courtyard with crates. 3.5 m tops are a mantle from the street.
static func _lot(node: Node3D, rng: RandomNumberGenerator, r: Rect2) -> void:
	var k := rng.randf()
	var mn := minf(r.size.x, r.size.y)
	if k < 0.32 and mn >= 14.0:
		_box(node, r, 0.0, 3.5, "Podium")
		_box(node, r.grow(-3.0), 3.5, rng.randf_range(10.0, 42.0), "Tower")
	elif k < 0.55:
		var hh := rng.randf_range(6.0, 16.0)
		if rng.randf() < 0.4 and mn >= 10.0:
			var parts := _split_side(r, rng.randi() % 4, 3.0)
			_box(node, parts[0], 0.0, 3.5, "Dock")
			_box(node, parts[1], 0.0, hh, "Building")
		else:
			_box(node, r, 0.0, hh, "Building")
	elif k < 0.74:
		_box(node, r, 0.0, 3.5, "Lowrise")
		if rng.randf() < 0.5:
			var axis := 0 if r.size.x >= r.size.y else 1
			var parts := _split_side(r, axis * 2 + rng.randi() % 2, r.size[axis] * 0.5)
			_box(node, parts[0], 3.5, 3.5, "Lowrise")
	elif k < 0.86 and mn >= 10.0:
		# arcade: walk through underneath, mantle onto the 4 m roof
		for cx: float in [r.position.x + 0.6, r.end.x - 0.6]:
			for cz: float in [r.position.y + 0.6, r.end.y - 0.6]:
				ArenaBuilder.add_box(node, Vector3(cx, 1.6, cz), Vector3(1.2, 3.2, 1.2), "ArcadePillar")
		_box(node, r, 3.2, 0.8, "ArcadeRoof")
	else:
		var heights := [1.1, 2.4, 3.6]
		for i in rng.randi_range(1, 3):
			var sz := Vector2(rng.randf_range(2.0, 5.0), rng.randf_range(2.0, 5.0))
			if sz.x > r.size.x - 2.0 or sz.y > r.size.y - 2.0:
				continue
			var p := Vector2(rng.randf_range(r.position.x + 1.0, r.end.x - 1.0 - sz.x), rng.randf_range(r.position.y + 1.0, r.end.y - 1.0 - sz.y))
			_box(node, Rect2(p, sz), 0.0, heights[rng.randi() % heights.size()], "Crate")


## [strip `amount` deep on `side` (0 -x, 1 +x, 2 -z, 3 +z), the rest].
static func _split_side(r: Rect2, side: int, amount: float) -> Array:
	var axis := side / 2
	var strip := r
	var rest := r
	strip.size[axis] = amount
	rest.size[axis] -= amount
	if side % 2 == 0:
		rest.position[axis] += amount
	else:
		strip.position[axis] = r.end[axis] - amount
	return [strip, rest]


static func _box(node: Node3D, r: Rect2, y0: float, h: float, name: String) -> void:
	var c := r.get_center()
	ArenaBuilder.add_box(node, Vector3(c.x, y0 + h * 0.5, c.y), Vector3(r.size.x, h, r.size.y), name)


# =============================================================================================
# pieces
# =============================================================================================

## Greybox block standing on y = feet.y (team A frame, rotated for team B).
static func _block(parent: Node3D, team: int, feet: Vector3, size: Vector3, yaw: float, name: String) -> void:
	var p := _map3(feet, team)
	ArenaBuilder.add_box(parent, p + Vector3.UP * size.y * 0.5, size, name, yaw + (PI if team == 1 else 0.0))


static func _rope(parent: Node3D, top: Vector3, length: float) -> void:
	ArenaBuilder.add_rope(parent, top, length)
	var vis := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, length, 0.06)
	mesh.material = _flat(Color(0.55, 0.4, 0.2))
	vis.mesh = mesh
	vis.position = top + Vector3.DOWN * length * 0.5
	parent.add_child(vis)


## Team-coloured solid structure with a floating name. Underground ones are cut to fit.
static func _structure(parent: Node3D, ctx: Dictionary, team: int, kind: StringName, p: Vector2, size: Vector3, label: String) -> void:
	var g := ground_y(p.x, p.y)
	var sz := size
	if g < ROOF_BELOW:
		sz.y = minf(sz.y, -1.5 - g)
	var body := ArenaBuilder._new_body(label.replace(" ", ""))
	body.position = Vector3(p.x, g + sz.y * 0.5, p.y)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = sz
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = sz
	var col := TEAM_COLORS[team] if team >= 0 else Color(0.9, 0.75, 0.25)
	if kind == &"shop":
		col = col.lerp(Color(0.9, 0.75, 0.25), 0.6)
	mesh.material = _lit(col)
	mi.mesh = mesh
	body.add_child(mi)
	body.set_meta(&"minimap", &"skip")
	parent.add_child(body)
	_label(parent, label, Vector3(p.x, g + minf(sz.y + 1.5, -g - 1.2 if g < ROOF_BELOW else INF), p.y))
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
	body.set_meta(&"minimap", &"skip")
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


## Zipline cables, posts and ceiling lights as MultiMeshes (one draw call each).
static func _build_visual_batches(root: Node3D, ctx: Dictionary) -> void:
	var cables: Array = ctx["cables"]
	var cm := _multimesh(root, "ZiplineCables", Vector3(0.06, 0.06, 1.0), _flat(Color(0.15, 0.15, 0.17)), cables.size())
	for i in cables.size():
		var a: Vector3 = cables[i][0]
		var b: Vector3 = cables[i][1]
		var basis := Basis.looking_at((b - a).normalized(), Vector3.UP) * Basis.from_scale(Vector3(1, 1, a.distance_to(b)))
		cm.set_instance_transform(i, Transform3D(basis, (a + b) * 0.5))
	var posts: Array = ctx["posts"]
	var pm := _multimesh(root, "ZiplinePosts", Vector3(0.25, 1.0, 0.25), _lit(Color(0.3, 0.3, 0.34)), posts.size())
	for i in posts.size():
		var feet: Vector3 = posts[i][0]
		var tall: float = posts[i][1]
		pm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(1, tall, 1)), feet + Vector3.UP * tall * 0.5))
	var lights: Array = ctx["lights"]
	var lm := _multimesh(root, "CeilingLights", Vector3(0.4, 0.12, 5.0), _flat(Color(1.0, 0.93, 0.75)), lights.size())
	for i in lights.size():
		var yaw: float = lights[i][1]
		lm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw), lights[i][0]))


static func _multimesh(root: Node3D, name: String, size: Vector3, mat: Material, count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mm.mesh = mesh
	mm.instance_count = count
	var mmi := MultiMeshInstance3D.new()
	mmi.name = name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)
	return mm


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
