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


## City map smoke test: base spawn, the subway floor, the canal bed, and a subway rail you can
## board with jump + jump near the apex.
func test_city_layout() -> void:
	var h := new_harness(&"city")
	await h.ready()
	assert_true(h.sim.ziplines.size() >= 6 and h.sim.ropes.size() > 0, "rails and ropes found")
	assert_true(h.state.grounded and h.state.position.y > 6.5, "spawn is grounded on the base plateau")
	h.run(64, hold(0, 0, 1))
	assert_true(h.state.grounded and h.state.horizontal_speed() > 6.0, "can walk from spawn")
	# subway floor
	h.spawn(Vector3(-320.0, -9.8, 0.0), 0.0)
	h.run(32, hold())
	assert_true(h.state.grounded and absf(h.state.position.y + 10.0) < 0.3, "stands in the subway")
	# canal bed
	var bed := CityMapBuilder.su(100.0, CityMapBuilder.meander(100.0))
	h.spawn(Vector3(bed.x, -3.3, bed.y), 0.0)
	h.run(32, hold())
	assert_true(h.state.grounded and absf(h.state.position.y + 3.5) < 0.3, "stands in the canal")
	# subway rail, 7 m east of the track centre and 3 m up
	h.spawn(Vector3(-313.0, -9.98, 0.0), 0.0)
	h.run(30, func(t: int) -> InputCmd: return cmd(t, B_JUMP if t == 1 or t == 20 else 0))
	assert_eq(h.state.loco, L.ZIPLINE, "boards the subway zipline")
	done()
