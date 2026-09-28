extends SceneTree
## Runs a scenario once at its current parameter values and writes the sim trace as CSV in game units, in the
## frame of the start facing: tick, fwd, left, up (u), speed3d, speed_h, vel_v (u/s), loco.
##   godot --headless --path <project> -s res://tools_fit/route_export.gd -- --scenario=<json> --out=<csv>

const FitCore := preload("res://tools_fit/fit_core.gd")


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
		printerr("route_export: " + err)
		quit(1)
		return
	await core.harness.ready()
	var sim := core.simulate(core.init_vector())
	var pos: Array[Vector3] = sim["pos"]
	var vel: Array[Vector3] = sim["vel"]
	var loco: PackedInt32Array = sim["loco"]
	var names: Array = MoveState.Loco.keys()
	var yaw := deg_to_rad(float((core.scenario.get("start", {}) as Dictionary).get("yaw_deg", 0.0)))
	var fwd := Basis(Vector3.UP, yaw) * Vector3.FORWARD
	var left := Basis(Vector3.UP, yaw) * Vector3.LEFT
	var f := FileAccess.open(_arg("out"), FileAccess.WRITE)
	f.store_line("tick,fwd,left,up,speed3d,speed_h,vel_v,loco")
	for i in pos.size():
		var d := pos[i] - pos[0]
		var v := vel[i]
		f.store_line("%d,%.2f,%.2f,%.2f,%.1f,%.1f,%.1f,%s" % [i, d.dot(fwd) / FitCore.U, d.dot(left) / FitCore.U,
			d.y / FitCore.U, v.length() / FitCore.U, Vector2(v.x, v.z).length() / FitCore.U, v.y / FitCore.U, names[loco[i]]])
	f.close()
	core.harness.free_all()
	quit(0)
