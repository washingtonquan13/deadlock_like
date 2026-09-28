extends RefCounted
## GROUND_DASH / AIR_DASH and dash-jump (design §7.10).

const Ctx = preload("res://src/movement/core/states/sim_context.gd")
const GroundState = preload("res://src/movement/core/states/ground_state.gd")
const L := MoveState.Loco


static func _dash_dir(sim: MovementSim, s: MoveState, ctx: Ctx) -> Vector3:
	# spec: movement.md §8 input direction, neutral = facing
	if ctx.has_move:
		return ctx.wish
	return sim.facing(s)


## Measured (session2_findings.md): with no move input, a ground or air dash does nothing.
## Checked before any stamina is spent; whether the game still spends stamina is not observable in cl_showpos.
static func _neutral_blocked(sim: MovementSim, ctx: Ctx) -> bool:
	return sim.cp.params.neutral_dash_does_nothing and not ctx.has_move


## whole: the dash lasts floor(t_exact) full ticks (measured, session2_findings.md) instead of
## ceil(t_exact) ticks with a fractional last tick (design §7.10).
static func _setup_ticks(s: MoveState, t_exact: float, whole: bool) -> void:
	s.dash_ticks = 0
	if whole:
		s.dash_total_ticks = maxi(1, floori(t_exact + 1e-6))
		s.dash_last_fraction = 1.0
		return
	var total := maxi(1, ceili(t_exact - 1e-6))
	s.dash_total_ticks = total
	s.dash_last_fraction = clampf(t_exact - float(total - 1), 0.0, 1.0)


## spec: movement.md §8 ground dash (sets velocity, costs 1).
static func try_ground_dash(sim: MovementSim, s: MoveState, ctx: Ctx) -> bool:
	var p := sim.cp.params
	if _neutral_blocked(sim, ctx):
		return false
	if not sim.spend(s, p.cost_ground_dash):
		return false
	if s.loco == L.SLIDE:
		sim.emit(s, MoveEvents.SLIDE_END)
	var dir := _dash_dir(sim, s, ctx)
	# spec: movement.md §6 crouch storage: crouch held when the dash starts
	s.dash_crouch_stored = ctx.is_held(InputCmd.BTN_CROUCH)
	if not s.dash_crouch_stored:
		sim.try_uncrouch(s)
	_setup_ticks(s, sim.cp.ground_dash_ticks_for(s), p.ground_dash_whole_ticks)
	s.dash_dir = dir
	s.dash_speed = sim.cp.ground_dash_speed_for(s)
	s.dash_jump_cancelled = false
	s.dash_jump_locked = false
	s.dash_jump_window_open = false
	s.action_buffer_ticks = 0
	s.action_buffer_button = 0
	s.loco = L.GROUND_DASH
	s.velocity = Vector3(dir.x * s.dash_speed, 0.0, dir.z * s.dash_speed)
	# G02: a new dash replaces a pending IAD end drag, by analogy with a chained air dash (V2 3:03). No clip
	# shows a ground dash out of an IAD. PROVISIONAL (G02).
	s.air_dash_drag_pending = false
	s.air_dash_drag_land_ticks = -1
	sim.emit(s, MoveEvents.DASHED, {"kind": &"ground", "bucket": sim.cp.hero.dash_bucket})
	return true


## spec: movement.md §11 air dash (impulse added to velocity, costs 1). Zeroing vy follows
## design §7.10 and is switchable via MovementParams.air_dash_zero_vertical (see deviations).
static func try_air_dash(sim: MovementSim, s: MoveState, ctx: Ctx) -> bool:
	var p := sim.cp.params
	if s.air_dashes_used >= sim.cp.air_dashes_max(s):
		return false
	if _neutral_blocked(sim, ctx):
		return false
	if not sim.spend(s, p.cost_air_dash):
		return false
	var dir := _dash_dir(sim, s, ctx)
	_setup_ticks(s, sim.cp.air_dash_ticks_for(s), p.air_dash_whole_ticks)
	s.dash_dir = dir
	s.dash_speed = sim.cp.air_dash_speed_for(s)
	s.air_dash_end_drag_ticks_left = 0
	if p.air_dash_cap_mode == 0:
		s.velocity += dir * s.dash_speed   # legacy uncapped add (K18, contradicted)
	elif p.air_dash_cap_mode == 3:
		_start_air_dash_ramp(sim, s, dir)
	else:
		_apply_air_dash_cap(sim, s, dir, p.air_dash_cap_mode)
	if p.air_dash_zero_vertical:
		s.velocity.y = 0.0
	# G02: this dash owes the end drag; starting it replaces (cancels) a pending one from a chained dash.
	# PROVISIONAL (G02): pending recording clip A2.
	s.air_dash_drag_pending = p.air_dash_end_drag_mode != 0
	s.air_dash_drag_land_ticks = -1
	s.air_dashes_used += 1
	s.air_dashed_this_airtime = true
	s.loco = L.AIR_DASH
	sim.emit(s, MoveEvents.DASHED, {"kind": &"air", "bucket": sim.cp.hero.dash_bucket})
	return true


## G01 directional cap (PROVISIONAL (G01), V8 2:16; pending recording clips A1, A2, A3).
## Horizontal velocity is split along the dash direction: v_perp is kept and
## mode 1 (Hypothesis A): v_par' = max(min(v_par + J, C), min(v_par, C)); mode 2: v_par' = C.
static func _apply_air_dash_cap(sim: MovementSim, s: MoveState, dir: Vector3, mode: int) -> void:
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length_squared() < 1e-9:
		return
	d = d.normalized()
	var j := s.dash_speed
	var c := sim.cp.air_dash_cap_for(s)
	var vh := Vector3(s.velocity.x, 0.0, s.velocity.z)
	var vpar := vh.dot(d)
	var vperp := vh - d * vpar
	var npar := c if mode == 2 else maxf(minf(vpar + j, c), minf(vpar, c))
	var nh := vperp + d * npar
	s.velocity.x = nh.x
	s.velocity.z = nh.z


## Cap mode 3 (measured, session2_findings.md "Session 2c"): no impulse at the start; the ramp in
## physics() pushes v_par toward target = frac[bucket] * dash speed + entry_frac * v_par at dash start.
static func _start_air_dash_ramp(sim: MovementSim, s: MoveState, dir: Vector3) -> void:
	var p := sim.cp.params
	var d := Vector3(dir.x, 0.0, dir.z)
	s.air_dash_ramp_done = false
	if d.length_squared() < 1e-9:
		s.air_dash_ramp_target = 0.0
		s.air_dash_ramp_done = true
		return
	d = d.normalized()
	s.dash_dir = d
	var vpar0 := Vector3(s.velocity.x, 0.0, s.velocity.z).dot(d)
	var b := clampi(sim.cp.hero.dash_bucket, 1, 3) - 1
	s.air_dash_ramp_v0 = vpar0
	# measured session 6 (s6_airdash): entries against the dash lower the peak more steeply (E386S, E700S)
	var k := p.air_dash_ramp_entry_frac if vpar0 >= 0.0 else p.air_dash_ramp_entry_frac_neg
	s.air_dash_ramp_target = p.air_dash_ramp_target_fracs[b] * s.dash_speed + k * vpar0


## One tick of the mode 3 ramp: v_par gains (rate - damping_c * (v_par - v_par0)) / duration * dt, stopping at the
## target; v_perp is kept. The dash's own drag (air_dash_drag) applies when air_dash_keeps_air_drag is set.
static func _air_dash_ramp_tick(sim: MovementSim, s: MoveState, ctx: Ctx) -> void:
	var p := sim.cp.params
	var dt := MoveUnits.DT * ctx.frac
	var d := Vector3(s.dash_dir.x, 0.0, s.dash_dir.z)
	var vh := Vector3(s.velocity.x, 0.0, s.velocity.z)
	if not s.air_dash_ramp_done and d.length_squared() > 1e-9:
		var vpar := vh.dot(d)
		var dur := maxf(sim.cp.air_dash_ticks_for(s) * MoveUnits.DT, 1e-6)
		var gain := maxf(0.0, (p.air_dash_ramp_rate - p.air_dash_ramp_damping_c * (vpar - s.air_dash_ramp_v0)) / dur * dt)
		if vpar + gain >= s.air_dash_ramp_target:
			# the ramp stops at the target (or at once when entering above it); the speed then decays
			gain = maxf(0.0, s.air_dash_ramp_target - vpar)
			s.air_dash_ramp_done = true
		vh += d * gain
	if p.air_dash_keeps_air_drag and s.zip_exit_momentum_ticks <= 0:
		vh *= maxf(0.0, 1.0 - p.air_dash_drag * (1.0 + p.slow_air_drag_factor * sim.cp.actual_slow(s)) * dt)
	s.velocity.x = vh.x
	s.velocity.z = vh.z


## G02 end drag on the horizontal speed (PROVISIONAL (G02), V8 2:38 / V9 1:09 / V2 3:03 / V10 3:18;
## pending recording clip A2). Skipped in the zip exit zero-drag window.
static func apply_air_dash_end_drag(sim: MovementSim, s: MoveState) -> void:
	var p := sim.cp.params
	var pending := s.air_dash_drag_pending
	s.air_dash_drag_pending = false
	s.air_dash_drag_land_ticks = -1
	if not pending or p.air_dash_end_drag_mode == 0 or s.zip_exit_momentum_ticks > 0:
		return
	var v := s.horizontal_speed()
	if v < 1e-9:
		return
	var nv := v
	if p.air_dash_end_drag_mode == 4:
		# measured (session2_findings.md "Session 2c"): the excess over the floor bleeds off over
		# air_dash_end_drag_ticks airborne ticks (AirState.air_physics); the grounded case is unmeasured.
		# measured session 6 (s6_airdash): it removes (1 - excess_keep) of the excess over the floor, but never more
		# than air_dash_end_drag_prop of the speed (E700W 670 -> 542, E700WD 762 -> 617, 565 -> 490).
		if s.grounded or v <= p.air_dash_end_drag_floor:
			return
		var fl := maxf(p.air_dash_end_drag_floor + p.air_dash_end_drag_excess_keep * (v - p.air_dash_end_drag_floor),
			v * (1.0 - p.air_dash_end_drag_prop))
		s.air_dash_end_drag_ticks_left = p.air_dash_end_drag_ticks
		s.air_dash_end_drag_step = (v - fl) / float(p.air_dash_end_drag_ticks)
		sim.emit(s, MoveEvents.AIR_DASH_END_DRAG, {"from": v, "to": fl})
		return
	match p.air_dash_end_drag_mode:
		1:
			nv = maxf(minf(v, p.air_dash_end_drag_floor), v - p.air_dash_end_drag_frac * (v - p.air_dash_end_drag_offset))
		2:
			nv = v - p.air_dash_end_drag_frac * maxf(0.0, v - p.air_dash_end_drag_floor)
		3:
			nv = v * (1.0 - p.air_dash_end_drag_frac)
	nv = clampf(nv, 0.0, v)
	s.velocity.x *= nv / v
	s.velocity.z *= nv / v
	sim.emit(s, MoveEvents.AIR_DASH_END_DRAG, {"from": v, "to": nv})


static func transitions(sim: MovementSim, s: MoveState, ctx: Ctx) -> void:
	if s.loco == L.AIR_DASH:
		# G02 chain exception: an air dash started before this one ends cancels its pending end drag
		# (V8; "IAD -> bhop -> IAD"). PROVISIONAL (G02): pending recording clip A2.
		if ctx.is_pressed(InputCmd.BTN_DASH) and (ctx.mask & ControlLocks.DASH) == 0 and s.dash_ticks > 0:
			if try_air_dash(sim, s, ctx):
				return
		# G50: a jump press during an air dash is dropped (no wall jump, mantle, air jump or buffer). No source
		# says whether the real game allows any of these mid-dash (V3 4:39 only says velocity is locked to the
		# dash direction). PROVISIONAL (G50): pending a recording (air dash into a wall, press jump mid-dash).
		if s.dash_ticks >= s.dash_total_ticks:
			# spec: movement.md §11 velocity is kept; gravity and drag resume. G02 end drag.
			if sim.cp.params.air_dash_exit_clamp:
				sim.clamp_horizontal(s, sim.cp.effective_move_speed(s, ctx.firing))
			apply_air_dash_end_drag(sim, s)
			s.loco = L.AIR
		return
	_ground_dash_transitions(sim, s, ctx)


static func _ground_dash_transitions(sim: MovementSim, s: MoveState, ctx: Ctx) -> void:
	var p := sim.cp.params
	var k := s.dash_ticks
	var in_window := k >= sim.cp.dash_jump_open_tick and k <= sim.cp.dash_jump_close_tick
	# spec: movement.md §9 dash-jump cancel: ability cast inside the window
	# PROVISIONAL (G06): window 0.30-0.55 s from the official 2026-06-30 notes; V17 reports 0.35-0.60 s.
	if in_window and ctx.is_pressed(InputCmd.BTN_ABILITY):
		s.dash_jump_cancelled = true
	# a one-tick hop over a bump still counts as grounded for the dash-jump (spec: movement.md §9).
	# G18: after dashing off a ledge the window stays open (ground_dash.md rule 15) and the dash-jump
	# uses no air jump. PROVISIONAL (G18): dash_jump_coyote_time < 0 = whole window; exact grace pending recording.
	var coyote := sim.cp.dash_jump_coyote_ticks
	var on_ground := s.grounded or s.airborne_ticks <= 1 or coyote < 0 or s.airborne_ticks <= coyote
	if ctx.is_pressed(InputCmd.BTN_JUMP) and (ctx.mask & ControlLocks.JUMP) == 0:
		# G07: a jump pressed before the window opens locks out the dash-jump for this dash
		# (ground_dash.md rule 12). Measured session 4: that press, and one after the window, does nothing
		# (no jump, not buffered).
		# PROVISIONAL (G06/G07): the open tick carries the G06 window conflict (0.30 vs 0.35 s).
		if k < sim.cp.dash_jump_open_tick:
			s.dash_jump_locked = true
		if in_window and not s.dash_jump_locked and not s.dash_jump_cancelled and on_ground and sim.can_spend(s, p.cost_dash_jump_extra):
			_dash_jump(sim, s, ctx)
			return
		if in_window and s.dash_jump_cancelled and on_ground:
			close_window(sim, s)
			# K12 removed: no walk-speed clamp on the ability-cancel jump; no source caps it and the dash
			# hop keeps the dash's momentum (video_guides V9 3:03, ground_dash.md rule 12b; gap G22).
			sim.do_ground_jump(s, ctx, &"dash_cancel")
			return
	# G20: a crouch press at any time during the dash starts the dash slide at the current speed
	# (ground_dash.md rules 7-8). Crouch already held at dash start is stored and gives no press (rule 9).
	if ctx.is_pressed(InputCmd.BTN_CROUCH) and s.grounded and (ctx.mask & ControlLocks.CROUCH) == 0:
		close_window(sim, s)
		# measured session 7 (s7_ramp RUP): uphill on a slide slope the press ends the dash into crouch friction
		if GroundState.moving_uphill_on_slide_slope(sim, s):
			GroundState.enter_crouch(sim, s)
		else:
			enter_dash_slide(sim, s)
		return
	if k >= s.dash_total_ticks:
		_end_ground_dash(sim, s, ctx)


## G21: the dash slide starts at dash_slide_speed along the dash direction in every bucket (video_guides
## V5 0:17). A crouch before dash_slide_dead_before gives the slower "dead slide" (measured session 11, S11-DC).
static func enter_dash_slide(sim: MovementSim, s: MoveState) -> void:
	var p := sim.cp.params
	var v := p.dash_slide_dead_speed if s.dash_ticks * MoveUnits.DT < p.dash_slide_dead_before else p.dash_slide_speed
	GroundState.enter_slide(sim, s, MoveState.SlideKind.DASH, v, s.dash_dir)


## spec: movement.md §9 dash-jump: +1 stamina, horizontal speed per G17, air-control bonus.
static func _dash_jump(sim: MovementSim, s: MoveState, ctx: Ctx) -> void:
	var p := sim.cp.params
	sim.spend(s, p.cost_dash_jump_extra)
	close_window(sim, s)
	var h := Vector3(s.velocity.x, 0.0, s.velocity.z)
	if p.dash_jump_speed_mode == 1:
		# G17 (fixes K13): SET to one bucket-independent speed along the dash direction, prior discarded
		# (ground_dash.md rule 13, video_guides V9 0:19). Measured session 4: 703 u/s for Haze (B1) and Abrams (B3).
		var d := Vector3(s.dash_dir.x, 0.0, s.dash_dir.z)
		if d.length_squared() < 1e-9:
			d = h
		if d.length_squared() < 1e-9:
			d = sim.facing(s)
		h = d.normalized() * p.dash_jump_set_speed
	else:
		h *= p.dash_jump_horizontal_mult   # legacy K13 (contradicted by V9 0:19)
	s.velocity = Vector3(h.x, p.dash_jump_vertical_speed, h.z)
	s.dash_jump_bonus_ticks = sim.cp.dash_jump_bonus_ticks
	s.dash_jumped_this_airtime = true
	# G40: crouch stored before the dash and still held: no slide on landing
	if s.dash_crouch_stored and ctx.is_held(InputCmd.BTN_CROUCH):
		s.slide_block_until_crouch_release = true
	s.grounded = false
	s.ground_normal = Vector3.UP
	s.coyote_ticks = 0
	s.action_buffer_ticks = 0
	s.action_buffer_button = 0
	sim.try_uncrouch(s)
	s.loco = L.AIR
	sim.emit(s, MoveEvents.JUMPED, {"kind": &"dash_jump"})


static func _end_ground_dash(sim: MovementSim, s: MoveState, ctx: Ctx) -> void:
	var p := sim.cp.params
	close_window(sim, s)
	var buffered_jump := s.action_buffer_ticks > 0 and (s.action_buffer_button & InputCmd.BTN_JUMP) != 0
	var crouch := ctx.is_held(InputCmd.BTN_CROUCH)
	if buffered_jump and s.grounded and (ctx.mask & ControlLocks.JUMP) == 0:
		# K14 removed: the dash hop keeps the dash's tail speed, no clamp (video_guides V9 3:03,
		# ground_dash.md rule 12b / momentum table; gap G22).
		sim.do_ground_jump(s, ctx, &"buffered")
		return
	# spec: movement.md §8 dash slide unless crouch was stored before the dash
	if crouch and not s.dash_crouch_stored and s.grounded and not GroundState.moving_uphill_on_slide_slope(sim, s):
		enter_dash_slide(sim, s)
		return
	# spec: movement.md §8 exit clamp (Open Q6)
	if p.ground_dash_exit_clamp:
		sim.clamp_horizontal(s, sim.cp.effective_move_speed(s, ctx.firing))
	if s.grounded:
		if crouch:
			if s.dash_crouch_stored:
				# spec: movement.md §6 crouch storage: the dash never becomes a slide, on any surface; block
				# CROUCH->SLIDE until crouch is released (ground_dash.md rule 9). K17 removed: no extra clamp to
				# crouch speed (no source); the walk-speed dash end (rule 4) then crouch friction apply.
				s.slide_block_until_crouch_release = true
			GroundState.enter_crouch(sim, s)
		else:
			sim.try_uncrouch(s)
			s.loco = L.GROUND if not s.crouched else L.CROUCH
	else:
		s.loco = L.AIR


static func close_window(sim: MovementSim, s: MoveState) -> void:
	if s.dash_jump_window_open:
		s.dash_jump_window_open = false
		sim.emit(s, MoveEvents.DASH_JUMP_WINDOW, {"open": false})


## Dash physics: constant velocity, gravity suspended, fractional last tick (design §7.10).
static func physics(sim: MovementSim, s: MoveState, ctx: Ctx) -> void:
	if s.dash_ticks >= s.dash_total_ticks - 1:
		ctx.frac = s.dash_last_fraction
	if s.loco == L.GROUND_DASH:
		var vy := 0.0
		if not s.grounded:
			vy = s.velocity.y
		s.velocity = Vector3(s.dash_dir.x * s.dash_speed, vy, s.dash_dir.z * s.dash_speed)
		if not s.grounded:
			# dashing off a ledge: fall normally (gravity suspension only applies on the ground)
			sim.gravity_half(s, ctx)
	else:
		# spec: movement.md §11 air dash: gravity and air drag disabled for the dash
		# (vy held at 0 per design §7.10, or kept constant when air_dash_zero_vertical is off)
		if sim.cp.params.air_dash_zero_vertical:
			s.velocity.y = 0.0
		if sim.cp.params.air_dash_cap_mode == 3:
			_air_dash_ramp_tick(sim, s, ctx)


## Counts completed dash ticks and emits the dash-jump window events (spec: movement.md §9).
static func post_move(sim: MovementSim, s: MoveState, ctx: Ctx) -> void:
	if s.loco != L.GROUND_DASH and s.loco != L.AIR_DASH:
		return
	s.dash_ticks += 1
	if s.loco == L.GROUND_DASH:
		if s.dash_ticks == sim.cp.dash_jump_open_tick and not s.dash_jump_window_open:
			s.dash_jump_window_open = true
			sim.emit(s, MoveEvents.DASH_JUMP_WINDOW, {"open": true})
		elif s.dash_ticks == sim.cp.dash_jump_close_tick + 1:
			close_window(sim, s)
