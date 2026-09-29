extends MoveTestCase
## Bullets as data: hits, walls, drop and a stress run (docs/design/gun_system_plan.md). Loose on purpose.

var ps: ProjectileSystem


func _setup(wall := false) -> void:
	new_harness(&"flat")
	if wall:
		ArenaBuilder.add_box(harness.root, Vector3(0, 2, -10), Vector3(6, 4, 0.5), "Wall")
	ps = ProjectileSystem.new()
	ps.auto_tick = false
	ps.draw_tracers = false
	harness.root.add_child(ps)
	await harness.ready()


func _dummy(pos: Vector3) -> TargetDummy:
	var d := TargetDummy.new()
	d.show_visual = false
	harness.root.add_child(d)
	d.global_position = pos
	return d


func _fly(ticks: int) -> void:
	for i in ticks:
		ps.step_tick()


## spec: combat.md §3/§4: head = crit with falloff, body = no crit
func test_proj_head_and_body() -> void:
	await _setup()
	var w := WeaponDB.get_weapon(&"haze")
	var d := _dummy(Vector3(0, 0, -30))
	var hits: Array = []
	ps.bullet_hit.connect(func(info: Dictionary) -> void: hits.append(info))
	ps.spawn(Vector3(0, d.head_center, 0), Vector3.FORWARD, w, w.bullet_damage)
	ps.spawn(Vector3(0, 1.0, 0), Vector3.FORWARD, w, w.bullet_damage)
	_fly(10)
	assert_eq(hits.size(), 2, "two hits")
	if hits.size() == 2:
		var head: Dictionary = hits[0] if hits[0]["is_head"] else hits[1]
		var body: Dictionary = hits[1] if hits[0]["is_head"] else hits[0]
		assert_true(head["is_crit"] and not body["is_crit"], "head crits, body does not")
		var fo := CombatMath.falloff_scale(w, float(body["distance"]))
		assert_near(float(body["amount"]), w.bullet_damage * fo, 1e-3, "body = base x falloff")
		assert_near(float(head["amount"]) / float(body["amount"]), 1.65, 0.02, "head ratio 1.65")
	assert_eq(ps.live_count, 0, "both consumed")
	done()


func test_proj_wall_and_drop() -> void:
	await _setup(true)
	var w := WeaponDB.get_weapon(&"haze")   # gravity scale 1.5
	var d := _dummy(Vector3(0, 0, -20))
	ps.spawn(Vector3(0, 1.0, 0), Vector3.FORWARD, w, w.bullet_damage)
	_fly(10)
	assert_near(d.total_damage, 0.0, 1e-6, "wall blocks")
	assert_eq(ps.live_count, 0, "bullet died on the wall")
	var i := ps.spawn(Vector3(0, 50, 20), Vector3.BACK, w, w.bullet_damage)
	_fly(12)   # 0.1875 s (Haze bullets expire at 178 m, 0.233 s)
	var drop := 50.0 - ps.get_bullet_position(i).y
	assert_near(drop, 0.5 * ProjectileSystem.GRAVITY * 1.5 * 0.1875 * 0.1875, 0.02, "gravity drop")
	done()


## Paige pierces: one bullet, two dummies
func test_proj_pierce() -> void:
	await _setup()
	var w := WeaponDB.get_weapon(&"paige")
	var a := _dummy(Vector3(0, 0, -5))
	var b := _dummy(Vector3(0, 0, -9))
	ps.spawn(Vector3(0, 1.0, 0), Vector3.FORWARD, w, w.bullet_damage)
	_fly(20)
	assert_true(a.total_damage > 0.0 and b.total_damage > 0.0, "pierced both")
	done()


## Thousands of bullets stay cheap: no physics bodies, one ray each per tick.
func test_proj_stress() -> void:
	await _setup()
	var w := WeaponDB.get_weapon(&"bebop")
	_dummy(Vector3(0, 0, -15))
	for k in 4000:
		var a := TAU * k / 4000.0
		ps.spawn(Vector3(0, 1.5, 0), Vector3(cos(a), 0.02 * sin(a * 7.0), sin(a)), w, 1.0)
	var t0 := Time.get_ticks_usec()
	_fly(16)
	var per_tick_ms := (Time.get_ticks_usec() - t0) / 16000.0
	print("  stress: 4000 bullets, %.2f ms per tick" % per_tick_ms)
	assert_true(per_tick_ms < 60.0, "4000 bullets under a loose 60 ms per tick (%.1f)" % per_tick_ms)
	done()
