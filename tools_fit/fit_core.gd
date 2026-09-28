extends RefCounted
## Fitting core: scenario loading, measured-CSV loading, deterministic MovementSim runs and the
## optimizers. Used by fit_runner.gd (fit a recording) and fit_selftest.gd (recover known params).
##
## Clean-room: only this project's own MovementSim is run. Nothing here adds behavior, caps or
## clamps to the sim; the fit only changes values of parameters that already exist, inside bounds
## the scenario author writes (and the report flags any result that sits on a bound).
##
## Channels (all rotation-invariant, so the recording's map orientation does not matter):
##   speed_h  horizontal speed                      m/s
##   vel_v    vertical velocity                     m/s
##   pos_h    horizontal distance from the t0 point  m
##   pos_v    height relative to the t0 point        m
##   h_along  horizontal velocity along the reference direction (mean velocity in align.ref_window)
##   h_across |horizontal velocity across it|  (absolute value: mirror-invariant, wall on either side)
## Measured CSVs are extract.py output (game units, u and u/s); 1 u = MoveUnits.HU m.

const U := 0.0254  # m per game unit (spec: movement.md §1, MovementParams.unit_m)
## speed_3d is the overlay speed readout (cl_showpos "vel:" first number, the 3D speed); it does not
## depend on the frame timing, unlike the velocities derived from position.
const CHANNELS: Array[String] = ["speed_h", "vel_v", "pos_h", "pos_v", "h_along", "h_across", "speed_3d"]
const POS_CHANNELS: Array[String] = ["pos_h", "pos_v"]
const BUTTONS := {
	"jump": InputCmd.BTN_JUMP, "crouch": InputCmd.BTN_CROUCH, "dash": InputCmd.BTN_DASH,
	"fire": InputCmd.BTN_FIRE, "melee_light": InputCmd.BTN_MELEE_LIGHT, "melee_heavy": InputCmd.BTN_MELEE_HEAVY,
	"parry": InputCmd.BTN_PARRY, "ability": InputCmd.BTN_ABILITY, "zip_boost": InputCmd.BTN_ZIP_BOOST,
}

var scenario: Dictionary = {}
var scenario_path: String = ""
var base_params: MovementParams
var base_hero: HeroMovementStats
var harness: SimHarness
var dt: float = 1.0 / 64.0
## Active fit parameters: {name, target ("params"|"hero"), prop, index (-1 = scalar), min, max, init, gap, note}
var specs: Array[Dictionary] = []
var skipped: PackedStringArray = PackedStringArray()
var warnings: PackedStringArray = PackedStringArray()
var weights: Dictionary = {}
var measured: Dictionary = {}
var evals: int = 0
var _cmds: Array[InputCmd] = []


# ------------------------------------------------------------------------------------------------
# scenario
# ------------------------------------------------------------------------------------------------

static func read_json(path: String) -> Variant:
	var txt := FileAccess.get_file_as_string(path)
	if txt == "":
		return null
	return JSON.parse_string(txt)


static func globalize(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path


## Loads the scenario and builds the harness. The caller must `await core.harness.ready()`.
func setup(tree: SceneTree, p_scenario_path: String) -> String:
	scenario_path = p_scenario_path
	var sc: Variant = read_json(p_scenario_path)
	if typeof(sc) != TYPE_DICTIONARY:
		return "cannot read scenario JSON: %s" % p_scenario_path
	scenario = sc
	var pp: String = scenario.get("params_resource", "res://data/movement/movement_params.tres")
	var hp: String = scenario.get("hero", "res://data/movement/heroes/hero_default_b1.tres")
	var pr: Resource = load(pp)
	var hr: Resource = load(hp)
	if not (pr is MovementParams):
		return "params_resource is not a MovementParams: %s" % pp
	if not (hr is HeroMovementStats):
		return "hero is not a HeroMovementStats: %s" % hp
	base_params = (pr as MovementParams).duplicate(true)
	base_hero = (hr as HeroMovementStats).duplicate(true)
	# fixed overrides (e.g. a hero's gravity_scale for a hover test); never fitted
	for k: String in (scenario.get("fixed", {}) as Dictionary).keys():
		var e := _resolve(k)
		if e.is_empty():
			return "fixed parameter '%s' does not exist" % k
		_set_value(base_params, base_hero, e, float(scenario["fixed"][k]))
	dt = 1.0 / float(base_params.tick_rate)
	var err := _resolve_specs()
	if err != "":
		return err
	weights = {"speed_h": 1.0, "vel_v": 1.0, "pos_h": 0.0, "pos_v": 0.0, "h_along": 0.0, "h_across": 0.0, "speed_3d": 0.0}
	for k: String in (scenario.get("weights", {}) as Dictionary).keys():
		if not CHANNELS.has(k):
			return "unknown channel in weights: %s (known: %s)" % [k, ", ".join(CHANNELS)]
		weights[k] = float(scenario["weights"][k])
	harness = SimHarness.create(tree, StringName(scenario.get("layout", "flat")), base_params, base_hero)
	harness.suppress_sprint = bool(scenario.get("suppress_sprint", true))
	for g: Dictionary in scenario.get("geometry", []):
		var c := _v3(g.get("center", [0, 0, 0]))
		var s := _v3(g.get("size", [1, 1, 1]))
		match String(g.get("type", "box")):
			"wall":
				ArenaBuilder.add_wall(harness.root, c, s)
			"box":
				ArenaBuilder.add_box(harness.root, c, s)
			_:
				return "unknown geometry type: %s" % g.get("type")
	_build_cmds()
	return ""


func _resolve_specs() -> String:
	specs.clear()
	skipped.clear()
	for p: Dictionary in scenario.get("params", []):
		var name: String = p.get("name", "")
		var e := _resolve(name)
		if e.is_empty():
			if bool(p.get("optional", false)):
				skipped.append(name)
				warnings.append("optional parameter '%s' does not exist in this build; skipped" % name)
				continue
			return "parameter '%s' does not exist (mark it \"optional\": true to skip)" % name
		if bool(e.get("is_int", false)):
			return "parameter '%s' is an int: the optimizer needs a continuous parameter (set it under \"fixed\" instead)" % name
		if not p.has("min") or not p.has("max") or float(p["max"]) <= float(p["min"]):
			return "parameter '%s' needs bounds with max > min" % name
		e["min"] = float(p["min"])
		e["max"] = float(p["max"])
		var cur := _get_value(base_params, base_hero, e)
		e["default"] = cur
		e["init"] = float(p.get("init", cur))
		if e["init"] < e["min"] or e["init"] > e["max"]:
			warnings.append("init of '%s' (%.6f) is outside its bounds; clamped" % [name, e["init"]])
			e["init"] = clampf(e["init"], e["min"], e["max"])
		e["gap"] = String(p.get("gap", ""))
		e["note"] = String(p.get("note", ""))
		specs.append(e)
	if specs.is_empty():
		return "no fit parameters (all missing or none listed)"
	return ""


## "name", "hero.name", "name[i]", "hero.name[i]" -> {name, target, prop, index} or {} when missing.
func _resolve(name: String) -> Dictionary:
	var target := "params"
	var prop := name
	if prop.begins_with("hero."):
		target = "hero"
		prop = prop.substr(5)
	var index := -1
	var b := prop.find("[")
	if b > 0 and prop.ends_with("]"):
		index = int(prop.substr(b + 1, prop.length() - b - 2))
		prop = prop.substr(0, b)
	var obj: Resource = base_params if target == "params" else base_hero
	if not _has_prop(obj, prop):
		return {}
	var v: Variant = obj.get(prop)
	if index >= 0:
		if not _is_array(v) or index >= v.size():
			return {}
		v = v[index]
	if not (v is float or v is int or v is bool):
		return {}
	# a bool counts as an int: usable under "fixed" only, never optimized
	return {"name": name, "target": target, "prop": prop, "index": index, "is_int": v is int or v is bool}


static func _is_array(v: Variant) -> bool:
	return typeof(v) in [TYPE_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY]


static func _has_prop(obj: Object, prop: String) -> bool:
	for d: Dictionary in obj.get_property_list():
		if String(d["name"]) == prop:
			return true
	return false


static func _get_value(params: MovementParams, hero: HeroMovementStats, e: Dictionary) -> float:
	var obj: Resource = params if e["target"] == "params" else hero
	var v: Variant = obj.get(e["prop"])
	if int(e["index"]) >= 0:
		return float(v[int(e["index"])])
	return float(v)


static func _set_value(params: MovementParams, hero: HeroMovementStats, e: Dictionary, value: float) -> void:
	var obj: Resource = params if e["target"] == "params" else hero
	var cur: Variant = obj.get(e["prop"])
	if int(e["index"]) >= 0:
		# write back a modified copy of the whole array: an element set on the getter's copy (packed
		# arrays) would be lost
		var arr: Variant = cur.duplicate()
		var i := int(e["index"])
		arr[i] = value if arr[i] is float else int(round(value))
		obj.set(e["prop"], arr)
	elif cur is int:
		obj.set(e["prop"], int(round(value)))
	elif cur is bool:
		obj.set(e["prop"], value != 0.0)  # "fixed" switches: 0 = false, anything else = true
	else:
		obj.set(e["prop"], value)


static func _v3(a: Variant) -> Vector3:
	var arr: Array = a
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))


func ticks() -> int:
	return int(scenario.get("ticks", 128))


## Timeline -> one InputCmd per tick. Ticks are 1-based (tick 1 is the first simulate()).
## "default": {move:[x,y], buttons:[...], yaw_deg}; timeline entries {from, to, buttons, move, yaw_deg}
## override/add for ticks from..to inclusive. Held bits only: the sim derives press edges, so a
## one-tick press is from == to.
func _build_cmds() -> void:
	_cmds.clear()
	var st: Dictionary = scenario.get("start", {})
	var d: Dictionary = scenario.get("default", {})
	var yaw0 := deg_to_rad(float(st.get("yaw_deg", 0.0)))
	for t in range(1, ticks() + 1):
		var mv: Array = d.get("move", [0, 0])
		var yaw := deg_to_rad(float(d.get("yaw_deg", rad_to_deg(yaw0))))
		var btn := _buttons(d.get("buttons", []))
		for e: Dictionary in scenario.get("timeline", []):
			if t >= int(e.get("from", 0)) and t <= int(e.get("to", e.get("from", 0))):
				btn |= _buttons(e.get("buttons", []))
				if e.has("move"):
					mv = e["move"]
				if e.has("yaw_deg"):
					yaw = deg_to_rad(float(e["yaw_deg"]))
		_cmds.append(InputCmd.create(t, btn, int(mv[0]), int(mv[1]), yaw, 0.0))


static func _buttons(names: Array) -> int:
	var b := 0
	for n: Variant in names:
		var k := String(n).to_lower()
		if BUTTONS.has(k):
			b |= int(BUTTONS[k])
		else:
			push_warning("unknown button '%s' (known: %s)" % [k, ", ".join(BUTTONS.keys())])
	return b


# ------------------------------------------------------------------------------------------------
# simulation
# ------------------------------------------------------------------------------------------------

func init_vector() -> PackedFloat64Array:
	var x := PackedFloat64Array()
	for e in specs:
		x.append(float(e["init"]))
	return x


func values_dict(x: PackedFloat64Array) -> Dictionary:
	var d := {}
	for i in specs.size():
		d[specs[i]["name"]] = x[i]
	return d


## Runs the scenario with parameter values x (native units of each parameter).
## Returns {t, pos, vel, loco} with index 0 = the start state at t = 0 and index i = after tick i.
func simulate(x: PackedFloat64Array) -> Dictionary:
	var params: MovementParams = base_params.duplicate(true)
	var hero: HeroMovementStats = base_hero.duplicate(true)
	for i in specs.size():
		_set_value(params, hero, specs[i], x[i])
	var cp := CompiledMoveParams.build(params, hero)
	harness.cp = cp
	harness.sim.set_params(cp)
	var st: Dictionary = scenario.get("start", {})
	var p0: Vector3 = _v3(st["pos_m"]) if st.has("pos_m") else harness.info.get("spawn", Vector3.ZERO)
	harness.spawn(p0, deg_to_rad(float(st.get("yaw_deg", 0.0))))
	var s := harness.state
	if st.has("vel_mps"):
		s.velocity = _v3(st["vel_mps"])
	if st.has("stamina"):
		s.stamina = float(st["stamina"])
	var out_t := PackedFloat64Array([0.0])
	var out_p: Array[Vector3] = [s.position]
	var out_v: Array[Vector3] = [s.velocity]
	var out_l := PackedInt32Array([s.loco])
	for c in _cmds:
		harness.step(c.duplicate_cmd())
		out_t.append(float(s.tick) * dt)
		out_p.append(s.position)
		out_v.append(s.velocity)
		out_l.append(s.loco)
	evals += 1
	return {"t": out_t, "pos": out_p, "vel": out_v, "loco": out_l}


## Godot (Y up, forward -Z) -> the extract.py frame with z up: (x, -z, y). A proper rotation, so
## signed quantities keep their handedness.
static func godot_to_zup(v: Vector3) -> Vector3:
	return Vector3(v.x, -v.z, v.y)


# ------------------------------------------------------------------------------------------------
# measured data
# ------------------------------------------------------------------------------------------------

## Reads an extract.py CSV. Only rows with valid == 1 are used. Returns {} and sets `warnings` on error.
func load_measured(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return "cannot open measured CSV: %s" % path
	var header := f.get_csv_line()
	var col := {}
	for i in header.size():
		col[header[i].strip_edges()] = i
	for need in ["t", "pos_x", "pos_y", "pos_z"]:
		if not col.has(need):
			return "measured CSV lacks column '%s'" % need
	var up := String(scenario.get("up_axis", "z")).to_lower()
	var t := PackedFloat64Array()
	var ph: Array[Vector2] = []
	var pv := PackedFloat64Array()
	var vh: Array[Vector2] = []
	var vv := PackedFloat64Array()
	var has_vel := PackedByteArray()
	var s3 := PackedFloat64Array()
	while not f.eof_reached():
		var r := f.get_csv_line()
		if r.size() < header.size():
			continue
		if col.has("valid") and r[col["valid"]].strip_edges() != "1":
			continue
		var tt := r[col["t"]]
		if tt == "" or r[col["pos_x"]] == "" or r[col["pos_y"]] == "" or r[col["pos_z"]] == "":
			continue
		var p := Vector3(float(r[col["pos_x"]]), float(r[col["pos_y"]]), float(r[col["pos_z"]])) * U
		var v := Vector3.ZERO
		var hv := col.has("vel_x") and r[col["vel_x"]] != "" and r[col["vel_y"]] != "" and r[col["vel_z"]] != ""
		if hv:
			v = Vector3(float(r[col["vel_x"]]), float(r[col["vel_y"]]), float(r[col["vel_z"]])) * U
		if up == "y":
			# y-up to z-up as a proper rotation (+90 deg about x), not a reflection. The fitted channels
			# (horizontal speed, vertical velocity and position) do not depend on the handedness anyway.
			p = Vector3(p.x, -p.z, p.y)
			v = Vector3(v.x, -v.z, v.y)
		t.append(float(tt))
		ph.append(Vector2(p.x, p.y))
		pv.append(p.z)
		vh.append(Vector2(v.x, v.y))
		vv.append(v.z)
		has_vel.append(1 if hv else 0)
		var sc := r[col["vel_scalar"]].strip_edges() if col.has("vel_scalar") else ""
		s3.append(float(sc) * U if sc != "" and sc != "nan" else NAN)
	if t.size() < 4:
		return "measured CSV has fewer than 4 valid rows: %s" % path
	measured = {"path": path, "t": t, "ph": ph, "pv": pv, "vh": vh, "vv": vv, "has_vel": has_vel, "s3": s3}
	return ""


# ------------------------------------------------------------------------------------------------
# channels, alignment, cost
# ------------------------------------------------------------------------------------------------

static func _interp_f(ts: PackedFloat64Array, ys: PackedFloat64Array, t: float) -> float:
	var n := ts.size()
	if t <= ts[0]:
		return ys[0]
	if t >= ts[n - 1]:
		return ys[n - 1]
	var lo := 0
	var hi := n - 1
	while hi - lo > 1:
		var m := (lo + hi) >> 1
		if ts[m] <= t:
			lo = m
		else:
			hi = m
	var a := (t - ts[lo]) / maxf(ts[hi] - ts[lo], 1e-12)
	return lerpf(ys[lo], ys[hi], a)


static func _interp_v2(ts: PackedFloat64Array, ys: Array[Vector2], t: float) -> Vector2:
	var xs := PackedFloat64Array()
	var yy := PackedFloat64Array()
	for v in ys:
		xs.append(v.x)
		yy.append(v.y)
	return Vector2(_interp_f(ts, xs, t), _interp_f(ts, yy, t))


## First time the channel crosses `value` in `direction` (+1 rising, -1 falling), linearly interpolated.
static func _crossing(ts: PackedFloat64Array, ys: PackedFloat64Array, value: float, direction: int, after: float) -> float:
	for i in range(1, ts.size()):
		if ts[i] < after:
			continue
		var a := ys[i - 1] - value
		var b := ys[i] - value
		if (direction >= 0 and a < 0.0 and b >= 0.0) or (direction < 0 and a > 0.0 and b <= 0.0):
			return ts[i - 1] + (ts[i] - ts[i - 1]) * (-a / (b - a))
	return NAN


## Sim series -> channel arrays (SI), relative to the start state; the reference direction is the
## mean horizontal velocity over align.ref_window (t relative to tick 0).
func sim_channels(sim: Dictionary) -> Dictionary:
	var ts: PackedFloat64Array = sim["t"]
	var pos: Array[Vector3] = sim["pos"]
	var vel: Array[Vector3] = sim["vel"]
	var ph: Array[Vector2] = []
	var pv := PackedFloat64Array()
	var vh: Array[Vector2] = []
	var vv := PackedFloat64Array()
	for i in ts.size():
		var p := godot_to_zup(pos[i])
		var v := godot_to_zup(vel[i])
		ph.append(Vector2(p.x, p.y))
		pv.append(p.z)
		vh.append(Vector2(v.x, v.y))
		vv.append(v.z)
	return _channels(ts, ph, pv, vh, vv, 0.0, ph[0], pv[0])


func _ref_dir(ts: PackedFloat64Array, vh: Array[Vector2], t0: float) -> Vector2:
	var w: Array = (scenario.get("align", {}) as Dictionary).get("ref_window", [])
	if w.size() != 2:
		return Vector2.ZERO
	var acc := Vector2.ZERO
	var n := 0
	for i in ts.size():
		var tr := ts[i] - t0
		if tr >= float(w[0]) - 1e-9 and tr <= float(w[1]) + 1e-9:
			acc += vh[i]
			n += 1
	if n == 0:
		acc = _interp_v2(ts, vh, t0 + 0.5 * (float(w[0]) + float(w[1])))
	if acc.length() < 1e-6:
		return Vector2.ZERO
	return acc.normalized()


func _channels(ts: PackedFloat64Array, ph: Array[Vector2], pv: PackedFloat64Array, vh: Array[Vector2], vv: PackedFloat64Array,
		t0: float, ph0: Vector2, pv0: float, s3_in: PackedFloat64Array = PackedFloat64Array()) -> Dictionary:
	var ref := _ref_dir(ts, vh, t0)
	# local packed arrays, stored in the dictionary at the end (packed arrays are values)
	var sh := PackedFloat64Array()
	var sv := PackedFloat64Array()
	var dh := PackedFloat64Array()
	var dv := PackedFloat64Array()
	var al := PackedFloat64Array()
	var ac := PackedFloat64Array()
	var trel := PackedFloat64Array()
	var s3 := PackedFloat64Array()
	for i in ts.size():
		trel.append(ts[i] - t0)
		sh.append(vh[i].length())
		sv.append(vv[i])
		dh.append((ph[i] - ph0).length())
		dv.append(pv[i] - pv0)
		al.append(vh[i].dot(ref) if ref != Vector2.ZERO else NAN)
		ac.append(absf(vh[i].cross(ref)) if ref != Vector2.ZERO else NAN)
		s3.append(s3_in[i] if s3_in.size() == ts.size() else sqrt(vh[i].length_squared() + vv[i] * vv[i]))
	var ch := {"speed_h": sh, "vel_v": sv, "pos_h": dh, "pos_v": dv, "h_along": al, "h_across": ac, "speed_3d": s3}
	return {"t": trel, "ch": ch, "ref": ref}


func measured_channels(t0: float) -> Dictionary:
	var ts: PackedFloat64Array = measured["t"]
	var ph0 := _interp_v2(ts, measured["ph"], t0)
	var pv0 := _interp_f(ts, measured["pv"], t0)
	var out := _channels(ts, measured["ph"], measured["pv"], measured["vh"], measured["vv"], t0, ph0, pv0, measured.get("s3", PackedFloat64Array()))
	# rows without a velocity readout (scalar/derived) carry derived velocity from extract.py only
	# when present; otherwise velocity channels are NaN there
	var hv: PackedByteArray = measured["has_vel"]
	for c in ["speed_h", "vel_v", "h_along", "h_across"]:
		var a: PackedFloat64Array = out["ch"][c]
		for i in a.size():
			if hv[i] == 0:
				a[i] = NAN
		out["ch"][c] = a
	return out


## Measured time of sim tick 0 for this sim run.
func align_t0(simc: Dictionary) -> float:
	var al: Dictionary = scenario.get("align", {})
	var mode := String(al.get("mode", "manual"))
	if mode == "manual":
		return float(al.get("measured_t0", 0.0))
	if mode == "threshold":
		var c := String(al.get("channel", "speed_h"))
		var val := float(al.get("value_u", 400.0)) * U
		var dirn := int(al.get("direction", 1))
		if not measured.has("_cross"):
			var mc := _channels(measured["t"], measured["ph"], measured["pv"], measured["vh"], measured["vv"], 0.0, Vector2.ZERO, 0.0, measured.get("s3", PackedFloat64Array()))
			measured["_cross"] = _crossing(_finite_t(mc["t"], mc["ch"][c]), _finite_y(mc["ch"][c]), val, dirn, float(al.get("measured_after", -1e9)))
		var ts := _crossing(simc["t"], simc["ch"][c], val, dirn, 0.0)
		if is_nan(float(measured["_cross"])) or is_nan(ts):
			return NAN
		return float(measured["_cross"]) - ts
	push_error("align.mode must be 'manual' or 'threshold'")
	return NAN


static func _finite_t(ts: PackedFloat64Array, ys: PackedFloat64Array) -> PackedFloat64Array:
	var o := PackedFloat64Array()
	for i in ts.size():
		if not is_nan(ys[i]):
			o.append(ts[i])
	return o


static func _finite_y(ys: PackedFloat64Array) -> PackedFloat64Array:
	var o := PackedFloat64Array()
	for y in ys:
		if not is_nan(y):
			o.append(y)
	return o


## Cost of one parameter vector: sum over channels of weight * mean squared residual (SI units)
## on measured samples inside fit_window (t relative to tick 0). With align.search_ticks > 0
## (manual mode) the best shift in quarter-tick steps within +-search_ticks is used.
func evaluate(x: PackedFloat64Array, want_rows: bool = false) -> Dictionary:
	var sim := simulate(x)
	var simc := sim_channels(sim)
	var t0 := align_t0(simc)
	if is_nan(t0):
		return {"cost": INF, "t0": NAN, "rmse": {}, "n": 0, "reason": "alignment failed (threshold never crossed)"}
	var al: Dictionary = scenario.get("align", {})
	var best := {}
	var steps := int(al.get("search_ticks", 0)) * 4
	for k in range(-steps, steps + 1):
		var r := _score(simc, t0 + float(k) * dt * 0.25, want_rows)
		if best.is_empty() or float(r["cost"]) < float(best["cost"]):
			best = r
	best["sim"] = sim
	best["simc"] = simc
	return best


func _score(simc: Dictionary, t0: float, want_rows: bool) -> Dictionary:
	var mc := measured_channels(t0)
	var win: Array = scenario.get("fit_window", [0.0, 1e9])
	var t_lo := float(win[0])
	var t_hi := minf(float(win[1]), (simc["t"] as PackedFloat64Array)[-1])
	var tm: PackedFloat64Array = mc["t"]
	var cost := 0.0
	var rmse := {}
	var nmax := 0
	var rows: Array[Dictionary] = []
	for c in CHANNELS:
		if float(weights.get(c, 0.0)) <= 0.0 and not want_rows:
			continue
		var ym: PackedFloat64Array = mc["ch"][c]
		var ys: PackedFloat64Array = simc["ch"][c]
		var ss := 0.0
		var n := 0
		for i in tm.size():
			if tm[i] < t_lo - 1e-9 or tm[i] > t_hi + 1e-9 or is_nan(ym[i]):
				continue
			var s := _interp_f(simc["t"], ys, tm[i])
			if is_nan(s):
				continue
			var d := s - ym[i]
			ss += d * d
			n += 1
		if n > 0:
			rmse[c] = sqrt(ss / n) / U  # u/s or u
			if float(weights.get(c, 0.0)) > 0.0:
				cost += float(weights[c]) * ss / n
		nmax = maxi(nmax, n)
	if want_rows:
		for i in tm.size():
			if tm[i] < t_lo - 1e-9 or tm[i] > t_hi + 1e-9:
				continue
			var row := {"t": (measured["t"] as PackedFloat64Array)[i], "t_rel": tm[i]}
			for c in CHANNELS:
				var m: float = (mc["ch"][c] as PackedFloat64Array)[i]
				var s := _interp_f(simc["t"], simc["ch"][c], tm[i])
				row[c + "_meas"] = m / U
				row[c + "_sim"] = s / U
				row[c + "_res"] = (s - m) / U
			rows.append(row)
	if nmax == 0:
		cost = INF
	return {"cost": cost, "t0": t0, "rmse": rmse, "n": nmax, "rows": rows}


# ------------------------------------------------------------------------------------------------
# optimizers (in normalized [0,1] bound space)
# ------------------------------------------------------------------------------------------------

func to_norm(x: PackedFloat64Array) -> PackedFloat64Array:
	var u := PackedFloat64Array()
	for i in specs.size():
		u.append((x[i] - float(specs[i]["min"])) / (float(specs[i]["max"]) - float(specs[i]["min"])))
	return u


func from_norm(u: PackedFloat64Array) -> PackedFloat64Array:
	var x := PackedFloat64Array()
	for i in specs.size():
		var c := clampf(u[i], 0.0, 1.0)
		x.append(float(specs[i]["min"]) + c * (float(specs[i]["max"]) - float(specs[i]["min"])))
	return x


func cost_norm(u: PackedFloat64Array) -> float:
	# outside the box: cost at the clamped point plus a penalty, so the simplex walks back in
	var pen := 0.0
	for v in u:
		if v < 0.0:
			pen += v * v
		elif v > 1.0:
			pen += (v - 1.0) * (v - 1.0)
	var c := float(evaluate(from_norm(u))["cost"])
	return c * (1.0 + 10.0 * pen) + pen


## Nelder-Mead with restarts from the best point. Returns {u, f, evals}.
func nelder_mead(u0: PackedFloat64Array, max_evals: int, restarts: int, step: float = 0.15, tol: float = 1e-10) -> Dictionary:
	var best_u := u0.duplicate()
	var best_f := cost_norm(best_u)
	var used := 1
	for r in restarts + 1:
		var res := _nm_once(best_u, best_f, maxi(1, max_evals - used), step if r == 0 else step * 0.5, tol)
		used += int(res["evals"])
		if float(res["f"]) <= best_f:
			best_u = res["u"]
			best_f = float(res["f"])
		if used >= max_evals:
			break
	return {"u": best_u, "f": best_f, "evals": used}


func _nm_once(u0: PackedFloat64Array, f0: float, budget: int, step: float, tol: float) -> Dictionary:
	var n := u0.size()
	var pts: Array[PackedFloat64Array] = [u0.duplicate()]
	var fs: Array[float] = [f0]
	var used := 0
	for i in n:
		var p := u0.duplicate()
		p[i] = p[i] + step if p[i] + step <= 1.0 else p[i] - step
		pts.append(p)
		fs.append(cost_norm(p))
		used += 1
	while used < budget:
		# sort
		var order: Array = range(n + 1)
		order.sort_custom(func(a: int, b: int) -> bool: return fs[a] < fs[b])
		var sp: Array[PackedFloat64Array] = []
		var sf: Array[float] = []
		for k: int in order:
			sp.append(pts[k])
			sf.append(fs[k])
		pts = sp
		fs = sf
		var size := 0.0
		for i in range(1, n + 1):
			for j in n:
				size = maxf(size, absf(pts[i][j] - pts[0][j]))
		if size < 1e-6 or absf(fs[n] - fs[0]) <= tol * (absf(fs[0]) + 1e-30):
			break
		var cen := PackedFloat64Array()
		cen.resize(n)
		for j in n:
			var s := 0.0
			for i in n:
				s += pts[i][j]
			cen[j] = s / n
		var xr := _lin(cen, pts[n], -1.0)
		var fr := cost_norm(xr)
		used += 1
		if fr < fs[0]:
			var xe := _lin(cen, pts[n], -2.0)
			var fe := cost_norm(xe)
			used += 1
			if fe < fr:
				pts[n] = xe
				fs[n] = fe
			else:
				pts[n] = xr
				fs[n] = fr
		elif fr < fs[n - 1]:
			pts[n] = xr
			fs[n] = fr
		else:
			var outside := fr < fs[n]
			var xc := _lin(cen, pts[n], -0.5 if outside else 0.5)
			var fc := cost_norm(xc)
			used += 1
			if (outside and fc <= fr) or (not outside and fc < fs[n]):
				pts[n] = xc
				fs[n] = fc
			else:
				for i in range(1, n + 1):
					pts[i] = _lin(pts[0], pts[i], 0.5)
					fs[i] = cost_norm(pts[i])
					used += 1
	var bi := 0
	for i in fs.size():
		if fs[i] < fs[bi]:
			bi = i
	return {"u": pts[bi], "f": fs[bi], "evals": used}


## c + a * (p - c)
static func _lin(c: PackedFloat64Array, p: PackedFloat64Array, a: float) -> PackedFloat64Array:
	var o := PackedFloat64Array()
	for j in c.size():
		o.append(c[j] + a * (p[j] - c[j]))
	return o


## Coordinate search: per parameter try +-step, keep improvements, halve the step when stuck.
func coordinate_search(u0: PackedFloat64Array, max_evals: int, step: float = 0.25, min_step: float = 1e-5) -> Dictionary:
	var u := u0.duplicate()
	var f := cost_norm(u)
	var used := 1
	while step > min_step and used < max_evals:
		var improved := false
		for i in u.size():
			for sgn in [1.0, -1.0]:
				var p := u.duplicate()
				p[i] = clampf(p[i] + sgn * step, 0.0, 1.0)
				if p[i] == u[i]:
					continue
				var fp := cost_norm(p)
				used += 1
				if fp < f:
					u = p
					f = fp
					improved = true
					break
		if not improved:
			step *= 0.5
	return {"u": u, "f": f, "evals": used}


## Runs the optimizer named in scenario.optimizer and returns {x, f, evals}.
func fit() -> Dictionary:
	var o: Dictionary = scenario.get("optimizer", {})
	var method := String(o.get("method", "nelder_mead"))
	var max_evals := int(o.get("max_evals", 400))
	var u0 := to_norm(init_vector())
	var r: Dictionary
	if method == "coordinate":
		r = coordinate_search(u0, max_evals)
	else:
		r = nelder_mead(u0, max_evals, int(o.get("restarts", 2)))
	return {"x": from_norm(r["u"]), "f": r["f"], "evals": r["evals"]}


## MovementParams.validate() on candidate x (hero values are not checked there), as report warnings.
func validate_candidate(x: PackedFloat64Array) -> PackedStringArray:
	var params: MovementParams = base_params.duplicate(true)
	var hero: HeroMovementStats = base_hero.duplicate(true)
	for i in specs.size():
		_set_value(params, hero, specs[i], x[i])
	var out := PackedStringArray()
	for w in params.validate():
		out.append("best candidate fails MovementParams.validate(): " + w)
	return out


## Identifiability: relative cost increase for a +-h step (normalized space) per parameter at x.
func sensitivity(x: PackedFloat64Array, h: float = 0.02) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var u := to_norm(x)
	var f0 := float(evaluate(x)["cost"])
	for i in specs.size():
		var rise := 0.0
		for sgn in [1.0, -1.0]:
			var p := u.duplicate()
			p[i] = clampf(p[i] + sgn * h, 0.0, 1.0)
			if p[i] == u[i]:
				continue
			rise = maxf(rise, float(evaluate(from_norm(p))["cost"]) - f0)
		var step_native := h * (float(specs[i]["max"]) - float(specs[i]["min"]))
		out.append({"name": specs[i]["name"], "cost_rise": rise, "rel_rise": rise / maxf(f0, 1e-12), "step": step_native})
	return out


# ------------------------------------------------------------------------------------------------
# outputs
# ------------------------------------------------------------------------------------------------

## Fits and writes best_params.json, residuals.csv, sim_best_trace.csv and report.md into out_dir.
## Returns the summary dictionary (also in best_params.json).
func run_and_write(out_dir: String) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(globalize(out_dir))
	var x0 := init_vector()
	var e0 := evaluate(x0, true)   # want_rows: RMSE for every channel, as for the best candidate
	var t_start := Time.get_ticks_msec()
	var r := fit()
	var xb: PackedFloat64Array = r["x"]
	var eb := evaluate(xb, true)
	var sens := sensitivity(xb)
	var secs := float(Time.get_ticks_msec() - t_start) / 1000.0
	var summary := {
		"scenario": scenario_path,
		"clip": scenario.get("clip", ""),
		"gaps": scenario.get("gaps", []),
		"measured": measured.get("path", ""),
		"optimizer": scenario.get("optimizer", {}),
		"evals": int(r["evals"]),
		"seconds": secs,
		"t0_measured": eb["t0"],
		"cost_init": e0["cost"],
		"cost_best": eb["cost"],
		"rmse_init": e0.get("rmse", {}),
		"rmse_best": eb.get("rmse", {}),
		"samples": eb.get("n", 0),
		"weights": weights,
		"skipped_params": Array(skipped),
		"warnings": Array(warnings) + Array(validate_candidate(xb)),
		"params": [],
	}
	for i in specs.size():
		var s := specs[i]
		var lo := float(s["min"])
		var hi := float(s["max"])
		var at_bound := absf(xb[i] - lo) <= 1e-3 * (hi - lo) or absf(xb[i] - hi) <= 1e-3 * (hi - lo)
		(summary["params"] as Array).append({
			"name": s["name"], "gap": s["gap"], "default": s["default"], "init": x0[i], "best": xb[i],
			"min": lo, "max": hi, "at_bound": at_bound,
			"sensitivity_rel": sens[i]["rel_rise"], "note": s["note"],
		})
	_write_text(out_dir.path_join("best_params.json"), JSON.stringify(summary, "  "))
	_write_residuals(out_dir.path_join("residuals.csv"), eb.get("rows", [] as Array[Dictionary]))
	if eb.has("sim"):
		_write_trace(out_dir.path_join("sim_best_trace.csv"), eb["sim"], float(eb["t0"]))
	_write_text(out_dir.path_join("report.md"), _report(summary))
	return summary


static func _write_text(path: String, txt: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot write %s" % path)
		return
	f.store_string(txt)
	f.close()


func _write_residuals(path: String, rows: Array[Dictionary]) -> void:
	var hdr := PackedStringArray(["t", "t_rel"])
	for c in CHANNELS:
		hdr.append_array([c + "_meas", c + "_sim", c + "_res"])
	var lines := PackedStringArray([",".join(hdr)])
	for r in rows:
		var vals := PackedStringArray()
		for h in hdr:
			var v := float(r.get(h, NAN))
			vals.append("" if is_nan(v) else ("%.6f" % v if (h == "t" or h == "t_rel") else "%.4f" % v))
		lines.append(",".join(vals))
	_write_text(path, "\n".join(lines) + "\n")


func _write_trace(path: String, sim: Dictionary, t0: float) -> void:
	var lines := PackedStringArray(["tick,t_rel,t_measured,pos_x_u,pos_y_u,pos_z_u,vel_x_ups,vel_y_ups,vel_z_ups,speed_h_ups,loco"])
	var ts: PackedFloat64Array = sim["t"]
	var names: Array = MoveState.Loco.keys()
	for i in ts.size():
		var p := godot_to_zup((sim["pos"] as Array)[i]) / U
		var v := godot_to_zup((sim["vel"] as Array)[i]) / U
		lines.append("%d,%.6f,%.6f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%s" % [i, ts[i], ts[i] + t0, p.x, p.y, p.z, v.x, v.y, v.z,
			Vector2(v.x, v.y).length(), names[(sim["loco"] as PackedInt32Array)[i]]])
	_write_text(path, "\n".join(lines) + "\n")


func _report(s: Dictionary) -> String:
	var L := PackedStringArray()
	L.append("# Fit report: %s" % String(scenario.get("name", scenario_path.get_file())))
	L.append("")
	L.append("- Scenario: `%s`" % scenario_path)
	L.append("- Measured: `%s`" % s["measured"])
	L.append("- Clip: %s. Gaps: %s" % [s["clip"], ", ".join(PackedStringArray(s["gaps"]))])
	L.append("- Optimizer: %s, %d sim runs, %.1f s. Measured time of tick 0: %.4f s" % [
		String((s["optimizer"] as Dictionary).get("method", "nelder_mead")), s["evals"], s["seconds"], s["t0_measured"]])
	L.append("- Samples in the fit window: %d. Cost %s -> %s" % [s["samples"], String.num_scientific(s["cost_init"]), String.num_scientific(s["cost_best"])])
	L.append("")
	L.append("Nothing here has been applied. The values below are candidates for review (plan step 3).")
	L.append("")
	L.append("## Parameters")
	L.append("")
	L.append("| parameter | gap | default | init | best | bounds | flags |")
	L.append("|---|---|---|---|---|---|---|")
	for p: Dictionary in s["params"]:
		var flags := PackedStringArray()
		if p["at_bound"]:
			flags.append("AT BOUND: widen bounds or the model cannot explain the clip")
		if float(p["sensitivity_rel"]) < 0.01:
			flags.append("FLAT: this clip barely constrains it")
		L.append("| %s | %s | %.6f | %.6f | **%.6f** | [%.6f, %.6f] | %s |" % [p["name"], p["gap"], p["default"], p["init"], p["best"],
			p["min"], p["max"], "; ".join(flags)])
	if not (s["skipped_params"] as Array).is_empty():
		L.append("")
		L.append("Skipped (not in this build): %s" % ", ".join(PackedStringArray(s["skipped_params"])))
	L.append("")
	L.append("## Fit quality (RMSE, u/s for velocities, u for positions)")
	L.append("")
	L.append("| channel | weight | before | after |")
	L.append("|---|---|---|---|")
	for c in CHANNELS:
		var b: Variant = (s["rmse_init"] as Dictionary).get(c)
		var a: Variant = (s["rmse_best"] as Dictionary).get(c)
		if b == null and a == null:
			continue
		L.append("| %s | %.6f | %s | %s |" % [c, float(weights.get(c, 0.0)), "-" if b == null else "%.2f" % float(b), "-" if a == null else "%.2f" % float(a)])
	L.append("")
	L.append("Sensitivity is the relative cost rise for a 2 % of range step from the best value. Below 0.01 means the")
	L.append("clip does not pin the parameter down: fix it from another clip, or add a channel that sees it.")
	L.append("")
	L.append("Review `residuals.csv` (per sample: measured, sim, residual) and `sim_best_trace.csv`. A residual with")
	L.append("structure (a step, a slope) means a behavior difference that parameter values cannot fix. Log that as a")
	L.append("gap instead of forcing the fit.")
	if not (s["warnings"] as Array).is_empty():
		L.append("")
		L.append("## Warnings")
		L.append("")
		for w: String in s["warnings"]:
			L.append("- " + w)
	L.append("")
	L.append("## Candidate .tres lines (do not apply until reviewed across trials)")
	L.append("")
	L.append("```")
	for p: Dictionary in s["params"]:
		var nm := String(p["name"])
		var file := "hero .tres" if nm.begins_with("hero.") else "movement_params.tres"
		L.append("%s = %.6f   # %s. Comment in movement_params.gd: # PROVISIONAL (%s): fitted from clip %s, pending trials" % [
			nm.trim_prefix("hero."), p["best"], file, p["gap"] if String(p["gap"]) != "" else "Gxx", s["clip"]])
	L.append("```")
	L.append("")
	return "\n".join(L)
