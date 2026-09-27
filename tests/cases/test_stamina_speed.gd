extends MoveTestCase
## Stamina regen, sprint, damage slow, vent, control locks, parry (design §13.1).


## spec: movement.md §7 one bar per 4.5 s (288 ticks), recovery bonus shortens it (T11)
func test_t11_stamina_regen() -> void:
	var h := new_harness(&"flat")
	await h.ready()
	h.run(300, func(t: int) -> InputCmd: return cmd(t, B_DASH if t == 1 else 0))
	var full := -1
	for i in h.trace.size():
		if float(h.trace[i]["stamina"]) >= 3.0 - 1e-9:
			full = i + 1
			break
	assert_eq(full, 288, "stamina full again on tick")
	var h2 := new_harness(&"flat")
	await h2.ready()
	h2.sim.push_external(h2.state, {"op": &"add_modifier", "def": ModifierDef.make(&"rec", ModifierDef.Stat.STAMINA_RECOVERY, 0.12), "source": &"test"})
	h2.run(300, func(t: int) -> InputCmd: return cmd(t, B_DASH if t == 1 else 0))
	full = -1
	for i in h2.trace.size():
		if float(h2.trace[i]["stamina"]) >= 3.0 - 1e-9:
			full = i + 1
			break
	assert_eq(full, 258, "stamina full with +12% recovery")
	done()


## spec: movement.md §3 sprint, §5 damage slow applies above base (T14)
func test_t14_sprint_damage_slow() -> void:
	var h := new_harness(&"flat")
	await h.ready()
	h.suppress_sprint = false
	# sprint starts on tick 192; the Source accel curve needs ~200 more ticks to settle to 1e-3
	h.run(400, hold(0, 0, 1))
	assert_true(h.state.sprint_active, "sprint active after 400 ticks")
	assert_near(h.cp.effective_move_speed(h.state, false), 8.8, 1e-6, "sprint speed")
	assert_near(h.state.horizontal_speed(), 8.8, 1e-3, "moving at sprint speed")
	# spec: movement.md §3 taking damage resets sprint (default damage op)
	var snap := h.state.duplicate_state()
	h.sim.push_external(h.state, {"op": &"damage", "from_hero": true})
	h.run(1, hold(0, 0, 1))
	assert_true(not h.state.sprint_active and h.state.sprint_timer_ticks == 0, "damage resets sprint")
	assert_near(h.cp.effective_move_speed(h.state, false), 7.2, 1e-6, "no above-base part left after the reset")
	assert_true(first_event(h.trace, MoveEvents.SPRINT_RESET, "reason", &"damage") >= 0, "SPRINT_RESET(damage) emitted")
	# spec: movement.md §5 damage slow = 20% of the speed above base (sprint kept via opt-out)
	h.state = snap
	h.sim.push_external(h.state, {"op": &"damage", "from_hero": true, "resets_sprint": false})
	h.run(1, hold(0, 0, 1))
	assert_near(h.cp.effective_move_speed(h.state, false), 8.48, 1e-6, "damage-slowed sprint speed (resets_sprint false)")
	assert_true(h.state.sprint_active, "opt-out keeps sprint")
	# spec: movement.md §5 the slow also applies to a non-sprint above-base bonus (+2 m/s item)
	var h2 := new_harness(&"flat")
	await h2.ready()
	h2.sim.push_external(h2.state, {"op": &"add_modifier", "def": ModifierDef.make(&"enduring", ModifierDef.Stat.MOVE_BONUS, 2.0), "source": &"test"})
	h2.run(1, hold(0, 0, 1))
	assert_near(h2.cp.effective_move_speed(h2.state, false), 9.2, 1e-6, "base + 2 m/s item")
	h2.sim.push_external(h2.state, {"op": &"damage", "from_hero": true})
	h2.run(1, hold(0, 0, 1))
	assert_near(h2.cp.effective_move_speed(h2.state, false), 8.8, 1e-6, "damage slow on the item bonus")
	done()


## spec: movement.md §4 vent multiplies the base part only (T15)
func test_t15_vent() -> void:
	var h := new_harness(&"flat")
	await h.ready()
	h.suppress_sprint = false
	h.run(260, hold(0, 0, 1))
	h.sim.push_external(h.state, {"op": &"add_modifier", "def": ModifierDef.make(&"vent", ModifierDef.Stat.VENT, 1.0), "source": &"test"})
	h.run(1, hold(0, 0, 1))
	assert_near(h.cp.effective_move_speed(h.state, false), 13.84, 1e-6, "vent + sprint speed")
	done()


## spec: movement.md §3 sprint delay 3 s, +2.5 instant, then 0.6 m/s per second; crouch resets (T16)
func test_t16_sprint_ramp() -> void:
	var hero := HeroMovementStats.new()
	hero.base_sprint_speed = 4.0
	var h := new_harness(&"flat", null, hero)
	await h.ready()
	h.suppress_sprint = false
	h.run(191, hold(0, 0, 1))
	assert_true(not h.state.sprint_active, "no sprint before tick 192")
	h.run(1, hold(0, 0, 1))
	assert_true(h.state.sprint_active, "sprint active on tick 192")
	assert_near(h.state.sprint_bonus_current, 2.5, 1e-9, "instant bonus")
	assert_true(first_event(h.trace, MoveEvents.SPRINT_START) + 1 == 192, "SPRINT_START on tick 192")
	h.run(159, hold(0, 0, 1))
	assert_true(h.state.sprint_bonus_current < 4.0 - 1e-9, "bonus below cap at tick 351 (got %.6f)" % h.state.sprint_bonus_current)
	h.run(1, hold(0, 0, 1))
	assert_near(h.state.sprint_bonus_current, 4.0, 1e-9, "bonus at cap on tick 352")
	# spec: movement.md §3/§13 sliding does not break sprint: a crouch press at sprint speed slides
	h.run(1, hold(B_CROUCH, 0, 1))
	assert_eq(h.state.loco, L.SLIDE, "crouch press at 11.2 m/s slides")
	assert_true(h.state.sprint_active and h.state.sprint_timer_ticks > 0, "sprint survives the slide start")
	# once the slide decays into a crouch, crouching resets sprint
	var n := 0
	while h.state.loco == L.SLIDE and n < 600:
		h.run(1, hold(B_CROUCH, 0, 1))
		n += 1
	assert_eq(h.state.loco, L.CROUCH, "slide ends in CROUCH")
	assert_true(not h.state.sprint_active, "crouch ends sprint")
	assert_eq(h.state.sprint_timer_ticks, 0, "crouch resets the timer")
	assert_near(h.state.sprint_bonus_current, 0.0, 1e-9, "bonus cleared")
	done()


## spec: movement.md §5 control locks: stun blocks jump/dash/move, friction still applies (T19)
func test_t19_stun_and_parry() -> void:
	var h := new_harness(&"flat")
	await h.ready()
	h.state.velocity = Vector3(0.0, 0.0, -7.2)
	h.sim.push_external(h.state, {"op": &"lock", "mask": ControlLocks.STUN, "duration": 1.0, "source": &"test"})
	h.run(40, func(t: int) -> InputCmd:
		var b := 0
		if t == 2:
			b = B_JUMP
		elif t == 3:
			b = B_DASH
		return cmd(t, b, 0, 1))
	assert_true(first_event(h.trace, MoveEvents.JUMPED) < 0, "no jump while stunned")
	assert_true(first_event(h.trace, MoveEvents.DASHED) < 0, "no dash while stunned")
	assert_true(first_event(h.trace, MoveEvents.LOCKED) == 0, "LOCKED event on tick 1")
	var v := 7.2
	var ok := true
	for i in h.trace.size():
		v = maxf(0.0, v - maxf(v, 2.54) * 4.0 / 64.0)
		if absf(float(h.trace[i]["hspeed"]) - v) > 1e-4:
			fail("stunned speed at tick %d: expected %.5f got %.5f" % [i + 1, v, float(h.trace[i]["hspeed"])])
			ok = false
			break
	assert_true(ok, "friction-only decay while stunned")
	# parry cancels a dash (spec: movement.md §19)
	var h2 := new_harness(&"flat")
	await h2.ready()
	h2.run(10, func(t: int) -> InputCmd: return cmd(t, B_DASH if t == 1 else (B_PARRY if t == 5 else 0)))
	assert_true(first_event(h2.trace, MoveEvents.PARRY_START) == 4, "PARRY_START on tick 5")
	assert_eq(int(h2.trace[4]["loco"]), L.GROUND, "parry ends the dash")
	assert_near(h2.trace[4]["hspeed"], 0.0, 1e-6, "parry stops dash momentum")
	done()
