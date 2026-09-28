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
	# measured session 7 (s7_ramp RS0/RSW): a crouch press on a ~20-26 degree ramp at rest or at crouch-walk speed
	# does not slide (HUD stays 0 / 187 all the way down), so a slope is no exception to slide_entry_speed here.
	# measured session 8 (s7_ramp RRUN/RJ re-read): running down a 26.5 deg ramp the HUD reads the along-surface speed
	# (347.5 horizontal -> ~390), and a crouch there slides, so the entry test uses the along-surface speed.
	var slide_ok := surface_speed(s) > p.slide_entry_speed and not s.slide_block_until_crouch_release
	# measured session 7 (s7_ramp RUP): a crouch pressed while moving uphill on a slide slope gets crouch friction,
	# not a slide. A slide carried onto an upslope ends (session 8 w2, SLIDE branch below).
	if moving_uphill_on_slide_slope(sim, s):
		slide_ok = false
	if s.loco == L.GROUND and s.crouched and not crouch:
		# safety net: never stay on the crouch capsule in GROUND (e.g. after a crouched mantle)
		if sim.mover.can_stand(s.position):
			s.crouched = false
		else:
			s.loco = L.CROUCH
	if s.loco == L.GROUND:
		# spec: movement.md §6 crouch, §13 slide entry ("above 350 u/s or when on a ramp")
		# measured session 8 (sliding_3 x1): a crouch pressed while walking downhill on a ~20-26 deg stair ramp at
		# ~70-100 u/s slides (HUD then climbs ~460 u/s^2 to the bottom); at rest (s7 RS0) or with crouch already held
		# before moving onto or down the ramp (s7 RSW, CROUCH branch below) it stays a crouch. No speed floor.
		if crouch:
			if slide_ok or (moving_downhill_on_slide_slope(sim, s) and not s.slide_block_until_crouch_release):
				enter_slide(sim, s, MoveState.SlideKind.NORMAL, -1.0)
				s.slide_from_ground = true
			else:
				enter_crouch(sim, s)
	elif s.loco == L.CROUCH:
		if not crouch:
			if sim.mover.can_stand(s.position):
				s.crouched = false
				s.loco = L.GROUND
		elif slide_ok:
			enter_slide(sim, s, MoveState.SlideKind.NORMAL, -1.0)
			s.slide_from_ground = true
	elif s.loco == L.SLIDE:
		# spec: movement.md §13 exits: crouch release, low speed (jump handled above)
		if not crouch:
			sim.emit(s, MoveEvents.SLIDE_END)
			if sim.mover.can_stand(s.position):
				s.crouched = false
				s.loco = L.GROUND
			else:
				s.loco = L.CROUCH
		# measured session 8 (sliding_2 w2): a mantle-glide slide at ~490 u/s carried from the flat onto ~28 deg stairs
		# going up ends at once: ~5.5/s crouch-like decay to crouch-walk 187 within ~0.2 s, no slide up the slope.
		elif moving_uphill_on_slide_slope(sim, s):
			sim.emit(s, MoveEvents.SLIDE_END)
			s.loco = L.CROUCH
			s.velocity.y = 0.0
		elif s.horizontal_speed() < sim.cp.effective_crouch_speed(s) and not sim.on_slide_slope(s):
			sim.emit(s, MoveEvents.SLIDE_END)
			s.loco = L.CROUCH
			s.velocity.y = 0.0


## Speed along the ground plane for the horizontal velocity (the vertical part follows the surface).
static func surface_speed(s: MoveState) -> float:
	var n := s.ground_normal
	if not s.grounded or n.y < 1e-3 or n.y > 0.99999:
		return s.horizontal_speed()
	var vy := -(n.x * s.velocity.x + n.z * s.velocity.z) / n.y
	return Vector3(s.velocity.x, vy, s.velocity.z).length()


## measured session 7 (s7_ramp RUP): no slide (normal or dash) starts while moving uphill on a slide slope.
static func moving_uphill_on_slide_slope(sim: MovementSim, s: MoveState) -> bool:
	return sim.on_slide_slope(s) and Vector2(s.velocity.x, s.velocity.z).dot(Vector2(s.ground_normal.x, s.ground_normal.z)) < 0.0


static func moving_downhill_on_slide_slope(sim: MovementSim, s: MoveState) -> bool:
	return sim.on_slide_slope(s) and Vector2(s.velocity.x, s.velocity.z).dot(Vector2(s.ground_normal.x, s.ground_normal.z)) > 0.0


static func enter_crouch(sim: MovementSim, s: MoveState) -> void:
	s.loco = L.CROUCH
	s.crouched = true


## spec: movement.md §13 slide entry. speed >= 0 overrides horizontal speed along `dir` (mantle glide).
static func enter_slide(sim: MovementSim, s: MoveState, kind: int, speed: float, dir: Vector3 = Vector3.ZERO) -> void:
	s.loco = L.SLIDE
	s.crouched = true
	s.slide_ticks = 0
	s.slide_penalty_ticks = 0
	s.slide_kind = kind
	s.slide_from_ground = false   # set by the GROUND/CROUCH crouch-press callers
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
		# measured session 5: the accel step is the same ~1600 u/s^2 for every hero (Haze, Infernus, Abrams), not
		# ground_accel * wishspeed
		if add > 0.0:
			v += ctx.wish * minf(add, p.ground_accel * p.ground_accel_ref_speed * dt)
	s.velocity = Vector3(v.x, 0.0, v.z)


## spec: movement.md §13 slide friction (base, then late-slide penalty) plus downhill gravity.
static func slide_physics(sim: MovementSim, s: MoveState, ctx: Ctx) -> void:
	var p := sim.cp.params
	var dt := MoveUnits.DT
	var n := s.ground_normal if s.grounded else Vector3.UP
	# measured session 7 (s7_ramp): slide velocity stays horizontal on a slope (the HUD reads horizontal speed there,
	# with no speed change at the top or bottom); a slope adds a horizontal downhill accel of g*tan(theta).
	var v := Vector3(s.velocity.x, 0.0, s.velocity.z)
	var dh := Vector3(n.x, 0.0, n.z)
	if n.y < 0.99999 and n.y > 1e-3:
		v += dh.normalized() * sim.cp.gravity(s) * dh.length() / n.y * dt
	var onset := sim.cp.slide_onset_ticks(s.slide_kind, sim.cp.slide_bonus(s), s.slide_from_ground)
	var f := p.slide_friction_dash if s.slide_kind == MoveState.SlideKind.DASH else p.slide_friction
	# measured session 7 (s7_ramp RRUN/RBOT/RDASH, one 26.5 deg ramp): before the penalty, the net downhill accel is
	# g*tan(theta) for a normal slide (no friction) and ~0.24/s friction for a dash slide.
	# PROVISIONAL (S7-SL): single-angle fit; a second ramp angle would separate accel scale from friction.
	if sim.on_slide_slope(s):
		f = p.slide_slope_friction_dash if s.slide_kind == MoveState.SlideKind.DASH else p.slide_slope_friction
		# measured session 8 (s8_city_slide v1-v4, 19-30 deg city ramps): no penalty while sliding downhill; the sharp
		# slowdown starts 0.57-0.60 s after reaching the flat whatever the time spent on the ramp, so the timer restarts.
		# PROVISIONAL (S8-SL): restart vs hold is not separated (every clip crouched at the top edge).
		if not moving_uphill_on_slide_slope(sim, s):
			s.slide_penalty_ticks = 0
	if s.slide_penalty_ticks >= onset:
		f = p.slide_penalty_friction_dash_jump if s.slide_kind == MoveState.SlideKind.DASH_JUMP else p.slide_penalty_friction
		if s.slide_penalty_ticks == onset:
			sim.emit(s, MoveEvents.SLIDE_PENALTY)
	v *= maxf(0.0, 1.0 - f * dt)
	# measured session 3: a held move key turns the horizontal velocity toward the wish direction at a capped
	# rate without changing speed; with no key held the mouse does not steer.
	if ctx.has_move and p.slide_turn_rate_deg > 0.0:
		var h := Vector2(v.x, v.z)
		var w := Vector2(ctx.wish.x, ctx.wish.z)
		if h.length_squared() > 1e-8 and w.length_squared() > 1e-8:
			var ang := h.angle_to(w)
			# measured session 4 (sback): a wish straight behind the slide (plain S) turns it to the camera's right,
			# at the same rate and speed as any other steer
			if absf(ang) > PI - 1e-3:
				var r := Basis(Vector3.UP, s.yaw) * Vector3.RIGHT
				ang = signf(h.angle_to(Vector2(r.x, r.z))) * PI
			var step := deg_to_rad(p.slide_turn_rate_deg) * dt
			h = h.rotated(clampf(ang, -step, step))
			v = Vector3(h.x, v.y, h.y)
	s.velocity = v
	s.slide_ticks += 1
	s.slide_penalty_ticks += 1
