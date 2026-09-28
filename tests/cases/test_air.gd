extends MoveTestCase
## Air drag, down dash, air jump (design §13.1).


## spec: movement.md §12 air drag, raised by 35% of the actual slow (T10)
## G08: research proves the old 0.1/s wrong; air_drag is 0.2/s, so 10*(1-0.2/64)^64 = 8.1847
## and under SLOW 0.5: 10*(1-0.2*1.175/64)^64 = 7.9023 (old 9.0477 / 8.8905 were for 0.1/s).
func test_t10_air_drag() -> void:
	var h := new_harness(&"flat", null, hero_with(1, 0.0))
	await h.ready()
	h.spawn(Vector3(0.0, 5.0, 0.0), 0.0)
	h.state.velocity = Vector3(0.0, 0.0, -10.0)
	h.run(64, hold())
	assert_eq(h.state.loco, L.AIR, "still airborne")
	assert_near(h.state.horizontal_speed(), 8.1847, 1e-3, "drag over 1 s (G08)")
	h.spawn(Vector3(0.0, 5.0, 0.0), 0.0)
	h.state.velocity = Vector3(0.0, 0.0, -10.0)
	h.sim.push_external(h.state, {"op": &"add_modifier", "def": ModifierDef.make(&"slow_half", ModifierDef.Stat.SLOW, 0.5), "source": &"test"})
	h.run(64, hold())
	assert_near(h.state.horizontal_speed(), 7.9023, 1e-3, "drag over 1 s under SLOW 0.5 (G08)")
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


## spec: movement.md §10 air jump sets vertical speed, costs 1, one per airtime (T18)
func test_t18_air_jump() -> void:
	var h := new_harness(&"flat")
	await h.ready()
	h.run(20, func(t: int) -> InputCmd: return cmd(t, B_JUMP if (t == 1 or t == 10 or t == 15) else 0))
	var i := first_event(h.trace, MoveEvents.JUMPED, "kind", &"air")
	assert_eq(i + 1, 10, "air jump on tick 10")
	if i >= 0:
		var vy: float = (h.trace[i]["vel"] as Vector3).y
		assert_near(vy, 7.493 - 20.32 / 64.0, 1e-4, "vertical speed after air jump (half-step gravity)")
		assert_near(h.trace[i]["stamina"], 2.0, 1e-9, "stamina after air jump")
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
