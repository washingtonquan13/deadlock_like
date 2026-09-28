extends MoveTestCase
## Air drag, down dash, air jump (design §13.1).


## Measured session 5 (vz0 pinned by airtime): ~0.2/s proportional horizontal decay in the air.
func test_t10_air_drag() -> void:
	var h := new_harness(&"flat", null, hero_with(1, 0.0))
	await h.ready()
	h.spawn(Vector3(0.0, 5.0, 0.0), 0.0)
	h.state.velocity = Vector3(0.0, 0.0, -10.0)
	h.run(64, hold())
	assert_eq(h.state.loco, L.AIR, "still airborne")
	assert_near(h.state.horizontal_speed(), 8.19, 0.15, "~0.2/s air drag over 1 s")
	done()


## Measured air steering (session4_findings.md): holding S against 344 u/s bleeds ~800 u/s^2 (drag included) and
## tops out near 80 u/s backwards; W from rest reaches the same ~80 u/s within ~0.1 s. Loose on purpose.
func test_measured_air_steering() -> void:
	for my: int in [-1, 1]:
		var haze := hero_with(1, 0.0)
		haze.base_move_speed = 386.0 * 0.0254   # measured on Haze
		var h := new_harness(&"flat", null, haze)
		await h.ready()
		h.spawn(Vector3(0.0, 50.0, 0.0), 0.0)
		h.state.velocity = Vector3(0.0, 0.0, -344.0 * 0.0254) if my < 0 else Vector3.ZERO
		h.run(40, func(t: int) -> InputCmd: return cmd(t, 0, 0, my))
		var fwd := func(i: int) -> float: return -float(h.trace[i]["vel"].z) / 0.0254
		if my < 0:
			assert_near(fwd.call(15), 344.0 - 800.0 * 16.0 / 64.0, 40.0, "S: ~800 u/s^2 against the motion")
			assert_near(fwd.call(39), -80.0, 10.0, "S: caps near 80 u/s backwards")
		else:
			assert_near(fwd.call(6), 75.0, 15.0, "W: ~80 u/s within ~0.1 s")
			assert_near(fwd.call(39), 80.0, 10.0, "W: caps near 80 u/s")
	done()


func _down_dash_run(second_press: int) -> SimHarness:
	var h := new_harness(&"flat")
	await h.ready()
	h.spawn(Vector3(0.0, 20.0, 0.0), 0.0)
	h.run(40, func(t: int) -> InputCmd: return cmd(t, B_CROUCH if (t == 1 or t == second_press) else 0))
	return h


## spec: movement.md §11 down dash: crouch double-tap within 0.4375 s (28 ticks) in the air (T17)
func test_t17_down_dash_double_tap() -> void:
	var h: SimHarness = await _down_dash_run(29)
	var i := first_event(h.trace, MoveEvents.DASHED, "kind", &"down")
	assert_eq(i + 1, 29, "down dash on the second press (28 ticks apart)")
	assert_true(count_loco(h.trace, L.DOWN_DASH) > 0, "DOWN_DASH loco entered")
	var h2: SimHarness = await _down_dash_run(30)
	assert_true(first_event(h2.trace, MoveEvents.DASHED, "kind", &"down") < 0, "no down dash 29 ticks apart")
	assert_eq(count_loco(h2.trace, L.DOWN_DASH), 0, "no DOWN_DASH loco 29 ticks apart")
	done()


## spec: movement.md §10 air jump sets vertical speed, one per airtime (T18); costs 1 stamina
func test_t18_air_jump() -> void:
	var h := new_harness(&"flat")
	await h.ready()
	h.run(20, func(t: int) -> InputCmd: return cmd(t, B_JUMP if (t == 1 or t == 10 or t == 15) else 0))
	var i := first_event(h.trace, MoveEvents.JUMPED, "kind", &"air")
	assert_eq(i + 1, 10, "air jump on tick 10")
	if i >= 0:
		var vy: float = (h.trace[i]["vel"] as Vector3).y
		assert_near(vy, 13.26 - 20.32 / 64.0, 1e-4, "vertical speed after air jump (half-step gravity)")
		assert_near(h.trace[i]["stamina"], 2.0, 1e-9, "air jump costs one stamina")
	assert_true(first_event(h.trace, MoveEvents.JUMPED, "kind", &"air", 10) < 0, "second air jump refused")
	assert_eq(h.state.air_jumps_used, 1, "one air jump used")
	# land, counters refresh
	h.run(120, hold())
	assert_true(h.state.grounded, "landed")
	assert_eq(h.state.air_jumps_used, 0, "air jumps refreshed on landing")
	h.trace.clear()
	var t0 := h.state.tick
	h.run(20, func(t: int) -> InputCmd: return cmd(t, B_JUMP if (t == t0 + 1 or t == t0 + 10) else 0))
	assert_true(first_event(h.trace, MoveEvents.JUMPED, "kind", &"air") >= 0, "air jump works again after landing")
	done()


## Measured air jump horizontal (session5_audit.md): along the previous tick's wish, top up toward run speed by at most
## ~200 u/s; no cap on |h|. Loose on purpose.
func test_measured_air_jump_wish_accel() -> void:
	var u := 0.0254
	for c: Array in [[1, 0, Vector3(0.0, 0.0, -340.0)], [0, -1, Vector3(0.0, 0.0, -210.0)], [0, 1, Vector3(0.0, 0.0, -40.0)]]:
		var h := new_harness(&"flat")
		await h.ready()
		h.spawn(Vector3(0.0, 50.0, 0.0), 0.0)
		h.state.air_jumps_used = 0
		h.state.velocity = c[2] * u
		h.run(2, func(t: int) -> InputCmd: return cmd(t, B_JUMP if t == 2 else 0, c[0], c[1]))
		var v: Vector3 = h.state.velocity / u
		var hs := Vector2(v.x, v.z).length()
		if c[0] == 1:
			assert_true(v.x > 120.0, "D: lateral gained")
			assert_true(hs > 370.0 and hs < 410.0, "D: 200 added sideways, no cap, got %.0f" % hs)
		elif c[1] == -1:
			assert_near(-v.z, 0.0, 30.0, "S against 210: one ~200 step, to ~0")
		else:
			assert_near(hs, 240.0, 30.0, "W from ~40: ~240")
	done()


## Measured diagonal air jump (session6_findings.md): the add uses the world-axis-clamped key vector, so W+D from rest
## gets ~280 when the diagonal lies on a world 45-degree line and ~200 when it lies on a world axis. Loose on purpose.
func test_measured_air_jump_diagonal_world_clamp() -> void:
	var u := 0.0254
	var got := []
	for yaw: float in [0.0, PI / 4.0]:
		var h := new_harness(&"flat")
		await h.ready()
		h.spawn(Vector3(0.0, 50.0, 0.0), yaw)
		h.state.air_jumps_used = 0
		h.run(2, func(t: int) -> InputCmd: return cmd(t, B_JUMP if t == 2 else 0, 1, 1, yaw))
		var v: Vector3 = h.state.velocity / u
		got.append(Vector2(v.x, v.z).length())
	assert_near(got[0], 283.0, 25.0, "W+D on a world diagonal: ~200*sqrt2, got %.0f" % got[0])
	assert_near(got[1], 200.0, 25.0, "W+D on a world axis: ~200, got %.0f" % got[1])
	done()


## Measured landing into a slide (session 6, session 7 LT*): below ~466 u/s it loses one ground-friction tick (~6%),
## above ~470 nothing. Loose on purpose.
func test_measured_landing_slide_loss() -> void:
	var u := 0.0254
	for c: Array in [[400.0, 0.90, 0.965], [520.0, 0.975, 1.01]]:
		var h := new_harness(&"flat")
		await h.ready()
		h.spawn(Vector3(0.0, 0.3, 0.0), 0.0)
		h.state.velocity = Vector3(0.0, -2.0, -float(c[0]) * u)
		for i in 30:
			h.run(1, hold(B_CROUCH))
			if h.state.grounded:
				break
		assert_eq(h.state.loco, L.SLIDE, "landed into a slide at %.0f" % c[0])
		var r: float = Vector2(h.state.velocity.x, h.state.velocity.z).length() / u / float(c[0])
		assert_true(r > c[1] and r < c[2], "landing at %.0f keeps %.3f" % [c[0], r])
	done()
