extends MoveTestCase
## Pure numeric tests: units, DR stacking, slows (design §13.1).


## spec: movement.md §1 Units and tick (T01)
func test_t01_units_ticks() -> void:
	assert_eq(MoveUnits.ticks(0.62), 40, "ticks(0.62)")
	assert_eq(MoveUnits.ticks(0.3), 20, "ticks(0.3)")
	assert_eq(MoveUnits.ticks(0.75), 48, "ticks(0.75)")
	assert_eq(MoveUnits.ticks(1.0), 64, "ticks(1.0)")
	assert_eq(MoveUnits.ticks(0.4375), 28, "ticks(0.4375)")
	assert_eq(MoveUnits.ticks(0.2), 13, "ticks(0.2)")
	assert_eq(MoveUnits.ticks(0.4), 26, "ticks(0.4)")
	assert_eq(MoveUnits.ticks(0.5), 32, "ticks(0.5)")
	assert_near(MoveUnits.hu(350), 8.89, 1e-9, "hu(350)")
	assert_near(MoveUnits.DT, 1.0 / 64.0, 1e-12, "DT")
	done()


## spec: movement.md §4 move-speed bonus diminishing returns (T12)
func test_t12_move_bonus_dr() -> void:
	var cp := CompiledMoveParams.build(MovementParams.new(), HeroMovementStats.new())
	var s := MoveState.new()
	ModifierStack.add(s, ModifierDef.make(&"mb_a", ModifierDef.Stat.MOVE_BONUS, 2.0), &"test")
	assert_near(cp.effective_move_speed(s, false) - 7.2, 2.0, 1e-6, "DR +2")
	ModifierStack.add(s, ModifierDef.make(&"mb_b", ModifierDef.Stat.MOVE_BONUS, 2.0), &"test")
	ModifierStack.add(s, ModifierDef.make(&"mb_c", ModifierDef.Stat.MOVE_BONUS, 3.0), &"test")
	assert_near(cp.effective_move_speed(s, false) - 7.2, 5.75, 1e-6, "DR +2 +2 +3")
	done()


## spec: movement.md §5 slows: multiplicative stacking, resist, 2.0 m/s floor (T13)
func test_t13_slows() -> void:
	var hero := HeroMovementStats.new()
	hero.base_move_speed = 8.2
	var cp := CompiledMoveParams.build(MovementParams.new(), hero)
	var s := MoveState.new()
	ModifierStack.add(s, ModifierDef.make(&"slow_a", ModifierDef.Stat.SLOW, 0.3), &"test")
	ModifierStack.add(s, ModifierDef.make(&"slow_b", ModifierDef.Stat.SLOW, 0.2), &"test")
	ModifierStack.add(s, ModifierDef.make(&"resist", ModifierDef.Stat.SLOW_RESIST, 0.25), &"test")
	assert_near(cp.effective_move_speed(s, false), 6.154, 1e-3, "slowed speed")
	var s2 := MoveState.new()
	ModifierStack.add(s2, ModifierDef.make(&"slow_big", ModifierDef.Stat.SLOW, 0.99), &"test")
	assert_true(cp.effective_move_speed(s2, false) >= 2.0 - 1e-9, "SLOW 0.99 keeps speed >= 2.0 (got %.4f)" % cp.effective_move_speed(s2, false))
	# the sim uses the same value: steady walk under the slows
	var h := new_harness(&"flat", null, hero)
	await h.ready()
	h.sim.push_external(h.state, {"op": &"add_modifier", "def": ModifierDef.make(&"slow_a", ModifierDef.Stat.SLOW, 0.3), "source": &"test"})
	h.sim.push_external(h.state, {"op": &"add_modifier", "def": ModifierDef.make(&"slow_b", ModifierDef.Stat.SLOW, 0.2), "source": &"test"})
	h.sim.push_external(h.state, {"op": &"add_modifier", "def": ModifierDef.make(&"resist", ModifierDef.Stat.SLOW_RESIST, 0.25), "source": &"test"})
	h.run(400, hold(0, 0, 1))
	assert_near(h.state.horizontal_speed(), 6.154, 1e-3, "steady walk under slows")
	done()
