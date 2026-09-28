extends SceneTree
## Verifier's own ramp replay (independent of s7_fit_ramp): straight downhill ramp along the start facing
## (no fall-line offset), flat top, 26.5 deg, 127.7 u drop, flat bottom. Per tick: horizontal / 3D speed,
## vertical velocity, loco, and "jump" = |dp - (v_prev + v)/2 * dt| in u (position change the velocity
## does not explain; a true teleport would show as a large value).
##   godot --headless --path . -s res://tools/movement_capture/scenarios/s7_verify_ramp/vramp.gd -- --scenario=<json> --out=<csv> [--start=top|bot]
const FitCore := preload("res://tools_fit/fit_core.gd")
const U := 0.0254

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
	var ang := 26.5
	var drop := 127.7 * U
	var run := drop / tan(deg_to_rad(ang))
	var edge := 141.0 * U
	# top flat: z in [-edge, +10]; slope from z=-edge down to z=-edge-run; bottom flat is the harness floor (y=0) if any, add one anyway
	ArenaBuilder.add_box(core.harness.root, Vector3(0, drop * 0.5, -edge + 15.0), Vector3(40, drop, 30), "Top")
	ArenaBuilder.add_ramp(core.harness.root, Vector3(0, 0, -edge - run), ang, run / cos(deg_to_rad(ang)), 40.0, PI)
	ArenaBuilder.add_box(core.harness.root, Vector3(0, -0.5, -edge - run - 30.0), Vector3(40, 1.0, 60.0), "Bottom")
	await core.harness.ready()
	var p0 := Vector3(0, drop, 0)
	var yaw := 0.0
	if _arg("start", "top") == "bot":
		p0 = Vector3(0, 0.0, -edge - run - 135.0 * U)
		yaw = PI
	core.scenario["start"]["pos_m"] = [p0.x, p0.y, p0.z]
	core.scenario["start"]["yaw_deg"] = rad_to_deg(yaw)
	core.scenario["default"]["yaw_deg"] = rad_to_deg(yaw)
	core._build_cmds()
	var sim := core.simulate(core.init_vector())
	var pos: Array[Vector3] = sim["pos"]
	var vel: Array[Vector3] = sim["vel"]
	var loco: PackedInt32Array = sim["loco"]
	var names: Array = MoveState.Loco.keys()
	var f := FileAccess.open(_arg("out"), FileAccess.WRITE)
	f.store_line("tick,t,y,h,s3,vy,loco,jump")
	for i in pos.size():
		var v := vel[i]
		var j := 0.0
		if i > 0:
			j = ((pos[i] - pos[i - 1]) - (vel[i - 1] + v) * 0.5 / 64.0).length() / U
		f.store_line("%d,%.4f,%.2f,%.1f,%.1f,%.1f,%s,%.2f" % [i, i / 64.0, (pos[i].y - p0.y) / U, Vector2(v.x, v.z).length() / U, v.length() / U, v.y / U, names[loco[i]], j])
	f.close()
	core.harness.free_all()
	quit(0)
