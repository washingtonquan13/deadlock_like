extends MoveTestCase
## Ground locomotion, jump and crouch on a flat floor (design §13.1).


## spec: movement.md §2 Base locomotion: Source friction + accelerate (T02)
func test_t02_walk_accel() -> void:
	var h := new_harness(&"flat")
	await h.ready()
	h.run(400, hold(0, 0, 1))
	assert_near(h.trace[0]["hspeed"], 0.45, 1e-5, "speed tick 1")
	assert_near(h.trace[1]["hspeed"], 0.74125, 1e-5, "speed tick 2")
	assert_near(h.trace[2]["hspeed"], 1.0325, 1e-5, "speed tick 3")
	var first := -1
	for i in h.trace.size():
		if float(h.trace[i]["hspeed"]) >= 6.84:
			first = i + 1
			break
	assert_eq(first, 48, "first tick with speed >= 95%")
	assert_true(absf(h.state.horizontal_speed() - 7.2) < 1e-4, "steady 7.2 after 400 ticks (got %.6f)" % h.state.horizontal_speed())
	assert_true(h.state.grounded, "grounded while walking")
	done()


## spec: movement.md §2 stopping with stop_speed friction (T03)
func test_t03_walk_stop() -> void:
	var h := new_harness(&"flat")
	await h.ready()
	h.state.velocity = Vector3(0.0, 0.0, -7.2)
	var start := h.state.position
	h.run(64, hold())
	var stop := -1
	for i in h.trace.size():
		if float(h.trace[i]["hspeed"]) == 0.0:
			stop = i + 1
			break
	assert_eq(stop, 33, "first tick at speed 0")
	if stop > 0:
		var p: Vector3 = h.trace[stop - 1]["pos"]
		var d := Vector2(p.x - start.x, p.z - start.z).length()
		assert_near(d, 1.38984, 1e-4, "stopping distance")
	done()


## spec: movement.md §10 Jump: 7.493 m/s, gravity 24.562, half-step integration (T04)
func test_t04_standing_jump() -> void:
	var h := new_harness(&"flat")
	await h.ready()
	h.run(60, func(t: int) -> InputCmd: return cmd(t, B_JUMP if t == 1 else 0))
	var y19: float = (h.trace[18]["pos"] as Vector3).y
	var y20: float = (h.trace[19]["pos"] as Vector3).y
	assert_near(y19, 1.14211, 1e-4, "y(19)")
	assert_near(y20, 1.14226, 1e-4, "y(20)")
	var apex := 0
	var best := -INF
	for i in 45:
		var y: float = (h.trace[i]["pos"] as Vector3).y
		if y > best:
			best = y
			apex = i + 1
	assert_eq(apex, 20, "apex tick")
	var land := -1
	for i in h.trace.size():
		if i > 0 and bool(h.trace[i]["grounded"]):
			land = i + 1
			break
	assert_eq(land, 39, "grounded again on tick")
	assert_eq(first_event(h.trace, MoveEvents.LANDED) + 1, 39, "LANDED event tick")
	assert_eq(first_event(h.trace, MoveEvents.JUMPED, "kind", &"ground") + 1, 1, "JUMPED ground on tick 1")
	done()


## spec: movement.md §6 Crouch speed, firing, §13 slide entry speed (T20)
func test_t20_crouch() -> void:
	var h := new_harness(&"flat")
	await h.ready()
	h.run(400, hold(B_CROUCH, 0, 1))
	assert_eq(h.state.loco, L.CROUCH, "crouch-walk loco")
	assert_near(h.state.horizontal_speed(), 4.8, 1e-4, "crouch-walk steady speed")
	h.run(200, hold(B_CROUCH | B_FIRE, 0, 1))
	assert_near(h.state.horizontal_speed(), 4.8, 1e-4, "crouch speed while firing")
	# 7.2 on flat: crouch, no slide
	h.spawn(Vector3.ZERO, 0.0)
	h.state.velocity = Vector3(0.0, 0.0, -7.2)
	h.run(1, hold(B_CROUCH))
	assert_eq(h.state.loco, L.CROUCH, "no slide at 7.2")
	# 9.0 on flat: slide
	h.spawn(Vector3.ZERO, 0.0)
	h.state.velocity = Vector3(0.0, 0.0, -9.0)
	h.run(1, hold(B_CROUCH))
	assert_eq(h.state.loco, L.SLIDE, "slide at 9.0")
	assert_true(first_event(h.trace, MoveEvents.SLIDE_START) == 0, "SLIDE_START event")
	done()
