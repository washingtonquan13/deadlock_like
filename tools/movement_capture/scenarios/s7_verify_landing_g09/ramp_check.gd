extends SceneTree
## Verifier (independent of the analyst's ramp_replay.gd). Replays an s7_ramp scenario on a sim ramp and checks for
## "teleports" two ways, per tick:
##  1. displacement: |p[i]-p[i-1]| vs max(|v[i-1]|,|v[i]|)*dt  (flag if it exceeds by > 0.5 u: position moved more than
##     the velocity can explain = a snap);
##  2. floor gap: feet height minus the analytic floor height under the feet (flag steps in the gap > 1 u between ticks
##     while the gap is small, i.e. a vertical snap onto/off the surface).
## --shape=ramp (ArenaBuilder.add_ramp) | box (a rotated BoxShape slab, a second independent smooth slope)
##   | stairs (ArenaBuilder.add_stairs with 16 u risers, to show what a stair snap looks like in this check).
##   godot --headless --path . -s res://tools/movement_capture/scenarios/s7_verify_landing_g09/ramp_check.gd --
##     --scenario=res://tools/movement_capture/scenarios/s7_ramp/RWALK.json --shape=ramp [--angle=26.3]

const FitCore := preload("res://tools_fit/fit_core.gd")
const U := 0.0254
const TOP_U := 141.0   # flat before the crest (slopefit)
const RUN_U := 260.0


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
	await core.harness.ready()
	var ang := deg_to_rad(float(_arg("angle", "26.3")))
	var run := RUN_U * U
	var h := run * tan(ang)
	var z0 := -TOP_U * U          # crest (player runs toward -Z from z = 0)
	var z1 := z0 - run            # foot of the slope
	var root: Node3D = core.harness.root
	var shape := _arg("shape", "ramp")
	# raise everything by h so the flat top is at y = h and the bottom is the harness floor (y = 0)
	ArenaBuilder.add_box(root, Vector3(0, h * 0.5, z0 + 10.0), Vector3(10, h, 20), "Deck")
	match shape:
		"ramp":
			ArenaBuilder.add_ramp(root, Vector3(0, 0, z1), rad_to_deg(ang), run / cos(ang), 10.0, PI)
		"box":
			var b := ArenaBuilder.add_box(root, Vector3.ZERO, Vector3(10, 1.0, run / cos(ang) + 0.6), "Slab")
			# top face through (z0, h) and (z1, 0): centre 0.5 m below the face midpoint along the normal
			var n := Vector3(0, cos(ang), -sin(ang))
			b.rotation = Vector3(-ang, 0, 0)
			b.position = Vector3(0, h * 0.5, (z0 + z1) * 0.5) - n * 0.5
		"stairs":
			var step := 16.0 * U
			var count := int(ceil(h / step))
			var depth := run / float(count)
			# add_stairs rises toward local -Z; a parent turned 180 deg at the slope foot makes it rise toward +Z
			var par := Node3D.new()
			par.position = Vector3(0, 0, z1)
			par.rotation = Vector3(0, PI, 0)
			root.add_child(par)
			ArenaBuilder.add_stairs(par, Vector3.ZERO, step, depth, count, 10.0)
	core.scenario["start"]["pos_m"] = [0.0, h, 0.0]
	var sim := core.simulate(core.init_vector())
	var pos: Array[Vector3] = sim["pos"]
	var vel: Array[Vector3] = sim["vel"]
	var loco: PackedInt32Array = sim["loco"]
	var names: Array = MoveState.Loco.keys()
	var dt := 1.0 / 64.0
	var flags := 0
	var prev_gap := 0.0
	var out := FileAccess.open(_arg("out", "user://ramp_check.csv"), FileAccess.WRITE)
	out.store_line("tick,fwd_u,feet_u,floor_u,gap_u,disp_u,vdt_u,speed3d,loco")
	for i in pos.size():
		var z := pos[i].z
		var fl := h if z >= z0 else (0.0 if z <= z1 else h * (z - z1) / (z0 - z1))
		var gap := (pos[i].y - fl) / U
		var disp := 0.0
		var vdt := 0.0
		if i > 0:
			disp = (pos[i] - pos[i - 1]).length() / U
			vdt = maxf(vel[i - 1].length(), vel[i].length()) * dt / U
			var jump := disp > vdt + 0.5
			var gstep := absf(gap - prev_gap) > 1.0 and absf(gap) < 20.0 and absf(prev_gap) < 20.0
			if jump or gstep:
				flags += 1
				print("FLAG t%d fwd %.0f gap %.1f->%.1f disp %.1f vdt %.1f %s" % [i, -z / U, prev_gap, gap, disp, vdt, names[loco[i]]])
		prev_gap = gap
		out.store_line("%d,%.1f,%.2f,%.2f,%.2f,%.2f,%.2f,%.1f,%s" % [i, -z / U, pos[i].y / U, fl / U, gap, disp, vdt,
			vel[i].length() / U, names[loco[i]]])
	out.close()
	print("%s %s: flags %d, final fwd %.0f u" % [_arg("scenario").get_file(), shape, flags, -pos[pos.size() - 1].z / U])
	core.harness.free_all()
	quit(0)
