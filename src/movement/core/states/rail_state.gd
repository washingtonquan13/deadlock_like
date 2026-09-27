extends RefCounted
## ZIPLINE and ROPE (design §7.10, spec: movement.md §16, §17).

const Ctx = preload("res://src/movement/core/states/sim_context.gd")
const L := MoveState.Loco


static func _center(sim: MovementSim, s: MoveState) -> Vector3:
	var p := sim.cp.params
	var h := p.capsule_height_crouch if s.crouched else p.capsule_height_stand
	return s.position + Vector3.UP * (h * 0.5)


## Attach on jump press. Returns true when attached.
static func try_attach(sim: MovementSim, s: MoveState, ctx: Ctx) -> bool:
	if not ctx.is_pressed(InputCmd.BTN_JUMP):
		return false
	if s.loco == L.MANTLE or s.loco == L.FORCED or s.loco == L.HEAVY_LUNGE:
		return false
	var p := sim.cp.params
	var c := _center(sim, s)
	# spec: movement.md §16 zipline attach (radius Open Q14), lockout after hero damage
	if (ctx.mask & ControlLocks.ZIPLINE) == 0 and s.zip_attach_lockout_ticks <= 0:
		var best: ZiplineRail = null
		var best_d := INF
		var best_s := 0.0
		for z in sim.ziplines:
			var r := z.closest(c)
			var d: float = r["distance"]
			if d <= p.zip_attach_radius and d < best_d:
				best = z
				best_d = d
				best_s = r["s"]
		if best != null:
			_attach_zipline(sim, s, ctx, best, best_s)
			return true
	# spec: movement.md §17 rope attach
	var best_r: RopeRail = null
	var best_rd := INF
	var best_rs := 0.0
	for rp in sim.ropes:
		var rr := rp.closest(c)
		var rd: float = rr["distance"]
		if rd <= p.rope_attach_radius and rd < best_rd:
			best_r = rp
			best_rd = rd
			best_rs = rr["s"]
	if best_r != null:
		_leave_current(sim, s)
		s.loco = L.ROPE
		s.rope_id = best_r.id
		s.rope_s = best_rs
		s.velocity = Vector3.ZERO
		s.grounded = false
		s.crouched = false
		sim.refresh_air(s)
		return true
	return false


static func _leave_current(sim: MovementSim, s: MoveState) -> void:
	if s.loco == L.SLIDE:
		sim.emit(s, MoveEvents.SLIDE_END)
	if s.loco == L.GROUND_DASH and s.dash_jump_window_open:
		s.dash_jump_window_open = false
		sim.emit(s, MoveEvents.DASH_JUMP_WINDOW, {"open": false})


static func _attach_zipline(sim: MovementSim, s: MoveState, ctx: Ctx, rail: ZiplineRail, at_s: float) -> void:
	_leave_current(sim, s)
	var t := rail.tangent(at_s)
	var look := ctx.wish if ctx.has_move else sim.facing(s)
	# spec: movement.md §16 movement input can choose the travel direction
	s.zip_dir = 1 if t.dot(look) >= 0.0 else -1
	s.loco = L.ZIPLINE
	s.zip_rail_id = rail.id
	s.zip_s = at_s
	s.zip_ride_ticks = 0
	s.zip_exit_momentum_ticks = 0
	s.zip_exit_drag_active = false   # G46
	s.grounded = false
	s.crouched = false
	s.velocity = Vector3.ZERO
	# spec: movement.md §16 attach resets sprint and refreshes air actions
	sim.reset_sprint(s, ctx, &"zipline")
	sim.refresh_air(s)
	sim.emit(s, MoveEvents.ZIP_ATTACH, {"rail_id": rail.id})


static func transitions(sim: MovementSim, s: MoveState, ctx: Ctx) -> void:
	var p := sim.cp.params
	if s.loco == L.ZIPLINE:
		var rail := sim.get_zipline(s.zip_rail_id)
		if rail == null:
			detach_zipline(sim, s, &"missing")
			return
		if ctx.is_pressed(InputCmd.BTN_CROUCH):
			detach_zipline(sim, s, &"crouch")
		elif ctx.is_pressed(InputCmd.BTN_JUMP):
			detach_zipline(sim, s, &"jump")
			s.velocity.y += p.jump_speed
			sim.emit(s, MoveEvents.JUMPED, {"kind": &"zipline"})
		elif (s.zip_dir > 0 and s.zip_s >= rail.length() - 1e-4) or (s.zip_dir < 0 and s.zip_s <= 1e-4):
			detach_zipline(sim, s, &"end")
		return
	# ROPE
	var rope := sim.get_rope(s.rope_id)
	if rope == null or ctx.is_pressed(InputCmd.BTN_CROUCH):
		s.loco = L.AIR
		s.rope_id = -1
		s.velocity = Vector3.ZERO
	elif ctx.is_pressed(InputCmd.BTN_JUMP) and ctx.has_move:
		var sp := sim.cp.effective_move_speed(s, ctx.firing)
		s.velocity = ctx.wish * sp + Vector3.UP * p.jump_speed
		s.loco = L.AIR
		s.rope_id = -1
		sim.emit(s, MoveEvents.JUMPED, {"kind": &"rope"})


## spec: movement.md §16 exit: momentum along the line kept for 2 s with drag suspended.
static func detach_zipline(sim: MovementSim, s: MoveState, reason: StringName) -> void:
	s.loco = L.AIR
	s.zip_rail_id = -1
	s.zip_exit_momentum_ticks = sim.cp.zip_exit_momentum_ticks
	# G46: after the zero-drag window, zip_exit_drag (0.25) applies until landing.
	# PROVISIONAL (G46): research names the crouch dismount; applied to every detach like the zero-drag window.
	s.zip_exit_drag_active = true
	sim.emit(s, MoveEvents.ZIP_DETACH, {"reason": reason})


## spec: movement.md §16 knock-off: fall straight down, stun on landing.
static func knockoff(sim: MovementSim, s: MoveState) -> void:
	s.loco = L.AIR
	s.zip_rail_id = -1
	s.zip_exit_momentum_ticks = 0
	s.zip_exit_drag_active = false   # G46
	s.velocity = Vector3(0.0, minf(s.velocity.y, 0.0), 0.0)
	s.zip_knockoff_pending = true
	sim.emit(s, MoveEvents.ZIP_DETACH, {"reason": &"knockoff"})


## Feet position hanging from `rail_point`. The hang offset (capsule height) is clamped by a
## downward sweep so a rail close to the ground never pushes the capsule into it.
static func _hang_position(sim: MovementSim, rail_point: Vector3) -> Vector3:
	var h := sim.cp.params.capsule_height_stand
	var start := rail_point - Vector3.UP * (h * 0.5)
	var r := sim.mover.test_motion(start, Vector3.DOWN * (h * 0.5), false)
	return r["position"] if r["collided"] else rail_point - Vector3.UP * h


## spec: movement.md §16 lane speed (inner/outer from MovementParams, CUSTOM from the rail),
## express lines x(1 + zip_express_mult).
static func rail_speed(sim: MovementSim, rail: ZiplineRail) -> float:
	var p := sim.cp.params
	var spd := rail.speed
	if rail.lane == 1:
		spd = p.zip_speed_inner
	elif rail.lane == 2:
		spd = p.zip_speed_outer
	if rail.express:
		spd *= 1.0 + p.zip_express_mult
	return spd


static func physics(sim: MovementSim, s: MoveState, ctx: Ctx) -> void:
	var p := sim.cp.params
	ctx.skip_move = true
	if s.loco == L.ZIPLINE:
		var rail := sim.get_zipline(s.zip_rail_id)
		if rail == null:
			return
		# spec: movement.md §16 Zipline Boost +80% for 32 s, 360 s cooldown, unlocked at 360 s
		# match time (the sim tick count is the match clock here)
		if ctx.is_pressed(InputCmd.BTN_ZIP_BOOST) and s.zip_boost_ticks <= 0:
			var no_cd := (s.cheat_flags & MoveState.CHEAT_NO_COOLDOWNS) != 0
			if no_cd or (s.zip_boost_cooldown_ticks <= 0 and s.tick >= sim.cp.zip_boost_unlock_ticks):
				s.zip_boost_ticks = sim.cp.zip_boost_ticks + 1
				s.zip_boost_cooldown_ticks = sim.cp.zip_boost_cooldown_ticks + 1
		var speed := rail_speed(sim, rail) * (1.0 + (p.zip_boost_mult if s.zip_boost_ticks > 0 else 0.0))
		var new_s := clampf(s.zip_s + float(s.zip_dir) * speed * MoveUnits.DT, 0.0, rail.length())
		var target := _hang_position(sim, rail.sample(new_s))
		# Sweep the hanging capsule along the rail; geometry blocking the path head-on detaches
		# instead of dragging the capsule through the world.
		if s.zip_ride_ticks > 0:
			var motion := target - s.position
			var hit := sim.mover.test_motion(s.position, motion, false)
			if hit["collided"] and (hit["normal"] as Vector3).dot(motion.normalized()) < -0.5:
				s.position = hit["position"]
				s.velocity = rail.tangent(s.zip_s) * float(s.zip_dir) * speed
				detach_zipline(sim, s, &"blocked")
				return
		s.zip_s = new_s
		s.position = target
		s.velocity = rail.tangent(s.zip_s) * float(s.zip_dir) * speed
		s.zip_ride_ticks += 1
		return
	# ROPE: spec: movement.md §17 climb while jump is held, 40% slower after damage
	var rope := sim.get_rope(s.rope_id)
	if rope == null:
		return
	var climb := 0.0
	if ctx.is_held(InputCmd.BTN_JUMP):
		var slow := clampf(ModifierStack.sum(s, ModifierDef.Stat.ROPE_SLOW), 0.0, 1.0)
		climb = p.rope_climb_speed * (1.0 - slow)
	var before := s.rope_s
	s.rope_s = clampf(s.rope_s - climb * MoveUnits.DT, 0.0, rope.length())
	var pt := rope.sample(s.rope_s)
	s.position = pt - Vector3.UP * (p.capsule_height_stand * 0.5)
	s.velocity = Vector3.UP * ((before - s.rope_s) / MoveUnits.DT)
