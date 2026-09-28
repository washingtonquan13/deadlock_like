extends SceneTree
## E: mantle max height. Builds a box ledge H u tall with its face FACE u ahead, W held from tick 1, jump at J,
## and reports whether a mantle happened (loco MANTLE seen, top reached) for each H, J and band-top override.
##   godot --headless --path . -s res://tools/movement_capture/scenarios/s7_fit_mantle_strafe/mantle_sweep.gd -- --tops=160,166,174
const FitCore := preload("res://tools_fit/fit_core.gd")
const HU := 0.0254
const OUT := "res://tools_fit/_out/s7_mantle_strafe/"
const FACE := 260.0


func _initialize() -> void:
	_run()


func _scenario(h: float, j: int, walk_ticks: int) -> String:
	var sc := {"name": "M%d_J%d" % [int(h), j], "up_axis": "z", "ticks": 150,
		"start": {"pos_m": [0, 0, 0], "yaw_deg": 0.0, "stamina": 3.0, "sprint_on": true},
		"suppress_sprint": false, "hero": "res://data/movement/heroes/hero_haze.tres",
		"default": {"move": [0, 0], "buttons": []},
		"timeline": [{"from": 1, "to": walk_ticks, "move": [0, 1]}, {"from": j, "to": j, "buttons": ["jump"]}],
		"geometry": [{"type": "box", "center": [0, h * HU / 2.0, -(FACE + 100.0) * HU], "size": [400 * HU, h * HU, 200 * HU]}],
		"params": [{"name": "air_accel", "min": 0, "max": 100}]}
	var p := OUT + "mantle_H%d_J%d.json" % [int(h), j]
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(JSON.stringify(sc, " "))
	f.close()
	return p


func _run() -> void:
	await process_frame
	var tops: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tops="):
			for t in a.substr(7).split(","):
				tops.append(int(t))
	if tops.is_empty():
		tops = [160]
	var names: Array = MoveState.Loco.keys()
	for top: int in tops:
		print("== mantle_band_tops_u last = %d" % top)
		for h: float in [150.0, 156.0, 160.0, 162.0, 164.0, 166.0, 168.0, 170.0, 174.0]:
			var line := "  H %3d:" % int(h)
			for j: int in [40, 44, 48, 52]:
				var core := FitCore.new()
				var err := core.setup(self, _scenario(h, j, 150))
				if err != "":
					printerr(err)
					quit(1)
					return
				await core.harness.ready()
				var bt: Array[int] = [64, 96, 128, top]
				core.base_params.mantle_band_tops_u = bt
				var sim := core.simulate(core.init_vector())
				var pos: Array[Vector3] = sim["pos"]
				var loco: PackedInt32Array = sim["loco"]
				var mant := false
				var ymax := -1e9
				for i in pos.size():
					ymax = maxf(ymax, pos[i].y / HU)
					if String(names[loco[i]]).begins_with("MANT"):
						mant = true
				line += "  J%d %s top%4.0f" % [j, "MANTLE" if mant else "no    ", ymax]
				core.harness.free_all()
			print(line)
	quit(0)
