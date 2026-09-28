extends MoveTestCase
## Ground dash, dash-jump, dash slide, dash-jump slide, air dash (design §13.1).

const DASH_SPEEDS: Array[float] = [16.129, 14.706, 13.889]
# floor(duration x 64) whole ticks (ground_dash_whole_ticks, measured B1-B3 in session2_findings.md)
const DASH_TICKS: Array[int] = [39, 43, 46]
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
			assert_near(Vector2(p.x - start.x, p.z - start.z).length(), DASH_SPEEDS[b] * DASH_TICKS[b] / 64.0, 2e-3, tag + " dash displacement")
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


## Measured dash slide (session3_findings.md): starts near 643 u/s, decays like the game, turns toward a held
## D at ~92 deg/s without losing speed, and ignores the mouse when no key is held.
## Deliberately loose: the model is still being fit against recordings.
func test_measured_dash_slide() -> void:
	var runs := {}
	for mode: String in ["none", "d", "yaw"]:
		var h := new_harness(&"flat")
		await h.ready()
		h.run(110, func(t: int) -> InputCmd:
			var b := B_DASH if t == 1 else (B_CROUCH if t >= 21 else 0)
			var mx := 1 if mode == "d" and t >= 30 else 0
			var yaw := deg_to_rad(-60.0) if mode == "yaw" and t >= 30 else 0.0
			return cmd(t, b, mx, 1 if t < 21 else 0, yaw))
		runs[mode] = h
		var s0 := first_loco(h.trace, L.SLIDE)
		assert_true(s0 >= 0, mode + ": dash slide entered")
		if s0 < 0:
			return done()
		assert_near(float(h.trace[s0]["hspeed"]) / 0.0254, 643.0, 10.0, mode + ": starts near 643 u/s")
		# measured 0.5 s into the slide: ~455 u/s
		assert_near(float(h.trace[s0 + 32]["hspeed"]) / 0.0254, 455.0, 30.0, mode + ": decays like the game")
	var vd: Vector3 = runs["d"].trace[60]["vel"]
	var vn: Vector3 = runs["none"].trace[60]["vel"]
	var vy: Vector3 = runs["yaw"].trace[60]["vel"]
	var turned := rad_to_deg(absf(Vector2(vn.x, vn.z).angle_to(Vector2(vd.x, vd.z))))
	assert_near(turned, 92.0 * 30.0 / 64.0, 12.0, "D turns the slide at ~92 deg/s")
	assert_near(Vector2(vd.x, vd.z).length(), Vector2(vn.x, vn.z).length(), 0.05, "turning keeps speed")
	assert_near(Vector2(vy.x, vy.z).angle_to(Vector2(vn.x, vn.z)), 0.0, 1e-3, "mouse alone does not steer")
	done()


## spec: movement.md §11 Air dash: 8 m in 0.43/0.47/0.51 s, adds velocity, suspends gravity (T09)
func test_t09_air_dash_buckets() -> void:
	for b in 3:
		var h := new_harness(&"flat", legacy_air_dash(), hero_with(b + 1, 0.0))
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


## Measured air dash (session2_findings.md): speed ramps up instead of jumping, peaks roughly at the measured
## 546/508/476 u/s from rest, stays level (no gravity), and is brought down toward 480 u/s afterwards.
## Deliberately loose: the model is still being fit against recordings.
func test_measured_air_dash_shape() -> void:
	var peaks_u := [546.7, 508.2, 476.4]
	for b in 3:
		var h := new_harness(&"flat", null, hero_with(b + 1, 0.0))
		await h.ready()
		h.spawn(Vector3(0.0, 5.0, 0.0), 0.0)
		var tag := "B%d" % (b + 1)
		h.run(50, func(t: int) -> InputCmd: return cmd(t, B_DASH if t == 1 else 0))
		var peak := 0.0
		for tr in h.trace:
			peak = maxf(peak, float(tr["hspeed"]))
		assert_true(float(h.trace[0]["hspeed"]) < 0.5 * peak, tag + " ramps up, no instant impulse")
		assert_near(peak / 0.0254, peaks_u[b], 15.0, tag + " peak near the measured value")
		assert_near(float(h.trace[20]["pos"].y), 5.0, 1e-3, tag + " level during the dash")
		assert_true(float(h.trace[49]["hspeed"]) / 0.0254 < 485.0, tag + " ends at or below ~480 u/s")
	done()


## Measured (session2_findings.md): a ground or air dash with no move input does nothing and costs nothing
## here; with W held the same press dashes.
func test_measured_neutral_dash_does_nothing() -> void:
	measured_neutral_dash = true
	for air: bool in [false, true]:
		for move: int in [0, 1]:
			var h := new_harness(&"flat", null, hero_with(1, 0.0 if air else 1.0))
			await h.ready()
			if air:
				h.spawn(Vector3(0.0, 5.0, 0.0), 0.0)
			h.run(10, func(t: int) -> InputCmd: return cmd(t, B_DASH if t == 1 else 0, 0, move))
			var tag := "%s, move=%d" % ["air" if air else "ground", move]
			var kind: StringName = &"air" if air else &"ground"
			var dashed := first_event(h.trace, MoveEvents.DASHED, "kind", kind) == 0
			assert_eq(dashed, move == 1, tag + ": dashed")
			assert_near(h.trace[0]["stamina"], 3.0 - float(move), 1e-9, tag + ": stamina")
	done()
