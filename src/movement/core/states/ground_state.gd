extends RefCounted
## GROUND / CROUCH / SLIDE transitions and physics (design §7.10).

const Ctx = preload("res://src/movement/core/states/sim_context.gd")
const MantleState = preload("res://src/movement/core/states/mantle_state.gd")
const DashState = preload("res://src/movement/core/states/dash_state.gd")
const L := MoveState.Loco


static func transitions(sim: MovementSim, s: MoveState, ctx: Ctx) -> void:
	var p := sim.cp.params
	# spec: movement.md §15 mantle from the ground (jump + forward toward a ledge)
	if MantleState.try_start(sim, s, ctx, false):
		return
	# spec: movement.md §8 ground dash
	var dash_req := ctx.is_pressed(InputCmd.BTN_DASH) or (s.action_buffer_ticks > 0 and (s.action_buffer_button & InputCmd.BTN_DASH) != 0)
	if dash_req and (ctx.mask & ControlLocks.DASH) == 0:
		if DashState.try_ground_dash(sim, s, ctx):
			return
	# spec: movement.md §10 ground jump, §13 slide jump (free)
	var jump_req := ctx.is_pressed(InputCmd.BTN_JUMP) or (s.action_buffer_ticks > 0 and (s.action_buffer_button & InputCmd.BTN_JUMP) != 0) or s.jump_buffer_ticks > 0
	if jump_req and (ctx.mask & ControlLocks.JUMP) == 0:
		sim.do_ground_jump(s, ctx, &"slide" if s.loco == L.SLIDE else &"ground")
		return
	var crouch := ctx.is_held(InputCmd.BTN_CROUCH)
	# spec: movement.md §6 crouch storage blocks slides until crouch is released
	if not crouch:
		s.slide_block_until_crouch_release = false
	var slide_ok := (s.horizontal_speed() > p.slide_entry_speed or sim.on_slide_slope(s)) and not s.slide_block_until_crouch_release
	if s.loco == L.GROUND and s.crouched and not crouch:
		# safety net: never stay on the crouch capsule in GROUND (e.g. after a crouched mantle)
		if sim.mover.can_stand(s.position):
			s.crouched = false
		else:
			s.loco = L.CROUCH
	if s.loco == L.GROUND:
		# spec: movement.md §6 crouch, §13 slide entry
		if crouch:
			if slide_ok:
				enter_slide(sim, s, MoveState.SlideKind.NORMAL, -1.0)
			else:
				enter_crouch(sim, s)
	elif s.loco == L.CROUCH:
		if not crouch:
			if sim.mover.can_stand(s.position):
				s.crouched = false
				s.loco = L.GROUND
		elif slide_ok:
			enter_slide(sim, s, MoveState.SlideKind.NORMAL, -1.0)
	elif s.loco == L.SLIDE:
		# spec: movement.md §13 exits: crouch release, low speed (jump handled above)
		if not crouch:
			sim.emit(s, MoveEvents.SLIDE_END)
			if sim.mover.can_stand(s.position):
				s.crouched = false
				s.loco = L.GROUND
			else:
				s.loco = L.CROUCH
		elif s.horizontal_speed() < sim.cp.effective_crouch_speed(s) and not sim.on_slide_slope(s):
			sim.emit(s, MoveEvents.SLIDE_END)
			s.loco = L.CROUCH
			s.velocity.y = 0.0


static func enter_crouch(sim: MovementSim, s: MoveState) -> void:
	s.loco = L.CROUCH
	s.crouched = true


## spec: movement.md §13 slide entry. speed >= 0 overrides horizontal speed along `dir` (mantle glide).
static func enter_slide(sim: MovementSim, s: MoveState, kind: int, speed: float, dir: Vector3 = Vector3.ZERO) -> void:
	s.loco = L.SLIDE
	s.crouched = true
	s.slide_ticks = 0
	s.slide_kind = kind
	s.mantle_glide = false   # G09: only the mantle glide slide (flag set by the caller after this) is a superglide
	if speed >= 0.0:
		var d := Vector3(dir.x, 0.0, dir.z)
		if d.length_squared() < 1e-9:
			d = Vector3(s.velocity.x, 0.0, s.velocity.z)
		if d.length_squared() < 1e-9:
			d = sim.facing(s)
		d = d.normalized()
		s.velocity = Vector3(d.x * speed, 0.0, d.z * speed)
	sim.emit(s, MoveEvents.SLIDE_START, {"kind": kind})


## spec: movement.md §2 Source-style friction then accelerate (horizontal velocity).
static func walk_physics(sim: MovementSim, s: MoveState, ctx: Ctx, wishspeed: float) -> void:
	var p := sim.cp.params
	var dt := MoveUnits.DT
	var v := Vector3(s.velocity.x, 0.0, s.velocity.z)
	var speed := v.length()
	if speed > 0.0:
		var drop := maxf(speed, p.stop_speed) * p.ground_friction * dt
		var ns := maxf(0.0, speed - drop)
		v *= ns / speed
	if ctx.has_move and wishspeed > 0.0:
		# spec: movement.md §2 backpedal/strafe multipliers (1.0 until measured)
		if ctx.move_y < 0:
			wishspeed *= p.backpedal_mult
		elif ctx.move_y == 0 and ctx.move_x != 0:
			wishspeed *= p.strafe_mult
		var cur := v.dot(ctx.wish)
		var add := wishspeed - cur
		if add > 0.0:
			v += ctx.wish * minf(add, p.ground_accel * wishspeed * dt)
	s.velocity = Vector3(v.x, 0.0, v.z)


## spec: movement.md §13 slide friction (base, then late-slide penalty) plus downhill gravity.
static func slide_physics(sim: MovementSim, s: MoveState, ctx: Ctx) -> void:
	var p := sim.cp.params
	var dt := MoveUnits.DT
	var n := s.ground_normal if s.grounded else Vector3.UP
	var v := s.velocity
	if n.y < 0.99999:
		var gv := Vector3(0.0, -sim.cp.gravity(s), 0.0)
		v += (gv - n * gv.dot(n)) * dt
	v -= n * v.dot(n)
	var onset := sim.cp.slide_onset_ticks(s.slide_kind, sim.cp.slide_bonus(s))
	var f := p.slide_friction
	if s.slide_ticks >= onset:
		f = p.slide_penalty_friction_dash_jump if s.slide_kind == MoveState.SlideKind.DASH_JUMP else p.slide_penalty_friction
		if s.slide_ticks == onset:
			sim.emit(s, MoveEvents.SLIDE_PENALTY)
	v *= maxf(0.0, 1.0 - f * dt)
	s.velocity = v
	s.slide_ticks += 1
