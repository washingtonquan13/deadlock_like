extends MoveTestCase
## Ground dash, dash-jump, dash slide, dash-jump slide, air dash (design §13.1).

const DASH_SPEEDS: Array[float] = [16.129, 14.706, 13.889]
const DASH_TICKS: Array[int] = [40, 44, 47]
# PROVISIONAL (G21): the dash slide starts at 650 u/s = 16.51 m/s in every bucket (V5 0:17), pending D2;
# 16.51 * (1 - 0.1875/64)^48 = 14.3412 at slide tick 48
const SLIDE48_SPEEDS: Array[float] = [14.3412, 14.3412, 14.3412]
const SLIDE_TOTAL: Array[int] = [70, 70, 70]
const AIR_DASH_SPEEDS: Array[float] = [18.605, 17.021, 15.686]
const AIR_DASH_TICKS: Array[int] = [28, 31, 33]


## spec: movement.md §8 Ground dash: 10 m in 0.62/0.68/0.72 s, fractional last tick, costs 1 (T05)
func test_t05_ground_dash_buckets() -> void:
	for b in 3:
		var h := new_harness(&"flat", null, hero_with(b + 1))
		await h.ready()
		var start := h.state.position
		h.run(60, func(t: int) -> InputCmd: return cmd(t, B_DASH if t == 1 else 0))
		var tag := "B%d" % (b + 1)
		assert_near(h.trace[0]["hspeed"], DASH_SPEEDS[b], 1e-3, tag + " dash speed")
		var n := count_loco(h.trace, L.GROUND_DASH)
		assert_eq(n, DASH_TICKS[b], tag + " ticks in GROUND_DASH")
		if n > 0:
			var p: Vector3 = h.trace[n - 1]["pos"]
			assert_near(Vector2(p.x - start.x, p.z - start.z).length(), 10.0, 1e-3, tag + " dash displacement")
		assert_near(h.trace[0]["stamina"], 2.0, 1e-9, tag + " stamina after dash")
		assert_true(first_event(h.trace, MoveEvents.DASHED, "kind", &"ground") == 0, tag + " DASHED event on tick 1")
	done()


func _dash_then(k_jump: int, k_ability: int = -1) -> SimHarness:
	var h := new_harness(&"flat")
	await h.ready()
	h.run(60, func(t: int) -> InputCmd:
		var b := 0
		if t == 1:
			b |= B_DASH
		if k_jump >= 0 and t == k_jump + 1:
			b |= B_JUMP
		if k_ability >= 0 and t == k_ability + 1:
			b |= B_ABILITY
		return cmd(t, b))
	return h


## spec: movement.md §9 Dash-jump window 0.3 s .. 0.55 s after dash start, +1 stamina (T06)
## G06: research (ground_dash.md rule 11) proves the old 0.2 s length wrong; the window is 0.25 s,
## so the last tick is ticks(0.55)-1 = 35 (was 31) and the close event moves from k=32 to k=36.
func test_t06_dash_jump_window() -> void:
	for k: int in [19, 20, 35, 36]:
		var h: SimHarness = await _dash_then(k)
		var i := first_event(h.trace, MoveEvents.JUMPED, "kind", &"dash_jump")
		var expect: bool = k == 20 or k == 35
		assert_eq(i >= 0, expect, "dash-jump at k=%d" % k)
		if expect and i >= 0:
			assert_eq(i + 1, k + 1, "dash-jump tick for k=%d" % k)
			assert_near(h.trace[i]["stamina"], 1.0, 1e-9, "stamina after dash-jump k=%d" % k)
			assert_eq(int(h.trace[i]["loco"]), L.AIR, "AIR after dash-jump k=%d" % k)
	# window events without a jump
	var h2: SimHarness = await _dash_then(-1)
	assert_eq(first_event(h2.trace, MoveEvents.DASH_JUMP_WINDOW, "open", true) + 1, 20, "window open event at k=20")
	assert_eq(first_event(h2.trace, MoveEvents.DASH_JUMP_WINDOW, "open", false) + 1, 36, "window close event at k=36 (G06)")
	# ability cast inside the window cancels it
	var h3: SimHarness = await _dash_then(24, 22)
	assert_true(first_event(h3.trace, MoveEvents.JUMPED, "kind", &"dash_jump") < 0, "no dash-jump after ability at k=22")
	assert_true(float(h3.state.stamina) >= 2.0 - 1e-9, "no dash-jump stamina spent after ability cancel")
	done()


## spec: movement.md §8 dash slide, §13 slide friction 0.1875 then penalty 3.1875 after 0.75 s (T07)
func test_t07_dash_slide_buckets() -> void:
	for b in 3:
		var h := new_harness(&"flat", null, hero_with(b + 1))
		await h.ready()
		h.run(200, func(t: int) -> InputCmd: return cmd(t, B_DASH if t == 1 else B_CROUCH))
		var tag := "B%d" % (b + 1)
		var s0 := first_loco(h.trace, L.SLIDE)
		assert_true(s0 >= 0, tag + " slide entered after the dash")
		if s0 < 0:
			continue
		assert_near(h.trace[s0 + 47]["hspeed"], SLIDE48_SPEEDS[b], 1e-3, tag + " speed at slide tick 48")
		var n := 0
		while s0 + n < h.trace.size() and int(h.trace[s0 + n]["loco"]) == L.SLIDE:
			n += 1
		assert_eq(n, SLIDE_TOTAL[b], tag + " slide ticks before exit")
		if s0 + n < h.trace.size():
			assert_eq(int(h.trace[s0 + n]["loco"]), L.CROUCH, tag + " exit to CROUCH")
		assert_true(first_event(h.trace, MoveEvents.SLIDE_START, "kind", MoveState.SlideKind.DASH) == s0, tag + " SLIDE_START kind DASH")
	done()


## spec: movement.md §13 dash-jump slide: onset 1.0 s, penalty 0.6875 (T08)
func test_t08_dash_jump_slide() -> void:
	var h := new_harness(&"flat")
	await h.ready()
	var s := h.state
	s.loco = L.SLIDE
	s.crouched = true
	s.slide_kind = MoveState.SlideKind.DASH_JUMP
	s.slide_ticks = 0
	s.velocity = Vector3(0.0, 0.0, -16.129)
	h.run(300, hold(B_CROUCH))
	assert_near(h.trace[63]["hspeed"], 13.368, 1e-3, "speed at slide tick 64")
	var n := 0
	while n < h.trace.size() and int(h.trace[n]["loco"]) == L.SLIDE:
		n += 1
	assert_eq(n - 64, 95, "penalty ticks at f=0.6875 until < 4.8")
	done()


## spec: movement.md §11 Air dash: 8 m in 0.43/0.47/0.51 s, adds velocity, suspends gravity (T09)
func test_t09_air_dash_buckets() -> void:
	for b in 3:
		var h := new_harness(&"flat", null, hero_with(b + 1, 0.0))
		await h.ready()
		h.spawn(Vector3(0.0, 5.0, 0.0), 0.0)
		var tag := "B%d" % (b + 1)
		assert_eq(h.state.loco, L.AIR, tag + " hovering in AIR")
		var start := h.state.position
		h.run(50, func(t: int) -> InputCmd: return cmd(t, B_DASH if t == 1 else 0))
		assert_near(h.trace[0]["hspeed"], AIR_DASH_SPEEDS[b], 1e-3, tag + " air dash speed")
		var n := count_loco(h.trace, L.AIR_DASH)
		assert_eq(n, AIR_DASH_TICKS[b], tag + " air dash ticks")
		if n > 0:
			var p: Vector3 = h.trace[n - 1]["pos"]
			assert_near(Vector2(p.x - start.x, p.z - start.z).length(), 8.0, 1e-3, tag + " air dash displacement")
			assert_near(p.y, start.y, 1e-6, tag + " no vertical motion")
	done()
