extends MoveTestCase
## Fidelity pass 1 (research-settled gaps, docs/design/movement_fidelity_gaps.md).
## One test per behavior; each numeric expectation comes from the research cited in the gap row.

const R := 0.4064
const G := 20.32   # measured gravity (session2_findings.md); spec §10 was 24.562
const DT := 1.0 / 64.0
const B_HEAVY := InputCmd.BTN_MELEE_HEAVY


## G05: dash-jump vertical 425 u/s = 10.795 m/s (ground_dash.md rule 13). End-of-tick vy = 10.795 - g*dt.
func test_fp1_g05_dash_jump_vertical() -> void:
	var h := new_harness(&"flat")
	await h.ready()
	h.run(80, func(t: int) -> InputCmd: return cmd(t, B_DASH if t == 1 else (B_JUMP if t == 21 else 0)))
	var i := first_event(h.trace, MoveEvents.JUMPED, "kind", &"dash_jump")
	assert_eq(i, 20, "dash-jump at k=20")
	if i >= 0:
		assert_near((h.trace[i]["vel"] as Vector3).y, 10.795 - G * DT, 1e-4, "dash-jump vy 425 u/s minus half-step gravity pair")
	done()


## G07: a jump pressed before the window opens (k=19 < 20) locks out the dash-jump for that dash
## (ground_dash.md rule 12), even when jump is pressed again inside the window (k=20).
func test_fp1_g07_early_jump_lockout() -> void:
	var h := new_harness(&"flat")
	await h.ready()
	h.run(60, func(t: int) -> InputCmd: return cmd(t, B_DASH if t == 1 else (B_JUMP if (t == 20 or t == 22) else 0)))
	assert_true(first_event(h.trace, MoveEvents.JUMPED, "kind", &"dash_jump") < 0, "no dash-jump after an early press at k=19")
	assert_near(h.trace[25]["stamina"], 2.0, 1e-9, "no dash-jump stamina spent (only the dash)")
	# control: the same in-window press without the early press dash-jumps
	var h2 := new_harness(&"flat")
	await h2.ready()
	h2.run(60, func(t: int) -> InputCmd: return cmd(t, B_DASH if t == 1 else (B_JUMP if t == 22 else 0)))
	assert_eq(first_event(h2.trace, MoveEvents.JUMPED, "kind", &"dash_jump"), 21, "control: dash-jump at k=21")
	done()


## G10: heavy lunge 750 u/s (19.05 m/s) on the ground, for up to 0.6 s = 39 ticks, after a 0.36 s
## (24 tick) windup (ziplines_melee_misc.md). PROVISIONAL (G10): constant profile pending H1.
func test_fp1_g10_heavy_lunge_ground() -> void:
	var h := new_harness(&"flat")
	await h.ready()
	h.run(120, func(t: int) -> InputCmd: return cmd(t, B_HEAVY if t == 1 else 0))
	var first := -1
	var n := 0
	for i in h.trace.size():
		if absf(float(h.trace[i]["hspeed"]) - 19.05) < 1e-3:
			n += 1
			if first < 0:
				first = i
	assert_eq(first, 24, "lunge starts after a 24-tick (0.36 s) windup (G12)")
	assert_eq(n, 39, "lunge lasts 39 ticks (0.6 s)")
	done()


## G10: air lunge 797 u/s = 20.2438 m/s for 39 ticks.
func test_fp1_g10_heavy_lunge_air() -> void:
	var h := new_harness(&"flat")
	await h.ready()
	h.spawn(Vector3(0.0, 60.0, 0.0), 0.0)
	h.run(100, func(t: int) -> InputCmd: return cmd(t, B_HEAVY if t == 1 else 0))
	var n := 0
	for i in h.trace.size():
		if absf(float(h.trace[i]["hspeed"]) - 20.2438) < 1e-3:
			n += 1
	assert_eq(n, 39, "air lunge at 797 u/s for 39 ticks")
	done()


## G12: recovery 0.2833 s (19 ticks) zeroes velocity on every axis, no walk-speed clamp, no gravity.
func test_fp1_g12_heavy_recovery_zero() -> void:
	var h := new_harness(&"flat")
	await h.ready()
	h.spawn(Vector3(0.0, 60.0, 0.0), 0.0)
	h.run(100, func(t: int) -> InputCmd: return cmd(t, B_HEAVY if t == 1 else 0))
	var n := 0
	var first := -1
	for i in h.trace.size():
		if int(h.trace[i]["loco"]) == L.HEAVY_LUNGE and (h.trace[i]["vel"] as Vector3).length() == 0.0:
			n += 1
			if first < 0:
				first = i
	assert_eq(n, 19, "recovery: 19 ticks with velocity exactly zero")
	assert_eq(first, 24 + 39, "recovery starts right after the lunge")
	done()


## Crouch held through a mantle glides at ~537 u/s (measured session 4);
## slide friction 0.1875 applies on the entry tick.
func test_fp1_g11_mantle_glide() -> void:
	var h := new_harness(&"flat")
	ArenaBuilder.add_ledge(h.root, Vector3(0.0, 0.0, -5.0), 64, 6.0)
	await h.ready()
	h.spawn(Vector3(0.0, 0.0, -5.0 + R + 0.3), 0.0)
	h.run(40, hold(B_JUMP | B_CROUCH, 0, 1))
	var s0 := first_event(h.trace, MoveEvents.SLIDE_START)
	assert_true(s0 >= 0, "slide after the mantle")
	if s0 >= 0:
		assert_near(float(h.trace[s0]["hspeed"]) / 0.0254, 537.0, 15.0, "glide speed ~537 u/s")
	done()


## G13: the wall jump pushes along the closest wall's normal. In an inside corner 0.05 m from the
## x wall and 0.2 m from the z wall, a neutral kick goes straight off the x wall (the old
## average normal gave -3.18 / +3.18).
func test_fp1_g13_closest_wall_normal() -> void:
	var h := new_harness(&"flat")
	ArenaBuilder.add_wall(h.root, Vector3(1.25, 5.0, 0.0), Vector3(0.5, 10.0, 10.0))
	ArenaBuilder.add_wall(h.root, Vector3(0.0, 5.0, -1.25), Vector3(10.0, 10.0, 0.5))
	await h.ready()
	h.spawn(Vector3(1.0 - R - 0.05, 3.0, -1.0 + R + 0.2), 0.0)
	h.run(2, func(t: int) -> InputCmd: return cmd(t, B_JUMP if t == 1 else 0))
	var i := first_event(h.trace, MoveEvents.WALL_JUMP)
	assert_eq(i, 0, "wall jump on tick 1")
	if i >= 0:
		var v: Vector3 = h.trace[i]["vel"]
		assert_near(v.x, -6.807, 0.05, "kick along the closest (x) wall normal")
		assert_near(v.z, 0.0, 0.05, "no component from the farther (z) wall")
	done()


## G18: dashing off a ledge keeps the dash-jump window (ground_dash.md rule 15); an airborne
## dash-jump at k=25 works and uses no air jump. PROVISIONAL (G18): exact grace pending recording.
func test_fp1_g18_coyote_dash_jump() -> void:
	var h := new_harness(&"none", null, hero_with(1))
	ArenaBuilder.add_box(h.root, Vector3(0.0, 1.0, 0.0), Vector3(4.0, 2.0, 4.0), "Platform")
	await h.ready()
	h.spawn(Vector3(0.0, 2.0, 1.5), 0.0)
	h.run(40, func(t: int) -> InputCmd: return cmd(t, B_DASH if t == 1 else (B_JUMP if t == 26 else 0)))
	assert_true(not bool(h.trace[24]["grounded"]), "airborne off the ledge before the press")
	var i := first_event(h.trace, MoveEvents.JUMPED, "kind", &"dash_jump")
	assert_eq(i, 25, "airborne dash-jump at k=25")
	if i >= 0:
		assert_near((h.trace[i]["vel"] as Vector3).y, 10.795 - G * DT, 1e-4, "dash-jump vy 425 u/s")
		# measured session 4: dash_jump_speed_mode 1 sets 703 u/s (session4_findings.md)
		assert_near(h.trace[i]["hspeed"] / 0.0254, 703.0, 5.0, "dash-jump sets ~703 u/s")
	assert_eq(h.state.air_jumps_used, 0, "no air jump used")
	done()


## G20: a crouch press at any time during the dash starts the dash slide at the current speed
## (ground_dash.md rules 7-8): press at k=10 -> SLIDE (DASH) on that tick at 16.129*(1-0.1875/64).
## Crouch already held at dash start is stored (rule 9): no slide during the dash.
func test_fp1_g20_dash_slide_on_press() -> void:
	var h := new_harness(&"flat")
	await h.ready()
	h.run(20, func(t: int) -> InputCmd: return cmd(t, B_DASH if t == 1 else (B_CROUCH if t >= 11 else 0)))
	assert_eq(first_event(h.trace, MoveEvents.SLIDE_START, "kind", MoveState.SlideKind.DASH), 10, "dash slide on the press tick (k=10)")
	# measured session 3: the dash slide starts at ~643 u/s
	assert_near(float(h.trace[10]["hspeed"]) / 0.0254, 643.0, 10.0, "dash slide starts near 643 u/s")
	var h2 := new_harness(&"flat")
	await h2.ready()
	h2.run(40, hold(B_DASH | B_CROUCH))
	assert_eq(count_loco(h2.trace, L.SLIDE), 0, "stored crouch: no slide during the dash")
	done()


## G28: down dash costs 0.5 stamina (wiki Stamina page).
func test_fp1_g28_down_dash_cost() -> void:
	var h := new_harness(&"flat")
	await h.ready()
	h.spawn(Vector3(0.0, 20.0, 0.0), 0.0)
	h.run(10, func(t: int) -> InputCmd: return cmd(t, B_CROUCH if (t == 1 or t == 5) else 0))
	var i := first_event(h.trace, MoveEvents.DASHED, "kind", &"down")
	assert_eq(i, 4, "down dash on the second tap")
	if i >= 0:
		assert_near(h.trace[i]["stamina"], 2.5, 1e-9, "down dash costs 0.5")
	done()


## G36: falling next to a wall is capped at 600 u/s = 15.24 m/s (walls_and_ledges.md rule 21).
## PROVISIONAL (G36): trigger pending recording. Away from walls the fall is not capped.
func test_fp1_g36_wall_slide_cap() -> void:
	var h := new_harness(&"flat")
	ArenaBuilder.add_wall(h.root, Vector3(1.25, 50.0, 0.0), Vector3(0.5, 100.0, 10.0))
	await h.ready()
	h.spawn(Vector3(1.0 - R - 0.1, 80.0, 0.0), 0.0)
	h.state.velocity = Vector3(0.0, -20.0, 0.0)
	h.run(1, hold())
	assert_near((h.trace[0]["vel"] as Vector3).y, -15.24, 1e-6, "fall capped at -600 u/s on the wall")
	h.spawn(Vector3(-20.0, 80.0, 0.0), 0.0)
	h.state.velocity = Vector3(0.0, -20.0, 0.0)
	h.run(1, hold())
	assert_near((h.trace[0]["vel"] as Vector3).y, -20.0 - G * DT, 1e-5, "no cap away from walls")
	done()


## G40 (fixes K6): crouch held at takeoff is stored, so landing does not slide while it stays held.
## Control: crouch pressed after takeoff slides on landing (speed 12 m/s > 8.89 slide entry).
func test_fp1_g40_crouch_storage_takeoff() -> void:
	var h := new_harness(&"flat")
	await h.ready()
	h.state.velocity = Vector3(0.0, 0.0, -12.0)
	h.run(80, func(t: int) -> InputCmd: return cmd(t, B_CROUCH | (B_JUMP if t == 1 else 0)))
	var land := first_event(h.trace, MoveEvents.LANDED)
	assert_true(land > 0, "landed")
	assert_eq(count_loco(h.trace, L.SLIDE), 0, "crouch held at takeoff: no slide")
	if land > 0:
		assert_eq(int(h.trace[land]["loco"]), L.CROUCH, "lands into CROUCH")
	var h2 := new_harness(&"flat")
	await h2.ready()
	h2.state.velocity = Vector3(0.0, 0.0, -12.0)
	h2.run(80, func(t: int) -> InputCmd: return cmd(t, B_JUMP if t == 1 else (B_CROUCH if t >= 10 else 0)))
	var land2 := first_event(h2.trace, MoveEvents.LANDED)
	assert_true(land2 > 0 and int(h2.trace[land2]["loco"]) == L.SLIDE, "control: crouch pressed in the air slides on landing")
	done()


## G45: parry roots the player (move multiplier 0) and keeps gravity (ziplines_melee_misc.md).
func test_fp1_g45_parry_root() -> void:
	var h := new_harness(&"flat")
	await h.ready()
	h.run(40, func(t: int) -> InputCmd: return cmd(t, B_PARRY if t == 1 else 0, 0, 1))
	assert_near(h.cp.effective_move_speed(h.state, false), 0.0, 1e-9, "move speed 0 during parry")
	assert_near(h.state.horizontal_speed(), 0.0, 1e-9, "no movement while parrying with forward held")
	var h2 := new_harness(&"flat")
	await h2.ready()
	h2.spawn(Vector3(0.0, 20.0, 0.0), 0.0)
	h2.run(2, func(t: int) -> InputCmd: return cmd(t, B_PARRY if t == 1 else 0))
	assert_near((h2.trace[1]["vel"] as Vector3).y, -2.0 * G * DT, 1e-6, "gravity kept during parry")
	done()


## G46: after the 2 s zero-drag zip exit window, drag is 0.25 (not 0.2) until landing.
func test_fp1_g46_zip_exit_drag() -> void:
	var h := new_harness(&"none", null, hero_with(1, 0.0))
	ArenaBuilder.add_zipline(h.root, PackedVector3Array([Vector3(0.0, 5.0, 0.0), Vector3(0.0, 9.0, -60.0)]), 18.0)
	ArenaBuilder.add_box(h.root, Vector3(0.0, 1.75, -2.0), Vector3(2.0, 3.5, 2.0), "Platform")
	await h.ready()
	h.spawn(Vector3(0.0, 3.5, -2.0), 0.0)
	h.run(240, func(t: int) -> InputCmd: return cmd(t, B_JUMP if t == 1 else (B_CROUCH if t == 40 else 0)))
	assert_eq(first_event(h.trace, MoveEvents.ZIP_DETACH) + 1, 40, "detached on tick 40")
	var hs0: float = h.trace[166]["hspeed"]
	assert_near(h.trace[167]["hspeed"], hs0 * (1.0 - 0.25 * DT), 1e-6, "drag 0.25 on the first tick after the window")
	assert_near(h.trace[167 + 63]["hspeed"], hs0 * pow(1.0 - 0.25 * DT, 64), 1e-5, "drag 0.25 over 1 s")
	done()


## Dash slow scales speed, not duration (ground_dash.md rule 6): DASH_DISTANCE_PCT -0.5 halves the
## speed (8.0645 m/s) and keeps 40 ticks.
func test_fp1_dash_slow_scales_speed() -> void:
	var h := new_harness(&"flat")
	await h.ready()
	h.sim.push_external(h.state, {"op": &"add_modifier", "def": ModifierDef.make(&"dash_slow", ModifierDef.Stat.DASH_DISTANCE_PCT, -0.5), "source": &"test"})
	h.run(60, func(t: int) -> InputCmd: return cmd(t, B_DASH if t == 1 else 0))
	assert_near(h.trace[0]["hspeed"], 16.129 * 0.5, 1e-3, "dash speed halved")
	assert_eq(count_loco(h.trace, L.GROUND_DASH), 39, "dash duration unchanged (39 whole ticks)")
	done()


## Dash bucket roster from the wiki Stamina page (ground_dash.md Q10): 9 / 18 / 11 heroes;
## the old spec's "most others B1" is wrong.
func test_fp1_dash_bucket_roster() -> void:
	var r := HeroMovementStats.DASH_BUCKET_ROSTER
	assert_eq((r[1] as Array).size(), 9, "B1 roster size")
	assert_eq((r[2] as Array).size(), 18, "B2 roster size")
	assert_eq((r[3] as Array).size(), 11, "B3 roster size")
	assert_eq(HeroMovementStats.dash_bucket_for("Haze"), 1, "Haze B1")
	assert_eq(HeroMovementStats.dash_bucket_for("Seven"), 2, "Seven B2")
	assert_eq(HeroMovementStats.dash_bucket_for("Abrams"), 3, "Abrams B3")
	assert_eq(HeroMovementStats.dash_bucket_for("Mo & Krill"), 3, "Mo & Krill B3")
	done()


## Measured session 4 (hop): a dash-slide jump cuts horizontal speed to ~x0.75. With crouch held, a late
## slide jump lands crouched (crouch stored); an early one lands back into a slide.
func test_fp1_dash_slide_jump() -> void:
	for k in [2, 25]:
		var h := new_harness(&"flat")
		await h.ready()
		var jt: int = 11 + k
		h.run(90, func(t: int) -> InputCmd: return cmd(t, (B_DASH if t == 1 else 0) | (B_CROUCH if t >= 11 else 0) | (B_JUMP if t == jt else 0)))
		var j := first_event(h.trace, MoveEvents.JUMPED)
		assert_true(j > 0, "jumped (k=%d)" % k)
		if j <= 0:
			continue
		var ratio := float(h.trace[j]["hspeed"]) / float(h.trace[j - 1]["hspeed"])
		assert_true(ratio > 0.7 and ratio < 0.8, "horizontal cut ~x0.75 (k=%d, got %.3f)" % [k, ratio])
		var land := first_event(h.trace, MoveEvents.LANDED)
		assert_true(land > j, "landed (k=%d)" % k)
		if land > j:
			assert_eq(int(h.trace[land]["loco"]), L.SLIDE if k == 2 else L.CROUCH, "landing loco (k=%d)" % k)
	done()


## session 4 (lslide): a dash-jump landing with crouch held slides only above the entry speed; the penalty
## starts ~0.69 s after touchdown. With S held in the air (landing slow) it lands crouched instead.
func test_fp1_dash_jump_landing_slide() -> void:
	for slow in [false, true]:
		var h := new_harness(&"flat")
		await h.ready()
		h.run(160, func(t: int) -> InputCmd:
			var my := -1 if (slow and t >= 30 and t < 60) else 0
			return cmd(t, (B_DASH if t == 1 else 0) | (B_JUMP if t == 21 else 0) | (B_CROUCH if t >= 40 else 0), 0, my))
		assert_true(first_event(h.trace, MoveEvents.JUMPED, "kind", &"dash_jump") > 0, "dash jump (slow=%s)" % slow)
		var land := first_event(h.trace, MoveEvents.LANDED)
		assert_true(land > 0, "landed (slow=%s)" % slow)
		if land <= 0:
			continue
		assert_eq(int(h.trace[land]["loco"]), L.CROUCH if slow else L.SLIDE, "landing loco (slow=%s)" % slow)
		if not slow:
			var pen := first_event(h.trace, MoveEvents.SLIDE_PENALTY, "", null, land)
			assert_true(pen - land >= 38 and pen - land <= 50, "penalty ~44 ticks after landing (got %d)" % (pen - land))
	done()
