extends SceneTree
## s7 ramp replay: runs an s7_ramp scenario JSON in the sim on a ramp built to the measured game geometry and
## writes a per-tick CSV (game units, start-facing frame) with a per-tick "snap" column: the part of the tick's
## displacement that the velocity does not explain (u). Large snap = the sim teleported the capsule.
##   godot --headless --path . -s res://tools/movement_capture/scenarios/s7_fit_ramp/ramp_replay.gd --
##     --scenario=res://tools/movement_capture/scenarios/s7_ramp/RRUN.json --out=tools_fit/_out/s7_ramp/x.csv
##     [--start=top|slope|bot] [--angle=26.5] [--fall_off=7.8] [--set=name=value,name=value]
##     [--patch=s7_h=1,s7_a=1,...]  scratch slope-slide rule, see s7_patch.gd
## Geometry (measured, slopefit.py): flat top, slope 128 u drop at 26.5 deg along the fall line, the path
## crosses the top edge 141 u after the ramp1_top start, fall line 7.8 deg right of the start facing.

const FitCore := preload("res://tools_fit/fit_core.gd")
const S7Patch := preload("res://tools/movement_capture/scenarios/s7_fit_ramp/s7_patch.gd")
const U := 0.0254


func _initialize() -> void:
	_run()


func _arg(name: String, default: String = "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.substr(name.length() + 3)
	return default


func _run() -> void:
	await process_frame
	var patch := _arg("patch", "")
	if patch != "":
		var opts := {}
		for kv in patch.split(","):
			var parts := kv.split("=")
			opts[parts[0]] = float(parts[1])
		print("patch ", opts)
		S7Patch.apply(opts)
	var core := FitCore.new()
	var err := core.setup(self, _arg("scenario"))
	if err != "":
		printerr("ramp_replay: " + err)
		quit(1)
		return
	var ang := float(_arg("angle", "26.5"))
	var off := deg_to_rad(float(_arg("fall_off", "7.8")))
	var drop := 127.7 * U
	var run := drop / tan(deg_to_rad(ang))
	var edge_d := 141.0 * U
	var pivot := Node3D.new()
	pivot.name = "RampPivot"
	pivot.position = Vector3(0.0, 0.0, -edge_d)
	pivot.rotation = Vector3(0.0, -off, 0.0)
	core.harness.root.add_child(pivot)
	var w := 40.0
	ArenaBuilder.add_box(pivot, Vector3(0.0, drop * 0.5, 15.0), Vector3(w, drop, 30.0), "RampTop")
	ArenaBuilder.add_ramp(pivot, Vector3(0.0, 0.0, -run), ang, run / cos(deg_to_rad(ang)), w, PI)
	await core.harness.ready()
	var start := _arg("start", "top")
	var yaw0 := 0.0
	var p0 := Vector3(0.0, drop, 0.0)
	if start == "slope":
		# ramp1_slope: ~16 u past the top edge along the facing, on the surface (8 u below the top)
		var dd := 16.0 * U
		p0 = Vector3(0.0, drop - dd * cos(off) * tan(deg_to_rad(ang)) + 0.002, -edge_d - dd)
	elif start == "bot":
		# ramp1_bot: on the bottom flat 135 u before the bottom edge, facing uphill (fall line + 180 + 2.5 deg)
		var fall := Basis(Vector3.UP, -off) * Vector3.FORWARD
		var be := Vector3(0.0, 0.0, -edge_d) + fall * run
		p0 = be + fall * (135.0 * U)
		p0.y = 0.0
		yaw0 = -off + PI + deg_to_rad(float(_arg("bot_yaw_off", "0.0")))
	core.scenario["start"]["pos_m"] = [p0.x, p0.y, p0.z]
	core.scenario["start"]["yaw_deg"] = rad_to_deg(yaw0)
	core.scenario["default"]["yaw_deg"] = rad_to_deg(yaw0)
	core._build_cmds()
	var sets := _arg("set", "")
	if sets != "":
		for kv in sets.split(","):
			var parts := kv.split("=")
			core.base_params.set(parts[0], float(parts[1]))
			print("set %s = %s" % [parts[0], core.base_params.get(parts[0])])
	var sim := core.simulate(core.init_vector())
	var pos: Array[Vector3] = sim["pos"]
	var vel: Array[Vector3] = sim["vel"]
	var loco: PackedInt32Array = sim["loco"]
	var names: Array = MoveState.Loco.keys()
	var fwd := Basis(Vector3.UP, yaw0) * Vector3.FORWARD
	var left := Basis(Vector3.UP, yaw0) * Vector3.LEFT
	var f := FileAccess.open(_arg("out"), FileAccess.WRITE)
	f.store_line("tick,t,fwd,left,up,speed3d,speed_h,vel_v,loco,snap")
	var max_snap := 0.0
	var max_snap_tick := 0
	for i in pos.size():
		var d := pos[i] - pos[0]
		var v := vel[i]
		var snap := 0.0
		if i > 0:
			# displacement not explained by the velocity before or after the tick
			var dp := pos[i] - pos[i - 1]
			snap = minf((dp - vel[i - 1] / 64.0).length(), (dp - vel[i] / 64.0).length()) / U
			if snap > max_snap:
				max_snap = snap
				max_snap_tick = i
		f.store_line("%d,%.4f,%.2f,%.2f,%.2f,%.1f,%.1f,%.1f,%s,%.2f" % [i, float(i) / 64.0, d.dot(fwd) / U, d.dot(left) / U,
			d.y / U, v.length() / U, Vector2(v.x, v.z).length() / U, v.y / U, names[loco[i]], snap])
	f.close()
	print("max snap %.2f u at tick %d" % [max_snap, max_snap_tick])
	core.harness.free_all()
	quit(0)
