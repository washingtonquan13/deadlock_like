extends SceneTree
## Runs a fit scenario once at its current parameter values and prints the sim trace: every locomotion
## change plus every Nth tick. Use it to check or line up a scenario timeline (jump / dash / crouch ticks)
## before fitting.
##   godot --headless --path <project> -s res://tools_fit/scenario_probe.gd -- \
##       --scenario=res://tools/movement_capture/scenarios/slide_hop_chain.json [--every=8]
## Speeds are printed in game units (u/s), positions in meters. Exit code: 0 ok, 1 error.

const FitCore := preload("res://tools_fit/fit_core.gd")


func _initialize() -> void:
	_run()


func _arg(name: String, default: String = "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.substr(name.length() + 3)
	return default


func _run() -> void:
	await process_frame  # the root viewport joins its World3D after _initialize
	var sc := _arg("scenario")
	if sc == "":
		printerr("usage: -s res://tools_fit/scenario_probe.gd -- --scenario=<json> [--every=8]")
		quit(1)
		return
	var every := maxi(1, int(_arg("every", "8")))
	var core := FitCore.new()
	var err := core.setup(self, sc)
	if err != "":
		printerr("probe: " + err)
		quit(1)
		return
	await core.harness.ready()
	var sim := core.simulate(core.init_vector())
	var names: Array = MoveState.Loco.keys()
	var ts: PackedFloat64Array = sim["t"]
	var pos: Array[Vector3] = sim["pos"]
	var vel: Array[Vector3] = sim["vel"]
	var loco: PackedInt32Array = sim["loco"]
	print("probe: %s (%d ticks)" % [String(core.scenario.get("name", sc)), ts.size() - 1])
	print("tick      t  loco         speed_h   vel_v   pos_y   dist_h")
	for i in ts.size():
		var changed := i > 0 and loco[i] != loco[i - 1]
		if i % every != 0 and not changed and i != ts.size() - 1:
			continue
		var h := Vector2(vel[i].x, vel[i].z).length() / FitCore.U
		var d := Vector2(pos[i].x - pos[0].x, pos[i].z - pos[0].z).length()
		print("%4d %6.3f  %-11s %8.1f %7.1f %7.3f %8.3f%s" % [i, ts[i], names[loco[i]], h, vel[i].y / FitCore.U,
			pos[i].y, d, "  <-" if changed else ""])
	core.harness.free_all()
	quit(0)
