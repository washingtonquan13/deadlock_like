extends MoveTestCase
## Mantle bands and wall jumps (design §13.1).

const R := 0.4064


func _ledge_x(i: int) -> float:
	return 4.0 * float(i)


## spec: movement.md §15 mantle heights 32-160 u; measured session 7: a 162 u ledge mantles. Measured session 4: climb ~215.6 u/s, so the
## duration grows with the height (64 u from the ground took ~0.5 s with the exit phase).
func test_t25_mantle_bands() -> void:
	var h := new_harness(&"flat")
	var hs: Array[int] = [24, 32, 64, 96, 128, 162, 170]
	var mantles: Array[bool] = [false, true, true, true, true, true, false]
	var prev_n := 0
	for i in hs.size():
		ArenaBuilder.add_ledge(h.root, Vector3(_ledge_x(i), 0.0, -5.0), hs[i], 6.0)
	var wall_i := hs.size()
	ArenaBuilder.add_ledge(h.root, Vector3(_ledge_x(wall_i), 0.0, -5.0), 160, 4.0 * ArenaBuilder.HU)
	await h.ready()
	var sz := -5.0 + R + 0.3
	for i in hs.size():
		h.spawn(Vector3(_ledge_x(i), 0.0, sz), 0.0)
		h.state.air_jumps_used = 1
		h.state.air_dashes_used = 1
		h.run(90, hold(B_JUMP, 0, 1))
		var tag := "%du" % hs[i]
		var n := count_loco(h.trace, L.MANTLE)
		if not mantles[i]:
			assert_eq(n, 0, tag + " no mantle")
			continue
		assert_true(n > prev_n, tag + " takes longer than the lower ledge")
		prev_n = n
		if hs[i] == 64:
			assert_true(n >= 24 and n <= 40, tag + " ~0.4-0.6 s (got %d ticks)" % n)
		if hs[i] == 162:
			# measured 162 u: ~32 climb ticks plus the exit (a 215.6 u/s climb would take ~64 here)
			assert_true(n >= 34 and n <= 54, tag + " faster climb on tall ledges (got %d ticks)" % n)
		if n > 0:
			var m0 := first_loco(h.trace, L.MANTLE)
			var after := m0 + n
			assert_true(first_event(h.trace, MoveEvents.MANTLE_START) == m0, tag + " MANTLE_START on first mantle tick")
			if after < h.trace.size():
				assert_true(bool(h.trace[after]["grounded"]), tag + " grounded after the mantle")
				assert_near((h.trace[after]["pos"] as Vector3).y, float(hs[i]) * ArenaBuilder.HU, 0.01, tag + " on top of the ledge")
			assert_eq(h.state.air_jumps_used, 0, tag + " air jumps refreshed")
			assert_eq(h.state.air_dashes_used, 0, tag + " air dashes refreshed")
	# 4 u deep wall: below the 6 u minimum depth
	h.spawn(Vector3(_ledge_x(wall_i), 0.0, sz), 0.0)
	h.run(60, hold(B_JUMP, 0, 1))
	assert_eq(count_loco(h.trace, L.MANTLE), 0, "4u-deep wall: no mantle")
	# crouch held through a mantle ends in a slide
	h.spawn(Vector3(_ledge_x(2), 0.0, sz), 0.0)
	h.run(40, hold(B_JUMP | B_CROUCH, 0, 1))
	var m := first_loco(h.trace, L.MANTLE)
	var n2 := count_loco(h.trace, L.MANTLE)
	assert_true(n2 > 0, "64u with crouch: mantled")
	if m >= 0 and m + n2 < h.trace.size():
		assert_eq(int(h.trace[m + n2]["loco"]), L.SLIDE, "64u with crouch: slide after the mantle")
	done()


## spec: movement.md §14 wall jump: first free, then 0.5 stamina and fatigue (T26)
func test_t26_wall_jump() -> void:
	# the G33 min interval would eat the tick-3 press; it is tested in test_fpp_g33_double_press_one_wall_jump
	var p := MovementParams.new()
	p.wall_jump_min_interval = 0.0
	var h := new_harness(&"flat", p)
	ArenaBuilder.add_wall(h.root, Vector3(1.25, 5.0, 0.0), Vector3(0.5, 10.0, 10.0))
	await h.ready()
	h.spawn(Vector3(1.0 - R - 0.05, 3.0, 0.0), 0.0)
	assert_eq(h.state.loco, L.AIR, "starts airborne next to the wall")
	h.run(4, func(t: int) -> InputCmd: return cmd(t, B_JUMP if (t == 1 or t == 3) else 0))
	var i1 := first_event(h.trace, MoveEvents.WALL_JUMP, "count", 1)
	var i2 := first_event(h.trace, MoveEvents.WALL_JUMP, "count", 2)
	assert_eq(i1, 0, "first wall jump on tick 1")
	assert_eq(i2, 2, "second wall jump on tick 3")
	if i1 >= 0:
		assert_near(h.trace[i1]["stamina"], 3.0, 1e-9, "first wall jump is free")
		var vx: float = (h.trace[i1]["vel"] as Vector3).x
		assert_near(vx, -6.807, 0.05, "neutral kick away from the wall")
	if i1 >= 0 and i2 >= 0:
		assert_near(h.trace[i2]["stamina"], 2.5, 1e-9, "second wall jump costs 0.5")
		assert_true((h.trace[i2]["vel"] as Vector3).y < (h.trace[i1]["vel"] as Vector3).y, "fatigue lowers the second jump")
	h.run(200, hold())
	assert_true(h.state.grounded, "landed")
	assert_near(h.state.wall_fatigue, 0.0, 1e-9, "fatigue cleared on landing")
	assert_eq(h.state.wall_jumps_done, 0, "wall jump count cleared on landing")
	done()


## Measured wall jump (session3_findings.md): ~519 u/s up from a hover, off-wall kick 268 / 215 (W) / 361 (S),
## A adds ~107 u/s along the wall on top of the incoming tangent (session 7b; none here, from a hover).
## Deliberately loose: the model is still being fit against recordings.
func test_measured_wall_jump_launch() -> void:
	var cases := {"none": [0, 0, 268.0, 0.0], "w": [0, 1, 215.0, 0.0], "s": [0, -1, 361.0, 0.0], "a": [-1, 0, 268.0, 107.0]}
	for key: String in cases:
		var c: Array = cases[key]
		var h := new_harness(&"flat")
		ArenaBuilder.add_wall(h.root, Vector3(1.25, 25.0, 0.0), Vector3(0.5, 50.0, 20.0))
		await h.ready()
		h.spawn(Vector3(1.0 - 0.4064 - 0.1, 30.0, 0.0), -PI / 2.0)
		h.run(1, func(t: int) -> InputCmd: return cmd(t, B_JUMP, int(c[0]), int(c[1]), -PI / 2.0))
		assert_eq(first_event(h.trace, MoveEvents.WALL_JUMP), 0, key + ": wall jump")
		var v: Vector3 = h.trace[0]["vel"] / 0.0254
		assert_near(v.y, 519.0, 20.0, key + ": launch up")
		assert_near(-v.x, float(c[2]), 20.0, key + ": kick off the wall")
		assert_near(absf(v.z), float(c[3]), 15.0, key + ": kick along the wall")
	done()


## Measured session 4 (wallfat): with W held, a second wall jump ~53 ticks after the first launches only ~0.3-0.45 of
## the first one's vertical speed; the kick off the wall is unchanged. Loose on purpose.
func test_wall_jump_fatigue_second_jump() -> void:
	var h := new_harness(&"flat")
	ArenaBuilder.add_wall(h.root, Vector3(1.25, 25.0, 0.0), Vector3(0.5, 50.0, 20.0))
	await h.ready()
	h.spawn(Vector3(1.0 - 0.4064 - 0.1, 30.0, 0.0), -PI / 2.0)
	h.run(80, func(t: int) -> InputCmd: return cmd(t, B_JUMP if (t == 1 or (t >= 40 and t % 2 == 0)) else 0, 0, 1, -PI / 2.0))
	var i1 := first_event(h.trace, MoveEvents.WALL_JUMP, "count", 1)
	var i2 := first_event(h.trace, MoveEvents.WALL_JUMP, "count", 2)
	assert_true(i1 >= 0 and i2 >= 0, "two wall jumps (W pulls back to the wall)")
	if i1 >= 0 and i2 >= 0:
		var v1: Vector3 = h.trace[i1]["vel"] / 0.0254
		var v2: Vector3 = h.trace[i2]["vel"] / 0.0254
		var r := v2.y / v1.y
		assert_true(r > 0.25 and r < 0.5, "second jump vertical is fatigued (ratio %.2f)" % r)
		assert_near(v2.x, v1.x, 20.0, "kick off the wall not fatigued")
	done()
