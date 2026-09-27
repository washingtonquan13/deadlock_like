extends SceneTree
## Self-test of the fitting harness: for each example scenario, generate a "measured" CSV from the
## sim itself with known parameter values (extract.py format, z-up game units), fit it starting
## from the scenario's initial values, and check that the known values come back.
##   godot --headless --path <project> -s res://tools_fit/fit_selftest.gd [-- --quick]
## Cases per scenario:
##   clean : 120 fps samples, full precision        -> each parameter within 1 %
##   noisy :  60 fps, overlay rounding (0.01), +-1 u/s velocity noise, 0.3 u position noise,
##            5 % dropped rows, a pre-roll with an odd time offset -> each parameter within 3 %
## The A2 drag fraction truth (0.15) keeps the post-dash speed above air_dash_end_drag_floor; above ~0.26
## the floor takes over and the clip cannot tell values apart (the report flags that as FLAT).
## Writes its CSVs and fit outputs under res://tools_fit/_out/selftest (git- and Godot-ignored).
## Exit code 0 when every case passes.

const FitCore := preload("res://tools_fit/fit_core.gd")
const OUT := "res://tools_fit/_out/selftest"
const SCENARIOS := [
	{"path": "res://tools/movement_capture/scenarios/air_dash_after_dash_jump.json",
	 "truth": {"air_dash_distance": 7.1, "dash_jump_vertical_speed": 11.6, "dash_jump_set_speed": 14.8, "air_dash_end_drag_frac": 0.15}},
	{"path": "res://tools/movement_capture/scenarios/wall_jump_neutral.json",
	 "truth": {"wall_jump_up_speed": 8.3, "wall_jump_kick_neutral": 5.2, "wall_jump_tangent_keep": 0.8}},
	{"path": "res://tools/movement_capture/scenarios/air_dash_from_rest.json",
	 "truth": {"air_dash_distance": 7.4, "air_dash_end_drag_frac": 0.25}},
	{"path": "res://tools/movement_capture/scenarios/air_dash_angled.json",
	 "truth": {"air_dash_distance": 7.4, "air_dash_end_drag_frac": 0.15}},
	{"path": "res://tools/movement_capture/scenarios/wall_jump_neutral_angled.json",
	 "truth": {"wall_jump_up_speed": 8.3, "wall_jump_kick_neutral": 5.2, "wall_jump_tangent_keep": 0.8}},
	{"path": "res://tools/movement_capture/scenarios/dash_jump_flat.json",
	 "truth": {"dash_jump_set_speed": 14.8, "dash_jump_vertical_speed": 11.6, "gravity": 23.0}},
	{"path": "res://tools/movement_capture/scenarios/ground_dash_profile.json",
	 "truth": {"ground_dash_durations[0]": 0.58, "ground_dash_distance": 10.8}},
	{"path": "res://tools/movement_capture/scenarios/slide_hop_chain.json",
	 "truth": {"slide_hop_penalty_drag": 1.2, "slide_friction": 0.25}},
]

var _fail := 0
var _pass := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame  # the root viewport joins its World3D after _initialize
	DirAccess.make_dir_recursive_absolute(FitCore.globalize(OUT))
	_ensure_gdignore()
	for sc: Dictionary in SCENARIOS:
		for variant in ["clean", "noisy"]:
			await _case(sc, variant)
	print("fit_selftest: %d passed, %d failed" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)


func _ensure_gdignore() -> void:
	var p := FitCore.globalize("res://tools_fit/_out/.gdignore")
	if not FileAccess.file_exists(p):
		var f := FileAccess.open(p, FileAccess.WRITE)
		if f != null:
			f.close()


func _case(sc: Dictionary, variant: String) -> void:
	var core := FitCore.new()
	var err := core.setup(self, sc["path"])
	if err != "":
		_check(false, "%s setup: %s" % [sc["path"], err])
		return
	await core.harness.ready()
	var tag := "%s/%s" % [String(core.scenario.get("clip", "?")), variant]
	# truth vector (skipped optional params are simply not part of the test)
	var truth := core.init_vector()
	var truth_d: Dictionary = sc["truth"]
	for i in core.specs.size():
		var n: String = core.specs[i]["name"]
		if truth_d.has(n):
			truth[i] = float(truth_d[n])
	var sim := core.simulate(truth)
	var csv := OUT.path_join("%s_%s.csv" % [String(core.scenario.get("clip", "x")), variant])
	_write_measured(sim, FitCore.globalize(csv), variant)
	err = core.load_measured(FitCore.globalize(csv))
	if err != "":
		_check(false, tag + " load: " + err)
		core.harness.free_all()
		return
	var e_truth := core.evaluate(truth)
	var out_dir := OUT.path_join("%s_%s_fit" % [String(core.scenario.get("clip", "x")), variant])
	var s := core.run_and_write(FitCore.globalize(out_dir))
	var tol := 0.01 if variant == "clean" else 0.03
	print("%s: cost at truth %s, init %s, best %s, %d runs, %.1f s, t0 %.4f" % [tag, String.num_scientific(e_truth["cost"]), String.num_scientific(s["cost_init"]), String.num_scientific(s["cost_best"]), s["evals"], s["seconds"], s["t0_measured"]])
	for i in core.specs.size():
		var p: Dictionary = s["params"][i]
		var rel := absf(float(p["best"]) - truth[i]) / maxf(absf(truth[i]), 1e-9)
		_check(rel <= tol, "%s %s: truth %.6f, init %.6f, fitted %.6f (rel err %.3f%%, tol %.0f%%)" % [
			tag, p["name"], truth[i], p["init"], p["best"], rel * 100.0, tol * 100.0])
	for w in core.warnings:
		print("  warning: " + w)
	core.harness.free_all()


## Samples the sim like a recording would (linear interpolation between ticks, as the overlay
## shows render-interpolated values) and writes an extract.py-style CSV in z-up game units.
func _write_measured(sim: Dictionary, path: String, variant: String) -> void:
	var fps := 120.0 if variant == "clean" else 60.0
	var t_off := 0.5 if variant == "clean" else 0.8137  # video time of tick 0
	var pre := 0.25
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var ts: PackedFloat64Array = sim["t"]
	var t_end := ts[ts.size() - 1]
	var lines := PackedStringArray(["frame,t,pos_x,pos_y,pos_z,vel_x,vel_y,vel_z,speed_h,speed_v,vel_source,dup,valid,flags"])
	var k := 0
	var t_vid := t_off - pre
	# first frame at or after (t_off - pre) on the video's frame grid
	k = int(ceil(t_vid * fps))
	while true:
		var tv := float(k) / fps
		var tr := tv - t_off
		if tr > t_end:
			break
		var p := _sample(ts, sim["pos"], tr)
		var v := _sample(ts, sim["vel"], tr)
		var pz := FitCore.godot_to_zup(p) / FitCore.U
		var vz := FitCore.godot_to_zup(v) / FitCore.U
		var valid := 1
		if variant == "noisy":
			pz += Vector3(rng.randfn(0.0, 0.3), rng.randfn(0.0, 0.3), rng.randfn(0.0, 0.3))
			vz += Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
			pz = Vector3(snappedf(pz.x, 0.01), snappedf(pz.y, 0.01), snappedf(pz.z, 0.01))
			vz = Vector3(snappedf(vz.x, 0.01), snappedf(vz.y, 0.01), snappedf(vz.z, 0.01))
			if rng.randf() < 0.05:
				valid = 0
		lines.append("%d,%.6f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,readout,0,%d," % [k, tv, pz.x, pz.y, pz.z, vz.x, vz.y, vz.z,
			Vector2(vz.x, vz.y).length(), vz.z, valid])
		k += 1
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()


static func _sample(ts: PackedFloat64Array, arr: Array, t: float) -> Vector3:
	if t <= 0.0:
		return arr[0]
	var i := int(floor(t / (ts[1] - ts[0])))
	if i >= ts.size() - 1:
		return arr[ts.size() - 1]
	var a := (t - ts[i]) / (ts[i + 1] - ts[i])
	return (arr[i] as Vector3).lerp(arr[i + 1], a)


func _check(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("PASS " + msg)
	else:
		_fail += 1
		print("FAIL " + msg)
