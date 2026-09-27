extends SceneTree
## Headless parameter fit of MovementSim against a measured recording (extract.py CSV).
##   godot --headless --path <project> -s res://tools_fit/fit_runner.gd -- \
##       --scenario=res://tools/movement_capture/scenarios/air_dash_after_dash_jump.json \
##       --measured=C:/rec/out/A2_default_t1.csv --out=C:/rec/out/fit_A2_t1 [--init=best_params.json]
## Writes best_params.json, residuals.csv, sim_best_trace.csv and report.md to --out.
## Never writes .tres files: applying values is a separate, reviewed step.
## Exit code: 0 ok, 1 error.

const FitCore := preload("res://tools_fit/fit_core.gd")


func _initialize() -> void:
	_run()


func _arg(name: String, default: String = "") -> String:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--" + name + "="):
			return a.substr(name.length() + 3)
	return default


func _run() -> void:
	await process_frame  # the root viewport joins its World3D after _initialize
	var sc := _arg("scenario")
	var me := _arg("measured")
	var out := _arg("out")
	if sc == "" or me == "" or out == "":
		printerr("usage: -s res://tools_fit/fit_runner.gd -- --scenario=<json> --measured=<csv> --out=<dir> [--init=<best_params.json>]")
		quit(1)
		return
	var core := FitCore.new()
	var err := core.setup(self, sc)
	if err != "":
		printerr("fit: " + err)
		quit(1)
		return
	await core.harness.ready()
	err = core.load_measured(me)
	if err != "":
		printerr("fit: " + err)
		core.harness.free_all()
		quit(1)
		return
	var init := _arg("init")
	if init != "":
		# start from a previous result (e.g. another trial of the same clip)
		var prev: Variant = FitCore.read_json(init)
		if typeof(prev) == TYPE_DICTIONARY:
			for p: Dictionary in prev.get("params", []):
				for s in core.specs:
					if s["name"] == p["name"]:
						s["init"] = clampf(float(p["best"]), float(s["min"]), float(s["max"]))
	for w in core.warnings:
		print("fit: warning: " + w)
	var s := core.run_and_write(out)
	print("fit: %d sim runs, cost %s -> %s, t0 = %.4f s" % [s["evals"], String.num_scientific(s["cost_init"]), String.num_scientific(s["cost_best"]), s["t0_measured"]])
	for p: Dictionary in s["params"]:
		print("  %-32s %.6f  (init %.6f, bounds [%.6f, %.6f])%s" % [p["name"], p["best"], p["init"], p["min"], p["max"], "  AT BOUND" if p["at_bound"] else ""])
	for c: String in (s["rmse_best"] as Dictionary).keys():
		print("  rmse %-8s %.2f (was %.2f)" % [c, s["rmse_best"][c], float((s["rmse_init"] as Dictionary).get(c, NAN))])
	print("fit: report %s" % FitCore.globalize(out.path_join("report.md")))
	core.harness.free_all()
	quit(0)
