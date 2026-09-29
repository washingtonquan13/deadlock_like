extends MoveTestCase
## Gun math and firing state machine (docs/design/gun_system_plan.md). Loose on purpose.


func _hold(s: WeaponState, w: WeaponData, ticks: int, fire := true) -> int:
	var n := 0
	for i in ticks:
		n += WeaponSim.step(s, w, fire, false).size()
	return n


## spec: combat.md table + §2 DPS formula (Haze 50.1)
func test_gun_data_all_heroes() -> void:
	assert_eq(WeaponDB.keys().size(), 38, "38 hero guns")
	var haze := WeaponDB.get_weapon(&"haze")
	assert_near(haze.burst_dps(), 50.1, 0.1, "haze burst dps")
	assert_near(WeaponDB.get_weapon(&"lash").burst_dps(), 49.3, 0.1, "lash dps matches the data table")
	done()


## spec: combat.md §3, §4
func test_gun_falloff_and_crit() -> void:
	var w := WeaponDB.get_weapon(&"haze")   # 20 -> 46 m, 0.1
	assert_near(CombatMath.falloff_scale(w, 10.0), 1.0, 1e-6, "inside start")
	assert_near(CombatMath.falloff_scale(w, 33.0), 0.55, 1e-6, "linear midpoint")
	assert_near(CombatMath.falloff_scale(w, 80.0), 0.1, 1e-6, "past end")
	var apollo := WeaponDB.get_weapon(&"apollo")
	assert_near(CombatMath.falloff_scale(apollo, 26.0), 0.0, 1e-6, "apollo cut-off")
	assert_near(CombatMath.crit_mult(0.0, 1.0), 1.65, 1e-6, "base crit")
	assert_near(CombatMath.crit_mult(-0.45, 1.0), 1.3575, 1e-6, "drifter crit")
	assert_near(CombatMath.crit_mult(0.0, 0.45), 1.2925, 1e-6, "vs seven")
	assert_near(CombatMath.fire_rate_mult([0.18, 0.2], [0.25, 0.28]), 1.0 / 1.08, 1e-3, "§12 example -8%")
	done()


## Haze empties 25 rounds in ~24 cycles, then a 2.35 s reload
func test_gun_auto_fire_and_reload() -> void:
	var w := WeaponDB.get_weapon(&"haze")
	var s := WeaponSim.new_state(w)
	var n := _hold(s, w, 64)   # 1 s: ~9.5 shots
	assert_true(n >= 9 and n <= 10, "haze shots in 1 s: %d" % n)
	n += _hold(s, w, 128)
	assert_eq(n, 25, "clip empties")
	assert_true(s.is_reloading(), "auto reload")
	_hold(s, w, int(2.4 * 64), false)
	assert_eq(s.ammo, 25, "reloaded")
	done()


## Lash: 3-shot bursts 0.084 s apart, then a 0.2625 s pause
func test_gun_burst() -> void:
	var w := WeaponDB.get_weapon(&"lash")
	var s := WeaponSim.new_state(w)
	var times: Array = []
	for i in 48:
		for sh in WeaponSim.step(s, w, true, false):
			times.append(sh["time"])
	assert_true(times.size() >= 6, "two bursts")
	assert_near(times[1] - times[0], 0.084, 1e-4, "intra-burst gap")
	assert_near(times[3] - times[0], 0.2625 + 3 * 0.084, 1e-4, "burst to burst")
	done()


## McGinnis spins up from 0.21 s toward 0.084 s
func test_gun_spin_up() -> void:
	var w := WeaponDB.get_weapon(&"mcginnis")
	var s := WeaponSim.new_state(w)
	var early := _hold(s, w, 64)
	_hold(s, w, 64)
	var late := _hold(s, w, 64)   # fully spun: ~12 shots/s
	assert_true(late > early + 3, "spin-up speeds fire (%d -> %d)" % [early, late])
	_hold(s, w, 64 * 5, false)
	assert_near(s.spin, 0.0, 1e-6, "spins down")
	done()


## Abrams: shells go in one at a time, a trigger press interrupts and keeps them
func test_gun_single_shell_reload() -> void:
	var w := WeaponDB.get_weapon(&"abrams")
	var s := WeaponSim.new_state(w)
	var shots := _hold(s, w, int(5.2 * 64))   # 9 shots 0.63 s apart
	assert_eq(shots, 9, "clip of 9")
	assert_true(s.mode == WeaponState.Mode.RELOADING_SINGLE, "single reload")
	_hold(s, w, int((0.705 + 0.352 * 3 + 0.1) * 64), false)
	assert_eq(s.ammo, 3, "three shells")
	var fired := WeaponSim.step(s, w, true, false).size()
	assert_eq(fired, 1, "fire interrupts")
	assert_eq(s.ammo, 2, "kept shells")
	assert_true(not s.is_reloading(), "reload cancelled")
	done()


## spec: slide_and_slopes.md rule 26, sliding fires without spending ammo
func test_gun_slide_infinite_ammo() -> void:
	var w := WeaponDB.get_weapon(&"haze")
	var s := WeaponSim.new_state(w)
	var n := 0
	for i in 64 * 5:
		n += WeaponSim.step(s, w, true, false, 1.0, 1.0, true).size()
	assert_true(n > w.clip_size and s.ammo == w.clip_size, "fired %d, clip still full" % n)
	done()
