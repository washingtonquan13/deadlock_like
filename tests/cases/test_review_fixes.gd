extends MoveTestCase
## Regression tests for the movement review fixes (see docs/design/movement_status.md).

const R := 0.4064   # capsule radius (MovementParams.capsule_radius default)


static func _air_ticks(tr: Array[Dictionary], from: int, to: int) -> int:
	var n := 0
	for k in range(from, mini(to, tr.size())):
		if not bool(tr[k]["grounded"]):
			n += 1
	return n


static func _first_z_at_least(tr: Array[Dictionary], z: float) -> int:
	for k in tr.size():
		if (tr[k]["pos"] as Vector3).z >= z:
			return k
	return -1


## spec: movement.md impl notes ground separation: walking/dashing downhill stays grounded
func test_rf_downhill_stays_grounded() -> void:
	for angle: float in [25.0, 40.0]:
		var h := new_harness(&"flat")
		var length := 8.0
		var run := length * cos(deg_to_rad(angle))
		var top := length * sin(deg_to_rad(angle))
		ArenaBuilder.add_ramp(h.root, Vector3(0.0, 0.0, 0.0), angle, length, 3.0)
		await h.ready()
		# start on the slope just below the crest, walk downhill (+Z)
		var z0 := -run + 1.0
		h.spawn(Vector3(0.0, top - 1.0 * tan(deg_to_rad(angle)), z0), PI)
		assert_true(h.state.grounded, "%d deg: spawned on the ramp" % int(angle))
		h.run(120, hold(0, 0, 1, PI))
		var reach := _first_z_at_least(h.trace, 1.5)
		assert_true(reach >= 0, "%d deg: reached the floor past the ramp" % int(angle))
		assert_eq(_air_ticks(h.trace, 0, reach + 1), 0, "%d deg: airborne ticks walking downhill" % int(angle))
	# ground dash down a 25 deg ramp
	var hd := new_harness(&"flat")
	ArenaBuilder.add_ramp(hd.root, Vector3.ZERO, 25.0, 12.0, 3.0)
	await hd.ready()
	var run2 := 12.0 * cos(deg_to_rad(25.0))
	hd.spawn(Vector3(0.0, (run2 - 1.0) * tan(deg_to_rad(25.0)), -run2 + 1.0), PI)
	hd.run(30, func(t: int) -> InputCmd: return cmd(t, B_DASH if t == 1 else 0, 0, 1, PI))
	assert_eq(_air_ticks(hd.trace, 0, 30), 0, "25 deg: airborne ticks during a downhill ground dash")
	done()


## spec: movement.md impl notes step-down: off a 0.3 m step and down stairs without going airborne
func test_rf_step_down_and_stairs() -> void:
	var h := new_harness(&"flat")
	ArenaBuilder.add_box(h.root, Vector3(0.0, 0.15, -3.0), Vector3(3.0, 0.3, 4.0), "Step30")
	ArenaBuilder.add_stairs(h.root, Vector3(6.0, 0.0, -4.0), 16.0 * ArenaBuilder.HU, 0.5, 8, 3.0)
	await h.ready()
	h.spawn(Vector3(0.0, 0.3, -3.0), PI)
	h.run(60, hold(0, 0, 1, PI))
	var reach := _first_z_at_least(h.trace, 0.5)
	assert_true(reach >= 0, "walked off the 0.3 m step")
	assert_eq(_air_ticks(h.trace, 0, reach + 1), 0, "airborne ticks stepping off 0.3 m")
	assert_near(h.state.position.y, 0.0, 0.01, "on the floor after the step")
	var top := 8.0 * 16.0 * ArenaBuilder.HU
	h.spawn(Vector3(6.0, top, -9.0), PI)
	assert_true(h.state.grounded, "spawned on the stair landing")
	h.run(120, hold(0, 0, 1, PI))
	var reach2 := _first_z_at_least(h.trace, -3.0)
	assert_true(reach2 >= 0, "walked down the stairs")
	assert_eq(_air_ticks(h.trace, 0, reach2 + 1), 0, "airborne ticks walking down 16u stairs")
	done()


## spec: movement.md §9 dash-jump works on a 12 deg downhill
func test_rf_downhill_dash_jump() -> void:
	var h := new_harness(&"flat")
	ArenaBuilder.add_ramp(h.root, Vector3.ZERO, 12.0, 20.0, 3.0)
	await h.ready()
	var run := 20.0 * cos(deg_to_rad(12.0))
	h.spawn(Vector3(0.0, (run - 1.0) * tan(deg_to_rad(12.0)), -run + 1.0), PI)
	h.run(60, func(t: int) -> InputCmd:
		var b := 0
		if t == 1:
			b = B_DASH
		elif t == 23:
			b = B_JUMP
		return cmd(t, b, 0, 0, PI))
	assert_eq(first_event(h.trace, MoveEvents.JUMPED, "kind", &"dash_jump"), 22, "dash-jump at k=22 on a 12 deg downhill")
	done()


## spec: movement.md §6 crouch storage: a dash with crouch held never becomes a slide
func test_rf_crouch_storage_no_slide() -> void:
	var h := new_harness(&"flat")
	ArenaBuilder.add_ramp(h.root, Vector3(10.0, 0.0, 0.0), 20.0, 16.0, 3.0)
	await h.ready()
	h.run(80, func(t: int) -> InputCmd: return cmd(t, B_CROUCH | (B_DASH if t == 3 else 0), 0, 1))
	assert_true(first_event(h.trace, MoveEvents.DASHED) >= 0, "dashed with crouch held")
	assert_eq(count_loco(h.trace, L.SLIDE), 0, "flat: no slide after a crouch-stored dash")
	assert_eq(h.state.loco, L.CROUCH, "flat: crouching after the dash")
	# downhill on a 20 deg ramp (slide slope)
	var run := 16.0 * cos(deg_to_rad(20.0))
	h.spawn(Vector3(10.0, (run - 1.0) * tan(deg_to_rad(20.0)), -run + 1.0), PI)
	h.run(80, func(t: int) -> InputCmd: return cmd(t, B_CROUCH | (B_DASH if t == 3 else 0), 0, 1, PI))
	# pressing crouch on a slide slope before the dash slides legitimately; only the time after the dash counts
	var dash_k := first_event(h.trace, MoveEvents.DASHED)
	assert_true(dash_k >= 0, "slope: dashed out of the slope slide")
	assert_eq(first_loco(h.trace, L.SLIDE, dash_k), -1, "slope: no slide after a crouch-stored dash")
	assert_eq(h.state.loco, L.CROUCH, "slope: crouching on the slide slope while crouch stays held")
	# releasing and pressing crouch again allows a slide on the slope
	h.run(2, hold(0, 0, 1, PI))
	h.run(4, hold(B_CROUCH, 0, 1, PI))
	assert_true(count_loco(h.trace, L.SLIDE) > 0 or not h.state.grounded, "re-pressed crouch may slide again")
	done()


## spec: movement.md §3 sprint rules: stopping and opposing keys reset; turning does not
func test_rf_sprint_resets() -> void:
	var h := new_harness(&"flat")
	await h.ready()
	h.suppress_sprint = false
	h.run(260, hold(0, 0, 1))
	assert_true(h.state.sprint_active, "sprinting")
	var snap := h.state.duplicate_state()
	# backpedal: wish opposes velocity but no opposing keys are held
	h.run(1, hold(0, 0, -1))
	assert_true(h.state.sprint_active, "reversing direction keeps sprint")
	# A+D held together while W is held (input sampler sets BTN_OPPOSE_X)
	h.state = snap.duplicate_state()
	h.run(1, hold(InputCmd.BTN_OPPOSE_X, 0, 1))
	assert_true(not h.state.sprint_active and h.state.sprint_timer_ticks == 0, "opposing keys reset sprint")
	assert_true(first_event(h.trace, MoveEvents.SPRINT_RESET, "reason", &"opposing") >= 0, "SPRINT_RESET(opposing)")
	# stopping
	h.state = snap.duplicate_state()
	h.run(120, hold())
	assert_near(h.state.horizontal_speed(), 0.0, 1e-6, "stopped")
	assert_eq(h.state.sprint_timer_ticks, 0, "stopping resets the sprint timer")
	h.run(1, hold(0, 0, 1))
	assert_true(not h.state.sprint_active, "no instant re-sprint after stopping")
	done()


## spec: movement.md §7/§14 wall-jump regen penalty only in combat
func test_rf_wall_jump_combat_penalty() -> void:
	for combat: bool in [false, true]:
		var h := new_harness(&"flat")
		ArenaBuilder.add_wall(h.root, Vector3(1.25, 5.0, 0.0), Vector3(0.5, 10.0, 10.0))
		await h.ready()
		h.suppress_sprint = false
		h.spawn(Vector3(1.0 - R - 0.1, 3.0, 0.0), 0.0)
		if combat:
			h.sim.push_external(h.state, {"op": &"combat_interaction"})
		h.run(1, func(t: int) -> InputCmd: return cmd(t, B_JUMP))
		assert_true(first_event(h.trace, MoveEvents.WALL_JUMP) == 0, "wall jump (combat=%s)" % combat)
		assert_eq(h.state.combat_regen_penalty_ticks > 0, combat, "regen penalty only in combat (combat=%s)" % combat)
	done()


## spec: movement.md §10 jump buffer (off by default): a press just before landing becomes a ground jump
func test_rf_jump_buffer() -> void:
	var p := MovementParams.new()
	p.jump_buffer_time = 0.1
	var h := new_harness(&"flat", p)
	await h.ready()
	h.spawn(Vector3(0.0, 2.0, 0.0), 0.0)
	h.run(80, hold())
	var land := first_event(h.trace, MoveEvents.LANDED)
	assert_true(land > 3, "baseline landing tick found")
	h.spawn(Vector3(0.0, 2.0, 0.0), 0.0)
	var press := land - 2   # trace index; the cmd tick is index + 1
	h.run(80, func(t: int) -> InputCmd: return cmd(t, B_JUMP if t == press + 1 else 0))
	assert_true(first_event(h.trace, MoveEvents.JUMPED, "kind", &"air") < 0, "no air jump burned")
	var j := first_event(h.trace, MoveEvents.JUMPED, "kind", &"ground")
	assert_true(j >= land and j <= land + 1, "buffered ground jump right after landing (got %d, landed %d)" % [j, land])
	assert_near(float(h.trace[maxi(j, 0)]["stamina"]), 3.0, 1e-9, "no stamina spent")
	# default params: the same press is an air jump
	var h2 := new_harness(&"flat")
	await h2.ready()
	h2.spawn(Vector3(0.0, 2.0, 0.0), 0.0)
	h2.run(80, func(t: int) -> InputCmd: return cmd(t, B_JUMP if t == press + 1 else 0))
	assert_true(first_event(h2.trace, MoveEvents.JUMPED, "kind", &"air") >= 0, "buffer off: air jump")
	done()


## spec: movement.md §6/§15 mantle started crouched ends standing once crouch is released
func test_rf_mantle_uncrouch() -> void:
	var h := new_harness(&"flat")
	ArenaBuilder.add_ledge(h.root, Vector3(0.0, 0.0, -5.0), 40, 6.0)
	await h.ready()
	h.spawn(Vector3(0.0, 0.0, -5.0 + R + 0.3), 0.0)
	h.state.air_jumps_used = 1
	h.state.air_dashes_used = 1
	h.run(5, hold(B_CROUCH))
	assert_true(h.state.crouched, "crouched before the mantle")
	h.run(3, hold(B_CROUCH | B_JUMP, 0, 1))
	h.run(60, hold(B_JUMP, 0, 1))
	h.run(40, hold(0, 0, 1))
	assert_true(count_loco(h.trace, L.MANTLE) > 0 or h.state.position.y > 0.9, "got onto the ledge")
	assert_true(not h.state.crouched, "stood up after the mantle")
	assert_true(h.state.loco != L.CROUCH, "not left in CROUCH")
	# safety net: GROUND with the crouch capsule and crouch released stands up
	h.spawn(Vector3(3.0, 0.0, 3.0), 0.0)
	h.state.crouched = true
	h.run(1, hold())
	assert_true(not h.state.crouched and h.state.loco == L.GROUND, "GROUND + crouched safety net")
	done()


## spec: movement.md §16 Zipline Boost cooldown and unlock; low rail never drags the capsule into the floor
func test_rf_zipline_boost_and_clearance() -> void:
	var h := new_harness(&"flat", null, hero_with(1, 0.0))
	ArenaBuilder.add_zipline(h.root, PackedVector3Array([Vector3(0.0, 1.2, 0.0), Vector3(0.0, 1.2, -200.0)]), 18.0)
	await h.ready()
	h.spawn(Vector3(0.0, 0.0, -1.0), 0.0)
	h.run(3, func(t: int) -> InputCmd: return cmd(t, B_JUMP if t == 1 else 0))
	assert_eq(h.state.loco, L.ZIPLINE, "attached")
	var tb := h.state.tick
	h.run(2, func(t: int) -> InputCmd: return cmd(t, InputCmd.BTN_ZIP_BOOST if t == tb + 1 else 0))
	assert_near(h.state.velocity.length(), 18.0, 1e-3, "boost locked before 360 s")
	h.state.tick = h.cp.zip_boost_unlock_ticks
	h.run(2, func(t: int) -> InputCmd: return cmd(t, InputCmd.BTN_ZIP_BOOST if t == h.cp.zip_boost_unlock_ticks + 1 else 0))
	assert_near(h.state.velocity.length(), 18.0 * 1.8, 1e-3, "boost +80% after unlock")
	h.state.zip_boost_ticks = 0
	var t0 := h.state.tick
	h.run(2, func(t: int) -> InputCmd: return cmd(t, InputCmd.BTN_ZIP_BOOST if t == t0 + 1 else 0))
	assert_near(h.state.velocity.length(), 18.0, 1e-3, "boost on cooldown")
	var min_y := INF
	for e in h.trace:
		min_y = minf(min_y, (e["pos"] as Vector3).y)
	assert_true(min_y > -0.01, "rail 1.2 m over the floor: feet never below the floor (min %.3f)" % min_y)
	done()


## spec: movement.md §14 fatigue recovery curve exponent
func test_rf_fatigue_exponent() -> void:
	for k: float in [1.0, 2.0]:
		var p := MovementParams.new()
		p.wall_jump_fatigue_recovery_exponent = k
		var h := new_harness(&"none", p, hero_with(1, 0.0))
		await h.ready()
		h.spawn(Vector3(0.0, 5.0, 0.0), 0.0)
		h.state.wall_fatigue = 0.5
		h.state.wall_fatigue_peak = 0.5
		h.state.wall_fatigue_recover_ticks = 0
		h.run(h.cp.wall_fatigue_recovery_ticks / 2, hold())
		assert_near(h.state.wall_fatigue, 0.5 * pow(0.5, k), 1e-6, "fatigue at half recovery (k=%.0f)" % k)
	done()


## spec: movement.md §5 melee self-slows are slows (resisted, floored), not raw multipliers
func test_rf_melee_self_slow_is_slow() -> void:
	var h := new_harness(&"flat")
	await h.ready()
	h.run(1, hold(InputCmd.BTN_MELEE_LIGHT, 0, 1))
	var found := false
	for m in h.state.modifiers:
		if m.id == &"light_melee_slow":
			found = true
			assert_eq(m.stat, ModifierDef.Stat.SLOW, "light melee self-slow uses Stat.SLOW")
	assert_true(found, "light melee self-slow applied")
	done()
