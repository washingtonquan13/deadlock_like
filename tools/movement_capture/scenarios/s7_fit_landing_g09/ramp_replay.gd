extends SceneTree
## Replays an s7_ramp scenario on a sim copy of ramp1 (ArenaBuilder.add_ramp at the measured angle) and
## flags "teleports": ticks whose vertical position change does not match the velocity integrated
## that tick (|dz - vz*dt| > 1 u), i.e. a step-up / step-down snap rather than motion.
##   godot --headless --path . -s res://tools/movement_capture/scenarios/s7_fit_landing_g09/ramp_replay.gd --
##     --scenario=res://tools/movement_capture/scenarios/s7_ramp/RWALK.json --start=top --out=<csv>
##     [--angle=26.3] [--set=param:value,...]   (scratch param overrides, src untouched)

const FitCore := preload("res://tools_fit/fit_core.gd")
const U := 0.0254
# measured (slopefit.py): top edge 141 u ahead of ramp1_top, 260 u run, 128 u drop; ramp1_bot 135 u before the bottom edge
const TOP_EDGE_U := 141.0
const RUN_U := 260.0
const BOT_EDGE_U := 135.0


func _initialize() -> void:
	_run()


func _arg(name: String, default: String = "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.substr(name.length() + 3)
	return default


func _run() -> void:
	await process_frame
	var core := FitCore.new()
	var err := core.setup(self, _arg("scenario"))
	if err != "":
		printerr(err)
		quit(1)
		return
	var sets := _arg("set")
	if sets != "":
		for kv in sets.split(","):
			var p := kv.split(":")
			core.base_params.set(p[0], float(p[1]))
	await core.harness.ready()
	var ang := float(_arg("angle", "26.3"))
	var run := RUN_U * U
	var h := run * tan(deg_to_rad(ang))
	var length := run / cos(deg_to_rad(ang))
	var root: Node3D = core.harness.root
	var start := _arg("start", "top")
	var p0 := Vector3.ZERO
	if start == "top":
		var ztop := -TOP_EDGE_U * U
		ArenaBuilder.add_box(root, Vector3(0, h * 0.5, ztop + 10.0), Vector3(8, h, 20), "Top")
		ArenaBuilder.add_ramp(root, Vector3(0, 0, ztop - run), ang, length, 8.0, PI)
		p0 = Vector3(0, h, 0)
	else:
		var zb := -BOT_EDGE_U * U
		ArenaBuilder.add_ramp(root, Vector3(0, 0, zb), ang, length, 8.0)
		ArenaBuilder.add_box(root, Vector3(0, h * 0.5, zb - run - 10.0), Vector3(8, h, 20), "Top")
	core.scenario["start"]["pos_m"] = [p0.x, p0.y, p0.z]
	var sim := core.simulate(core.init_vector())
	var pos: Array[Vector3] = sim["pos"]
	var vel: Array[Vector3] = sim["vel"]
	var loco: PackedInt32Array = sim["loco"]
	var names: Array = MoveState.Loco.keys()
	var f := FileAccess.open(_arg("out"), FileAccess.WRITE)
	f.store_line("tick,fwd,up,speed3d,speed_h,vel_v,dz_minus_vzdt,loco")
	var snaps := 0
	for i in pos.size():
		var d := pos[i] - pos[0]
		var mis := 0.0
		if i > 0:
			mis = ((pos[i].y - pos[i - 1].y) - vel[i].y / 64.0) / U
			if absf(mis) > 1.0:
				snaps += 1
				print("SNAP tick %d fwd %.0f u up %.1f u  dz-vz*dt %+.1f u  loco %s" % [i, -d.z / U, d.y / U, mis, names[loco[i]]])
		var v := vel[i]
		f.store_line("%d,%.2f,%.2f,%.1f,%.1f,%.1f,%.2f,%s" % [i, -d.z / U, d.y / U, v.length() / U,
			Vector2(v.x, v.z).length() / U, v.y / U, mis, names[loco[i]]])
	f.close()
	print("snaps: %d  (ramp %.1f deg, drop %.0f u)" % [snaps, ang, h / U])
	core.harness.free_all()
	quit(0)
