extends MoveTestCase
## Zipline and rope (design §13.1).


## spec: movement.md §16 zipline attach, lane speed, exit momentum 2 s without drag (T27)
func test_t27_zipline() -> void:
	var h := new_harness(&"none", null, hero_with(1, 0.0))
	ArenaBuilder.add_zipline(h.root, PackedVector3Array([Vector3(0.0, 5.0, 0.0), Vector3(0.0, 9.0, -60.0)]), 18.0)
	ArenaBuilder.add_box(h.root, Vector3(0.0, 1.75, -2.0), Vector3(2.0, 3.5, 2.0), "Platform")
	await h.ready()
	h.spawn(Vector3(0.0, 3.5, -2.0), 0.0)
	h.suppress_sprint = false
	h.state.sprint_active = true
	h.state.sprint_timer_ticks = 300
	h.state.sprint_bonus_current = 1.6
	h.state.air_jumps_used = 1
	h.state.air_dashes_used = 1
	h.run(3, func(t: int) -> InputCmd: return cmd(t, B_JUMP if t == 1 else 0))
	assert_eq(int(h.trace[0]["loco"]), L.ZIPLINE, "attached on tick 1")
	assert_true(first_event(h.trace, MoveEvents.ZIP_ATTACH) == 0, "ZIP_ATTACH on tick 1")
	assert_near((h.trace[2]["vel"] as Vector3).length(), 18.0, 1e-3, "lane speed")
	assert_eq(h.state.air_jumps_used, 0, "air jumps refreshed on attach")
	assert_eq(h.state.air_dashes_used, 0, "air dashes refreshed on attach")
	assert_true(not h.state.sprint_active and h.state.sprint_timer_ticks <= 3, "sprint reset on attach")
	h.run(200, func(t: int) -> InputCmd: return cmd(t, B_CROUCH if t == 40 else 0))
	var d := first_event(h.trace, MoveEvents.ZIP_DETACH)
	assert_eq(d + 1, 40, "detached by crouch on tick 40")
	var hs0: float = h.trace[39]["hspeed"]
	var steady := true
	for k in range(39, 167):
		if absf(float(h.trace[k]["hspeed"]) - hs0) > 1e-6:
			steady = false
			fail("exit momentum changed at tick %d: %.6f vs %.6f" % [k + 1, float(h.trace[k]["hspeed"]), hs0])
			break
	assert_true(steady, "no drag for 128 ticks after detach")
	assert_true(float(h.trace[167]["hspeed"]) < hs0 - 1e-6, "drag resumes on tick 168")
	done()


## spec: movement.md §17 rope climb 4 m/s, 40% slower under ROPE_SLOW (T28)
func test_t28_rope() -> void:
	for slowed in [false, true]:
		var h := new_harness(&"none")
		ArenaBuilder.add_rope(h.root, Vector3(0.0, 12.0, 0.0), 10.0)
		await h.ready()
		h.spawn(Vector3(0.3, 5.0, 0.0), 0.0)
		if slowed:
			h.sim.push_external(h.state, {"op": &"add_modifier", "def": ModifierDef.make(&"rope_slow", ModifierDef.Stat.ROPE_SLOW, 0.4), "source": &"test"})
		h.run(8, hold(B_JUMP))
		assert_eq(int(h.trace[0]["loco"]), L.ROPE, "attached to the rope on tick 1")
		var vy: float = (h.trace[4]["vel"] as Vector3).y
		assert_near(vy, 2.4 if slowed else 4.0, 1e-3, "climb speed%s" % (" (slowed)" if slowed else ""))
	done()
