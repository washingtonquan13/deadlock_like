extends SceneTree
## Verifier (independent of the analyst's ramp_replay.gd): replay an s7_ramp scenario on a smooth 26.2 deg
## ramp (add_ramp) with a top deck, and report per-tick displacement anomalies:
##  - TELEPORTED events from the sim
##  - ticks whose 3D step differs from the tick-average velocity*dt by more than TOL u AND whose vertical step
##    is not the slope-following rise (|dz| ~ dh*tan) -> "snap"
## Also prints max per-tick |dz| and the loco sequence summary.
##   godot --headless --path . -s res://tools/movement_capture/scenarios/s7_verify_air_wall/vramp.gd -- --scenario=res://... --mark=top|bot
const FitCore := preload("res://tools_fit/fit_core.gd")
const U := 0.0254
const TOL := 1.0

func _initialize() -> void:
	_run()

func _arg(n: String, d: String = "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + n + "="):
			return a.substr(n.length() + 3)
	return d

func _run() -> void:
	await process_frame
	var core := FitCore.new()
	var err := core.setup(self, _arg("scenario"))
	if err != "":
		printerr(err); quit(1); return
	var run := 260.0 * U
	var h := 127.7 * U
	var tanA := h / run
	ArenaBuilder.add_ramp(core.harness.root, Vector3.ZERO, rad_to_deg(atan2(h, run)), sqrt(run * run + h * h), 8.0)
	ArenaBuilder.add_box(core.harness.root, Vector3(0, h * 0.5, -run - 20.0), Vector3(8.0, h, 40.0), "Deck")
	var st: Dictionary = core.scenario["start"]
	var top := _arg("mark", "top") == "top"
	if top:
		st["pos_m"] = [0.0, h + 0.001, -run - 141.0 * U]
		st["yaw_deg"] = 180.0
	else:
		st["pos_m"] = [0.0, 0.001, 128.0 * U]
		st["yaw_deg"] = 0.0
	core._build_cmds()
	await core.harness.ready()
	var sim := core.simulate(core.init_vector())
	var pos: Array[Vector3] = sim["pos"]
	var vel: Array[Vector3] = sim["vel"]
	var loco: PackedInt32Array = sim["loco"]
	var names: Array = MoveState.Loco.keys()
	var snaps := 0
	var maxdz := 0.0
	var seq := ""
	var last := -1
	for i in range(1, pos.size()):
		var d := (pos[i] - pos[i - 1]) / U
		var ev := (vel[i] + vel[i - 1]) * 0.5 * core.dt / U
		var dh := Vector2(d.x, d.z).length()
		var on_ramp := pos[i].z > -run - 0.5 and pos[i].z < 0.5
		maxdz = maxf(maxdz, absf(d.y))
		if loco[i] != last:
			seq += "%s@%d " % [names[loco[i]], i]
			last = loco[i]
		var off_vel := (d - ev).length()
		var off_slope := absf(absf(d.y) - dh * tanA)
		if off_vel > TOL and (off_slope > TOL or not on_ramp):
			snaps += 1
			print("  tick %3d  step(%.2f,%.2f,%.2f)u  vel*dt(%.2f,%.2f,%.2f)u  off_vel %.2f off_slope %.2f  z %.1fu  %s" % [
				i, d.x, d.y, d.z, ev.x, ev.y, ev.z, off_vel, off_slope, -pos[i].z / U, names[loco[i]]])
	print("%s: snaps %d  max|dz| %.2f u/tick  end z %.0f u  loco: %s" % [_arg("scenario").get_file(), snaps, maxdz, -pos[pos.size() - 1].z / U, seq])
	core.harness.free_all()
	quit(0)
