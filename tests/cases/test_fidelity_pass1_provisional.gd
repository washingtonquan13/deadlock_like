extends MoveTestCase
## Fidelity pass 1 (provisional): interim changes for gaps that still need recording
## (docs/design/movement_fidelity_gaps.md, specs/movement_behavior/video_guides.md).
## Every value tested here is PROVISIONAL and will be refit from the recording clip named per test.

const R := 0.4064
const G := 20.32   # measured gravity (session2_findings.md); spec §10 was 24.562
const DT := 1.0 / 64.0
const HU := 0.0254
const C_B1 := 8.0 / 0.43          # B1 air dash speed = V8 cap (732 u/s)
const DashState = preload("res://src/movement/core/states/dash_state.gd")


static func _drag_a(v: float) -> float:
	return maxf(minf(v, 12.192), v - 0.2 * (v - 2.032))


## G01 + G02 worked example (V8): B1 dash-jump then a forward air dash. Hyp A caps the dash at the
## bucket speed (732 u/s); the V8 (a) end drag leaves 0.8*732 + 16 = 601.98 u/s. Pending A1-A3, A2.
func test_fpp_g01_g02_dash_jump_air_dash_601() -> void:
	var h := new_harness(&"flat", legacy_air_dash(), hero_with(1))
	await h.ready()
	h.run(90, func(t: int) -> InputCmd: return cmd(t, B_DASH if (t == 1 or t == 31) else (B_JUMP if t == 21 else 0)))
	assert_eq(first_event(h.trace, MoveEvents.JUMPED, "kind", &"dash_jump"), 20, "dash-jump at k=20")
	var a := first_event(h.trace, MoveEvents.DASHED, "kind", &"air")
	assert_eq(a, 30, "air dash on tick 31")
	if a >= 0:
		assert_near(h.trace[a]["hspeed"], C_B1, 1e-4, "Hyp A: capped at the bucket dash speed, not 635 + 732 u/s")
		var peak := 0.0
		for i in range(a, h.trace.size()):
			peak = maxf(peak, float(h.trace[i]["hspeed"]))
		assert_true(peak <= C_B1 + 1e-4, "never above the cap")
	var e := first_event(h.trace, MoveEvents.AIR_DASH_END_DRAG)
	assert_eq(e, a + 28, "end drag when the 28-tick dash ends airborne")
	if e >= 0:
		var to := 0.0
		for ev in h.trace[e]["events"]:
			if StringName(ev["type"]) == MoveEvents.AIR_DASH_END_DRAG:
				to = float(ev["to"])
		assert_near(to / HU, 601.98, 0.05, "V8 formula (a): about 601 u/s")
		assert_near(h.trace[e]["hspeed"], _drag_a(C_B1), 1e-4, "then no air drag")
	done()


## G01/G02 alternative model via params only: flat 700 u/s cap and flat 20% drag give 560 u/s.
func test_fpp_g01_g02_alt_model_560() -> void:
	var p := legacy_air_dash()
	p.air_dash_cap_override = 17.78
	p.air_dash_end_drag_mode = 3
	var h := new_harness(&"flat", p, hero_with(1))
	await h.ready()
	h.run(90, func(t: int) -> InputCmd: return cmd(t, B_DASH if (t == 1 or t == 31) else (B_JUMP if t == 21 else 0)))
	var a := first_event(h.trace, MoveEvents.DASHED, "kind", &"air")
	if a >= 0:
		assert_near(h.trace[a]["hspeed"], 17.78, 1e-4, "capped at 700 u/s")
	var e := first_event(h.trace, MoveEvents.AIR_DASH_END_DRAG)
	assert_true(e > 0, "end drag applied")
	if e > 0:
		assert_near(h.trace[e]["hspeed"] / HU, 560.0, 0.05, "0.8 * 700 = 560 u/s")
	done()


## G01: perpendicular velocity is kept; a same-direction dash above the cap ends at the cap (Hyp A);
## mode 0 is the legacy uncapped add. Pending A1-A3.
func test_fpp_g01_perpendicular_kept() -> void:
	var h := new_harness(&"flat", legacy_air_dash(), hero_with(1))
	await h.ready()
	h.spawn(Vector3(0.0, 60.0, 0.0), 0.0)
	h.state.velocity = Vector3(10.0, 0.0, 0.0)
	h.run(1, func(t: int) -> InputCmd: return cmd(t, B_DASH))
	assert_vec_near(h.trace[0]["vel"], Vector3(10.0, 0.0, -C_B1), 1e-4, "90 deg dash: v_perp 10 kept, v_par = J")
	h.spawn(Vector3(0.0, 60.0, 0.0), 0.0)
	h.state.velocity = Vector3(0.0, 0.0, -25.0)
	h.run(1, func(t: int) -> InputCmd: return cmd(t, B_DASH))
	assert_near((h.trace[0]["vel"] as Vector3).z, -C_B1, 1e-4, "same direction above the cap: v_par = min(v_par, C)")
	var p := MovementParams.new()
	p.air_dash_cap_mode = 0
	var h2 := new_harness(&"flat", p, hero_with(1))
	await h2.ready()
	h2.spawn(Vector3(0.0, 60.0, 0.0), 0.0)
	h2.state.velocity = Vector3(0.0, 0.0, -10.0)
	h2.run(1, func(t: int) -> InputCmd: return cmd(t, B_DASH))
	assert_near((h2.trace[0]["vel"] as Vector3).z, -10.0 - C_B1, 1e-4, "mode 0: legacy uncapped add")
	done()


## G02 formulas: (a) no drag below 480 u/s and floor 480; (b) 20% above 480; flat 0.8. Pending A2.
func test_fpp_g02_end_drag_formulas() -> void:
	var h := new_harness(&"flat")
	await h.ready()
	var cases := [[1, 10.0, 10.0], [1, 13.0, 12.192], [1, 18.0, _drag_a(18.0)], [2, 10.0, 10.0], [2, 18.0, 18.0 - 0.2 * (18.0 - 12.192)], [3, 18.0, 14.4]]
	for c in cases:
		var p := MovementParams.new()
		p.air_dash_end_drag_mode = int(c[0])
		h.sim.set_params(CompiledMoveParams.build(p, HeroMovementStats.new()))
		var s := h.sim.new_state(Vector3(0.0, 60.0, 0.0), 0.0)
		s.velocity = Vector3(float(c[1]), 0.0, 0.0)
		s.air_dash_drag_pending = true
		DashState.apply_air_dash_end_drag(h.sim, s)
		assert_near(s.horizontal_speed(), float(c[2]), 1e-6, "mode %d at %.1f m/s" % [int(c[0]), float(c[1])])
	done()


## G02 exceptions: zip exit window (ZMC) and landing before the dash ends (IAD) skip the end drag.
func test_fpp_g02_zip_and_iad_skip() -> void:
	var h := new_harness(&"flat", legacy_air_dash(), hero_with(1))
	await h.ready()
	h.spawn(Vector3(0.0, 60.0, 0.0), 0.0)
	h.state.zip_exit_momentum_ticks = 100
	h.run(40, func(t: int) -> InputCmd: return cmd(t, B_DASH if t == 1 else 0))
	assert_true(first_event(h.trace, MoveEvents.AIR_DASH_END_DRAG) < 0, "no end drag in the zip exit window")
	assert_near(h.trace[39]["hspeed"], C_B1, 1e-4, "speed kept (no drag in the window)")
	# IAD: keep the falling vy through the dash so it lands mid-dash, crouch held -> AIR slide
	var p := legacy_air_dash()
	p.air_dash_zero_vertical = false
	var h2 := new_harness(&"flat", p, hero_with(1))
	await h2.ready()
	h2.spawn(Vector3(0.0, 0.5, 0.0), 0.0)
	h2.state.velocity = Vector3(0.0, -3.0, 0.0)
	h2.run(40, func(t: int) -> InputCmd: return cmd(t, B_CROUCH | (B_DASH if t == 1 else 0)))
	var land := first_event(h2.trace, MoveEvents.LANDED)
	assert_true(land > 0 and land < 28, "landed during the dash")
	assert_true(first_event(h2.trace, MoveEvents.AIR_DASH_END_DRAG) < 0, "IAD: no end drag")
	assert_eq(first_event(h2.trace, MoveEvents.SLIDE_START, "kind", MoveState.SlideKind.AIR), land, "lands into an air slide")
	done()


## G02 chain exception: a second air dash started before the first ends cancels its pending drag.
func test_fpp_g02_chain_cancels_drag() -> void:
	var h := new_harness(&"flat", null, hero_with(1))
	await h.ready()
	h.spawn(Vector3(0.0, 60.0, 0.0), 0.0)
	h.sim.push_external(h.state, {"op": &"add_modifier", "def": ModifierDef.make(&"extra_dash", ModifierDef.Stat.AIR_DASHES, 1.0), "source": &"test"})
	h.run(60, func(t: int) -> InputCmd: return cmd(t, B_DASH if (t == 1 or t == 11) else 0))
	var n := 0
	var first := -1
	for i in h.trace.size():
		if has_event(h.trace[i], MoveEvents.AIR_DASH_END_DRAG):
			n += 1
			if first < 0:
				first = i
	assert_eq(first_event(h.trace, MoveEvents.DASHED, "kind", &"air", 1), 10, "chained dash on tick 11")
	assert_eq(n, 1, "only the last dash of the chain drags")
	assert_eq(first, 10 + 28, "drag at the end of the second dash")
	done()


## G03: the wall jump keeps the tangential velocity and sets the normal axis to the kick. Pending W1.
func test_fpp_g03_wall_jump_keeps_tangent() -> void:
	var h := new_harness(&"flat")
	ArenaBuilder.add_wall(h.root, Vector3(1.25, 5.0, 0.0), Vector3(0.5, 10.0, 20.0))
	await h.ready()
	h.spawn(Vector3(1.0 - R - 0.1, 3.0, 0.0), 0.0)
	h.state.velocity = Vector3(3.0, 0.0, -8.0)
	h.run(1, func(t: int) -> InputCmd: return cmd(t, B_JUMP))
	assert_eq(first_event(h.trace, MoveEvents.WALL_JUMP), 0, "wall jump")
	var v: Vector3 = h.trace[0]["vel"]
	var k := 1.0   # no air drag (session 4)
	assert_near(v.z, -8.0 * 0.95 * k, 1e-3, "tangential -8 m/s kept x0.95")
	assert_near(v.x, -6.807 * k, 1e-3, "normal axis set to the neutral kick (incoming +3 discarded)")
	done()


func _run_until_slide(h: SimHarness, max_ticks: int) -> void:
	for n in max_ticks:
		h.run(1, hold(B_CROUCH))
		if h.state.loco == L.SLIDE:
			return


## G09: the first slide jump is exempt and sets the flag; a flagged slide jump under 0.5 s adds the
## slide-drag air drag until landing; ground time clears the flag; zip immunity blocks it. Pending S2.
func test_fpp_g09_slide_hop_penalty() -> void:
	for variant in ["early", "late", "zip"]:
		var h := new_harness(&"flat")
		await h.ready()
		h.state.velocity = Vector3(0.0, 0.0, -14.0)
		h.run(10, func(t: int) -> InputCmd: return cmd(t, B_CROUCH | (B_JUMP if t == 10 else 0)))
		assert_true(first_event(h.trace, MoveEvents.SLIDE_DRAG) < 0, variant + ": first slide jump exempt")
		assert_true(h.state.slide_hop_flag, variant + ": first slide jump sets the flag")
		_run_until_slide(h, 80)
		assert_eq(h.state.loco, L.SLIDE, variant + ": landed into a slide")
		var wait := 8 if variant != "late" else 33
		h.run(wait, hold(B_CROUCH))
		if variant == "zip":
			h.state.zip_exit_momentum_ticks = 100
		h.trace.clear()
		h.run(2, func(t: int) -> InputCmd: return cmd(t, B_CROUCH | (B_JUMP if h.trace.is_empty() else 0)))
		assert_eq(first_event(h.trace, MoveEvents.JUMPED), 0, variant + ": slide jump")
		if variant == "early":
			assert_eq(first_event(h.trace, MoveEvents.SLIDE_DRAG), 0, "early: slide drag")
			var r: float = float(h.trace[1]["hspeed"]) / float(h.trace[0]["hspeed"])
			assert_near(r, 1.0 - 0.8 * DT, 1e-6, "early: 0.8 penalty (no air drag)")
			h.run(80, hold())
			assert_true(h.state.grounded and not h.state.slide_hop_penalty_active, "penalty ends on landing")
			h.run(20, hold())
			assert_true(not h.state.slide_hop_flag, "ground time not sliding clears the flag")
		else:
			assert_true(first_event(h.trace, MoveEvents.SLIDE_DRAG) < 0, variant + ": no slide drag")
			assert_true(not h.state.slide_hop_penalty_active, variant + ": penalty inactive")
	done()


## G26: air wishspeed cap 80 u/s, 50 u/s above 700 u/s (V8). Steady lateral speed = cap*(1 - 0.2/64).
## Pending A5.
func test_fpp_g26_air_wishspeed_caps() -> void:
	var h := new_harness(&"flat", null, hero_with(1, 0.0))
	await h.ready()
	for c in [[15.0, 2.032], [20.0, 1.27]]:
		h.spawn(Vector3(0.0, 10.0, 0.0), 0.0)
		h.state.velocity = Vector3(0.0, 0.0, -float(c[0]))
		h.run(20, hold(0, 1, 0))
		var vx: float = (h.trace[19]["vel"] as Vector3).x
		assert_near(vx, float(c[1]) * (1.0 - 0.2 * DT), 0.02, "lateral speed at %.0f m/s" % float(c[0]))
	done()


static func _count(tr: Array[Dictionary], type: StringName, key: String = "", value: Variant = null) -> int:
	var n := 0
	for e in tr:
		if has_event(e, type, key, value):
			n += 1
	return n


## G02 IAD without crouch: the landed air dash still gets its end drag at the dash's scheduled end
## (V2 0:11 / V9 1:41: only an IAD into a slide on level ground skips it). Pending A2.
func test_fpp_g02_iad_no_crouch_drags_at_end() -> void:
	var p := legacy_air_dash()
	p.air_dash_zero_vertical = false
	var h := new_harness(&"flat", p, hero_with(1))
	await h.ready()
	h.spawn(Vector3(0.0, 0.5, 0.0), 0.0)
	h.state.velocity = Vector3(0.0, -3.0, 0.0)
	h.run(40, func(t: int) -> InputCmd: return cmd(t, B_DASH if t == 1 else 0))
	var land := first_event(h.trace, MoveEvents.LANDED)
	assert_true(land > 0 and land < 28, "landed during the dash")
	assert_eq(_count(h.trace, MoveEvents.AIR_DASH_END_DRAG), 1, "exactly one end drag")
	assert_eq(first_event(h.trace, MoveEvents.AIR_DASH_END_DRAG), 28, "at the scheduled dash end (same tick as an airborne dash)")
	done()


## G02 IAD then a bhop: leaving the ground before the scheduled end applies the drag on the jump tick
## (V2 0:33 / 3:03, V9 1:58). Pending A2.
func test_fpp_g02_iad_bhop_drags() -> void:
	var p := legacy_air_dash()
	p.air_dash_zero_vertical = false
	var h := new_harness(&"flat", p, hero_with(1))
	await h.ready()
	h.spawn(Vector3(0.0, 0.5, 0.0), 0.0)
	h.state.velocity = Vector3(0.0, -3.0, 0.0)
	h.run(3, func(t: int) -> InputCmd: return cmd(t, B_DASH if t == 1 else 0))
	for n in 20:
		if h.state.grounded:
			break
		h.run(1, hold())
	assert_true(h.state.grounded, "landed during the dash")
	h.run(2, hold())
	var j := h.trace.size()
	h.run(10, func(t: int) -> InputCmd: return cmd(t, B_JUMP if t == j + 1 else 0))
	assert_true(first_event(h.trace, MoveEvents.JUMPED) >= j, "jumped off the IAD")
	assert_eq(first_event(h.trace, MoveEvents.AIR_DASH_END_DRAG), first_event(h.trace, MoveEvents.JUMPED), "drag on the jump tick")
	assert_eq(_count(h.trace, MoveEvents.AIR_DASH_END_DRAG), 1, "exactly one end drag")
	done()


## G33 min interval: a second jump press next to the same wall 2 ticks after a wall jump is eaten:
## one WALL_JUMP, no air jump, stamina charged once (V7 14:14, V18 1:21). Pending W5.
func test_fpp_g33_double_press_one_wall_jump() -> void:
	var h := new_harness(&"flat")
	ArenaBuilder.add_wall(h.root, Vector3(1.25, 5.0, 0.0), Vector3(0.5, 10.0, 20.0))
	await h.ready()
	h.spawn(Vector3(1.0 - R - 0.05, 3.0, 0.0), 0.0)
	h.state.wall_jumps_done = 1   # next wall jump costs cost_wall_jump_subsequent
	var st0 := h.state.stamina
	h.run(6, func(t: int) -> InputCmd: return cmd(t, B_JUMP if (t == 1 or t == 3) else 0))
	assert_eq(_count(h.trace, MoveEvents.WALL_JUMP), 1, "one wall jump")
	assert_eq(first_event(h.trace, MoveEvents.JUMPED, "kind", &"air"), -1, "second press not spent as an air jump")
	assert_eq(h.state.air_jumps_used, 0, "no air jump used")
	assert_near(h.state.stamina, st0 - h.sim.cp.params.cost_wall_jump_subsequent, 1e-6, "stamina charged once")
	done()


## G50: a jump press mid-dash is dropped (G50,
## PROVISIONAL); a wall jump after the dash ends works.
func test_fpp_g50_air_dash_along_wall() -> void:
	var h := new_harness(&"flat", null, hero_with(1))
	ArenaBuilder.add_wall(h.root, Vector3(1.25, 25.0, -20.0), Vector3(0.5, 50.0, 60.0))
	await h.ready()
	h.spawn(Vector3(1.0 - R - 0.1, 30.0, 0.0), 0.0)
	h.run(5, func(t: int) -> InputCmd: return cmd(t, B_DASH if t == 1 else 0))
	assert_eq(h.state.loco, L.AIR_DASH, "air dashing along the wall")
	h.run(1, func(t: int) -> InputCmd: return cmd(t, B_JUMP))
	assert_eq(first_event(h.trace, MoveEvents.JUMPED), -1, "G50: jump press mid-dash dropped")
	while h.state.loco == L.AIR_DASH and h.trace.size() < 60:
		h.run(1, hold())
	assert_eq(h.state.loco, L.AIR, "dash ended airborne")
	var j := h.trace.size()
	h.run(2, func(t: int) -> InputCmd: return cmd(t, B_JUMP if t == j + 2 else 0))
	assert_eq(first_event(h.trace, MoveEvents.WALL_JUMP, "", null, j), j + 1, "wall jump after the dash")
	done()


## G06/G18: after dashing off a ledge, a jump press after the window closes (k=39 > close tick 35)
## is not a dash-jump.
func test_fpp_g06_airborne_jump_after_window_not_dash_jump() -> void:
	var h := new_harness(&"none", null, hero_with(1))
	ArenaBuilder.add_box(h.root, Vector3(0.0, 1.0, 0.0), Vector3(4.0, 2.0, 4.0), "Platform")
	await h.ready()
	h.spawn(Vector3(0.0, 2.0, 1.5), 0.0)
	h.run(45, func(t: int) -> InputCmd: return cmd(t, B_DASH if t == 1 else (B_JUMP if t == 40 else 0)))
	assert_true(h.sim.cp.dash_jump_close_tick < 39, "press is past the window")
	assert_true(not bool(h.trace[38]["grounded"]), "airborne before the press")
	assert_eq(first_event(h.trace, MoveEvents.JUMPED, "kind", &"dash_jump"), -1, "no dash-jump after the window")
	# still in the airborne GROUND_DASH at k=39: the post-window press falls in the G06/G07 lockout
	assert_eq(first_event(h.trace, MoveEvents.JUMPED, "kind", &"dash_jump", 39), -1, "the late press is not turned into a dash-jump later either")
	done()
