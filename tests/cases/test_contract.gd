extends MoveTestCase
## Determinism, serialization, data and purity contracts (design §13.2).


func _demo_checksums(h: SimHarness, ticks: int) -> PackedInt64Array:
	var out := PackedInt64Array()
	for i in ticks:
		h.step(demo_cmd(h.state.tick + 1))
		out.append(h.state.checksum())
	return out


## spec: design §7.8 simulate() is deterministic and supports resimulation (T29)
func test_t29_determinism() -> void:
	var h := new_harness(&"full")
	await h.ready()
	h.suppress_sprint = false
	var spawn: Vector3 = h.info.get("spawn", Vector3.ZERO)
	h.spawn(spawn, 0.0)
	var a := _demo_checksums(h, 600)
	h.spawn(spawn, 0.0)
	var saved: MoveState = null
	var b := PackedInt64Array()
	for i in 600:
		if i == 300:
			saved = h.state.duplicate_state()
		h.step(demo_cmd(h.state.tick + 1))
		b.append(h.state.checksum())
	var first_diff := -1
	for i in a.size():
		if a[i] != b[i]:
			first_diff = i + 1
			break
	assert_eq(first_diff, -1, "first diverging tick between identical runs")
	# resimulate from tick 300
	h.state = saved
	h.sim.resimulating = true
	for i in 300:
		h.step(demo_cmd(h.state.tick + 1))
	h.sim.resimulating = false
	assert_eq(h.state.checksum(), b[599], "resimulated final checksum")
	done()


## spec: design §7.1 / §7.2 InputCmd and MoveState round trips (T30)
func test_t30_serialization() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var bad := 0
	for i in 1000:
		var c := InputCmd.create(rng.randi_range(0, 1 << 30), rng.randi() & InputCmd.BTN_MASK, rng.randi_range(-1, 1), rng.randi_range(-1, 1), rng.randf_range(-TAU, TAU), rng.randf_range(-1.5, 1.5))
		if not InputCmd.from_bytes(c.to_bytes()).equals(c):
			bad += 1
	assert_eq(bad, 0, "InputCmd byte round trip failures")
	var h := new_harness(&"full")
	await h.ready()
	h.suppress_sprint = false
	h.run(300, func(t: int) -> InputCmd: return demo_cmd(t))
	var copy := MoveState.from_dict(h.state.to_dict())
	assert_true(copy.equals(h.state), "MoveState dict round trip")
	assert_eq(copy.checksum(), h.state.checksum(), "checksum after round trip")
	done()


## spec: design §6 shipped params match the defaults and validate cleanly (T31)
func test_t31_params_resource() -> void:
	var res := load("res://data/movement/movement_params.tres") as MovementParams
	assert_true(res != null, "movement_params.tres loads as MovementParams")
	if res == null:
		done()
		return
	var def := MovementParams.new()
	var fields: Array[String] = [
		"ground_dash_durations", "air_dash_durations", "cost_ground_dash", "cost_air_dash",
		"cost_dash_jump_extra", "cost_air_jump", "cost_wall_jump_subsequent",
		"slide_friction", "slide_penalty_friction", "slide_penalty_friction_dash_jump",
		"zip_speed_inner", "zip_speed_outer", "sprint_delay", "sprint_instant_cap",
		"sprint_ramp_rate", "firing_speed_mult", "slow_floor_speed", "jump_speed", "gravity",
	]
	for f in fields:
		var a: Variant = res.get(f)
		var b: Variant = def.get(f)
		if typeof(a) == TYPE_FLOAT or typeof(b) == TYPE_FLOAT:
			assert_near(float(a), float(b), 1e-9, "param %s" % f)
		else:
			assert_true(a == b, "param %s: %s vs default %s" % [f, str(a), str(b)])
	var w := res.validate()
	assert_true(w.is_empty(), "validate() warnings: %s" % "; ".join(w))
	done()


## spec: design §7.8 purity: no engine input singleton in movement or tests (T32)
func test_t32_no_input_singleton() -> void:
	var re := RegEx.new()
	re.compile("\\bInput" + "\\.")
	var hits := PackedStringArray()
	for root in ["res://src/movement", "res://tests"]:
		for path in _gd_files(root):
			var f := FileAccess.open(path, FileAccess.READ)
			if f == null:
				continue
			var lines := f.get_as_text().split("\n")
			for i in lines.size():
				if re.search(lines[i]) != null:
					hits.append("%s:%d" % [path, i + 1])
	assert_true(hits.is_empty(), "singleton references: %s" % ", ".join(hits))
	done()


static func _gd_files(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	for sub in d.get_directories():
		out.append_array(_gd_files(dir_path.path_join(sub)))
	return out
