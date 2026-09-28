extends RefCounted
## s7 ramp scratch override: patches the in-memory source of ground_state.gd / movement_sim.gd (never the files)
## with the proposed slope-slide rule, then reloads them. Knobs are Engine metas read at run time:
##   s7_h        1 = slide velocity stays horizontal on slopes (moved like walking: projected motion, vy = 0)
##   s7_a        downhill horizontal accel as a multiple of g*tan(theta) (normal slide kinds)
##   s7_a_dash   same for dash slides (-1 = use s7_a)
##   s7_k        slide friction on a slide slope, normal kinds (-1 = flat value)
##   s7_k_dash   slide friction on a slide slope, dash kind (-1 = flat value)
##   s7_up_end   1 = a slide moving uphill on a slide slope ends (CROUCH, ground friction)
##   s7_hold     1 = onset timer does not advance while sliding downhill on a slide slope

const GS := "res://src/movement/core/states/ground_state.gd"
const MS := "res://src/movement/core/movement_sim.gd"


static func _rep(src: String, a: String, b: String, tag: String) -> String:
	if src.find(a) < 0:
		push_error("s7_patch: anchor not found: " + tag)
		return src
	return src.replace(a, b)


static func apply(opts: Dictionary) -> void:
	for k in opts:
		Engine.set_meta(k, opts[k])
	var gs: GDScript = load(GS)
	var src := gs.source_code
	src = _rep(src, """	if n.y < 0.99999:
		var gv := Vector3(0.0, -sim.cp.gravity(s), 0.0)
		v += (gv - n * gv.dot(n)) * dt
	v -= n * v.dot(n)
	var onset := sim.cp.slide_onset_ticks(s.slide_kind, sim.cp.slide_bonus(s))
	var f := p.slide_friction_dash if s.slide_kind == MoveState.SlideKind.DASH else p.slide_friction
""", """	var s7_slope := s.grounded and n.y < 0.99999
	if Engine.get_meta("s7_h", 0.0) > 0.5:
		v.y = 0.0
		if s7_slope:
			var dh := Vector3(n.x, 0.0, n.z)
			var am: float = Engine.get_meta("s7_a", 1.0)
			if s.slide_kind == MoveState.SlideKind.DASH and Engine.get_meta("s7_a_dash", -1.0) >= 0.0:
				am = Engine.get_meta("s7_a_dash", -1.0)
			v += dh.normalized() * am * sim.cp.gravity(s) * dh.length() / n.y * dt
	else:
		if n.y < 0.99999:
			var gv := Vector3(0.0, -sim.cp.gravity(s), 0.0)
			v += (gv - n * gv.dot(n)) * dt
		v -= n * v.dot(n)
	var onset := sim.cp.slide_onset_ticks(s.slide_kind, sim.cp.slide_bonus(s))
	var f := p.slide_friction_dash if s.slide_kind == MoveState.SlideKind.DASH else p.slide_friction
	if sim.on_slide_slope(s):
		var ks: float = Engine.get_meta("s7_k_dash", -1.0) if s.slide_kind == MoveState.SlideKind.DASH else Engine.get_meta("s7_k", -1.0)
		if ks >= 0.0:
			f = ks
		if Engine.get_meta("s7_hold", 0.0) > 0.5 and Vector2(v.x, v.z).dot(Vector2(n.x, n.z)) > 0.0 and s.slide_ticks < onset:
			s.slide_ticks -= 1
""", "slide_physics")
	src = _rep(src, """		elif s.horizontal_speed() < sim.cp.effective_crouch_speed(s) and not sim.on_slide_slope(s):
""", """		elif Engine.get_meta("s7_up_end", 0.0) > 0.5 and sim.on_slide_slope(s) and Vector2(s.velocity.x, s.velocity.z).dot(Vector2(s.ground_normal.x, s.ground_normal.z)) < 0.0:
			sim.emit(s, MoveEvents.SLIDE_END)
			s.loco = L.CROUCH
			s.velocity.y = 0.0
		elif s.horizontal_speed() < sim.cp.effective_crouch_speed(s) and not sim.on_slide_slope(s):
""", "transitions")
	src = _rep(src, """	var slide_ok := s.horizontal_speed() > p.slide_entry_speed and not s.slide_block_until_crouch_release
""", """	var slide_ok := s.horizontal_speed() > p.slide_entry_speed and not s.slide_block_until_crouch_release
	if Engine.get_meta("s7_up_end", 0.0) > 0.5 and sim.on_slide_slope(s) and Vector2(s.velocity.x, s.velocity.z).dot(Vector2(s.ground_normal.x, s.ground_normal.z)) < 0.0:
		slide_ok = false
""", "slide_ok uphill")
	gs.source_code = src
	var e := gs.reload(true)
	if e != OK:
		push_error("s7_patch: ground_state reload failed %d" % e)
	if Engine.get_meta("s7_h", 0.0) > 0.5:
		var ms: GDScript = load(MS)
		var m := ms.source_code
		m = _rep(m, "s.ground_normal) if s.loco != L.SLIDE else motion", "s.ground_normal)", "_move project")
		m = _rep(m, "	if s.grounded and is_ground_loco(s.loco) and s.loco != L.SLIDE:\n		v.y = 0.0", "	if s.grounded and is_ground_loco(s.loco):\n		v.y = 0.0", "_move vy")
		m = _rep(m, "(s.velocity.dot(s.ground_normal) > LEAVE_GROUND_SPEED) if s.loco == L.SLIDE else (s.velocity.y > LEAVE_GROUND_SPEED)", "(s.velocity.y > LEAVE_GROUND_SPEED)", "categorize")
		m = _rep(m, "					if s.loco != L.SLIDE:\n						s.velocity.y = 0.0", "					s.velocity.y = 0.0", "categorize vy")
		ms.source_code = m
		e = ms.reload(true)
		if e != OK:
			push_error("s7_patch: movement_sim reload failed %d" % e)
