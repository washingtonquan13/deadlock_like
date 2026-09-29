extends MoveTestCase
## Cast state, charges and progression (specs/abilities.md). Loose on purpose.


func _data(kind: String, cd_on_end := false) -> AbilityData:
	return AbilityData.from_dict({"id": "t", "kind": kind, "cd_on_end": cd_on_end, "props": {"cooldown": 10}})


func _run(c: CastSlot, seconds: float) -> void:
	for i in int(roundf(seconds / MoveUnits.DT)):
		c.step(MoveUnits.DT)


## spec: abilities.md M1–M4
func test_progression() -> void:
	assert_eq(Progression.level_for(600), 0, "start is level 0")
	assert_eq(Progression.level_for(49200), 35, "max level")
	assert_eq(Progression.ap_total(35), 32, "32 AP in total")
	assert_eq(Progression.regular_unlocks(4), 3, "3 abilities by level 4")
	assert_true(Progression.ultimate_unlocked(7) and not Progression.ultimate_unlocked(6), "ult at 7")
	done()


## spec: abilities.md M5, M7 — charges restore one at a time; the lockout ignores CDR
func test_charges_and_lockout() -> void:
	var c := CastSlot.new(_data("instant"))
	c.configure(10.0, 2, 2.0, 0.0, 0.0)
	var casts := [0]
	c.fired.connect(func(e: StringName) -> void: if e == &"cast": casts[0] += 1)
	assert_true(c.press(), "first charge")
	assert_true(not c.press(), "lockout blocks the second")
	_run(c, 2.1)
	assert_true(c.press(), "second charge after the lockout")
	assert_eq(c.charges, 0, "out of charges")
	_run(c, 8.0)
	assert_eq(c.charges, 1, "one charge back after the cooldown")
	_run(c, 10.0)
	assert_eq(c.charges, 2, "then the next")
	assert_eq(casts[0], 2, "two casts fired")
	var s := StatSheet.new()
	s.set_source(&"a", {StatDefs.COOLDOWN: 20})
	s.set_source(&"b", {StatDefs.COOLDOWN: 20})
	var a := _data("instant")
	assert_near(a.value(&"cooldown", 0, s, 0.0, 0), 6.4, 1e-3, "CDR stacks multiplicatively")
	done()


## spec: abilities.md M6 — channel ends into its effect; cancelling still costs the cooldown
func test_channel_and_toggle() -> void:
	var c := CastSlot.new(_data("channel"))
	c.configure(10.0, 1, 0.0, 0.0, 1.0)
	var ev := []
	c.fired.connect(func(e: StringName) -> void: ev.append(e))
	c.press()
	_run(c, 1.1)
	assert_true(ev.has(&"channel_end"), "channel finishes")
	var d := CastSlot.new(_data("channel", true))
	d.configure(10.0, 1, 0.0, 0.0, 1.0)
	d.press()
	d.cancel()
	assert_true(not d.is_ready(), "cancel puts it on cooldown")
	var t := CastSlot.new(_data("toggle", true))
	t.configure(10.0, 1, 0.0, 0.0, 0.0)
	t.press()
	assert_eq(t.phase, CastSlot.Phase.ACTIVE, "toggle on")
	assert_eq(t.charges, 1, "cd_on_end: no cooldown while on")
	t.press()
	assert_true(t.phase == CastSlot.Phase.IDLE and t.charges == 0, "toggle off starts the cooldown")
	done()


## Kit data loads and scales with spirit power and upgrades.
func test_kit_values() -> void:
	var kit := AbilityDB.kit(&"pyre")
	assert_eq(kit.size(), 4, "4 abilities")
	assert_true(kit[3].is_ultimate, "last is the ultimate")
	assert_near(kit[0].value(&"damage", 0, null, 100.0, 0), 100.0, 1e-3, "40 + 0.6 x 100 SP")
	assert_near(kit[1].value(&"cooldown", 1, null, 0.0, 0), 26.0, 1e-3, "T1 -12 s")
	var s := StatSheet.new()
	s.set_source(&"a", {StatDefs.CHARGES: 1})
	assert_near(kit[0].value(&"charges", 0, s, 0.0, 0), 1.0, 1e-3, "no bonus charge on a 1-charge ability")
	assert_near(kit[0].value(&"charges", 1, s, 0.0, 0), 3.0, 1e-3, "bonus charge once it has charges")
	done()
