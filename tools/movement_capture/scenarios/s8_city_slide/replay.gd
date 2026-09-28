extends SceneTree
## s8 city stair-ramp slides (video OCR of cl_showpos, rec/2026-09-28 *.mp4): replays a run-up, a crouch at the
## top edge and a slide down a straight ramp onto a long flat, and prints per-tick horizontal speed and height (u).
##   godot --headless --path . -s res://tools/movement_capture/scenarios/s8_city_slide/replay.gd --
##     --angle=30 --drop=413 --runup=150 [--crouch_at=0] [--entry=0] [--set=name=value,...]
## runup: flat distance (u) from the spawn to the top edge; crouch_at: distance (u) past the edge where crouch is held.

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
	var params := MovementParams.new()
	var sets := _arg("set", "")
	if sets != "":
		for kv in sets.split(","):
			var parts := kv.split("=")
			params.set(parts[0], float(parts[1]))
	var h := SimHarness.create(self, &"flat", params, load(_arg("hero", "res://data/movement/heroes/hero_haze.tres")))
	var ang := float(_arg("angle", "30"))
	var drop := float(_arg("drop", "413")) * U
	var runup := float(_arg("runup", "150")) * U
	var crouch_at := float(_arg("crouch_at", "0")) * U
	var run := drop / tan(deg_to_rad(ang))
	ArenaBuilder.add_box(h.root, Vector3(0.0, drop * 0.5, 20.0), Vector3(20.0, drop, 40.0), "Top")
	ArenaBuilder.add_ramp(h.root, Vector3(0.0, 0.0, -run), ang, run / cos(deg_to_rad(ang)), 20.0, PI)
	h.suppress_sprint = false
	await h.ready()
	h.spawn(Vector3(0.0, drop + 0.01, runup), 0.0)
	var st := h.state
	# the clips start mid-run with sprint already on: arm the sprint timer and set the entry speed (u/s, along -z)
	st.sprint_timer_ticks = 100000
	var entry := float(_arg("entry", "0")) * U
	if entry > 0.0:
		st.velocity = Vector3(0.0, 0.0, -entry)
	print("t,hs,y,loco")
	for i in 320:
		var b := 0
		if st.position.z < -crouch_at:
			b = InputCmd.BTN_CROUCH
		h.step(InputCmd.create(st.tick + 1, b, 0, 1, 0.0, 0.0))
		print("%.4f,%.2f,%.2f,%d" % [float(i + 1) / 64.0, st.horizontal_speed() / U, st.position.y / U, st.loco])
	quit(0)
