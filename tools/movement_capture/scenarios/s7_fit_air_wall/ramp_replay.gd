extends SceneTree
## s7 ramp replay (analyst scratch). Builds the game's ramp1 as a smooth add_ramp (26.2 deg, 260 u run, 128 u drop,
## measured by scenarios/s7_ramp/slopefit.py) with a flat top deck, replays an s7_ramp scenario from the matching
## mark and writes per-tick CSV plus "jump" rows where the per-tick displacement disagrees with velocity*dt
## (a teleport / snap). Param overrides for a scratch test: --set=name:value[,name:value] (MovementParams fields).
##   godot --headless --path . -s res://tools/movement_capture/scenarios/s7_fit_air_wall/ramp_replay.gd --
##        --scenario=res://tools/movement_capture/scenarios/s7_ramp/RWALK.json --mark=top --out=tools_fit/_out/s7_air_wall/x.csv

const FitCore := preload("res://tools_fit/fit_core.gd")
const U := 0.0254
const RUN_U := 260.0
const DROP_U := 127.7


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
	for kv in _arg("set", "").split(",", false):
		var p := kv.split(":")
		var e := core._resolve(p[0])
		if e.is_empty():
			printerr("no param " + p[0]); quit(1); return
		FitCore._set_value(core.base_params, core.base_hero, e, float(p[1]))
		print("override %s = %s" % [p[0], p[1]])
	var run := RUN_U * U
	var h := DROP_U * U
	var ang := rad_to_deg(atan2(h, run))
	ArenaBuilder.add_ramp(core.harness.root, Vector3(0, 0, 0), ang, sqrt(run * run + h * h), 6.0)
	ArenaBuilder.add_box(core.harness.root, Vector3(0, h * 0.5, -run - 15.0), Vector3(6.0, h, 30.0), "Deck")
	var st: Dictionary = core.scenario["start"]
	if _arg("mark", "top") == "top":
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
	var fwd := Vector3(0, 0, 1) if _arg("mark", "top") == "top" else Vector3(0, 0, -1)
	var dt := core.dt
	var f := FileAccess.open(_arg("out"), FileAccess.WRITE)
	f.store_line("tick,d,up,speed_h,vel_v,dz_tick,vz_dt,loco")
	var jumps := 0
	for i in pos.size():
		var d := pos[i] - pos[0]
		var v := vel[i]
		var dz := 0.0
		var ez := 0.0
		if i > 0:
			dz = (pos[i].y - pos[i - 1].y) / U
			ez = vel[i].y * dt / U
			# a snap: the tick's rise/drop is > 1.5 u off what the velocity explains AND off the slope-following rise
			var dh := Vector2(pos[i].x - pos[i - 1].x, pos[i].z - pos[i - 1].z).length() / U
			var slope_dz := dh * DROP_U / RUN_U
			if absf(dz - ez) > 1.5 and absf(absf(dz) - slope_dz) > 1.5:
				jumps += 1
				print("SNAP tick %d  dz %.2f u  vel*dt %.2f u  slope-follow %.2f u  d %.1f  %s" % [i, dz, ez, slope_dz, d.dot(fwd) / U, names[loco[i]]])
		f.store_line("%d,%.2f,%.2f,%.1f,%.1f,%.2f,%.2f,%s" % [i, d.dot(fwd) / U, d.y / U,
			Vector2(v.x, v.z).length() / U, v.y / U, dz, ez, names[loco[i]]])
	f.close()
	print("snaps: %d" % jumps)
	core.harness.free_all()
	quit(0)
