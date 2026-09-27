extends MoveTestCase
## Arena layout smoke test (design §11).


func test_arena_full_layout() -> void:
	var h := new_harness(&"full")
	await h.ready()
	var markers: Dictionary = h.info.get("markers", {})
	for m in ["01_spawn", "02_sprint_lane", "03_ramp_20", "04_slide_slope", "05_stairs_18u", "06_walls_corridor", "07_mantle_064u", "08_zipline", "09_rope", "10_jump_gauge"]:
		assert_true(markers.has(m), "marker %s" % m)
	assert_eq(h.sim.ziplines.size(), 2, "ziplines found")
	assert_eq(h.sim.ropes.size(), 1, "ropes found")
	assert_true(h.state.grounded, "spawn is grounded")
	h.run(64, hold(0, 0, 1))
	assert_true(h.state.grounded and h.state.horizontal_speed() > 6.0, "can walk from spawn")
	done()
