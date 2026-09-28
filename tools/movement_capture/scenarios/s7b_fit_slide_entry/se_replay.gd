extends SceneTree
## s7b: flat-ground replay of a scenario with optional scratch param overrides (--set=name=value,...).
## Writes tick,t,fwd,speed_h,loco (game units).

const FitCore := preload("res://tools_fit/fit_core.gd")
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
	var core := FitCore.new()
	var err := core.setup(self, _arg("scenario"))
	if err != "":
		printerr("se_replay: " + err)
		quit(1)
		return
	await core.harness.ready()
	var sets := _arg("set", "")
	if sets != "":
		for kv in sets.split(","):
			var parts := kv.split("=")
			core.base_params.set(parts[0], float(parts[1]))
			print("set %s = %s" % [parts[0], core.base_params.get(parts[0])])
	var on0 := _arg("onset0", "")
	if on0 != "":
		var tb: Array[float] = core.base_params.slide_onset_table.duplicate()
		tb[0] = float(on0)
		core.base_params.slide_onset_table = tb
		print("set onset0 = ", tb)
	var sim := core.simulate(core.init_vector())
	var pos: Array[Vector3] = sim["pos"]
	var vel: Array[Vector3] = sim["vel"]
	var loco: PackedInt32Array = sim["loco"]
	var names: Array = MoveState.Loco.keys()
	var f := FileAccess.open(_arg("out"), FileAccess.WRITE)
	f.store_line("tick,t,fwd,speed_h,loco")
	for i in pos.size():
		var v := vel[i]
		f.store_line("%d,%.4f,%.2f,%.1f,%s" % [i, float(i) / 64.0, -(pos[i] - pos[0]).z / U, Vector2(v.x, v.z).length() / U, names[loco[i]]])
	f.close()
	core.harness.free_all()
	quit(0)
