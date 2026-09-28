extends MoveTestCase
## Collision parity against KinematicMover: slopes, stairs, wall slide, walkable limit (design §13.1).

const R := 0.4064   # capsule radius, spec: movement.md §20


## measured session 7 (s7_ramp RS0): crouching at rest on a 20 degree slope does not slide (T21)
func test_t21_slope_slide() -> void:
	var h := new_harness(&"flat")
	ArenaBuilder.add_ramp(h.root, Vector3.ZERO, 20.0, 40.0, 6.0)
	await h.ready()
	var d := 25.0
	h.spawn(Vector3(0.0, d * tan(deg_to_rad(20.0)) + slope_rest_offset(R, 20.0), -d), 0.0)
	h.run(48, hold(B_CROUCH))
	assert_eq(h.state.loco, L.CROUCH, "crouched, not sliding")
	assert_true(h.state.velocity.length() < 1.0, "stays put on the slope")
	done()


## measured session 8 (s8_city_slide): a slide down a long ramp keeps gaining speed; the penalty waits for the flat
func test_long_ramp_slide_no_penalty() -> void:
	var h := new_harness(&"flat")
	ArenaBuilder.add_ramp(h.root, Vector3.ZERO, 30.0, 45.0, 6.0)
	await h.ready()
	var d := 36.0
	h.spawn(Vector3(0.0, d * tan(deg_to_rad(30.0)) + slope_rest_offset(R, 30.0), -d), PI)
	h.state.velocity = Vector3(0.0, 0.0, 10.0)   # ~394 u/s downhill
	h.run(80, hold(B_CROUCH))
	assert_eq(h.state.loco, L.SLIDE, "still sliding after 1.25 s on the ramp")
	assert_true(h.state.horizontal_speed() > 20.0, "gained speed (%.1f m/s)" % h.state.horizontal_speed())
	assert_true(first_event(h.trace, MoveEvents.SLIDE_PENALTY) < 0, "no penalty on the ramp")
	done()


## measured session 8 (sliding_2 w2): a slide carried from the flat onto an upslope ends and decays to crouch speed.
func test_slide_into_upslope_ends() -> void:
	var h := new_harness(&"flat")
	ArenaBuilder.add_ramp(h.root, Vector3.ZERO, 28.0, 20.0, 6.0)
	await h.ready()
	h.spawn(Vector3(0.0, 0.0, 3.0), 0.0)
	h.state.velocity = Vector3(0.0, 0.0, -12.5)   # ~490 u/s toward the uphill
	h.run(45, hold(B_CROUCH))
	assert_true(first_event(h.trace, MoveEvents.SLIDE_START) >= 0, "slid on the flat")
	assert_true(h.state.loco != L.SLIDE, "no slide up the slope (%s)" % L.keys()[h.state.loco])
	assert_true(h.state.horizontal_speed() < 7.0, "slowed on the slope (%.1f m/s)" % h.state.horizontal_speed())
	done()


## spec: movement.md §20 step height 18 u: 8/16/18 u stairs climb, 20 u blocks (T22)
func test_t22_stairs() -> void:
	var h := new_harness(&"flat")
	var heights: Array[int] = [8, 16, 18, 20]
	for i in heights.size():
		ArenaBuilder.add_stairs(h.root, Vector3(5.0 * float(i), 0.0, -4.0), float(heights[i]) * ArenaBuilder.HU, 0.5, 8, 3.0)
	await h.ready()
	for i in heights.size():
		var su := heights[i]
		var top := 8.0 * float(su) * ArenaBuilder.HU
		h.spawn(Vector3(5.0 * float(i), 0.0, -3.0), 0.0)
		h.run(90, hold(0, 0, 1))
		if su <= 18:
			var reach := -1
			for k in h.trace.size():
				if (h.trace[k]["pos"] as Vector3).z <= -8.6:
					reach = k
					break
			assert_true(reach >= 0, "%du stairs: reached the top landing" % su)
			if reach < 0:
				continue
			var air := 0
			for k in reach + 1:
				if not bool(h.trace[k]["grounded"]):
					air += 1
			assert_eq(air, 0, "%du stairs: airborne ticks while climbing" % su)
			assert_near((h.trace[reach]["pos"] as Vector3).y, top, 0.01, "%du stairs: height at the top" % su)
		else:
			assert_true(h.state.position.y < 0.1, "20u stairs: stays on the floor (y %.3f)" % h.state.position.y)
			assert_true(h.state.position.z > -5.0, "20u stairs: blocked at the first step (z %.3f)" % h.state.position.z)
	done()


## spec: movement.md §2 wall slide keeps the tangential wishspeed component (T23)
func test_t23_wall_slide() -> void:
	var h := new_harness(&"flat")
	ArenaBuilder.add_wall(h.root, Vector3(2.25, 2.0, -25.0), Vector3(0.5, 4.0, 60.0))
	await h.ready()
	var yaw := -PI / 4.0
	h.spawn(Vector3(0.5, 0.0, 0.0), yaw)
	h.state.velocity = InputCmd.wish_dir_for(0, 1, yaw) * 7.2
	h.run(256, hold(0, 0, 1, yaw))
	# the steady tangential speed depends on the (constant, measured) ground accel; wall slides are unmeasured
	var vt := absf(h.state.velocity.z)
	assert_true(vt > 4.0 and vt < 7.2 + 1e-3, "keeps a tangential speed along the wall, at most wishspeed (got %.3f)" % vt)
	var worst := -INF
	for e in h.trace:
		worst = maxf(worst, (e["pos"] as Vector3).x + R)
	assert_true(worst <= 2.0 + 0.002, "capsule never penetrates the wall (max x+r %.4f)" % worst)
	done()


## spec: movement.md §20 walkable up to normal.y 0.7 (45.57 degrees) (T24)
func test_t24_walkable_limit() -> void:
	var h := new_harness(&"flat")
	ArenaBuilder.add_ramp(h.root, Vector3(0.0, 0.0, 0.0), 45.0, 20.0, 4.0)
	ArenaBuilder.add_ramp(h.root, Vector3(10.0, 0.0, 0.0), 50.0, 20.0, 4.0)
	await h.ready()
	# 45 degrees: walk up from the base
	h.spawn(Vector3(0.0, 0.0, 1.0), 0.0)
	h.run(100, hold(0, 0, 1))
	var air := 0
	for e in h.trace:
		if not bool(e["grounded"]):
			air += 1
	assert_eq(air, 0, "45 degrees: airborne ticks while walking up")
	assert_true(h.state.position.y > 2.0, "45 degrees: climbed (y %.3f)" % h.state.position.y)
	# 50 degrees: placed on the surface, slides down, never grounded
	var d := 5.0
	var y0 := d * tan(deg_to_rad(50.0)) + slope_rest_offset(R, 50.0)
	h.spawn(Vector3(10.0, y0, -d), 0.0)
	h.run(20, hold())
	var grounded := 0
	for e in h.trace:
		if bool(e["grounded"]):
			grounded += 1
	assert_eq(grounded, 0, "50 degrees: grounded ticks on the steep ramp")
	assert_true(h.state.position.y < y0 - 0.05, "50 degrees: slid down (y %.3f from %.3f)" % [h.state.position.y, y0])
	assert_true(h.state.position.z > -d + 0.02, "50 degrees: moved down-slope (z %.3f)" % h.state.position.z)
	done()
