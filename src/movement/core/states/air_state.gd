extends RefCounted
## AIR / DOWN_DASH transitions and physics, wall jump (design §7.10).

const Ctx = preload("res://src/movement/core/states/sim_context.gd")
const MantleState = preload("res://src/movement/core/states/mantle_state.gd")
const DashState = preload("res://src/movement/core/states/dash_state.gd")
const L := MoveState.Loco


static func transitions(sim: MovementSim, s: MoveState, ctx: Ctx) -> void:
	var p := sim.cp.params
	# spec: movement.md §15 mantle (jump pressed or held + forward)
	if MantleState.try_start(sim, s, ctx, false):
		return
	# spec: movement.md §11 air dash
	if ctx.is_pressed(InputCmd.BTN_DASH) and (ctx.mask & ControlLocks.DASH) == 0:
		if DashState.try_air_dash(sim, s, ctx):
			return
	# spec: movement.md §11 down dash: double-tap crouch within 28 ticks
	if ctx.is_pressed(InputCmd.BTN_CROUCH):
		var last := s.last_air_crouch_press_tick
		var down_max := p.down_dashes_per_airtime + (sim.cp.air_dashes_max(s) - p.air_dashes_per_airtime)
		if s.loco == L.AIR and last >= 0 and ctx.tick_no - last <= sim.cp.down_dash_window_ticks and s.down_dashes_used < down_max and sim.spend(s, p.cost_down_dash):
			s.loco = L.DOWN_DASH
			s.velocity.y = -p.down_dash_speed
			s.down_dashes_used += 1
			s.last_air_crouch_press_tick = -1
			sim.emit(s, MoveEvents.DASHED, {"kind": &"down", "bucket": sim.cp.hero.dash_bucket})
			return
		s.last_air_crouch_press_tick = ctx.tick_no
	# spec: movement.md §10, §14 jump in the air: wall jump, coyote jump, air jump
	if ctx.is_pressed(InputCmd.BTN_JUMP) and (ctx.mask & ControlLocks.JUMP) == 0:
		if try_wall_jump(sim, s, ctx):
			return
		if s.coyote_ticks > 0:
			sim.do_ground_jump(s, ctx, &"coyote")
			return
		# spec: movement.md §10 jump buffer (Open Q20, off by default): a press just before landing
		# is kept for the ground jump instead of burning the air jump.
		if sim.cp.jump_buffer_ticks > 0 and s.velocity.y <= 0.0 and _ground_within_buffer(sim, s):
			s.jump_buffer_ticks = sim.cp.jump_buffer_ticks + 1
			return
		if s.air_jumps_used < sim.cp.air_jumps_max(s) and sim.spend(s, p.cost_air_jump):
			var vy := p.air_jump_speed * sqrt(maxf(0.0, sim.cp.air_action_scale(s)))
			if p.air_jump_sets_vertical:
				s.velocity.y = vy
			else:
				s.velocity.y += vy
			# measured session 5 (DB*/DG* refit with drag): along the previous tick's wish (a key change on the jump
			# tick is ignored), top v.dir up toward run speed by at most air_jump_wish_add_max; no cap on |h|.
			# measured session 6 (s6_diag, s6_diagverify): the add uses the UNNORMALIZED key vector with each world
			# horizontal axis clamped to [-1, 1]; dir = c/|c| and the cap scales by |c|. Single keys are unaffected,
			# diagonals lean toward the nearest world 45-degree line (so the result depends on world yaw).
			var c := Vector3(clampf(s.prev_wish_raw.x, -1.0, 1.0), 0.0, clampf(s.prev_wish_raw.z, -1.0, 1.0))
			var clen := c.length()
			if clen > 1e-4:
				var dir := c / clen
				var along := s.velocity.dot(dir)
				var run := sim.cp.effective_move_speed(s, ctx.firing)
				if along < run:
					var add := minf(p.air_jump_wish_add_max * clen, run - along)
					s.velocity += dir * add
			s.air_jumps_used += 1
			s.loco = L.AIR
			sim.emit(s, MoveEvents.JUMPED, {"kind": &"air"})
		elif sim.cp.jump_buffer_ticks > 0:
			s.jump_buffer_ticks = sim.cp.jump_buffer_ticks + 1   # spec: movement.md §10 jump buffer


## True when the fall over the jump-buffer window reaches walkable ground (spec: movement.md §10).
static func _ground_within_buffer(sim: MovementSim, s: MoveState) -> bool:
	var t := float(sim.cp.jump_buffer_ticks) * MoveUnits.DT
	var reach := -s.velocity.y * t + 0.5 * sim.cp.gravity(s) * t * t + sim.cp.params.ground_probe_distance
	var pr := sim.mover.probe_ground_dist(s.position, s.crouched, reach)
	return bool(pr["hit"]) and bool(pr["walkable"])


## spec: movement.md §14 wall jump. Returns true when performed.
static func try_wall_jump(sim: MovementSim, s: MoveState, ctx: Ctx) -> bool:
	var p := sim.cp.params
	var walls := sim.mover.find_walls(s.position, s.crouched, p.wall_detect_distance)
	if walls.is_empty():
		return false
	# G13: push along the single closest contact's normal (walls_and_ledges.md rule 3), not the
	# average of all sweep normals. Corner and edge boosts are game bugs: not modeled, expected to emerge.
	var best: Dictionary = walls[0]
	for w in walls:
		if float(w["distance"]) < float(best["distance"]):
			best = w
	var n := best["normal"] as Vector3
	n.y = 0.0
	# guard: a contact normal with no horizontal part gives no push direction
	if n.length_squared() < 1e-6:
		return false
	n = n.normalized()
	# G33: a wall jump too soon after the previous one gives no height and no distance (video_guides V7 14:14);
	# the extra press next to the wall is eaten, not spent as an air jump (V18 Stairs 1:21).
	# PROVISIONAL (G33): interval length pending clip W5.
	if s.last_wall_jump_tick >= 0 and ctx.tick_no - s.last_wall_jump_tick < sim.cp.wall_jump_min_interval_ticks:
		return true
	var cost := 0.0 if s.wall_jumps_done < p.wall_jump_free_count else p.cost_wall_jump_subsequent
	if not sim.spend(s, cost):
		return false
	# measured session 3: the launch depends on the vertical speed just before the press (steeper while falling)
	# measured session 4 (wallfat): fatigue scales only the base up speed, not the vz term and not the kick
	var vz0 := s.velocity.y
	var base := p.wall_jump_up_speed * maxf(p.wall_jump_fatigue_min_mult, 1.0 - s.wall_fatigue)
	var vy := maxf(0.0, base + vz0 * (p.wall_jump_up_vz_gain_fall if vz0 < 0.0 else p.wall_jump_up_vz_gain_rise))
	sim.add_wall_fatigue(s, p.wall_jump_fatigue_per_jump)
	# measured session 3: the kick off the wall is linear in d = wish.normal (W in = toward, S out = away)
	var d := ctx.wish.dot(n) if ctx.has_move else 0.0
	var kick := p.wall_jump_kick_neutral + d * ((p.wall_jump_kick_away - p.wall_jump_kick_neutral) if d > 0.0 else (p.wall_jump_kick_neutral - p.wall_jump_kick_toward))
	# measured session 3/7: a held key's component along the wall adds its own tangential kick, on top of the kept
	# incoming tangent (session 7: the air strafe before the press is part of the launch)
	var tan_kick := (ctx.wish - n * d) * p.wall_jump_kick_tangent if ctx.has_move else Vector3.ZERO
	tan_kick.y = 0.0
	# G03: split the incoming horizontal velocity into normal and tangential parts; the tangential
	# part is kept (x wall_jump_tangent_keep), the normal axis is set to (or gets) the kick and the
	# vertical axis is set.
	var vh := Vector3(s.velocity.x, 0.0, s.velocity.z)
	var vn := vh.dot(n)
	var t := vh - n * vn
	var normal_speed := kick if p.wall_jump_normal_mode == 0 else vn + kick
	var h := t * p.wall_jump_tangent_keep + n * normal_speed + tan_kick
	s.velocity = Vector3(h.x, vy, h.z)
	s.last_wall_jump_tick = ctx.tick_no
	s.wall_jumps_done += 1
	s.loco = L.AIR
	# spec: movement.md §7, §14 wall jump while in combat (recent damage or hero/neutral
	# interaction, window = in_combat_time) slows stamina regen by 25% for 5 s
	if s.ticks_since_combat < sim.cp.in_combat_ticks:
		s.combat_regen_penalty_ticks = sim.cp.combat_penalty_ticks
	sim.emit(s, MoveEvents.WALL_JUMP, {"count": s.wall_jumps_done, "fatigue": s.wall_fatigue})
	sim.emit(s, MoveEvents.JUMPED, {"kind": &"wall"})
	return true


## spec: movement.md §12 Source-style air accelerate with a wishspeed cap, then linear drag.
static func air_physics(sim: MovementSim, s: MoveState, ctx: Ctx, allow_input: bool) -> void:
	var p := sim.cp.params
	var dt := MoveUnits.DT
	var v := Vector3(s.velocity.x, 0.0, s.velocity.z)
	if allow_input and ctx.has_move:
		var full := sim.cp.effective_move_speed(s, ctx.firing)
		# G26: wishspeed cap 80 u/s, 50 u/s above 700 u/s (V8). PROVISIONAL (G26): pending A5.
		var cap := p.air_wishspeed_cap if v.length() <= p.air_fast_threshold else p.air_wishspeed_cap_fast
		var ws := minf(full, cap)
		var add := ws - v.dot(ctx.wish)
		if add > 0.0:
			# PROVISIONAL (G26): accel rate pending A5. The 450 u/s split is sourced (air_movement.md rule 27,
			# wiki E8) but no source gives a factor, so air_accel_high_speed_mult defaults to 1.0 (K26).
			var accel := p.air_accel * full * dt
			if v.length() > p.air_strafe_threshold:
				accel *= p.air_accel_high_speed_mult
			if s.dash_jump_bonus_ticks > 0:
				accel *= 1.0 + p.dash_jump_air_control_bonus   # spec: movement.md §9
			v += ctx.wish * minf(add, accel)
	# spec: movement.md §12 drag (raised by slows); suspended after a zipline exit (§16).
	# G46: after the zero-drag window a zip exit uses zip_exit_drag until landing.
	# PROVISIONAL (G46): persistence until landing and no slow scaling are assumptions (research Q3).
	if s.zip_exit_momentum_ticks <= 0:
		var drag := sim.cp.params.zip_exit_drag if s.zip_exit_drag_active else sim.cp.effective_air_drag(s)
		v *= maxf(0.0, 1.0 - drag * dt)
		# G09 slide drag after an early chained slide jump (blocked by the zip window above).
		# measured session 9 (s9_open SHL, s7_open SHH): pulls h toward slide_hop_penalty_target, not a drag box.
		if s.slide_hop_penalty_active:
			var sp := v.length()
			var excess := sp - p.slide_hop_penalty_target
			if excess > 0.0 and sp > 1e-6:
				v *= (sp - minf(excess, excess * p.slide_hop_penalty_drag * dt)) / sp
	# air dash end drag mode 4 (measured): step the horizontal speed down toward the floor
	if s.air_dash_end_drag_ticks_left > 0:
		s.air_dash_end_drag_ticks_left -= 1
		var sp := v.length()
		var nsp := maxf(p.air_dash_end_drag_floor, sp - s.air_dash_end_drag_step)
		if sp > 1e-9 and nsp < sp:
			v *= nsp / sp
	s.velocity.x = v.x
	s.velocity.z = v.z
